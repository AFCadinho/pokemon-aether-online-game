# Medium animated Android renderer smoke

This extends the private `android-quality` APK/USB fixture with `--mode gameplay`.
It uses no game account or backend and touches only the slot's diagnostic app.
The ordinary game's preferences and Android defaults remain unchanged.

The bounded protocol reconstructs the production forest pool/presenter three
separate times with trusted v16 Charizard/Dragonite assets, Medium on both
passes, authored shadows and a 60 FPS cap. Unlike the fixed-scene soaks,
model playback is enabled at 1×. Noon, wind and camera remain fixed. Each cycle
runs Flamethrower, Thunderbolt, Rock Slide and Draco Meteor through the actual
`BattleAnimationRouter`, alternating actors, with real model-clock playback,
confirmed impacts, recovery and effect/audio cleanup. It then opens the actual
in-game settings menu and visits all eight tabs before closing it. These are
renderer exercises, not claims about those actors' legal battle movesets.

Each observation lasts at least 30 seconds and must complete the sequence in
less than 90 seconds. Overall intervals include menu/attack setup, local audio
loading and diagnostic bookkeeping; a nested series records each move's loop
intervals and both pass GPU samples. Individual boundaries have process-frame
precision. Native PSS queries, arena reconstruction and a three-second settling
period are outside these statistics. Initial preparation is therefore reported
separately rather than hidden in steady-state FPS. Driver/native caches from
prior diagnostic runs are retained: this is not a cold-install test.

A separate unmeasured effect pass saves actual impact images, keeping PNG
readback/encoding outside the performance windows. Real Android HOME/resume and
opt-out checks still run after measurement. The host rejects missing effects,
impacts, cleanup, menu tabs, finite samples or distinct arena instances. Slow but
finite timing results remain valid evidence, not a reason to discard a run.

Build with the normal private Android-quality exporter; run using a fresh output
folder and the assigned slot environment:

```sh
ops/worktrees/slot-env slot-a -- python3 -u .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --mode gameplay \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/gameplay-export-1/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/gameplay-run-1
```

Keep the phone unlocked with this diagnostic in the foreground. Keep polling
its terminal session during the run. Host evidence is checkpointed atomically.
This is an automated native smoke, not a full gameplay duration test: it does
not cover authenticated loading/profile hydration, real map travel, crowded
worlds, server-driven battles/PvP, touch ergonomics or all moves/devices.
