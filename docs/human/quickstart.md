# Quickstart (5 minutes)

Run one deterministic end-to-end pipeline first. Read internals second.

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

## 2) What the demo actually did

1. Decoded `GR1:` transport payload.
2. Verified COSE signature under narrow profile.
3. Appended one deterministic `IntakeEvent` to a local demo ledger.
4. Reduced ledger state to deterministic totals (`sum_mean`, `sum_var`).

## 3) Choose your next path

- [Build an app on Grain](./building-on-grain.md)
- [Implement Grain](./implementing-grain.md)
- [Run fast developer verification](./start-here.md#verification-paths)
- [Start-here overview](./start-here.md)

## 4) Deep protocol references (after first run)

- `conformance/SPEC.md`
- `spec/NES-v0.1.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/EDGE_CASES.md`

## 5) TS full engine and C01 smoke

```bash
npm --prefix runner/typescript run run:c01
npm --prefix runner/typescript run divergence:c01
npm --prefix runner/typescript run run:full
npm --prefix runner/typescript run divergence:full
```

TS now has a full strict engine. C01 remains the Wave A byte-path profile for focused drift checks.
