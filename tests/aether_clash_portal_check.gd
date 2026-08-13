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
	_check(portal.get("team_id") == "purple", "Portal defaults to the purple team")
	_check(not bool(portal.get("entry_open")), "Portal entry starts locked outside a war")
	var sprite := portal.get_node_or_null("PortalSprite") as Sprite2D
	var light := portal.get_node_or_null("PortalLight") as PointLight2D
	_check(light != null and light.enabled, "Portal remains visibly energized while entry is locked")
	portal.set("_animation_time", 0.25)
	portal.call("_animate_portal")
	_check(sprite != null and sprite.scale != Vector2.ONE, "Portal continuously pulses")
	_check(portal.has_method("configure_war"), "Portal exposes the war-state hook")
	portal.call("configure_war", "war-test", true)
	_check(bool(portal.get("entry_open")), "Active war opens the portal")
	_check(portal.get("active_war_id") == "war-test", "Portal retains its authoritative war id")
	portal.call("clear_war")
	_check(not bool(portal.get("entry_open")), "Clearing the war closes the portal")
	_check(light != null and light.enabled, "Closing entry does not deactivate the portal visuals")

	var red_portal := packed.instantiate()
	red_portal.set("team_id", "red")
	root.add_child(red_portal)
	await process_frame
	var red_sprite := red_portal.get_node_or_null("PortalSprite") as Sprite2D
	_check(
		red_sprite != null and red_sprite.texture.resource_path.ends_with("clash_portal_red.png"),
		"Red team always receives the red portal art"
	)
	var red_light := red_portal.get_node_or_null("PortalLight") as PointLight2D
	_check(red_light != null and red_light.color == Color("ff3829"), "Red portal uses a red glow")
	red_portal.queue_free()
	portal.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
