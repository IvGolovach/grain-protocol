use std::collections::{BTreeMap, BTreeSet};

use base64::{engine::general_purpose::STANDARD, Engine};
use grain_core::{
    cbor::{encode_canonical, parse_exact_to_error, CborValue as C, ParseOptions},
    cid::derive_cid_v1_dag_cbor_sha256,
    cose::verify_cose_sign1_payload,
    ledger::{reduce_ledger, LedgerEvent, LedgerTotals},
    typed_object::validate_typed_object_v1,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};

pub(super) const INVALID: &str = "SDK_ERR_SIGNED_FOOD_INVALID";
pub(super) const TRUST: &str = "SDK_ERR_SIGNED_FOOD_TRUST";
pub(super) const LIMIT: &str = "SDK_ERR_SIGNED_FOOD_LIMIT";
pub(super) const MAX_SEQ: u64 = i64::MAX as u64;
pub(super) const MAX_BYTES: usize = 16_000_000;
pub(super) const MAX_EVENTS: usize = 4096;

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct Transfer {
    pub bundle_v: u32,
    pub root_pub_b64: String,
    pub events: Vec<String>,
    #[serde(deserialize_with = "unique_objects")]
    pub objects: BTreeMap<String, String>,
}

fn unique_objects<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> Result<BTreeMap<String, String>, D::Error> {
    struct Unique;
    impl<'de> serde::de::Visitor<'de> for Unique {
        type Value = BTreeMap<String, String>;
        fn expecting(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.write_str("unique object CID keys")
        }
        fn visit_map<M: serde::de::MapAccess<'de>>(
            self,
            mut input: M,
        ) -> Result<Self::Value, M::Error> {
            let mut values = BTreeMap::new();
            while let Some((key, value)) = input.next_entry::<String, String>()? {
                if values.insert(key, value).is_some() {
                    return Err(serde::de::Error::custom("duplicate object CID"));
                }
            }
            Ok(values)
        }
    }
    deserializer.deserialize_map(Unique)
}

pub(super) struct Verified {
    pub transfer: Transfer,
    pub events: BTreeMap<String, Event>,
    pub pubs: BTreeMap<String, Vec<u8>>,
    pub authorized: BTreeSet<String>,
    pub counters: BTreeMap<String, u64>,
    pub totals: LedgerTotals,
}

pub(super) struct Event {
    pub ak: String,
    pub seq: u64,
    pub kind: String,
    pub body: C,
    pub operation_id: Option<String>,
    pub cose_b64: String,
}

pub(super) fn encode(value: &C) -> Vec<u8> {
    let mut bytes = Vec::new();
    encode_canonical(value, &mut bytes);
    bytes
}

