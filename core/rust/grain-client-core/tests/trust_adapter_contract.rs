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

#[test]
fn trust_anchor_bundle_builds_static_provider_without_fallback() {
    let trust_pub_b64 = trusted_pub_b64();
    let bundle = format!(
        r#"{{
            "bundle_v": 1,
            "anchors": [
                {{"id": "fixture:primary", "trust_pub_b64": "{trust_pub_b64}"}}
            ]
        }}"#
    );

    let provider = StaticTrustProvider::from_bundle_json(&bundle).expect("valid bundle must parse");

    let resolved = resolve_trust_pub_b64(&provider, Some("fixture:primary"))
        .expect("bundle anchor must resolve");
    let unknown = resolve_trust_pub_b64(&provider, Some("fixture:missing"))
        .expect_err("unknown bundle anchor must fail closed");

    assert_eq!(resolved, trust_pub_b64);
    assert_eq!(unknown, "SDK_ERR_TRUST_ANCHOR_NOT_FOUND");
}

#[test]
fn trust_anchor_bundle_rejects_ambiguous_or_invalid_material() {
    let trust_pub_b64 = trusted_pub_b64();
    let duplicate_bundle = format!(
        r#"{{
            "bundle_v": 1,
            "anchors": [
                {{"id": "fixture:primary", "trust_pub_b64": "{trust_pub_b64}"}},
                {{"id": "fixture:primary", "trust_pub_b64": "{trust_pub_b64}"}}
            ]
        }}"#
    );
    let malformed_bundle = r#"{
        "bundle_v": 1,
        "anchors": [
            {"id": "fixture:primary", "trust_pub_b64": "not base64"}
        ]
    }"#;

    assert_eq!(
        StaticTrustProvider::from_bundle_json(&duplicate_bundle).expect_err("duplicates reject"),
        "SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID"
    );
    assert_eq!(
        StaticTrustProvider::from_bundle_json(malformed_bundle).expect_err("bad trust rejects"),
        "SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID"
    );
}
