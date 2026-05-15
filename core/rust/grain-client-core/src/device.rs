use base64::engine::general_purpose::STANDARD;
use base64::Engine;

use crate::diag::{
    SDK_ERR_CSPRNG_UNAVAILABLE, SDK_ERR_DEVICE_EXISTS, SDK_ERR_DEVICE_UNKNOWN,
    SDK_ERR_IDENTITY_MISSING, SDK_ERR_REVOKE_ROOT_FORBIDDEN, SDK_ERR_UNAUTHORIZED_AK,
};
use crate::identity::{derive_kid, hex_sha256, is_authorized, require_identity};
use crate::store::IdentityClientStore;
use crate::types::{DeviceKey, DeviceResult, DeviceStatus, IdentityBundleV1, LifecycleEventRecord};

pub fn device_add_key<S: IdentityClientStore>(store: &mut S, label: &str) -> DeviceResult {
    let mut pub_bytes = [0u8; 32];
    if getrandom::fill(&mut pub_bytes).is_err() {
        return device_rejected(SDK_ERR_CSPRNG_UNAVAILABLE);
    }
    let pub_b64 = STANDARD.encode(pub_bytes);
    let ak = derive_kid(&pub_bytes);

    match store.atomic(|tx| {
        let mut bundle = require_identity(tx)?;
        if bundle.device_keys.iter().any(|device| device.ak == ak) {
            return Err(SDK_ERR_DEVICE_EXISTS.to_string());
        }

        let root_kid = bundle.root_kid.clone();
        let seq = tx.reserve_next_seq(&root_kid)?;
        bundle.seq_state.insert(root_kid.clone(), seq.to_string());
        bundle.device_keys.push(DeviceKey {
            ak: ak.clone(),
            label: label.to_string(),
            pub_b64,
        });
        let event = lifecycle_event("DeviceKeyGrant", &root_kid, seq, &ak);
        tx.save_identity_bundle(bundle.clone())?;
        tx.append_lifecycle_event(event)?;
        Ok(bundle)
    }) {
        Ok(bundle) => device_from_bundle(DeviceStatus::Added, Some(ak), bundle, store),
        Err(diag) => device_rejected(diag),
    }
}

pub fn device_revoke_key<S: IdentityClientStore>(store: &mut S, ak: &str) -> DeviceResult {
    match store.atomic(|tx| {
        let mut bundle = require_identity(tx)?;
        if ak == bundle.root_kid {
            return Err(SDK_ERR_REVOKE_ROOT_FORBIDDEN.to_string());
        }
        if !bundle.device_keys.iter().any(|device| device.ak == ak) {
            return Err(SDK_ERR_DEVICE_UNKNOWN.to_string());
        }
        if bundle.revoked_aks.iter().any(|revoked| revoked == ak) {
            return Ok(bundle);
        }
        bundle.revoked_aks.push(ak.to_string());
        bundle.revoked_aks.sort();
        if bundle.active_ak == ak {
            bundle.active_ak = bundle.root_kid.clone();
        }

        let root_kid = bundle.root_kid.clone();
        let seq = tx.reserve_next_seq(&root_kid)?;
        bundle.seq_state.insert(root_kid.clone(), seq.to_string());
        let event = lifecycle_event("DeviceKeyRevoke", &root_kid, seq, ak);
        tx.save_identity_bundle(bundle.clone())?;
        tx.append_lifecycle_event(event)?;
        Ok(bundle)
    }) {
        Ok(bundle) => {
            device_from_bundle(DeviceStatus::Revoked, Some(ak.to_string()), bundle, store)
        }
        Err(diag) => device_rejected(diag),
    }
}

