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

#[cfg(test)]
mod tests {
    use super::*;
    use sha2::{Digest, Sha256};

    #[test]
    fn parses_items_in_order_and_hashes_each_item() {
        let bytes = [0x01, 0x02, 0x03];
        let hashes = parse_cborseq_stream(&bytes).unwrap();

        let expected = vec![
            hex::encode(Sha256::digest([0x01])),
            hex::encode(Sha256::digest([0x02])),
            hex::encode(Sha256::digest([0x03])),
        ];

        assert_eq!(hashes, expected);
    }

    #[test]
    fn rejects_truncated_first_item() {
        let err = parse_cborseq_stream(&[0x18]).unwrap_err();
        assert_eq!(err.diag(), Diag::CborseqTruncated);
    }
}
