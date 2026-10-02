extends "res://tests/battle_3d_first_five_forms_check.gd"
## Real battle: three exact revised form pairs, on-demand loads and all clips.
func _run() -> void:
	var work := OS.get_environment("POKEAETHER_OGERPON_REVISION_WORK")
	assert(work.is_absolute_path())
	fixture = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("runtime-fixture.json")))
	Registry.DATA.data.models.merge(fixture.models, true)
	Registry.DATA.data.profiles.merge(fixture.profiles, true)
	var service := LocalBundles.new()
	service.local_index = JSON.parse_string(FileAccess.get_file_as_string(work.path_join("bundles/asset-index.json")))
	for asset: Dictionary in service.local_index.assets:
		Service.RELEASE.data.requiredAssetIds.append(asset.asset_id)
		service.archives[asset.object_key] = work.path_join("bundles").path_join(str(asset.object_key).get_file())
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	service.name = "OnDemand3DBundleService"
	root.add_child(service)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	stage = Renderer.new()
	root.add_child(stage)
	stage.setup()
	for species in ["ogerpon-wellspring", "ogerpon-hearthflame", "ogerpon-cornerstone"]:
		stage.set_combatant(0, species, false)
		stage.set_combatant(1, species, true)
		await stage.await_prepared(true, 30000)
		assert(stage.active and not stage.preparation_failed, stage.reason)
		assert(stage.handles("p1") and stage.handles("p2"))
		assert(stage.identities.slice(0, 2) == [species, species+"@shiny"])
		assert(stage._anticipated_form_keys().is_empty())
		assert(not stage._models_pending())
		assert(stage.attack_action_for("Body Slam", "p1") == "physical_attack_2")
		assert(stage.attack_action_for("Ivy Cudgel", "p1") == "physical_attack")
		for identity in [species, species+"@shiny"]:
			assert(stage.packed.has(identity))
			var scene: Node = stage.packed[identity].instantiate()
			var players := scene.find_children("*", "AnimationPlayer", true, false)
			assert(players.size() == 1)
			for action in ["idle", "physical_attack", "physical_attack_2", "special_attack", "sleep", "damage", "faint_start", "faint_loop"]:
				assert(players[0].has_animation(action))
			scene.free()
	stage.queue_free()
	await process_frame
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("OGERPON_CLOAK_BATTLE_OK pairs=3 models=6 loaded_before_reveal=true clips=48 attack_mapping=true")
	quit()
