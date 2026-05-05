use std::collections::BTreeMap;

use crate::diag::{
    SDK_ERR_STORE_ATOMIC_NESTED, SDK_ERR_STORE_CONFLICT, SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC,
};
use crate::store::{ClientStore, IdentityClientStore, StorePutResult};
use crate::types::{AcceptedScanRecord, IdentityBundleV1, LifecycleEventRecord};

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
