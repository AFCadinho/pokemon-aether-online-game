class_name PokedexModelPreview
extends Control
## A single-model desktop viewport for the Pokédex and summary cards.
## It deliberately reads the same hash-bound catalog as the battle presenter.

const ReviewedModels = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const MaterialResponse = preload("res://scripts/battle/battle_ui/material_response.gd")
const LocalReview = preload("res://scripts/ui/local_model_review.gd")
const DEFAULT_FOV := 34.0

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var actor: Node3D
var player: AnimationPlayer
var status: Label
var requested_key := ""
var loading_path := ""
var download_pending := false
var request_generation := 0
var yaw := 0.0
var profile := {}
var preview_floor: MeshInstance3D
var pokedex_zoom_factor := 1.0
signal model_failed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(380, 276)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17283b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	MaterialResponse.apply_neutral_lighting(world)
	var floor := MeshInstance3D.new()
	preview_floor = floor
	var disk := CylinderMesh.new()
	disk.top_radius = 1.7
	disk.bottom_radius = 1.8
	disk.height = 0.08
	floor.mesh = disk
	floor.position.y = -0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("3d6380")
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	world.add_child(floor)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.2, 5.2)
	camera.fov = DEFAULT_FOV
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color("b9d9ee"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(status)

func show_species(species: String, shiny: bool) -> bool:
	requested_key = ReviewedModels.key(species, shiny)
	_clear_actor()
	var settings := get_node_or_null("/root/SettingsManager")
	if not preload("res://scripts/battle/battle_ui/model_platform.gd").supported() or settings == null or settings.battle_presentation_mode not in ["2.5d", "3d"]:
		return false
	var candidate_review := LocalReview.resolve(requested_key) if not ReviewedModels.supports(requested_key) else {}
	if not candidate_review.is_empty():
		profile = candidate_review.profile
		return _request_model(candidate_review.path)
	if _request_cached_model():
		return true
	if not ReviewedModels.supports(requested_key) or settings.has_manual_battle_3d_catalog_selection():
		return false
	if not settings.battle_3d_catalog_path.is_empty() and not OS.has_environment("POKEAETHER_MODEL_CATALOG"):
		return false
	if get_node_or_null("/root/OnDemand3DBundleService") == null:
		return false
	download_pending = true
	status.text = "Loading 3D model…"
	_download_model.call_deferred(requested_key, request_generation)
	return true

func is_loading() -> bool:
	return download_pending or not loading_path.is_empty()

func _download_model(identity: String, generation: int) -> void:
	if generation != request_generation:
		return
	var service := get_node("/root/OnDemand3DBundleService")
	var settings := get_node("/root/SettingsManager")
	var identities: Array[String] = [identity]
	var result: Dictionary = await service.ensure_models(identities, settings.get_battle_3d_catalog_path())
	# Changing or clearing entries must never display a previous request.
	if generation != request_generation:
		return
	download_pending = false
	if str(result.get("error", "")).is_empty() and not str(result.get("path", "")).is_empty():
		OS.set_environment("POKEAETHER_MODEL_CATALOG", str(result.path))
		if _request_cached_model():
			return
	status.text = "3D preview unavailable"
	model_failed.emit()

func _request_cached_model() -> bool:
	var settings := get_node("/root/SettingsManager")
	var catalogs := [str(settings.get_battle_3d_catalog_path())]
	if not settings.has_manual_battle_3d_catalog_selection():
		var downloaded := ProjectSettings.globalize_path("user://on-demand-3d-v1/runtime-catalog.json")
		if downloaded not in catalogs:
			catalogs.append(downloaded)
	for path in catalogs:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Array:
			continue
		for candidate: Variant in raw:
			if not candidate is Dictionary:
				continue
			var candidate_identity := ReviewedModels.canonical_identity(ReviewedModels.entry_key(candidate))
			if candidate_identity != ReviewedModels.canonical_identity(requested_key):
				continue
			var digest := str(candidate.get("runtime_sha256", ""))
			var model_path := str(candidate.get("runtime_path", ""))
			profile = ReviewedModels.resolve(requested_key, digest)
			if profile.is_empty() or not model_path.ends_with(".scn") or not FileAccess.file_exists(model_path):
				continue
			if FileAccess.get_sha256(model_path) == digest:
				return _request_model(model_path)
	return false

func _request_model(model_path: String) -> bool:
	loading_path = model_path
	status.text = "Loading 3D model…"
	if ResourceLoader.load_threaded_request(model_path, "PackedScene") != OK:
		loading_path = ""
		return false
	return true

func _process(_delta: float) -> void:
	if download_pending:
		var service := get_node_or_null("/root/OnDemand3DBundleService")
		if service != null:
			var progress: String = service.progress_text()
			if not progress.is_empty():
				status.text = progress
	if loading_path.is_empty():
		return
	var progress: Array = []
	var load_state := ResourceLoader.load_threaded_get_status(loading_path, progress)
	if load_state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(loading_path) if load_state == ResourceLoader.THREAD_LOAD_LOADED else null
	loading_path = ""
	if scene == null:
		status.text = "3D preview unavailable"
		model_failed.emit()
		return
	actor = scene.instantiate() as Node3D
	if actor == null:
		status.text = "3D preview unavailable"
		model_failed.emit()
		return
	world.add_child(actor)
	if not profile.is_empty():
		actor.scale = Vector3.ONE * float(profile.get("placement", {}).get("scale", 1.0))
	player = _find_player(actor)
	preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
	preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor, requested_key, str(profile.get("grounding", {}).get("sha256", "")))
	if player != null:
		preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player, requested_key, str(profile.get("grounding", {}).get("sha256", "")))
		preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player, requested_key, str(profile.get("grounding", {}).get("sha256", "")))
		var clips := player.get_animation_list()
		if "idle" in clips:
			player.play("idle")
		elif not clips.is_empty():
			player.play(clips[0])
	status.text = "Drag to rotate the 3D model"
	if profile.get("review_candidate", false):
		preview_floor.hide()
		_fit_review_actor()
		status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		status.text = "Review candidate"
		tooltip_text = "Local review candidate — not approved for battles or distribution"

