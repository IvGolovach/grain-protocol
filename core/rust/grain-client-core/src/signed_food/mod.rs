//! Additive signed-food workflow. The host persists preparation before signing
//! and persists commit before reporting durable success.

mod wire;

use std::collections::BTreeMap;
use std::sync::Mutex;

use base64::{engine::general_purpose::STANDARD, Engine};
use grain_core::cbor::CborValue as C;
use serde::{Deserialize, Serialize};

use wire::*;

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Pending {
    author_pub_b64: String,
    operation_id: String,
    kind: String,
    seq: u64,
    payload_b64: String,
    objects: BTreeMap<String, String>,
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct State {
    snapshot_v: u32,
    transfer: Transfer,
    counters: BTreeMap<String, u64>,
    pending: Option<Pending>,
    read_only: bool,
}

/// Sensitive workflow outputs are intentionally omitted from Debug.
pub struct FfiSignedFoodResult {
    pub status: String,
    pub diag: Vec<String>,
    pub operation_id: Option<String>,
    pub seq: Option<u64>,
    pub signing_bytes_b64: Option<String>,
    pub snapshot_b64: Option<String>,
    pub transfer_json: Option<String>,
    pub sum_mean_kcal: Option<i64>,
    pub sum_var_kcal: Option<i64>,
    pub event_count: u64,
}

impl std::fmt::Debug for FfiSignedFoodResult {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FfiSignedFoodResult")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("sensitive_workflow_outputs", &"[REDACTED]")
            .finish()
    }
}

impl FfiSignedFoodResult {
    fn empty(status: &str) -> Self {
        Self {
            status: status.into(),
            diag: Vec::new(),
            operation_id: None,
            seq: None,
            signing_bytes_b64: None,
            snapshot_b64: None,
            transfer_json: None,
            sum_mean_kcal: None,
            sum_var_kcal: None,
            event_count: 0,
        }
    }
    fn rejected(diag: String) -> Self {
        let mut result = Self::empty("Rejected");
        result.diag.push(diag);
        result
    }
}

/// In-memory workflow state, paired with an application-owned durable adapter.
pub struct GrainSignedFoodJournal {
    state: Mutex<Option<State>>,
}

impl Default for GrainSignedFoodJournal {
    fn default() -> Self {
        Self::new()
    }
}

impl GrainSignedFoodJournal {
    pub fn new() -> Self {
        Self {
            state: Mutex::new(None),
        }
    }

