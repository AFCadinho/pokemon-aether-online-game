# Story interaction client architecture

Story progress is server-owned. `StoryHook` resolves a configured interaction,
`StorySequenceRunner` executes only the catalog-v2 presentation allowlist, and
the hook acknowledges completion only after the full sequence succeeds. A
battle ends the sequence as `pending_battle`; battle results advance story on
the server and are never acknowledged as client presentation progress.

Legacy interaction is allowed only when a successful resolve explicitly
returns `handled: false`. Transport, server, schema, action, and completion
errors fail closed.

Resolved dialogue and trainer metadata must return the exact catalog identity
that was requested before presentation or battle startup begins. Completion
responses advance exactly one story revision. An idempotent retry may replay
its original response snapshot; that retry still succeeds, but the client
never replaces a newer cached story revision with the older snapshot.

## Scene wiring

For an interaction-driven NPC or world object, add a `StoryHook` child and set
its stable `interaction_id`. Set `entity_id` explicitly when the host's
`npc_id` or `interactable_id` is not the catalog identity. Existing NPC,
sign, PC, and generic-interactable behavior remains the fallback while that
known interaction is inactive.

For an area event, use a `StoryTrigger` `Area2D` with a `StoryHook` child and a
collision shape. `story_host_path` identifies the node used as `self` for
dialogue, facing, and movement; an empty path uses the trigger itself. Catalog
`mapId`, `entityId`, and `trigger` must exactly match the runtime context.

No production scene is wired in the foundation layer and the production
catalog is empty. The first real hook belongs in the Pallet Town vertical
slice, together with its catalog definition and reload/reconnect tests.

## Authoring rule for movement

Direction paths are replayable presentation, not authoritative positioning.
Use `move_actor` only from a blocked, known staging position. In particular,
do not author player movement where a retry or reconnect could replay the path
from a changed position and cause cumulative drift.
