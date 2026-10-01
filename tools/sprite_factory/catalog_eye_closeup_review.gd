extends "catalog_motion_review.gd"
## Review framing only: isolate posed eye surfaces, with whole-model fallback.
func _bounds(model:Node) -> AABB:
 var result:=AABB()
 var first:=true
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
  var posed:Mesh=mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin!=null else mesh.mesh
  for surface in posed.get_surface_count():
   var material:Material=mesh.get_active_material(surface)
   if material==null:continue
   var named_eye:=material.resource_name.to_lower().contains("eye")
   var mesh_eye:=str(mesh.name).to_lower().contains("eye") or material.resource_name in ["BodyAVco","BodyAParasVco00","BodyAParasVco01","BodyBNon"]
   if not named_eye and not mesh_eye:continue
   for vertex:Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    var point:=mesh.global_transform*vertex
    result=AABB(point,Vector3.ZERO) if first else result.expand(point)
    first=false
 return super._bounds(model) if first or result.size.length()<.00001 else result.grow(result.size.length()*.22)
