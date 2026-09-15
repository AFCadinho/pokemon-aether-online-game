# Final browser demo: Misty enablement

The server now projects all 38 supported static maps from its canonical world
catalog: the original 22 plus the 16 maps in `browser-misty-scope.json`.
Cerulean is the fifth supported Aethernet destination; canonical attunement,
fares and guild benefits are unchanged. No generic desktop API is opened.

Route 3 still requires Brock. Route 5 (all three exits), Route 9 and Cerulean
Cave remain outside the browser projection even after their story requirements
are satisfied. Existing restrictions on other outside-demo maps remain intact.

The normal optional-module builder produces both Aether Clash and Misty packs,
each with a 32 MiB ceiling, and a single manifest. Integrity hashes are streamed
from disk. Validation enumerates the mounted pack's actual files in an isolated
Godot project: script references to an outside map do not count as exporting it.
The initial core still excludes the Misty maps and their visual directories.
The historical preset name `Web Misty Maps Trial` is retained for repeatable
older experiments; its normal output is `modules/kanto-through-misty-maps.pck`.

Focused evidence:

- Normal module exports: Aether Clash approximately 7.9 MiB; Misty approximately
  19.9 MiB in slot C and 25.1 MiB in the integration checkout with its own import
  cache/assets. Both remain within budget. Required maps present, canonical
  outside maps absent. Initial integration build stays 300.9 MiB.
- Module pipeline/scope tests, trial validation tests and release-packaging tests.
- Browser HTTP tests cover Brock gating, Route 3 entry, saved Cerulean resume,
  all five permanent Cerulean exits, scoped transit and 22 ordinary pickups.
- Canonical story-slice tests cover Mt. Moon fossils, Bill and Misty. Dedicated
  pickup/transit service tests retain canonical reward and travel safeguards.
- Existing first-gym frontend contract check remains compatible.

This is technical enablement, not complete browser playthrough acceptance.
Active NPC/cutscene presentation, every door/ladder, encounters/capture, Bill's
sequence, Misty's battle/rewards and lower-memory devices still require active
browser gameplay review. The previous construction-only WebGL probe is not
evidence that those active gameplay paths have been played. No production or
public release is authorized by this change.
