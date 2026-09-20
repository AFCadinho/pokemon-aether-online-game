extends "res://tools/sprite_factory/cave_battle_review.gd"
## Offline, render-synchronized calibration. Does not rewrite source models.
var grounding := {}
func _place_actor(actor: Node3D, animation_player: AnimationPlayer) -> void:
	await super._place_actor(actor,animation_player)
	var index: int = stage.actors.find(actor)
	var entry: Dictionary = entries[index]
	grounding[entry.species] = {"sha256":FileAccess.get_sha256(entry.runtime_path),
		"scale":actor.scale.x,"lift":actor.position.y}

func _smoke() -> void:
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if FileAccess.file_exists(report+".runtime.json"):
		report += ".runtime.json"
	assert(grounding.size()==2)
	var file := FileAccess.open(report+".grounding.json",FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"schema":1,"entries":grounding},"\t"))
	file.close()
	print("ARENA_GROUNDING_EXPORTED ",report+".grounding.json")
	quit()