pub(super) fn text(value: &str) -> C {
    C::Text(value.as_bytes().to_vec())
}
pub(super) fn map(values: Vec<(&str, C)>) -> C {
    C::Map(
        values
            .into_iter()
            .map(|(key, value)| (text(key), value))
            .collect(),
    )
}
pub(super) fn number(value: i64) -> C {
    if value >= 0 {
        C::Unsigned(value as u64)
    } else {
        C::Negative(value as i128)
    }
}
pub(super) fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}
pub(super) fn kid(public: &[u8]) -> Vec<u8> {
    Sha256::digest(public)[..16].to_vec()
}
pub(super) fn cid(bytes: &[u8]) -> Result<String, String> {
    derive_cid_v1_dag_cbor_sha256(bytes).map_err(|error| error.diag().to_string())
}
pub(super) fn link(bytes: &[u8]) -> C {
    let mut binary = vec![0, 1, 0x71, 0x12, 0x20];
    binary.extend_from_slice(&Sha256::digest(bytes));
    C::Tag(42, Box::new(C::Bytes(binary)))
}
pub(super) fn decode(value: &str) -> Result<Vec<u8>, String> {
    if value.len() > MAX_BYTES {
        return Err(LIMIT.into());
    }
    let bytes = STANDARD.decode(value).map_err(|_| INVALID.to_string())?;
    if STANDARD.encode(&bytes) != value {
        return Err(INVALID.into());
    }
    Ok(bytes)
}
pub(super) fn public_key(value: &str) -> Result<Vec<u8>, String> {
    let bytes = decode(value)?;
    if bytes.len() != 32 {
        return Err(TRUST.into());
    }
    Ok(bytes)
}
pub(super) fn field<'a>(value: &'a C, name: &str) -> Result<&'a C, String> {
    value.map_get(name).ok_or_else(|| INVALID.to_string())
}
fn bytes_field(value: &C, name: &str) -> Result<Vec<u8>, String> {
    field(value, name)?
        .as_bytes()
        .map(|b| b.to_vec())
        .ok_or_else(|| INVALID.to_string())
}
pub(super) fn text_field(value: &C, name: &str) -> Result<String, String> {
    field(value, name)?
        .as_text()
        .ok_or_else(|| INVALID.to_string())
}
pub(super) fn integer(value: &C) -> Result<i64, String> {
    match value {
        C::Unsigned(n) => i64::try_from(*n).map_err(|_| INVALID.to_string()),
        C::Negative(n) => i64::try_from(*n).map_err(|_| INVALID.to_string()),
        _ => Err(INVALID.into()),
    }
}
pub(super) fn operation_id(value: &str) -> Result<(), String> {
    if value.is_empty()
        || value.len() > 128
        || !value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
    {
        return Err(INVALID.into());
    }
    Ok(())
}
pub(super) fn with_operation(mut body: C, id: &str) -> Result<C, String> {
    operation_id(id)?;
    let C::Map(ref mut fields) = body else {
        return Err(INVALID.into());
    };
    fields.push((
        text("ext"),
        map(vec![("grain.food.operation_id", text(id))]),
    ));
    Ok(body)
}
pub(super) fn typed(bytes: &[u8], kind: &str) -> Result<C, String> {
    validate_typed_object_v1(bytes, kind).map_err(|error| error.diag().to_string())
}
pub(super) fn payload(kind: &str, public: &[u8], seq: u64, body: C) -> Result<Vec<u8>, String> {
    typed(&encode(&body), kind)?;
    let bytes = encode(&map(vec![
        ("v", C::Unsigned(1)),
        ("t", text(kind)),
        ("ak", C::Bytes(kid(public))),
        ("seq", C::Unsigned(seq)),
        ("body", body),
    ]));
    typed(&bytes, "LedgerEvent")?;
    Ok(bytes)
}
fn protected(public: &[u8]) -> Vec<u8> {
    encode(&C::Map(vec![
        (C::Unsigned(1), C::Negative(-19)),
        (C::Unsigned(4), C::Bytes(kid(public))),
    ]))
}
pub(super) fn signing_bytes(public: &[u8], payload: &[u8]) -> Vec<u8> {
    encode(&C::Array(vec![
        text("Signature1"),
        C::Bytes(protected(public)),
        C::Bytes(Vec::new()),
        C::Bytes(payload.to_vec()),
    ]))
}
pub(super) fn envelope(public: &[u8], payload: &[u8], signature: &[u8]) -> Vec<u8> {
    encode(&C::Array(vec![
        C::Bytes(protected(public)),
        C::Map(Vec::new()),
        C::Bytes(payload.to_vec()),
        C::Bytes(signature.to_vec()),
    ]))
}

fn envelope_author(bytes: &[u8]) -> Result<String, String> {
    let parsed = parse_exact_to_error(bytes, ParseOptions::generic_cbor_canonical())
        .map_err(|e| e.diag().to_string())?;
    let C::Array(items) = parsed else {
        return Err(INVALID.into());
    };
    if items.len() != 4 {
        return Err(INVALID.into());
    }
    let protected = items[0].as_bytes().ok_or_else(|| INVALID.to_string())?;
    let parsed = parse_exact_to_error(protected, ParseOptions::generic_cbor_canonical())
        .map_err(|e| e.diag().to_string())?;
    let C::Map(fields) = parsed else {
        return Err(INVALID.into());
    };
    fields
        .iter()
        .find_map(|(key, value)| {
            if *key == C::Unsigned(4) {
                value.as_bytes().map(hex)
            } else {
                None
            }
        })
        .ok_or_else(|| INVALID.to_string())
}

fn verify_event(cose: &[u8], public: &[u8]) -> Result<(String, Event), String> {
    let verified =
        verify_cose_sign1_payload(cose, public, &[]).map_err(|e| e.diag().to_string())?;
    let value = typed(&verified.payload, "LedgerEvent")?;
    if bytes_field(&value, "ak")? != verified.kid {
        return Err(TRUST.into());
    }
    let kind = text_field(&value, "t")?;
    if ![
        "LedgerGenesis",
        "DeviceKeyGrant",
        "DeviceKeyRevoke",
        "IntakeEvent",
    ]
    .contains(&kind.as_str())
    {
        return Err("SDK_ERR_SIGNED_FOOD_UNSUPPORTED".into());
    }
    let body = field(&value, "body")?.clone();
    typed(&encode(&body), &kind)?;
    let id = if kind == "LedgerGenesis" {
        None
    } else {
        let value = text_field(field(&body, "ext")?, "grain.food.operation_id")?;
        operation_id(&value)?;
        Some(value)
    };
    let seq = integer(field(&value, "seq")?)? as u64;
    Ok((
        cid(&verified.payload)?,
        Event {
            ak: hex(&verified.kid),
            seq,
            kind,
            body,
            operation_id: id,
            cose_b64: STANDARD.encode(cose),
        },
    ))
}

