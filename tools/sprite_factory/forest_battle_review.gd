extends SceneTree
## Isolated full-screen environment review, not authoritative battle gameplay.
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
class ForestResponse extends Response:
	var forest_factory: Callable
	func _build() -> void:
		# TerraBrush's generated internal Terrain class cannot be duplicated.
		# Build the same authored terrain in the second isolated viewport instead.
		var original: Node3D = stage.world
		var proxy := Node3D.new()
		for child in original.get_children():
			if child is WorldEnvironment or child is Light3D:
				proxy.add_child(child.duplicate())
		stage.world = proxy
		super._build()
		stage.world = original
		source_world_id = original.get_instance_id()
		proxy.free()
		world.add_child(forest_factory.call())
class Stage extends Control:
	var world: Node3D
	var viewport: SubViewport
	var camera: Camera3D
	var actors: Array = [null, null]
	var identities := ["dragonite", "roaring-moon"]
	var packed := {}
	var active := true

class InputRelay extends Node:
	var callback: Callable
	func _unhandled_input(event: InputEvent) -> void:
		callback.call(event)

var stage: Stage
var response: Node
var players: Array = []
var entries: Array = []
var angle := 0.55
var elevation := 0.28
var distance := 12.0
var target := Vector3(0, 1.3, 0)
var dragging := false
var status: Label
var ui: CanvasLayer
var selection: OptionButton
var forest: Node3D

func _init() -> void:
	_run.call_deferred()

func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _player(child)
		if found != null:
			return found
	return null

func _camera() -> void:
	stage.camera.position = target + Vector3(sin(angle)*cos(elevation), sin(elevation), cos(angle)*cos(elevation))*distance
	stage.camera.look_at(target)

func _input_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 8, 18)
			_camera()
	if event is InputEventMouseMotion and dragging:
		angle -= event.relative.x*0.006
		elevation = clampf(elevation+event.relative.y*0.004, 0.12, 0.9)
		_camera()
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		ui.visible = not ui.visible

func _play() -> void:
	var action := selection.get_item_text(selection.selected)
	for index in 2:
		players[index].speed_scale = entries[index].action_timing[action].speed
		players[index].play(action)
	status.text = action + " — right-drag: orbit · wheel: zoom · Tab: hide controls"

func _resize() -> void:
	if is_instance_valid(stage):
		stage.viewport.size = Vector2i(root.size)

func _credit_text() -> String:
	return "Forest: Jonnie Gieringer (MIT) · rocks: Michael Hooper (CC BY 4.0)\nNeutral lighting + approved Pokémon materials · isolated review, no gameplay"

func _ground_position(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos+Vector3.UP*100, pos-Vector3.UP*100)
	var hit := stage.world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		pos.y = hit.position.y
	return pos

func _place_actor(_actor: Node3D, _animation_player: AnimationPlayer) -> void:
	pass

func _make_forest() -> Node3D:
	var scene: Node3D = load("res://scenes/levels/forest.tscn").instantiate()
	scene.position = Vector3(-12, 0, -8)
	var terrain = scene.get_node("TerraBrush")
	terrain.terrainZones = terrain.terrainZones.duplicate(true)
	var zone = terrain.terrainZones.zones[0]
	# Carve a review clearing in the authored placement masks, in memory only.
	# Zone 0 is centered at world origin; preserve source terrain heights/colors.
	for masks in [zone.objectsImage, zone.foliagesImage]:
		for mask: Image in masks:
			var center := Vector2(mask.get_width()/2.0+12, mask.get_height()/2.0+8)
			var radius := 32.0 if masks == zone.objectsImage else 10.0
			for y in range(maxi(0, int(center.y-radius)), mini(mask.get_height(), int(center.y+radius+1))):
				for x in range(maxi(0, int(center.x-radius)), mini(mask.get_width(), int(center.x+radius+1))):
					if Vector2(x,y).distance_to(center) < radius:
						mask.set_pixel(x,y,Color(0,0,0,0))
	return scene

