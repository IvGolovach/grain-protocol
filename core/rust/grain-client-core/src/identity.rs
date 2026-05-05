use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use serde::de::DeserializeOwned;
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::diag::{
    SDK_ERR_CSPRNG_UNAVAILABLE, SDK_ERR_IDENTITY_BUNDLE_INVALID, SDK_ERR_IDENTITY_BUNDLE_VERSION,
    SDK_ERR_IDENTITY_CONFLICT, SDK_ERR_IDENTITY_EXISTS, SDK_ERR_IDENTITY_MISSING,
};
use crate::store::IdentityClientStore;
use crate::types::{
    ClientLifecycle, ClientLifecycleStatus, DeviceKey, IdentityBundleV1, IdentityResult,
    IdentityStatus,
};

pub fn identity_create_root<S: IdentityClientStore>(store: &mut S, label: &str) -> IdentityResult {
    if store.load_identity_bundle().is_some() {
        return identity_rejected(IdentityStatus::AlreadyExists, SDK_ERR_IDENTITY_EXISTS);
    }

    let mut root_pub = [0u8; 32];
    let mut sync_secret = [0u8; 32];
    if getrandom::getrandom(&mut root_pub).is_err()
        || getrandom::getrandom(&mut sync_secret).is_err()
    {
        return identity_rejected(IdentityStatus::Rejected, SDK_ERR_CSPRNG_UNAVAILABLE);
    }

    let root_kid = derive_kid(&root_pub);
    let mut seq_state = BTreeMap::new();
    seq_state.insert(root_kid.clone(), "0".to_string());
    let bundle = IdentityBundleV1 {
        bundle_v: 1,
        root_kid: root_kid.clone(),
        root_pub_b64: STANDARD.encode(root_pub),
        active_ak: root_kid.clone(),
        device_keys: vec![DeviceKey {
            ak: root_kid.clone(),
            label: label.to_string(),
            pub_b64: STANDARD.encode(root_pub),
        }],
        revoked_aks: Vec::new(),
        sync_secret_b64: STANDARD.encode(sync_secret),
        seq_state,
    };

    match store.atomic(|tx| tx.save_identity_bundle(bundle.clone()).map(|_| ())) {
        Ok(()) => identity_from_bundle(IdentityStatus::Created, Vec::new(), Some(bundle), store),
        Err(diag) => identity_rejected(IdentityStatus::Rejected, diag),
    }
}

pub fn identity_export_bundle<S: IdentityClientStore>(store: &S) -> IdentityResult {
    let Some(bundle) = store.load_identity_bundle() else {
        return identity_rejected(IdentityStatus::Uninitialized, SDK_ERR_IDENTITY_MISSING);
    };
    match encode_json_b64(&bundle) {
        Ok(bundle_b64) => {
            let mut result =
                identity_from_bundle(IdentityStatus::Exported, Vec::new(), Some(bundle), store);
            result.bundle_b64 = Some(bundle_b64);
            result
        }
        Err(diag) => identity_rejected(IdentityStatus::Rejected, diag),
    }
}

pub fn identity_import_bundle<S: IdentityClientStore>(
    store: &mut S,
    bundle_b64: &str,
) -> IdentityResult {
    let bundle = match decode_identity_bundle_b64(bundle_b64) {
        Ok(bundle) => bundle,
        Err(diag) => return identity_rejected(IdentityStatus::Rejected, diag),
    };

    if let Some(existing) = store.load_identity_bundle() {
        if existing.root_kid != bundle.root_kid {
            return identity_rejected(IdentityStatus::Rejected, SDK_ERR_IDENTITY_CONFLICT);
        }
    }

    match store.atomic(|tx| {
        tx.import_seq_state(bundle.seq_state.clone())?;
        tx.save_identity_bundle(bundle.clone()).map(|_| ())
    }) {
        Ok(()) => identity_from_bundle(IdentityStatus::Imported, Vec::new(), Some(bundle), store),
        Err(diag) => identity_rejected(IdentityStatus::Rejected, diag),
    }
}

pub fn client_lifecycle<S: IdentityClientStore>(store: &S) -> ClientLifecycle {
    match store.load_identity_bundle() {
        Some(bundle) => ClientLifecycle {
            status: ClientLifecycleStatus::Ready,
            diag: Vec::new(),
            root_kid: Some(bundle.root_kid),
            active_ak: Some(bundle.active_ak),
            device_count: bundle.device_keys.len() as u64,
            revoked_count: bundle.revoked_aks.len() as u64,
            accepted_record_count: store.list_accepted_scans().len() as u64,
            lifecycle_event_count: store.list_lifecycle_events().len() as u64,
        },
        None => ClientLifecycle {
            status: ClientLifecycleStatus::Uninitialized,
            diag: vec![SDK_ERR_IDENTITY_MISSING.to_string()],
            root_kid: None,
            active_ak: None,
            device_count: 0,
            revoked_count: 0,
            accepted_record_count: store.list_accepted_scans().len() as u64,
            lifecycle_event_count: store.list_lifecycle_events().len() as u64,
        },
    }
}

pub(crate) fn derive_kid(bytes: &[u8]) -> String {
    hex_sha256(bytes)[..32].to_string()
}

