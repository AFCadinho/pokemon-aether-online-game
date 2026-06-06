extends Panel

class_name BattlePlatform

enum PlatformSide {
	PLAYER,
	ENEMY,
}

@export var platform_side: PlatformSide = PlatformSide.PLAYER

@onready var hazards: CanvasItem = $Hazards
@onready var sticky_webs_image: TextureRect = $Hazards/StickyWebsImage
@onready var stealth_rock_image: TextureRect = $Hazards/StealthRockImage
@onready var spikes_image: TextureRect = $Hazards/SpikesImage
@onready var toxic_spikes_image: TextureRect = $Hazards/ToxicSpikesImage
@onready var player_screens: CanvasItem = $PlayerScreens
@onready var enemy_screens: CanvasItem = $EnemyScreens
@onready var player_aurora_veil_image: TextureRect = $PlayerScreens/AuroraVeilImage
@onready var player_light_screen_image: TextureRect = $PlayerScreens/LightScreenImage
@onready var player_reflect_image: TextureRect = $PlayerScreens/ReflectImage
@onready var enemy_aurora_veil_image: TextureRect = $EnemyScreens/AuroraVeilImage
@onready var enemy_light_screen_image: TextureRect = $EnemyScreens/LightScreenImage
@onready var enemy_reflect_image: TextureRect = $EnemyScreens/ReflectImage

func _ready() -> void:
	clear_side_effect_visuals()

func clear_side_effect_visuals() -> void:
	hazards.visible = false
	sticky_webs_image.visible = false
	stealth_rock_image.visible = false
	spikes_image.visible = false
	toxic_spikes_image.visible = false
	player_screens.visible = false
	enemy_screens.visible = false
	player_aurora_veil_image.visible = false
	player_light_screen_image.visible = false
	player_reflect_image.visible = false
	enemy_aurora_veil_image.visible = false
	enemy_light_screen_image.visible = false
	enemy_reflect_image.visible = false

func set_side_effects(side_effects: Array) -> void:
	clear_side_effect_visuals()

	for effect_value in side_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var effect_key: String = _normalize_effect_key(str(effect_data.get("effect", "")))
		match effect_key:
			"stickyweb", "stickywebs":
				_set_hazard_visible(sticky_webs_image, true)
			"stealthrock":
				_set_hazard_visible(stealth_rock_image, true)
			"spikes":
				_set_hazard_visible(spikes_image, true)
			"toxicspikes":
				_set_hazard_visible(toxic_spikes_image, true)
			"auroraveil":
				_set_screen_visible("auroraveil", true)
			"lightscreen":
				_set_screen_visible("lightscreen", true)
			"reflect":
				_set_screen_visible("reflect", true)

func _set_hazard_visible(hazard_image: TextureRect, is_visible: bool) -> void:
	hazards.visible = true
	hazard_image.visible = is_visible

func _set_screen_visible(effect_key: String, is_visible: bool) -> void:
	var screens_container: CanvasItem = player_screens if platform_side == PlatformSide.PLAYER else enemy_screens
	screens_container.visible = true

	match effect_key:
		"auroraveil":
			if platform_side == PlatformSide.PLAYER:
				player_aurora_veil_image.visible = is_visible
			else:
				enemy_aurora_veil_image.visible = is_visible
		"lightscreen":
			if platform_side == PlatformSide.PLAYER:
				player_light_screen_image.visible = is_visible
			else:
				enemy_light_screen_image.visible = is_visible
		"reflect":
			if platform_side == PlatformSide.PLAYER:
				player_reflect_image.visible = is_visible
			else:
				enemy_reflect_image.visible = is_visible

func _normalize_effect_key(effect: String) -> String:
	var cleaned: String = effect.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.to_lower().replace(" ", "").replace("_", "").replace("-", "")
