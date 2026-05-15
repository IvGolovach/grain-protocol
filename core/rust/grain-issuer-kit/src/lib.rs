use std::io::Write;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use ed25519_dalek::{Signer, SigningKey};
use flate2::write::ZlibEncoder;
use flate2::Compression;
use grain_core::cbor::{encode_canonical, CborValue};
use grain_core::dagcbor::{
    validate_serving_offer_payload as validate_core_serving_offer_payload, validate_strict_dagcbor,
};
use grain_core::error::GrainError;
use sha2::{Digest, Sha256};
use thiserror::Error;

const BASE45_ALPHABET: &[u8; 45] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
const GR1_PREFIX: &str = "GR1:";

#[derive(Debug, Error)]
pub enum IssuerError {
    #[error("failed to read OS randomness: {0}")]
    Random(String),
    #[error("payload is not strict DAG-CBOR: {0}")]
    Payload(String),
    #[error("failed to encode GR1 zlib body")]
    Zlib(#[source] std::io::Error),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IssuedQr {
    pub qr_string: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
    pub issuer_kid_b64: String,
}

pub struct Issuer {
    signing_key: SigningKey,
}

impl Issuer {
    pub fn generate() -> Result<Self, IssuerError> {
        let mut seed = [0u8; 32];
        getrandom::fill(&mut seed).map_err(|err| IssuerError::Random(err.to_string()))?;
        Ok(Self::from_seed(seed))
    }

    fn from_seed(seed: [u8; 32]) -> Self {
        Self {
            signing_key: SigningKey::from_bytes(&seed),
        }
    }

    pub fn trust_pub_b64(&self) -> String {
        STANDARD.encode(self.public_key_bytes())
    }

    pub fn issuer_kid(&self) -> [u8; 16] {
        issuer_kid_for_pubkey(&self.public_key_bytes())
    }

    pub fn issuer_kid_b64(&self) -> String {
        STANDARD.encode(self.issuer_kid())
    }

    pub fn issue_sample_serving_offer(&self) -> Result<IssuedQr, IssuerError> {
        let payload = sample_serving_offer_payload(self.issuer_kid());
        self.issue_payload(&payload)
    }

    pub fn issue_payload(&self, payload: &[u8]) -> Result<IssuedQr, IssuerError> {
        validate_serving_offer_payload(payload, self.issuer_kid())?;

        let protected = protected_header(self.issuer_kid());
        let mut protected_bstr = Vec::new();
        encode_canonical(&protected, &mut protected_bstr);

        let mut sig_structure = Vec::new();
        encode_canonical(
            &CborValue::Array(vec![
                CborValue::Text(b"Signature1".to_vec()),
                CborValue::Bytes(protected_bstr.clone()),
                CborValue::Bytes(Vec::new()),
                CborValue::Bytes(payload.to_vec()),
            ]),
            &mut sig_structure,
        );

        let signature = self.signing_key.sign(&sig_structure);
        let cose = cose_sign1(
            protected_bstr,
            payload.to_vec(),
            signature.to_bytes().to_vec(),
        );
        let qr_string = encode_gr1_from_cose(&cose)?;

        Ok(IssuedQr {
            qr_string,
            cose_b64: STANDARD.encode(cose),
            trust_pub_b64: self.trust_pub_b64(),
            issuer_kid_b64: self.issuer_kid_b64(),
        })
    }

