extends "catalog_sleep_review_pack.gd"
## Explicit, hash-pinned eye surface corrections. Does not modify bones or geometry.
func _run() -> void:
 var input:=OS.get_environment("POKEAETHER_EYE_DETAIL_JOB")
 var job:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input))
 var output:String=job.output
 assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
 assert(DirAccess.make_dir_recursive_absolute(output)==OK)
 var rows:Array=[]
 for row:Dictionary in job.entries:
  assert(FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  var actor:Node=ResourceLoader.load(row.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  root.add_child(actor)
  var player:AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
  var found:Dictionary={}
  for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   for surface in mesh.mesh.get_surface_count():
    var original:Material=mesh.get_active_material(surface)
    if not original is StandardMaterial3D:continue
    if not row.eye_detail_materials.has(original.resource_name):continue
    var data:Dictionary=row.eye_detail_materials[original.resource_name]
    var material:StandardMaterial3D=original.duplicate(true)
    material.resource_local_to_scene=true
    material.albedo_color=Color.WHITE
    material.metallic=0
    material.roughness=.7
    var states:Dictionary={}
    for state:String in ["open","closed"]:
     if not data.has(state):continue
     assert(FileAccess.get_sha256(data[state].path)==data[state].sha256)
     var image:=Image.load_from_file(data[state].path)
     assert(image!=null)
     image.generate_mipmaps()
     states[state]=ImageTexture.create_from_image(image)
    if data.get("thin_cover",false):
     material.albedo_texture=null
     material.albedo_color=Color(1,1,1,float(data.reflectance))
     material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    else:
     assert(states.has("open"))
     material.albedo_texture=states.open
     if data.get("opaque",false):material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
     if data.get("alpha",false):material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
     if data.get("disable_false_emission",false):material.emission_enabled=false
    mesh.set_surface_override_material(surface,material)
    var target:=NodePath(str(actor.get_path_to(mesh))+":surface_material_override/"+str(surface)+":albedo_texture")
    for library_name in player.get_animation_library_list():
     var library:=player.get_animation_library(library_name)
     for action in library.get_animation_list():
      var clip:=library.get_animation(action)
      for track in clip.get_track_count():
       if clip.track_get_path(track)!=target:continue
       assert(clip.track_get_type(track)==Animation.TYPE_VALUE)
       for key in clip.track_get_key_count(track):
        clip.track_set_key_value(track,key,states.get("closed",states.get("open")) if action=="sleep" else states.get("open"))
    found[original.resource_name]=true
  assert(found.size()==row.eye_detail_materials.size(),"Missing correction material: "+row.species)
  _inline(actor,{})
  var packed:=PackedScene.new()
  assert(packed.pack(actor)==OK)
  var path:=output.path_join(row.species+".scn")
  assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
  assert(ResourceLoader.get_dependencies(path).is_empty())
  var fresh:Node=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  root.add_child(fresh)
  var fresh_player:AnimationPlayer=fresh.find_children("*","AnimationPlayer",true,false)[0]
  for action:String in ["idle","sleep","idle"]:
   fresh_player.play(action);fresh_player.advance(0)
   for mesh:MeshInstance3D in fresh.find_children("*","MeshInstance3D",true,false):
    for surface in mesh.mesh.get_surface_count():
     var material:Material=mesh.get_active_material(surface)
     if not row.eye_detail_materials.has(material.resource_name):continue
     var data:Dictionary=row.eye_detail_materials[material.resource_name]
     if not data.has("open"):continue
     var state:Dictionary=data.get("closed",data.open) if action=="sleep" else data.open
     var actual:Image=material.albedo_texture.get_image()
     var expected:=Image.load_from_file(state.path)
     actual.clear_mipmaps();actual.convert(Image.FORMAT_RGBA8);expected.convert(Image.FORMAT_RGBA8)
     assert(actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data(),"Wrong eye state after reload: "+row.species+" "+action)
  fresh.free()
  var next:Dictionary=row.duplicate(true)
  next["eye_detail_source_runtime_sha256"]=row.runtime_sha256
  next.runtime_path=path;next.runtime_sha256=FileAccess.get_sha256(path)
  next["runtime_approved"]=false
  rows.append(next)
  actor.free()
  print("EYE_DETAIL_PACK ",row.species)
 FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 quit()
