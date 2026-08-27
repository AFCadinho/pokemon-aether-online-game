extends "res://scripts/world/map_metadata.gd"


func _enter_tree() -> void:
	var template := get_node_or_null("PewterGymTemplate")
	if template == null:
		return
	for branch_name: String in ["Visuals", "FloorVisibilityMask", "Entities", "Spawns", "Exits"]:
		var branch := template.get_node_or_null(branch_name)
		if branch != null:
			branch.free()


func _ready() -> void:
	super._ready()
