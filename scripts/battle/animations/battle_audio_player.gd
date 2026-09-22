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

func begin() -> void:
	if speed > 0:
		_dispatch()
	if float(plan.get("duration_seconds", 0)) <= 0:
		done = true

func _process(delta: float) -> void:
	for player: AudioStreamPlayer in players.values():
		player.stream_paused = speed <= 0
	if done:
		return
	if valid.is_valid() and not valid.call():
		cancel()
		return
	if speed <= 0:
		return
	elapsed += maxf(delta, 0) * speed
	_dispatch()
	done = elapsed >= float(plan.get("duration_seconds", 0))

func _dispatch() -> void:
	var cues: Array = plan.get("cues", [])
	while cursor < cues.size() and float(cues[cursor].at_seconds) <= elapsed:
		_play_cue(cues[cursor].event)
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

func cancel() -> void:
	done = true
	valid = Callable() # Release the router/generation closure immediately.
	for player: AudioStreamPlayer in players.values():
		player.stop()
	set_process(false)
