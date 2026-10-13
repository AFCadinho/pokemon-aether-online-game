extends "remaining_fourteen_prepare.gd"
## Select separate, shared-geometry eye states through discrete visibility.
func isolate(scene: PackedScene, entry: Dictionary) -> int:
 var a:=scene.instantiate();var b:=scene.instantiate();root.add_child(a);root.add_child(b)
 await process_frame
 RenderingServer.force_draw(false)
 var pa: AnimationPlayer=a.find_children("*","AnimationPlayer",true,false)[0]
 var pb: AnimationPlayer=b.find_children("*","AnimationPlayer",true,false)[0]
 pb.play("idle");pb.pause();pb.seek(0,true)
 var before:=actor_materials(b);var count:=0
 for action: String in entry.animations:
  pa.play(action);pa.pause()
  for fraction in [0.0,0.25,0.5,0.75,1.0]:
   pa.seek(pa.get_animation(action).length*fraction,true)
   assert(actor_materials(b)==before,"Appearance state leaked to another instance")
   count+=1
 pa.stop();pb.stop();await process_frame
 a.queue_free();b.queue_free();await process_frame
 return count

func select_visibility(player: AnimationPlayer, node: Node3D, sleeping: bool) -> void:
 var origin:=player.get_node(player.root_node)
 for action in player.get_animation_list():
  var clip:=player.get_animation(action)
  var t:=clip.add_track(Animation.TYPE_VALUE)
  clip.track_set_path(t,NodePath(str(origin.get_path_to(node))+":visible"))
  clip.value_track_set_update_mode(t,Animation.UPDATE_DISCRETE)
  clip.track_insert_key(t,0.0,(action=="sleep") if sleeping else (action!="sleep"))

func _run() -> void:
 var args:=OS.get_cmdline_user_args();assert(args.size()==2)
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]));var folder: String=args[1]
 assert(not DirAccess.dir_exists_absolute(folder));DirAccess.make_dir_recursive_absolute(folder)
 var rows:=[]
 for entry: Dictionary in source.entries:
  assert(FileAccess.get_sha256(entry.runtime_path)==entry.runtime_sha256)
  var original:=load(entry.runtime_path) as PackedScene;var actor:=original.instantiate()
  var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
  var library:=player.get_animation_library("").duplicate(true) as AnimationLibrary
  player.remove_animation_library("");player.add_animation_library("",library)
  var eye_count:=0
  for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():
    var original_material:=mesh.get_active_material(i)
    if entry.get("surface_updates",{}).has(original_material.resource_name):
     var spec: Dictionary=entry.surface_updates[original_material.resource_name]
     assert(FileAccess.get_sha256(spec.path)==spec.sha256)
     var material:=original_material.duplicate(true) as StandardMaterial3D
     var im:=Image.load_from_file(spec.path)
     if spec.get("preserve_alpha",false):
      var previous: Image=material.get(spec.property).get_image()
      assert(previous.get_size()==im.get_size());im.convert(Image.FORMAT_RGBA8)
      for y in im.get_height():
       for x in im.get_width():
        var c:=im.get_pixel(x,y);c.a=previous.get_pixel(x,y).a;im.set_pixel(x,y,c)
     im.generate_mipmaps()
     material.set(spec.property,ImageTexture.create_from_image(im));mesh.set_surface_override_material(i,material)
   if entry.base_species=="necrozma-ultra" and ("EyeSkin" in str(mesh.name) or "EyeoffsetSkin" in str(mesh.name)):
    select_visibility(player,mesh,false);eye_count+=1
   var selected:=[]
   for i in mesh.mesh.get_surface_count():
    var mat:=mesh.get_active_material(i)
    if entry.closed_eyes.has(mat.resource_name):selected.append(i)
   if selected.is_empty():continue
   var closed:=mesh.duplicate(0) as MeshInstance3D;closed.name=str(mesh.name)+"__closed"
   mesh.get_parent().add_child(closed);closed.owner=actor;closed.visible=false
   assert(closed.mesh==mesh.mesh and closed.skin==mesh.skin)
   for i in selected:
    var material:=mesh.get_active_material(i).duplicate(true) as StandardMaterial3D
    var spec: Dictionary=entry.closed_eyes[material.resource_name]
    assert(FileAccess.get_sha256(spec.path)==spec.sha256)
    var im:=Image.load_from_file(spec.path);im.generate_mipmaps()
    material.albedo_texture=ImageTexture.create_from_image(im);material.emission_enabled=false;material.normal_enabled=false
    material.metallic=0;material.roughness=.8;material.resource_local_to_scene=true
    closed.set_surface_override_material(i,material);eye_count+=1
   select_visibility(player,mesh,false);select_visibility(player,closed,true)
  # Keep instance-local materials on node overrides. Local materials embedded
  # in a shared ArrayMesh can leave stale renderer RIDs when another actor frees.
  for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   var active:=[]
   for i in mesh.mesh.get_surface_count():active.append(mesh.get_active_material(i).duplicate(true))
   var clean: ArrayMesh
   if mesh.mesh is ArrayMesh:
    clean=mesh.mesh.duplicate(false) as ArrayMesh
    for i in clean.get_surface_count():clean.surface_set_material(i,null)
   else:
    clean=ArrayMesh.new()
    for i in mesh.mesh.get_surface_count():clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.mesh.surface_get_arrays(i))
   mesh.material_override=null;mesh.mesh=clean
   for i in active.size():mesh.set_surface_override_material(i,active[i])
  var packed:=PackedScene.new();assert(packed.pack(actor)==OK);actor.free()
  materials.clear();visited.clear();texture_tracks.clear();visit(packed)
  assert(texture_tracks.is_empty())
  for material: Material in materials:material.resource_local_to_scene=true
  var path:=folder.path_join(entry.species+".scn");assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var cold:=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
  var checks:=await isolate(cold,entry)
  var row:=entry.duplicate(true);row.preview_runtime_path=entry.runtime_path;row.preview_runtime_sha256=entry.runtime_sha256
  row.runtime_path=path;row.runtime_sha256=FileAccess.get_sha256(path)
  row["material_isolation_samples"]=checks;row["authored_closed_eye_surfaces"]=eye_count;row["action_timing"]={}
  for action: String in row.animations:
   var c: Dictionary=row.animations[action];row.action_timing[action]={"frames":c.duration*60,"speed":1,"loop":c.loop}
  rows.append(row)
 var f:=FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));f.close()
 print("FINAL_TWENTY_ONE_PREPARED");quit()
