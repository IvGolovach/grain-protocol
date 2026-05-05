use crate::store::{ClientStore, StorePutResult};
use crate::types::AcceptedScanRecord;

/// Atomically put one accepted scan record through a platform storage adapter.
///
/// Adapter implementations must preserve `ClientStore` semantics: writes only
/// happen inside `atomic`, duplicate identical records are idempotent, conflicts
/// reject, and failed mutations roll back to the pre-call state.
pub fn put_accepted_scan_atomically<S: ClientStore>(
    store: &mut S,
    record: AcceptedScanRecord,
) -> Result<StorePutResult, String> {
    store.atomic(|tx| tx.put_accepted_scan(record))
}

/// List accepted scans through the platform storage contract.
///
/// The returned order must be deterministic by `scan_id` so generated SDKs can
/// expose stable list results across languages.
pub fn list_accepted_scans<S: ClientStore>(store: &S) -> Vec<AcceptedScanRecord> {
    store.list_accepted_scans()
}
