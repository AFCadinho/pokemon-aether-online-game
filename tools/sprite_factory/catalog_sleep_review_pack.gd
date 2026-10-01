extends "catalog_fire_preview_pack.gd"
## Offline source-eye state proposals. Preserves every existing animation track.
func _init() -> void:
 _run.call_deferred()
func _inline(value: Variant, seen: Dictionary) -> void:
 if value is Resource or value is Node:
  var identity:int=value.get_instance_id()
  if seen.has(identity):return
  seen[identity]=true
  if value is Resource:value.resource_path=""
  for property in value.get_property_list():
   if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("instance_shader_parameters"):
    _inline(value.get(property.name),seen)
  if value is Node:
   for child in value.get_children():_inline(child,seen)
 elif value is Array:
  for item in value:_inline(item,seen)
 elif value is Dictionary:
  for item in value.values():_inline(item,seen)
func _run() -> void:
 var input:=OS.get_environment("POKEAETHER_SLEEP_PACK_JOB")
 if not input.is_absolute_path() or not FileAccess.file_exists(input):
  printerr("Missing absolute sleep pack job");quit(2);return
 var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(input))
 if not parsed is Dictionary or not parsed.has("output") or not parsed.has("entries"):
  printerr("Invalid sleep pack job");quit(2);return
 var job:Dictionary=parsed
 var output:String=job.output
 assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
 assert(DirAccess.make_dir_recursive_absolute(output)==OK)
 var rows:Array=[]
 for row:Dictionary in job.entries:
  assert(FileAccess.get_sha256(row.runtime_path)==row.runtime_sha256)
  var node:Node=ResourceLoader.load(row.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
  root.add_child(node)
  var player:AnimationPlayer=node.find_children("*","AnimationPlayer",true,false)[0]
  var bindings:Array=[]
  for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
   for surface in mesh.mesh.get_surface_count():
    var original:Material=mesh.get_active_material(surface)
    if not original is StandardMaterial3D:continue
    var data:Dictionary=row.get("eye_states",{}).get(original.resource_name,{})
    var override:Dictionary=row.get("colour_overrides",{}).get(original.resource_name,{})
    if data.is_empty() and override.is_empty():continue
    var material:StandardMaterial3D=original.duplicate(true)
    material.resource_local_to_scene=true
    mesh.set_surface_override_material(surface,material)
    if not override.is_empty():
     material.albedo_color=Color(override.colour[0],override.colour[1],override.colour[2],1)
     material.metallic=0
     material.roughness=.8
    if not data.is_empty():
     assert(FileAccess.get_sha256(data.path)==data.sha256)
     var image:=Image.load_from_file(data.path)
     assert(image!=null)
     image.generate_mipmaps()
     var closed:=ImageTexture.create_from_image(image)
     var target:=NodePath(str(node.get_path_to(mesh))+":surface_material_override/"+str(surface)+":albedo_texture")
     for library_name in player.get_animation_library_list():
      var library:=player.get_animation_library(library_name)
      for action in library.get_animation_list():
       var clip:=library.get_animation(action)
       var track:=clip.add_track(Animation.TYPE_VALUE)
       clip.track_set_path(track,target)
       clip.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
       clip.track_insert_key(track,0.0,closed if action=="sleep" else original.albedo_texture)
       if data.get("disable_emission_on_sleep", false):
        var emission_track:=clip.add_track(Animation.TYPE_VALUE)
        clip.track_set_path(emission_track,NodePath(str(node.get_path_to(mesh))+":surface_material_override/"+str(surface)+":emission_enabled"))
        clip.value_track_set_update_mode(emission_track,Animation.UPDATE_DISCRETE)
        clip.track_insert_key(emission_track,0.0,false if action=="sleep" else original.emission_enabled)
     bindings.append({"node":str(node.get_path_to(mesh)),"surface":surface,"material":original.resource_name,"closed_sha256":data.sha256,"disable_emission_on_sleep":data.get("disable_emission_on_sleep",false),"original_emission_enabled":original.emission_enabled})
  var completion:=preload("complete_pose_channels.gd").new()
  assert(completion.apply(node),completion.failure)
  _inline(node,{})
  var packed:=PackedScene.new()
  assert(packed.pack(node)==OK)
  var path:=output.path_join(row.species+".scn")
  assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
  assert(ResourceLoader.get_dependencies(path).is_empty())
  var fresh:PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
  var actor:=fresh.instantiate()
  root.add_child(actor)
  var ap:AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
  for action in ["idle","sleep","idle"]:
   ap.play(action);ap.advance(0)
   for binding:Dictionary in bindings:
    var mesh:MeshInstance3D=actor.get_node(binding.node)
    var material:StandardMaterial3D=mesh.get_active_material(binding.surface)
    assert(material.albedo_texture!=null)
    if binding.disable_emission_on_sleep:
     assert(material.emission_enabled==(false if action=="sleep" else binding.original_emission_enabled),"Eye emission state did not survive reload: "+row.species)
    if action=="sleep":
     var actual:=material.albedo_texture.get_image()
     var expected:=Image.load_from_file(row.eye_states[binding.material].path)
     actual.clear_mipmaps()
     actual.convert(Image.FORMAT_RGBA8);expected.convert(Image.FORMAT_RGBA8)
     assert(actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data(),"Sleep texture did not survive reload: "+row.species)
  actor.free();node.free()
  var next:Dictionary=row.duplicate(true)
  next.runtime_path=path;next.runtime_sha256=FileAccess.get_sha256(path)
  next["sleep_eye_proposals"]=bindings;next["runtime_approved"]=false
  rows.append(next)
  print("SLEEP_REVIEW_PACK ",row.species," bindings=",bindings.size())
 FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 quit()
