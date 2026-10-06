extends "res://tools/sprite_factory/native_resource_compression_check.gd"
func shot(stage: Stage, actors: Array, active: int, action: String, fraction: float) -> Dictionary:
	for i in actors.size():
		actors[i].visible = i == active
		pose(actors[i],action,fraction)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := stage.viewport.get_texture().get_image()
	return {"image":image,"bytes":image.get_data(),"signature":signature(actors[active]),"bounds":bounds(actors[active])}
func _run() -> void:
	sink.tree=self
	OS.add_logger(sink)
	directory=OS.get_environment("NATIVE_COMPRESSION_OUTPUT")
	var input: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("report.json")))
	report["paired_actor_reference"] = true
	report["candidate_first"] = OS.get_environment("NATIVE_CANDIDATE_FIRST") == "1"
	report["godot"] = Engine.get_version_info().string
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["source_fixture_sha256"] = FileAccess.get_sha256(directory.path_join("report.json"))
	report["original_only_control"] = OS.get_environment("NATIVE_ORIGINAL_ONLY") == "1"
	for entry: Dictionary in input.entries:
		assert(FileAccess.get_sha256(entry.source_path)==entry.source_sha256)
		assert(FileAccess.get_sha256(entry.candidate_path)==entry.candidate_sha256)
		for response in [false,true]:
			var a: PackedScene
			var b: PackedScene
			var candidate_path: String=entry.source_path if report.original_only_control else entry.candidate_path
			if OS.get_environment("NATIVE_CANDIDATE_FIRST") == "1":
				b=ResourceLoader.load(candidate_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
				a=ResourceLoader.load(entry.source_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			else:
				a=ResourceLoader.load(entry.source_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
				b=ResourceLoader.load(candidate_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			assert(a != b and Components.fingerprint(a)==Components.fingerprint(b))
			var a_ref: WeakRef=weakref(a)
			var b_ref: WeakRef=weakref(b)
			var actors: Array=[a.instantiate(),b.instantiate()]
			prepare_actor(actors[0],entry,false)
			prepare_actor(actors[1],entry,not report.original_only_control)
			var stage:=make_stage()
			stage.identities=["source","candidate"]
			stage.packed={"source":a,"candidate":b}
			stage.actors=actors
			for actor: Node3D in actors:
				stage.world.add_child(actor)
				pose(actor,"idle",0)
				actor.visible=false
			actors[0].visible=true
			var box:=bounds(actors[0])
			stage.camera.position=box.get_center()+Vector3(0,.1,1).normalized()*maxf(box.size.length(),.1)*2
			stage.camera.look_at(box.get_center())
			stage.camera.far=1000
			if response:
				var supported: bool=Response.supported_actor(actors[0]) and actors[0].get_meta(Response.META,0)==1
				assert(supported==(Response.supported_actor(actors[1]) and actors[1].get_meta(Response.META,0)==1))
				if not supported:
					await process_frame
					await RenderingServer.frame_post_draw
					stage.queue_free()
					for frame in 3:await process_frame
					actors.clear()
					a=null
					b=null
					assert(a_ref.get_ref()==null and b_ref.get_ref()==null)
					if not report.has("response_skipped"):report["response_skipped"]=[]
					report.response_skipped.append(entry.identity)
					continue
				var effect:=Response.new()
				effect.stage=stage
				stage.add_child(effect)
			var player:=actors[0].find_child("AnimationPlayer",true,false) as AnimationPlayer
			for action in player.get_animation_list():
				if action=="RESET":continue
				for fraction in [0.0,.5,.999]:
					var aa:=await shot(stage,actors,0,action,fraction)
					var bb:=await shot(stage,actors,1,action,fraction)
					var again:=await shot(stage,actors,0,action,fraction)
					var same: bool=aa.bytes==bb.bytes and aa.bytes==again.bytes
					assert(aa.signature==bb.signature and aa.bounds==bb.bounds)
					report.comparisons.append({"identity":entry.identity,"response":response,"pose":str(action)+":"+str(fraction),"pixel_exact":same,"repeat_exact":aa.bytes==again.bytes,"sha256_original":Components.sha(aa.bytes),"sha256_candidate":Components.sha(bb.bytes)})
					if not same:
						report["failure_evidence"] = difference(aa,bb)
						for label in {"original":aa,"candidate":bb,"repeat":again}:
							var capture: Dictionary={"original":aa,"candidate":bb,"repeat":again}[label]
							assert(capture.image.save_png(directory.path_join("mismatch-"+label+".png"))==OK)
						await failure_diagnostics(stage,actors,action,fraction)
						report["failure"]="Paired reference mismatch"
						save_report()
						push_error("Paired reference mismatch "+entry.identity+" "+str(action)+" "+str(fraction))
						quit(2)
						return
			stage.queue_free()
			for frame in 3:await process_frame
			actors.clear()
			a=null
			b=null
			assert(a_ref.get_ref()==null and b_ref.get_ref()==null, "Pair retained after cleanup")
			print("PAIRED_REFERENCE_OK ",entry.identity," response=",response)
	report.complete=sink.errors.is_empty()
	save_report()
	quit()

func difference(a: Dictionary,b: Dictionary) -> Dictionary:
	assert(a.image.get_format()==Image.FORMAT_RGBA8 and b.image.get_format()==Image.FORMAT_RGBA8)
	assert(a.image.get_size()==b.image.get_size())
	var changed:=0
	var alpha_changed:=0
	var maximum: Array[int]=[0,0,0,0]
	var samples:=[]
	for offset in range(0,a.bytes.size(),4):
		var different:=false
		for channel in 4:
			var delta: int=absi(int(a.bytes[offset+channel])-int(b.bytes[offset+channel]))
			maximum[channel]=maxi(maximum[channel],delta)
			different=different or delta!=0
		if not different:continue
		changed+=1
		if a.bytes[offset+3]!=b.bytes[offset+3]:alpha_changed+=1
		if samples.size()<16:
			var pixel: int=offset/4
			samples.append({"x":pixel%a.image.get_width(),"y":pixel/a.image.get_width(),"a":Array(a.bytes.slice(offset,offset+4)),"b":Array(b.bytes.slice(offset,offset+4))})
	return {"changed_pixels":changed,"alpha_changed_pixels":alpha_changed,"maximum_channel_delta":maximum,"samples":samples}

func failure_diagnostics(_stage: Stage,_actors: Array,_action: String,_fraction: float) -> void:
	# Default strict comparator never changes rendering to make a failure pass.
	pass

func prepare_actor(_actor: Node3D,_entry: Dictionary,_candidate: bool) -> void:
	pass
