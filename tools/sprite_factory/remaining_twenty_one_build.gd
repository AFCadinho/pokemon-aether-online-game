extends "catalog_dlc_runtime_review.gd"
## Offline authored previews only. Catalog admission is deliberately absent.
const Costume=preload("remaining_twenty_one_costumes.gd")
const Effect=preload("remaining_twenty_one_effect.gdshader")
const Layers=preload("remaining_twenty_one_layers.gdshader")

func _load_glb(path: String) -> Node3D:
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(path,state)==OK)
 var model:=doc.generate_scene(state,60)
 assert(model!=null)
 return model

func _own(node: Node,owner_node: Node) -> void:
 for child in node.get_children():child.owner=owner_node;_own(child,owner_node)

func _hold(player: AnimationPlayer) -> void:
 if player.has_animation("faint_loop"):return
 var original:=player.get_animation("faint_start")
 var clip:=original.duplicate(true) as Animation
 for track in clip.get_track_count():
  var count:=clip.track_get_key_count(track)
  if count==0:continue
  var v: Variant=clip.track_get_key_value(track,count-1)
  for k in range(count-1,-1,-1):clip.track_remove_key(track,k)
  clip.track_insert_key(track,0.0,v);clip.track_insert_key(track,1.0,v)
 clip.length=1.0;clip.loop_mode=Animation.LOOP_LINEAR
 player.get_animation_library("").add_animation("faint_loop",clip)

func _effects(actor: Node3D,player: AnimationPlayer,tint: Color,crystal: bool) -> int:
 var count:=0
 for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var original:=mesh.get_active_material(surface) as StandardMaterial3D
   if original==null:continue
   var label:=original.resource_name.to_lower()
   var selected: bool=("_gem_mesh" in str(mesh.name) or "body_b" in label) if crystal else ("effect" in label or "light" in label or "body_b" in label or "body_c" in label)
   if not selected:continue
   var material:=ShaderMaterial.new();material.shader=Shader.new();material.shader.code=Effect.code
   material.resource_name=original.resource_name;material.resource_local_to_scene=true
   material.set_shader_parameter("colour_map",original.albedo_texture)
   material.set_shader_parameter("tint",tint);material.set_shader_parameter("crystal",1.0 if crystal else 0.0)
   mesh.set_surface_override_material(surface,material);count+=1
   for action in player.get_animation_list():
    if action=="RESET":continue
    var clip:=player.get_animation(action)
    var track:=clip.add_track(Animation.TYPE_VALUE)
    var root_node:=player.get_node(player.root_node)
    clip.track_set_path(track,NodePath(str(root_node.get_path_to(mesh))+":surface_material_override/%d:shader_parameter/phase"%surface))
    clip.track_insert_key(track,0.0,0.0);clip.track_insert_key(track,clip.length,1.0)
 return count

func _tera(actor: Node3D,player: AnimationPlayer,entry: Dictionary) -> Dictionary:
 var masks: Array[MeshInstance3D]=[]
 for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if "_body_b_mesh" in str(mesh.name):masks.append(mesh)
  if "_branch_" in str(mesh.name) or "_tentacle_" in str(mesh.name):mesh.visible=false
 assert(masks.size()==1)
 var mask:=masks[0];var target:=mask.global_transform*mask.bake_mesh_from_current_skeleton_pose().get_aabb().get_center()
 var gem:=_load_glb(entry.gem_path);world.add_child(gem)
 var gem_player: AnimationPlayer=gem.find_children("*","AnimationPlayer",true,false)[0]
 await _sample(gem,gem_player,"idle",0.0)
 var gem_mask: MeshInstance3D
 for mesh: MeshInstance3D in gem.find_children("*","MeshInstance3D",true,false):
  if "gemmask" in str(mesh.name) or "_body_b_mesh" in str(mesh.name):gem_mask=mesh
 assert(gem_mask!=null)
 var origin:=gem_mask.global_transform*gem_mask.bake_mesh_from_current_skeleton_pose().get_aabb().get_center()
 # Freeze the selected mask pose before attaching it. Body clip resets must
 # not reset this independent mask skeleton back to its unposed source rest.
 for mesh: MeshInstance3D in gem.find_children("*","MeshInstance3D",true,false):
  var baked: Mesh=mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin!=null else mesh.mesh
  var materials:=[]
  for i in mesh.mesh.get_surface_count():materials.append(mesh.get_active_material(i))
  mesh.reparent(gem,true);mesh.skin=null;mesh.skeleton=NodePath("");mesh.mesh=baked
  for i in materials.size():mesh.set_surface_override_material(i,materials[i])
 for child in gem.get_children():
  if not child is MeshInstance3D:child.free()
 var skel: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
 var idx:=skel.find_bone("head");assert(idx>=0)
 var attach:=BoneAttachment3D.new();attach.name="AuthoredTeraAttachment";skel.add_child(attach);attach.owner=actor;attach.bone_name="head"
 gem.reparent(attach,false);gem.name="AuthoredTeraMask"
 var transform:=Transform3D(Basis.IDENTITY,target-origin)
 gem.transform=(skel.global_transform*skel.get_bone_global_pose(idx)).affine_inverse()*transform
 _own(actor,actor)
 var tint:=Color(entry.effect_colour)
 for mesh: MeshInstance3D in gem.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var name:=mesh.get_active_material(surface).resource_name
   if not entry.gem_layers.has(name):continue
   var spec: Dictionary=entry.gem_layers[name]
   var material:=ShaderMaterial.new();material.shader=Shader.new();material.shader.code=Layers.code;material.resource_name=name;material.resource_local_to_scene=true
   for key: String in spec.textures:
    var record: Dictionary=spec.textures[key];assert(FileAccess.get_sha256(record.path)==record.sha256)
    var im:=Image.load_from_file(record.path);im.generate_mipmaps()
    material.set_shader_parameter("layer_mask" if key=="LayerMaskMap" else "normal_map",ImageTexture.create_from_image(im))
   var powers:=Vector4();var scales:=Vector4()
   for i in 4:
    var c: Array=spec.colours.get("BaseColorLayer%d"%[i+1],[1,1,1,1])
    material.set_shader_parameter("colour%d"%[i+1],Vector4(c[0],c[1],c[2],c[3]))
    c=spec.colours.get("EmissionColorLayer%d"%[i+1],[0,0,0,1])
    material.set_shader_parameter("emission%d"%[i+1],Vector4(c[0],c[1],c[2],c[3]))
    powers[i]=spec.floats.get("EmissionIntensityLayer%d"%[i+1],0)
    scales[i]=spec.floats.get("LayerMaskScale%d"%[i+1],1)
   material.set_shader_parameter("powers",powers);material.set_shader_parameter("scales",scales)
   mesh.set_surface_override_material(surface,material)
 var effects:=_effects(gem,player,tint,true)
 return {"attachment_bone":"head","gem_source_sha256":entry.gem_sha256,"authored_alignment":true,"effect_surfaces":effects}

