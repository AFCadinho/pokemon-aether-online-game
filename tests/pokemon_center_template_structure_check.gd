extends SceneTree

const HealMachineEffectScript := preload("res://scripts/world/npcs/heal_machine_effect.gd")
const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const HEAL_NPC_PATH := "res://scenes/npcs/heal_npc.tscn"
const PEWTER_CENTER_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pokemon_center.tscn"
const PEWTER_CITY_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
const VIRIDIAN_CENTER_PATH := "res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn"
const VIRIDIAN_CITY_PATH := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"

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
	var nurse_start := template_source.find('[node name="NurseJoy" parent="Entities/NPCs"')
	var nurse_end := template_source.find('[node name="HealMachineEffect"', nurse_start)
	var nurse_source := template_source.substr(nurse_start, nurse_end - nurse_start)
	_check(
		template_source.contains('[node name="NurseJoy" parent="Entities/NPCs"')
		and nurse_source.contains("manual_interaction_reach_tiles = 2")
		and template_source.contains('[node name="Clerk" parent="Entities/NPCs"')
		and template_source.contains('[node name="Clerk2" parent="Entities/NPCs"')
		and template_source.contains('path="res://scenes/npcs/market_seller_npc.tscn"')
		and template_source.contains('path="res://scenes/npcs/market_buyer_npc.tscn"'),
		"Pokémon Center template keeps Nurse Joy reachable and provides generic buyer and seller roles"
	)
	_check(
		template_source.contains(
			'path="res://scenes/npcs/aether_atelier_npc.tscn"'
		)
			and template_source.contains(
				'[node name="AetherAtelier" parent="Entities/NPCs"'
			),
		"Pokémon Center template provides the reusable Aether Atelier tailor"
	)
	_check(
		template_source.contains('path="res://scenes/npcs/move_mentor_npc.tscn"')
			and template_source.contains('[node name="MoveManiac" parent="Entities/NPCs"'),
		"Pokémon Center template provides the reusable Move Maniac"
	)
	_check(
		template_source.contains('path="res://scenes/npcs/move_deleter_npc.tscn"')
			and template_source.contains('[node name="MoveDeleter" parent="Entities/NPCs"')
			and template_source.contains("position = Vector2(656, 464)"),
		"Pokémon Center template provides a separate directly approachable Move Deleter"
	)
	var first_clerk_start := template_source.find('[node name="Clerk" parent="Entities/NPCs"')
	var second_clerk_start := template_source.find('[node name="Clerk2" parent="Entities/NPCs"')
	var atelier_start := template_source.find('[node name="AetherAtelier" parent="Entities/NPCs"', second_clerk_start)
	var second_clerk_end := atelier_start
	if second_clerk_end < 0:
		second_clerk_end = template_source.find('[node name="Interactables"', second_clerk_start)
	var first_clerk_source := template_source.substr(first_clerk_start, second_clerk_start - first_clerk_start)
	var second_clerk_source := template_source.substr(second_clerk_start, second_clerk_end - second_clerk_start)
	_check(
		not first_clerk_source.contains("npc_sprite_frames")
		and not second_clerk_source.contains("npc_sprite_frames"),
		"Pokémon Center clerks inherit sprite frames from the shared clerk scene"
	)
	_check(
		template_source.contains('path="res://scripts/world/npcs/heal_machine_effect.gd"')
		and template_source.contains('[node name="HealMachineEffect" type="Node2D" parent="Entities/NPCs"')
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

	var viridian_center_source := FileAccess.get_file_as_string(VIRIDIAN_CENTER_PATH)
	_check(
		viridian_center_source.contains('instance=ExtResource("1_template")')
			and viridian_center_source.contains('map_id = "kanto_viridian_city_pokemon_center"')
			and viridian_center_source.contains('map_display_name = "Viridian City Pokémon Center"')
			and viridian_center_source.contains('npc_id = "kanto_viridian_city_pokemon_center_nurse_joy"')
			and viridian_center_source.contains('target_spawn_name = "FromPokecenter"'),
		"Viridian City Pokémon Center inherits the shared interior and its local identity"
	)
	var viridian_city_source := FileAccess.get_file_as_string(VIRIDIAN_CITY_PATH)
	_check(
		viridian_city_source.contains('target_scene_path = "res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn"')
			and viridian_city_source.contains('target_spawn_name = "FromOutside"')
			and viridian_city_source.contains('[node name="FromPokecenter" type="Marker2D" parent="Spawns"'),
		"Viridian City connects its Pokémon Center entrance and return spawn"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
