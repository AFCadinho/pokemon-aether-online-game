extends Node
## Audio-only clock: no sprites, textures, VFX or gameplay events.
var plan := {}
var streams := {}
var players := {}
var bus := "Master"
var speed := 1.0
var elapsed := 0.0
var cursor := 0
var done := false
var valid: Callable
var clock: Callable
var draining := false
var confirmed_hit := true
var envelopes := {}

func begin() -> void:
	if speed > 0:
		_dispatch()
	if float(plan.get("duration_seconds", 0)) <= 0:
		done = true

func _process(delta: float) -> void:
	for player: AudioStreamPlayer in players.values():
		player.stream_paused = speed <= 0
	if valid.is_valid() and not valid.call():
		cancel()
		if draining:
			queue_free()
		return
	if draining:
		var playing := false
		for player: AudioStreamPlayer in players.values():
			playing = playing or player.playing
		if not playing:
			queue_free()
		return
	if done:
		return
	if speed <= 0:
		return
	elapsed = maxf(elapsed, float(clock.call())) if clock.is_valid() else elapsed + maxf(delta, 0) * speed
	_dispatch()
	_update_envelopes()
	done = elapsed >= float(plan.get("duration_seconds", 0))

func _dispatch() -> void:
	var cues: Array = plan.get("cues", [])
	while cursor < cues.size() and float(cues[cursor].at_seconds) <= elapsed:
		var event: Dictionary = cues[cursor].event
		if (not bool(event.get("requires_hit", false)) or confirmed_hit) and float(event.get("end_seconds", INF)) > elapsed:
			_play_cue(event)
		cursor += 1

func _play_cue(event: Dictionary) -> void:
	var name := str(event.get("name", ""))
	if not streams.has(name):
		return # Missing optional audio must not prevent a battle progressing.
	var player: AudioStreamPlayer = players.get(name)
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = streams[name]
		player.bus = bus
		add_child(player)
		players[name] = player
	player.volume_db = linear_to_db(maxf(0, float(event.get("volume", 100)) / 100.0))
	player.pitch_scale = maxf(.01, float(event.get("pitch", 100)) / 100.0)
	player.play()
	if event.has("end_seconds"):
		envelopes[name] = event

func _update_envelopes() -> void:
	# Envelopes follow the same native clock as the geometry, including pause,
	# slow motion and accelerated playback; audio pitch remains unchanged.
	for name in envelopes.keys():
		var event: Dictionary = envelopes[name]
		var player: AudioStreamPlayer = players[name]
		var remaining := float(event.end_seconds) - elapsed
		if remaining <= 0:
			player.stop()
			envelopes.erase(name)
			continue
		var gain := clampf(remaining / maxf(float(event.fade_seconds), 0.001), 0.0, 1.0)
		player.volume_db = linear_to_db(maxf(0.00001, float(event.get("volume", 100)) / 100.0 * gain))

func drain() -> void:
	if bool(plan.get("bounded_to_action", false)):
		cancel()
		queue_free()
		return
	# Normal action completion lets already-started samples finish independently.
	done = true
	draining = true
	clock = Callable()
	set_process(true)

func cancel() -> void:
	done = true
	clock = Callable()
	valid = Callable() # Release the router/generation closure immediately.
	envelopes.clear()
	for player: AudioStreamPlayer in players.values():
		player.stop()
	set_process(false)
