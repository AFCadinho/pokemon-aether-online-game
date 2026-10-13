extends "battle_3d_alternate_form_check.gd"
## Final reconstructed forms: compare the packaged actor with its corrected native scene.
var output: String
var rows: Array
var battle: Control
var checks := {"complete":false,"shots":[],"material_isolation_samples":0,"material_source_samples":0,"pairs":0,"faint_replacements":0}

const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
var species_name: String
var references: Array[Node] = []
var texture_signatures := {}

func _appearance(actor: Node) -> Dictionary:
	var result := {}
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		var key := str(actor.get_path_to(mesh))
		if str(mesh.name).ends_with("__sleep_eyes"):
			var awake: MeshInstance3D = mesh.get_parent().get_node(str(mesh.name).trim_suffix("__sleep_eyes"))
			assert(mesh.visible!=awake.visible,"Exactly one eye state must be visible")
			if not mesh.visible:continue
			key=key.trim_suffix("__sleep_eyes")
		else:
			var closed:=mesh.get_parent().get_node_or_null(str(mesh.name)+"__sleep_eyes")
			if closed!=null and closed.visible:continue
		var surfaces := []
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var properties := {}
			for property: String in Audit.storage_properties(material):
				if property=="resource_local_to_scene":continue
				var value: Variant = material.get(property)
				if value is Texture2D:
					if not texture_signatures.has(value): texture_signatures[value] = Audit.signature(value)
					properties[property] = texture_signatures[value]
				else: properties[property] = Audit.signature(value)
			surfaces.append(properties)
		result[key] = {"visible":mesh.visible,"surfaces":surfaces}
	return result

func _values(index: int) -> Dictionary:
	return _appearance(stage.actors[index])

func _expected(variant: int, action: String, fraction: float) -> Dictionary:
	var actor := references[variant]
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	player.play(action); player.pause(); player.seek(player.get_animation(action).length*fraction,true)
	return _appearance(actor)

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
	output = OS.get_environment("POKEAETHER_FOURTEEN_UI_OUTPUT")
	assert(directory.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	rows = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_FOURTEEN_NATIVE")))
	species_name = rows[0].base_species
	for entry: Dictionary in rows:
		assert(FileAccess.get_sha256(entry.runtime_path)==entry.runtime_sha256)
		var actor: Node3D = load(entry.runtime_path).instantiate()
		root.add_child(actor)
		preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
		actor.visible = false
		references.append(actor)
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
			stage.set_combatant(0,species_name,variants[0],true)
			stage.set_combatant(1,species_name,variants[1],true)
			await stage.await_prepared(true,30000)
			assert(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"),stage.reason)
			assert(stage.arena_id == arena)
			battle.player_hud_panel.set_pokemon_data(species_name,100,100,100)
			battle.enemy_hud_panel.set_pokemon_data(species_name,100,100,100)
			await create_timer(0.6).timeout
			for index in 2:
				var hud: Control = battle.player_hud_panel if index==0 else battle.enemy_hud_panel
				assert(stage._visual_rect(index).has_area())
				assert(not hud.get_global_rect().intersects(stage._visual_rect(index)),"Actual HUD overlaps model")
			stage.playback_speed = 0.0
			stage.start_action("p2","idle")
			# Re-requesting an already-playing idle returns early in _action().
			# Freeze its player before the baseline; otherwise one scheduled frame
			# advances animated shader uniforms before the presenter applies speed.
			stage.players[1].speed_scale = 0.0
			stage.players[1].seek(0,true)
			await _frames(2)
			var other := _values(1)
			for action: String in rows[0].animations:
				stage.set_combatant(0,species_name,variants[0],true)
				await _frames(3)
				await stage.await_prepared(true,30000)
				stage.start_action("p1",action)
				assert(stage.current_actions[0]==action,"Requested action did not start")

				for fraction in [0.0,0.5,1.0]:
					stage.players[0].seek(stage.players[0].get_animation(action).length*fraction,true)
					await _frames(2)
					assert(_values(1)==other,"Material animation leaked to opponent")
					var current := _values(0)
					var observed_action: String=stage.current_actions[0]
					var observed_fraction: float=fraction
					if fraction<1.0:
						assert(observed_action==action,"Action finished before its endpoint")
					else:
						# A real battle returns completed attacks to idle, joins a
						# faint hold, or wraps a loop during the awaited frames.
						assert(observed_action in [action,"idle","faint_loop"])
						observed_fraction=stage.players[0].current_animation_position/stage.players[0].get_animation(observed_action).length
					var expected := _expected(1 if variants[0] else 0,observed_action,observed_fraction)
					if current!=expected:
						for key in current:
							if current[key]!=expected.get(key):print("APPEARANCE_DIFFERENCE ",key," actual=",JSON.stringify(current[key])," expected=",JSON.stringify(expected.get(key)))
					assert(current==expected,"Battle appearance differs from approved native scene: "+species_name+"/"+action)
					checks.material_source_samples += 1
					checks.material_isolation_samples += 1
					if variants == [false,true] and fraction == 0.5:
						var name: String = arena+"-"+action+".png"
						assert(root.get_texture().get_image().save_png(output.path_join(name))==OK)
						checks.shots.append(name)
			stage.set_combatant(0,species_name,variants[0],true)
			await _frames(3)
			await stage.await_prepared(true,30000)
			stage.play_action("p1","idle")
			stage.play_action("p2","idle")
			stage.playback_speed = 1.0
			stage.play_action("p1","faint_start")
			stage.players[0].advance(100.0)
			await _frames(4)
			assert(stage.lifecycle[0]=="fainted" and stage.current_actions[1]=="idle")
			stage.set_combatant(0,species_name,variants[0],true)
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
	checks["ui_check_sha256"] = FileAccess.get_sha256("res://tests/battle_3d_final_forms_check.gd")
	checks.complete = true
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"));file.close()
	for actor in references: actor.free()
	texture_signatures.clear()
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("FINAL_FORMS_BATTLE_UI_OK ",JSON.stringify(checks))
	quit()