pub(crate) fn hex_sha256(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    let mut out = String::with_capacity(64);
    for byte in digest {
        write!(&mut out, "{byte:02x}").expect("writing to string cannot fail");
    }
    out
}

pub(crate) fn encode_json_b64<T: Serialize>(value: &T) -> Result<String, String> {
    serde_json::to_vec(value)
        .map(|bytes| STANDARD.encode(bytes))
        .map_err(|_| SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string())
}

pub(crate) fn decode_json_b64<T: DeserializeOwned>(
    value_b64: &str,
    invalid_diag: &'static str,
) -> Result<T, String> {
    let bytes = decode_standard_b64(value_b64, invalid_diag)?;
    serde_json::from_slice(&bytes).map_err(|_| invalid_diag.to_string())
}

pub(crate) fn decode_identity_bundle_b64(bundle_b64: &str) -> Result<IdentityBundleV1, String> {
    let bundle = decode_json_b64::<IdentityBundleV1>(bundle_b64, SDK_ERR_IDENTITY_BUNDLE_INVALID)?;
    validate_identity_bundle(&bundle)?;
    Ok(bundle)
}

pub(crate) fn validate_identity_bundle(bundle: &IdentityBundleV1) -> Result<(), String> {
    if bundle.bundle_v != 1 {
        return Err(SDK_ERR_IDENTITY_BUNDLE_VERSION.to_string());
    }
    if bundle.root_kid.is_empty()
        || bundle.root_pub_b64.is_empty()
        || bundle.active_ak.is_empty()
        || bundle.sync_secret_b64.is_empty()
        || bundle.device_keys.is_empty()
    {
        return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
    }

    let root_pub = decode_standard_b64(&bundle.root_pub_b64, SDK_ERR_IDENTITY_BUNDLE_INVALID)?;
    let sync_secret =
        decode_standard_b64(&bundle.sync_secret_b64, SDK_ERR_IDENTITY_BUNDLE_INVALID)?;
    if root_pub.is_empty() || sync_secret.is_empty() {
        return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
    }
    if derive_kid(&root_pub) != bundle.root_kid {
        return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
    }

    let mut seen = BTreeSet::new();
    let mut root_device_seen = false;
    for device in &bundle.device_keys {
        if device.ak.is_empty() || device.pub_b64.is_empty() {
            return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
        }
        if !seen.insert(device.ak.clone()) {
            return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
        }
        let pub_bytes = decode_standard_b64(&device.pub_b64, SDK_ERR_IDENTITY_BUNDLE_INVALID)?;
        if pub_bytes.is_empty() {
            return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
        }
        if derive_kid(&pub_bytes) != device.ak {
            return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
        }
        if device.ak == bundle.root_kid {
            if pub_bytes != root_pub {
                return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
            }
            root_device_seen = true;
        }
    }

    if !root_device_seen {
        return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
    }
    if !is_authorized(bundle, &bundle.active_ak) {
        return Err(SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string());
    }
    for seq in bundle.seq_state.values() {
        seq.parse::<u64>()
            .map_err(|_| SDK_ERR_IDENTITY_BUNDLE_INVALID.to_string())?;
    }

    Ok(())
}

pub(crate) fn is_authorized(bundle: &IdentityBundleV1, ak: &str) -> bool {
    if ak == bundle.root_kid {
        return true;
    }
    if bundle.revoked_aks.iter().any(|revoked| revoked == ak) {
        return false;
    }
    bundle.device_keys.iter().any(|device| device.ak == ak)
}

pub(crate) fn require_identity<S: IdentityClientStore>(
    store: &S,
) -> Result<IdentityBundleV1, String> {
    store
        .load_identity_bundle()
        .ok_or_else(|| SDK_ERR_IDENTITY_MISSING.to_string())
}

pub(crate) fn identity_from_bundle<S: IdentityClientStore>(
    status: IdentityStatus,
    diag: Vec<String>,
    bundle: Option<IdentityBundleV1>,
    store: &S,
) -> IdentityResult {
    match bundle {
        Some(bundle) => IdentityResult {
            status,
            diag,
            root_kid: Some(bundle.root_kid),
            active_ak: Some(bundle.active_ak),
            bundle_b64: None,
            device_count: bundle.device_keys.len() as u64,
            revoked_count: bundle.revoked_aks.len() as u64,
            lifecycle_event_count: store.list_lifecycle_events().len() as u64,
        },
        None => identity_rejected(status, SDK_ERR_IDENTITY_MISSING),
    }
}

pub(crate) fn identity_rejected(status: IdentityStatus, diag: impl Into<String>) -> IdentityResult {
    IdentityResult {
        status,
        diag: vec![diag.into()],
        root_kid: None,
        active_ak: None,
        bundle_b64: None,
        device_count: 0,
        revoked_count: 0,
        lifecycle_event_count: 0,
    }
}

pub(crate) fn decode_standard_b64(
    value_b64: &str,
    invalid_diag: &'static str,
) -> Result<Vec<u8>, String> {
    if value_b64.is_empty() || value_b64.trim() != value_b64 {
        return Err(invalid_diag.to_string());
    }
    STANDARD
        .decode(value_b64)
        .map_err(|_| invalid_diag.to_string())
}
