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
	_check(not bool(portal.get("entry_open")), "Portal starts dormant outside a war")
	_check(portal.has_method("configure_war"), "Portal exposes the war-state hook")
	portal.call("configure_war", "war-test", true)
	_check(bool(portal.get("entry_open")), "Active war opens the portal")
	_check(portal.get("active_war_id") == "war-test", "Portal retains its authoritative war id")
	var light := portal.get_node_or_null("PortalLight") as PointLight2D
	_check(light != null and light.enabled, "Open portal enables its colored light")
	portal.call("clear_war")
	_check(not bool(portal.get("entry_open")), "Clearing the war closes the portal")
	portal.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
