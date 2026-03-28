use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::error::{Diag, GrainError, GrainResult};

#[derive(Debug, Clone, Deserialize)]
pub struct LedgerEvent {
    pub t: String,
    pub ak: String,
    pub seq: u64,
    pub payload_cid: String,
    pub body: Value,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct LedgerTotals {
    pub sum_mean: BTreeMap<String, i64>,
    pub sum_var: BTreeMap<String, i64>,
    pub diag_contains: Vec<String>,
}

pub fn reduce_ledger(root_kid: &str, events: &[LedgerEvent]) -> GrainResult<LedgerTotals> {
    let mut diagnostics: BTreeSet<Diag> = BTreeSet::new();

    let mut grants: BTreeSet<String> = BTreeSet::new();
    let mut revokes: BTreeSet<String> = BTreeSet::new();

    for ev in events {
        match ev.t.as_str() {
            "DeviceKeyGrant" => {
                if ev.ak == root_kid {
                    if let Some(grant_ak) = ev.body.get("grant_ak").and_then(Value::as_str) {
                        grants.insert(grant_ak.to_string());
                    }
                } else {
                    diagnostics.insert(Diag::UnauthorizedGrantIgnored);
                }
            }
            "DeviceKeyRevoke" => {
                if ev.ak == root_kid {
                    if let Some(revoke_ak) = ev.body.get("revoke_ak").and_then(Value::as_str) {
                        revokes.insert(revoke_ak.to_string());
                    }
                } else {
                    diagnostics.insert(Diag::UnauthorizedGrantIgnored);
                }
            }
            _ => {}
        }
    }

    let is_authorized = |ak: &str| -> bool {
        if ak == root_kid {
            return true;
        }
        grants.contains(ak) && !revokes.contains(ak)
    };

    let mut authorized_events: Vec<&LedgerEvent> = Vec::new();
    for ev in events {
        if !is_authorized(&ev.ak) {
            if revokes.contains(&ev.ak) {
                diagnostics.insert(Diag::AkRevoked);
            }
            continue;
        }
        authorized_events.push(ev);
    }

    let mut pair_payloads: BTreeMap<(String, u64), BTreeSet<String>> = BTreeMap::new();
    for ev in &authorized_events {
        pair_payloads
            .entry((ev.ak.clone(), ev.seq))
            .or_default()
            .insert(ev.payload_cid.clone());
    }

    let conflicted: BTreeSet<(String, u64)> = pair_payloads
        .iter()
        .filter_map(|(k, payloads)| if payloads.len() > 1 { Some(k.clone()) } else { None })
        .collect();

    if !conflicted.is_empty() {
        diagnostics.insert(Diag::SeqConflict);
    }

    let mut sum_mean: i128 = 0;
    let mut sum_var: i128 = 0;

    let mut seen_exact: BTreeSet<(String, u64, String)> = BTreeSet::new();

    for ev in authorized_events {
        if conflicted.contains(&(ev.ak.clone(), ev.seq)) {
            continue;
        }
        if !seen_exact.insert((ev.ak.clone(), ev.seq, ev.payload_cid.clone())) {
            // set-union semantics: exact duplicates are idempotent
            continue;
        }
        if ev.t != "IntakeEvent" {
            continue;
        }

        let mean_kcal = ev
            .body
            .get("mean")
            .and_then(|m| m.get("kcal"))
            .and_then(Value::as_i64)
            .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

        let var_kcal = ev
            .body
            .get("var")
            .and_then(|m| m.get("kcal"))
            .and_then(Value::as_i64)
            .ok_or_else(|| GrainError::from_diag(Diag::Schema))?;

        if var_kcal < 0 {
            return Err(GrainError::from_diag(Diag::Schema));
        }

        sum_mean += mean_kcal as i128;
        sum_var += var_kcal as i128;
    }

    if sum_mean > i64::MAX as i128 || sum_mean < i64::MIN as i128 {
        return Err(GrainError::from_diag(Diag::Overflow));
    }
    if sum_var > i64::MAX as i128 || sum_var < 0 {
        return Err(GrainError::from_diag(Diag::Overflow));
    }

    let mut out_mean = BTreeMap::new();
    out_mean.insert("kcal".to_string(), sum_mean as i64);

    let mut out_var = BTreeMap::new();
    out_var.insert("kcal".to_string(), sum_var as i64);

    let diag_contains = diagnostics.into_iter().map(|d| d.code().to_string()).collect();

    Ok(LedgerTotals {
        sum_mean: out_mean,
        sum_var: out_var,
        diag_contains,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn intake_event(ak: &str, seq: u64, payload_cid: &str, mean: i64, var: i64) -> LedgerEvent {
        LedgerEvent {
            t: "IntakeEvent".to_string(),
            ak: ak.to_string(),
            seq,
            payload_cid: payload_cid.to_string(),
            body: json!({
                "mean": { "kcal": mean },
                "var": { "kcal": var },
            }),
        }
    }

    #[test]
    fn exact_duplicate_intake_event_is_idempotent() {
        let event = intake_event("root", 1, "cid-1", 7, 3);
        let totals = reduce_ledger("root", &[event.clone(), event]).unwrap();

        assert_eq!(totals.sum_mean.get("kcal"), Some(&7));
        assert_eq!(totals.sum_var.get("kcal"), Some(&3));
        assert!(totals.diag_contains.is_empty());
    }

    #[test]
    fn conflicting_sequence_is_dropped_and_flagged() {
        let totals = reduce_ledger(
            "root",
            &[
                intake_event("root", 1, "cid-a", 7, 3),
                intake_event("root", 1, "cid-b", 9, 5),
            ],
        )
        .unwrap();

        assert_eq!(totals.sum_mean.get("kcal"), Some(&0));
        assert_eq!(totals.sum_var.get("kcal"), Some(&0));
        assert!(totals.diag_contains.contains(&Diag::SeqConflict.code().to_string()));
    }

    #[test]
    fn unauthorized_grant_is_ignored_and_authorized_events_still_reduce() {
        let totals = reduce_ledger(
            "root",
            &[
                LedgerEvent {
                    t: "DeviceKeyGrant".to_string(),
                    ak: "intruder".to_string(),
                    seq: 1,
                    payload_cid: "grant-cid".to_string(),
                    body: json!({ "grant_ak": "kid-1" }),
                },
                intake_event("root", 2, "cid-1", 7, 3),
            ],
        )
        .unwrap();

        assert_eq!(totals.sum_mean.get("kcal"), Some(&7));
        assert_eq!(totals.sum_var.get("kcal"), Some(&3));
        assert!(totals.diag_contains.contains(&Diag::UnauthorizedGrantIgnored.code().to_string()));
    }

    #[test]
    fn revoked_authorized_events_are_flagged_and_dropped() {
        let totals = reduce_ledger(
            "root",
            &[
                LedgerEvent {
                    t: "DeviceKeyGrant".to_string(),
                    ak: "root".to_string(),
                    seq: 1,
                    payload_cid: "grant-cid".to_string(),
                    body: json!({ "grant_ak": "kid-1" }),
                },
                LedgerEvent {
                    t: "DeviceKeyRevoke".to_string(),
                    ak: "root".to_string(),
                    seq: 2,
                    payload_cid: "revoke-cid".to_string(),
                    body: json!({ "revoke_ak": "kid-1" }),
                },
                intake_event("kid-1", 3, "cid-1", 7, 3),
            ],
        )
        .unwrap();

        assert_eq!(totals.sum_mean.get("kcal"), Some(&0));
        assert_eq!(totals.sum_var.get("kcal"), Some(&0));
        assert!(totals.diag_contains.contains(&Diag::AkRevoked.code().to_string()));
    }
}
