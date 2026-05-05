use grain_client_core::{
    ClientLifecycleStatus, PairingStatus, ScanAcceptStatus, ScanPreviewStatus, SyncStatus,
};
use serde::Deserialize;
use std::fs;
use std::path::{Component, Path, PathBuf};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowFixture {
    pub fixture_id: String,
    pub workflow: WorkflowName,
    pub strict: bool,
    pub input: WorkflowInput,
    pub expect: WorkflowExpect,
    pub meta: WorkflowMeta,
}

#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum WorkflowName {
    ScanPreview,
    ScanAccept,
    DeviceLifecycle,
    Pairing,
    SyncBundle,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowInput {
    pub qr_string_ref: Option<String>,
    pub trust_pub_b64_ref: Option<String>,
    pub trust_pub_b64: Option<String>,
    pub accept_attempts: Option<usize>,
    pub import_attempts: Option<usize>,
    pub root_label: Option<String>,
    pub device_label: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowExpect {
    pub status: ExpectedStatus,
    pub diag: Option<Vec<String>>,
    pub diag_contains: Option<Vec<String>>,
    pub cose_b64: Option<CosePresence>,
    pub store_mutation: Option<StoreMutation>,
    pub accepted_record_count: Option<usize>,
    pub device_count: Option<u64>,
    pub revoked_count: Option<u64>,
    pub lifecycle_event_count: Option<u64>,
    pub root_kid: Option<Presence>,
    pub active_ak: Option<Presence>,
    pub device_ak: Option<Presence>,
    pub pairing_id: Option<Presence>,
    pub envelope_b64: Option<Presence>,
    pub bundle_b64: Option<Presence>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowMeta {
    pub desc: String,
}

#[derive(Debug, Deserialize)]
pub enum ExpectedStatus {
    Verified,
    Untrusted,
    Accepted,
    AlreadyAccepted,
    Created,
    Valid,
    Paired,
    AlreadyPaired,
    Ready,
    Uninitialized,
    Exported,
    Empty,
    Imported,
    AlreadyImported,
    Rejected,
}

impl ExpectedStatus {
    pub fn as_preview_status(&self) -> ScanPreviewStatus {
        match self {
            Self::Verified => ScanPreviewStatus::Verified,
            Self::Untrusted => ScanPreviewStatus::Untrusted,
            Self::Rejected => ScanPreviewStatus::Rejected,
            Self::Accepted
            | Self::AlreadyAccepted
            | Self::Created
            | Self::Valid
            | Self::Paired
            | Self::AlreadyPaired
            | Self::Ready
            | Self::Uninitialized
            | Self::Exported
            | Self::Empty
            | Self::Imported
            | Self::AlreadyImported => {
                panic!("invalid status used for as_preview_status")
            }
        }
    }

    pub fn as_accept_status(&self) -> ScanAcceptStatus {
        match self {
            Self::Accepted => ScanAcceptStatus::Accepted,
            Self::AlreadyAccepted => ScanAcceptStatus::AlreadyAccepted,
            Self::Rejected => ScanAcceptStatus::Rejected,
            Self::Verified
            | Self::Untrusted
            | Self::Created
            | Self::Valid
            | Self::Paired
            | Self::AlreadyPaired
            | Self::Ready
            | Self::Uninitialized
            | Self::Exported
            | Self::Empty
            | Self::Imported
            | Self::AlreadyImported => {
                panic!("invalid status used for as_accept_status")
            }
        }
    }

    pub fn as_lifecycle_status(&self) -> ClientLifecycleStatus {
        match self {
            Self::Ready => ClientLifecycleStatus::Ready,
            Self::Uninitialized => ClientLifecycleStatus::Uninitialized,
            _ => panic!("non-lifecycle status used for device_lifecycle"),
        }
    }

    pub fn as_pairing_status(&self) -> PairingStatus {
        match self {
            Self::Created => PairingStatus::Created,
            Self::Valid => PairingStatus::Valid,
            Self::Paired => PairingStatus::Paired,
            Self::AlreadyPaired => PairingStatus::AlreadyPaired,
            Self::Rejected => PairingStatus::Rejected,
            _ => panic!("non-pairing status used for pairing"),
        }
    }

    pub fn as_sync_status(&self) -> SyncStatus {
        match self {
            Self::Exported => SyncStatus::Exported,
            Self::Empty => SyncStatus::Empty,
            Self::Imported => SyncStatus::Imported,
            Self::AlreadyImported => SyncStatus::AlreadyImported,
            Self::Rejected => SyncStatus::Rejected,
            _ => panic!("non-sync status used for sync_bundle"),
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CosePresence {
    Present,
    Absent,
}

#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum StoreMutation {
    None,
    AcceptedScanInserted,
}

#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Presence {
    Present,
    Absent,
}

pub fn load_scan_preview_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("scan-preview")
}

pub fn load_scan_accept_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("scan-accept")
}

pub fn load_device_lifecycle_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("device-lifecycle")
}

