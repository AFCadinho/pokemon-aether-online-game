extends RefCounted
## Explicit authored geometry. Attachments are bound to the animated source bones.
var actor: Node3D
var skeleton: Skeleton3D
var counter := 0
var attachments: Array[String] = []

func _mat(colour: Color, metal: float = 0.0) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=colour;m.roughness=0.65;m.metallic=metal;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.resource_local_to_scene=true
 return m

func _bind(mesh: Mesh, bone: String, pos: Vector3, scale: Vector3, colour: Color, rotation: Vector3=Vector3.ZERO, metal: float=0.0) -> MeshInstance3D:
 var index:=skeleton.find_bone(bone);assert(index>=0,"Missing costume bone: "+bone)
 var attach:=BoneAttachment3D.new();counter+=1;attach.name="ReconstructionAttach%d"%counter
 skeleton.add_child(attach);attach.owner=actor;attach.bone_name=bone
 var item:=MeshInstance3D.new();item.name="AuthoredDetail%d"%counter;item.mesh=mesh;item.material_override=_mat(colour,metal)
 attach.add_child(item);item.owner=actor
 var desired:=Transform3D(Basis.from_euler(rotation).scaled(scale),pos)
 item.transform=(skeleton.global_transform*skeleton.get_bone_global_pose(index)).affine_inverse()*desired
 attachments.append(bone)
 return item

func _ball(bone: String,pos: Vector3,size: Vector3,c: Color) -> void:
 var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=32;mesh.rings=16
 _bind(mesh,bone,pos,size,c)

func _box(bone: String,pos: Vector3,size: Vector3,c: Color,rotation: Vector3=Vector3.ZERO) -> void:
 var mesh:=BoxMesh.new();mesh.size=Vector3.ONE
 _bind(mesh,bone,pos,size,c,rotation)

func _ring(bone: String,pos: Vector3,radius: float,tube: float,c: Color,rotation: Vector3=Vector3.ZERO,scale: Vector3=Vector3.ONE) -> void:
 var mesh:=TorusMesh.new();mesh.inner_radius=radius-tube;mesh.outer_radius=radius+tube;mesh.rings=48;mesh.ring_segments=10
 _bind(mesh,bone,pos,scale,c,rotation)

func _cone(bone: String,pos: Vector3,radius: float,height: float,c: Color,rotation: Vector3=Vector3.ZERO) -> void:
 var mesh:=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=0;mesh.height=height;mesh.radial_segments=12
 _bind(mesh,bone,pos,Vector3.ONE,c,rotation)

func _cloth(bone: String,ys: Array,radii: Array,c: Color,start: float=0.0,end: float=TAU,zscale: float=0.85) -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in ys.size()-1:
  for i in 64:
   var a:=lerpf(start,end,float(i)/64);var b:=lerpf(start,end,float(i+1)/64)
   var pts:=[Vector3(sin(a)*radii[row],ys[row],cos(a)*radii[row]*zscale),Vector3(sin(b)*radii[row],ys[row],cos(b)*radii[row]*zscale),Vector3(sin(a)*radii[row+1],ys[row+1],cos(a)*radii[row+1]*zscale),Vector3(sin(b)*radii[row+1],ys[row+1],cos(b)*radii[row+1]*zscale)]
   for idx in [0,2,1,1,2,3]:surface.add_vertex(pts[idx])
 surface.generate_normals()
 _bind(surface.commit(),bone,Vector3.ZERO,Vector3.ONE,c)

func _bow(bone: String,pos: Vector3,c: Color,size: float=1.0) -> void:
 for side in [-1,1]:
  _ball(bone,pos+Vector3(side*.018*size,0,0),Vector3(.022,.012,.009)*size,c)
 _ball(bone,pos,Vector3(.009,.009,.011)*size,c)

func _tail() -> void:
 for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if not "sippo" in str(node.name):continue
  var baked:=node.bake_mesh_from_current_skeleton_pose()
  var rebuilt:=ArrayMesh.new()
  for s in node.mesh.get_surface_count():
   var arrays:=node.mesh.surface_get_arrays(s)
   var posed: PackedVector3Array=baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
   var ymax:=-INF;var ymin:=INF
   for pt in posed:
    var y:=(node.global_transform*pt).y;ymax=maxf(ymax,y);ymin=minf(ymin,y)
   var colours:=PackedColorArray()
   for pt in posed:colours.append(Color(0.035,0.028,0.04) if (node.global_transform*pt).y>lerpf(ymin,ymax,0.72) else Color.WHITE)
   arrays[Mesh.ARRAY_COLOR]=colours
   rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var original:=node.get_active_material(s) as StandardMaterial3D
   var mat:=ShaderMaterial.new();mat.shader=Shader.new()
   mat.shader.code="shader_type spatial; uniform sampler2D base : source_color,filter_linear_mipmap; void fragment(){ ALBEDO=texture(base,UV).rgb*mix(vec3(0.035),vec3(1.0),step(0.5,COLOR.r));ROUGHNESS=0.7;}"
   mat.set_shader_parameter("base",original.albedo_texture)
   mat.resource_local_to_scene=true;rebuilt.surface_set_material(s,mat)
  node.mesh=rebuilt
  for s in rebuilt.get_surface_count():node.set_surface_override_material(s,rebuilt.surface_get_material(s))

