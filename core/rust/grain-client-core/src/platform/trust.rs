use std::collections::{BTreeMap, BTreeSet};

use serde::Deserialize;

use crate::diag::{
    SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID, SDK_ERR_TRUST_ANCHOR_NOT_FOUND,
    SDK_ERR_TRUST_ANCHOR_REQUIRED,
};
use crate::scan::{scan_accept, scan_accept_prepare, scan_preview};
use crate::store::ClientStore;
use crate::trust::decode_trust_pub_b64;
use crate::types::{ScanAccept, ScanPreview};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustAnchorBundleV1 {
    bundle_v: u32,
    anchors: Vec<TrustAnchorV1>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustAnchorV1 {
    id: String,
    trust_pub_b64: String,
}

/// Platform-neutral trust lookup contract.
///
/// Implementations return explicit base64 trust material for a caller-provided
/// anchor ID, or `None` when the anchor is unknown. The Rust core never performs
/// hidden fallback lookup or network trust discovery.
pub trait TrustProvider {
    fn trust_pub_b64(&self, anchor_id: &str) -> Option<String>;
}

/// In-memory trust provider for contract tests and reference examples.
#[derive(Debug, Clone, Default)]
pub struct StaticTrustProvider {
    anchors: BTreeMap<String, String>,
}

impl StaticTrustProvider {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn from_bundle_json(bundle_json: &str) -> Result<Self, &'static str> {
        let bundle: TrustAnchorBundleV1 =
            serde_json::from_str(bundle_json).map_err(|_| SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID)?;
        if bundle.bundle_v != 1 || bundle.anchors.is_empty() {
            return Err(SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID);
        }

        let mut seen = BTreeSet::new();
        let mut provider = Self::new();
        for anchor in bundle.anchors {
            if anchor.id.is_empty()
                || anchor.id.trim() != anchor.id
                || !seen.insert(anchor.id.clone())
                || decode_trust_pub_b64(&anchor.trust_pub_b64).is_err()
            {
                return Err(SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID);
            }
            provider = provider.with_anchor(anchor.id, anchor.trust_pub_b64);
        }

        Ok(provider)
    }

    pub fn with_anchor(
        mut self,
        anchor_id: impl Into<String>,
        trust_pub_b64: impl Into<String>,
    ) -> Self {
        self.anchors.insert(anchor_id.into(), trust_pub_b64.into());
        self
    }
}

impl TrustProvider for StaticTrustProvider {
    fn trust_pub_b64(&self, anchor_id: &str) -> Option<String> {
        self.anchors.get(anchor_id).cloned()
    }
}

/// Resolve and validate explicit trust material from a platform provider.
pub fn resolve_trust_pub_b64<P: TrustProvider>(
    provider: &P,
    anchor_id: Option<&str>,
) -> Result<String, &'static str> {
    let Some(anchor_id) = anchor_id else {
        return Err(SDK_ERR_TRUST_ANCHOR_REQUIRED);
    };
    if anchor_id.trim().is_empty() {
        return Err(SDK_ERR_TRUST_ANCHOR_REQUIRED);
    }

    let trust_pub_b64 = provider
        .trust_pub_b64(anchor_id)
        .ok_or(SDK_ERR_TRUST_ANCHOR_NOT_FOUND)?;
    decode_trust_pub_b64(&trust_pub_b64)?;

    Ok(trust_pub_b64)
}

/// Resolve trust from a platform provider, then run the pure scan-preview flow.
pub fn scan_preview_with_trust_provider<P: TrustProvider>(
    qr_string: &str,
    trust_anchor_id: Option<&str>,
    trust_provider: &P,
) -> ScanPreview {
    match resolve_trust_pub_b64(trust_provider, trust_anchor_id) {
        Ok(trust_pub_b64) => scan_preview(qr_string, Some(&trust_pub_b64)),
        Err(diag) => ScanPreview::rejected(diag, None),
    }
}

/// Resolve trust from a platform provider, then run pure scan-accept preparation.
pub fn scan_accept_prepare_with_trust_provider<P: TrustProvider>(
    qr_string: &str,
    trust_anchor_id: Option<&str>,
    trust_provider: &P,
) -> ScanAccept {
    match resolve_trust_pub_b64(trust_provider, trust_anchor_id) {
        Ok(trust_pub_b64) => scan_accept_prepare(qr_string, Some(&trust_pub_b64)),
        Err(diag) => ScanAccept::rejected(diag),
    }
}

/// Resolve trust from a platform provider, then run the core scan-accept flow.
pub fn scan_accept_with_trust_provider<S: ClientStore, P: TrustProvider>(
    store: &mut S,
    qr_string: &str,
    trust_anchor_id: Option<&str>,
    trust_provider: &P,
) -> ScanAccept {
    match resolve_trust_pub_b64(trust_provider, trust_anchor_id) {
        Ok(trust_pub_b64) => scan_accept(store, qr_string, Some(&trust_pub_b64)),
        Err(diag) => ScanAccept::rejected(diag),
    }
}
