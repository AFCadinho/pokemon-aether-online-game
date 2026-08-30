extends SceneTree

const PORTAL_SCENE := "res://scenes/world/interactables/aether_clash_portal.tscn"

var failed := false


func _init() -> void:
	var packed := load(PORTAL_SCENE) as PackedScene
	_check(packed != null, "Aether Clash portal scene loads")
	if packed == null:
		quit(1)
		return

	var portal := packed.instantiate()
	root.add_child(portal)
	await process_frame
	_check(portal.get("mode_id") == "guild_duel", "Portal defaults to Guild vs Guild mode")
	_check(not bool(portal.get("entry_open")), "Portal entry starts locked outside a war")
	var sprite := portal.get_node_or_null("PortalSprite") as Sprite2D
	var light := portal.get_node_or_null("PortalLight") as PointLight2D
	_check(
		sprite != null and sprite.texture.resource_path.ends_with("clash_portal_red.png"),
		"Guild vs Guild mode receives the red portal art"
	)
	_check(light != null and light.color == Color("ff3829"), "Guild vs Guild portal uses a red glow")
	_check(light != null and light.enabled, "Portal remains visibly energized while entry is locked")
	portal.set("_animation_time", 0.25)
	portal.call("_animate_portal")
	_check(sprite != null and sprite.scale != Vector2.ONE, "Portal continuously pulses")
	_check(portal.has_method("configure_mode_available"), "Portal exposes the mode availability hook")
	portal.call("configure_mode_available", true)
	_check(bool(portal.get("entry_open")), "An available Guild duel opens the portal")
	portal.call("configure_mode_available", false)
	_check(not bool(portal.get("entry_open")), "Unavailable mode closes portal entry")
	_check(light != null and light.enabled, "Closing entry does not deactivate the portal visuals")

	var royale_portal := packed.instantiate()
	royale_portal.set("mode_id", "battle_royale")
	root.add_child(royale_portal)
	await process_frame
	var purple_sprite := royale_portal.get_node_or_null("PortalSprite") as Sprite2D
	_check(
		purple_sprite != null
		and purple_sprite.texture.resource_path.ends_with("clash_portal_purple.png"),
		"Battle Royale mode receives the purple portal art"
	)
	var purple_light := royale_portal.get_node_or_null("PortalLight") as PointLight2D
	_check(
		purple_light != null and purple_light.color == Color("a647ff"),
		"Battle Royale portal uses a purple glow"
	)
	royale_portal.queue_free()
	var exit_portal := packed.instantiate()
	exit_portal.set("portal_action", "exit")
	exit_portal.set("entry_open", true)
	root.add_child(exit_portal)
	_check(exit_portal.get("interactable_kind") == "aether_clash_exit_portal", "Arena copies use exit interaction semantics")
	var portal_source := FileAccess.get_file_as_string("res://scripts/world/interactables/aether_clash_portal.gd")
	_check(
		portal_source.contains('controller_group = "aether_clash_duel_controller"')
		and portal_source.contains('controller_method = "request_portal_exit"'),
		"Arena copies dispatch to the Duel exit controller"
	)
	exit_portal.queue_free()
	portal.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