func _fit_review_actor() -> void:
	# Preview framing only; never change source scale or catalog placement.
	if player != null:
		player.advance(0)
	var box := AABB()
	var found := false
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		# Some valid standalone scenes carry a skin without a registered
		# Skeleton3D at preview-fit time. The source mesh still gives a safe
		# camera envelope without requiring a pose bake.
		for surface in mesh.mesh.get_surface_count():
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform * vertex
				box = box.expand(point) if found else AABB(point, Vector3.ZERO)
				found = true
	if not found:
		return
	var aspect := maxf(size.x / maxf(size.y, 1.0), 0.1)
	var extent := maxf(box.size.y, box.size.x / aspect) * 0.5
	# Frame at the normal field of view so toggling zoom never re-fits away
	# the closer inspection the player requested.
	var distance := maxf(extent / tan(deg_to_rad(DEFAULT_FOV * 0.5)) + box.size.z * 0.5, 0.1) * 1.35
	camera.near = maxf(distance * 0.001, 0.001)
	camera.far = maxf(distance * 12, 10)
	camera.position = box.get_center() + Vector3(0, 0, distance)
	camera.look_at(box.get_center())

func set_zoom(factor: float) -> void:
	pokedex_zoom_factor = clampf(factor, 1.0, 2.0)
	if camera != null:
		camera.fov = DEFAULT_FOV / pokedex_zoom_factor

func rotate_by(delta_x: float) -> void:
	yaw += delta_x * 0.012
	if actor != null:
		actor.rotation.y = yaw

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		rotate_by((event as InputEventMouseMotion).relative.x)
		accept_event()

func _clear_actor() -> void:
	request_generation += 1
	download_pending = false
	loading_path = ""
	if actor != null:
		actor.queue_free()
	actor = null
	player = null
	profile = {}
	# A card can clear its selection before the preview enters the scene tree.
	if not is_instance_valid(status):
		return
	status.text = ""
	tooltip_text = "Drag to rotate the 3D model"
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_floor.show()
	camera.near = 0.05
	camera.far = 4000
	camera.fov = DEFAULT_FOV / pokedex_zoom_factor
	camera.position = Vector3(0, 1.2, 5.2)
	camera.look_at(Vector3(0, 0.8, 0))

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