    pub fn initialize(&self, root_pub_b64: String) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let public = public_key(&root_pub_b64)?;
            if let Some(existing) = state {
                if existing.transfer.root_pub_b64 != root_pub_b64 {
                    return Err(TRUST.into());
                }
                if existing.transfer.events.is_empty() {
                    return prepared(existing);
                }
                return result(existing, "AlreadyCommitted", None, Some(0));
            }
            let body = map(vec![
                ("v", C::Unsigned(1)),
                ("t", text("LedgerGenesis")),
                ("root_kid", C::Bytes(kid(&public))),
                ("root_pub", C::Bytes(public.clone())),
            ]);
            let candidate = State {
                snapshot_v: 1,
                transfer: Transfer {
                    bundle_v: 1,
                    root_pub_b64: root_pub_b64.clone(),
                    events: Vec::new(),
                    objects: BTreeMap::new(),
                },
                counters: BTreeMap::from([(hex(&kid(&public)), 0)]),
                read_only: false,
                pending: Some(Pending {
                    author_pub_b64: root_pub_b64,
                    operation_id: "genesis".into(),
                    kind: "LedgerGenesis".into(),
                    seq: 0,
                    payload_b64: STANDARD.encode(payload("LedgerGenesis", &public, 0, body)?),
                    objects: BTreeMap::new(),
                }),
            };
            let response = prepared(&candidate)?;
            *state = Some(candidate);
            Ok(response)
        })
    }

    pub fn prepare_intake(
        &self,
        author_pub_b64: String,
        operation_id: String,
        source_class: String,
        mean_kcal: i64,
        var_kcal: i64,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            if !["estimated", "measured"].contains(&source_class.as_str())
                || mean_kcal < 0
                || var_kcal < 0
            {
                return Err(INVALID.into());
            }
            wire::operation_id(&operation_id)?;
            let profile = encode(&map(vec![
                ("v", C::Unsigned(1)),
                ("t", text("NutrientProfile")),
                ("dataset_snapshot_id", text(&operation_id)),
                ("source", text(&source_class)),
                ("basis", text("per_serving")),
                ("nutr", map(vec![("kcal", number(mean_kcal))])),
                ("uncert", map(vec![("kcal", number(var_kcal))])),
            ]));
            typed(&profile, "NutrientProfile")?;
            let body = with_operation(
                map(vec![
                    ("v", C::Unsigned(1)),
                    ("t", text("IntakeEvent")),
                    ("source_class", text(&source_class)),
                    ("mean", map(vec![("kcal", number(mean_kcal))])),
                    ("var", map(vec![("kcal", number(var_kcal))])),
                    ("mode", text("from_profile")),
                    ("profile", link(&profile)),
                    ("servings", C::Unsigned(1)),
                ]),
                &operation_id,
            )?;
            prepare(
                state,
                &author_pub_b64,
                &operation_id,
                "IntakeEvent",
                body,
                BTreeMap::from([(cid(&profile)?, STANDARD.encode(profile))]),
            )
        })
    }

    pub fn prepare_grant(
        &self,
        operation_id: String,
        device_pub_b64: String,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let current = state.as_ref().ok_or_else(|| INVALID.to_string())?;
            let root = current.transfer.root_pub_b64.clone();
            let device = public_key(&device_pub_b64)?;
            if device_pub_b64 == root {
                return Err(TRUST.into());
            }
            let body = with_operation(
                map(vec![
                    ("v", C::Unsigned(1)),
                    ("t", text("DeviceKeyGrant")),
                    ("ak", C::Bytes(kid(&device))),
                    ("pub", C::Bytes(device)),
                    ("caps", C::Array(vec![text("write")])),
                ]),
                &operation_id,
            )?;
            prepare(
                state,
                &root,
                &operation_id,
                "DeviceKeyGrant",
                body,
                BTreeMap::new(),
            )
        })
    }

    pub fn prepare_revoke(
        &self,
        operation_id: String,
        device_pub_b64: String,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let current = state.as_ref().ok_or_else(|| INVALID.to_string())?;
            let root = current.transfer.root_pub_b64.clone();
            let device = public_key(&device_pub_b64)?;
            if device_pub_b64 == root {
                return Err(TRUST.into());
            }
            let body = with_operation(
                map(vec![
                    ("v", C::Unsigned(1)),
                    ("t", text("DeviceKeyRevoke")),
                    ("ak", C::Bytes(kid(&device))),
                ]),
                &operation_id,
            )?;
            prepare(
                state,
                &root,
                &operation_id,
                "DeviceKeyRevoke",
                body,
                BTreeMap::new(),
            )
        })
    }

    pub fn commit_signature(
        &self,
        operation_id: String,
        signature_b64: String,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let current = state.as_mut().ok_or_else(|| INVALID.to_string())?;
            let pending = current
                .pending
                .clone()
                .ok_or_else(|| "SDK_ERR_SIGNED_FOOD_PENDING".to_string())?;
            if pending.operation_id != operation_id {
                return Err("SDK_ERR_SIGNED_FOOD_PENDING".into());
            }
            let public = public_key(&pending.author_pub_b64)?;
            let bytes = decode(&pending.payload_b64)?;
            let cose = envelope(&public, &bytes, &decode(&signature_b64)?);
            current.transfer.events.push(STANDARD.encode(cose));
            merge_objects(&mut current.transfer.objects, pending.objects)?;
            let verified =
                verify_transfer(current.transfer.clone(), &current.transfer.root_pub_b64)?;
            current.transfer = verified.transfer;
            current.pending = None;
            result(current, "Committed", Some(operation_id), Some(pending.seq))
        })
    }

    pub fn export_snapshot(&self) -> FfiSignedFoodResult {
        self.mutate(|state| {
            result(
                state.as_ref().ok_or_else(|| INVALID.to_string())?,
                "Exported",
                None,
                None,
            )
        })
    }

    pub fn restore_snapshot(
        &self,
        snapshot_b64: String,
        trusted_root_pub_b64: String,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let bytes = decode(&snapshot_b64)?;
            let mut incoming: State =
                serde_json::from_slice(&bytes).map_err(|_| INVALID.to_string())?;
            validate_state(&incoming, &trusted_root_pub_b64)?;
            if let Some(current) = state {
                if current.transfer.root_pub_b64 != trusted_root_pub_b64 {
                    return Err(TRUST.into());
                }
                incoming
                    .transfer
                    .events
                    .extend(current.transfer.events.clone());
                merge_objects(
                    &mut incoming.transfer.objects,
                    current.transfer.objects.clone(),
                )?;
                for (ak, seq) in &current.counters {
                    incoming
                        .counters
                        .entry(ak.clone())
                        .and_modify(|n| *n = (*n).max(*seq))
                        .or_insert(*seq);
                }
                if current.pending.is_some() {
                    incoming.pending = current.pending.clone();
                }
                // An in-memory read-only importer cannot become a writer through merging.
                incoming.read_only |= current.read_only;
            }
            if !incoming.transfer.events.is_empty() {
                let verified = verify_transfer(incoming.transfer.clone(), &trusted_root_pub_b64)?;
                incoming.transfer = verified.transfer;
                if let Some(pending) = &incoming.pending {
                    if verified
                        .events
                        .contains_key(&cid(&decode(&pending.payload_b64)?)?)
                    {
                        incoming.pending = None;
                    }
                }
            }
            validate_state(&incoming, &trusted_root_pub_b64)?;
            let response = result(&incoming, "Restored", None, None)?;
            *state = Some(incoming);
            Ok(response)
        })
    }

    pub fn export_transfer(&self) -> FfiSignedFoodResult {
        self.mutate(|state| {
            let current = state.as_ref().ok_or_else(|| INVALID.to_string())?;
            let verified =
                verify_transfer(current.transfer.clone(), &current.transfer.root_pub_b64)?;
            let mut response = result(current, "Exported", None, None)?;
            response.transfer_json =
                Some(serde_json::to_string(&verified.transfer).map_err(|_| INVALID.to_string())?);
            Ok(response)
        })
    }

    pub fn import_transfer(
        &self,
        transfer_json: String,
        trusted_root_pub_b64: String,
    ) -> FfiSignedFoodResult {
        self.mutate(|state| {
            if transfer_json.len() > MAX_BYTES {
                return Err(LIMIT.into());
            }
            let incoming: Transfer =
                serde_json::from_str(&transfer_json).map_err(|_| INVALID.to_string())?;
            let incoming = verify_transfer(incoming, &trusted_root_pub_b64)?;
            let mut candidate = if let Some(current) = state {
                if current.transfer.root_pub_b64 != trusted_root_pub_b64 {
                    return Err(TRUST.into());
                }
                if current.pending.is_some() {
                    return Err("SDK_ERR_SIGNED_FOOD_PENDING".into());
                }
                current.clone()
            } else {
                State {
                    snapshot_v: 1,
                    transfer: incoming.transfer.clone(),
                    counters: BTreeMap::new(),
                    pending: None,
                    read_only: true,
                }
            };
            candidate.transfer.events.extend(incoming.transfer.events);
            merge_objects(&mut candidate.transfer.objects, incoming.transfer.objects)?;
            let verified = verify_transfer(candidate.transfer, &trusted_root_pub_b64)?;
            candidate.transfer = verified.transfer;
            for (ak, seq) in verified.counters {
                candidate
                    .counters
                    .entry(ak)
                    .and_modify(|n| *n = (*n).max(seq))
                    .or_insert(seq);
            }
            let response = result(&candidate, "Imported", None, None)?;
            *state = Some(candidate);
            Ok(response)
        })
    }

    fn mutate(
        &self,
        mutation: impl FnOnce(&mut Option<State>) -> Result<FfiSignedFoodResult, String>,
    ) -> FfiSignedFoodResult {
        let Ok(mut stored) = self.state.lock() else {
            return FfiSignedFoodResult::rejected("SDK_ERR_SIGNED_FOOD_STORE".into());
        };
        let mut candidate = stored.clone();
        match mutation(&mut candidate) {
            Ok(response) => {
                *stored = candidate;
                response
            }
            Err(diag) => FfiSignedFoodResult::rejected(diag),
        }
    }
}

