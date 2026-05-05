use grain_client_core::platform::{resolve_trust_pub_b64, StaticTrustProvider};
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
struct VectorFile {
    input: serde_json::Value,
}

fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../conformance/vectors")
}

fn vector(relative: &str) -> VectorFile {
    let text =
        std::fs::read_to_string(fixture_root().join(relative)).expect("fixture must be readable");
    serde_json::from_str(&text).expect("fixture must be valid JSON")
}

fn trusted_pub_b64() -> String {
    vector("cose/POS-COSE-001.json")
        .input
        .get("pub_b64")
        .and_then(serde_json::Value::as_str)
        .expect("POS-COSE-001 must carry input.pub_b64")
        .to_string()
}

#[test]
fn trust_adapter_contract_rejects_missing_anchor_id() {
    let provider = StaticTrustProvider::new();

    let missing = resolve_trust_pub_b64(&provider, None).expect_err("anchor is required");
    let blank = resolve_trust_pub_b64(&provider, Some(" ")).expect_err("blank anchor is required");
    let empty = resolve_trust_pub_b64(&provider, Some("")).expect_err("empty anchor is required");

    assert_eq!(missing, "SDK_ERR_TRUST_ANCHOR_REQUIRED");
    assert_eq!(blank, "SDK_ERR_TRUST_ANCHOR_REQUIRED");
    assert_eq!(empty, "SDK_ERR_TRUST_ANCHOR_REQUIRED");
}

#[test]
fn trust_adapter_contract_rejects_unknown_anchor() {
    let provider = StaticTrustProvider::new();

    let err =
        resolve_trust_pub_b64(&provider, Some("primary")).expect_err("unknown anchor must reject");

    assert_eq!(err, "SDK_ERR_TRUST_ANCHOR_NOT_FOUND");
}

#[test]
fn trust_adapter_contract_rejects_malformed_anchor_material() {
    let provider = StaticTrustProvider::new().with_anchor("primary", "not base64");

    let err =
        resolve_trust_pub_b64(&provider, Some("primary")).expect_err("malformed trust must reject");

    assert_eq!(err, "SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID");
}

#[test]
fn trust_adapter_contract_returns_explicit_anchor_material() {
    let trust_pub_b64 = trusted_pub_b64();
    let provider = StaticTrustProvider::new().with_anchor("primary", trust_pub_b64.clone());

    let resolved = resolve_trust_pub_b64(&provider, Some("primary")).expect("anchor must resolve");

    assert_eq!(resolved, trust_pub_b64);
}
