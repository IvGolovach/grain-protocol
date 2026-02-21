use grain_core::ledger::{reduce_ledger, LedgerEvent};
use grain_core::manifest::{resolve_manifest, ManifestRecord, ManifestResolveInput};
use proptest::prelude::*;
use serde_json::json;

fn permute_in_place<T>(items: &mut [T], seed: u64) {
    if items.is_empty() {
        return;
    }
    let shift = (seed as usize) % items.len();
    items.rotate_left(shift);
    if seed & 1 == 1 {
        items.reverse();
    }
}

fn baseline_events() -> Vec<LedgerEvent> {
    vec![
        LedgerEvent {
            t: "DeviceKeyGrant".to_string(),
            ak: "root".to_string(),
            seq: 1,
            payload_cid: "cid-grant-dev1".to_string(),
            body: json!({"grant_ak":"dev1"}),
        },
        LedgerEvent {
            t: "IntakeEvent".to_string(),
            ak: "dev1".to_string(),
            seq: 1,
            payload_cid: "cid-intake-a".to_string(),
            body: json!({"mean":{"kcal":120},"var":{"kcal":9}}),
        },
        LedgerEvent {
            t: "IntakeEvent".to_string(),
            ak: "dev1".to_string(),
            seq: 2,
            payload_cid: "cid-intake-b".to_string(),
            body: json!({"mean":{"kcal":80},"var":{"kcal":4}}),
        },
    ]
}

fn baseline_manifest_input() -> ManifestResolveInput {
    ManifestResolveInput {
        eligible_records: vec![
            ManifestRecord {
                op: "put".to_string(),
                cap_id: Some(vec![0x02; 32]),
                chash: Some(vec![0x22; 32]),
            },
            ManifestRecord {
                op: "put".to_string(),
                cap_id: Some(vec![0x01; 32]),
                chash: Some(vec![0x11; 32]),
            },
            ManifestRecord {
                op: "put".to_string(),
                cap_id: Some(vec![0x03; 32]),
                chash: Some(vec![0x33; 32]),
            },
            ManifestRecord {
                op: "put".to_string(),
                cap_id: Some(vec![0x03; 32]),
                chash: Some(vec![0x44; 32]),
            },
        ],
        eligible_tombstones: vec![],
        ineligible_records: vec![],
        ineligible_tombstones: vec![],
    }
}

proptest! {
    #[test]
    fn reducer_order_independent(seed in any::<u64>()) {
        let expected = reduce_ledger("root", &baseline_events()).unwrap();

        let mut events = baseline_events();
        permute_in_place(&mut events, seed);
        let got = reduce_ledger("root", &events).unwrap();

        prop_assert_eq!(got.sum_mean, expected.sum_mean);
        prop_assert_eq!(got.sum_var, expected.sum_var);
    }

    #[test]
    fn reducer_idempotent(seed in any::<u64>()) {
        let expected = reduce_ledger("root", &baseline_events()).unwrap();

        let mut duplicated = baseline_events();
        duplicated.extend(baseline_events());
        permute_in_place(&mut duplicated, seed);

        let got = reduce_ledger("root", &duplicated).unwrap();

        prop_assert_eq!(got.sum_mean, expected.sum_mean);
        prop_assert_eq!(got.sum_var, expected.sum_var);
    }

    #[test]
    fn manifest_resolution_order_independent(seed in any::<u64>()) {
        let expected = resolve_manifest(baseline_manifest_input()).unwrap();

        let mut input = baseline_manifest_input();
        permute_in_place(&mut input.eligible_records, seed);
        let got = resolve_manifest(input).unwrap();

        prop_assert_eq!(got.status_unresolvable, expected.status_unresolvable);
        prop_assert_eq!(got.cap_id, expected.cap_id);
        prop_assert_eq!(got.diagnostics, expected.diagnostics);
    }
}
