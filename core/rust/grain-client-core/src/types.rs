use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, fmt};

/// Preview status for a scanned transport payload.
///
/// `Untrusted` means the transport decoded successfully, but the caller did
/// not provide trust material. Verification failures are explicit rejections.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanPreviewStatus {
    Verified,
    Untrusted,
    Rejected,
}

/// Pure scan preview output for client SDKs.
///
/// This type is intentionally FFI-friendly: platform bindings can expose the
/// status, deterministic diag strings, and optional COSE bytes without exposing
/// raw protocol runner operations to app developers.
#[derive(Clone, PartialEq, Eq)]
pub struct ScanPreview {
    pub status: ScanPreviewStatus,
    pub diag: Vec<String>,
    pub cose_b64: Option<String>,
}

impl ScanPreview {
    pub(crate) fn verified(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Verified,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    pub(crate) fn untrusted(cose: &[u8]) -> Self {
        Self {
            status: ScanPreviewStatus::Untrusted,
            diag: Vec::new(),
            cose_b64: Some(STANDARD.encode(cose)),
        }
    }

    pub(crate) fn rejected(diag: impl Into<String>, cose_b64: Option<String>) -> Self {
        Self {
            status: ScanPreviewStatus::Rejected,
            diag: vec![diag.into()],
            cose_b64,
        }
    }
}

impl fmt::Debug for ScanPreview {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ScanPreview")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field("cose_b64", &self.cose_b64.as_ref().map(|_| "[REDACTED]"))
            .finish()
    }
}

/// Request DTO for generated SDK scan-accept workflows.
#[derive(Clone, PartialEq, Eq)]
pub struct ScanAcceptRequest {
    pub qr_string: String,
    pub trust_pub_b64: String,
}

impl fmt::Debug for ScanAcceptRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ScanAcceptRequest")
            .field("qr_string", &self.qr_string)
            .field("trust_pub_b64", &"[REDACTED]")
            .finish()
    }
}

/// Accept status for a scanned transport payload.
///
/// `Accepted` means the scan has been verified and normalized into a
/// persistence-ready record. Store mutation starts in the `scan_accept`
/// workflow; `scan_accept_prepare` itself remains pure.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScanAcceptStatus {
    /// Verified and normalized into a persistence-ready record.
    Accepted,
    /// The same verified scan was already present in client storage.
    AlreadyAccepted,
    /// Rejected before any persistence-ready record exists.
    Rejected,
}

/// Verified scan record prepared for later atomic persistence.
#[derive(Clone, PartialEq, Eq)]
pub struct AcceptedScan {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

impl fmt::Debug for AcceptedScan {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AcceptedScan")
            .field("scan_id", &self.scan_id)
            .field("cose_b64", &"[REDACTED]")
            .field("trust_pub_b64", &"[REDACTED]")
            .finish()
    }
}

/// Persisted accepted scan record.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AcceptedScanRecord {
    pub scan_id: String,
    pub cose_b64: String,
    pub trust_pub_b64: String,
}

impl fmt::Debug for AcceptedScanRecord {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AcceptedScanRecord")
            .field("scan_id", &self.scan_id)
            .field("cose_b64", &"[REDACTED]")
            .field("trust_pub_b64", &"[REDACTED]")
            .finish()
    }
}

impl From<AcceptedScan> for AcceptedScanRecord {
    fn from(accepted: AcceptedScan) -> Self {
        Self {
            scan_id: accepted.scan_id,
            cose_b64: accepted.cose_b64,
            trust_pub_b64: accepted.trust_pub_b64,
        }
    }
}

/// Device authorization key tracked by the portable client lifecycle.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceKey {
    pub ak: String,
    pub label: String,
    pub pub_b64: String,
}

/// Portable identity bundle shared by generated SDKs.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IdentityBundleV1 {
    pub bundle_v: u32,
    pub root_kid: String,
    pub root_pub_b64: String,
    pub active_ak: String,
    pub device_keys: Vec<DeviceKey>,
    pub revoked_aks: Vec<String>,
    pub sync_secret_b64: String,
    pub seq_state: BTreeMap<String, String>,
}

impl fmt::Debug for IdentityBundleV1 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("IdentityBundleV1")
            .field("bundle_v", &self.bundle_v)
            .field("root_kid", &self.root_kid)
            .field("root_pub_b64", &self.root_pub_b64)
            .field("active_ak", &self.active_ak)
            .field("device_keys", &self.device_keys)
            .field("revoked_aks", &self.revoked_aks)
            .field("sync_secret_b64", &"[REDACTED]")
            .field("seq_state", &self.seq_state)
            .finish()
    }
}

