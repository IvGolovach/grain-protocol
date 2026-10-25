use base64::{engine::general_purpose::STANDARD, Engine};
use ed25519_dalek::{Signer, SigningKey};
use grain_client_core::{FfiSignedFoodResult, GrainSignedFoodJournal};
use grain_core::cbor::{encode_canonical, CborValue as C};
use serde_json::{json, Value};

fn ctext(value: &str) -> C {
    C::Text(value.as_bytes().to_vec())
}
fn cmap(values: Vec<(&str, C)>) -> C {
    C::Map(
        values
            .into_iter()
            .map(|(key, value)| (ctext(key), value))
            .collect(),
    )
}
fn encoded(value: &C) -> Vec<u8> {
    let mut bytes = Vec::new();
    encode_canonical(value, &mut bytes);
    bytes
}
fn signed_payload(key: &SigningKey, payload: Vec<u8>) -> String {
    use sha2::{Digest, Sha256};
    let kid = Sha256::digest(key.verifying_key().as_bytes())[..16].to_vec();
    let protected = encoded(&C::Map(vec![
        (C::Unsigned(1), C::Negative(-19)),
        (C::Unsigned(4), C::Bytes(kid)),
    ]));
    let message = encoded(&C::Array(vec![
        ctext("Signature1"),
        C::Bytes(protected.clone()),
        C::Bytes(vec![]),
        C::Bytes(payload.clone()),
    ]));
    STANDARD.encode(encoded(&C::Array(vec![
        C::Bytes(protected),
        C::Map(vec![]),
        C::Bytes(payload),
        C::Bytes(key.sign(&message).to_bytes().to_vec()),
    ])))
}

fn non_root_grant(key: &SigningKey, target: &SigningKey) -> String {
    use sha2::{Digest, Sha256};
    let target_pub = target.verifying_key().to_bytes().to_vec();
    let body = cmap(vec![
        ("v", C::Unsigned(1)),
        ("t", ctext("DeviceKeyGrant")),
        ("ak", C::Bytes(Sha256::digest(&target_pub)[..16].to_vec())),
        ("pub", C::Bytes(target_pub)),
        ("caps", C::Array(vec![ctext("write")])),
        (
            "ext",
            cmap(vec![(
                "grain.food.operation_id",
                ctext("unauthorized-grant"),
            )]),
        ),
    ]);
    let payload = encoded(&cmap(vec![
        ("v", C::Unsigned(1)),
        ("t", ctext("DeviceKeyGrant")),
        (
            "ak",
            C::Bytes(Sha256::digest(key.verifying_key().as_bytes())[..16].to_vec()),
        ),
        ("seq", C::Unsigned(1)),
        ("body", body),
    ]));
    signed_payload(key, payload)
}

fn key(seed: u8) -> SigningKey {
    SigningKey::from_bytes(&[seed; 32])
}
fn public(key: &SigningKey) -> String {
    STANDARD.encode(key.verifying_key().as_bytes())
}
fn complete(
    journal: &GrainSignedFoodJournal,
    key: &SigningKey,
    prepared: FfiSignedFoodResult,
) -> FfiSignedFoodResult {
    assert_eq!(prepared.status, "Prepared", "{:?}", prepared.diag);
    let signature = key.sign(
        &STANDARD
            .decode(prepared.signing_bytes_b64.unwrap())
            .unwrap(),
    );
    let result = journal.commit_signature(
        prepared.operation_id.unwrap(),
        STANDARD.encode(signature.to_bytes()),
    );
    assert_eq!(result.status, "Committed", "{:?}", result.diag);
    result
}
fn journal(key: &SigningKey) -> GrainSignedFoodJournal {
    let journal = GrainSignedFoodJournal::new();
    complete(&journal, key, journal.initialize(public(key)));
    journal
}
fn intake(
    journal: &GrainSignedFoodJournal,
    key: &SigningKey,
    id: &str,
    kcal: i64,
) -> FfiSignedFoodResult {
    journal.prepare_intake(public(key), id.into(), "estimated".into(), kcal, 4)
}
fn snapshot(journal: &GrainSignedFoodJournal) -> String {
    journal.export_snapshot().snapshot_b64.unwrap()
}
fn transfer(journal: &GrainSignedFoodJournal) -> String {
    journal.export_transfer().transfer_json.unwrap()
}

