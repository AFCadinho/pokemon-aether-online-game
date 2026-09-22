extends "res://scripts/ui/pokedex_model_preview.gd"
## Card-owned playback, using the card's existing animation menu.
var configured_player: AnimationPlayer
var animation_button: MenuButton
var base_transforms: Dictionary = {}
var selected_clip := "idle"
var camera_target := Vector3.ZERO
var camera_distance := 1.0
var zoom_factor := 1.0

func _ready() -> void:
	super._ready()
	tooltip_text = "Drag to rotate the 3D model"
	# A fixed platform obscures valid native poses below its plane.
	# Summary cards inspect the model, not an artificial arena floor.
	preview_floor.hide()

func bind_animation_button(button: MenuButton) -> void:
	animation_button = button
	if button != null:
		button.set_meta("model_preview", weakref(self))
	_update_menu()

func _update_menu() -> void:
	if not is_instance_valid(animation_button):
		return
	animation_button.show()
	animation_button.disabled = configured_player == null
	animation_button.tooltip_text = "Animations are loading…" if configured_player == null else "Preview animation"
	var popup := animation_button.get_popup()
	popup.clear()
	if configured_player == null:
		return
	for clip in player.get_animation_list():
		if clip == "RESET":
			continue
		popup.add_item(String(clip).replace("_", " ").capitalize())
		popup.set_item_metadata(popup.item_count - 1, clip)

func _process(delta: float) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree():
		if player != null:
			player.active = false
		return
	if player != null:
		player.active = true
	super._process(delta)
	if player == null or player == configured_player:
		return
	configured_player = player
	base_transforms.clear()
	for node in actor.find_children("*", "Node3D", true, false):
		base_transforms[node] = node.transform
	selected_clip = "idle" if player.has_animation("idle") else String(player.get_animation_list()[0])
	play_clip(selected_clip)
	_fit_model()
	status.text = "Review candidate" if profile.get("review_candidate", false) else ""
	_update_menu()

func play_clip(clip: String) -> void:
	if player == null or not player.has_animation(clip):
		return
	selected_clip = clip
	player.stop()
	# Clips key different subsets of the rig. Clear previous action transforms.
	for node: Node3D in base_transforms:
		node.transform = base_transforms[node]
		if node is Skeleton3D:
			(node as Skeleton3D).reset_bone_poses()
	if player.has_animation("RESET"):
		player.play("RESET")
		player.advance(0)
	if player.has_animation("idle"):
		player.play("idle")
		player.advance(0)
	if clip == "faint_loop" and player.has_animation("faint_start"):
		player.play("faint_start")
		player.seek(player.get_animation("faint_start").length, true)
	player.play(clip)
	player.seek(0, true)
	player.advance(0)

func toggle_pause() -> void:
	if player == null:
		return
	if player.is_playing():
		player.pause()
	else:
		player.play()

func _fit_model() -> void:
	for skeleton in actor.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	var bounds := AABB()
	var found := false
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			var vertices: PackedVector3Array = posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := mesh.global_transform * vertex
				bounds = bounds.expand(point) if found else AABB(point, Vector3.ZERO)
				found = true
	if not found:
		return
	camera_target = bounds.get_center()
	var aspect := maxf(size.x / maxf(size.y, 1.0), 0.1)
	var half_height := maxf(bounds.size.y, bounds.size.x / aspect) * 0.5
	# Leave room below idle for native recoil/down poses without moving the
	# camera on each action (which would conceal positional discontinuities).
	camera_distance = maxf(half_height / tan(deg_to_rad(camera.fov * 0.5)) + bounds.size.z * 0.5, 0.1) * 1.35
	camera.near = maxf(camera_distance * 0.001, 0.001)
	camera.far = maxf(camera_distance * 12, 10)
	set_zoom(zoom_factor)

func set_zoom(factor: float) -> void:
	zoom_factor = factor
	camera.position = camera_target + Vector3(0, 0, camera_distance / factor)
	camera.look_at(camera_target)

func _clear_actor() -> void:
	configured_player = null
	base_transforms.clear()
	super._clear_actor()
	preview_floor.hide()
	_update_menu()
