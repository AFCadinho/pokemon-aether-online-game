# R2 retention cleanup, 15 September 2026

The account's listed object storage decreased from 13,907,817,423 bytes to
9,298,784,482 bytes. The target is 10,000,000,000 bytes, leaving 701,215,518
bytes of headroom. Every bucket was fully paginated; no private object bodies
were fetched. These are current object sizes, not a billing-period average.

| Bucket | Bytes after cleanup |
| --- | ---: |
| pokemon-aether-updates | 7,190,399,977 |
| pokemon-aether-backups | 1,904,517,136 |
| pokemon-aether-ml-datasets-private | 203,867,369 |
| pokeaether-web | 0 |
| pokemon-aether-ml-private | 0 |

Removed 9,781 objects: 25 ZIPs in ten old launcher folders, 9,750 objects
in six old web releases, and six duplicate latest-download ZIPs. Backups,
datasets, news and browser sprite catalogs were unchanged.

Retained game versions 0.3.78 and 0.3.77, launcher versions 0.3.78 and
0.3.75, and both versions of each desktop asset pack. The retained complete
web bundles each contain 1,625 objects:

- Current: `e13ff52a2389ef91f5e385185114be28dda87afc-34820430832-1`
- Previous successful release: `e72d03a9d42a329be937cbd1c346ab3015123d21-34784165523-1`

The live Worker `pokeaether-update-downloads` has deployment ID
`6b8527a2bf6c42ea96a1cb74290fb14d`. Its four routes intercept only game and
launcher latest-download paths on the two update hostnames. All twelve
hostname/download combinations passed real redirect and one-byte ZIP range
checks before alias deletion; redirects were rechecked afterward. Current
and previous web manifests, WASM and PCK were reachable. All active desktop,
launcher and web references matched the pre-cleanup snapshot afterward.

The larger Cloudflare API call timed out after 300 seconds while its deletion
continued on Cloudflare. Final state was checked independently: only the two
retained web release folders remain, each intact. A tool timeout must not be
treated as evidence that a remote mutation stopped.

Source changes were tested and committed locally on development, starting
with `bc2ff73b1c8a1e21237ba472db9a59687069d506`. Focused checks passed:
10 retention tests, 14 Worker tests, 6 upload tests, 1 redirect-verifier test,
workflow YAML parsing and git whitespace validation. No full development
gate, promotion, GitHub push or game release was performed.

The redirect Worker is live. The changed release workflows are still local
and require the normal authorized release process before future GitHub runs
use them. Existing remote workflows can recreate duplicate aliases or retain
additional launcher/web history. The 24-hour upload grace period, new assets,
and other buckets can also increase storage; two-version retention alone is
not a strict account-wide capacity cap. See
[the operational instructions](../infrastructure/updates/README.md).
