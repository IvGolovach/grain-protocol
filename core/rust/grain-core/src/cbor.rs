use std::collections::HashSet;

use crate::error::{Diag, GrainError, GrainResult};
use crate::limits::Limits;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CborValue {
    Unsigned(u64),
    Negative(i128),
    Bytes(Vec<u8>),
    Text(Vec<u8>),
    Array(Vec<CborValue>),
    Map(Vec<(CborValue, CborValue)>),
    Tag(u64, Box<CborValue>),
    Bool(bool),
    Null,
    Undefined,
    Simple(u8),
}

impl CborValue {
    pub fn as_text_bytes(&self) -> Option<&[u8]> {
        match self {
            Self::Text(v) => Some(v.as_slice()),
            _ => None,
        }
    }

    pub fn as_text(&self) -> Option<String> {
        self.as_text_bytes()
            .and_then(|b| String::from_utf8(b.to_vec()).ok())
    }

    pub fn as_bytes(&self) -> Option<&[u8]> {
        match self {
            Self::Bytes(v) => Some(v.as_slice()),
            _ => None,
        }
    }

    pub fn as_map(&self) -> Option<&Vec<(CborValue, CborValue)>> {
        match self {
            Self::Map(m) => Some(m),
            _ => None,
        }
    }

    pub fn map_get(&self, key: &str) -> Option<&CborValue> {
        let map = self.as_map()?;
        for (k, v) in map {
            if let Some(kb) = k.as_text_bytes() {
                if kb == key.as_bytes() {
                    return Some(v);
                }
            }
        }
        None
    }
}

#[derive(Debug, Clone, Copy)]
pub struct ParseOptions {
    pub enforce_canonical: bool,
    pub dag_cbor_strict: bool,
    pub allow_only_tag42: bool,
    pub limits: Limits,
}

impl ParseOptions {
    pub fn strict_dag_cbor() -> Self {
        Self {
            enforce_canonical: true,
            dag_cbor_strict: true,
            allow_only_tag42: true,
            limits: Limits::STRICT_BASELINE,
        }
    }

    pub fn generic_cbor_canonical() -> Self {
        Self {
            enforce_canonical: true,
            dag_cbor_strict: false,
            allow_only_tag42: false,
            limits: Limits::STRICT_BASELINE,
        }
    }

    pub fn generic_cbor_lenient() -> Self {
        Self {
            enforce_canonical: false,
            dag_cbor_strict: false,
            allow_only_tag42: false,
            limits: Limits::STRICT_BASELINE,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParseFail {
    Truncated,
    InvalidInitial,
    Diag(Diag),
}

struct Parser<'a> {
    bytes: &'a [u8],
    pos: usize,
    opts: ParseOptions,
}

impl<'a> Parser<'a> {
    fn new(bytes: &'a [u8], opts: ParseOptions) -> Self {
        Self { bytes, pos: 0, opts }
    }

    fn eof(&self) -> bool {
        self.pos >= self.bytes.len()
    }

    fn read_u8(&mut self) -> Result<u8, ParseFail> {
        if self.pos >= self.bytes.len() {
            return Err(ParseFail::Truncated);
        }
        let b = self.bytes[self.pos];
        self.pos += 1;
        Ok(b)
    }

    fn read_exact(&mut self, n: usize) -> Result<&'a [u8], ParseFail> {
        if self.bytes.len().saturating_sub(self.pos) < n {
            return Err(ParseFail::Truncated);
        }
        let s = &self.bytes[self.pos..self.pos + n];
        self.pos += n;
        Ok(s)
    }

    fn parse_uint_arg(&mut self, ai: u8) -> Result<u64, ParseFail> {
        match ai {
            0..=23 => Ok(ai as u64),
            24 => {
                let v = self.read_u8()? as u64;
                if self.opts.enforce_canonical && v < 24 {
                    return Err(ParseFail::Diag(Diag::NonCanonical));
                }
                Ok(v)
            }
            25 => {
                let b = self.read_exact(2)?;
                let v = u16::from_be_bytes([b[0], b[1]]) as u64;
                if self.opts.enforce_canonical && v <= u8::MAX as u64 {
                    return Err(ParseFail::Diag(Diag::NonCanonical));
                }
                Ok(v)
            }
            26 => {
                let b = self.read_exact(4)?;
                let v = u32::from_be_bytes([b[0], b[1], b[2], b[3]]) as u64;
                if self.opts.enforce_canonical && v <= u16::MAX as u64 {
                    return Err(ParseFail::Diag(Diag::NonCanonical));
                }
                Ok(v)
            }
            27 => {
                let b = self.read_exact(8)?;
                let v = u64::from_be_bytes([b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]]);
                if self.opts.enforce_canonical && v <= u32::MAX as u64 {
                    return Err(ParseFail::Diag(Diag::NonCanonical));
                }
                Ok(v)
            }
            31 => Err(ParseFail::Diag(Diag::NonCanonical)),
            _ => Err(ParseFail::InvalidInitial),
        }
    }