    fn public_key_bytes(&self) -> [u8; 32] {
        self.signing_key.verifying_key().to_bytes()
    }
}

pub fn issuer_kid_for_pubkey(pubkey: &[u8; 32]) -> [u8; 16] {
    let digest = Sha256::digest(pubkey);
    let mut kid = [0u8; 16];
    kid.copy_from_slice(&digest[..16]);
    kid
}

pub fn sample_serving_offer_payload(issuer_kid: [u8; 16]) -> Vec<u8> {
    let offer = CborValue::Map(vec![
        (text("v"), CborValue::Unsigned(1)),
        (text("t"), text("ServingOffer")),
        (text("issuer_kid"), CborValue::Bytes(issuer_kid.to_vec())),
        (text("serving_g"), CborValue::Unsigned(250)),
        (text("mean"), nutrients(620, 18, 74, 31)),
        (text("var"), nutrients(9, 1, 4, 2)),
    ]);

    let mut out = Vec::new();
    encode_canonical(&offer, &mut out);
    out
}

fn protected_header(issuer_kid: [u8; 16]) -> CborValue {
    CborValue::Map(vec![
        (CborValue::Unsigned(1), CborValue::Negative(-19)),
        (
            CborValue::Unsigned(4),
            CborValue::Bytes(issuer_kid.to_vec()),
        ),
    ])
}

fn cose_sign1(protected_bstr: Vec<u8>, payload: Vec<u8>, signature: Vec<u8>) -> Vec<u8> {
    let value = CborValue::Array(vec![
        CborValue::Bytes(protected_bstr),
        CborValue::Map(Vec::new()),
        CborValue::Bytes(payload),
        CborValue::Bytes(signature),
    ]);

    let mut out = Vec::new();
    encode_canonical(&value, &mut out);
    out
}

fn encode_gr1_from_cose(cose: &[u8]) -> Result<String, IssuerError> {
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(cose).map_err(IssuerError::Zlib)?;
    let compressed = encoder.finish().map_err(IssuerError::Zlib)?;
    Ok(format!("{GR1_PREFIX}{}", base45_encode(&compressed)))
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

fn nutrients(kcal: u64, fat_g: u64, carb_g: u64, protein_g: u64) -> CborValue {
    CborValue::Map(vec![
        (text("kcal"), CborValue::Unsigned(kcal)),
        (text("fat_g"), CborValue::Unsigned(fat_g)),
        (text("carb_g"), CborValue::Unsigned(carb_g)),
        (text("protein_g"), CborValue::Unsigned(protein_g)),
    ])
}

fn text(value: &str) -> CborValue {
    CborValue::Text(value.as_bytes().to_vec())
}

fn payload_error(err: GrainError) -> IssuerError {
    IssuerError::Payload(err.diag().code().to_string())
}

fn validate_serving_offer_payload(
    payload: &[u8],
    expected_issuer_kid: [u8; 16],
) -> Result<(), IssuerError> {
    let value = validate_strict_dagcbor(payload).map_err(payload_error)?;

    match value.map_get("t").and_then(CborValue::as_text_bytes) {
        Some(b"ServingOffer") => {}
        _ => {
            return Err(IssuerError::Payload(
                "QR payload must be a ServingOffer".to_string(),
            ));
        }
    }

    match value.map_get("issuer_kid").and_then(CborValue::as_bytes) {
        Some(kid) if kid == expected_issuer_kid => {}
        Some(_) => {
            return Err(IssuerError::Payload(
                "ServingOffer issuer_kid must match issuer public key".to_string(),
            ));
        }
        None => {
            return Err(IssuerError::Payload(
                "ServingOffer issuer_kid is required".to_string(),
            ));
        }
    }

    validate_core_serving_offer_payload(payload, &expected_issuer_kid)
        .map(|_| ())
        .map_err(payload_error)
}

#[cfg(test)]
mod tests {
    use super::*;
    use grain_core::qr::decode_gr1_to_cose;

    #[test]
    fn base45_gr1_encoder_round_trips_through_core_decoder() {
        let issuer = Issuer::generate().expect("issuer key generation must succeed");
        let issued = issuer
            .issue_sample_serving_offer()
            .expect("sample offer must issue");
        let decoded = decode_gr1_to_cose(&issued.qr_string).expect("GR1 must decode");

        assert_eq!(STANDARD.encode(decoded), issued.cose_b64);
    }
}
