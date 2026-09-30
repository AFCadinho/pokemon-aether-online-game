# Published 39-pair animation recovery cohort

All 39 qualified species bundles (78 normal/shiny scenes) are available on R2,
279,850,346 bytes total. The complete public response SHA-256 and HEAD size
were checked for all 39 archives and the immutable content index.

- `approved_3d_recovery_39_index.json` contains exactly this 39-species cohort.
- `approved_3d_recovery_39_r2_upload.json` records public object keys, SHA-256,
  sizes, approval/catalog hashes and each successful public verification.
- Qualification is pinned to
  `tools/sprite_factory/catalog_animation_recovery_39_bundle_qualification.json`.
- Existing immutable objects are reused after verification. The index was
  published after all referenced bundles passed verification.

The public `manifest.json` was read before and after publication; its hash is
unchanged. No launcher/game release was activated. The full locally approved
catalog remains 751 base species plus Mega Dragonite; this index contains the
39 newly completed species only. A future complete release index must combine
these entries with the other approved, publicly verified bundles.

The publication command is:

```sh
python3 tools/publish_animation_recovery_39.py \
  .tmp/remaining-animation-recovery/remaining-39/final-battle/bundles \
  --credentials /path/to/local-r2-profile --apply
```

Omitting `--apply` verifies the local qualification, archive hashes and both
embedded scene hashes without accessing R2. Credentials stay in the local
profile/environment and are never written to the receipt.
