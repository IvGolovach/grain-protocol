//! Platform adapter contracts for generated client SDKs.
//!
//! These traits and helpers define the Rust-owned behavior expected from
//! platform storage and trust adapters without embedding Keychain, Keystore,
//! SQLite, IndexedDB, network, or device-specific APIs in the core crate.

pub mod storage;
pub mod trust;

pub use storage::{list_accepted_scans, put_accepted_scan_atomically};
pub use trust::{
    resolve_trust_pub_b64, scan_accept_prepare_with_trust_provider,
    scan_accept_with_trust_provider, scan_preview_with_trust_provider, StaticTrustProvider,
    TrustProvider,
};
