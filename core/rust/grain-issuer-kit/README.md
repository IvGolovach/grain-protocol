# Grain Issuer Kit

Reference issuer path for scanner examples. It creates a signed `GR1:` QR
payload plus the public trust material needed by `grain-client-core`.

The CLI generates an ephemeral Ed25519 issuer key for each run and prints only:

- `qr_string`
- `trust_pub_b64`
- `issuer_kid_b64`
- `cose_b64`

It does not persist or print private signing material.

## Run

```bash
cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty
```

To sign your own strict DAG-CBOR payload bytes:

```bash
cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- \
  --payload-b64 "$PAYLOAD_B64" \
  --pretty
```

The emitted `trust_pub_b64` is the explicit trust material expected by scanner
examples and generated client SDK wrappers. No hidden trust discovery is
performed.
