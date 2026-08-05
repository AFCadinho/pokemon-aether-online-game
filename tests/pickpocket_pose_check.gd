extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const PLAYER_PATH := "res://scripts/world/player.gd"

const BODY_ASSETS := [
	"res://assets/player/male/body/pickpocket/Gen4_Base_v1_pickpocket.png",
	"res://assets/player/male/body/pickpocket/Gen4_Base_M_Tan_pickpocket.png",
	"res://assets/player/male/body/pickpocket/Gen4_Base_M_Dark_pickpocket.png",
	"res://assets/player/female/body/pickpocket/Gen4_Base_F_v1_pickpocket.png",
	"res://assets/player/female/body/pickpocket/Gen4_Base_F_Tan_pickpocket.png",
	"res://assets/player/female/body/pickpocket/Gen4_Base_F_Dark_pickpocket.png",
]

var failed := false


func _init() -> void:
	for asset_path: String in BODY_ASSETS:
		_check(ResourceLoader.exists(asset_path), "Rodless body pose exists: %s" % asset_path.get_file())
		var texture := load(asset_path) as Texture2D
		if texture == null:
			continue
		var image := texture.get_image()
		_check(image.get_width() == 256 and image.get_height() == 256, "Rodless pose keeps the 4x4 sheet")
		for removed_rod_pixel: Vector2i in [
			Vector2i(31, 52),
			Vector2i(20, 107),
			Vector2i(45, 171),
			Vector2i(29, 198),
		]:
			_check(
				image.get_pixelv(removed_rod_pixel).a == 0.0,
				"%s removes rod pixel %s" % [asset_path.get_file(), removed_rod_pixel]
			)

	var fishing_texture := load(
		"res://assets/player/male/body/fish/Gen4_Base_v1_fish.png"
	) as Texture2D
	_check(
		fishing_texture != null and fishing_texture.get_image().get_pixel(31, 52).a > 0.0,
		"Original fishing body keeps its rod"
	)
	_check(
		APPEARANCE.normalize_movement_style("thieving") == APPEARANCE.BODY_MOVEMENT_PICKPOCKET,
		"Thieving resolves to the dedicated pickpocket movement style"
	)
	_check(
		APPEARANCE.resolve_layer_movement_style("pickpocket", "body")
			== APPEARANCE.BODY_MOVEMENT_PICKPOCKET,
		"Pickpocket uses its rodless body pose"
	)
	for category: String in ["top", "bottom", "shoes"]:
		_check(
			APPEARANCE.resolve_layer_movement_style("pickpocket", category)
				== APPEARANCE.BODY_MOVEMENT_FISH,
			"Pickpocket reuses the fishing %s pose" % category
		)
	_check(
		APPEARANCE.get_body_frames(
			APPEARANCE.DEFAULT_MALE_BODY_ID,
			"male",
			APPEARANCE.BODY_MOVEMENT_PICKPOCKET
		) != null,
		"Male pickpocket body frames load"
	)
	_check(
		APPEARANCE.get_body_frames(
			APPEARANCE.DEFAULT_FEMALE_BODY_ID,
			"female",
			APPEARANCE.BODY_MOVEMENT_PICKPOCKET
		) != null,
		"Female pickpocket body frames load"
	)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	_check(
		player_source.count(
			"normalized_style == CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET"
		) == 2,
		"Pickpocket pose reuses fishing layer and visual offsets"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
