extends Node
const AudioPlayer = preload("res://scripts/battle/animations/battle_audio_player.gd")
const Catalog = preload("res://scripts/battle/animations/battle_audio_catalog.gd")

class RecordingPlayer extends AudioPlayer:
	var heard: Array = []
	func _play_cue(event: Dictionary) -> void:
		heard.append(event.name)

class Presenter extends Node:
	signal released
	var active := true
	var delayed := false
	func handles(_ident: String) -> bool:
		return true
	func attack_action_for(_move: String) -> String:
		return "physical_attack"
	func start_action(_actor: String, _action: String) -> void:
		pass
	func wait_action(_actor: String) -> void:
		if delayed:
			await released

var move_completed := false
func _move(driver, presenter: Node, audio: Node) -> void:
	await driver.play_move(presenter, "Fixture", "p1", "p2", {}, audio)
	move_completed = true

func _ready() -> void:
	var player := RecordingPlayer.new()
	add_child(player)
	player.set_process(false)
	player.plan = {"duration_seconds": 1.0, "cues": [
		{"at_seconds": 0.0, "event": {"name": "start"}},
		{"at_seconds": 0.5, "event": {"name": "middle"}},
		{"at_seconds": 0.9, "event": {"name": "end"}}]}
	player.begin()
	assert(player.heard == ["start"])
	player.speed = 0
	player._process(5)
	assert(player.elapsed == 0 and player.heard.size() == 1)
	player.speed = 2
	player._process(.25)
	assert(player.heard == ["start", "middle"])
	player.speed = 1
	player._process(.5)
	assert(player.done and player.heard == ["start", "middle", "end"])
	player._process(5)
	assert(player.heard.size() == 3)
	player.free()
	var paused_start := RecordingPlayer.new()
	paused_start.plan = {"duration_seconds": 1, "cues": [{"at_seconds": 0, "event": {"name": "resume"}}]}
	paused_start.speed = 0
	paused_start.begin()
	assert(paused_start.heard.is_empty())
	paused_start.speed = 1
	paused_start._process(.01)
	assert(paused_start.heard == ["resume"])
	paused_start.free()
	var cancelled := RecordingPlayer.new()
	cancelled.plan = {"duration_seconds": 2, "cues": [{"at_seconds": 1, "event": {"name": "late"}}]}
	add_child(cancelled)
	cancelled.set_process(false)
	cancelled.begin()
	cancelled.cancel()
	cancelled._process(10)
	assert(cancelled.done and cancelled.heard.is_empty())
	cancelled.free()
	var invalidated := RecordingPlayer.new()
	invalidated.plan = {"duration_seconds": 2, "cues": [{"at_seconds": 1, "event": {"name": "stale"}}]}
	invalidated.valid = func(): return false
	invalidated._process(10)
	assert(invalidated.done and invalidated.heard.is_empty())
	invalidated.free()
	var catalog := Catalog.new()
	for key in ["outrage", "dragondance", "roost"]:
		var plan := catalog.get_plan("move", key)
		assert(not plan.is_empty() and not plan.cues.is_empty())
		assert(not plan.has("sheet_path") and not plan.has("background_path"))
	assert(not catalog.get_plan("effect", "stat_up").is_empty())
	assert(catalog.get_plan("move", "unknown-fixture").is_empty())
	# Real audio-node properties: pitch is source pitch, never multiplied by
	# playback speed. Cancellation stops streams, not merely future cues.
	var real := AudioPlayer.new()
	add_child(real)
	real.set_process(false)
	var wave := AudioStreamWAV.new()
	wave.data = PackedByteArray([128, 128, 128, 128])
	real.streams = {"tone": wave}
	real.plan = {"duration_seconds": 5.0, "cues": [{"at_seconds": 0.0, "event": {"name": "tone", "volume": 50.0, "pitch": 120.0}}]}
	real.begin()
	assert(real.players.size() == 1 and is_equal_approx(real.players.tone.pitch_scale, 1.2))
	real.speed = 0
	real._process(1)
	assert(real.players.tone.stream_paused and real.elapsed == 0)
	real.speed = 4
	real._process(.1)
	assert(not real.players.tone.stream_paused and is_equal_approx(real.players.tone.pitch_scale, 1.2))
	real.cancel()
	assert(not real.players.tone.playing)
	real.free()
	# Both lifetimes overlap; neither is silently shortened or played serially.
	var driver = preload("res://scripts/battle/battle_move_presentation_3d.gd").new()
	var presenter := Presenter.new()
	add_child(presenter)
	var pending := RecordingPlayer.new()
	add_child(pending)
	pending.set_process(false)
	_move(driver, presenter, pending)
	assert(not move_completed)
	pending.done = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert(move_completed, "Short native clip must still wait for audio")
	move_completed = false
	presenter.delayed = true
	_move(driver, presenter, pending)
	assert(not move_completed)
	presenter.released.emit()
	assert(move_completed, "Short audio must not truncate the native clip")
	pending.free()
	presenter.free()
	await get_tree().create_timer(.1).timeout # Let the audio mixer release stopped playback refs.
	print("BATTLE_AUDIO_PLAYBACK_OK")
	get_tree().quit()
