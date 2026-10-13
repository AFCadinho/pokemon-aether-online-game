extends "remaining_fourteen_prepare.gd"
## Exact eye geometry/textures, selected by visibility rather than Resource keys.
const SUFFIX := "__sleep_eyes"

func strip_texture_tracks(clip: Animation, eye_path: String, candidate: bool) -> void:
	for track in range(clip.get_track_count()-1,-1,-1):
		if clip.track_get_type(track)!=Animation.TYPE_VALUE:continue
		var path:=str(clip.track_get_path(track))
		if clip.track_get_key_count(track)>0 and clip.track_get_key_value(track,0) is Texture2D:
			assert(path.begins_with(eye_path+":"))
			clip.remove_track(track)
		elif path==eye_path+":visible" or (candidate and path==eye_path+SUFFIX+":visible"):
			clip.remove_track(track)

func normalized(actor: Node, library: AnimationLibrary, eye_path: String, candidate: bool) -> String:
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var origin:=player.get_node(player.root_node)
	if candidate:
		var eye: MeshInstance3D = origin.get_node(eye_path)
		var closed: MeshInstance3D = origin.get_node(eye_path+SUFFIX)
		assert(closed.mesh==eye.mesh and closed.skin==eye.skin)
		assert(closed.skeleton==eye.skeleton and closed.transform==eye.transform)
		assert(closed.cast_shadow==eye.cast_shadow and closed.layers==eye.layers)
		closed.owner=null # Exclude only the declared extra instance from the normalized pack.
	for action in player.get_animation_list():
		var expected:=library.get_animation(action).duplicate(true) as Animation
		var actual:=player.get_animation(action).duplicate(true) as Animation
		strip_texture_tracks(expected,eye_path,false)
		strip_texture_tracks(actual,eye_path,candidate)
		assert(Audit.signature(actual)==Audit.signature(expected),"Unintended animation change: "+action)
	player.remove_animation_library("")
	player.add_animation_library("",library)
	var scene:=PackedScene.new()
	assert(scene.pack(actor)==OK)
	materials.clear();visited.clear();texture_tracks.clear();visit(scene)
	for material: Material in materials:material.resource_local_to_scene=false
	return Audit.signature(scene)

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	assert(args.size()==2)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var folder: String = args[1]
	assert(not DirAccess.dir_exists_absolute(folder))
	DirAccess.make_dir_recursive_absolute(folder)
	var rows:=[]
	for entry: Dictionary in source.entries:
		assert(entry.base_species in ["cramorant-gorging","cramorant-gulping"])
		assert(FileAccess.get_sha256(entry.runtime_path)==entry.runtime_sha256)
		var source_scene:=ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var actor:=source_scene.instantiate()
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		var original_library:=player.get_animation_library("")
		var library:=original_library.duplicate(true) as AnimationLibrary
		player.remove_animation_library("");player.add_animation_library("",library)
		var origin:=player.get_node(player.root_node)
		var eyes: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				if mesh.get_active_material(surface).resource_name=="l_eye":eyes.append(mesh)
		assert(eyes.size()==1)
		var eye:=eyes[0]
		for surface in eye.mesh.get_surface_count():assert(eye.get_active_material(surface).resource_name in ["l_eye","r_eye"])
		var closed:=eye.duplicate(0) as MeshInstance3D
		closed.name=str(eye.name)+SUFFIX
		eye.get_parent().add_child(closed)
		eye.get_parent().move_child(closed,eye.get_index()+1)
		closed.owner=actor
		closed.visible=false
		for surface in eye.mesh.get_surface_count():closed.set_surface_override_material(surface,eye.get_active_material(surface).duplicate(false))
		var eye_path:=str(origin.get_path_to(eye))
		var sleep_clip:=library.get_animation("sleep")
		var selected:=0
		for track in sleep_clip.get_track_count():
			if sleep_clip.track_get_type(track)!=Animation.TYPE_VALUE or sleep_clip.track_get_key_count(track)==0:continue
			var value: Variant = sleep_clip.track_get_key_value(track,0)
			if not value is Texture2D:continue
			var path:=sleep_clip.track_get_path(track)
			assert(str(path.get_concatenated_names())==eye_path)
			closed.set_indexed(NodePath(":"+str(path.get_concatenated_subnames())),value)
			selected+=1
		assert(selected==6)
		for action in library.get_animation_list():
			var clip:=library.get_animation(action)
			strip_texture_tracks(clip,eye_path,false)
			for state in [[eye_path,action!="sleep"],[eye_path+SUFFIX,action=="sleep"]]:
				var track:=clip.add_track(Animation.TYPE_VALUE)
				clip.track_set_path(track,NodePath(state[0]+":visible"))
				clip.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
				clip.track_insert_key(track,0,state[1])
		var scene:=PackedScene.new()
		assert(scene.pack(actor)==OK)
		actor.free()
		materials.clear();visited.clear();texture_tracks.clear();visit(scene)
		assert(texture_tracks.is_empty())
		for material: Material in materials:material.resource_local_to_scene=true
		var path:=folder.path_join(entry.species+".scn")
		assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
		var cold:=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var checks:=check_isolation(cold,entry)
		var candidate:=cold.instantiate()
		var reference:=source_scene.instantiate()
		assert(normalized(candidate,original_library,eye_path,true)==normalized(reference,original_library,eye_path,false),"Changes beyond exact eye visibility selection and ownership")
		candidate.free();reference.free()
		var row:=entry.duplicate(true)
		row["preview_runtime_path"]=entry.runtime_path
		row["preview_runtime_sha256"]=entry.runtime_sha256
		row["runtime_path"]=path
		row["runtime_sha256"]=FileAccess.get_sha256(path)
		row["material_isolation_samples"]=checks
		row["declared_changes_only"]=true
		row["declared_changes"]=["per_instance_material_ownership","constant_eye_texture_selection_as_visibility"]
		row["eye_visibility_path"]=eye_path
		row["action_timing"]={}
		for action: String in row.animations:
			var clip: Dictionary=row.animations[action]
			row.action_timing[action]={"frames":clip.duration*60,"speed":1,"loop":clip.loop}
		rows.append(row)
	var file:=FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("CRAMORANT_EYE_VISIBILITY_PREPARED declared_changes_only=true")
	quit()
