extends "catalog_pair_runtime_parity.gd"
## Exact geometry/skin/motion equality after material-only eye state proposals.
func _structure(node:Node) -> Dictionary:
 var data:Dictionary=super._structure(node)
 if node is AnimationPlayer:
  for name in data.animations:
   var retained:Array=[]
   for track:Array in data.animations[name][2]:
    var path:=str(track[1])
    # These are the explicit offline texture-state tracks introduced by the
    # sleep pack. Bone, visibility, effect and other tracks remain exact.
    if path.contains(":surface_material_override/") and path.ends_with(":albedo_texture"):
     assert(track[0]==Animation.TYPE_VALUE)
     continue
    retained.append(track)
   data.animations[name][2]=retained
 var generated:=RegEx.new();generated.compile("@PhysicalBoneSimulator3D@[0-9]+")
 for child:Array in data.children:
  child[0]=generated.sub(str(child[0]),"@PhysicalBoneSimulator3D",true)
 return data
