# Desktop model-file qualification workflow

Task `lossless-desktop-qualification`, slot-b, 2026-10-06. The user has no
Windows/Mac test machines and requested preparation of GitHub Actions. This
task prepared that workflow locally. The later `lossless-native-ci-run` task
has explicit user authorization to publish the immutable test input, push a
separate CI branch and run the native checks. Player release and model-catalog
activation remain separate.

## Prepared scope

`.github/workflows/qualify-lossless-models.yml` runs the actual launcher
file/update tests on Windows x64, macOS Intel, macOS Apple Silicon and a Linux
control. It uses SHA-pinned official Godot 4.6.2 archives and pinned action
commits, read-only repository permissions and fresh job machines. It uses
neither production credentials nor the deployment workflow. The matrix labels
are taken from the [GitHub runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Every target tests 11 pairs / 22 appearances with the same original and
256 KiB / Zstd level 9 inputs already exercised on Linux:

- Published pins reject the unpublished subset.
- The original collection stages its first ZIP, pauses a partial second ZIP,
  and retains the existing active generation.
- A new engine process reuses the staged ZIP and resumes the partial body.
- The smaller collection updates through the actual Downloads UI, including
  same-process Pause/Resume.
- All installed hashes and native SCN loads are verified after each completed
  phase. Restart planning requests no repeated downloads.
- The normal update queue restores all original hashes without network
  downloads, reusing the retained original objects.

The runner checks both Python's native host and Godot's reported OS/architecture,
records the engine version, fixture hash and repository HEAD, and rejects actual
engine/script errors across the full log. Locally, tests run before commit, so
the recorded HEAD is the development base; it is not a certified release SHA.
On CI, checkout supplies the selected remote commit.

This is headless file-format/installation qualification. It does not establish
Windows/macOS GPU image equivalence, battle framerate, exported game startup,
Apple signing or a full 2,400-appearance platform run. Renderer/reference and
performance results remain those of the earlier Linux tasks. Player-release
certification remains separate.

## Portable fixture

`launcher/tests/native_qualification_fixture.py` packages only the two indexes,
their declared bundle ZIPs and test metadata. It verifies original bundles
against the current checked-in v10 release index, verifies every encoded model
hash, and rechecks equality of the decoded original/candidate model data using
the existing codec. The package contains no code, build, cache, credentials,
configuration, userdata or logs. Member paths are relative and declared by a
checksum manifest. Input unpacking rejects traversal, symlinks, duplicates,
undeclared members, oversized files and checksum failures, then relocates only
the declared fixture paths for the target operating system.

Prepared input retained locally:

```text
.tmp/lossless-desktop-v1/input.zip
SHA-256: 0acc710748557f1818033ef2dab07ef7d7e0bb74c35bb24e021f6bd3caee754d
Bytes: 606979690
```

The receipt is `input.receipt.json`. This is a test asset package, not a
production bundle index. The candidate release is still unapproved/unpublished.

The Windows path uses allowlisted tracked source files materialized into new
tiny projects, so it needs no symlink privilege. This copies source scripts,
assets and UID metadata only; caches and userdata are created afresh by each
project. No existing caches/configuration are copied. All phases share only
their newly created test installation and partial bodies as required to test
recovery. The official Windows console executable supplies process output.

## Local validation

Evidence is retained in `.tmp/lossless-desktop-v1/`:

- Packaging reverified all 22 decoded model streams and the approved originals.
- Eleven Python transport checks pass: relocation, outer/member checksums,
  traversal/code/cache rejection, duplicates, symlinks, metadata limits,
  undeclared members, escaping routes and existing-output preservation.
- `actionlint` 1.7.12 passes on the workflow.
- Python compilation and whitespace checks pass.
- `linux-portable/report.json` passes the complete workflow runner route with
  materialized source, relocated package paths and the SHA-verified downloaded
  official Linux engine, version `4.6.2.stable.official.71f334935`.
- The fresh-process original resume reuses 262,144 bytes; the same-process
  native resume reuses 1,048,576 bytes. Each completed original/native/rollback
  phase independently verifies all 22 files; rollback downloads zero ZIPs.

At the end of that preparation task, native Windows and macOS results were not
available. No virtual machines are registered locally; Wine is not used as a
substitute for native results. The subsequent GitHub execution is recorded below.

## Running the prepared workflow

The input ZIP must first be made available at an explicitly approved HTTPS
test-asset location. The workflow requires its exact SHA-256. It downloads no
other Pokémon assets automatically. Fixture publication and a test-branch push
require user authorization under workspace AGENTS.md; that authorization was
given for `lossless-native-ci-run`.

For the first test without promoting local development/main, configure the
repository variables `LOSSLESS_MODELS_FIXTURE_URL` and
`LOSSLESS_MODELS_FIXTURE_SHA256`, then push the approved code to a dedicated
`ci/lossless-models-*` branch. Only this workflow's push trigger selects that
branch pattern. Existing deployment workflows are manual.

Once the workflow exists on the remote default branch, it can also be invoked
manually with `fixture_url` and `fixture_sha256` inputs against a selected ref.
GitHub requires the workflow to exist on the default branch for initial
`workflow_dispatch` registration; merely pushing a new workflow to a feature
branch does not make manual dispatch available. See
[GitHub's manual-run instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

Reports/errors use an explicit JSON/log allowlist. The workflow requests 14 days
of retention, but the current repository caps artifacts at one day. Durable
result summaries therefore belong in the checked-in qualification receipt.
Model archives, installed objects, caches and userdata are excluded
from those report artifacts. The workflow has no game export, model activation
in published catalogs, R2 deployment or release step.

## Local reproduction

Run these commands through the assigned slot environment:

```sh
python3 launcher/tests/native_qualification_fixture.py pack \
  /ABSOLUTE/PATH/TO/fixture.json .tmp/FRESH-INPUT.zip
python3 launcher/tests/native_qualification_fixture.py unpack \
  .tmp/FRESH-INPUT.zip EXPECTED_SHA256 .tmp/FRESH-PORTABLE
python3 launcher/tests/run_native_compression_install_check.py \
  .tmp/FRESH-PORTABLE/fixture.json .tmp/FRESH-RESULTS \
  --streaming --materialize-sources --expected-platform Linux \
  --expected-architecture x86_64
```

Set `GODOT_BIN` to the verified official engine executable. The native-platform
flags must match the real host; changing a flag does not emulate that system.

## GitHub execution, 2026-10-06

The immutable 606,979,690-byte input was published at the content-addressed test
location recorded in `release/native_model_qualification_input_r2_receipt.json`.
The full public GET reproduced its pinned SHA-256. The five active platform
manifests were identical before and after publication. The branch is
`ci/lossless-models-20261006`; it has no deployment or model-activation step.

The first run (`37428810235`, commit `7328c7cda`) failed before model checks:
the public edge rejected urllib's generic user agent with HTTP 403 / code 1010.
A request identifying `PokeAether-Qualification/1.0` succeeded. The downloader
now identifies this test client while retaining mandatory input/engine checksums.

The next run (`37429269704`, commit `06d4b5201`) completed the model phases on
Linux and both Macs. Windows rejected the generated test subset because source
paths used backslashes and failed exact fixture-override comparisons. This was
a test-project construction error; the real release-pin rejection was correct.
Run `37429820463` exposed the same issue in a second path list for release JSON.
Both file-system and Git source lists now use consistent POSIX relative names,
with a regression check using `PureWindowsPath`.

Fresh source projects also import assets before enabling their real autoloads
and main scene. This avoids the font preload error on a cold import without
copying caches or disabling localization during the model checks. Both import
passes and launcher execution now reject engine/script errors. No model bytes,
release acceptance rule or quality/performance threshold was relaxed.

### Final native results

[Run 37430114921](https://github.com/AFCadinho/pokemon-aether-online-game/actions/runs/37430114921)
passed every job at commit `ac998792ba4956dd34c737c5f027f357fed36910`.
All targets used the pinned official engine `4.6.2.stable.official.71f334935`.
The durable summary is `launcher/tests/native_desktop_ci_qualification_results.json`;
the earlier preparation receipt remains a historical record.

| Native target | Verified files in original / smaller / rollback phases | Restart resume | Same-process resume | Rollback downloads |
| --- | --- | --- | --- | --- |
| Linux x64 | 22 / 22 / 22 | 524,288 bytes | 524,288 bytes | 0 |
| Windows x64 | 22 / 22 / 22 | 1,048,576 bytes | 786,432 bytes | 0 |
| macOS Intel | 22 / 22 / 22 | 262,144 bytes | 262,144 bytes | 0 |
| macOS Apple Silicon | 22 / 22 / 22 | 786,432 bytes | 786,432 bytes | 0 |

Every completed collection also deserialized all 22 native SCN files and passed
restart planning with zero pending downloads. The paused original phase retained
one staged bundle and the unchanged active generation. Every smaller-file phase
used the actual same-process Pause/Resume path; every rollback used the normal
automatic update queue. Published pins rejected the unpublished fixture on all
four targets. The collected reports match the selected commit, native OS and
architecture, official engine and exact input SHA-256. All 30 retained logs per
target were checked for engine/script errors, including both import passes.

Local transport/path regression checks total 15 passing tests; Python compilation,
actionlint 1.7.12 and whitespace checks pass. A fresh local Linux reproduction
also passed the two-pass import and all installer phases. Report hashes, job and
artifact IDs, expiry times and prior failed/canceled attempts are retained in the
durable summary. These results qualify native file loading and installation for
this 11-pair sample. GPU rendering, exported player builds, the full collection
on every platform and player-release certification remain separate checks.
