extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const RENDERER_PATHS: Array[String] = [
	"res://scripts/world/player.gd",
	"res://scripts/world/remote_player_avatar.gd",
	"res://scripts/ui/login_screen.gd",
	"res://scripts/ui/ui_overlay.gd",
	"res://scripts/ui/donator_store_popup.gd",
	"res://scripts/ui/aether_atelier_popup.gd",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		not FileAccess.file_exists("res://assets/player/hair/Bald_Hair.png"),
		"the obsolete bald-dot spritesheet is removed"
	)
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/services/character_appearance_service.gd"
	)
	_check(
		not service_source.contains("BASE_HAIR_ID")
		and not service_source.contains("resolve_hair_render_id"),
		"no hidden hairstyle can replace an explicitly empty hair slot"
	)
	_check(
		APPEARANCE.serialize_part_id("") == APPEARANCE.UNEQUIPPED_PART_ID
		and APPEARANCE.deserialize_part_id(APPEARANCE.UNEQUIPPED_PART_ID) == "",
		"the explicit no-hair state keeps its presence representation"
	)
	_check(
		APPEARANCE.get_part_frames("hair", "", "male") == null
		and APPEARANCE.get_tinted_part_frames("hair", "", "female") == null,
		"an empty hair slot renders no sprite layer"
	)

	for renderer_path: String in RENDERER_PATHS:
		var renderer_source := FileAccess.get_file_as_string(renderer_path)
		_check(
			not renderer_source.contains("resolve_hair_render_id"),
			"%s does not restore the removed bald-dot fallback" % renderer_path
		)

	var remote_script := load("res://scripts/world/remote_player_avatar.gd") as Script
	var remote_avatar := remote_script.new() as Node
	remote_avatar.set("current_body_gender", "male")
	remote_avatar.set(
		"current_appearance_state",
		{"hair": APPEARANCE.UNEQUIPPED_PART_ID}
	)
	_check(
		remote_avatar.call("_get_appearance_hair_id") == "",
		"remote players render explicit no-hair presence without a sprite"
	)
	remote_avatar.set("current_appearance_state", {})
	_check(
		remote_avatar.call("_get_appearance_hair_id")
		== APPEARANCE.get_default_part_id("hair", "male"),
		"legacy remote presence without a hair field keeps Starter Hair"
	)
	remote_avatar.free()

	for hairstyle_id: String in ["Hair", "Adinho_Hair", "IronFanton_Hair"]:
		_check(
			APPEARANCE.get_tinted_part_frames(
				"hair",
				hairstyle_id,
				"male",
				APPEARANCE.BODY_MOVEMENT_DEFAULT,
				Color("#5a3728"),
				true
			) != null,
			"%s still renders as an independent hairstyle" % hairstyle_id
		)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
