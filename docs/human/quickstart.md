# Quickstart (5 minutes)

Run one working flow first.
Read internals second.

This path uses Docker so you can get a first success without setting up a local Rust toolchain.

## 1) Run the demo pipeline

```bash
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; cargo run -q -p grain-runner -- demo --strict'
```

Expected deterministic output:

```json
{
  "demo_id": "quickstart-v0.1",
  "pass": true,
  "result": {
    "sum_mean": {
      "kcal": 260
    },
    "sum_var": {
      "kcal": 14
    }
  },
  "source_vectors": [
    "POS-QR-001",
    "POS-COSE-001",
    "POS-LED-001"
  ],
  "steps": {
    "append_intake_event": {
      "event": {
        "ak": "dev1",
        "body": {
          "mean": {
            "kcal": 60
          },
          "var": {
            "kcal": 1
          }
        },
        "payload_cid": "cid-intake-demo-3",
        "seq": 3,
        "t": "IntakeEvent"
      },
      "pass": true
    },
    "cose_verify": {
      "diag": [],
      "pass": true
    },
    "ledger_reduce": {
      "diag": [],
      "out": {
        "sum_mean": {
          "kcal": 260
        },
        "sum_var": {
          "kcal": 14
        }
      },
      "pass": true
    },
    "qr_decode_gr1": {
      "cose_bytes_len": 255,
      "diag": [],
      "pass": true
    }
  },
  "strict": true
}
```

The demo uses stable placeholder labels such as `cid-intake-demo-3` for `payload_cid`.
Those are demo identifiers inside the sample ledger, not separately derived protocol-object CIDs.

## 2) What the demo just did

1. Decoded a `GR1:` transport payload.
2. Verified a COSE signature under the narrow profile.
3. Appended one deterministic `IntakeEvent` to a local demo ledger.
4. Reduced ledger state to deterministic totals (`sum_mean`, `sum_var`).

## 3) What the terms mean

- `strict: true`: no permissive fallback behavior was used.
- `GR1:`: the fixed QR transport prefix for Grain v0.1.
- `COSE narrow profile`: the small fixed signature profile Grain uses for deterministic verification.
- `C01`: a small TypeScript smoke profile for byte-path checks. It is not a second protocol mode.

## 4) Choose your next path

- [Build the smallest app with the SDK](./sdk/minimal-app-example.md)
- [Build an app on Grain](./building-on-grain.md)
- [Use the SDK path](./sdk/start-here.md)
- [Implement Grain](./implementing-grain.md)
- [Maintain the repo](./maintainer-start-here.md)
- [Run fast developer verification](./start-here.md#verification-paths)
- [Start-here overview](./start-here.md)

## 5) Deep protocol references

Read these after your first run, not before:

- `conformance/SPEC.md`
- `spec/NES-v0.1.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/EDGE_CASES.md`

## 6) Going deeper

If you are just evaluating Grain, you can stop here.

If you are implementing or testing Grain itself, these TypeScript engine commands are useful:

```bash
npm --prefix runner/typescript run run:c01
npm --prefix runner/typescript run divergence:c01
npm --prefix runner/typescript run run:full
npm --prefix runner/typescript run divergence:full
```

TS now has a full strict engine.
`C01` stays as the smaller smoke profile for byte-path regressions.

If you want the broader local verification pass after this demo, run `./scripts/verify`.