#[test]
fn preparation_survives_restart_and_committed_retry_does_not_allocate_again() {
    let root = key(41);
    let first = journal(&root);
    let prepared = intake(&first, &root, "meal-1", 700);
    let signing_bytes = prepared.signing_bytes_b64.clone();
    let restarted = GrainSignedFoodJournal::new();
    assert_eq!(
        restarted
            .restore_snapshot(prepared.snapshot_b64.unwrap(), public(&root))
            .status,
        "Restored"
    );
    let retry = intake(&restarted, &root, "meal-1", 700);
    assert!(retry.signing_bytes_b64 == signing_bytes);
    let committed = complete(&restarted, &root, retry);
    assert_eq!(
        (
            committed.seq,
            committed.sum_mean_kcal,
            committed.sum_var_kcal
        ),
        (Some(1), Some(700), Some(4))
    );
    let before = snapshot(&restarted);
    assert_eq!(
        intake(&restarted, &root, "meal-1", 700).status,
        "AlreadyCommitted"
    );
    assert_eq!(
        intake(&restarted, &root, "meal-1", 701).diag,
        ["SDK_ERR_SIGNED_FOOD_OPERATION_CONFLICT"]
    );
    assert!(snapshot(&restarted) == before);
    assert_eq!(
        complete(&restarted, &root, intake(&restarted, &root, "meal-2", 100)).seq,
        Some(2)
    );
}

#[test]
fn public_transfer_is_verified_deduplicated_and_read_only() {
    let root = key(42);
    let writer = journal(&root);
    complete(&writer, &root, intake(&writer, &root, "meal-1", 700));
    let exported = transfer(&writer);
    let mut shuffled: Value = serde_json::from_str(&exported).unwrap();
    shuffled["events"].as_array_mut().unwrap().reverse();
    let reader = GrainSignedFoodJournal::new();
    let imported = reader.import_transfer(shuffled.to_string(), public(&root));
    assert_eq!(imported.status, "Imported", "{:?}", imported.diag);
    assert_eq!(
        (imported.event_count, imported.sum_mean_kcal),
        (2, Some(700))
    );
    assert!(transfer(&reader) == exported);
    let before = snapshot(&reader);
    assert_eq!(
        reader.import_transfer(exported, public(&root)).event_count,
        2
    );
    assert!(snapshot(&reader) == before);
    assert_eq!(
        intake(&reader, &root, "meal-2", 1).diag,
        ["SDK_ERR_SIGNED_FOOD_READ_ONLY"]
    );
}

#[test]
fn invalid_signer_and_conflicting_retry_preserve_the_persisted_reservation() {
    let root = key(43);
    let writer = journal(&root);
    let prepared = intake(&writer, &root, "meal-1", 700);
    let before = snapshot(&writer);
    let wrong = key(99).sign(
        &STANDARD
            .decode(prepared.signing_bytes_b64.clone().unwrap())
            .unwrap(),
    );
    assert_eq!(
        writer
            .commit_signature("meal-1".into(), STANDARD.encode(wrong.to_bytes()))
            .status,
        "Rejected"
    );
    assert_eq!(
        intake(&writer, &root, "meal-2", 200).diag,
        ["SDK_ERR_SIGNED_FOOD_PENDING"]
    );
    assert_eq!(
        intake(&writer, &root, "meal-1", 701).diag,
        ["SDK_ERR_SIGNED_FOOD_PENDING"]
    );
    assert!(snapshot(&writer) == before);
    assert_eq!(
        complete(&writer, &root, intake(&writer, &root, "meal-1", 700)).seq,
        Some(1)
    );
}

#[test]
fn device_revoke_is_retroactive_and_blocks_future_preparation() {
    let root = key(44);
    let device = key(45);
    let writer = journal(&root);
    complete(
        &writer,
        &root,
        writer.prepare_grant("grant-1".into(), public(&device)),
    );
    complete(
        &writer,
        &device,
        intake(&writer, &device, "device-meal", 700),
    );
    complete(&writer, &root, intake(&writer, &root, "root-meal", 100));
    let revoked = complete(
        &writer,
        &root,
        writer.prepare_revoke("revoke-1".into(), public(&device)),
    );
    assert_eq!(revoked.sum_mean_kcal, Some(100));
    assert!(revoked.diag.iter().any(|diag| diag == "AK_REVOKED"));
    assert_eq!(
        intake(&writer, &device, "device-meal-2", 1).diag,
        ["SDK_ERR_UNAUTHORIZED_AK"]
    );
    let reader = GrainSignedFoodJournal::new();
    assert_eq!(
        reader
            .import_transfer(transfer(&writer), public(&root))
            .sum_mean_kcal,
        Some(100)
    );
}

