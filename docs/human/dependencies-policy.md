# Dependencies Policy

This page defines the low-noise update policy for dependency pull requests.
The goals are to keep security updates prompt, batch routine maintenance, and
avoid privileged merge automation.

ADR references:

- `adr/conformance/0006-ci-economy-and-trusted-runners.md`

## Version updates

Dependabot uses a monthly version-update cadence for three ecosystems:

- GitHub Actions at `/`: grouped minor and patch updates
- Cargo at `/core/rust`: grouped patch updates
- npm at `/runner/typescript`: grouped minor and patch updates

Every entry keeps `rebase-strategy: disabled` and its
open-pull-requests-limit at or below 2. This prevents background rebases from
starting new CI runs and limits the active maintenance queue. Major updates and
Cargo minor updates stay separate for manual review.

## Security updates

Dependabot security updates remain immediate and are not delayed by the monthly
version-update schedule. Repository vulnerability alerts and automated security
updates must remain enabled in GitHub settings. Security PRs still require the
same tests and manual merge as every other dependency PR.

## CI behavior

- Every external fork contributor requires maintainer approval before any
  workflow jobs start.
- Every PR runs the automatic Linux verification jobs.
- Docs and approved repository metadata changes can pass without the macOS job.
- Code, executable automation, protocol, conformance, SDK, script, or unknown
  paths wait at the protected `full-ci` environment after the automatic Linux
  jobs succeed.
- After reviewing the final diff, a maintainer selects `Review deployments` and
  approves `full-ci`. The GitHub-hosted macOS SDK gate and evidence bundle start
  only after that approval.
- A new commit or Dependabot branch update cancels the old run and requires a
  new environment approval.
- `CI gate` fails closed if required work fails, is cancelled, or is skipped.

## Merge policy

There is no privileged automerge workflow and no automerge PAT. Maintainers use
manual merge after `CI gate` succeeds and the diff is reviewed. This avoids a
standing write-capable token and keeps dependency updates auditable.

The public Grain repository must not run pull-request code on a persistent
self-hosted runner. The explicit full lane uses GitHub-hosted `macos-15`. A
future private executor must live in a separate private repository and use an
isolated runner identity.
