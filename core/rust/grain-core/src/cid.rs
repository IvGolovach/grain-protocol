use sha2::{Digest, Sha256};

use crate::error::{Diag, GrainError, GrainResult};

pub fn derive_cid_v1_dag_cbor_sha256(bytes: &[u8]) -> GrainResult<String> {
    let digest = Sha256::digest(bytes);

    let mut cid_bytes = Vec::new();
    push_varint(1, &mut cid_bytes); // cidv1
    push_varint(0x71, &mut cid_bytes); // dag-cbor codec
    push_varint(0x12, &mut cid_bytes); // sha2-256 multihash code
    push_varint(32, &mut cid_bytes); // digest length
    cid_bytes.extend_from_slice(&digest);

    let b32 = base32_lower_no_pad(&cid_bytes);
    Ok(format!("b{}", b32))
}

pub fn ensure_cid_link_prefix_0(cid_link_bstr: &[u8]) -> GrainResult<()> {
    if cid_link_bstr.first().copied() != Some(0x00) {
        return Err(GrainError::from_diag(Diag::BadCidLink));
    }
    Ok(())
}

fn push_varint(mut v: u64, out: &mut Vec<u8>) {
    loop {
        let mut b = (v & 0x7f) as u8;
        v >>= 7;
        if v != 0 {
            b |= 0x80;
        }
        out.push(b);
        if v == 0 {
            break;
        }
    }
}

fn base32_lower_no_pad(data: &[u8]) -> String {
    const ALPHABET: &[u8; 32] = b"abcdefghijklmnopqrstuvwxyz234567";

    let mut out = String::new();
    let mut buffer: u32 = 0;
    let mut bits_left: u8 = 0;

    for &byte in data {
        buffer = (buffer << 8) | byte as u32;
        bits_left += 8;
        while bits_left >= 5 {
            let idx = ((buffer >> (bits_left - 5)) & 0x1f) as usize;
            out.push(ALPHABET[idx] as char);
            bits_left -= 5;
        }
    }

    if bits_left > 0 {
        let idx = ((buffer << (5 - bits_left)) & 0x1f) as usize;
        out.push(ALPHABET[idx] as char);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base32_no_pad_smoke() {
        assert_eq!(base32_lower_no_pad(&[0xff]), "74");
        assert_eq!(base32_lower_no_pad(b""), "");
    }

    #[test]
    fn ensure_cid_link_prefix_0_accepts_prefixed_bytes() {
        assert!(ensure_cid_link_prefix_0(&[0x00, 0x11, 0x22]).is_ok());
    }

    #[test]
    fn ensure_cid_link_prefix_0_rejects_missing_prefix() {
        let err = ensure_cid_link_prefix_0(&[0x01, 0x11, 0x22]).unwrap_err();
        assert_eq!(err.diag(), Diag::BadCidLink);
    }
}
