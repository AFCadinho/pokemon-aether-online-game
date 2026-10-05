extends SceneTree
const Standing = preload("res://scripts/battle/animations/mega_garchomp_standing.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
const Placement = preload("res://scripts/battle/battle_ui/model_placement.gd")
func _initialize() -> void:
	var library: AnimationLibrary = load(Standing.LIBRARY_PATH)
	assert(FileAccess.get_sha256(Standing.LIBRARY_PATH) == Standing.DATA.data.library_sha256)
	assert(library.get_animation_list().size() == 7)
	for clip_name in library.get_animation_list():
		var clip := library.get_animation(clip_name)
		assert(clip.length > 0)
		for t in clip.get_track_count():
			assert(clip.track_get_type(t) in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D], "No methods, materials or mesh mutations")
			assert(str(clip.track_get_path(t)).begins_with("pm0445_51_00/Skeleton3D:"))
			assert(clip.track_get_key_count(t)>0)
			assert(clip.track_get_key_time(t,0)==0)
			assert(clip.track_get_key_time(t,clip.track_get_key_count(t)-1)<=clip.length+0.00001)
	var shared := AnimationLibrary.new()
	shared.add_animation("old_idle", Animation.new())
	var first := AnimationPlayer.new()
	var second := AnimationPlayer.new()
	first.add_animation_library("",shared)
	second.add_animation_library("",shared)
	assert(not Standing.apply(first,"weezing",Standing.DATA.data.models["garchomp-mega"]))
	assert(not Standing.apply(first,"garchomp-mega","changed-model"))
	assert(first.get_animation_library("")==shared)
	for identity: String in Standing.DATA.data.models:
		var digest: String = Standing.DATA.data.models[identity]
		var profile := Reviewed.resolve(identity,digest)
		var placement := Placement.resolve(profile,profile.grounding,digest)
		assert(placement.hover_height == 0)
		assert(not Motion.resolve(profile.motion,placement,digest,profile.action_timing).is_empty())
		assert(profile.action_timing.size()==library.get_animation_list().size())
		for action: String in profile.action_timing:
			assert(is_equal_approx(profile.action_timing[action].frames/60.0,library.get_animation(action).length))
		assert(Standing.apply(first,identity,digest))
		assert(second.get_animation_library("")==shared and second.has_animation("old_idle"))
		first.get_animation("idle").length=99
		assert(library.get_animation("idle").length<3,"No cross-actor mutation")
	assert(Standing.profile_for("garchomp-mega","future-model",{"sentinel":true})=={"sentinel":true})
	assert(Reviewed.resolve("garchomp-mega","changed-model").is_empty())
	for identity in ["garchomp-mega-z", "garchomp-mega-z@shiny"]:
		var model: Dictionary = Reviewed.DATA.data.models[identity]
		assert(not Standing.apply(first,identity,model.sha256))
		var original: Dictionary = Reviewed.DATA.data.profiles[model.profile]
		var resolved := Reviewed.resolve(identity,model.sha256)
		assert(original.action_timing == resolved.action_timing)
		assert(original.bounds == resolved.bounds)
	first.free()
	second.free()
	print("MEGA_GARCHOMP_STANDING_OK variants=2 exact_hashes=true isolated_animation_libraries=true")
	quit()
