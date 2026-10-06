# Model installation and displayed ping, 2026-10-06

## Local fix following this investigation

The application now awaits storage workers for new-download verification,
atomic file publication, archive installation, index/catalog reads, installed
entry checks, and catalog publication. HTTPRequest uses its download thread;
Node/progress state and the downloader lock stay on the main thread. Full
archive/model SHA checks, reviewed-model admission, temporary-file publication,
and cache-clear guards are retained. Pending storage work never joins on the
main thread; only completed jobs are collected.

The updated benchmark also exercises the actual application `_install_asset`
path, with a completed download supplied from the benchmark's own approved
input file. The Litten installation took **144.858 ms** in total while **21
frames** continued; the longest frame was **6.993 ms**. Direct synchronous
reference work in the same run blocked frames for **114–127 ms**. This excludes
network variability and GPU/model instantiation, and is not a live RTT forecast.

`model_install_worker_check.gd` deliberately holds archive work and checks
continued frames, cache-clear protection, one download for concurrent callers,
full SHA admission, corrupt-body rejection, retry, and invalid model digest
rejection. Existing cached-battle and Pokédex checks also pass. Runtime changes
need a new client release; this local result does not change an installed client.

## Finding

A newly downloaded model can block the client main thread while the archive
is verified and unpacked. This delays world-presence WebSocket polling and
pong handling, increasing application RTT even when the server has already
responded. This mechanism was reproduced locally; it does not prove which
step caused the player's specific 163 ms reading.

`OnDemand3DBundleService._fetch()` resumes after the HTTP request and calls
`_valid_file()` synchronously. `_install_asset()` then calls `_unpack_asset()`
synchronously. That method verifies the archive again, reads/decompresses
both scene files, hashes them, writes missing files, and verifies written files.
The already-installed fast path uses a worker, but the new-install path does not.
Resource loading elsewhere is already threaded and is a separate phase.

`WorldPresenceService._process()` polls and consumes WebSocket packets on each
frame. `ConnectionLatency.received()` measures until that consumption happens.
`PerformanceMetrics` displays a mean of the last five samples, so one delayed
pong can affect several subsequent displayed values.

## Local measurement

Frontend base: `759c66e496e32fc1209ec7f544fcbec8920ca267`.
Godot: `4.6.2.stable.official.71f334935`, headless, Linux.
Approved v11 Litten bundle: 8,667,841 archive bytes, with 4,420,075 and
4,246,723 byte normal/shiny scene files. The downloaded archive matched the
pinned SHA-256 in `release/approved_3d_bundles_v11_index.json`.

| Run | Archive verification | Synchronous unpack/install | Combined main-thread work | Longest install frame |
| --- | ---: | ---: | ---: | ---: |
| 1 | 30.433 ms | 98.564 ms | 128.997 ms | 129.136 ms |
| 2 | 29.001 ms | 96.529 ms | 125.530 ms | 125.687 ms |
| 3 | 27.183 ms | 95.025 ms | 122.208 ms | 122.551 ms |

A diagnostic worker comparison executed the same verification/install methods
in 118.855 ms while 18 frames continued; the longest frame was 7.009 ms.
This comparison is in the benchmark only. Application behavior was not changed.
The unpack methods verify resulting model hashes; an additional post-install
integrity check is timed separately and excluded from the install-frame column.
Later runs reuse files installed in the benchmark's own slot userdata.

These are warm local/headless measurements of one representative archive,
without model instantiation, GPU uploads, shader compilation, or live gameplay.
They establish a blocking mechanism, not an exact production-client RTT forecast.

## Reproduction

Use an assigned frontend slot and its `slot-env`. Obtain the selected asset row
from the pinned v11 index and the corresponding public archive. Keep downloaded
inputs outside the source checkout, in that slot's own diagnostic directory.
Do not copy another checkout's caches, models, or userdata.

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path FRONTEND \
  --script res://tools/benchmarks/model_install_latency.gd -- \
  /absolute/path/to/asset-row.json /absolute/path/to/approved-archive.zip
```

The command prints `MODEL_INSTALL_LATENCY` with three synchronous runs and a
worker comparison. It writes verified model fixtures only to the slot's userdata
and performs no network requests. It requires an archive whose size and digest
match the supplied approved metadata.

## Recommended implementation

Move new-download verification and archive installation into an awaited worker
job, keeping HTTPRequest, Node/tree interaction, progress updates, and publishing
coordination on the main thread. Retain the existing downloader lock, cache-clear
guards, all pinned hashes, reviewed-model checks, and atomic file publication.
Check responsiveness while work is deliberately held, failure/corruption paths,
and concurrent prefetch/battle requests. Do not hide or subtract client stalls
from the displayed RTT.
