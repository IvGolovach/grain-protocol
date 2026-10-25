use serde::{Deserialize, Serialize};

use crate::accepted_scan::validate_accepted_scan_record;
use crate::custody::PortableTransferCustodyV1;
use crate::device::validate_lifecycle_event_record;
use crate::diag::{SDK_ERR_IDENTITY_CONFLICT, SDK_ERR_SYNC_BUNDLE_INVALID};
use crate::identity::{
    decode_json_b64, encode_json_b64, merge_identity_bundle, validate_identity_bundle,
};
use crate::store::{IdentityClientStore, StorePutResult};
use crate::types::{
    AcceptedScanRecord, IdentityBundleV1, LifecycleEventRecord, SyncResult, SyncStatus,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct SyncBundleV1 {
    bundle_v: u32,
    #[serde(default = "sync_custody_default")]
    custody: PortableTransferCustodyV1,
    identity: Option<IdentityBundleV1>,
    accepted_scans: Vec<AcceptedScanRecord>,
    lifecycle_events: Vec<LifecycleEventRecord>,
}

pub fn sync_export_bundle<S: IdentityClientStore>(store: &S) -> SyncResult {
    let identity = store.load_identity_bundle();
    let accepted_scans = store.list_accepted_scans();
    let lifecycle_events = store.list_lifecycle_events();

    if identity.is_none() && accepted_scans.is_empty() && lifecycle_events.is_empty() {
        return SyncResult {
            status: SyncStatus::Empty,
            diag: Vec::new(),
            bundle_b64: None,
            accepted_record_count: 0,
            device_count: 0,
            lifecycle_event_count: 0,
        };
    }

    let device_count = identity
        .as_ref()
        .map(|bundle| bundle.device_keys.len() as u64)
        .unwrap_or(0);
    let bundle = SyncBundleV1 {
        bundle_v: 1,
        custody: PortableTransferCustodyV1::sync_bundle(),
        identity,
        accepted_scans,
        lifecycle_events,
    };
    match encode_json_b64(&bundle) {
        Ok(bundle_b64) => SyncResult {
            status: SyncStatus::Exported,
            diag: Vec::new(),
            bundle_b64: Some(bundle_b64),
            accepted_record_count: bundle.accepted_scans.len() as u64,
            device_count,
            lifecycle_event_count: bundle.lifecycle_events.len() as u64,
        },
        Err(diag) => sync_rejected(diag),
    }
}

pub fn sync_import_bundle<S: IdentityClientStore>(store: &mut S, bundle_b64: &str) -> SyncResult {
    let bundle = match decode_sync_bundle(bundle_b64) {
        Ok(bundle) => bundle,
        Err(diag) => return sync_rejected(diag),
    };

    if let (Some(existing), Some(incoming)) =
        (store.load_identity_bundle(), bundle.identity.as_ref())
    {
        if existing.root_kid != incoming.root_kid {
            return sync_rejected(SDK_ERR_IDENTITY_CONFLICT);
        }
    }

    let import = store.atomic(|tx| {
        let mut inserted = false;

        if let Some(incoming) = bundle.identity.clone() {
            let identity = merge_identity_bundle(
                tx.load_identity_bundle(),
                incoming,
                SDK_ERR_SYNC_BUNDLE_INVALID,
            )?;
            tx.import_seq_state(identity.seq_state.clone())?;
            inserted |= matches!(tx.save_identity_bundle(identity)?, StorePutResult::Inserted);
        }

        for record in &bundle.accepted_scans {
            inserted |= matches!(
                tx.put_accepted_scan(record.clone())?,
                StorePutResult::Inserted
            );
        }
        for event in &bundle.lifecycle_events {
            inserted |= matches!(
                tx.append_lifecycle_event(event.clone())?,
                StorePutResult::Inserted
            );
        }

        Ok::<bool, String>(inserted)
    });

    match import {
        Ok(inserted) => SyncResult {
            status: if inserted {
                SyncStatus::Imported
            } else {
                SyncStatus::AlreadyImported
            },
            diag: Vec::new(),
            bundle_b64: None,
            accepted_record_count: store.list_accepted_scans().len() as u64,
            device_count: store
                .load_identity_bundle()
                .map(|identity| identity.device_keys.len() as u64)
                .unwrap_or(0),
            lifecycle_event_count: store.list_lifecycle_events().len() as u64,
        },
        Err(diag) => sync_rejected(diag),
    }
}

fn decode_sync_bundle(bundle_b64: &str) -> Result<SyncBundleV1, String> {
    let bundle = decode_json_b64::<SyncBundleV1>(bundle_b64, SDK_ERR_SYNC_BUNDLE_INVALID)?;
    if bundle.bundle_v != 1 || !bundle.custody.is_portable_transfer_for("sync_bundle_v1") {
        return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
    }
    if let Some(identity) = &bundle.identity {
        validate_identity_bundle(identity).map_err(|_| SDK_ERR_SYNC_BUNDLE_INVALID.to_string())?;
    }
    for scan in &bundle.accepted_scans {
        validate_accepted_scan_record(scan).map_err(|_| SDK_ERR_SYNC_BUNDLE_INVALID.to_string())?;
    }
    if bundle.identity.is_none() && !bundle.lifecycle_events.is_empty() {
        return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
    }
    if let Some(identity) = &bundle.identity {
        for event in &bundle.lifecycle_events {
            if !validate_lifecycle_event_record(event, identity) {
                return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
            }
        }
    }
    Ok(bundle)
}

fn sync_custody_default() -> PortableTransferCustodyV1 {
    PortableTransferCustodyV1::sync_bundle()
}

fn sync_rejected(diag: impl Into<String>) -> SyncResult {
    SyncResult {
        status: SyncStatus::Rejected,
        diag: vec![diag.into()],
        bundle_b64: None,
        accepted_record_count: 0,
        device_count: 0,
        lifecycle_event_count: 0,
    }
}
