use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use sha2::{Digest, Sha256};

use crate::cbor::{encode_canonical, parse_exact_to_error, CborValue, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};

const ED25519_FIELD_P_LE: [u8; 32] = [
    0xed, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
];

const ED25519_SCALAR_L_LE: [u8; 32] = [
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
];

const ED25519_SMALL_ORDER_ENCODINGS: [[u8; 32]; 8] = [
    [
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
    ],
    [
        0xc7, 0x17, 0x6a, 0x70, 0x3d, 0x4d, 0xd8, 0x4f, 0xba, 0x3c, 0x0b, 0x76, 0x0d, 0x10, 0x67,
        0x0f, 0x2a, 0x20, 0x53, 0xfa, 0x2c, 0x39, 0xcc, 0xc6, 0x4e, 0xc7, 0xfd, 0x77, 0x92, 0xac,
        0x03, 0x7a,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x80,
    ],
    [
        0x26, 0xe8, 0x95, 0x8f, 0xc2, 0xb2, 0x27, 0xb0, 0x45, 0xc3, 0xf4, 0x89, 0xf2, 0xef, 0x98,
        0xf0, 0xd5, 0xdf, 0xac, 0x05, 0xd3, 0xc6, 0x33, 0x39, 0xb1, 0x38, 0x02, 0x88, 0x6d, 0x53,
        0xfc, 0x05,
    ],
    [
        0xec, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x7f,
    ],
    [
        0x26, 0xe8, 0x95, 0x8f, 0xc2, 0xb2, 0x27, 0xb0, 0x45, 0xc3, 0xf4, 0x89, 0xf2, 0xef, 0x98,
        0xf0, 0xd5, 0xdf, 0xac, 0x05, 0xd3, 0xc6, 0x33, 0x39, 0xb1, 0x38, 0x02, 0x88, 0x6d, 0x53,
        0xfc, 0x85,
    ],
    [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
    ],
    [
        0xc7, 0x17, 0x6a, 0x70, 0x3d, 0x4d, 0xd8, 0x4f, 0xba, 0x3c, 0x0b, 0x76, 0x0d, 0x10, 0x67,
        0x0f, 0x2a, 0x20, 0x53, 0xfa, 0x2c, 0x39, 0xcc, 0xc6, 0x4e, 0xc7, 0xfd, 0x77, 0x92, 0xac,
        0x03, 0xfa,
    ],
];

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
    validate_strict_ed25519_inputs(pub_key, sig_bytes)?;

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

fn validate_strict_ed25519_inputs(pub_key: &[u8], sig_bytes: &[u8]) -> GrainResult<()> {
    if pub_key.len() != 32 || sig_bytes.len() != 64 {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    let r_bytes = &sig_bytes[..32];
    let s_bytes = &sig_bytes[32..];
    if !is_canonical_edwards_y(pub_key)
        || !is_canonical_edwards_y(r_bytes)
        || is_small_order_edwards_encoding(pub_key)
        || is_small_order_edwards_encoding(r_bytes)
        || !le_bytes_less_than(s_bytes, &ED25519_SCALAR_L_LE)
    {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    Ok(())
}

fn is_canonical_edwards_y(bytes: &[u8]) -> bool {
    if bytes.len() != 32 {
        return false;
    }
    let sign_bit_set = bytes[31] & 0x80 != 0;
    let mut y = [0u8; 32];
    y.copy_from_slice(bytes);
    y[31] &= 0x7f;
    if !le_bytes_less_than(&y, &ED25519_FIELD_P_LE) {
        return false;
    }

    // RFC 8032 point decoding rejects x=0 with the x-sign bit set. On
    // Edwards25519, x=0 only when y is 1 or -1.
    !(sign_bit_set && edwards_y_has_zero_x(&y))
}

fn edwards_y_has_zero_x(y: &[u8; 32]) -> bool {
    let is_identity = y[0] == 1 && y[1..].iter().all(|byte| *byte == 0);
    let is_negative_identity =
        y[0] == 0xec && y[1..31].iter().all(|byte| *byte == 0xff) && y[31] == 0x7f;
    is_identity || is_negative_identity
}

fn is_small_order_edwards_encoding(bytes: &[u8]) -> bool {
    ED25519_SMALL_ORDER_ENCODINGS
        .iter()
        .any(|candidate| bytes == candidate)
}

fn le_bytes_less_than(value: &[u8], limit: &[u8; 32]) -> bool {
    if value.len() != 32 {
        return false;
    }
    for i in (0..32).rev() {
        if value[i] < limit[i] {
            return true;
        }
        if value[i] > limit[i] {
            return false;
        }
    }
    false
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

    #[test]
    fn strict_ed25519_input_validator_rejects_bad_lengths() {
        let bad_pub_key = validate_strict_ed25519_inputs(&[0u8; 31], &[0u8; 64]).unwrap_err();
        let bad_sig = validate_strict_ed25519_inputs(&[0u8; 32], &[0u8; 63]).unwrap_err();

        assert_eq!(bad_pub_key.diag(), Diag::CoseProfile);
        assert_eq!(bad_sig.diag(), Diag::CoseProfile);
    }

    #[test]
    fn canonical_edwards_y_rejects_negative_zero_aliases() {
        let mut identity_alias = ED25519_SMALL_ORDER_ENCODINGS[0];
        identity_alias[31] |= 0x80;
        let mut negative_identity_alias = ED25519_SMALL_ORDER_ENCODINGS[4];
        negative_identity_alias[31] |= 0x80;

        assert!(!is_canonical_edwards_y(&identity_alias));
        assert!(!is_canonical_edwards_y(&negative_identity_alias));
    }
}