fn merge_objects(
    target: &mut BTreeMap<String, String>,
    incoming: BTreeMap<String, String>,
) -> Result<(), String> {
    for (cid, bytes) in incoming {
        if target.get(&cid).is_some_and(|existing| existing != &bytes) {
            return Err(INVALID.into());
        }
        target.insert(cid, bytes);
    }
    Ok(())
}

fn result(
    state: &State,
    status: &str,
    operation_id: Option<String>,
    seq: Option<u64>,
) -> Result<FfiSignedFoodResult, String> {
    let bytes = serde_json::to_vec(state).map_err(|_| INVALID.to_string())?;
    if bytes.len() > MAX_BYTES {
        return Err(LIMIT.into());
    }
    let mut response = FfiSignedFoodResult::empty(status);
    response.operation_id = operation_id;
    response.seq = seq;
    let encoded = STANDARD.encode(bytes);
    if encoded.len() > MAX_BYTES {
        return Err(LIMIT.into());
    }
    response.snapshot_b64 = Some(encoded);
    if !state.transfer.events.is_empty() {
        let verified = verify_transfer(state.transfer.clone(), &state.transfer.root_pub_b64)?;
        response.sum_mean_kcal = verified.totals.sum_mean.get("kcal").copied();
        response.sum_var_kcal = verified.totals.sum_var.get("kcal").copied();
        response.event_count = verified.events.len() as u64;
        response.diag = verified.totals.diag_contains;
    }
    Ok(response)
}