pub fn load_pairing_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("pairing")
}

pub fn load_sync_bundle_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("sync-bundle")
}

fn load_workflow_fixtures(workflow_dir: &str) -> Result<Vec<WorkflowFixture>, String> {
    let fixture_dir = repo_root()
        .join("sdk/workflows/fixtures")
        .join(workflow_dir);
    let mut paths = fs::read_dir(&fixture_dir)
        .map_err(|err| format!("read {}: {err}", fixture_dir.display()))?
        .map(|entry| {
            entry
                .map(|entry| entry.path())
                .map_err(|err| err.to_string())
        })
        .collect::<Result<Vec<_>, _>>()?;

    paths.retain(|path| path.extension().and_then(|ext| ext.to_str()) == Some("json"));
    paths.sort();

    let mut fixtures = Vec::with_capacity(paths.len());
    for path in paths {
        let text =
            fs::read_to_string(&path).map_err(|err| format!("read {}: {err}", path.display()))?;
        let fixture = serde_json::from_str::<WorkflowFixture>(&text)
            .map_err(|err| format!("parse {}: {err}", path.display()))?;
        fixtures.push(fixture);
    }

    Ok(fixtures)
}

pub fn resolve_string_ref(reference: &str) -> Result<String, String> {
    let (file_part, pointer) = reference
        .split_once("#/")
        .ok_or_else(|| format!("reference must contain JSON pointer: {reference}"))?;

    let relative = Path::new(file_part);
    if relative.is_absolute()
        || relative
            .components()
            .any(|component| matches!(component, Component::ParentDir))
    {
        return Err(format!("reference escapes repository root: {reference}"));
    }

    let root = repo_root();
    let vectors_root = root
        .join("conformance/vectors")
        .canonicalize()
        .map_err(|err| format!("canonicalize conformance/vectors: {err}"))?;
    let target = root
        .join(relative)
        .canonicalize()
        .map_err(|err| format!("canonicalize {file_part}: {err}"))?;

    if !target.starts_with(&vectors_root) {
        return Err(format!(
            "reference must stay under conformance/vectors: {reference}"
        ));
    }

    let text =
        fs::read_to_string(&target).map_err(|err| format!("read {}: {err}", target.display()))?;
    let mut node = serde_json::from_str::<serde_json::Value>(&text)
        .map_err(|err| format!("parse {}: {err}", target.display()))?;

    for raw_part in pointer.split('/') {
        let part = raw_part.replace("~1", "/").replace("~0", "~");
        node = node
            .get(&part)
            .cloned()
            .ok_or_else(|| format!("missing JSON pointer segment {part:?} in {reference}"))?;
    }

    node.as_str()
        .map(ToOwned::to_owned)
        .ok_or_else(|| format!("reference must point to a string: {reference}"))
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .expect("repo root must canonicalize from grain-client-core")
}
