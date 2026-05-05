use base64::engine::general_purpose::STANDARD;
use base64::Engine;

use crate::diag::SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID;

pub(crate) fn decode_trust_pub_b64(trust_pub_b64: &str) -> Result<Vec<u8>, &'static str> {
    if trust_pub_b64.trim().is_empty() {
        return Err(SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID);
    }

    let bytes = STANDARD
        .decode(trust_pub_b64)
        .map_err(|_| SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID)?;
    if bytes.is_empty() {
        return Err(SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID);
    }

    Ok(bytes)
}