func _run() -> void:
 process_frame.connect(func(): RenderingServer.force_draw(false))
 world=Node3D.new();root.add_child(world)
 var args:=OS.get_cmdline_user_args();assert(args.size()==2)
 var stage: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 var output: String=args[1];DirAccess.make_dir_recursive_absolute(output)
 assert(not FileAccess.file_exists(output.path_join("catalog.json")),"Keep completed preview evidence immutable")
 var results:=[]
 for entry: Dictionary in stage.entries:
  assert(FileAccess.get_sha256(entry.path)==entry.glb_sha256)
  var actor:=_load_glb(entry.path);world.add_child(actor)
  var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
  var complete:=preload("complete_pose_channels.gd").new()
  assert(complete.apply(actor),complete.failure)
  _hold(player)
  await _sample(actor,player,"idle",0.0)
  var changes:={}
  if entry.base_species=="castform-snowy":
   for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
    if "HeadB" in str(mesh.name):mesh.visible=false
    if "HeadC" in str(mesh.name):
     for i in mesh.mesh.get_surface_count():
      var material:=mesh.get_active_material(i).duplicate(true) as StandardMaterial3D
      var im:=material.albedo_texture.get_image()
      im.convert(Image.FORMAT_RGBA8)
      for y in im.get_height():
       for x in im.get_width():
        var c:=im.get_pixel(x,y)
        if c.b>c.g*1.10:c.a=0.0;im.set_pixel(x,y,c)
      im.generate_mipmaps();material.albedo_texture=ImageTexture.create_from_image(im)
      material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
      mesh.set_surface_override_material(i,material)
    if "HeadA" in str(mesh.name):
     for i in mesh.mesh.get_surface_count():
      var material:=mesh.get_active_material(i).duplicate(true) as StandardMaterial3D
      material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
      material.albedo_color.a=0.28;mesh.set_surface_override_material(i,material)
   changes={"authored_shell_visibility":true,"authored_shell_alpha":0.28}
  if entry.base_species.begins_with("pikachu-") or entry.base_species=="pichu-spiky-eared":
   changes=Costume.new().apply(actor,entry.base_species)
  elif entry.base_species.begins_with("ogerpon-"):
   changes=await _tera(actor,player,entry)
  elif entry.base_species in ["necrozma-dawn-wings","necrozma-dusk-mane"]:
   changes={"authored_effect_surfaces":_effects(actor,player,Color("b598f9"),false)}
  actor.set_meta("remaining_forms_local_preview",true)
  actor.set_meta("authored_reconstruction",true)
  _own(actor,actor)
  var packed:=PackedScene.new();assert(packed.pack(actor)==OK)
  var path:=output.path_join(entry.species+".scn")
  assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var result:=entry.duplicate(true)
  result["runtime_path"]=path;result["runtime_sha256"]=FileAccess.get_sha256(path)
  result["changes"]=changes;result["status"]="exported_for_review"
  result["animations"]={}
  for clip in player.get_animation_list():
   if clip=="RESET":continue
   var a:=player.get_animation(clip)
   result.animations[clip]={"duration":a.length,"loop":a.loop_mode==Animation.LOOP_LINEAR}
  result["review_poses"]=[["idle",0.0,"front"],["idle",0.5,"back"],["physical_attack",0.5,"front"],["special_attack",0.5,"front"],["damage",0.5,"front"],["sleep",0.5,"front"],["faint_start",1.0,"front"]]
  results.append(result);actor.free();print("RECONSTRUCTION_BUILT ",entry.species)
 var file:=FileAccess.open(output.path_join("catalog.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"runtime_approved":false,"entries":results},"  "));file.close()
 world.free();quit()
