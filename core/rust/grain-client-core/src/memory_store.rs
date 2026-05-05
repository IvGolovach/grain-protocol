use std::collections::BTreeMap;

use crate::diag::{
    SDK_ERR_STORE_ATOMIC_NESTED, SDK_ERR_STORE_CONFLICT, SDK_ERR_STORE_MUTATION_OUTSIDE_ATOMIC,
};
use crate::store::{ClientStore, StorePutResult};
use crate::types::AcceptedScanRecord;

#[derive(Debug, Clone, Default)]
pub struct MemoryClientStore {
    accepted_scans: BTreeMap<String, AcceptedScanRecord>,
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

        let snapshot = self.accepted_scans.clone();
        self.in_atomic = true;
        let result = mutation(self);
        self.in_atomic = false;

        if result.is_err() {
            self.accepted_scans = snapshot;
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
