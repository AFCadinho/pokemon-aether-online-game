# Shared desktop and Android 3D overview

In a desktop development run, adjust the idle battle camera with left-drag and
the mouse wheel, release the mouse, then press **Ctrl+Shift+C**. This records the
current zoom, yaw/pitch (both radians and degrees), actual camera pose, FOV,
render/screen dimensions and the visible battle-log rectangle. The numeric JSON
is written to `user://battle_camera_capture.json` and printed with the prefix
`DESKTOP_BATTLE_CAMERA_CAPTURE`. Each explicit capture replaces the last one.
It contains no account, team or battle identities. The shortcut is disabled in
release, Android and web builds, during loading/preview/attack shots and while
editing chat. Recording does not change the camera or the default settings.
Restart the development client after integrating this measurement aid; it
cannot read the camera of an already-running client from before the change.

Desktop now uses the Android close-up policy with a slightly wider starting
view: default zoom 0.63 (5% farther than 0.60); Android stays at 0.60. Both use limits
0.30–1.60, the same three-quarter singles direction and wider resting-frame
region. The logical HUD still reserves prompt/move-button space. The camera
fits resting envelopes first, then applies zoom; wheel input can actually move
closer without model-envelope fitting undoing it. Zooming out retains a complete
overview. Camera reset restores the close-up default. Large limbs can crop at
close zoom, as on Android; slot centres remain in front of the near plane.
The desktop default was adjusted after the user's screenshot/reference feedback.
The yaw, pitch and FOV are unchanged. Roster framing is normalized by the current
platform's default, so the small battle-camera adjustment does not zoom the roster.

Pending fullscreen entries reserve one overview from the local lead's compiled
resting profile, with the existing neutral envelope if no profile is available.
That reference and the already approved 4/3 distance adjustment now apply on
desktop too. The arena fades in after two drawn frames while the authoritative
response and model checks continue. The ready 3D field uses the same 0.12-second,
six-step minimum fade as Android; input and intro remain covered until complete
preparation. The old 2D/hybrid fade policy is retained. Actual models still pass
their normal download/integrity gates and use the same retained viewport.

Team Preview keeps its separate roster framing. Android's protected roster view
is retained, while desktop roster zoom is normalized around the new default so
its existing wheel/orbit controls remain available. The 2.5D camera stays
orthographic. Platform-specific camera-motion preferences are unchanged.

The existing cinematic clearance helper is already shared by both platforms:
it raises the lens above nearby grass and upright arena props, preserves focus
and FOV, blends back to the overview during recovery, and does not hide foliage
or change materials. No new per-frame arena scan or geometry modification is
introduced. Its bounding boxes remain conservative around gaps in scenery.

Focused checks cover equal desktop/Android poses across viewport sizes, arenas,
singles/doubles, zoom and orbit; the wider overview and HUD reservation; stable
entry with held response/downloads; repeated entry, preview and cancellation;
mouse-wheel/touch controls; fullscreen blending; and native grass/prop bounds.
Move-camera checks cover Draco Meteor's charge/release/pause/recovery at the new
default, plus catalog choreography. Renderer checks use local fixtures rather
than a live account or server battle.

Completed focused checks: desktop/Android pose parity (108 cases), resting
overview framing (648 cases), singles/orbit/HUD behavior (84 cases), Android
framing regression (216 cases), held-entry/cancellation checks on both policies,
mouse-wheel/touch controls, Draco Meteor and eleven catalog move profiles, all
35 Z-moves, native MultiMesh grass clearance and the native fullscreen fade.
The native fade pixel probe observed ten distinct intermediate blend levels
after a simulated upload stall; the ready 3D early-entry check additionally
asserts at least four intermediate steps. No live desktop battle or additional
desktop GPU has been measured as part of this task.

Integration retained the newer scenery-gap/overhead-roof clearance and Rock
Slide framing from development. The native grass/prop check and eleven move
profiles passed again with these updates; Rock Slide passed 1026 cases including
raised floors, recoil, pause and recovery with the shared close-up default.
