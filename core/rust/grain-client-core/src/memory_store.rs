use std::collections::BTreeMap;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use serde::{Deserialize, Serialize};

use crate::accepted_scan::validate_accepted_scan_record;
use crate::device::validate_lifecycle_event_record;
use crate::diag::{
    SDK_ERR_STORE_ATOMIC_NESTED, SDK_ERR_STORE_CONFLICT, SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC,
    SDK_ERR_STORE_SNAPSHOT_INVALID, SDK_ERR_STORE_SNAPSHOT_VERSION,
};
use crate::identity::{decode_standard_b64, validate_identity_bundle};
use crate::store::{ClientStore, IdentityClientStore, StorePutResult};
use crate::types::{
    AcceptedScanRecord, IdentityBundleV1, LifecycleEventRecord, StoreSnapshotResult,
    StoreSnapshotStatus,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct StoreSnapshotV1 {
    snapshot_v: u32,
    identity: Option<IdentityBundleV1>,
    accepted_scans: Vec<AcceptedScanRecord>,
    lifecycle_events: Vec<LifecycleEventRecord>,
}

#[derive(Debug, Clone, Default)]
pub struct MemoryClientStore {
    accepted_scans: BTreeMap<String, AcceptedScanRecord>,
    identity_bundle: Option<IdentityBundleV1>,
    seq_by_ak: BTreeMap<String, u64>,
    lifecycle_events: BTreeMap<String, LifecycleEventRecord>,
    in_atomic: bool,
}

impl MemoryClientStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn export_store_snapshot(&self) -> StoreSnapshotResult {
        let snapshot = StoreSnapshotV1 {
            snapshot_v: 1,
            identity: self.identity_bundle.clone(),
            accepted_scans: self.accepted_scans.values().cloned().collect(),
            lifecycle_events: self.lifecycle_events.values().cloned().collect(),
        };

        if snapshot.identity.is_none()
            && snapshot.accepted_scans.is_empty()
            && snapshot.lifecycle_events.is_empty()
        {
            return snapshot_result(StoreSnapshotStatus::Empty, Vec::new(), None, &snapshot);
        }

        match encode_snapshot_b64(&snapshot) {
            Ok(snapshot_b64) => snapshot_result(
                StoreSnapshotStatus::Exported,
                Vec::new(),
                Some(snapshot_b64),
                &snapshot,
            ),
            Err(diag) => snapshot_rejected(diag),
        }
    }

    pub fn restore_store_snapshot(&mut self, snapshot_b64: &str) -> StoreSnapshotResult {
        if self.in_atomic {
            return snapshot_rejected(SDK_ERR_STORE_ATOMIC_NESTED);
        }

        let (snapshot, replacement) = match decode_store_snapshot(snapshot_b64) {
            Ok(decoded) => decoded,
            Err(diag) => return snapshot_rejected(diag),
        };

        self.accepted_scans = replacement.accepted_scans;
        self.identity_bundle = snapshot.identity.clone();
        self.seq_by_ak = replacement.seq_by_ak;
        self.lifecycle_events = replacement.lifecycle_events;
        snapshot_result(StoreSnapshotStatus::Restored, Vec::new(), None, &snapshot)
    }
}

struct SnapshotMaps {
    accepted_scans: BTreeMap<String, AcceptedScanRecord>,
    seq_by_ak: BTreeMap<String, u64>,
    lifecycle_events: BTreeMap<String, LifecycleEventRecord>,
}

fn encode_snapshot_b64(snapshot: &StoreSnapshotV1) -> Result<String, String> {
    serde_json::to_vec(snapshot)
        .map(|bytes| STANDARD.encode(bytes))
        .map_err(|_| SDK_ERR_STORE_SNAPSHOT_INVALID.to_string())
}

