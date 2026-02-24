#!/usr/bin/env python3
"""Spec drift checks for frozen-core anchors.

This is still lightweight (not semantic equivalence), but it enforces that
privacy-critical and interop-critical anchor text stays aligned across docs.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NES = (ROOT / "spec" / "NES-v0.1.md").read_text(encoding="utf-8")
CDDL = (ROOT / "spec" / "schemas" / "grain-v0.1.cddl").read_text(encoding="utf-8")
FREEZE = (ROOT / "spec" / "FREEZE-v0.1.md").read_text(encoding="utf-8")
FREEZE_CONFIRM = (ROOT / "spec" / "FREEZE-CONFIRMATION-v0.1.md").read_text(encoding="utf-8")
SCOPE = (ROOT / "spec" / "SCOPE-v0.1.md").read_text(encoding="utf-8")
INTEROP = (ROOT / "spec" / "INTEROP-v0.1.md").read_text(encoding="utf-8")
E2E = (ROOT / "spec" / "profiles" / "e2e-profile.md").read_text(encoding="utf-8")
CBOR = (ROOT / "spec" / "profiles" / "cbor-profile.md").read_text(encoding="utf-8")
CONF_SPEC = (ROOT / "conformance" / "SPEC.md").read_text(encoding="utf-8")
ADR_WAVE_A = ROOT / "adr" / "conformance" / "0001-wave-a-byte-level-ops.md"


def require(text: str, needle: str, err: str) -> None:
    if needle not in text:
        raise SystemExit(err)


def main() -> int:
    # Protocol schema major anchor.
    require(NES, "v MUST be 1", "NES missing schema major rule (v MUST be 1).")
    require(CDDL, "Protocol schema major: 1", "CDDL missing schema major comment (Protocol schema major: 1).")

    # cap_id randomness anchor (privacy critical).
    csrng_rule = "cap_id MUST be generated using a cryptographically secure random number generator"
    require(NES, csrng_rule, "NES missing cap_id randomness MUST rule.")
    require(E2E, csrng_rule, "E2E profile missing cap_id randomness MUST rule.")
    require(FREEZE, "cap_id MUST be random", "Freeze statement missing cap_id randomness note.")
    require(FREEZE_CONFIRM, "cap_id` CSPRNG-only rule", "Freeze confirmation missing cap_id frozen anchor.")

    # Deterministic nonce derivation + mismatch code.
    require(NES, "nonce_derived = HKDF-Expand", "NES missing nonce derivation anchor.")
    require(E2E, "nonce_derived = HKDF-Expand", "E2E profile missing nonce derivation anchor.")
    require(NES, "NONCE_PROFILE_MISMATCH", "NES missing nonce mismatch diagnostic anchor.")
    require(E2E, "NONCE_PROFILE_MISMATCH", "E2E profile missing nonce mismatch diagnostic anchor.")
    require(CONF_SPEC, "NONCE_PROFILE_MISMATCH", "Conformance SPEC missing nonce mismatch diagnostic anchor.")

    # Manifest op-shape strictness is frozen across NES/E2E/CDDL/FREEZE.
    require(NES, '`ManifestRecord.op` MUST be exactly `"put"` or `"del"`', "NES missing ManifestRecord op-shape MUST rule.")
    require(E2E, '`op` MUST be exactly `"put"` or `"del"`', "E2E profile missing manifest op-shape MUST rule.")
    require(CDDL, '"op": "put"', "CDDL missing manifest put shape.")
    require(CDDL, '"op": "del"', "CDDL missing manifest del shape.")
    require(FREEZE, "Manifest op-shape is strict", "Freeze statement missing manifest op-shape freeze anchor.")
    require(FREEZE_CONFIRM, "Manifest semantics:", "Freeze confirmation missing manifest frozen section.")

    # Strict conformance mode anchors.
    require(NES, "Strict Conformance Mode", "NES missing strict mode section.")
    require(CBOR, "Strict Conformance Mode", "CBOR profile missing strict mode section.")
    require(NES, "GRAIN_ERR_LIMIT", "NES missing strict-limit diagnostic anchor.")
    require(CBOR, "GRAIN_ERR_LIMIT", "CBOR profile missing strict-limit diagnostic anchor.")

    # Wave A conformance contract anchors.
    require(CONF_SPEC, "parse_cborseq_stream_v1", "Conformance SPEC missing raw CBOR-seq parse op.")
    require(CONF_SPEC, "e2e_derive_v1", "Conformance SPEC missing E2E derive op.")
    require(CONF_SPEC, "result mode is XOR", "Conformance SPEC missing CBOR-seq XOR result semantics anchor.")
    require(CONF_SPEC, "GRAIN_ERR_CBORSEQ_TRUNCATED", "Conformance SPEC missing CBOR-seq truncated diagnostic.")
    require(CONF_SPEC, "GRAIN_ERR_CBORSEQ_GARBAGE_TAIL", "Conformance SPEC missing CBOR-seq garbage-tail diagnostic.")
    require(CONF_SPEC, "GRAIN_ERR_CBORSEQ_INVALID_INITIAL_BYTE", "Conformance SPEC missing CBOR-seq invalid-initial diagnostic.")
    if not ADR_WAVE_A.exists():
        raise SystemExit("Missing ADR for Wave A conformance contract extensions (adr/conformance/0001-wave-a-byte-level-ops.md).")

    # Interop claim anchors.
    require(INTEROP, "Strict Conformance Mode", "INTEROP spec missing strict-mode scope anchor.")
    require(INTEROP, "two independent implementations", "INTEROP spec missing dual-implementation claim anchor.")
    require(INTEROP, "Conformance criterion", "INTEROP spec missing conformance criterion anchor.")
    require(INTEROP, "Strong interoperability claim", "INTEROP spec missing strong claim anchor.")
    require(INTEROP, "no claim of truthfulness", "INTEROP spec missing non-claim boundary for truth.")
    require(INTEROP, "SHA-256", "INTEROP spec missing cryptographic assumptions anchor.")
    require(INTEROP, "evidence.sha256", "INTEROP spec missing evidence hash anchor.")

    # Scope clarification anchors.
    require(SCOPE, "Domain-neutral core infrastructure", "SCOPE missing domain-neutral core anchor.")
    require(SCOPE, "food-first", "SCOPE missing food-first profile anchor.")
    require(SCOPE, "verifiable physical events", "SCOPE missing strategic direction anchor.")
    require(SCOPE, "No frozen-core change is required", "SCOPE missing additive expansion anchor.")

    print("Spec drift checks: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