#[test]
fn old_snapshot_retains_known_history_counters_and_pending_bytes() {
    let root = key(46);
    let writer = journal(&root);
    let old = snapshot(&writer);
    complete(&writer, &root, intake(&writer, &root, "meal-1", 100));
    let pending = intake(&writer, &root, "meal-2", 200);
    let bytes = pending.signing_bytes_b64;
    let restored = writer.restore_snapshot(old, public(&root));
    assert_eq!(restored.status, "Restored", "{:?}", restored.diag);
    assert_eq!(restored.sum_mean_kcal, Some(100));
    let retry = intake(&writer, &root, "meal-2", 200);
    assert!(retry.signing_bytes_b64 == bytes);
    assert_eq!(complete(&writer, &root, retry).seq, Some(2));
}

#[test]
fn valid_sequence_conflicts_ignore_all_and_continue_above_high_water() {
    let root = key(47);
    let left = journal(&root);
    let right = GrainSignedFoodJournal::new();
    assert_eq!(
        right
            .restore_snapshot(snapshot(&left), public(&root))
            .status,
        "Restored"
    );
    complete(&left, &root, intake(&left, &root, "left-meal", 100));
    complete(&right, &root, intake(&right, &root, "right-meal", 200));
    let merged = left.import_transfer(transfer(&right), public(&root));
    assert_eq!(merged.status, "Imported");
    assert_eq!(merged.sum_mean_kcal, Some(0));
    assert!(merged.diag.iter().any(|diag| diag == "SEQ_CONFLICT"));
    let next = complete(&left, &root, intake(&left, &root, "next-meal", 300));
    assert_eq!((next.seq, next.sum_mean_kcal), (Some(2), Some(300)));
}

#[test]
fn tampered_bundle_wrong_trust_and_legacy_identity_reject_without_mutation() {
    let root = key(48);
    let writer = journal(&root);
    complete(&writer, &root, intake(&writer, &root, "meal-1", 700));
    let before = snapshot(&writer);
    let exported = transfer(&writer);
    let mut bad: Value = serde_json::from_str(&exported).unwrap();
    let mut cose = STANDARD.decode(bad["events"][0].as_str().unwrap()).unwrap();
    let last = cose.len() - 1;
    cose[last] ^= 1;
    bad["events"][0] = json!(STANDARD.encode(cose));
    assert_eq!(
        writer
            .import_transfer(bad.to_string(), public(&root))
            .status,
        "Rejected"
    );
    assert_eq!(
        writer.import_transfer(exported, public(&key(49))).status,
        "Rejected"
    );
    let legacy_store = grain_client_core::GrainClientMemoryStore::new();
    legacy_store.create_root_identity("legacy".into());
    let legacy = legacy_store.export_identity_bundle();
    assert_eq!(
        writer
            .restore_snapshot(legacy.bundle_b64.unwrap(), public(&root))
            .status,
        "Rejected"
    );
    assert!(snapshot(&writer) == before);
}

#[test]
fn exhausted_or_corrupted_private_state_rejects_without_recycling_sequences() {
    let root = key(50);
    let writer = journal(&root);
    let saved = snapshot(&writer);
    let mut state: Value = serde_json::from_slice(&STANDARD.decode(&saved).unwrap()).unwrap();
    for value in state["counters"].as_object_mut().unwrap().values_mut() {
        *value = json!(i64::MAX);
    }
    assert_eq!(
        writer
            .restore_snapshot(STANDARD.encode(state.to_string()), public(&root))
            .status,
        "Restored"
    );
    assert_eq!(
        intake(&writer, &root, "meal-1", 1).diag,
        ["SDK_ERR_SIGNED_FOOD_SEQUENCE"]
    );
    let before = snapshot(&writer);
    state["snapshot_v"] = json!(2);
    assert_eq!(
        writer
            .restore_snapshot(STANDARD.encode(state.to_string()), public(&root))
            .status,
        "Rejected"
    );
    assert!(snapshot(&writer) == before);
}

#[test]
fn debug_does_not_reveal_signing_snapshot_or_food_payloads() {
    let root = key(51);
    let writer = journal(&root);
    let result = intake(&writer, &root, "meal-private", 777);
    let debug = format!("{result:?}");
    assert!(!debug.contains(result.snapshot_b64.as_ref().unwrap()));
    assert!(!debug.contains(result.signing_bytes_b64.as_ref().unwrap()));
    assert!(!debug.contains("meal-private"));
}