pub(super) fn verify_transfer(transfer: Transfer, trusted_pub: &str) -> Result<Verified, String> {
    if transfer.bundle_v != 1 || transfer.root_pub_b64 != trusted_pub {
        return Err(TRUST.into());
    }
    let root = public_key(trusted_pub)?;
    let root_ak = hex(&kid(&root));
    if transfer.events.is_empty()
        || transfer.events.len() > MAX_EVENTS
        || transfer.objects.len() > MAX_EVENTS
    {
        return Err(LIMIT.into());
    }
    let size = serde_json::to_vec(&transfer)
        .map_err(|_| INVALID.to_string())?
        .len();
    if size > MAX_BYTES {
        return Err(LIMIT.into());
    }
    let mut pubs = BTreeMap::from([(root_ak.clone(), root.clone())]);
    let mut events = BTreeMap::new();
    let mut deferred = Vec::new();
    for encoded in &transfer.events {
        let bytes = decode(encoded)?;
        if bytes.len() > 34_000 {
            return Err(LIMIT.into());
        }
        let author = envelope_author(&bytes)?;
        if author != root_ak {
            deferred.push((author, bytes));
            continue;
        }
        let (id, event) = verify_event(&bytes, &root)?;
        if event.kind == "DeviceKeyGrant" {
            let granted = bytes_field(&event.body, "pub")?;
            let ak = bytes_field(&event.body, "ak")?;
            if kid(&granted) != ak || ak == kid(&root) {
                return Err(TRUST.into());
            }
            if pubs
                .get(&hex(&ak))
                .is_some_and(|existing| existing != &granted)
            {
                return Err(TRUST.into());
            }
            pubs.insert(hex(&ak), granted);
        }
        insert_event(&mut events, id, event);
    }
    for (author, bytes) in deferred {
        let public = pubs.get(&author).ok_or_else(|| TRUST.to_string())?;
        let (id, event) = verify_event(&bytes, public)?;
        insert_event(&mut events, id, event);
    }
    evaluate(transfer, trusted_pub, events, pubs)
}

pub(super) fn validate_preparation(
    transfer: &Transfer,
    public: &[u8],
    kind: &str,
    seq: u64,
    body: &C,
    objects: &BTreeMap<String, String>,
    operation_id: &str,
) -> Result<(), String> {
    let mut verified = verify_transfer(transfer.clone(), &transfer.root_pub_b64)?;
    let payload = payload(kind, public, seq, body.clone())?;
    verified.events.insert(
        cid(&payload)?,
        Event {
            ak: hex(&kid(public)),
            seq,
            kind: kind.into(),
            body: body.clone(),
            operation_id: Some(operation_id.into()),
            cose_b64: String::new(),
        },
    );
    let mut candidate = transfer.clone();
    for (id, bytes) in objects {
        if candidate
            .objects
            .get(id)
            .is_some_and(|existing| existing != bytes)
        {
            return Err(INVALID.into());
        }
        candidate.objects.insert(id.clone(), bytes.clone());
    }
    // Verify semantic acceptance before issuing bytes to a signer. In particular,
    // an overflowing intake or grant must not create an uncommittable reservation.
    evaluate(
        candidate,
        &transfer.root_pub_b64,
        verified.events,
        verified.pubs,
    )?;
    Ok(())
}

