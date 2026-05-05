use grain_client_core::{ScanAcceptStatus, ScanPreviewStatus};
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
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowInput {
    pub qr_string_ref: String,
    pub trust_pub_b64_ref: Option<String>,
    pub trust_pub_b64: Option<String>,
    pub accept_attempts: Option<usize>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkflowExpect {
    pub status: ExpectedStatus,
    pub diag: Option<Vec<String>>,
    pub diag_contains: Option<Vec<String>>,
    pub cose_b64: CosePresence,
    pub store_mutation: StoreMutation,
    pub accepted_record_count: Option<usize>,
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
    Rejected,
}

impl ExpectedStatus {
    pub fn as_preview_status(&self) -> ScanPreviewStatus {
        match self {
            Self::Verified => ScanPreviewStatus::Verified,
            Self::Untrusted => ScanPreviewStatus::Untrusted,
            Self::Rejected => ScanPreviewStatus::Rejected,
            Self::Accepted | Self::AlreadyAccepted => {
                panic!("scan_accept status used for scan_preview")
            }
        }
    }

    pub fn as_accept_status(&self) -> ScanAcceptStatus {
        match self {
            Self::Accepted => ScanAcceptStatus::Accepted,
            Self::AlreadyAccepted => ScanAcceptStatus::AlreadyAccepted,
            Self::Rejected => ScanAcceptStatus::Rejected,
            Self::Verified | Self::Untrusted => {
                panic!("scan_preview status used for scan_accept")
            }
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

pub fn load_scan_preview_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("scan-preview")
}

pub fn load_scan_accept_fixtures() -> Result<Vec<WorkflowFixture>, String> {
    load_workflow_fixtures("scan-accept")
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
