use sha2::{Digest, Sha256};

use crate::cbor::{parse_one, ParseFail, ParseOptions};
use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;

pub fn parse_cborseq_stream(bytes: &[u8]) -> GrainResult<Vec<String>> {
    if bytes.len() > Limits::STRICT_BASELINE.max_cborseq_segment_bytes {
        return Err(GrainError::from_diag(Diag::Limit));
    }

    if bytes.is_empty() {
        return Ok(Vec::new());
    }

    let mut pos = 0usize;
    let mut out = Vec::new();

    while pos < bytes.len() {
        let rem = &bytes[pos..];
        match parse_one(rem, ParseOptions::generic_cbor_lenient()) {
            Ok((_value, used)) => {
                if used == 0 {
                    return Err(GrainError::from_diag(if pos == 0 {
                        Diag::CborseqInvalidInitialByte
                    } else {
                        Diag::CborseqGarbageTail
                    }));
                }
                let item = &bytes[pos..pos + used];
                let hash = Sha256::digest(item);
                out.push(hex::encode(hash));
                pos += used;

                if out.len() > Limits::STRICT_BASELINE.max_cborseq_segment_items {
                    return Err(GrainError::from_diag(Diag::Limit));
                }
            }
            Err(ParseFail::Truncated) => {
                return Err(GrainError::from_diag(Diag::CborseqTruncated));
            }
            Err(ParseFail::InvalidInitial) => {
                return Err(GrainError::from_diag(if pos == 0 {
                    Diag::CborseqInvalidInitialByte
                } else {
                    Diag::CborseqGarbageTail
                }));
            }
            Err(ParseFail::Diag(_)) => {
                return Err(GrainError::from_diag(if pos == 0 {
                    Diag::CborseqInvalidInitialByte
                } else {
                    Diag::CborseqGarbageTail
                }));
            }
        }
    }

    Ok(out)
}
