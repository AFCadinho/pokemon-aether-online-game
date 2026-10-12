# Dark / Shiny Flying Nimbus

Dark blue and violet color variant of Flying Nimbus, inspired by the user's
Dark Nimbus references. Created using the built-in imagegen edit tool. The
original generated transparent atlas is retained as `source.png`; the full
prompt is in `prompt.txt`.

Generation: exec-399634e4-cf1c-47d7-8f6e-d15c2ca63f5a.
The original normal source was the edit target. No rider is baked into the
artwork: the real player layers and all four approved seats are reused.

`python3 tools/build_flying_nimbus.py --check` verifies normal and shiny runtime
atlases and offsets. The normal packing rules (64px nearest sampling, binary
alpha, lower-rim foreground masks) also apply to this generated color edit.
The normal artwork remains unchanged. Both variants use the same hover,
interaction anchors and land movement restrictions.

The shared Nimbus trail reads `trailColor` and `trailHighlightColor`; this
variant uses violet #6838ce and pale periwinkle #afaeff. Gold remains the normal
variant's default, including when switching back from shiny.

Grant `shiny-flying-nimbus-mount` through administration and choose
**Shiny Flying Nimbus** in the Land picker. There is no box or store listing.

Preview with `tools/preview_flying_nimbus.gd -- --shiny --output=/absolute/path`.