fn evaluate(
    transfer: Transfer,
    trusted_pub: &str,
    events: BTreeMap<String, Event>,
    pubs: BTreeMap<String, Vec<u8>>,
) -> Result<Verified, String> {
    if events.len() > MAX_EVENTS || transfer.objects.len() > MAX_EVENTS {
        return Err(LIMIT.into());
    }
    let root = public_key(trusted_pub)?;
    let root_ak = hex(&kid(&root));
    let mut links = BTreeMap::new();
    for (id, encoded) in &transfer.objects {
        let bytes = decode(encoded)?;
        if cid(&bytes)? != *id {
            return Err(INVALID.into());
        }
        let profile = typed(&bytes, "NutrientProfile")?;
        links.insert(encode(&link(&bytes)), profile);
    }
    let mut genesis = 0;
    let mut counters: BTreeMap<String, u64> = BTreeMap::new();
    let mut sequences: BTreeMap<(String, u64), BTreeSet<String>> = BTreeMap::new();
    let mut rows = Vec::new();
    let mut operations = BTreeMap::new();
    for (id, event) in &events {
        if let Some(operation) = &event.operation_id {
            if operations
                .insert((event.ak.clone(), operation.clone()), id.clone())
                .is_some_and(|previous| previous != *id)
            {
                return Err("SDK_ERR_SIGNED_FOOD_OPERATION_CONFLICT".into());
            }
        }
        sequences
            .entry((event.ak.clone(), event.seq))
            .or_default()
            .insert(id.clone());
        counters
            .entry(event.ak.clone())
            .and_modify(|n| *n = (*n).max(event.seq))
            .or_insert(event.seq);
        let body = match event.kind.as_str() {
            "LedgerGenesis" => {
                if event.ak != root_ak
                    || event.seq != 0
                    || bytes_field(&event.body, "root_pub")? != root
                    || bytes_field(&event.body, "root_kid")? != kid(&root)
                {
                    return Err(TRUST.into());
                }
                genesis += 1;
                json!({})
            }
            "DeviceKeyGrant" => json!({"grant_ak": hex(&bytes_field(&event.body, "ak")?)}),
            "DeviceKeyRevoke" => {
                let revoked = hex(&bytes_field(&event.body, "ak")?);
                if revoked == root_ak {
                    return Err(TRUST.into());
                }
                json!({"revoke_ak": revoked})
            }
            "IntakeEvent" => {
                if text_field(&event.body, "mode")? != "from_profile"
                    || integer(field(&event.body, "servings")?)? != 1
                {
                    return Err("SDK_ERR_SIGNED_FOOD_UNSUPPORTED".into());
                }
                let source = text_field(&event.body, "source_class")?;
                if !["estimated", "measured"].contains(&source.as_str()) {
                    return Err("SDK_ERR_SIGNED_FOOD_UNSUPPORTED".into());
                }
                let profile = links
                    .get(&encode(field(&event.body, "profile")?))
                    .ok_or_else(|| INVALID.to_string())?;
                if text_field(profile, "basis")? != "per_serving"
                    || text_field(profile, "source")? != source
                {
                    return Err(INVALID.into());
                }
                let mean = integer(field(field(&event.body, "mean")?, "kcal")?)?;
                let var = integer(field(field(&event.body, "var")?, "kcal")?)?;
                if integer(field(field(profile, "nutr")?, "kcal")?)? != mean
                    || integer(field(field(profile, "uncert")?, "kcal")?)? != var
                {
                    return Err(INVALID.into());
                }
                json!({"mean":{"kcal":mean},"var":{"kcal":var},"source_class":source})
            }
            _ => return Err(INVALID.into()),
        };
        rows.push(LedgerEvent {
            t: event.kind.clone(),
            ak: event.ak.clone(),
            seq: event.seq,
            payload_cid: id.clone(),
            body,
        });
    }
    if genesis != 1
        || sequences
            .get(&(root_ak.clone(), 0))
            .map_or(true, |set| set.len() != 1)
    {
        return Err(TRUST.into());
    }
    let conflicted: BTreeSet<_> = sequences
        .into_iter()
        .filter(|(_, ids)| ids.len() > 1)
        .map(|(key, _)| key)
        .collect();
    let mut authorized = BTreeSet::from([root_ak.clone()]);
    let mut revoked = BTreeSet::new();
    for row in &rows {
        if row.ak != root_ak || conflicted.contains(&(row.ak.clone(), row.seq)) {
            continue;
        }
        if row.t == "DeviceKeyGrant" {
            authorized.insert(row.body["grant_ak"].as_str().unwrap().to_string());
        }
        if row.t == "DeviceKeyRevoke" {
            revoked.insert(row.body["revoke_ak"].as_str().unwrap().to_string());
        }
    }
    authorized.retain(|ak| !revoked.contains(ak));
    let totals = reduce_ledger(&root_ak, &rows).map_err(|e| e.diag().to_string())?;
    let normalized = Transfer {
        bundle_v: 1,
        root_pub_b64: trusted_pub.to_string(),
        events: events
            .values()
            .map(|event| event.cose_b64.clone())
            .collect(),
        objects: transfer.objects,
    };
    Ok(Verified {
        transfer: normalized,
        events,
        pubs,
        authorized,
        counters,
        totals,
    })
}

fn insert_event(events: &mut BTreeMap<String, Event>, id: String, event: Event) {
    match events.get(&id) {
        Some(existing) if existing.cose_b64 <= event.cose_b64 => {}
        _ => {
            events.insert(id, event);
        }
    }
}