func apply(model: Node3D, name: String) -> Dictionary:
 actor=model;skeleton=actor.find_children("*","Skeleton3D",true,false)[0]
 var white:=Color("fff6ea");var pink:=Color("ef65af");var blue:=Color("376cc8");var dark:=Color("252431");var red:=Color("bf2637");var orange:=Color("eb6825")
 if name.begins_with("pikachu-"):_tail()
 if name=="pikachu-cosplay":return {"attachments":attachments,"black_tail_tip":true}
 if name=="pichu-spiky-eared":
  var i:=skeleton.find_bone("left_ear_02");assert(i>=0)
  var p:=(skeleton.global_transform*skeleton.get_bone_global_pose(i)).origin
  for j in 3:
   _cone("left_ear_02",p+Vector3(.018+j*.014,.016-j*.018,0),.013,.046,Color("292834"),Vector3(0,0,-.9-j*.15))
  return {"attachments":attachments,"authored_ear":true}
 if name=="pikachu-phd":
  _cloth("spine_01",[.035,.14,.215],[.126,.111,.068],white,.48,TAU-.48)
  for side in [-1,1]:
   _ball("head",Vector3(side*.073,.274,.095),Vector3(.009,.006,.015),dark)
   _ring("head",Vector3(side*.043,.285,.119),.026,.004,white,Vector3(PI/2,0,0))
   for j in 28:
    var angle:=j*TAU/14;var r:=.003+j*.00068
    _ball("head",Vector3(side*.043+sin(angle)*r,.285+cos(angle)*r,.121),Vector3(.0015,.0015,.0015),white)
  _box("head",Vector3(0,.377,.015),Vector3(.19,.016,.17),dark,Vector3(0,.12,0))
  _box("head",Vector3(0,.357,.015),Vector3(.12,.027,.09),dark)
  _bow("spine_02",Vector3(0,.210,.097),Color("75b644"))
  _box("head",Vector3(.082,.352,.078),Vector3(.007,.065,.007),Color("e4c348"))
 elif name=="pikachu-pop-star":
  _cloth("hips",[.052,.080,.170],[.163,.145,.091],pink)
  _cloth("hips",[.043,.052,.062],[.165,.165,.157],white)
  _cloth("spine_01",[.164,.218],[.096,.074],pink)
  _bow("head",Vector3(-.076,.362,.04),pink,1.3)
  _bow("spine_02",Vector3(0,.207,.099),white,.8)
  for j in 18:
   var angle:=j*TAU/18
   _ball("hips",Vector3(sin(angle)*.16,.051,cos(angle)*.137),Vector3(.017,.012,.012),white)
  for side in [-1,1]:
   for j in 3:_ball("head",Vector3(side*(.082+j*.004),.302-j*.019,.043),Vector3(.019,.018,.018),pink)
 elif name=="pikachu-belle":
  _cloth("hips",[.017,.065,.18],[.169,.150,.079],blue)
  _cloth("hips",[.016,.028],[.175,.17],white)
  _cloth("spine_01",[.16,.22],[.092,.077],blue)
  _ball("head",Vector3(0,.328,-.038),Vector3(.132,.175,.045),blue)
  _ball("head",Vector3(0,.328,-.015),Vector3(.117,.158,.021),white)
  _ring("head",Vector3(0,.324,-.008),.125,.024,blue,Vector3(PI/2,0,0),Vector3(1,1,1.38))
  _ring("head",Vector3(0,.324,.013),.126,.010,white,Vector3(PI/2,0,0),Vector3(1,1,1.38))
  _bow("head",Vector3(.094,.248,.048),white,1.1)
  _bow("spine_02",Vector3(0,.203,.105),white,1.2)
  for side in [-1,1]:
   _ball("spine_02",Vector3(side*.082,.189,.023),Vector3(.038,.033,.048),blue)
 elif name=="pikachu-rock-star":
  _cloth("hips",[.028,.125],[.105,.113],dark)
  _cloth("spine_01",[.113,.205],[.116,.088],red,.5,TAU-.5)
  _box("hips",Vector3(0,.115,.102),Vector3(.15,.020,.01),dark)
  for side in [-1,1]:
   _ball("spine_02",Vector3(side*.090,.207,0.012),Vector3(.035,.025,.042),dark)
   for j in 4:_cone("spine_02",Vector3(side*(.073+j*.014),.23,.01),.010,.033,Color("c3c8d5"),Vector3(0,0,-side*.25))
   _box("head",Vector3(side*.049,.347,.102),Vector3(.070,.013,.008),red,Vector3(0,0,side*.8))
  for j in 8:_ball("hips",Vector3(-.066+j*.019,.115,.110),Vector3(.003,.004,.002),Color("e9c650"))
 elif name=="pikachu-libre":
  _cloth("hips",[.03,.12],[.106,.113],dark)
  _box("hips",Vector3(0,.13,.109),Vector3(.17,.030,.014),red)
  for side in [-1,1]:
   _ring("head",Vector3(side*.041,.29,.12),.039,.011,orange,Vector3(PI/2,0,0),Vector3(.92,1,.87))
   _ring("head",Vector3(side*.041,.29,.126),.028,.0035,white,Vector3(PI/2,0,0),Vector3(.92,1,.87))
   _box("head",Vector3(side*.025,.332,.103),Vector3(.044,.035,.009),orange,Vector3(0,0,-side*.45))
   _ball("left_foot" if side==1 else "right_foot",Vector3(side*.065,.019,.026),Vector3(.035,.020,.048),red)
  _box("head",Vector3(0,.30,.127),Vector3(.020,.022,.012),orange)
 else:assert(false,"Unknown costume "+name)
 return {"attachments":attachments,"authored_geometry":counter,"black_tail_tip":true}