fn prepared(state: &State) -> Result<FfiSignedFoodResult, String> {
    let pending = state.pending.as_ref().ok_or_else(|| INVALID.to_string())?;
    let mut response = result(
        state,
        "Prepared",
        Some(pending.operation_id.clone()),
        Some(pending.seq),
    )?;
    response.signing_bytes_b64 = Some(STANDARD.encode(signing_bytes(
        &public_key(&pending.author_pub_b64)?,
        &decode(&pending.payload_b64)?,
    )));
    Ok(response)
}

fn prepare(
    state: &mut Option<State>,
    author: &str,
    id: &str,
    kind: &str,
    body: C,
    objects: BTreeMap<String, String>,
) -> Result<FfiSignedFoodResult, String> {
    wire::operation_id(id)?;
    let current = state.as_mut().ok_or_else(|| INVALID.to_string())?;
    if current.read_only {
        return Err("SDK_ERR_SIGNED_FOOD_READ_ONLY".into());
    }
    let public = public_key(author)?;
    let ak = hex(&kid(&public));
    let verified = verify_transfer(current.transfer.clone(), &current.transfer.root_pub_b64)?;
    for event in verified
        .events
        .values()
        .filter(|event| event.ak == ak && event.operation_id.as_deref() == Some(id))
    {
        if event.kind != kind || encode(&event.body) != encode(&body) {
            return Err("SDK_ERR_SIGNED_FOOD_OPERATION_CONFLICT".into());
        }
        return result(
            current,
            "AlreadyCommitted",
            Some(id.to_string()),
            Some(event.seq),
        );
    }
    if !verified.authorized.contains(&ak) || verified.pubs.get(&ak) != Some(&public) {
        return Err("SDK_ERR_UNAUTHORIZED_AK".into());
    }
    if let Some(pending) = &current.pending {
        let expected = payload(kind, &public, pending.seq, body)?;
        if pending.author_pub_b64 != author
            || pending.operation_id != id
            || pending.kind != kind
            || decode(&pending.payload_b64)? != expected
            || pending.objects != objects
        {
            return Err("SDK_ERR_SIGNED_FOOD_PENDING".into());
        }
        return prepared(current);
    }
    let previous = current
        .counters
        .get(&ak)
        .copied()
        .unwrap_or(0)
        .max(verified.counters.get(&ak).copied().unwrap_or(0));
    let seq = previous
        .checked_add(1)
        .filter(|seq| *seq <= MAX_SEQ)
        .ok_or_else(|| "SDK_ERR_SIGNED_FOOD_SEQUENCE".to_string())?;
    validate_preparation(&current.transfer, &public, kind, seq, &body, &objects, id)?;
    let bytes = payload(kind, &public, seq, body)?;
    current.counters.insert(ak, seq);
    current.pending = Some(Pending {
        author_pub_b64: author.to_string(),
        operation_id: id.to_string(),
        kind: kind.to_string(),
        seq,
        payload_b64: STANDARD.encode(bytes),
        objects,
    });
    prepared(current)
}

