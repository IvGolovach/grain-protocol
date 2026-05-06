use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::custody::PortableTransferCustodyV1;
use crate::diag::{SDK_ERR_IDENTITY_CONFLICT, SDK_ERR_SYNC_BUNDLE_INVALID};
use crate::identity::{decode_json_b64, encode_json_b64, validate_identity_bundle};
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
            let identity = merge_identity_bundle(tx.load_identity_bundle(), incoming)?;
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
        if scan.scan_id.is_empty() || scan.cose_b64.is_empty() || scan.trust_pub_b64.is_empty() {
            return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
        }
    }
    if bundle.identity.is_none() && !bundle.lifecycle_events.is_empty() {
        return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
    }
    if let Some(identity) = &bundle.identity {
        for event in &bundle.lifecycle_events {
            if event.ak != identity.root_kid
                || !identity
                    .device_keys
                    .iter()
                    .any(|device| device.ak == event.target_ak)
            {
                return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
            }
        }
    }
    for event in &bundle.lifecycle_events {
        if event.event_id.is_empty()
            || event.t.is_empty()
            || event.ak.is_empty()
            || event.payload_cid.is_empty()
            || event.target_ak.is_empty()
        {
            return Err(SDK_ERR_SYNC_BUNDLE_INVALID.to_string());
        }
    }
    Ok(bundle)
}

fn merge_identity_bundle(
    existing: Option<IdentityBundleV1>,
    mut incoming: IdentityBundleV1,
) -> Result<IdentityBundleV1, String> {
    let Some(mut existing) = existing else {
        return Ok(incoming);
    };
    if existing.root_kid != incoming.root_kid
        || existing.root_pub_b64 != incoming.root_pub_b64
        || existing.sync_secret_b64 != incoming.sync_secret_b64
    {
        return Err(SDK_ERR_IDENTITY_CONFLICT.to_string());
    }

    let mut known_device_pubs = BTreeMap::new();
    for device in &existing.device_keys {
        known_device_pubs.insert(device.ak.clone(), device.pub_b64.clone());
    }
    let mut new_devices = Vec::new();
    for device in incoming.device_keys.drain(..) {
        match known_device_pubs.get(&device.ak) {
            Some(existing_pub_b64) if existing_pub_b64 != &device.pub_b64 => {
                return Err(SDK_ERR_IDENTITY_CONFLICT.to_string());
            }
            Some(_) => {}
            None => {
                known_device_pubs.insert(device.ak.clone(), device.pub_b64.clone());
                new_devices.push(device);
            }
        }
    }
    new_devices.sort_by(|left, right| left.ak.cmp(&right.ak));
    existing.device_keys.extend(new_devices);

    for revoked in incoming.revoked_aks {
        if !existing.revoked_aks.iter().any(|known| known == &revoked) {
            existing.revoked_aks.push(revoked);
        }
    }
    existing.revoked_aks.sort();

    for (ak, incoming_seq) in incoming.seq_state {
        let incoming_seq = incoming_seq
            .parse::<u64>()
            .map_err(|_| SDK_ERR_SYNC_BUNDLE_INVALID.to_string())?;
        let merged_seq = existing
            .seq_state
            .get(&ak)
            .map(|seq| {
                seq.parse::<u64>()
                    .map(|existing_seq| existing_seq.max(incoming_seq))
                    .map_err(|_| SDK_ERR_SYNC_BUNDLE_INVALID.to_string())
            })
            .transpose()?
            .unwrap_or(incoming_seq);
        existing.seq_state.insert(ak, merged_seq.to_string());
    }

    if existing
        .revoked_aks
        .iter()
        .any(|revoked| revoked == &existing.active_ak)
        || !existing
            .device_keys
            .iter()
            .any(|device| device.ak == existing.active_ak)
    {
        existing.active_ak = incoming.active_ak;
        if existing
            .revoked_aks
            .iter()
            .any(|revoked| revoked == &existing.active_ak)
            || !existing
                .device_keys
                .iter()
                .any(|device| device.ak == existing.active_ak)
        {
            existing.active_ak = existing.root_kid.clone();
        }
    }

    validate_identity_bundle(&existing).map_err(|_| SDK_ERR_SYNC_BUNDLE_INVALID.to_string())?;
    Ok(existing)
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
