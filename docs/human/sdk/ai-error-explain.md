# SDK AI Explain Contract

AI boundary rejections return deterministic structured explain payloads.

## Fields

- `code`
- `category`
- `summary`
- `likely_causes[]`
- `how_to_fix[]`
- `spec_refs[]`
- `invariant_refs[]`
- `vector_refs[]`
- `normalization_applied[]`
- `redaction_policy`

## Determinism requirements

- `code` and `category` are deterministic for same input.
- Explain skeleton fields are stable for same rejection class.
- Free-text variability is intentionally minimized.

## Redaction defaults

By default:

- no raw candidate bytes
- no plaintext private bytes
- no large raw payload excerpts

Sensitive details may be opt-in, never default.

In sensitive mode, SDK still does not emit raw candidate/private bytes.
Only bounded metadata is allowed (for example short hashes, lengths, token prefix).
