# Inventory Profile 1.0

Inventory Profile 1.0 is an example opaque domain profile for physical stock
counts and transfers.

The machine-readable profile is `spec/profiles/inventory-profile.v1.json`.

## Scope

This profile shows how to record inventory facts on top of Grain without adding
new reducer semantics to the v0.1 protocol core.

Events using this profile are stored and transported through the same strict
encoding, COSE, ledger, E2E, manifest, and GR1 rules as any other Grain event.
The v0.1 food reducer does not interpret `InventoryCountEvent`.

## Source Class

`source_class` MUST be exactly one of:
- `counted`
- `transferred`
- `estimated`

## Identity

Adapters SHOULD identify the counted item with:
- `sku`
- `lot_id`
- `location_id`

The adapter owns the meaning and normalization of those identifiers.

## Quantity

`quantity_count` is a non-negative int64 value with `scale_exp10 = 0`.

The unit MUST be one of:
- `each`
- `gram`
- `milliliter`

Fractional source data must be rounded or scaled by the adapter before it emits
a Grain event.

## Time

`observed_at_ms` is an int64 Unix timestamp in UTC milliseconds.
The profile does not add timezone, locale, display-unit, or warehouse-policy
semantics.
