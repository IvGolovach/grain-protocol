use crate::types::{AcceptedScanRecord, IdentityBundleV1, LifecycleEventRecord};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StorePutResult {
    Inserted,
    AlreadyExists,
}

/// Platform-neutral storage contract for client workflows.
///
/// Implementations must make `atomic` all-or-nothing. Mutating methods may be
/// exposed on concrete stores for testability, but they must reject calls made
/// outside an active atomic transaction.
pub trait ClientStore: Sized {
    fn atomic<R>(
        &mut self,
        mutation: impl FnOnce(&mut Self) -> Result<R, String>,
    ) -> Result<R, String>;

    fn put_accepted_scan(&mut self, record: AcceptedScanRecord) -> Result<StorePutResult, String>;

    /// Return accepted scans in deterministic `scan_id` order.
    fn list_accepted_scans(&self) -> Vec<AcceptedScanRecord>;
}

/// Platform-neutral identity, pairing, and lifecycle storage contract.
///
/// Implementations must preserve the same atomic boundary as `ClientStore`:
/// mutating methods reject calls outside an active transaction, and a failed
/// transaction restores every identity/lifecycle field.
pub trait IdentityClientStore: ClientStore {
    fn load_identity_bundle(&self) -> Option<IdentityBundleV1>;

    fn save_identity_bundle(&mut self, bundle: IdentityBundleV1) -> Result<StorePutResult, String>;

    fn reserve_next_seq(&mut self, ak: &str) -> Result<u64, String>;

    fn import_seq_state(
        &mut self,
        state: std::collections::BTreeMap<String, String>,
    ) -> Result<(), String>;

    fn append_lifecycle_event(
        &mut self,
        event: LifecycleEventRecord,
    ) -> Result<StorePutResult, String>;

    fn list_lifecycle_events(&self) -> Vec<LifecycleEventRecord>;
}
