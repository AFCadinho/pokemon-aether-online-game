# Approved 3D bundle release v5

Release v5 adds the approved normal and shiny Mega Dragonite appearances to
the 82 base-form bundles in v4. It contains 83 independently versioned
bundles and 166 appearances. Mega Dragonite depends on the unchanged Dragonite
base bundle. The two Mega appearances share a single 67,184,462-byte archive.

The pinned receipt is `release/approved_3d_bundles_v5.json`. Its index SHA-256
is `609e95118b68fc22d7020a84e23589a22a4293e1396da56e04b253cf6e1bd447`.
The archive and generated index are staged outside the repository in
`/home/adinho/Documents/3d_models/PokeAether/release-approved-bundles-v5`.
The 82 v4 archives are reused byte-for-byte; only the Mega archive and new
index need uploading.

The launcher release adapter accepts this exact v5 index and verifies the
normal/shiny hashes against its checked-in approval registry. The deployment
workflow requires a rebuilt launcher when selecting v5 and checks all 84
public objects before writing a desktop manifest. The model scenes remain
outside the base game export.

Local staging and dry-run publication:

```sh
python3 tools/package_approved_3d_release_v5.py V4_DIR MEGA_DIR V5_DIR release/approved_3d_bundles_v5.json
python3 tools/publish_approved_3d_bundles.py V5_DIR --metadata release/approved_3d_bundles_v5.json
```

Uploading, certification, promotion, pushing and desktop deployment are
separate release operations.

## R2 upload (26 September 2026)

The Mega archive and v5 index were uploaded to the existing R2 bucket. Public
GET verified their full sizes and SHA-256 digests (67,258,099 bytes total).
All 84 objects required by v5 returned the pinned sizes in public HEAD checks.
The details are recorded in `release/approved_3d_bundles_v5_r2_upload.json`.
The desktop manifest has not selected v5 yet.
