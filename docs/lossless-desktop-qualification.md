# Desktop model-file qualification workflow

Task `lossless-desktop-qualification`, slot-b, 2026-10-06. The user has no
Windows/Mac test machines and requested preparation of GitHub Actions. This
task prepares that workflow locally; no branch, fixture, workflow run or
player build is published by this task.

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

**Native Windows and macOS results are not available yet.** No virtual machines
are registered locally. Wine was not used as a substitute for those results.

## Running the prepared workflow

The input ZIP must first be made available at an explicitly approved HTTPS
test-asset location. The workflow requires its exact SHA-256. It downloads no
other Pokémon assets automatically. Fixture publication and a test-branch push
still require user authorization under workspace AGENTS.md.

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

Reports/errors are retained per target for 14 days, using an explicit JSON/log
allowlist. Model archives, installed objects, caches and userdata are excluded
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
