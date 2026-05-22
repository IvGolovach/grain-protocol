# Public Protocol / Private Product Boundary

Grain is public protocol infrastructure. This repository is intended to contain
the specification, conformance suite, SDKs, fixtures, examples, local starter
templates, and documentation needed for independent implementations to build
against the same protocol.

This repository is not the home for production applications, account backends,
hosted services, App Store or Play Store release lanes, subscription products,
provider credentials, operational deployment configuration, or commercial product
experience.

First-party applications built on Grain may be developed in private repositories.
Those applications consume the public Grain SDK and contracts the same way an
external application would. Keeping that boundary explicit helps downstream
developers understand what is protocol surface and what is product surface.

## Public In This Repository

- protocol specifications and profiles;
- conformance vectors and verification tools;
- source SDKs and app-facing contracts;
- local reference apps and starter templates that avoid store, account, hosted
  backend, and production credential assumptions;
- fixtures and docs that help independent implementations interoperate.

## Private Product Surface

- branded production apps;
- hosted account/session/subscription backends;
- app-store metadata, StoreKit product setup, release archives, and upload lanes;
- provider orchestration, quota, and entitlement implementation details;
- deployment topology, staging/production resource IDs, and private runbooks.

## Practical Rule

If code is needed for another developer to implement Grain compatibility, it
belongs here. If code is needed to ship and monetize a specific product, it
belongs in that product's private repository.