pub fn device_set_active<S: IdentityClientStore>(store: &mut S, ak: &str) -> DeviceResult {
    match store.atomic(|tx| {
        let mut bundle = require_identity(tx)?;
        if !is_authorized(&bundle, ak) {
            return Err(SDK_ERR_UNAUTHORIZED_AK.to_string());
        }
        bundle.active_ak = ak.to_string();
        tx.save_identity_bundle(bundle.clone())?;
        Ok(bundle)
    }) {
        Ok(bundle) => device_from_bundle(DeviceStatus::Active, Some(ak.to_string()), bundle, store),
        Err(diag) => device_rejected(diag),
    }
}

pub(crate) fn lifecycle_event(
    t: &str,
    root_kid: &str,
    seq: u64,
    target_ak: &str,
) -> LifecycleEventRecord {
    LifecycleEventRecord {
        event_id: lifecycle_event_id(t, root_kid, seq, target_ak),
        t: t.to_string(),
        ak: root_kid.to_string(),
        seq,
        payload_cid: lifecycle_payload_cid(t, target_ak)
            .unwrap_or_else(|| format!("lifecycle:{target_ak}")),
        target_ak: target_ak.to_string(),
    }
}

pub(crate) fn validate_lifecycle_event_record(
    event: &LifecycleEventRecord,
    identity: &IdentityBundleV1,
) -> bool {
    if event.event_id.is_empty()
        || event.t.is_empty()
        || event.ak.is_empty()
        || event.payload_cid.is_empty()
        || event.target_ak.is_empty()
        || event.seq == 0
    {
        return false;
    }
    if event.ak != identity.root_kid {
        return false;
    }
    let Some(expected_payload) = lifecycle_payload_cid(&event.t, &event.target_ak) else {
        return false;
    };
    if event.payload_cid != expected_payload
        || event.event_id != lifecycle_event_id(&event.t, &event.ak, event.seq, &event.target_ak)
    {
        return false;
    }
    let Some(root_seq) = identity
        .seq_state
        .get(&event.ak)
        .and_then(|seq| seq.parse::<u64>().ok())
    else {
        return false;
    };
    if event.seq > root_seq {
        return false;
    }
    if event.target_ak == identity.root_kid
        || !identity
            .device_keys
            .iter()
            .any(|device| device.ak == event.target_ak)
    {
        return false;
    }
    if event.t == "DeviceKeyRevoke"
        && !identity
            .revoked_aks
            .iter()
            .any(|revoked| revoked == &event.target_ak)
    {
        return false;
    }
    true
}

fn lifecycle_payload_cid(t: &str, target_ak: &str) -> Option<String> {
    match t {
        "DeviceKeyGrant" => Some(format!("grant:{target_ak}")),
        "DeviceKeyRevoke" => Some(format!("revoke:{target_ak}")),
        _ => None,
    }
}

fn lifecycle_event_id(t: &str, root_kid: &str, seq: u64, target_ak: &str) -> String {
    format!(
        "event-sha256:{}",
        hex_sha256(format!("{t}:{root_kid}:{seq}:{target_ak}").as_bytes())
    )
}

fn device_from_bundle<S: IdentityClientStore>(
    status: DeviceStatus,
    device_ak: Option<String>,
    bundle: IdentityBundleV1,
    store: &S,
) -> DeviceResult {
    DeviceResult {
        status,
        diag: Vec::new(),
        device_ak,
        active_ak: Some(bundle.active_ak),
        root_kid: Some(bundle.root_kid),
        device_count: bundle.device_keys.len() as u64,
        revoked_count: bundle.revoked_aks.len() as u64,
        lifecycle_event_count: store.list_lifecycle_events().len() as u64,
    }
}

fn device_rejected(diag: impl Into<String>) -> DeviceResult {
    let diag = diag.into();
    DeviceResult {
        status: DeviceStatus::Rejected,
        diag: vec![if diag.is_empty() {
            SDK_ERR_IDENTITY_MISSING.to_string()
        } else {
            diag
        }],
        device_ak: None,
        active_ak: None,
        root_kid: None,
        device_count: 0,
        revoked_count: 0,
        lifecycle_event_count: 0,
    }
}
