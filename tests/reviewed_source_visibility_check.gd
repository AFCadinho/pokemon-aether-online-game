extends "res://tools/sprite_factory/native_resource_compression_check.gd"
const Visibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
func _run() -> void:
	sink.tree=self
	OS.add_logger(sink)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("VISIBILITY_SOURCE_FIXTURE")))
	var checked:=0
	for entry: Dictionary in fixture.entries:
		if not Visibility.matches(entry.identity,entry.source_sha256):continue
		for candidate in [false,true]:
			var path: String=entry.candidate_path if candidate else entry.source_path
			var digest: String=entry.candidate_sha256 if candidate else entry.source_sha256
			assert(FileAccess.get_sha256(path)==digest)
			var packed: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			var fingerprint:=Components.fingerprint(packed)
			var a: Node3D=packed.instantiate()
			var b: Node3D=packed.instantiate()
			root.add_child(a)
			root.add_child(b)
			var pa: AnimationPlayer=a.find_child("AnimationPlayer",true,false)
			var pb: AnimationPlayer=b.find_child("AnimationPlayer",true,false)
			var original:=pa.get_animation_library("")
			assert(not Visibility.apply(a,entry.identity,"0".repeat(64)))
			assert(not Visibility.apply(a,"future-form",digest))
			assert(pa.get_animation_library("")==original)
			assert(Visibility.apply(a,entry.identity,digest))
			assert(Visibility.apply(a,entry.identity,digest)) # Idempotent; no second tracks.
			assert(pa.get_animation_library("")!=original and pb.get_animation_library("")==original)
			for action in pb.get_animation_list():
				var source:=pb.get_animation(action)
				var corrected:=pa.get_animation(action)
				assert(source.length==corrected.length and source.loop_mode==corrected.loop_mode)
				assert(source.get_track_count()+6==corrected.get_track_count())
				for track in source.get_track_count():
					assert(source.track_get_path(track)==corrected.track_get_path(track))
					assert(source.track_get_type(track)==corrected.track_get_type(track))
					assert(source.track_get_key_count(track)==corrected.track_get_key_count(track))
					for key in source.track_get_key_count(track):
						assert(source.track_get_key_time(track,key)==corrected.track_get_key_time(track,key))
						assert(source.track_get_key_value(track,key)==corrected.track_get_key_value(track,key))
				for fraction in [0.0,.5,.999]:
					pose(a,action,fraction)
					pose(b,action,fraction)
					var ma:=a.find_children("*","MeshInstance3D",true,false)
					var mb:=b.find_children("*","MeshInstance3D",true,false)
					for i in ma.size():
						assert(ma[i].mesh==mb[i].mesh and ma[i].skin==mb[i].skin)
						assert(ma[i].visible==(ma[i].name!="pm1089_00_00_wing_b_mesh"))
						assert(mb[i].visible)
					var sa: Skeleton3D=a.find_child("Skeleton3D",true,false)
					var sb: Skeleton3D=b.find_child("Skeleton3D",true,false)
					for bone in sa.get_bone_count():assert(sa.get_bone_pose(bone)==sb.get_bone_pose(bone))
			assert(Components.fingerprint(packed)==fingerprint)
			var bad: Node3D=packed.instantiate()
			root.add_child(bad)
			var bad_player: AnimationPlayer=bad.find_child("AnimationPlayer",true,false)
			var bad_library:=bad_player.get_animation_library("")
			bad.find_child("pm1089_00_00_wing_b_mesh",true,false).name="UnexpectedMesh"
			assert(not Visibility.apply(bad,entry.identity,digest))
			assert(bad_player.get_animation_library("")==bad_library and not bad.has_meta(Visibility.META))
			await process_frame
			await RenderingServer.frame_post_draw
			for actor in [a,b,bad]:actor.queue_free()
			for frame in 3:await process_frame
			checked+=1
	assert(checked==4)
	print("REVIEWED_SOURCE_VISIBILITY_OK variants=",checked)
	quit()
