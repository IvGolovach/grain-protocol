use aes_gcm::aead::{Aead, Payload};
use aes_gcm::{Aes256Gcm, KeyInit, Nonce};
use hkdf::Hkdf;
use sha2::{Digest, Sha256};

use crate::cid::ensure_cid_link_prefix_0;
use crate::dagcbor::validate_strict_dagcbor;
use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;

const KEY_INFO: &[u8] = b"GrainE2E\0v0.1\0A256GCM\0key";
const NONCE_INFO_PREFIX: &[u8] = b"GrainE2E\0v0.1\0A256GCM\0nonce\0";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DerivedKeyNonce {
    pub key: [u8; 32],
    pub nonce: [u8; 12],
}

pub fn derive_key_nonce(sync_secret: &[u8], cap_id: &[u8], cid_link_bstr: &[u8]) -> GrainResult<DerivedKeyNonce> {
    if sync_secret.len() != 32 || cap_id.len() != 32 {
        return Err(GrainError::from_diag(Diag::E2eInputLength));
    }
    ensure_cid_link_prefix_0(cid_link_bstr)?;

    let hk = Hkdf::<Sha256>::new(Some(cap_id), sync_secret);

    let mut key = [0u8; 32];
    hk.expand(KEY_INFO, &mut key)
        .map_err(|_| GrainError::from_diag(Diag::E2eBadLabel))?;

    let mut nonce = [0u8; 12];
    let mut nonce_info = Vec::with_capacity(NONCE_INFO_PREFIX.len() + cid_link_bstr.len());
    nonce_info.extend_from_slice(NONCE_INFO_PREFIX);
    nonce_info.extend_from_slice(cid_link_bstr);

    hk.expand(&nonce_info, &mut nonce)
        .map_err(|_| GrainError::from_diag(Diag::E2eBadLabel))?;

    Ok(DerivedKeyNonce { key, nonce })
}

pub fn decrypt_encrypted_object(
    encrypted_object_bytes: &[u8],
    sync_secret: &[u8],
    cid_link_bstr: &[u8],
    manifest_chash: Option<&[u8]>,
) -> GrainResult<Vec<u8>> {
    if encrypted_object_bytes.len() > Limits::STRICT_BASELINE.max_e2e_ciphertext_bytes {
        return Err(GrainError::from_diag(Diag::Limit));
    }

    if let Some(expected) = manifest_chash {
        let actual = Sha256::digest(encrypted_object_bytes);
        if expected != actual.as_slice() {
            return Err(GrainError::from_diag(Diag::ChashMismatch));
        }
    }

    let value = validate_strict_dagcbor(encrypted_object_bytes)?;
    let Some(map) = value.as_map() else {
        return Err(GrainError::from_diag(Diag::Schema));
    };

    let t = map_find_text(map, "t");
    if t.as_deref() != Some("EncryptedObject") {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let v = map_find_unsigned(map, "v");
    if v != Some(1) {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let alg = map_find_text(map, "alg");
    if alg.as_deref() != Some("A256GCM") {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let cap_id = map_find_bytes(map, "cap_id").ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    if cap_id.len() != 32 {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let nonce_env = map_find_bytes(map, "nonce").ok_or_else(|| GrainError::from_diag(Diag::Schema))?;
    if nonce_env.len() != 12 {
        return Err(GrainError::from_diag(Diag::Schema));
    }

    let ct = map_find_bytes(map, "ct").ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

    let derived = derive_key_nonce(sync_secret, &cap_id, cid_link_bstr)?;

    let cipher = Aes256Gcm::new_from_slice(&derived.key).map_err(|e| GrainError::Internal(e.to_string()))?;
    let nonce = Nonce::from_slice(&derived.nonce);

    let pt = cipher
        .decrypt(
            nonce,
            Payload {
                msg: &ct,
                aad: &cap_id,
            },
        )
        .map_err(|_| GrainError::from_diag(Diag::AeadAuth))?;

    if nonce_env.as_slice() != derived.nonce.as_slice() {
        return Err(GrainError::from_diag(Diag::NonceProfileMismatch));
    }

    Ok(pt)
}

fn map_find<'a>(map: &'a [(crate::cbor::CborValue, crate::cbor::CborValue)], key: &str) -> Option<&'a crate::cbor::CborValue> {
    for (k, v) in map {
        if k.as_text_bytes() == Some(key.as_bytes()) {
            return Some(v);
        }
    }
    None
}

fn map_find_text(map: &[(crate::cbor::CborValue, crate::cbor::CborValue)], key: &str) -> Option<String> {
    map_find(map, key).and_then(|v| v.as_text())
}

fn map_find_unsigned(map: &[(crate::cbor::CborValue, crate::cbor::CborValue)], key: &str) -> Option<u64> {
    let v = map_find(map, key)?;
    match v {
        crate::cbor::CborValue::Unsigned(n) => Some(*n),
        _ => None,
    }
}

fn map_find_bytes(map: &[(crate::cbor::CborValue, crate::cbor::CborValue)], key: &str) -> Option<Vec<u8>> {
    map_find(map, key).and_then(|v| v.as_bytes().map(|b| b.to_vec()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derive_key_nonce_is_deterministic_for_same_inputs() {
        let sync_secret = [0u8; 32];
        let cap_id = [1u8; 32];
        let cid_link = [0x00, 0x42, 0x99];

        let first = derive_key_nonce(&sync_secret, &cap_id, &cid_link).unwrap();
        let second = derive_key_nonce(&sync_secret, &cap_id, &cid_link).unwrap();

        assert_eq!(first, second);
    }

    #[test]
    fn derive_key_nonce_rejects_bad_cid_link_prefix() {
        let sync_secret = [0u8; 32];
        let cap_id = [1u8; 32];
        let cid_link = [0x01, 0x42, 0x99];

        let err = derive_key_nonce(&sync_secret, &cap_id, &cid_link).unwrap_err();
        assert_eq!(err.diag(), Diag::BadCidLink);
    }

    #[test]
    fn decrypt_encrypted_object_rejects_manifest_chash_mismatch() {
        let err = decrypt_encrypted_object(
            b"not-an-encrypted-object",
            &[0u8; 32],
            &[0x00, 0x42],
            Some(&[0xaa, 0xbb]),
        )
        .unwrap_err();

        assert_eq!(err.diag(), Diag::ChashMismatch);
    }
}
