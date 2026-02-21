use ed25519_dalek::{Signature, Verifier, VerifyingKey};

use crate::cbor::{encode_canonical, parse_exact_to_error, CborValue, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};

pub fn verify_cose_sign1(cose_bytes: &[u8], pub_key: &[u8], external_aad: &[u8]) -> GrainResult<()> {
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
    let mut kid_ok = false;

    for (k, v) in pmap {
        match (k, v) {
            (CborValue::Unsigned(1), CborValue::Negative(-19)) => {
                alg_ok = true;
            }
            (CborValue::Unsigned(4), CborValue::Bytes(_kid)) => {
                kid_ok = true;
            }
            _ => return Err(GrainError::from_diag(Diag::CoseProfile)),
        }
    }

    if !(alg_ok && kid_ok) {
        return Err(GrainError::from_diag(Diag::CoseProfile));
    }

    if pub_key.len() != 32 {
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

    let sig = Signature::from_slice(sig_bytes).map_err(|_| GrainError::from_diag(Diag::CoseProfile))?;

    verify_key
        .verify(&to_sign, &sig)
        .map_err(|_| GrainError::from_diag(Diag::CoseProfile))?;

    Ok(())
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
