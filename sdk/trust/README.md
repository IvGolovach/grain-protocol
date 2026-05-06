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
