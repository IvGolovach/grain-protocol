# Food Profile 1.0

Food Profile 1.0 is the v0.1 domain profile for reducer-visible food events.
It fixes the units and vocabularies that adapters must use when they map outside food data into Grain's shipped `IntakeEvent` path.

The machine-readable profile is `spec/profiles/food-profile.v1.json`.

## Scope

These rules apply only to food-profile objects and reducer-visible `IntakeEvent` bodies.
They do not add food semantics to the frozen infrastructure layers: encoding, CID, COSE, ledger authority, E2E, manifest resolution, and GR1 transport stay domain-neutral.

## Source Class

`source_class` MUST be exactly one of:
- `attested`
- `measured`
- `estimated`

Adapters SHOULD use `estimated` when a source does not make a stronger claim.
Adapters MUST NOT mint extra source classes without a future profile revision.

## Reducer-Visible Nutrient Units

The v0.1 normative reducer-visible nutrient is `kcal`.

`kcal` means integer kilocalories with `scale_exp10 = 0`.
Values use the int64 numeric domain and inherit the overflow behavior in `spec/NES-v0.1.md`.

Adapters MAY carry additional nutrient fields in profile objects for application use.
Those fields do not have v0.1 normative reducer semantics unless a future profile declares them.

## Quantity Units

Food Profile 1.0 fixes these quantity fields:

| Field | Unit | scale_exp10 | Domain |
|---|---|---:|---|
| `amount_g` | gram | 0 | non-negative int64 |
| `yield_g` | gram | 0 | non-negative int64 |
| `serving_g` | gram | 0 | non-negative int64 |
| `servings` | serving count | 0 | non-negative int64 |

Fractional source data must be rounded or scaled by the adapter before emission.
The chosen adapter policy must be documented outside the protocol object.

## Reducer Outputs

For v0.1 food reducers, normative outputs remain:
- `sum_mean`
- `sum_var`

No quantile, percentile, display unit, locale, timezone, or nutrition-label rounding rule is part of Food Profile 1.0.
