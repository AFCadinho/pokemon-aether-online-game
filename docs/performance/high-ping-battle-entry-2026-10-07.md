# High-ping PvE entry, 2026-10-07

## Player-visible change

Wild entry combines position persistence and battle creation in one client HTTP
request. Ordinary trainer entry does the same, and combines automatic player
and NPC lead selection in a second request. Successful-path external request
counts therefore change from 2 to 1 for wild entry and 4 to 2 for trainers without
interactive Team Preview. Required repel-step flushes and exceptional party
refresh/recovery reads remain separate. No additional infrastructure is used.

This removes sequential client round trips. It does not reduce physical network
RTT and is not a measured China latency result. Position and creation remain
ordered cross-service operations; they are not advertised as one transaction.

## Preserved behavior

- Reuse account-service desktop/browser position endpoints and their session,
  maintenance, detention, co-op, appearance, map and teleport validation.
- Serialize against in-flight position saves. Reconcile saved walk steps,
  appearance, teleport revision and happiness even when creation then fails.
- Apply authoritative walking happiness to the battle team before creation.
- Keep existing battle admission, active-battle conflicts and resume recovery.
- Keep both player and NPC lead responses for ordered client state processing.
- Require an owned ordinary PvE battle for lead batching; PvP, AI training and
  interactive Team Preview keep their existing selection contracts.
- Weekly-boss admission and developer-created encounters keep their own paths.
- Preserve the already-visible pending arena and authoritative outcome rules.
- Reject delayed position responses after account-session changes.

## Compatibility and rollout

Older clients continue to use existing routes. New clients fall back only when
a new route is absent (404 `Not Found`) or an older browser bridge rejects it
before forwarding (403 `web_route_not_allowed`). A timeout, auth/maintenance
error, domain-level 404, or acknowledged partial operation does not replay.

Fallback costs one extra unsupported-route probe until the backend/browser
bridge is upgraded. Deploy the backend before distributing the new client.
Browser publication must include the scoped production bridge allowlist updates.
No build, publication, push, promotion or deployment is part of this task.

## Focused validation

- `high_ping_battle_start_check.gd`: single-request wild/trainer/lead success,
  unchanged position payload, rematches, no retry on failures/partial starts,
  acknowledgement validation, legacy backend/bridge compatibility, walking
  happiness, stale session rejection and teleport/save reconciliation.
- Existing wild/trainer entry checks: fullscreen and classic pending arena,
  hidden unknown combatants, interactive preview and rejected-entry cleanup.
- Existing activity recovery, authorized teleport, browser readiness and repel
  checks exercise neighboring fences.
- 174 battle-orchestrator unit tests (new start contracts, existing controller,
  trainer resume and wild capture context), 19 gateway proxy tests, browser
  function route tests and 12 connected browser proxy tests.
- Four pre-existing controller test failures were reproduced against unchanged
  development: three incomplete AI-session fixtures and one old encounter
  catalog expectation. Only those fixtures/expectations were updated.

Full paired certification and real-device/China measurements remain release
work. The download, action-feedback and remote-movement suggestions from the
broader investigation are not implemented by this battle-entry change.
