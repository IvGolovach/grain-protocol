use std::collections::{BTreeMap, BTreeSet};

use crate::error::{Diag, GrainError, GrainResult};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestRecord {
    pub op: String,
    pub cap_id: Option<Vec<u8>>,
    pub chash: Option<Vec<u8>>,
}

#[derive(Debug, Clone)]
pub struct ManifestResolveInput {
    pub eligible_records: Vec<ManifestRecord>,
    pub eligible_tombstones: Vec<ManifestRecord>,
    pub ineligible_records: Vec<ManifestRecord>,
    pub ineligible_tombstones: Vec<ManifestRecord>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestResolveOutput {
    pub cap_id: Option<Vec<u8>>,
    pub status_unresolvable: bool,
    pub diagnostics: Vec<Diag>,
}

pub fn resolve_manifest(input: ManifestResolveInput) -> GrainResult<ManifestResolveOutput> {
    for rec in input
        .eligible_records
        .iter()
        .chain(input.eligible_tombstones.iter())
        .chain(input.ineligible_records.iter())
        .chain(input.ineligible_tombstones.iter())
    {
        validate_record_shape(rec)?;
    }

    if !input.eligible_tombstones.is_empty() {
        return Ok(ManifestResolveOutput {
            cap_id: None,
            status_unresolvable: true,
            diagnostics: Vec::new(),
        });
    }

    let mut put_records: Vec<ManifestRecord> = input
        .eligible_records
        .into_iter()
        .filter(|r| r.op == "put")
        .collect();

    let mut cap_to_chash: BTreeMap<Vec<u8>, BTreeSet<Vec<u8>>> = BTreeMap::new();
    for rec in &put_records {
        let cap = rec.cap_id.clone().unwrap_or_default();
        let chash = rec.chash.clone().unwrap_or_default();
        cap_to_chash.entry(cap).or_default().insert(chash);
    }

    let conflicted_caps: BTreeSet<Vec<u8>> = cap_to_chash
        .iter()
        .filter_map(|(cap, chashes)| if chashes.len() > 1 { Some(cap.clone()) } else { None })
        .collect();

    let mut diagnostics = Vec::new();
    if !conflicted_caps.is_empty() {
        diagnostics.push(Diag::CapChashConflict);
        put_records.retain(|r| !conflicted_caps.contains(&r.cap_id.clone().unwrap_or_default()));
    }

    if put_records.is_empty() {
        return Ok(ManifestResolveOutput {
            cap_id: None,
            status_unresolvable: true,
            diagnostics,
        });
    }

    let mut min_cap: Option<Vec<u8>> = None;
    for rec in put_records {
        let cap = rec.cap_id.unwrap_or_default();
        match &min_cap {
            None => min_cap = Some(cap),
            Some(cur) => {
                if cap < *cur {
                    min_cap = Some(cap);
                }
            }
        }
    }

    Ok(ManifestResolveOutput {
        cap_id: min_cap,
        status_unresolvable: false,
        diagnostics,
    })
}

fn validate_record_shape(rec: &ManifestRecord) -> GrainResult<()> {
    match rec.op.as_str() {
        "put" => {
            if rec.cap_id.is_none() || rec.chash.is_none() {
                return Err(GrainError::from_diag(Diag::ManifestOp));
            }
        }
        "del" => {
            if rec.cap_id.is_some() || rec.chash.is_some() {
                return Err(GrainError::from_diag(Diag::ManifestOp));
            }
        }
        _ => return Err(GrainError::from_diag(Diag::ManifestOp)),
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(op: &str, cap_id: Option<&[u8]>, chash: Option<&[u8]>) -> ManifestRecord {
        ManifestRecord {
            op: op.to_string(),
            cap_id: cap_id.map(|v| v.to_vec()),
            chash: chash.map(|v| v.to_vec()),
        }
    }

    #[test]
    fn selects_lowest_cap_id_among_eligible_puts() {
        let out = resolve_manifest(ManifestResolveInput {
            eligible_records: vec![
                record("put", Some(&[0x02]), Some(&[0x10])),
                record("put", Some(&[0x01]), Some(&[0x10])),
            ],
            eligible_tombstones: vec![],
            ineligible_records: vec![],
            ineligible_tombstones: vec![],
        })
        .unwrap();

        assert!(!out.status_unresolvable);
        assert_eq!(out.cap_id, Some(vec![0x01]));
        assert!(out.diagnostics.is_empty());
    }

    #[test]
    fn conflicting_chash_marks_cap_conflict_and_becomes_unresolvable() {
        let out = resolve_manifest(ManifestResolveInput {
            eligible_records: vec![
                record("put", Some(&[0x01]), Some(&[0x10])),
                record("put", Some(&[0x01]), Some(&[0x11])),
            ],
            eligible_tombstones: vec![],
            ineligible_records: vec![],
            ineligible_tombstones: vec![],
        })
        .unwrap();

        assert!(out.status_unresolvable);
        assert_eq!(out.cap_id, None);
        assert_eq!(out.diagnostics, vec![Diag::CapChashConflict]);
    }

    #[test]
    fn eligible_tombstone_short_circuits_resolution() {
        let out = resolve_manifest(ManifestResolveInput {
            eligible_records: vec![record("put", Some(&[0x02]), Some(&[0x10]))],
            eligible_tombstones: vec![record("del", None, None)],
            ineligible_records: vec![],
            ineligible_tombstones: vec![],
        })
        .unwrap();

        assert!(out.status_unresolvable);
        assert_eq!(out.cap_id, None);
        assert!(out.diagnostics.is_empty());
    }
}
