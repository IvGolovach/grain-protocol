use std::collections::BTreeMap;
use std::io::Read;

use flate2::read::ZlibDecoder;

use crate::error::{Diag, GrainError, GrainResult};

const PREFIX: &str = "GR1:";
const B45_ALPHABET: &str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
pub const MAX_GR1_COSE_BYTES: usize = 16 * 1024;

pub fn decode_gr1_to_cose(qr: &str) -> GrainResult<Vec<u8>> {
    if !qr.starts_with(PREFIX) {
        return Err(GrainError::from_diag(Diag::QrPrefix));
    }

    let payload = &qr[PREFIX.len()..];
    let b45 = base45_decode(payload).map_err(|_| GrainError::from_diag(Diag::Schema))?;

    let z = ZlibDecoder::new(b45.as_slice());
    let mut limited = z.take((MAX_GR1_COSE_BYTES as u64) + 1);
    let mut out = Vec::new();
    limited
        .read_to_end(&mut out)
        .map_err(|_| GrainError::from_diag(Diag::Schema))?;
    if out.is_empty() {
        return Err(GrainError::from_diag(Diag::Schema));
    }
    if out.len() > MAX_GR1_COSE_BYTES {
        return Err(GrainError::from_diag(Diag::Limit));
    }

    Ok(out)
}

fn base45_decode(s: &str) -> Result<Vec<u8>, ()> {
    if s.is_empty() {
        return Ok(Vec::new());
    }

    let mut table = BTreeMap::new();
    for (i, c) in B45_ALPHABET.chars().enumerate() {
        table.insert(c, i as u32);
    }

    let chars: Vec<char> = s.chars().collect();
    let mut out = Vec::new();
    let mut i = 0usize;

    while i < chars.len() {
        let remain = chars.len() - i;
        if remain >= 3 {
            let c0 = *table.get(&chars[i]).ok_or(())?;
            let c1 = *table.get(&chars[i + 1]).ok_or(())?;
            let c2 = *table.get(&chars[i + 2]).ok_or(())?;
            let v = c0 + c1 * 45 + c2 * 45 * 45;
            if v > 65535 {
                return Err(());
            }
            out.push((v / 256) as u8);
            out.push((v % 256) as u8);
            i += 3;
        } else if remain == 2 {
            let c0 = *table.get(&chars[i]).ok_or(())?;
            let c1 = *table.get(&chars[i + 1]).ok_or(())?;
            let v = c0 + c1 * 45;
            if v > 255 {
                return Err(());
            }
            out.push(v as u8);
            i += 2;
        } else {
            return Err(());
        }
    }

    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    use flate2::write::ZlibEncoder;
    use flate2::Compression;

    #[test]
    fn rejects_invalid_base45_body() {
        let err = decode_gr1_to_cose("GR1:0?").expect_err("invalid Base45 must reject");
        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn rejects_invalid_zlib_body_that_yields_empty_output() {
        let err = decode_gr1_to_cose("GR1:00").expect_err("invalid zlib payload must reject");
        assert_eq!(err.diag(), Diag::Schema);
    }

    #[test]
    fn rejects_zlib_output_above_gr1_cose_limit() {
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::best());
        encoder
            .write_all(&vec![0u8; MAX_GR1_COSE_BYTES + 1])
            .expect("test zlib write must succeed");
        let compressed = encoder.finish().expect("test zlib finish must succeed");
        let qr = format!("GR1:{}", base45_encode(&compressed));

        let err = decode_gr1_to_cose(&qr).expect_err("oversized zlib output must reject");

        assert_eq!(err.diag(), Diag::Limit);
    }

    fn base45_encode(bytes: &[u8]) -> String {
        let alphabet = B45_ALPHABET.as_bytes();
        let mut out = String::new();
        let mut chunks = bytes.chunks_exact(2);

        for chunk in &mut chunks {
            let value = u16::from_be_bytes([chunk[0], chunk[1]]) as usize;
            out.push(alphabet[value % 45] as char);
            out.push(alphabet[(value / 45) % 45] as char);
            out.push(alphabet[value / (45 * 45)] as char);
        }

        if let Some(&byte) = chunks.remainder().first() {
            let value = byte as usize;
            out.push(alphabet[value % 45] as char);
            out.push(alphabet[value / 45] as char);
        }

        out
    }
}
