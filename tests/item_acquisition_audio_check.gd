extends SceneTree

const ITEM_FOUND_SOUND := "res://assets/audio/sfx/overworld/item_found.ogg"
const ITEM_RECEIVED_SOUND := "res://assets/audio/sfx/overworld/item_received.ogg"
const SFX_MANAGER := "res://scripts/services/sfx_manager.gd"
const INVENTORY_SERVICE := "res://scripts/services/inventory_service.gd"
const UI_OVERLAY := "res://scripts/ui/ui_overlay.gd"
const OAK_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oak.gd"

var failed := false


func _init() -> void:
	var found_stream := load(ITEM_FOUND_SOUND) as AudioStream
	var received_stream := load(ITEM_RECEIVED_SOUND) as AudioStream
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER)
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY)
	var oak_source := FileAccess.get_file_as_string(OAK_SCRIPT)

	_check(found_stream != null, "trimmed item-found OGG loads as an audio stream")
	_check(received_stream != null, "trimmed item-received OGG loads as an audio stream")
	_check(
		sfx_source.contains('"item_found"')
		and sfx_source.contains('"path": "%s"' % ITEM_FOUND_SOUND),
		"SfxManager registers the item-found jingle"
	)
	_check(
		sfx_source.contains('"item_received"')
		and sfx_source.contains('"path": "%s"' % ITEM_RECEIVED_SOUND),
		"SfxManager registers the item-received jingle"
	)
	_check(
		inventory_source.contains('if bool(body.get("claimed", false)):')
		and inventory_source.contains('SfxManager.play("item_received")'),
		"new authoritative NPC rewards play the received-item jingle once"
	)
	_check(
		overlay_source.contains("if granted_count > 0:")
		and overlay_source.contains('SfxManager.play("item_found")'),
		"discovering items in a bundle plays the item-found jingle"
	)
	_check(
		oak_source.contains('if bool(result.get("turnedIn", false)):')
		and oak_source.contains('SfxManager.play("item_received")'),
		"receiving the Pokedex plays the received-item jingle"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
