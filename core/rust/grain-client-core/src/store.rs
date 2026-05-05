use crate::types::AcceptedScanRecord;

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