#[test]
fn overflowing_intake_rejects_before_reserving_or_signing() {
    let root = key(52);
    let writer = journal(&root);
    complete(
        &writer,
        &root,
        writer.prepare_intake(
            public(&root),
            "maximum".into(),
            "measured".into(),
            i64::MAX,
            0,
        ),
    );
    let before = snapshot(&writer);
    assert_eq!(intake(&writer, &root, "overflow", 1).status, "Rejected");
    assert_eq!(snapshot(&writer), before);
    let valid = complete(
        &writer,
        &root,
        writer.prepare_intake(public(&root), "zero".into(), "measured".into(), 0, 0),
    );
    assert_eq!(valid.seq, Some(2));
}

#[test]
fn independent_verifier_corpus_matches_writer() {
    let root = key(53);
    let device = key(54);
    let mut cases = Vec::new();
    let mut capture = |name: &str,
                       writer: &GrainSignedFoodJournal,
                       mean: i64,
                       variance: i64,
                       diagnostics: Vec<&str>| {
        let exported = writer.export_transfer();
        assert_eq!(exported.sum_mean_kcal, Some(mean));
        assert_eq!(exported.sum_var_kcal, Some(variance));
        assert_eq!(exported.diag, diagnostics);
        let value: Value = serde_json::from_str(exported.transfer_json.as_ref().unwrap()).unwrap();
        let mut payload_cids = value["events"]
            .as_array()
            .unwrap()
            .iter()
            .map(|event| {
                let bytes = STANDARD.decode(event.as_str().unwrap()).unwrap();
                let C::Array(envelope) = grain_core::cbor::parse_exact_to_error(
                    &bytes,
                    grain_core::cbor::ParseOptions::generic_cbor_canonical(),
                )
                .unwrap() else {
                    panic!("test envelope")
                };
                grain_core::cid::derive_cid_v1_dag_cbor_sha256(envelope[2].as_bytes().unwrap())
                    .unwrap()
            })
            .collect::<Vec<_>>();
        payload_cids.sort();
        cases.push(json!({"name":name, "trustedRootPubB64":public(&root),
            "transfer":value, "payloadCids":payload_cids,
            "expected":{"eventCount":exported.event_count,"sumMeanKcal":mean,"sumVarKcal":variance,"diagnostics":diagnostics}}));
    };
    let writer = journal(&root);
    let base = snapshot(&writer);
    complete(
        &writer,
        &root,
        intake(&writer, &root, "confirmed-meal", 700),
    );
    capture("confirmed", &writer, 700, 4, vec![]);
    complete(
        &writer,
        &root,
        writer.prepare_grant("grant-device".into(), public(&device)),
    );
    complete(
        &writer,
        &device,
        intake(&writer, &device, "device-meal", 300),
    );
    complete(
        &writer,
        &root,
        writer.prepare_revoke("revoke-device".into(), public(&device)),
    );
    capture("revoked", &writer, 700, 4, vec!["AK_REVOKED"]);
    let delegated = journal(&root);
    complete(
        &delegated,
        &root,
        delegated.prepare_grant("root-grant".into(), public(&device)),
    );
    let mut imported: Value = serde_json::from_str(&transfer(&delegated)).unwrap();
    imported["events"]
        .as_array_mut()
        .unwrap()
        .push(json!(non_root_grant(&device, &key(55))));
    assert_eq!(
        delegated
            .import_transfer(imported.to_string(), public(&root))
            .status,
        "Imported"
    );
    assert_eq!(
        intake(&delegated, &key(55), "unauthorized-meal", 100).diag,
        ["SDK_ERR_UNAUTHORIZED_AK"]
    );
    capture(
        "non-root-grant",
        &delegated,
        0,
        0,
        vec!["UNAUTHORIZED_GRANT_IGNORED"],
    );
    let left = GrainSignedFoodJournal::new();
    let right = GrainSignedFoodJournal::new();
    assert_eq!(
        left.restore_snapshot(base.clone(), public(&root)).status,
        "Restored"
    );
    assert_eq!(
        right.restore_snapshot(base.clone(), public(&root)).status,
        "Restored"
    );
    complete(&left, &root, intake(&left, &root, "left", 100));
    complete(&right, &root, intake(&right, &root, "right", 200));
    assert_eq!(
        left.import_transfer(transfer(&right), public(&root)).status,
        "Imported"
    );
    capture("conflicted", &left, 0, 0, vec!["SEQ_CONFLICT"]);
    let high = GrainSignedFoodJournal::new();
    let mut state: Value = serde_json::from_slice(&STANDARD.decode(base).unwrap()).unwrap();
    for value in state["counters"].as_object_mut().unwrap().values_mut() {
        *value = json!(9_007_199_254_740_991_u64);
    }
    assert_eq!(
        high.restore_snapshot(STANDARD.encode(state.to_string()), public(&root))
            .status,
        "Restored"
    );
    complete(
        &high,
        &root,
        intake(&high, &root, "exact-large-sequence-first", 200),
    );
    let big = complete(
        &high,
        &root,
        intake(&high, &root, "exact-large-sequence", 200),
    );
    assert_eq!(big.seq, Some(9_007_199_254_740_993));
    capture("exact-u63", &high, 400, 8, vec![]);
    let actual = serde_json::to_string_pretty(&cases).unwrap() + "\n";
    if let Ok(path) = std::env::var("GRAIN_SIGNED_FOOD_FIXTURE_OUTPUT") {
        std::fs::write(path, actual).unwrap();
    } else {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../sdk/workflows/signed-food/v1.json");
        assert_eq!(
            std::fs::read_to_string(path).unwrap(),
            actual,
            "signed food fixture drift"
        );
    }
}

