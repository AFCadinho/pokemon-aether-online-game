extends RefCounted
## GLES outdoor presentation gain, compared against the linear-renderer preview.
## Only instance-local lit albedo changes; textures, alpha and emission are kept.
const Colour = preload("res://scripts/battle/arenas/shared/compatibility_outdoor_colour.gd")
const GAIN := 0.82
const META := "pokeaether_android_outdoor_exposure"

static func supported() -> bool:
	return Colour.supported()

static func apply(actor: Node) -> int:
	var copies: Dictionary = {}
	var count := 0
	var nodes: Array[Node] = [actor]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var original: Material = node.get_active_material(surface)
				if not original is StandardMaterial3D or original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or original.next_pass != null or original.has_meta(META):
					continue
				var key := original.get_instance_id()
				if not copies.has(key):
					var material := original.duplicate() as StandardMaterial3D
					var colour := material.albedo_color
					material.albedo_color = Color(colour.r * GAIN, colour.g * GAIN, colour.b * GAIN, colour.a)
					material.set_meta(META, GAIN)
					copies[key] = material
					count += 1
				if node.material_override != null:
					node.material_override = copies[key]
				else:
					node.set_surface_override_material(surface, copies[key])
	return count
