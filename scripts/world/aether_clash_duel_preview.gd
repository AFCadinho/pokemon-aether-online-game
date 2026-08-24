extends "res://scripts/world/map_metadata.gd"

const JAIL_SPAWN_PATH := ^"Spawns/JailSpawn"
const MATCH_JAIL_SPAWN_PATH := ^"PreviewMap/Spawns/JailSpawn"


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_sync_jail_spawn()


func _ready() -> void:
	_sync_jail_spawn()


func _sync_jail_spawn() -> void:
	var jail_spawn := get_node_or_null(JAIL_SPAWN_PATH) as Marker2D
	var match_jail_spawn := get_node_or_null(MATCH_JAIL_SPAWN_PATH) as Marker2D
	if jail_spawn == null or match_jail_spawn == null:
		return
	jail_spawn.position = match_jail_spawn.position
