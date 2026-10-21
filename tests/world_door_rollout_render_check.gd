extends SceneTree
const CATALOG := "res://resources/world/map_doors.json"
var failed := false
func _init() -> void:
	run.call_deferred()
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2);return
	var world: Node = load("res://scripts/world/world.gd").new()
	var vp:=SubViewport.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var out:="user://world-door-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for path:String in catalog:
		var original:Node=load(path).instantiate()
		var visual:Node=original.get_node(catalog[path][0].visual)
		var controller:Node=original.get_node("MapDoors")
		original.remove_child(visual);original.remove_child(controller);original.free()
		var map:=Node2D.new();map.scene_file_path=path;vp.add_child(map);map.add_child(visual);map.add_child(controller)
		for door:Node in controller.doors.values():door.set_process(false)
		# Also freeze pilot doors, if this map already had one.
		for node:Node in visual.get_children():
			if node.has_method("prepare_for_arrival"):node.set_process(false)
		world.call("_normalize_map_depth_layer_z_indices",map)
		for entry:Dictionary in catalog[path]:
			var door:Node2D=controller.doors[entry.id]
			var b:Array=entry.bounds
			vp.size=Vector2i(int(b[2])+16,int(b[3])+16)
			vp.canvas_transform.origin=-Vector2(b[0]-8,b[1]-8)
			door.visible=false
			await process_frame;RenderingServer.force_draw(true,0.0)
			var reference:=vp.get_texture().get_image()
			door.visible=true
			for step in [0,2,4]:
				door.open_amount=step/4.0
				await process_frame;RenderingServer.force_draw(true,0.0)
				var frame:=vp.get_texture().get_image()
				frame.save_png(out+"/%s_%d.png"%[entry.id,step])
				var outside:=0;var remaining:=0
				for y in range(frame.get_height()):
					for x in range(frame.get_width()):
						var inside:=Rect2i(8,8,int(b[2]),int(b[3])).has_point(Vector2i(x,y))
						if inside and entry.kind=="gym":
							var edge:=mini(x-8,int(b[2])-1-(x-8))
							var top:=0 if edge<2 else (2 if edge<10 else (4 if edge<20 else 6))
							inside=y-8>=top and y-8<top+int(b[3])-6
						if not inside and frame.get_pixel(x,y)!=reference.get_pixel(x,y):outside+=1
						if inside and step==4 and not frame.get_pixel(x,y).is_equal_approx(door.opening_color):remaining+=1
				check(outside==0,entry.id+" fixed frame step "+str(step))
				if step==0:check(frame.get_data()==reference.get_data(),entry.id+" exact closed pixels")
				if step==4:check(remaining==0,entry.id+" complete open aperture")
			if entry.has("depth_y"):
				# A raised building layer must not make the open leaf cover a
				# character standing immediately in front of the threshold.
				var actor := Polygon2D.new()
				actor.polygon = PackedVector2Array([Vector2(-4,-48),Vector2(4,-48),Vector2(4,0),Vector2(-4,0)])
				actor.color = Color.MAGENTA
				actor.position = Vector2(b[0]+b[2]/2,b[1]+b[3]+16)
				actor.z_as_relative = false
				actor.z_index = floori(actor.position.y)
				map.add_child(actor)
				await process_frame;RenderingServer.force_draw(true,0.0)
				check(vp.get_texture().get_image().get_pixel(8+int(b[2])/2,int(b[3])).is_equal_approx(Color.MAGENTA),entry.id+" player remains in front of doorway")
				actor.free()
			door.open_amount=0.0
		map.free()
	vp.free();world.free()
	print("World door render check: ","FAIL" if failed else "PASS", " images: ",ProjectSettings.globalize_path(out))
	quit(1 if failed else 0)
func check(ok:bool,message:String)->void:
	if not ok:push_error("FAIL "+message)
	failed=failed or not ok