/// SDK lifecycle record used to keep generated-client authorization history
/// synchronized with local identity state.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LifecycleEventRecord {
    pub event_id: String,
    pub t: String,
    pub ak: String,
    pub seq: u64,
    pub payload_cid: String,
    pub target_ak: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StoreSnapshotStatus {
    Exported,
    Restored,
    Empty,
    Rejected,
}

#[derive(Clone, PartialEq, Eq)]
pub struct StoreSnapshotResult {
    pub status: StoreSnapshotStatus,
    pub diag: Vec<String>,
    pub snapshot_b64: Option<String>,
    pub accepted_record_count: u64,
    pub device_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for StoreSnapshotResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("StoreSnapshotResult")
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum IdentityStatus {
    Created,
    Exported,
    Imported,
    AlreadyExists,
    Uninitialized,
    Rejected,
}

#[derive(Clone, PartialEq, Eq)]
pub struct IdentityResult {
    pub status: IdentityStatus,
    pub diag: Vec<String>,
    pub root_kid: Option<String>,
    pub active_ak: Option<String>,
    pub bundle_b64: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for IdentityResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("IdentityResult")
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeviceStatus {
    Added,
    Revoked,
    Active,
    Rejected,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceResult {
    pub status: DeviceStatus,
    pub diag: Vec<String>,
    pub device_ak: Option<String>,
    pub active_ak: Option<String>,
    pub root_kid: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub lifecycle_event_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClientLifecycleStatus {
    Ready,
    Uninitialized,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientLifecycle {
    pub status: ClientLifecycleStatus,
    pub diag: Vec<String>,
    pub root_kid: Option<String>,
    pub active_ak: Option<String>,
    pub device_count: u64,
    pub revoked_count: u64,
    pub accepted_record_count: u64,
    pub lifecycle_event_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PairingStatus {
    Created,
    Valid,
    Paired,
    AlreadyPaired,
    Rejected,
}

#[derive(Clone, PartialEq, Eq)]
pub struct PairingResult {
    pub status: PairingStatus,
    pub diag: Vec<String>,
    pub pairing_id: Option<String>,
    pub envelope_b64: Option<String>,
    pub root_kid: Option<String>,
    pub device_count: u64,
}

impl fmt::Debug for PairingResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PairingResult")
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SyncStatus {
    Exported,
    Empty,
    Imported,
    AlreadyImported,
    Rejected,
}

#[derive(Clone, PartialEq, Eq)]
pub struct SyncResult {
    pub status: SyncStatus,
    pub diag: Vec<String>,
    pub bundle_b64: Option<String>,
    pub accepted_record_count: u64,
    pub device_count: u64,
    pub lifecycle_event_count: u64,
}

impl fmt::Debug for SyncResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SyncResult")
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

impl From<AcceptedScanRecord> for AcceptedScan {
    fn from(record: AcceptedScanRecord) -> Self {
        Self {
            scan_id: record.scan_id,
            cose_b64: record.cose_b64,
            trust_pub_b64: record.trust_pub_b64,
        }
    }
}

/// Pure scan-accept preparation output.
#[derive(Clone, PartialEq, Eq)]
pub struct ScanAccept {
    pub status: ScanAcceptStatus,
    pub diag: Vec<String>,
    pub accepted: Option<AcceptedScan>,
}

impl ScanAccept {
    pub(crate) fn accepted(accepted: AcceptedScan) -> Self {
        Self {
            status: ScanAcceptStatus::Accepted,
            diag: Vec::new(),
            accepted: Some(accepted),
        }
    }

    pub(crate) fn already_accepted(accepted: AcceptedScan) -> Self {
        Self {
            status: ScanAcceptStatus::AlreadyAccepted,
            diag: Vec::new(),
            accepted: Some(accepted),
        }
    }

    pub(crate) fn rejected(diag: impl Into<String>) -> Self {
        Self {
            status: ScanAcceptStatus::Rejected,
            diag: vec![diag.into()],
            accepted: None,
        }
    }
}

impl fmt::Debug for ScanAccept {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ScanAccept")
            .field("status", &self.status)
            .field("diag", &self.diag)
            .field(
                "accepted",
                &self
                    .accepted
                    .as_ref()
                    .map(|accepted| (&accepted.scan_id, "[REDACTED]")),
            )
            .finish()
    }
}
