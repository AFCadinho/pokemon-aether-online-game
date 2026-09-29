# Approved 3D catalog: 705 profiles

This publication contains the exact normal/shiny scene hashes from the reviewed
catalog at frontend commit `e8939190db585ae0ed686c41cc35a25355344bb3`:
704 base Pokémon plus Mega Dragonite, in 705 independent bundles (1,410 scenes).

- `approved_3d_bundles_705_index.json` is the combined immutable content index.
- `approved_3d_bundles_705_r2_upload.json` records its public object key, size,
  SHA-256, the reviewed catalog hash, and verification of each bundle.
- Bundles were selected by exact approved scene hashes. Unapproved candidates,
  obsolete variants, and the remaining-ten update probe were excluded.
- Local archive size, archive SHA-256, and both embedded scene hashes were
  checked. Existing and newly uploaded objects were fully downloaded from the
  public update host and checked for exact size and SHA-256.
- The combined index was published only after every referenced bundle passed.
- The launcher index validator accepted all 705 entries. The index is below the
  game downloader's 1 MiB index limit.

## Desktop activation

This is an R2 content publication, not a desktop release. The existing public
`manifest.json` and the game's pinned on-demand release descriptor were not
changed. A subsequent certified desktop release must use this index and the
matching reviewed catalog to make the expanded set available to players.

For the release descriptor use the receipt's `catalog_revision`, `content_index`
and `public_base_url`. Do not infer availability from candidate directories or
rewrite an immutable published object. Later model corrections require their
own verified bundle version and a new content index.
