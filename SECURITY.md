# Security Policy

Thanks for helping keep Grain safe and trustworthy.

## Supported Versions

We currently provide security fixes for:

| Version | Supported |
| --- | --- |
| `main` | Yes |
| latest tagged release in the current major line | Yes |
| older releases and unpublished feature branches | No |

If a report only affects an unsupported version, we may still look at it, but fixes will usually land on `main` first.

## Reporting a Vulnerability

Please do **not** open a public issue, discussion, or pull request for a suspected vulnerability.

For the public repository, use **GitHub Private Vulnerability Reporting** / **GitHub Security Advisories** when private reporting is enabled.

## What To Include

A good report usually includes:

- the affected commit, tag, or version
- the component or path involved
- clear reproduction steps
- expected behavior and actual behavior
- impact: what guarantee can be broken, bypassed, forged, leaked, or corrupted
- a proof of concept, test case, or minimal input if you have one
- any environment details that matter

If you are not sure whether something is exploitable, that is still fine. Send what you know.

## What Counts As a Security Issue Here

For this repository, security issues can include:

- signature verification bypasses
- canonicalization or encoding bugs that can change verification meaning
- CID, COSE, CBOR, or manifest handling flaws with real security impact
- parser bugs that can crash, hang, corrupt, or mis-verify trusted flows
- tooling or CI issues that expose secrets or weaken release integrity
- dependency issues with a credible impact on supported paths

## Usually Not Security Issues

These are usually handled through normal issues unless there is a concrete exploit path:

- documentation mistakes
- best-practice suggestions without a demonstrated security impact
- reports that only affect unsupported versions
- purely theoretical concerns with no realistic attack path
- social engineering tests, spam, or reports against third-party services we do not control

## Response Expectations

We aim to:

- acknowledge new reports within 3 business days
- follow up when we can reproduce or scope the issue
- share status updates during active handling
- coordinate public disclosure after a fix is available, when disclosure is appropriate

Response time can vary depending on report quality, impact, and maintainer availability.

## Disclosure

Please keep vulnerability details private until we have had a reasonable chance to investigate and ship a fix.

When appropriate, we may publish a GitHub Security Advisory and request a CVE.

## No Bug Bounty

This project does not currently run a paid bug bounty program.

## Thanks

Careful reports help protect users, implementers, and downstream maintainers. We appreciate the help.
