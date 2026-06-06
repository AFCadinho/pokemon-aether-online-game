extends Panel

class_name BattlePlatform

@onready var sticky_webs_image: TextureRect = $StickyWebsImage
@onready var stealth_rock_image: TextureRect = $StealthRockImage
@onready var spikes_image: TextureRect = $SpikesImage
@onready var toxic_spikes_image: TextureRect = $ToxicSpikesImage

func _ready() -> void:
	clear_hazards()

func clear_hazards() -> void:
	sticky_webs_image.visible = false
	stealth_rock_image.visible = false
	spikes_image.visible = false
	toxic_spikes_image.visible = false

func set_side_effects(side_effects: Array) -> void:
	clear_hazards()

	for effect_value in side_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var effect_key: String = _normalize_effect_key(str(effect_data.get("effect", "")))
		match effect_key:
			"stickyweb", "stickywebs":
				sticky_webs_image.visible = true
			"stealthrock":
				stealth_rock_image.visible = true
			"spikes":
				spikes_image.visible = true
			"toxicspikes":
				toxic_spikes_image.visible = true

func _normalize_effect_key(effect: String) -> String:
	var cleaned: String = effect.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.to_lower().replace(" ", "").replace("_", "").replace("-", "")
