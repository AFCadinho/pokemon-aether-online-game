extends SceneTree

const HealMachineEffectScript := preload("res://scripts/world/npcs/heal_machine_effect.gd")
const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const HEAL_NPC_PATH := "res://scenes/npcs/heal_npc.tscn"
const PEWTER_CENTER_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pokemon_center.tscn"
const PEWTER_CITY_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"

var failed := false


func _init() -> void:
	var template_source := FileAccess.get_file_as_string(TEMPLATE_PATH)
	_check(
		template_source.contains('script = ExtResource("3_map_meta")'),
		"Pokémon Center template is a complete map root"
	)
	_check(
		template_source.contains('[node name="Visuals" parent="."'),
		"Pokémon Center template owns its generated visuals"
	)
	_check(
		template_source.contains('[node name="Collision" type="TileMapLayer" parent="."'),
		"Pokémon Center template owns root-level collision"
	)
	_check(
		template_source.count('[node name="Entities" type="Node2D" parent="."') == 1,
		"Pokémon Center template has exactly one root Entities container"
	)
	_check(
		template_source.contains('[node name="Players" type="Node2D" parent="Entities"')
		and template_source.contains('[node name="NPCs" type="Node2D" parent="Entities"')
		and template_source.contains('[node name="Interactables" type="Node2D" parent="Entities"'),
		"Pokémon Center template provides the standard Entities branches"
	)
	_check(
		template_source.contains('[node name="NurseJoy" parent="Entities/NPCs"')
		and template_source.contains('[node name="Clerk" parent="Entities/NPCs"')
		and template_source.count('npc_definition_id = "pokemon_center_clerk"') == 2,
		"Pokémon Center template provides staff with shared definitions"
	)
	var first_clerk_start := template_source.find('[node name="Clerk" parent="Entities/NPCs"')
	var second_clerk_start := template_source.find('[node name="Clerk2" parent="Entities/NPCs"')
	var interactables_start := template_source.find('[node name="Interactables"', second_clerk_start)
	var first_clerk_source := template_source.substr(first_clerk_start, second_clerk_start - first_clerk_start)
	var second_clerk_source := template_source.substr(second_clerk_start, interactables_start - second_clerk_start)
	_check(
		not first_clerk_source.contains("npc_sprite_frames")
		and not second_clerk_source.contains("npc_sprite_frames"),
		"Pokémon Center clerks inherit sprite frames from the shared clerk scene"
	)
	_check(
		template_source.contains('path="res://scripts/world/npcs/heal_machine_effect.gd"')
		and template_source.contains('[node name="HealMachineEffect" type="Node2D" parent="Entities/NPCs"]')
		and template_source.contains("position = Vector2(464, 600)")
		and template_source.contains('signal="heal_sequence_started"')
		and template_source.contains('method="play_heal_sequence"'),
		"Pokémon Center connects Nurse Joy to the healing machine light sequence"
	)
	var heal_machine_effect := HealMachineEffectScript.new()
	_check(
		heal_machine_effect.has_method("play_heal_sequence"),
		"Healing machine effect exposes its reusable playback entrypoint"
	)
	_check(
		int(heal_machine_effect.get("indicator_columns")) == 2,
		"Healing machine arranges party indicators in two columns"
	)
	heal_machine_effect.call("play_heal_sequence", 0.8, 3)
	_check(
		int(heal_machine_effect.get("_visible_indicator_count")) == 3,
		"Healing machine limits indicators to the current party size"
	)
	heal_machine_effect.free()
	var heal_npc_source := FileAccess.get_file_as_string(HEAL_NPC_PATH)
	_check(
		heal_npc_source.contains('npc_definition_id = "pokemon_center_nurse"'),
		"Heal NPC scene defaults to the shared nurse definition"
	)
	_check(
		template_source.contains('[node name="FromOutside" type="Marker2D" parent="Spawns"')
		and template_source.contains('[node name="ToOutside" type="Area2D" parent="Exits"'),
		"Pokémon Center template provides generic entrance and exit nodes"
	)

	var center_source := FileAccess.get_file_as_string(PEWTER_CENTER_PATH)
	_check(
		center_source.contains('instance=ExtResource("1_template")'),
		"Pewter City Pokémon Center inherits the full template"
	)
	_check(
		not center_source.contains("script = null")
		and center_source.contains('map_id = "kanto_pewter_city_pokemon_center"')
		and center_source.contains('map_display_name = "Pewter City Pokémon Center"'),
		"Pewter City preserves inherited map metadata and its location overrides"
	)
	_check(
		not center_source.contains("generated/tiled_visuals/pokemon_center"),
		"Pewter City does not duplicate the visuals inherited from the template"
	)
	_check(
		not center_source.contains('[node name="Entities" type="Node2D"'),
		"Pewter City Pokémon Center does not duplicate Entities"
	)
	_check(
		center_source.contains('npc_id = "kanto_pewter_city_pokemon_center_nurse_joy"')
		and center_source.contains('respawn_point_id = "kanto_pewter_city_pokemon_center"')
		and center_source.contains('npc_id = "kanto_pewter_city_pokemon_center_clerk"'),
		"Pewter City overrides location-specific staff identity and respawn data"
	)
	_check(
		center_source.contains('target_spawn_name = "FromPokecenter"'),
		"Pewter City Pokémon Center configures its inherited exit"
	)

	var city_source := FileAccess.get_file_as_string(PEWTER_CITY_PATH)
	_check(
		city_source.contains('target_spawn_name = "FromOutside"'),
		"Pewter City enters the inherited generic Pokémon Center spawn"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
