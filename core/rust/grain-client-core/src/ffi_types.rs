use crate::store::StorePutResult;
use crate::types::{
    AcceptedScan, AcceptedScanRecord, ClientLifecycle, ClientLifecycleStatus, DeviceResult,
    DeviceStatus, IdentityResult, IdentityStatus, PairingResult, PairingStatus, ScanAccept,
    ScanAcceptRequest, ScanAcceptStatus, ScanPreview, ScanPreviewStatus, StoreSnapshotResult,
    StoreSnapshotStatus, SyncResult, SyncStatus,
};
use std::fmt;

/// Binding-safe scan-preview request DTO.
///
/// `scan_preview` has no separate core request type today; generated bindings
/// pass these owned fields directly to the core function.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiScanPreviewRequest {
    pub qr_string: String,
    pub trust_pub_b64: Option<String>,
}

impl fmt::Debug for FfiScanPreviewRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiScanPreviewRequest")
            .field("qr_string", &self.qr_string)
            .field(
                "trust_pub_b64",
                &self.trust_pub_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .finish()
    }
}

/// Binding-safe scan-preview result DTO.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiScanPreview {
    pub status: String,
    pub diag: Vec<String>,
    pub cose_b64: Option<String>,
}

impl fmt::Debug for FfiScanPreview {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiScanPreview")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("cose_b64", &self.cose_b64.as_ref().map(|_| "[REDACTED]"))
            .finish()
    }
}

impl From<ScanPreview> for FfiScanPreview {
    fn from(preview: ScanPreview) -> Self {
        Self {
            status: preview_status_string(preview.status),
            diag: preview.diag,
            cose_b64: preview.cose_b64,
        }
    }
}

/// Binding-safe scan-accept request DTO.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiScanAcceptRequest {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

impl fmt::Debug for FfiScanAcceptRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiScanAcceptRequest")
            .field("qr_string", &self.qr_string)
            .field("trust_pub_b64", &"[REDACTED]")
            .finish()
    }
}

impl From<FfiScanAcceptRequest> for ScanAcceptRequest {
    fn from(request: FfiScanAcceptRequest) -> Self {
        Self {
            qr_string: request.qr_string,
            trust_pub_b64: request.trust_pub_b64,
        }
    }
}

impl From<ScanAcceptRequest> for FfiScanAcceptRequest {
    fn from(request: ScanAcceptRequest) -> Self {
        Self {
            qr_string: request.qr_string,
            trust_pub_b64: request.trust_pub_b64,
        }
    }
}

/// Binding-safe accepted scan DTO.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiAcceptedScan {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

impl fmt::Debug for FfiAcceptedScan {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiAcceptedScan")
            .field("scan_id", &self.scan_id)
            .field("cose_b64", &"[REDACTED]")
            .field("trust_pub_b64", &"[REDACTED]")
            .finish()
    }
}

impl From<AcceptedScan> for FfiAcceptedScan {
    fn from(accepted: AcceptedScan) -> Self {
        Self {
            scan_id: accepted.scan_id,
            cose_b64: accepted.cose_b64,
            trust_pub_b64: accepted.trust_pub_b64,
        }
    }
}

impl From<AcceptedScanRecord> for FfiAcceptedScan {
    fn from(record: AcceptedScanRecord) -> Self {
        Self {
            scan_id: record.scan_id,
            cose_b64: record.cose_b64,
            trust_pub_b64: record.trust_pub_b64,
        }
    }
}

/// Binding-safe scan-accept result DTO.
#[derive(Clone, PartialEq, Eq)]
pub struct FfiScanAccept {
    pub status: String,
    pub diag: Vec<String>,
    pub scan_id: Option<String>,
    pub cose_b64: Option<String>,
    pub trust_pub_b64: Option<String>,
}

impl fmt::Debug for FfiScanAccept {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiScanAccept")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("scan_id", &self.scan_id)
            .field("cose_b64", &self.cose_b64.as_ref().map(|_| "[REDACTED]"))
            .field(
                "trust_pub_b64",
                &self.trust_pub_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .finish()
    }
}