fn decode_store_snapshot(snapshot_b64: &str) -> Result<(StoreSnapshotV1, SnapshotMaps), String> {
    let bytes = decode_standard_b64(snapshot_b64, SDK_ERR_STORE_SNAPSHOT_INVALID)?;
    let snapshot = serde_json::from_slice::<StoreSnapshotV1>(&bytes)
        .map_err(|_| SDK_ERR_STORE_SNAPSHOT_INVALID.to_string())?;
    validate_snapshot_shape(&snapshot)?;
    let maps = snapshot_maps(&snapshot)?;
    Ok((snapshot, maps))
}

fn validate_snapshot_shape(snapshot: &StoreSnapshotV1) -> Result<(), String> {
    if snapshot.snapshot_v != 1 {
        return Err(SDK_ERR_STORE_SNAPSHOT_VERSION.to_string());
    }
    if let Some(identity) = &snapshot.identity {
        validate_identity_bundle(identity)
            .map_err(|_| SDK_ERR_STORE_SNAPSHOT_INVALID.to_string())?;
    }
    if snapshot.identity.is_none() && !snapshot.lifecycle_events.is_empty() {
        return Err(SDK_ERR_STORE_SNAPSHOT_INVALID.to_string());
    }
    Ok(())
}

fn snapshot_maps(snapshot: &StoreSnapshotV1) -> Result<SnapshotMaps, String> {
    let mut accepted_scans = BTreeMap::new();
    for record in &snapshot.accepted_scans {
        validate_accepted_scan_record(record)
            .map_err(|_| SDK_ERR_STORE_SNAPSHOT_INVALID.to_string())?;
        if accepted_scans
            .insert(record.scan_id.clone(), record.clone())
            .is_some()
        {
            return Err(SDK_ERR_STORE_SNAPSHOT_INVALID.to_string());
        }
    }

    let mut seq_by_ak = BTreeMap::new();
    if let Some(identity) = &snapshot.identity {
        for (ak, seq) in &identity.seq_state {
            let parsed = seq
                .parse::<u64>()
                .map_err(|_| SDK_ERR_STORE_SNAPSHOT_INVALID.to_string())?;
            seq_by_ak.insert(ak.clone(), parsed);
        }
    }

    let mut lifecycle_events = BTreeMap::new();
    for event in &snapshot.lifecycle_events {
        if let Some(identity) = &snapshot.identity {
            if !validate_lifecycle_event_record(event, identity) {
                return Err(SDK_ERR_STORE_SNAPSHOT_INVALID.to_string());
            }
        }
        if lifecycle_events
            .insert(event.event_id.clone(), event.clone())
            .is_some()
        {
            return Err(SDK_ERR_STORE_SNAPSHOT_INVALID.to_string());
        }
    }

    Ok(SnapshotMaps {
        accepted_scans,
        seq_by_ak,
        lifecycle_events,
    })
}

fn snapshot_result(
    status: StoreSnapshotStatus,
    diag: Vec<String>,
    snapshot_b64: Option<String>,
    snapshot: &StoreSnapshotV1,
) -> StoreSnapshotResult {
    StoreSnapshotResult {
        status,
        diag,
        snapshot_b64,
        accepted_record_count: snapshot.accepted_scans.len() as u64,
        device_count: snapshot
            .identity
            .as_ref()
            .map(|identity| identity.device_keys.len() as u64)
            .unwrap_or(0),
        lifecycle_event_count: snapshot.lifecycle_events.len() as u64,
    }
}

fn snapshot_rejected(diag: impl Into<String>) -> StoreSnapshotResult {
    StoreSnapshotResult {
        status: StoreSnapshotStatus::Rejected,
        diag: vec![diag.into()],
        snapshot_b64: None,
        accepted_record_count: 0,
        device_count: 0,
        lifecycle_event_count: 0,
    }
}

