use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use sha2::{Digest, Sha256};

use crate::cbor::{encode_canonical, parse_exact_to_error, CborValue, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedCoseSign1 {
    pub payload: Vec<u8>,
    pub kid: Vec<u8>,
}

pub fn verify_cose_sign1(
    cose_bytes: &[u8],
    pub_key: &[u8],
    external_aad: &[u8],
) -> GrainResult<()> {
    verify_cose_sign1_payload(cose_bytes, pub_key, external_aad).map(|_| ())
}

pub fn verify_cose_sign1_payload(
    cose_bytes: &[u8],
    pub_key: &[u8],
    external_aad: &[u8],
) -> GrainResult<VerifiedCoseSign1> {
    if is_top_level_tag18(cose_bytes) {
        return Err(GrainError::from_diag(Diag::CoseTag18Forbidden));
    }

    let value = parse_exact_to_error(cose_bytes, ParseOptions::generic_cbor_canonical())?;

    let mut canonical = Vec::new();
    encode_canonical(&value, &mut canonical);
    if canonical != cose_bytes {
        return Err(GrainError::from_diag(Diag::NonCanonical));
    }

    let CborValue::Array(items) = value else {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    };

    if items.len() != 4 {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let protected_bstr = items[0]
        .as_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::CoseProfile))?;

    let unprotected = &items[1];
    match unprotected {
        CborValue::Map(m) if m.is_empty() => {}
        _ => return Err(GrainError::from_diag(Diag::CoseProfile)),
    }

    if !external_aad.is_empty() {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let payload = items[2]
        .as_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::CoseProfile))?;

    let sig_bytes = items[3]
        .as_bytes()
        .ok_or_else(|| GrainError::from_diag(Diag::CoseProfile))?;

    if sig_bytes.len() != 64 {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let protected = parse_exact_to_error(protected_bstr, ParseOptions::generic_cbor_canonical())?;
    let mut protected_canonical = Vec::new();
    encode_canonical(&protected, &mut protected_canonical);
    if protected_canonical != protected_bstr {
        return Err(GrainError::from_diag(Diag::NonCanonical));
    }

    let CborValue::Map(pmap) = protected else {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    };

    if pmap.len() != 2 {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let mut alg_ok = false;
    let mut protected_kid: Option<Vec<u8>> = None;

    for (k, v) in pmap {
        match (k, v) {
            (CborValue::Unsigned(1), CborValue::Negative(-19)) => {
                alg_ok = true;
            }
            (CborValue::Unsigned(4), CborValue::Bytes(kid)) => {
                if kid.len() != 16 {
                    return Err(GrainError::from_diag(Diag::CoseProfile));
                }
                protected_kid = Some(kid);
            }
            _ => return Err(GrainError::from_diag(Diag::CoseProfile)),
        }
    }

    let Some(protected_kid) = protected_kid else {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    };

    if !alg_ok {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    if pub_key.len() != 32 {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }
    let expected_kid = kid_for_public_key(pub_key);
    if protected_kid != expected_kid {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let mut to_sign = Vec::new();
    let sig_structure = CborValue::Array(vec![
        CborValue::Text(b"Signature1".to_vec()),
        CborValue::Bytes(protected_bstr.to_vec()),
        CborValue::Bytes(external_aad.to_vec()),
        CborValue::Bytes(payload.to_vec()),
    ]);
    encode_canonical(&sig_structure, &mut to_sign);

    let verify_key = VerifyingKey::from_bytes(
        &pub_key
            .try_into()
            .map_err(|_| GrainError::from_diag(Diag::CoseProfile))?,
    )
    .map_err(|_| GrainError::from_diag(Diag::CoseProfile))?;

    let sig =
        Signature::from_slice(sig_bytes).map_err(|_| GrainError::from_diag(Diag::CoseProfile))?;

    verify_key
        .verify(&to_sign, &sig)
        .map_err(|_| GrainError::from_diag(Diag::CoseProfile))?;

    Ok(VerifiedCoseSign1 {
        payload: payload.to_vec(),
        kid: protected_kid,
    })
}

pub fn kid_for_public_key(pub_key: &[u8]) -> Vec<u8> {
    let digest = Sha256::digest(pub_key);
    digest[..16].to_vec()
}

fn is_top_level_tag18(bytes: &[u8]) -> bool {
    if bytes.is_empty() {
        return false;
    }
    let b0 = bytes[0];
    let major = b0 >> 5;
    let ai = b0 & 0x1f;
    if major != 6 {
        return false;
    }

    match ai {
        18 => true,
        24 => bytes.get(1).copied() == Some(18),
        25 => bytes.get(1).copied() == Some(0) && bytes.get(2).copied() == Some(18),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};

    fn cose_for_payload(payload: &[u8], protected_kid: Vec<u8>) -> (Vec<u8>, Vec<u8>) {
        let signing_key = SigningKey::from_bytes(&[7u8; 32]);
        let pub_key = signing_key.verifying_key().to_bytes().to_vec();
        let protected = CborValue::Map(vec![
            (CborValue::Unsigned(1), CborValue::Negative(-19)),
            (CborValue::Unsigned(4), CborValue::Bytes(protected_kid)),
        ]);
        let mut protected_bstr = Vec::new();
        encode_canonical(&protected, &mut protected_bstr);
        let sig_structure = CborValue::Array(vec![
            CborValue::Text(b"Signature1".to_vec()),
            CborValue::Bytes(protected_bstr.clone()),
            CborValue::Bytes(Vec::new()),
            CborValue::Bytes(payload.to_vec()),
        ]);
        let mut to_sign = Vec::new();
        encode_canonical(&sig_structure, &mut to_sign);
        let signature = signing_key.sign(&to_sign);
        let cose = CborValue::Array(vec![
            CborValue::Bytes(protected_bstr),
            CborValue::Map(Vec::new()),
            CborValue::Bytes(payload.to_vec()),
            CborValue::Bytes(signature.to_bytes().to_vec()),
        ]);
        let mut out = Vec::new();
        encode_canonical(&cose, &mut out);
        (out, pub_key)
    }

    #[test]
    fn verify_returns_payload_and_kid_when_signature_and_kid_match() {
        let payload = b"payload";
        let signing_key = SigningKey::from_bytes(&[7u8; 32]);
        let pub_key = signing_key.verifying_key().to_bytes().to_vec();
        let expected_kid = kid_for_public_key(&pub_key);
        let (cose, pub_key) = cose_for_payload(payload, expected_kid.clone());

        let verified = verify_cose_sign1_payload(&cose, &pub_key, &[]).unwrap();

        assert_eq!(verified.payload, payload);
        assert_eq!(verified.kid, expected_kid);
    }

    #[test]
    fn verify_rejects_protected_kid_that_does_not_match_public_key() {
        let (cose, pub_key) = cose_for_payload(b"payload", vec![0x42; 16]);

        let err = verify_cose_sign1_payload(&cose, &pub_key, &[]).unwrap_err();

        assert_eq!(err.diag(), Diag::CoseProfile);
    }
}
