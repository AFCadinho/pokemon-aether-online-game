extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const TERRAIN_VISUAL_SCRIPT_PATH := "res://scripts/battle/animations/terrain_field_visual.gd"
const TERRAIN_CASES := {
	"GrassyTerrainVisual": "grassy",
	"MistyTerrainVisual": "misty",
	"PsychicTerrainVisual": "psychic",
	"ElectricTerrainVisual": "electric",
}
const TERRAIN_TEXTURES := {
	"grassy": "res://assets/battles/animations/grassyterrain/PRAS- Grass.png",
	"misty": "res://assets/battles/animations/mistyterrain/PRAS- Orbs.png",
	"psychic": "res://assets/battles/animations/psychicterrain/PRAS- Mirror Coat.png",
	"electric": "res://assets/battles/animations/electricterrain/PRAS- Electric.png",
}

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var visual_source := FileAccess.get_file_as_string(TERRAIN_VISUAL_SCRIPT_PATH)
	for visual_name: String in TERRAIN_CASES:
		_check_true(scene_source.contains('[node name="%s" type="Node2D"' % visual_name), "%s uses the reusable terrain visual" % visual_name)
		var expected_type: String = TERRAIN_CASES[visual_name]
		var selects_behavior := scene_source.contains('terrain_type = "%s"' % expected_type)
		if expected_type == "grassy":
			selects_behavior = selects_behavior or visual_source.contains('terrain_type := "grassy"')
		_check_true(selects_behavior, "%s selects its own terrain behavior" % visual_name)

	_check_true(scene_source.contains("PRAS- Grass.png"), "Grassy Terrain uses its imported move sheet")
	_check_true(scene_source.contains("PRAS- Orbs.png"), "Misty Terrain uses its imported move sheet")
	_check_true(scene_source.contains("PRAS- Mirror Coat.png"), "Psychic Terrain uses its imported move sheet")
	_check_true(scene_source.contains("PRAS- Electric.png"), "Electric Terrain uses its imported move sheet")
	_check_true(not scene_source.contains("TerrainParticles"), "legacy rising terrain particles are removed")
	_check_true(visual_source.contains("_draw_grassy_field"), "persistent terrain visuals include grassy leaves")
	_check_true(visual_source.contains("_draw_misty_field"), "persistent terrain visuals include misty orbs")
	_check_true(visual_source.contains("_draw_psychic_field"), "persistent terrain visuals include psychic rings")
	_check_true(visual_source.contains("_draw_electric_field"), "persistent terrain visuals include electric discharges")
	_check_true(
		scene_source.find('[node name="PlayerSpriteBox"') < scene_source.find('[node name="GrassyTerrainLayer"')
		and scene_source.find('[node name="GrassyTerrainLayer"') < scene_source.find('[node name="CaptureBallAnimationPlayer"'),
		"terrain particles render above platforms and Pokemon but below battle overlays"
	)

	for terrain_type: String in TERRAIN_TEXTURES:
		var visual := TerrainFieldVisual.new()
		visual.terrain_type = terrain_type
		visual.source_texture = load(TERRAIN_TEXTURES[terrain_type]) as Texture2D
		visual.elapsed = 1.25
		root.add_child(visual)
		await process_frame
		_check_true(is_instance_valid(visual), "%s terrain visual renders from its move sheet" % terrain_type.capitalize())
		visual.free()

	quit(1 if failed else 0)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