impl ClientStore for MemoryClientStore {
    fn atomic<R>(
        &mut self,
        mutation: impl FnOnce(&mut Self) -> Result<R, String>,
    ) -> Result<R, String> {
        if self.in_atomic {
            return Err(SDK_ERR_STORE_ATOMIC_NESTED.to_string());
        }

        let snapshot = (
            self.accepted_scans.clone(),
            self.identity_bundle.clone(),
            self.seq_by_ak.clone(),
            self.lifecycle_events.clone(),
        );
        self.in_atomic = true;
        let result = mutation(self);
        self.in_atomic = false;

        if result.is_err() {
            self.accepted_scans = snapshot.0;
            self.identity_bundle = snapshot.1;
            self.seq_by_ak = snapshot.2;
            self.lifecycle_events = snapshot.3;
        }

        result
    }

    fn put_accepted_scan(&mut self, record: AcceptedScanRecord) -> Result<StorePutResult, String> {
        if !self.in_atomic {
            return Err(SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC.to_string());
        }

        match self.accepted_scans.get(&record.scan_id) {
            Some(existing) if existing == &record => Ok(StorePutResult::AlreadyExists),
            Some(_) => Err(SDK_ERR_STORE_CONFLICT.to_string()),
            None => {
                self.accepted_scans.insert(record.scan_id.clone(), record);
                Ok(StorePutResult::Inserted)
            }
        }
    }

    fn list_accepted_scans(&self) -> Vec<AcceptedScanRecord> {
        self.accepted_scans.values().cloned().collect()
    }
}

impl IdentityClientStore for MemoryClientStore {
    fn load_identity_bundle(&self) -> Option<IdentityBundleV1> {
        self.identity_bundle.clone()
    }

    fn save_identity_bundle(&mut self, bundle: IdentityBundleV1) -> Result<StorePutResult, String> {
        if !self.in_atomic {
            return Err(SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC.to_string());
        }

        let result = match self.identity_bundle.as_ref() {
            Some(existing) if existing == &bundle => StorePutResult::AlreadyExists,
            _ => StorePutResult::Inserted,
        };
        self.seq_by_ak.clear();
        for (ak, seq) in &bundle.seq_state {
            let parsed = seq
                .parse::<u64>()
                .map_err(|_| SDK_ERR_STORE_CONFLICT.to_string())?;
            self.seq_by_ak.insert(ak.clone(), parsed);
        }
        self.identity_bundle = Some(bundle);
        Ok(result)
    }

    fn reserve_next_seq(&mut self, ak: &str) -> Result<u64, String> {
        if !self.in_atomic {
            return Err(SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC.to_string());
        }

        let next = self
            .seq_by_ak
            .get(ak)
            .copied()
            .unwrap_or(0)
            .checked_add(1)
            .ok_or_else(|| SDK_ERR_STORE_CONFLICT.to_string())?;
        self.seq_by_ak.insert(ak.to_string(), next);
        Ok(next)
    }

    fn import_seq_state(&mut self, state: BTreeMap<String, String>) -> Result<(), String> {
        if !self.in_atomic {
            return Err(SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC.to_string());
        }

        self.seq_by_ak.clear();
        for (ak, seq) in state {
            let parsed = seq
                .parse::<u64>()
                .map_err(|_| SDK_ERR_STORE_CONFLICT.to_string())?;
            self.seq_by_ak.insert(ak, parsed);
        }
        Ok(())
    }

    fn append_lifecycle_event(
        &mut self,
        event: LifecycleEventRecord,
    ) -> Result<StorePutResult, String> {
        if !self.in_atomic {
            return Err(SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC.to_string());
        }

        match self.lifecycle_events.get(&event.event_id) {
            Some(existing) if existing == &event => Ok(StorePutResult::AlreadyExists),
            Some(_) => Err(SDK_ERR_STORE_CONFLICT.to_string()),
            None => {
                self.lifecycle_events.insert(event.event_id.clone(), event);
                Ok(StorePutResult::Inserted)
            }
        }
    }

    fn list_lifecycle_events(&self) -> Vec<LifecycleEventRecord> {
        self.lifecycle_events.values().cloned().collect()
    }
}
