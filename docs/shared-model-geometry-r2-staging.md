# Shared geometry R2 staging and previous staging cleanup

The Linux-qualified geometry collection is staged on R2 as immutable objects.
The exact 1,200-pair index and all payloads passed full public GET SHA-256 and
HEAD size checks: 1,031 new PCKs (7,738,013,284 bytes) plus 169 reused
objects. The new index is 203,589 bytes. The active public manifests were
identical before and after upload; no player release was activated.

The [upload preflight](../release/shared_model_geometry_r2_receipt.preflight.json)
pins every object, the build receipt and active manifest hashes. The
[completed upload receipt](../release/shared_model_geometry_r2_receipt.json)
records the independent public verification of each object and the index.

The previous qualified test collection was staged but never selected by an
active player manifest. The [retirement plan](../release/shared_model_geometry_r2_retirement_plan.json)
selected only 968 superseded PCKs and its old pilot index: 969 objects totalling
8,781,512,908 bytes. The 114 old PCKs still used by the new collection, all
original v11 ZIPs and every active v11 object were excluded. The plan checked
the new collection against R2 inventory, fetched the active public indexes and
found no reference to any retirement candidate. The
[retirement receipt](../release/shared_model_geometry_r2_retirement_receipt.json)
records 969 successful deletes with signed HEAD 404 checks and unchanged active
manifest references. A separate final inventory check found all 1,201 new
objects present at their exact sizes and all 969 retired keys absent.

Adding 7,738,216,873 bytes and removing 8,781,512,908 bytes reduces actual
R2 object storage by **1,043,296,035 bytes** compared with the previous staged
state. This is separate from the **4,167,740,277-byte** reduction in the
potential active download collection versus the original v11 collection. The
current game and launcher still select v11; those live objects remain in R2.

This staging remains debug-only and Linux-qualified. A future player release
must bind the exact checked index and payloads in production game and launcher
code, run its release checks, and update public manifests through the normal
release process. Windows, macOS and physical Android tests remain unavailable.
