# Grain v0.1 — QR Transport Profile (GR1)

This document is normative for Grain Protocol v0.1.

## 1. Prefix (MUST)

- Embedded QR payload MUST start with ASCII prefix: `GR1:`
- Decoders MUST accept `GR1:`
- Encoders MUST emit `GR1:`
- Incompatible future QR formats MUST use a new prefix (e.g., `GR2:`)

## 2. Encoding pipeline (MUST)

`GR1:` + Base45( Zlib( COSE_Sign1_BYTES ) )

Notes:
- zlib/deflate output is not required to be byte-identical across implementations.
- Interop criterion is decode + verify + strict validate.

## 3. Payload (ServingOffer)

Embedded QR payload MUST be a COSE_Sign1 whose payload is a strict DAG-CBOR `ServingOffer` object (see CDDL).

ServingOffer is a short summary by design.
Full object graphs MUST be distributed via pointer/fetch mechanisms (out of scope for GR1 embedded mode).

## 4. Error handling (MUST)

- Wrong prefix -> reject.
- Base45 decode failure -> reject.
- zlib inflate failure -> reject.
- COSE profile violation -> reject.
- Non-canonical DAG-CBOR payload -> reject.

## 5. Size guidance (SHOULD)

Implementations SHOULD target:
- ServingOffer payload <= CBL_MAX_SERVINGOFFER_PAYLOAD_BYTES (see CBOR profile)
- QR error correction level Q

These are interoperability/scannability targets, not protocol correctness constraints.