impl From<ScanAccept> for FfiScanAccept {
    fn from(accepted: ScanAccept) -> Self {
        let (scan_id, cose_b64, trust_pub_b64) = accepted
            .accepted
            .map(|record| {
                (
                    Some(record.scan_id),
                    Some(record.cose_b64),
                    Some(record.trust_pub_b64),
                )
            })
            .unwrap_or((None, None, None));

        Self {
            status: accept_status_string(accepted.status),
            diag: accepted.diag,
            scan_id,
            cose_b64,
            trust_pub_b64,
        }
    }
}

/// Binding-safe store put result DTO.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiStorePutResult {
    pub status: String,
}

impl From<StorePutResult> for FfiStorePutResult {
    fn from(result: StorePutResult) -> Self {
        let status = match result {
            StorePutResult::Inserted => "Inserted",
            StorePutResult::AlreadyExists => "AlreadyExists",
        };
        Self {
            status: status.to_string(),
        }
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiStoreSnapshotResult {
    pub status: String,
    pub diag: Vec<String>,
    pub snapshot_b64: Option<String>,
    pub accepted_record_count: u64,
    pub device_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for FfiStoreSnapshotResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiStoreSnapshotResult")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field(
                "snapshot_b64",
                &self.snapshot_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .field("accepted_record_count", &self.accepted_record_count)
            .field("device_count", &self.device_count)
            .field("lifecycle_event_count", &self.lifecycle_event_count)
            .finish()
    }
}

impl From<StoreSnapshotResult> for FfiStoreSnapshotResult {
    fn from(result: StoreSnapshotResult) -> Self {
        Self {
            status: store_snapshot_status_string(result.status),
            diag: result.diag,
            snapshot_b64: result.snapshot_b64,
            accepted_record_count: result.accepted_record_count,
            device_count: result.device_count,
            lifecycle_event_count: result.lifecycle_event_count,
        }
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiIdentityResult {
    pub status: String,
    pub diag: Vec<String>,
    pub root_kid: Option<String>,
    pub active_ak: Option<String>,
    pub bundle_b64: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for FfiIdentityResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiIdentityResult")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("root_kid", &self.root_kid)
            .field("active_ak", &self.active_ak)
            .field(
                "bundle_b64",
                &self.bundle_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .field("device_count", &self.device_count)
            .field("revoked_count", &self.revoked_count)
            .field("lifecycle_event_count", &self.lifecycle_event_count)
            .finish()
    }
}

impl From<IdentityResult> for FfiIdentityResult {
    fn from(result: IdentityResult) -> Self {
        Self {
            status: identity_status_string(result.status),
            diag: result.diag,
            root_kid: result.root_kid,
            active_ak: result.active_ak,
            bundle_b64: result.bundle_b64,
            device_count: result.device_count,
            revoked_count: result.revoked_count,
            lifecycle_event_count: result.lifecycle_event_count,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiDeviceResult {
    pub status: String,
    pub diag: Vec<String>,
    pub device_ak: Option<String>,
    pub active_ak: Option<String>,
    pub root_kid: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub lifecycle_event_count: u64,
}

impl From<DeviceResult> for FfiDeviceResult {
    fn from(result: DeviceResult) -> Self {
        Self {
            status: device_status_string(result.status),
            diag: result.diag,
            device_ak: result.device_ak,
            active_ak: result.active_ak,
            root_kid: result.root_kid,
            device_count: result.device_count,
            revoked_count: result.revoked_count,
            lifecycle_event_count: result.lifecycle_event_count,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiClientLifecycle {
    pub status: String,
    pub diag: Vec<String>,
    pub root_kid: Option<String>,
    pub active_ak: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub accepted_record_count: u64,
    pub lifecycle_event_count: u64,
}

impl From<ClientLifecycle> for FfiClientLifecycle {
    fn from(result: ClientLifecycle) -> Self {
        Self {
            status: lifecycle_status_string(result.status),
            diag: result.diag,
            root_kid: result.root_kid,
            active_ak: result.active_ak,
            device_count: result.device_count,
            revoked_count: result.revoked_count,
            accepted_record_count: result.accepted_record_count,
            lifecycle_event_count: result.lifecycle_event_count,
        }
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiPairingEnvelopeRequest {
    pub envelope_b64: String,
}

impl fmt::Debug for FfiPairingEnvelopeRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiPairingEnvelopeRequest")
            .field("envelope_b64", &"[REDACTED]")
            .finish()
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiPairingResult {
    pub status: String,
    pub diag: Vec<String>,
    pub pairing_id: Option<String>,
    pub envelope_b64: Option<String>,
    pub root_kid: Option<String>,
    pub device_count: u64,
}

impl From<PairingResult> for FfiPairingResult {
    fn from(result: PairingResult) -> Self {
        Self {
            status: pairing_status_string(result.status),
            diag: result.diag,
            pairing_id: result.pairing_id,
            envelope_b64: result.envelope_b64,
            root_kid: result.root_kid,
            device_count: result.device_count,
        }
    }
}

impl fmt::Debug for FfiPairingResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiPairingResult")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("pairing_id", &self.pairing_id)
            .field(
                "envelope_b64",
                &self.envelope_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .field("root_kid", &self.root_kid)
            .field("device_count", &self.device_count)
            .finish()
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiSyncBundleRequest {
    pub bundle_b64: String,
}

impl fmt::Debug for FfiSyncBundleRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiSyncBundleRequest")
            .field("bundle_b64", &"[REDACTED]")
            .finish()
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct FfiSyncResult {
    pub status: String,
    pub diag: Vec<String>,
    pub bundle_b64: Option<String>,
    pub accepted_record_count: u64,
    pub device_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for FfiSyncResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FfiSyncResult")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field(
                "bundle_b64",
                &self.bundle_b64.as_ref().map(|_| "[REDACTED]"),
            )
            .field("accepted_record_count", &self.accepted_record_count)
            .field("device_count", &self.device_count)
            .field("lifecycle_event_count", &self.lifecycle_event_count)
            .finish()
    }
}

impl From<SyncResult> for FfiSyncResult {
    fn from(result: SyncResult) -> Self {
        Self {
            status: sync_status_string(result.status),
            diag: result.diag,
            bundle_b64: result.bundle_b64,
            accepted_record_count: result.accepted_record_count,
            device_count: result.device_count,
            lifecycle_event_count: result.lifecycle_event_count,
        }
    }
}

fn preview_status_string(status: ScanPreviewStatus) -> String {
    match status {
        ScanPreviewStatus::Verified => "Verified",
        ScanPreviewStatus::Untrusted => "Untrusted",
        ScanPreviewStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn accept_status_string(status: ScanAcceptStatus) -> String {
    match status {
        ScanAcceptStatus::Accepted => "Accepted",
        ScanAcceptStatus::AlreadyAccepted => "AlreadyAccepted",
        ScanAcceptStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn store_snapshot_status_string(status: StoreSnapshotStatus) -> String {
    match status {
        StoreSnapshotStatus::Exported => "Exported",
        StoreSnapshotStatus::Restored => "Restored",
        StoreSnapshotStatus::Empty => "Empty",
        StoreSnapshotStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn identity_status_string(status: IdentityStatus) -> String {
    match status {
        IdentityStatus::Created => "Created",
        IdentityStatus::Exported => "Exported",
        IdentityStatus::Imported => "Imported",
        IdentityStatus::AlreadyExists => "AlreadyExists",
        IdentityStatus::Uninitialized => "Uninitialized",
        IdentityStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn device_status_string(status: DeviceStatus) -> String {
    match status {
        DeviceStatus::Added => "Added",
        DeviceStatus::Revoked => "Revoked",
        DeviceStatus::Active => "Active",
        DeviceStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn lifecycle_status_string(status: ClientLifecycleStatus) -> String {
    match status {
        ClientLifecycleStatus::Ready => "Ready",
        ClientLifecycleStatus::Uninitialized => "Uninitialized",
    }
    .to_string()
}

fn pairing_status_string(status: PairingStatus) -> String {
    match status {
        PairingStatus::Created => "Created",
        PairingStatus::Valid => "Valid",
        PairingStatus::Paired => "Paired",
        PairingStatus::AlreadyPaired => "AlreadyPaired",
        PairingStatus::Rejected => "Rejected",
    }
    .to_string()
}

fn sync_status_string(status: SyncStatus) -> String {
    match status {
        SyncStatus::Exported => "Exported",
        SyncStatus::Empty => "Empty",
        SyncStatus::Imported => "Imported",
        SyncStatus::AlreadyImported => "AlreadyImported",
        SyncStatus::Rejected => "Rejected",
    }
    .to_string()
}
