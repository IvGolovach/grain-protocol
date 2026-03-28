use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum Diag {
    NonCanonical,
    DupMapKey,
    SetArrayOrder,
    SetArrayDup,
    TagForbidden,
    UnknownTopLevelKey,
    BadCidLink,
    CoseProfile,
    CoseTag18Forbidden,
    Schema,
    E2eInputLength,
    E2eBadLabel,
    AeadAuth,
    ManifestOp,
    QrPrefix,
    CborseqTruncated,
    CborseqGarbageTail,
    CborseqInvalidInitialByte,
    Limit,
    Overflow,
    SeqConflict,
    AkRevoked,
    UnauthorizedGrantIgnored,
    CapChashConflict,
    CapIdOverwrite,
    ChashMismatch,
    NonceProfileMismatch,
}

impl Diag {
    pub fn code(&self) -> &'static str {
        match self {
            Self::NonCanonical => "GRAIN_ERR_NONCANONICAL",
            Self::DupMapKey => "GRAIN_ERR_DUP_MAP_KEY",
            Self::SetArrayOrder => "GRAIN_ERR_SET_ARRAY_ORDER",
            Self::SetArrayDup => "GRAIN_ERR_SET_ARRAY_DUP",
            Self::TagForbidden => "GRAIN_ERR_TAG_FORBIDDEN",
            Self::UnknownTopLevelKey => "GRAIN_ERR_UNKNOWN_TOPLEVEL_KEY",
            Self::BadCidLink => "GRAIN_ERR_BAD_CID_LINK",
            Self::CoseProfile => "GRAIN_ERR_COSE_PROFILE",
            Self::CoseTag18Forbidden => "GRAIN_ERR_COSE_TAG18_FORBIDDEN",
            Self::Schema => "GRAIN_ERR_SCHEMA",
            Self::E2eInputLength => "GRAIN_ERR_E2E_INPUT_LENGTH",
            Self::E2eBadLabel => "GRAIN_ERR_E2E_BAD_LABEL",
            Self::AeadAuth => "GRAIN_ERR_AEAD_AUTH",
            Self::ManifestOp => "GRAIN_ERR_MANIFEST_OP",
            Self::QrPrefix => "GRAIN_ERR_QR_PREFIX",
            Self::CborseqTruncated => "GRAIN_ERR_CBORSEQ_TRUNCATED",
            Self::CborseqGarbageTail => "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL",
            Self::CborseqInvalidInitialByte => "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE",
            Self::Limit => "GRAIN_ERR_LIMIT",
            Self::Overflow => "GRAIN_ERR_OVERFLOW",
            Self::SeqConflict => "SEQ_CONFLICT",
            Self::AkRevoked => "AK_REVOKED",
            Self::UnauthorizedGrantIgnored => "UNAUTHORIZED_GRANT_IGNORED",
            Self::CapChashConflict => "CAP_CHASH_CONFLICT",
            Self::CapIdOverwrite => "CAP_ID_OVERWRITE",
            Self::ChashMismatch => "CHASH_MISMATCH",
            Self::NonceProfileMismatch => "NONCE_PROFILE_MISMATCH",
        }
    }
}

impl std::fmt::Display for Diag {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.code())
    }
}

#[derive(Debug, Error)]
pub enum GrainError {
    #[error("{0}")]
    Diag(Diag),
    #[error("internal error: {0}")]
    Internal(String),
}

impl GrainError {
    pub fn from_diag(diag: Diag) -> Self {
        Self::Diag(diag)
    }

    pub fn diag(&self) -> Diag {
        match self {
            Self::Diag(d) => d.clone(),
            Self::Internal(_) => Diag::Schema,
        }
    }
}

pub type GrainResult<T> = Result<T, GrainError>;

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    #[test]
    fn diag_codes_are_unique_and_stable() {
        let variants = [
            Diag::NonCanonical,
            Diag::DupMapKey,
            Diag::SetArrayOrder,
            Diag::SetArrayDup,
            Diag::TagForbidden,
            Diag::UnknownTopLevelKey,
            Diag::BadCidLink,
            Diag::CoseProfile,
            Diag::CoseTag18Forbidden,
            Diag::Schema,
            Diag::E2eInputLength,
            Diag::E2eBadLabel,
            Diag::AeadAuth,
            Diag::ManifestOp,
            Diag::QrPrefix,
            Diag::CborseqTruncated,
            Diag::CborseqGarbageTail,
            Diag::CborseqInvalidInitialByte,
            Diag::Limit,
            Diag::Overflow,
            Diag::SeqConflict,
            Diag::AkRevoked,
            Diag::UnauthorizedGrantIgnored,
            Diag::CapChashConflict,
            Diag::CapIdOverwrite,
            Diag::ChashMismatch,
            Diag::NonceProfileMismatch,
        ];

        let mut seen = BTreeSet::new();
        for diag in &variants {
            assert!(seen.insert(diag.code()), "duplicate diagnostic code: {}", diag.code());
        }

        assert_eq!(variants.len(), seen.len());
        assert_eq!(Diag::SeqConflict.code(), "SEQ_CONFLICT");
        assert_eq!(Diag::UnauthorizedGrantIgnored.code(), "UNAUTHORIZED_GRANT_IGNORED");
        assert_eq!(Diag::NonceProfileMismatch.code(), "NONCE_PROFILE_MISMATCH");
    }
}
