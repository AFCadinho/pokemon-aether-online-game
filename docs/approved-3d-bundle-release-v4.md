# Approved 3D bundle release v4

The six placement recovery approvals (Charizard, Corviknight, Dondozo,
Gyarados, Haunter and Mewtwo) have been added to the 76-species v3 catalog.
Release v4 contains 82 individually versioned normal/shiny bundles. The six
new archives total 156,357,668 bytes; the full catalog archives total
2,035,806,695 bytes. The v4 index SHA-256 is
`d53284accb23040e1200cf085ddcb982510966fc73ba146c80030f16af6092f9`.

## R2 upload (26 September 2026)

The six new bundle objects and the v4 index were uploaded to the existing R2
bucket. The 76 unchanged v3 bundle objects were reused. Public GET requests for
all seven new objects returned their pinned sizes and SHA-256 hashes, verifying
156,430,361 bytes. Details are in
`release/approved_3d_bundles_v4_r2_upload.json`.

This upload did not activate the v4 index in the desktop manifest. The launcher
still selects v2 until a separate desktop release is certified and published.
The model bundles remain outside the base game build.
