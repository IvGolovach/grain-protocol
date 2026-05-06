use serde::{Deserialize, Serialize};

use crate::custody::PortableTransferCustodyV1;
use crate::diag::{
    SDK_ERR_IDENTITY_CONFLICT, SDK_ERR_IDENTITY_MISSING, SDK_ERR_PAIRING_ENVELOPE_INVALID,
};
use crate::identity::{decode_json_b64, encode_json_b64, hex_sha256, validate_identity_bundle};
use crate::store::IdentityClientStore;
use crate::types::{IdentityBundleV1, PairingResult, PairingStatus};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct PairingEnvelopeV1 {
    pairing_v: u32,
    pairing_id: String,
    transfer: String,
    #[serde(default = "pairing_custody_default")]
    custody: PortableTransferCustodyV1,
    identity_bundle: IdentityBundleV1,
}

pub fn pairing_create_envelope<S: IdentityClientStore>(store: &S) -> PairingResult {
    let Some(bundle) = store.load_identity_bundle() else {
        return pairing_rejected(SDK_ERR_IDENTITY_MISSING);
    };
    let envelope = PairingEnvelopeV1 {
        pairing_v: 1,
        pairing_id: pairing_id_for_bundle(&bundle),
        transfer: "identity_bundle_v1".to_string(),
        custody: PortableTransferCustodyV1::pairing_identity_bundle(),
        identity_bundle: bundle.clone(),
    };

    match encode_json_b64(&envelope) {
        Ok(envelope_b64) => PairingResult {
            status: PairingStatus::Created,
            diag: Vec::new(),
            pairing_id: Some(envelope.pairing_id),
            envelope_b64: Some(envelope_b64),
            root_kid: Some(bundle.root_kid),
            device_count: bundle.device_keys.len() as u64,
        },
        Err(diag) => pairing_rejected(diag),
    }
}

pub fn pairing_preview_envelope(envelope_b64: &str) -> PairingResult {
    match decode_pairing_envelope(envelope_b64) {
        Ok(envelope) => PairingResult {
            status: PairingStatus::Valid,
            diag: Vec::new(),
            pairing_id: Some(envelope.pairing_id),
            envelope_b64: None,
            root_kid: Some(envelope.identity_bundle.root_kid),
            device_count: envelope.identity_bundle.device_keys.len() as u64,
        },
        Err(diag) => pairing_rejected(diag),
    }
}

pub fn pairing_accept_envelope<S: IdentityClientStore>(
    store: &mut S,
    envelope_b64: &str,
) -> PairingResult {
    let envelope = match decode_pairing_envelope(envelope_b64) {
        Ok(envelope) => envelope,
        Err(diag) => return pairing_rejected(diag),
    };

    if let Some(existing) = store.load_identity_bundle() {
        if existing == envelope.identity_bundle {
            return PairingResult {
                status: PairingStatus::AlreadyPaired,
                diag: Vec::new(),
                pairing_id: Some(envelope.pairing_id),
                envelope_b64: None,
                root_kid: Some(existing.root_kid),
                device_count: existing.device_keys.len() as u64,
            };
        }
        return pairing_rejected(SDK_ERR_IDENTITY_CONFLICT);
    }

    match store.atomic(|tx| {
        tx.import_seq_state(envelope.identity_bundle.seq_state.clone())?;
        tx.save_identity_bundle(envelope.identity_bundle.clone())
            .map(|_| ())
    }) {
        Ok(()) => PairingResult {
            status: PairingStatus::Paired,
            diag: Vec::new(),
            pairing_id: Some(envelope.pairing_id),
            envelope_b64: None,
            root_kid: Some(envelope.identity_bundle.root_kid),
            device_count: envelope.identity_bundle.device_keys.len() as u64,
        },
        Err(diag) => pairing_rejected(diag),
    }
}

fn decode_pairing_envelope(envelope_b64: &str) -> Result<PairingEnvelopeV1, String> {
    let envelope =
        decode_json_b64::<PairingEnvelopeV1>(envelope_b64, SDK_ERR_PAIRING_ENVELOPE_INVALID)?;
    if envelope.pairing_v != 1
        || envelope.transfer != "identity_bundle_v1"
        || !envelope
            .custody
            .is_portable_transfer_for("identity_bundle_v1")
        || envelope.pairing_id != pairing_id_for_bundle(&envelope.identity_bundle)
    {
        return Err(SDK_ERR_PAIRING_ENVELOPE_INVALID.to_string());
    }
    validate_identity_bundle(&envelope.identity_bundle)
        .map_err(|_| SDK_ERR_PAIRING_ENVELOPE_INVALID.to_string())?;
    Ok(envelope)
}

fn pairing_id_for_bundle(bundle: &IdentityBundleV1) -> String {
    let material = format!(
        "{}:{}:{}:{}",
        bundle.root_kid,
        bundle.active_ak,
        bundle.sync_secret_b64,
        bundle.device_keys.len()
    );
    format!("pairing-sha256:{}", hex_sha256(material.as_bytes()))
}

fn pairing_custody_default() -> PortableTransferCustodyV1 {
    PortableTransferCustodyV1::pairing_identity_bundle()
}

fn pairing_rejected(diag: impl Into<String>) -> PairingResult {
    PairingResult {
        status: PairingStatus::Rejected,
        diag: vec![diag.into()],
        pairing_id: None,
        envelope_b64: None,
        root_kid: None,
        device_count: 0,
    }
}
