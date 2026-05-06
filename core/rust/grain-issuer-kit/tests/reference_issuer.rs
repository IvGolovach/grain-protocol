use grain_client_core::{scan_accept_prepare, scan_preview, ScanAcceptStatus, ScanPreviewStatus};
use grain_core::cbor::{encode_canonical, CborValue};
use grain_issuer_kit::{sample_serving_offer_payload, Issuer};

#[test]
fn generated_reference_qr_verifies_through_client_core() {
    let issuer = Issuer::generate().expect("issuer key generation must succeed");
    let payload = sample_serving_offer_payload(issuer.issuer_kid());
    let issued = issuer
        .issue_payload(&payload)
        .expect("sample ServingOffer must issue");

    assert!(issued.qr_string.starts_with("GR1:"));
    assert_eq!(issued.trust_pub_b64, issuer.trust_pub_b64());
    assert_eq!(issued.issuer_kid_b64, issuer.issuer_kid_b64());
    assert!(!issued.trust_pub_b64.is_empty());
    assert!(!issued.cose_b64.is_empty());

    let preview = scan_preview(&issued.qr_string, Some(&issued.trust_pub_b64));
    assert_eq!(preview.status, ScanPreviewStatus::Verified);
    assert!(preview.diag.is_empty());
    assert_eq!(preview.cose_b64, Some(issued.cose_b64.clone()));

    let accepted = scan_accept_prepare(&issued.qr_string, Some(&issued.trust_pub_b64));
    assert_eq!(accepted.status, ScanAcceptStatus::Accepted);
    assert!(accepted.diag.is_empty());
    assert!(accepted.accepted.is_some());
}

#[test]
fn generated_reference_qr_rejects_under_wrong_trust() {
    let issuer = Issuer::generate().expect("issuer key generation must succeed");
    let wrong_issuer = Issuer::generate().expect("wrong issuer key generation must succeed");
    let payload = sample_serving_offer_payload(issuer.issuer_kid());
    let issued = issuer
        .issue_payload(&payload)
        .expect("sample ServingOffer must issue");

    assert_ne!(issued.trust_pub_b64, wrong_issuer.trust_pub_b64());

    let preview = scan_preview(&issued.qr_string, Some(&wrong_issuer.trust_pub_b64()));
    assert_eq!(preview.status, ScanPreviewStatus::Rejected);
    assert_eq!(preview.diag, vec!["GRAIN_ERR_COSE_PROFILE"]);
    assert_eq!(preview.cose_b64, Some(issued.cose_b64));

    let accepted = scan_accept_prepare(&issued.qr_string, Some(&wrong_issuer.trust_pub_b64()));
    assert_eq!(accepted.status, ScanAcceptStatus::Rejected);
    assert_eq!(accepted.diag, vec!["GRAIN_ERR_COSE_PROFILE"]);
    assert!(accepted.accepted.is_none());
}

#[test]
fn issuer_rejects_non_dag_cbor_payloads_before_signing() {
    let issuer = Issuer::generate().expect("issuer key generation must succeed");

    let err = issuer
        .issue_payload(b"not canonical dag-cbor")
        .expect_err("issuer must reject invalid payloads");

    assert!(err.to_string().contains("strict DAG-CBOR"));
}

#[test]
fn issuer_rejects_strict_dag_cbor_that_is_not_serving_offer() {
    let issuer = Issuer::generate().expect("issuer key generation must succeed");
    let mut payload = Vec::new();
    encode_canonical(
        &CborValue::Map(vec![
            (CborValue::Text(b"v".to_vec()), CborValue::Unsigned(1)),
            (
                CborValue::Text(b"t".to_vec()),
                CborValue::Text(b"IngredientRef".to_vec()),
            ),
            (
                CborValue::Text(b"ref_type".to_vec()),
                CborValue::Text(b"example".to_vec()),
            ),
            (
                CborValue::Text(b"ref_id".to_vec()),
                CborValue::Text(b"ingredient-1".to_vec()),
            ),
        ]),
        &mut payload,
    );

    let err = issuer
        .issue_payload(&payload)
        .expect_err("issuer must only sign ServingOffer QR payloads");

    assert!(err.to_string().contains("ServingOffer"));
}

#[test]
fn issuer_rejects_serving_offer_with_mismatched_issuer_kid() {
    let issuer = Issuer::generate().expect("issuer key generation must succeed");
    let wrong_issuer = Issuer::generate().expect("wrong issuer key generation must succeed");
    let payload = sample_serving_offer_payload(wrong_issuer.issuer_kid());

    let err = issuer
        .issue_payload(&payload)
        .expect_err("issuer must not sign a ServingOffer for another kid");

    assert!(err.to_string().contains("issuer_kid"));
}
