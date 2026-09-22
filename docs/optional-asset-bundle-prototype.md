# Optional asset bundle prototype

This local-only prototype proves one species/form bundle as the smallest 3D
delivery and update unit. It is deliberately not connected to launcher UI,
the production release manifest, R2 publication, gameplay downloads, sprites
or arenas.

## Contracts

`pokeaether-optional-asset-index` schema 1 lists immutable archives. A Pokémon
bundle ID has the form `pokemon_3d:<species>:<form>`. Its appearances explicitly
name normal/shiny runtime identities and hashes; no Pokédex-number, filename or
variant inference is permitted. Dependencies are stable asset IDs, validated
for missing entries and cycles, and planned before their consumers.

Each `pokeaether-asset-bundle` archive contains `bundle.json` plus declared,
self-contained `.scn` files. The archive size/SHA-256 from the content index is
checked before bounded ZIP inspection and extraction. The inner manifest,
model sizes and model SHA-256 values are then checked independently.

The launcher-side store uses immutable `objects/<archive-sha256>` directories
and content-hashed state generations. A new generation contains deterministic
`installed-state.json` and a loader-compatible `runtime-catalog.json`. Only an
`active.json` pointer changes at activation. The prior pointer is retained for
recovery until explicit garbage collection.

The generated runtime catalog does not grant model approval. The existing
checked-in reviewed/screened registry remains the production identity and hash
gate when the game loads it.

## Local prototype cohort

The delivery packager accepts an already approved local/portable catalog and
produces exactly these three base-form bundles, each with normal and shiny:

- Arcanine
- Dragonite
- Roaring Moon

It never converts or changes source scenes, selects the output, installs it or
uploads it. Existing output is never overwritten.

## Proven behavior

The focused launcher test uses small valid binary Godot scenes with the same
six explicit identities to exercise the store without shipping model assets.
It proves:

- initial installation of all three independent bundles;
- a second plan with zero downloads;
- dependency ordering;
- deterministic state/catalog recovery across a new store instance;
- recovery through the previous pointer when the active pointer is damaged;
- a Dragonite-only v2 update while the other object hashes remain unchanged;
- rejection of same-version/different-hash publication;
- rejection of corrupt, incomplete and internally mismatched replacements;
- preservation of the active Dragonite v2 state after every failed v3 update;
- explicit Arcanine removal followed by controlled orphan cleanup;
- normal absence in the generated catalog after removal;
- successful `PackedScene` loading from every generated catalog path.

The Python packaging test independently proves three deterministic bundle
boundaries, normal/shiny identity, outer hashes/sizes, archive contents,
approval enforcement and no-overwrite behavior.

## Deferred production work

No R2 objects or manifests are created. Before later publication, the release
manifest must anchor the content index by URL, size and SHA-256, and R2 cleanup
must protect immutable objects referenced by that verified nested index.
Pack/region selection, launcher UI, background/on-demand downloading and other
asset types remain outside this prototype.