    fn parse_item(&mut self, depth: usize) -> Result<CborValue, ParseFail> {
        if depth > self.opts.limits.max_cbor_nesting_depth {
            return Err(ParseFail::Diag(Diag::Limit));
        }
        if self.eof() {
            return Err(ParseFail::Truncated);
        }
        let initial = self.read_u8()?;
        let major = initial >> 5;
        let ai = initial & 0x1f;

        match major {
            0 => {
                let v = self.parse_uint_arg(ai)?;
                Ok(CborValue::Unsigned(v))
            }
            1 => {
                let v = self.parse_uint_arg(ai)?;
                let n = -1i128 - (v as i128);
                Ok(CborValue::Negative(n))
            }
            2 => {
                let len = self.parse_uint_arg(ai)? as usize;
                let b = self.read_exact(len)?.to_vec();
                Ok(CborValue::Bytes(b))
            }
            3 => {
                let len = self.parse_uint_arg(ai)? as usize;
                if len > self.opts.limits.max_tstr_utf8_bytes {
                    return Err(ParseFail::Diag(Diag::Limit));
                }
                let b = self.read_exact(len)?.to_vec();
                if std::str::from_utf8(&b).is_err() {
                    return Err(ParseFail::Diag(Diag::NonCanonical));
                }
                Ok(CborValue::Text(b))
            }
            4 => {
                let len = self.parse_uint_arg(ai)? as usize;
                if len > self.opts.limits.max_cbor_array_length {
                    return Err(ParseFail::Diag(Diag::Limit));
                }
                let mut out = Vec::with_capacity(len);
                for _ in 0..len {
                    out.push(self.parse_item(depth + 1)?);
                }
                Ok(CborValue::Array(out))
            }
            5 => {
                let len = self.parse_uint_arg(ai)? as usize;
                if len > self.opts.limits.max_cbor_map_pairs {
                    return Err(ParseFail::Diag(Diag::Limit));
                }
                let mut out = Vec::with_capacity(len);
                let mut seen: HashSet<Vec<u8>> = HashSet::with_capacity(len);
                let mut prev_key_encoded: Option<Vec<u8>> = None;

                for _ in 0..len {
                    let key_start = self.pos;
                    let key = self.parse_item(depth + 1)?;
                    let key_end = self.pos;
                    let key_encoded = self.bytes[key_start..key_end].to_vec();

                    if self.opts.dag_cbor_strict && !matches!(key, CborValue::Text(_)) {
                        return Err(ParseFail::Diag(Diag::NonCanonical));
                    }

                    if !seen.insert(key_encoded.clone()) {
                        return Err(ParseFail::Diag(Diag::DupMapKey));
                    }

                    if self.opts.enforce_canonical {
                        if let Some(prev) = &prev_key_encoded {
                            match compare_canonical_map_key(prev, &key_encoded) {
                                std::cmp::Ordering::Greater => {
                                    return Err(ParseFail::Diag(Diag::NonCanonical));
                                }
                                std::cmp::Ordering::Equal => {
                                    return Err(ParseFail::Diag(Diag::DupMapKey));
                                }
                                std::cmp::Ordering::Less => {}
                            }
                        }
                        prev_key_encoded = Some(key_encoded);
                    }

                    let value = self.parse_item(depth + 1)?;
                    out.push((key, value));
                }

                Ok(CborValue::Map(out))
            }
            6 => {
                let tag = self.parse_uint_arg(ai)?;
                if self.opts.allow_only_tag42 && tag != 42 {
                    return Err(ParseFail::Diag(Diag::TagForbidden));
                }
                let inner = self.parse_item(depth + 1)?;
                if self.opts.dag_cbor_strict && tag == 42 {
                    let Some(cid_bstr) = inner.as_bytes() else {
                        return Err(ParseFail::Diag(Diag::BadCidLink));
                    };
                    if cid_bstr.first().copied() != Some(0x00) {
                        return Err(ParseFail::Diag(Diag::BadCidLink));
                    }
                }
                Ok(CborValue::Tag(tag, Box::new(inner)))
            }
            7 => match ai {
                20 => Ok(CborValue::Bool(false)),
                21 => Ok(CborValue::Bool(true)),
                22 => Ok(CborValue::Null),
                23 => Ok(CborValue::Undefined),
                24 => {
                    let v = self.read_u8()?;
                    Ok(CborValue::Simple(v))
                }
                25 | 26 | 27 => {
                    if self.opts.dag_cbor_strict {
                        return Err(ParseFail::Diag(Diag::NonCanonical));
                    }
                    // Consume float bytes for generic parser paths.
                    let n = match ai {
                        25 => 2,
                        26 => 4,
                        _ => 8,
                    };
                    let _ = self.read_exact(n)?;
                    Err(ParseFail::Diag(Diag::NonCanonical))
                }
                31 => Err(ParseFail::Diag(Diag::NonCanonical)),
                v => Ok(CborValue::Simple(v)),
            },
            _ => Err(ParseFail::InvalidInitial),
        }
    }
}

