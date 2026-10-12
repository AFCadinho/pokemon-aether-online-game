extends "battle_3d_alternate_form_check.gd"
## Real BattleDisplay, offline production bundle loader and independent materials.
var output: String
var rows: Array
var battle: Control
var checks := {"complete":false,"shots":[],"material_isolation_samples":0,"material_source_samples":0,"pairs":0,"faint_replacements":0}

func _values(index: int) -> Array:
	var player: AnimationPlayer = stage.players[index]
	var origin := player.get_node(player.root_node)
	var result := []
	for check: Dictionary in rows[1 if stage.identities[index].ends_with("@shiny") else 0].material_checks:
		var path := NodePath(check.path)
		var target := origin.get_node(NodePath(path.get_concatenated_names()))
		result.append(target.get_indexed(NodePath(":"+str(path.get_concatenated_subnames()))))
	return result

func _frames(count: int) -> void:
	for frame in count: await process_frame

func _run() -> void:
	auto_accept_quit = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.always_on_top = true
	root.show()
	process_frame.connect(func(): RenderingServer.force_draw(false))
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	output = OS.get_environment("POKEAETHER_ZYGARDE_UI_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	rows = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_ZYGARDE_NATIVE")))
	fixture = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	if OS.get_environment("POKEAETHER_FORM_BATCH_ADMITTED") == "1":
		for key in fixture.models: assert(Registry.DATA.data.models[key].sha256==fixture.models[key].sha256)
	else:
		Registry.DATA.data.models.merge(fixture.models,true)
		Registry.DATA.data.profiles.merge(fixture.profiles,true)
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST","1")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	var service := LocalBundles.new()
	service.local_index = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("shared/index.json")))
	PairPilot.catalog()
	PairPilot._catalog = service.local_index
	PairPilot._lookups.clear()
	service.local_release = Service.RELEASE_V8.data.duplicate(true)
	service.local_release.revision = service.local_index.catalog_revision
	service.local_release.requiredAssetIds = []
	for asset: Dictionary in service.local_index.assets:
		service.local_release.requiredAssetIds.append(asset.asset_id)
		service.archives[asset.object_key] = directory.path_join("shared/packs").path_join(str(asset.object_key).get_file())
	service.name = "OnDemand3DBundleService"
	root.add_child(service)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	for arena in ["classic","stadium"]:
		settings.battle_3d_arena = arena
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		battle = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(host)
		host.mount(battle)
		stage = battle.animation_router.model_presenter
		for variants in [[false,true],[false,false],[true,true]]:
			stage.set_combatant(0,"zygarde-10",variants[0],true)
			stage.set_combatant(1,"zygarde-10",variants[1],true)
			await stage.await_prepared(true,30000)
			assert(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"),stage.reason)
			assert(stage.arena_id == arena)
			battle.player_hud_panel.set_pokemon_data("Zygarde 10%",100,100,100)
			battle.enemy_hud_panel.set_pokemon_data("Zygarde 10%",100,100,100)
			await create_timer(0.6).timeout
			for index in 2:
				var hud: Control = battle.player_hud_panel if index==0 else battle.enemy_hud_panel
				assert(stage._visual_rect(index).has_area())
				assert(not hud.get_global_rect().intersects(stage._visual_rect(index)),"Actual HUD overlaps model")
			stage.playback_speed = 0.0
			stage.start_action("p2","idle")
			stage.players[1].seek(0,true)
			var other := _values(1)
			for action: String in rows[0].animations:
				stage.set_combatant(0,"zygarde-10",variants[0],true)
				await _frames(3)
				await stage.await_prepared(true,30000)
				stage.start_action("p1",action)
				assert(stage.current_actions[0]==action,"Requested action did not start")

				for fraction in [0.0,0.5,1.0]:
					stage.players[0].seek(stage.players[0].get_animation(action).length*fraction,true)
					await _frames(2)
					assert(_values(1)==other,"Material animation leaked to opponent")
					var current := _values(0)
					var entry: Dictionary = rows[1 if variants[0] else 0]
					var time: float = stage.players[0].get_animation(action).length*fraction
					for i in entry.material_checks.size():
						var check: Dictionary = entry.material_checks[i]
						var keys: Array = check.clips[action]
						var expected := float(keys[0][1])
						for k in range(1,keys.size()):
							if time >= float(keys[k][0]): expected = keys[k][1]
							elif time >= float(keys[k-1][0]):
								expected = lerpf(keys[k-1][1],keys[k][1],(time-float(keys[k-1][0]))/(float(keys[k][0])-float(keys[k-1][0])))
								break
						var actual := float(current[i].a) if check.alpha else float(current[i])
						assert(absf(actual-expected)<0.0001,"Battle material differs from source curve: "+check.material+"/"+action)
						checks.material_source_samples += 1
					checks.material_isolation_samples += 1
					if variants == [false,true] and fraction == 0.5:
						var name: String = arena+"-"+action+".png"
						assert(root.get_texture().get_image().save_png(output.path_join(name))==OK)
						checks.shots.append(name)
			stage.set_combatant(0,"zygarde-10",variants[0],true)
			await _frames(3)
			await stage.await_prepared(true,30000)
			stage.play_action("p1","idle")
			stage.play_action("p2","idle")
			stage.playback_speed = 1.0
			stage.play_action("p1","faint_start")
			stage.players[0].advance(100.0)
			await _frames(4)
			assert(stage.lifecycle[0]=="fainted" and stage.current_actions[1]=="idle")
			stage.set_combatant(0,"zygarde-10",variants[0],true)
			await stage.await_prepared(true,30000)
			assert(stage.lifecycle[0]=="idle" and stage.active)
			checks.faint_replacements += 1
			checks.pairs += 1
		host.queue_free()
		await _frames(3)
	assert(service.requested.size()<=1,"Cached variants downloaded again")
	checks["downloads"] = service.requested.size()
	checks["renderer"] = RenderingServer.get_current_rendering_method()
	checks["fixture_sha256"] = FileAccess.get_sha256(directory.path_join("runtime-fixture.json"))
	checks["index_sha256"] = FileAccess.get_sha256(directory.path_join("shared/index.json"))
	checks.complete = true
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"));file.close()
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("ZYGARDE_BATTLE_UI_OK ",JSON.stringify(checks))
	quit()