func _run() -> void:
	stage = Stage.new()
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.viewport = SubViewport.new()
	stage.viewport.own_world_3d = true
	stage.viewport.msaa_3d = Viewport.MSAA_4X
	stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(stage.viewport)
	var surface := TextureRect.new()
	stage.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.texture = stage.viewport.get_texture()
	root.size_changed.connect(_resize)
	_resize()
	stage.world = Node3D.new()
	stage.viewport.add_child(stage.world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b4cad6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	stage.world.add_child(environment)
	Response.apply_neutral_lighting(stage.world)
	stage.camera = Camera3D.new()
	stage.camera.fov = 48
	stage.world.add_child(stage.camera)
	stage.camera.current = true
	_camera()
	forest = _make_forest()
	stage.world.add_child(forest)
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if FileAccess.file_exists(report+".runtime.json"):
		report += ".runtime.json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(report))
	assert(data is Array)
	for species in stage.identities:
		for entry in data:
			if entry.species == species:
				entries.append(entry)
				stage.packed[species] = load(entry.runtime_path)
	assert(entries.size() == 2)
	for frame in 60:
		await process_frame
	for index in 2:
		var actor: Node3D = stage.packed[stage.identities[index]].instantiate()
		stage.actors[index] = actor
		stage.world.add_child(actor)
		actor.position = Vector3(-2.8, 0, 1.5) if index == 0 else Vector3(2.8, 0, -1.5)
		actor.position = _ground_position(actor.position)
		actor.scale = Vector3.ONE*(1.0 if index == 0 else 0.65)
		var facing := -actor.position
		actor.rotation.y = atan2(facing.x, facing.z)
		players.append(_player(actor))
		await _place_actor(actor, players[-1])
	response = ForestResponse.new()
	response.forest_factory = _make_forest
	response.stage = stage
	stage.add_child(response)
	ui = CanvasLayer.new()
	root.add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	status = Label.new()
	box.add_child(status)
	var row := HBoxContainer.new()
	box.add_child(row)
	selection = OptionButton.new()
	for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]:
		selection.add_item(action)
	row.add_child(selection)
	var play := Button.new()
	play.text = "Play both"
	row.add_child(play)
	play.pressed.connect(_play)
	var reset := Button.new()
	reset.text = "Battle view"
	row.add_child(reset)
	reset.pressed.connect(func(): angle=0.55; elevation=0.28; distance=12; _camera())
	var credit := Label.new()
	credit.text = _credit_text()
	box.add_child(credit)
	var relay := InputRelay.new()
	relay.callback = _input_event
	root.add_child(relay)
	_play()
	if OS.get_environment("POKEAETHER_FOREST_SMOKE") == "1":
		await _smoke()

func _smoke() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	for frame in 90:
		await process_frame
	assert(response.viewport != null and response.sync_count > 0)
	var frames := []
	ui.hide()
	for index in 4:
		angle = 0.55 + index*PI/2.0
		_camera()
		for frame in 60:
			var start := Time.get_ticks_usec()
			await process_frame
			frames.append(float(Time.get_ticks_usec()-start)/1000.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("forest-%s.png"%index))
	for action_index in selection.item_count:
		selection.select(action_index)
		_play()
		for frame in 3:
			await process_frame
		assert(players[0].is_playing() and players[1].is_playing())
	frames.sort()
	print("FOREST_REVIEW_OK p95_ms=", frames[int(frames.size()*0.95)], " max_ms=", frames[-1], " video_bytes=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var report := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"p95_ms": frames[int(frames.size()*0.95)], "max_ms": frames[-1], "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "size": [stage.viewport.size.x, stage.viewport.size.y], "actions": selection.item_count}, "\t"))
	report.close()
	var main_view: WeakRef = weakref(stage.viewport)
	var light_view: WeakRef = weakref(response.viewport)
	stage.queue_free()
	for frame in 4:
		await process_frame
	assert(main_view.get_ref() == null and light_view.get_ref() == null)
	quit()
