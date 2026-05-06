use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub(crate) struct PortableTransferCustodyV1 {
    pub custody_v: u32,
    pub material: String,
    pub device_bound: bool,
    pub storage: String,
}

impl PortableTransferCustodyV1 {
    pub(crate) fn pairing_identity_bundle() -> Self {
        Self::new("identity_bundle_v1")
    }

    pub(crate) fn sync_bundle() -> Self {
        Self::new("sync_bundle_v1")
    }

    pub(crate) fn is_portable_transfer_for(&self, material: &str) -> bool {
        self.custody_v == 1
            && self.material == material
            && !self.device_bound
            && self.storage == "app_encrypted_transfer_required"
    }

    fn new(material: &str) -> Self {
        Self {
            custody_v: 1,
            material: material.to_string(),
            device_bound: false,
            storage: "app_encrypted_transfer_required".to_string(),
        }
    }
}
