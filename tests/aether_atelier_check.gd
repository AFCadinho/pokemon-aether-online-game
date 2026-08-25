extends SceneTree

const ATELIER_SERVICE := preload("res://scripts/services/aether_atelier_service.gd")
const ATELIER_POPUP_SCENE := preload("res://scenes/interface/aether_atelier_popup.tscn")
const ATELIER_NPC_SCENE_PATH := "res://scenes/npcs/aether_atelier_npc.tscn"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var service := ATELIER_SERVICE.new()
	var parsed := service.parse_catalog_response({
		"success": true,
		"body": {
			"wallet": {"money": 2500},
			"chromaItems": [{
				"itemId": "adinho-chroma-shirt",
				"name": "Adinho Chroma Shirt",
				"slot": "top",
				"appearanceId": "Adinho_Shirt_Chroma",
				"genders": ["male"],
				"color": "#7a46c5",
				"fee": 2500,
				"equipped": true,
				"tintable": true,
			}],
			"outfits": [{
				"boxItemId": "aether-blossom-outfit",
				"name": "Aether Blossom Outfit",
				"genders": ["female"],
				"fee": 1000,
				"components": [{
					"itemId": "aether-blossom-dress",
					"name": "Aether Blossom Dress",
					"requiredQuantity": 1,
					"ownedQuantity": 1,
					"hasEnough": true,
				}],
				"ownedComponentCount": 1,
				"totalComponentCount": 1,
				"missingItemIds": [],
				"canCreate": true,
			}],
		},
	})
	_check(bool(parsed.get("success", false)), "Atelier service accepts a successful catalog")
	var parsed_outfits: Array = parsed.get("outfits", [])
	_check(parsed_outfits.size() == 1, "Atelier service retains catalog outfits")
	if not parsed_outfits.is_empty():
		var outfit: Dictionary = parsed_outfits[0]
		_check(
			outfit.get("genders", []) == ["female"]
				and bool(outfit.get("canCreate", false)),
			"Atelier service retains gender and completion state"
		)
	var parsed_chroma_items: Array = parsed.get("chromaItems", [])
	_check(
		parsed_chroma_items.size() == 1
			and str((parsed_chroma_items[0] as Dictionary).get("color", "")) == "#7a46c5",
		"Atelier service retains per-item Chroma dye state"
	)
	_check(
		bool((parsed_chroma_items[0] as Dictionary).get("equipped", false)),
		"Atelier service retains worn Chroma state"
	)
	_check(
		bool((parsed_chroma_items[0] as Dictionary).get("tintable", false)),
		"Atelier service identifies Chroma-capable wear items"
	)
	service.free()

	var popup := ATELIER_POPUP_SCENE.instantiate()
	_check(popup is AetherAtelierPopup, "Atelier popup scene uses the searchable Atelier UI")
	_check(
		popup.get("custom_minimum_size") == Vector2(940, 610),
		"Atelier popup has the intended shop workspace size"
	)
	popup.free()

	var npc_source := FileAccess.get_file_as_string(ATELIER_NPC_SCENE_PATH)
	_check(
		npc_source.contains(
			'path="res://scripts/world/npcs/aether_atelier_npc.gd"'
		)
			and npc_source.contains('npc_definition_id = "aether_atelier_tailor"'),
		"Atelier NPC resolves its shared dialogue metadata"
	)

	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(
		ui_source.contains("func open_aether_atelier()")
			and ui_source.contains("_on_aether_atelier_bundle_created")
			and ui_source.contains("_on_aether_atelier_chroma_dyed")
			and ui_source.contains("_activate_ui_panel(aether_atelier_popup)")
			and ui_source.contains("_deactivate_ui_panel(aether_atelier_popup)"),
		"UI overlay applies Atelier inventory and Chroma dye results"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