pub fn parse_one(bytes: &[u8], opts: ParseOptions) -> Result<(CborValue, usize), ParseFail> {
    let mut parser = Parser::new(bytes, opts);
    let value = parser.parse_item(0)?;
    Ok((value, parser.pos))
}

pub fn parse_exact(bytes: &[u8], opts: ParseOptions) -> Result<CborValue, ParseFail> {
    let (value, used) = parse_one(bytes, opts)?;
    if used != bytes.len() {
        return Err(ParseFail::Diag(Diag::NonCanonical));
    }
    Ok(value)
}

pub fn parse_exact_to_error(bytes: &[u8], opts: ParseOptions) -> GrainResult<CborValue> {
    parse_exact(bytes, opts).map_err(parse_fail_to_error)
}

pub fn parse_fail_to_error(err: ParseFail) -> GrainError {
    match err {
        ParseFail::Truncated => GrainError::from_diag(Diag::NonCanonical),
        ParseFail::InvalidInitial => GrainError::from_diag(Diag::NonCanonical),
        ParseFail::Diag(d) => GrainError::from_diag(d),
    }
}

pub fn compare_canonical_map_key(a: &[u8], b: &[u8]) -> std::cmp::Ordering {
    a.len().cmp(&b.len()).then_with(|| a.cmp(b))
}

pub fn encode_canonical(value: &CborValue, out: &mut Vec<u8>) {
    match value {
        CborValue::Unsigned(v) => encode_major_u64(0, *v, out),
        CborValue::Negative(v) => {
            let n = (-1i128 - *v) as u64;
            encode_major_u64(1, n, out);
        }
        CborValue::Bytes(b) => {
            encode_major_u64(2, b.len() as u64, out);
            out.extend_from_slice(b);
        }
        CborValue::Text(t) => {
            encode_major_u64(3, t.len() as u64, out);
            out.extend_from_slice(t);
        }
        CborValue::Array(items) => {
            encode_major_u64(4, items.len() as u64, out);
            for item in items {
                encode_canonical(item, out);
            }
        }
        CborValue::Map(entries) => {
            encode_major_u64(5, entries.len() as u64, out);
            let mut tmp: Vec<(Vec<u8>, Vec<u8>)> = Vec::with_capacity(entries.len());
            for (k, v) in entries {
                let mut kb = Vec::new();
                let mut vb = Vec::new();
                encode_canonical(k, &mut kb);
                encode_canonical(v, &mut vb);
                tmp.push((kb, vb));
            }
            tmp.sort_by(|a, b| compare_canonical_map_key(&a.0, &b.0));
            for (k, v) in tmp {
                out.extend_from_slice(&k);
                out.extend_from_slice(&v);
            }
        }
        CborValue::Tag(tag, inner) => {
            encode_major_u64(6, *tag, out);
            encode_canonical(inner, out);
        }
        CborValue::Bool(false) => out.push(0xf4),
        CborValue::Bool(true) => out.push(0xf5),
        CborValue::Null => out.push(0xf6),
        CborValue::Undefined => out.push(0xf7),
        CborValue::Simple(v) => {
            if *v < 24 {
                out.push(0xe0 | *v);
            } else {
                out.push(0xf8);
                out.push(*v);
            }
        }
    }
}

fn encode_major_u64(major: u8, value: u64, out: &mut Vec<u8>) {
    if value <= 23 {
        out.push((major << 5) | (value as u8));
    } else if value <= u8::MAX as u64 {
        out.push((major << 5) | 24);
        out.push(value as u8);
    } else if value <= u16::MAX as u64 {
        out.push((major << 5) | 25);
        out.extend_from_slice(&(value as u16).to_be_bytes());
    } else if value <= u32::MAX as u64 {
        out.push((major << 5) | 26);
        out.extend_from_slice(&(value as u32).to_be_bytes());
    } else {
        out.push((major << 5) | 27);
        out.extend_from_slice(&value.to_be_bytes());
    }
}
