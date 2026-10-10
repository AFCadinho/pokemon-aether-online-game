# Mobile context actions

Touch-generated mouse presses on registered controls use the shared
`scripts/ui/mobile/touch_context_gesture.gd` recognizer. A stationary press of
0.5 seconds dispatches the existing right-click handler. A short tap replays
the existing left-click flow through Godot's viewport. Movement over 10 viewport
units hands the original press back to the existing drag path. Real mouse input
retains its original timing.

The party, Bag, hotbar, PC (including search results), and chat message/sender
controls register the same adapter. Other players use their existing interaction
hit area before the mobile movement pad handles the touch; a short tap retains
ordinary world interaction. World holds do not start the joystick. Nearby battle
spectating retains its existing priority. The photo camera supports direct
one-finger dragging outside its controls, scaled to camera zoom.

The recognizer handles Godot's paired native-touch and emulated-mouse events,
second-finger cancellation, hidden/disabled targets, and application focus loss.
It clears the emulated left-button state before opening a popup and observes the
popup window's release so lifting the opening finger cannot select an action or
leave the gesture active. Closed/freed controls release their signal connections.

Touch-specific hints are localized in English, Dutch, Portuguese and Chinese.
Desktop hints and context handlers remain available. New right-click UI actions
should register with `TouchContextGesture.attach(control, input_handler)` rather
than connecting the context handler directly to `gui_input`.

The focused regression check sends both emulated mouse events and native touch
events through Godot's input pipeline, exercises real party slots, native Bag
dragging, remote-player context dispatch, popup release and the photo camera.
It runs headless and with the desktop renderer. A physical Android/iOS device
and browser touch smoke test remain useful at release verification; this task
does not build, publish or deploy a client.
