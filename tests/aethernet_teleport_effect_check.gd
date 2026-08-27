extends SceneTree

const AethernetTeleportEffectScript := preload(
	"res://scripts/world/aethernet_teleport_effect.gd"
)

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var texture := load(
		"res://assets/battles/animations/teleport/PRAS- Teleport.png"
	) as Texture2D
	var sound := load(
		"res://assets/battles/animations/teleport/PRSFX- Teleport.wav"
	) as AudioStream
	_check(texture != null and texture.get_size() == Vector2(384, 192), "effect reuses the Teleport move sheet")
	_check(sound != null, "local Aethernet travel reuses the Teleport move sound")

	var target := Node2D.new()
	root.add_child(target)
	var departure := AethernetTeleportEffectScript.new() as AethernetTeleportEffect
	root.add_child(departure)
	departure.start(target, "depart", false)
	await departure.finished
	_check(target.modulate.a <= 0.01, "departure dissolves the trainer")

	var arrival := AethernetTeleportEffectScript.new() as AethernetTeleportEffect
	root.add_child(arrival)
	arrival.start(target, "arrive", false)
	await arrival.finished
	_check(target.modulate.a >= 0.99, "arrival rematerializes the trainer")

	var keeper_source := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/transit_keeper_npc.gd"
	)
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var presence_source := FileAccess.get_file_as_string(
		"res://scripts/services/world_presence_service.gd"
	)
	var remote_source := FileAccess.get_file_as_string(
		"res://scripts/world/remote_player_avatar.gd"
	)
	_check(
		keeper_source.contains('await world.call("play_aethernet_departure_effect")'),
		"Aethernet travel waits for its departure animation"
	)
	_check(
		world_source.contains('await _play_local_aethernet_effect("arrive", false)'),
		"authorized Aethernet travel plays the arrival animation"
	)
	_check(
		presence_source.contains('"aethernetEffect"'),
		"Aethernet effect phase is sent through world presence"
	)
	_check(
		remote_source.contains('effect.call("start", self, phase, false)'),
		"remote trainers play the effect without sound"
	)

	target.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failed = true
	push_error("FAIL: %s" % label)
