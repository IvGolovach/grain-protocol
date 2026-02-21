#[derive(Debug, Clone, Copy)]
pub struct Limits {
    pub max_cbor_nesting_depth: usize,
    pub max_cbor_map_pairs: usize,
    pub max_cbor_array_length: usize,
    pub max_tstr_utf8_bytes: usize,
    pub max_dagcbor_object_bytes: usize,
    pub max_ext_canonical_bytes: usize,
    pub max_crit_entries: usize,
    pub max_crit_total_utf8_bytes: usize,
    pub max_ledger_event_payload_bytes: usize,
    pub max_manifest_record_payload_bytes: usize,
    pub max_servingoffer_payload_bytes: usize,
    pub max_e2e_ciphertext_bytes: usize,
    pub max_cborseq_segment_bytes: usize,
    pub max_cborseq_segment_items: usize,
}

impl Limits {
    pub const STRICT_BASELINE: Limits = Limits {
        max_cbor_nesting_depth: 32,
        max_cbor_map_pairs: 4096,
        max_cbor_array_length: 4096,
        max_tstr_utf8_bytes: 1024,
        max_dagcbor_object_bytes: 5_000_000,
        max_ext_canonical_bytes: 65_536,
        max_crit_entries: 64,
        max_crit_total_utf8_bytes: 4096,
        max_ledger_event_payload_bytes: 32_768,
        max_manifest_record_payload_bytes: 8_192,
        max_servingoffer_payload_bytes: 2_048,
        max_e2e_ciphertext_bytes: 8_000_000,
        max_cborseq_segment_bytes: 64_000_000,
        max_cborseq_segment_items: 1_000_000,
    };
}

#[derive(Debug, Clone, Copy)]
pub struct StrictMode {
    pub enabled: bool,
}

impl StrictMode {
    pub fn required() -> Self {
        Self { enabled: true }
    }
}
