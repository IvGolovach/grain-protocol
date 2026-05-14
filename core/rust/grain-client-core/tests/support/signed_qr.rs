use std::io::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use ed25519_dalek::{Signer, SigningKey};
use flate2::write::ZlibEncoder;
use flate2::Compression;
use grain_core::cbor::{encode_canonical, CborValue};
use grain_core::cose::kid_for_public_key;

const BASE45_ALPHABET: &[u8; 45] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

pub struct SignedQr {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

pub fn signed_qr_for_payload(payload: &[u8]) -> SignedQr {
    let signing_key = SigningKey::from_bytes(&[9u8; 32]);
    let pub_key = signing_key.verifying_key().to_bytes().to_vec();
    let protected = CborValue::Map(vec![
        (CborValue::Unsigned(1), CborValue::Negative(-19)),
        (
            CborValue::Unsigned(4),
            CborValue::Bytes(kid_for_public_key(&pub_key)),
        ),
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
    let mut cose_bytes = Vec::new();
    encode_canonical(&cose, &mut cose_bytes);

    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder
        .write_all(&cose_bytes)
        .expect("test QR zlib write must succeed");
    let compressed = encoder.finish().expect("test QR zlib finish must succeed");

    SignedQr {
        qr_string: format!("GR1:{}", base45_encode(&compressed)),
        trust_pub_b64: STANDARD.encode(pub_key),
    }
}

fn base45_encode(bytes: &[u8]) -> String {
    let mut out = String::new();
    let mut chunks = bytes.chunks_exact(2);

    for chunk in &mut chunks {
        let value = u16::from_be_bytes([chunk[0], chunk[1]]) as usize;
        out.push(BASE45_ALPHABET[value % 45] as char);
        out.push(BASE45_ALPHABET[(value / 45) % 45] as char);
        out.push(BASE45_ALPHABET[value / (45 * 45)] as char);
    }

    let rem = chunks.remainder();
    if let Some(&byte) = rem.first() {
        let value = byte as usize;
        out.push(BASE45_ALPHABET[value % 45] as char);
        out.push(BASE45_ALPHABET[value / 45] as char);
    }

    out
}
