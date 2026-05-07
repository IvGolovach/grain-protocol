# Trust Anchor Bundles

Trust anchor bundles are local app-distributed JSON files for building a static
`GrainTrustProvider` without network discovery or fallback trust.

The v1 shape is:

```json
{
  "bundle_v": 1,
  "anchors": [
    {
      "id": "publisher:primary",
      "trust_pub_b64": "<standard-base64-public-key>"
    }
  ]
}
```

Parsers must reject unknown fields, unsupported versions, empty bundles, blank
or duplicate IDs, and invalid or empty `trust_pub_b64` values.

Treat bundles as integrity-sensitive local verification policy. Production apps
should package, sign, MDM-provision, or otherwise pin the bundle through an
app-owned channel and fail closed on missing, unknown, malformed, or unexpected
anchors. Network lookup, TOFU, platform CA fallback, and default issuers do not
belong in SDK trust resolution.

Production handoff bundles can add governance metadata in a separate reviewed
bundle file under `sdk/trust/governed`. The governance guard requires a
`bundle_id`, `revision`, checksum, signature reference, reviewer, `fail_closed:
true`, and an explicit anchor `state` such as `active` or `revoked`. The
checksum is the SHA-256 of the canonical runtime payload containing only
`bundle_v` and `anchors`.

```bash
python3 tools/ci/check_trust_bundle_governance.py
```

Generated SDK trust providers still load the compact runtime v1 shape above.
If an app uses governed bundles, its app-owned release process should strip or
adapt governance metadata before passing anchors to the runtime provider, while
preserving the reviewed checksum/signature record outside the SDK core.
