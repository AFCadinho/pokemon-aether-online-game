# Battle presentation platform strategy

Accepted product direction — 2026-09-20.

Development sequencing update: focus exclusively on desktop 3D until the model
catalog and 3D experience are stable/production-ready. Preserve architectural
room for 2.5D but defer its development and platform rollout. Do not require
2.5D feature parity for new 3D work. See [3D lifecycle](battle_3d_lifecycle.md).

## Platform roles

| Platform | Battle presentation | Role |
| --- | --- | --- |
| Desktop client | Full 3D experience, with a retained 2.5D option | Primary complete visual experience |
| Browser | Existing animated sprites and 2D battle backgrounds | Low-friction entry without a complete client download |
| Android | Existing animated sprites and 2D battle backgrounds | Convenient portable play |

The overworld remains 2D. Browser and Android are not separate rule sets or
restricted battle simulations. Accounts, progression, battle rules and events
remain shared; presentation must not affect outcomes or competitive timing.
The desktop 2.5D option is a supported player choice, not a deprecated mode.

## Development boundary

- Build and validate 3D models, materials, arenas, cameras and move effects for
  desktop only. Browser/Android 3D compatibility and optimization are outside
  this trajectory. Android build work is not a prerequisite for desktop work.
- Preserve the existing sprite renderer as the shared 2.5D route. Do not fork
  battle logic for the different renderers. Presentation consumes the same
  authoritative battle events and must support cancellation and replay.
- Keep 2.5D as the current default while desktop 3D is experimental. Changing
  the default requires a later readiness decision, not this strategy document.
- Retain the sprite assets and pipeline. Their exact distribution catalog is
  a separate decision: this strategy does not authorize shipping the entire
  high-resolution rendered animation catalog to browser or Android.

## Asset delivery requirements, not implemented guarantees

Browser and Android must not download the desktop 3D catalog. Desktop players
must not be required to download both complete presentation catalogs. Future
packaging should separate shared essentials from presentation-specific assets;
switching modes may require obtaining the selected mode's assets. A small
fallback set must not silently become a second full-catalog dependency.

The current prototype loads local GLBs and retains sprite resources for fallback.
It does not yet satisfy final packaging/memory goals, and this decision adds no
delivery service or catalog migration. Browser startup and sprite download costs
still need their own measured budget; desktop-only 3D does not solve those costs.

## Next desktop milestone

Complete a representative single-battle vertical slice with the existing
Dragonite/Roaring Moon study models before expanding the 3D catalog:

1. Stabilize loading, resource cleanup and action/switch/faint transitions.
2. Add readable arena framing and controlled camera movement, with a stable
   camera option. Keep the HUD usable and attack targets clear.
3. Validate identical battle state and event completion in 3D and 2.5D, including
   replay, speed changes, cancellation and unsupported-situation fallback.
4. Measure desktop frame time, memory and action-start latency and visually
   review the result before scaling up species or designing final asset packs.

These are follow-up milestones, not claims that the prototype already provides
them. See [desktop preview instructions](battle_3d_desktop_preview.md) for its
current capabilities and known limitations.
