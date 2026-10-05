# Project checks

Run the complete project checks only as part of an authorized integration or
release certification. Use the paired `ops/integration/verify-release` command
for a release, so the world catalog and backend gate remain mandatory.

On Linux, `run_project_checks.gd` uses GNU coreutils `timeout` to limit each
child check to 180 seconds, followed by forced termination after 10 seconds.
A timed-out child fails the gate; the runner continues collecting other
failures. A captured `SCRIPT ERROR:` also fails a check when Godot returns
exit code zero. Successful checks remain quiet unless
`POKEAETHER_TEST_VERBOSE` is enabled.

`project_check_runner_timeout_check.gd` exercises a deliberately hung process,
a script error followed by exit code zero, and a subsequent successful child.
The scripts under `fixtures/project_check_*` are intentional subprocess
fixtures, not standalone project checks.