fn validate_state(state: &State, trusted_root: &str) -> Result<(), String> {
    if state.snapshot_v != 1 || state.transfer.root_pub_b64 != trusted_root {
        return Err(TRUST.into());
    }
    let root = public_key(trusted_root)?;
    let verified = if state.transfer.events.is_empty() {
        None
    } else {
        Some(verify_transfer(state.transfer.clone(), trusted_root)?)
    };
    for (ak, seq) in &state.counters {
        if ak.len() != 32
            || !ak
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
            || *seq > MAX_SEQ
        {
            return Err(INVALID.into());
        }
    }
    if let Some(verified) = &verified {
        for (ak, seq) in &verified.counters {
            if state.counters.get(ak).map_or(true, |counter| counter < seq) {
                return Err(INVALID.into());
            }
        }
    }
    if let Some(pending) = &state.pending {
        if state.read_only {
            return Err(INVALID.into());
        }
        let public = public_key(&pending.author_pub_b64)?;
        let ak = hex(&kid(&public));
        let bytes = decode(&pending.payload_b64)?;
        let parsed = typed(&bytes, "LedgerEvent")?;
        let body = field(&parsed, "body")?.clone();
        if payload(&pending.kind, &public, pending.seq, body.clone())? != bytes
            || state
                .counters
                .get(&ak)
                .map_or(true, |seq| *seq < pending.seq)
        {
            return Err(INVALID.into());
        }
        if pending.kind == "LedgerGenesis" {
            if verified.is_some()
                || pending.seq != 0
                || pending.operation_id != "genesis"
                || public != root
                || field(&body, "root_pub")?.as_bytes() != Some(root.as_slice())
                || field(&body, "root_kid")?.as_bytes() != Some(kid(&root).as_slice())
                || !pending.objects.is_empty()
            {
                return Err(TRUST.into());
            }
        } else {
            wire::operation_id(&pending.operation_id)?;
            if text_field(field(&body, "ext")?, "grain.food.operation_id")? != pending.operation_id
            {
                return Err(INVALID.into());
            }
            let verified = verified.as_ref().ok_or_else(|| INVALID.to_string())?;
            if !verified.authorized.contains(&ak)
                || verified.pubs.get(&ak) != Some(&public)
                || verified.events.values().any(|event| {
                    event.ak == ak
                        && (event.seq == pending.seq
                            || event.operation_id.as_deref() == Some(&pending.operation_id))
                })
            {
                return Err(TRUST.into());
            }
            validate_preparation(
                &state.transfer,
                &public,
                &pending.kind,
                pending.seq,
                &body,
                &pending.objects,
                &pending.operation_id,
            )?;
        }
    } else if verified.is_none() {
        return Err(INVALID.into());
    }
    Ok(())
}
