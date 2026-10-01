extends SceneTree
## Prove native curve and fresh bone-pose preservation after offline clip completion.
func _init() -> void:
 _run.call_deferred()
func signature(animation: Animation, track: int) -> Array:
 var keys=[]
 for j in animation.track_get_key_count(track):
  var value:Variant=animation.track_get_key_value(track,j)
  if value is Texture2D:
   var image:Image=value.get_image()
   var hashing:=HashingContext.new()
   hashing.start(HashingContext.HASH_SHA256);hashing.update(image.get_data())
   value=["Texture2D",image.get_format(),image.get_size(),image.has_mipmaps(),hashing.finish().hex_encode()]
  keys.append([animation.track_get_key_time(track,j),value,animation.track_get_key_transition(track,j)])
 return [animation.track_get_type(track),animation.track_get_path(track),animation.track_is_enabled(track),animation.track_get_interpolation_type(track),animation.track_get_interpolation_loop_wrap(track),keys]
func pose(node: Node, player: AnimationPlayer, action: String, fraction: float) -> Array:
 player.stop()
 for skeleton: Skeleton3D in node.find_children('*','Skeleton3D',true,false):skeleton.reset_bone_poses()
 if player.has_animation('RESET'):
  player.play('RESET');player.advance(0)
 player.play(action);player.pause();player.seek(player.get_animation(action).length*fraction,true)
 var states=[]
 for skeleton: Skeleton3D in node.find_children('*','Skeleton3D',true,false):
  for i in skeleton.get_bone_count():states.append(skeleton.get_bone_pose(i))
 return states
func _run() -> void:
 var old: Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment('OLD_STAGE')))
 var new: Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment('NEW_STAGE')))
 assert(old.size()==new.size() and not old.is_empty())
 var output:=OS.get_environment('PROOF_OUTPUT')
 assert(output.is_absolute_path() and not FileAccess.file_exists(output))
 var by={}
 for row in new:
  assert(not by.has(row.species) and FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  by[row.species]=row
 var results=[]
 for row in old:
  var name: String=row.species.replace('@shiny','-shiny')
  assert(FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  var a: Node=load(row.runtime_path).instantiate()
  var b: Node=load(by[name].runtime_path).instantiate()
  var ap: AnimationPlayer=a.find_children('*','AnimationPlayer',true,false)[0]
  var bp: AnimationPlayer=b.find_children('*','AnimationPlayer',true,false)[0]
  root.add_child(a);root.add_child(b)
  var verified:=0
  var poses:=0
  for action in ap.get_animation_list():
   if action=='RESET':continue
   var aa:=ap.get_animation(action)
   var bb:=bp.get_animation(action)
   assert(aa.length==bb.length and aa.loop_mode==bb.loop_mode)
   for fraction in [0.0,0.5,1.0]:
    var av:=pose(a,ap,action,fraction)
    var bv:=pose(b,bp,action,fraction)
    assert(av.size()==bv.size())
    for index in av.size():assert(av[index].is_equal_approx(bv[index]),'Fresh native pose changed: '+name+' '+str(action)+' bone '+str(index))
    poses+=1
   for i in aa.get_track_count():
    var expected:=signature(aa,i)
    var found:=false
    for j in bb.get_track_count():
     if bb.track_get_type(j)==aa.track_get_type(i) and bb.track_get_path(j)==aa.track_get_path(i):
      assert(signature(bb,j)==expected,'Native curve changed: '+name+' '+str(action))
      found=true
      break
    assert(found,'Native curve missing: '+name)
    verified+=1
  results.append({'species':name,'old_runtime_sha256':row.runtime_sha256,'new_runtime_sha256':by[name].runtime_sha256,'native_tracks_verified':verified,'fresh_pose_comparisons':poses,'inserted_default_channels':b.get_meta('pokeaether_complete_pose_channels',-1)})
  a.free();b.free()
 assert(results.size()==old.size())
 FileAccess.open(OS.get_environment('PROOF_OUTPUT'),FileAccess.WRITE).store_string(JSON.stringify(results,'  '))
 print('PASS: ',results.size(),' scenes retain every native track, key, clock, interpolation and fresh bone pose')
 quit()