#[test]
fn correctly_signed_but_mismatched_profile_rejects_without_mutation() {
    let root = key(56);
    let writer = journal(&root);
    complete(&writer, &root, intake(&writer, &root, "meal", 700));
    let before = snapshot(&writer);
    let mut bundle: Value = serde_json::from_str(&transfer(&writer)).unwrap();
    for item in bundle["events"].as_array_mut().unwrap() {
        let cose = STANDARD.decode(item.as_str().unwrap()).unwrap();
        let verified = grain_core::cose::verify_cose_sign1_payload(
            &cose,
            root.verifying_key().as_bytes(),
            &[],
        )
        .unwrap();
        let mut payload =
            grain_core::typed_object::validate_typed_object_v1(&verified.payload, "LedgerEvent")
                .unwrap();
        if payload.map_get("t").unwrap().as_text().unwrap() != "IntakeEvent" {
            continue;
        }
        fn field_mut<'a>(node: &'a mut C, key: &str) -> &'a mut C {
            let C::Map(fields) = node else {
                panic!("test map")
            };
            &mut fields
                .iter_mut()
                .find(|(k, _)| k.as_text().as_deref() == Some(key))
                .unwrap()
                .1
        }
        *field_mut(field_mut(field_mut(&mut payload, "body"), "mean"), "kcal") = C::Unsigned(701);
        *item = json!(signed_payload(&root, encoded(&payload)));
    }
    assert_eq!(
        writer
            .import_transfer(bundle.to_string(), public(&root))
            .status,
        "Rejected"
    );
    assert_eq!(snapshot(&writer), before);
}

#[test]
fn duplicate_json_fields_and_invalid_pending_state_reject_atomically() {
    let root = key(57);
    let writer = journal(&root);
    let before = snapshot(&writer);
    let duplicate =
        transfer(&writer).replacen("\"bundle_v\":1", "\"bundle_v\":1,\"bundle_v\":1", 1);
    assert_eq!(
        writer.import_transfer(duplicate, public(&root)).status,
        "Rejected"
    );
    let pending = intake(&writer, &root, "reserved", 100);
    let reserved = snapshot(&writer);
    let mut state: Value =
        serde_json::from_slice(&STANDARD.decode(pending.snapshot_b64.unwrap()).unwrap()).unwrap();
    state["pending"]["seq"] = json!(2);
    assert_eq!(
        writer
            .restore_snapshot(STANDARD.encode(state.to_string()), public(&root))
            .status,
        "Rejected"
    );
    assert_eq!(snapshot(&writer), reserved);
    let mut missing_profile: Value =
        serde_json::from_slice(&STANDARD.decode(&reserved).unwrap()).unwrap();
    missing_profile["pending"]["objects"] = json!({});
    assert_eq!(
        writer
            .restore_snapshot(STANDARD.encode(missing_profile.to_string()), public(&root))
            .status,
        "Rejected"
    );
    assert_eq!(snapshot(&writer), reserved);
    assert_ne!(reserved, before);
}
