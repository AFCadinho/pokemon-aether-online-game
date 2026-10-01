extends SceneTree
## Fresh SCN action clocks and order independence after offline channel completion.
func _init() -> void:
 _run.call_deferred()
func _state(actor:Node, player:AnimationPlayer, action:String, fraction:float) -> Array:
 player.play(action);player.pause();player.seek(player.get_animation(action).length*fraction,true)
 var result:Array=[]
 var generated:=RegEx.new()
 generated.compile("@PhysicalBoneSimulator3D@[0-9]+")
 for node:Node3D in actor.find_children("*","Node3D",true,false):
  # Godot creates a fresh simulator instance ID for every loaded skeleton.
  # Keep its hierarchy and transform in the comparison, canonicalizing only
  # that generated name. Source bone/node identities remain exact.
  result.append([generated.sub(str(actor.get_path_to(node)),"@PhysicalBoneSimulator3D",true),node.transform])
  if node is Skeleton3D:
   for bone in node.get_bone_count():result.append(node.get_bone_pose(bone))
 return result
func _same(a:Array,b:Array) -> bool:
 if a.size()!=b.size():return false
 for i in a.size():
  if a[i] is Transform3D:
   if not a[i].is_equal_approx(b[i]):return false
  elif a[i] is Array:
   if a[i][0]!=b[i][0] or not a[i][1].is_equal_approx(b[i][1]):return false
  elif a[i]!=b[i]:return false
 return true
func _run() -> void:
 var source:=OS.get_environment("POKEAETHER_POSE_ORDER_REPORT")
 var output:=OS.get_environment("POKEAETHER_POSE_ORDER_OUTPUT")
 assert(source.is_absolute_path() and output.is_absolute_path() and not FileAccess.file_exists(output))
 var rows:Array=JSON.parse_string(FileAccess.get_file_as_string(source))
 var results:Array=[]
 var failed:=false
 for row:Dictionary in rows:
  assert(FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  var packed:PackedScene=ResourceLoader.load(row.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var a:Node=packed.instantiate();var b:Node=packed.instantiate()
  root.add_child(a);root.add_child(b)
  var ap:AnimationPlayer=a.find_children("*","AnimationPlayer",true,false)[0]
  var bp:AnimationPlayer=b.find_children("*","AnimationPlayer",true,false)[0]
  var actions:Array[String]=[]
  var errors:Array[String]=[]
  for action in ap.get_animation_list():
   if action=="RESET":continue
   actions.append(action)
   var clip:=ap.get_animation(action)
   if clip.get_track_count()==0 or not is_equal_approx(clip.length,float(row.action_timing[action].frames)/60.0):errors.append("Clock/empty clip: "+str(action))
  var expected:Dictionary={}
  for action:String in actions:
   expected[action]=_state(a,ap,action,.5)
  actions.reverse()
  for action:String in actions:
   if not _same(expected[action],_state(b,bp,action,.5)):errors.append("Order-dependent pose: "+str(action))
  _state(a,ap,"faint_start",1)
  _state(b,bp,"sleep",.5)
  if not _same(_state(a,ap,"idle",.5),_state(b,bp,"idle",.5)):errors.append("Faint/sleep state leaked into idle")
  failed=failed or not errors.is_empty()
  results.append({"species":row.species,"runtime_sha256":row.runtime_sha256,"tested_actions":actions.size(),"errors":errors})
  a.free();b.free()
  print("POSE_ORDER ",row.species," ",errors)
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"report_sha256":FileAccess.get_sha256(source),"runtime_approved":false,"entries":results},"  "))
 quit(1 if failed else 0)
