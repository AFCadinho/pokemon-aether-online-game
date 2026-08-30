extends "res://scripts/world/map_metadata.gd"

const DUEL_SPAWN_NAMES: Array[StringName] = [
	&"Guild1ArenaSpawn",
	&"Guild2ArenaSpawn",
	&"Guild1JailSpawn",
	&"Guild2JailSpawn",
]


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_sync_duel_spawns()


func _ready() -> void:
	_sync_duel_spawns()


func _sync_duel_spawns() -> void:
	for spawn_name: StringName in DUEL_SPAWN_NAMES:
		var preview_spawn := get_node_or_null("Spawns/%s" % spawn_name) as Marker2D
		var match_spawn := get_node_or_null("PreviewMap/Spawns/%s" % spawn_name) as Marker2D
		if preview_spawn != null and match_spawn != null:
			preview_spawn.position = match_spawn.position
