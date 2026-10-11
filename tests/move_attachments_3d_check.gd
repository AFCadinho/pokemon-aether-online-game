extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
class Doll extends Node3D:
	var idle_scale := 0.8
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const SourceEffect = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const LegacyEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
var seconds := 0.0
func _ready() -> void: _run.call_deferred()
func _rig(world: Node3D, names: Array) -> Node3D:
	var actor := Node3D.new()
	world.add_child(actor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Rig"
	actor.add_child(skeleton)
	for name_value: String in names: skeleton.add_bone(name_value)
	return actor
func _run() -> void:
	get_tree().create_timer(15).timeout.connect(func(): get_tree().quit(1))
	var world := Node3D.new()
	add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(5, -2, 3))
	_check_weighted_attachments(world)
	_check_family_routes()
	_check_reviewed_hand_routes()
	_check_catalog_routes()
	var actor := _rig(world, ["head", "left_feeler_b_02", "right_feeler_b_02"])
	actor.transform = Transform3D(Basis(Vector3.UP, 0.9).scaled(Vector3(2, 3, 2)), Vector3(-4, 1, 2))
	var skeleton: Skeleton3D = actor.get_node("Rig")
	skeleton.position = Vector3(0.2, 0.3, 0.4)
	skeleton.set_bone_pose_position(0, Vector3(0, 1, 0))
	var mouth: Dictionary = Attachments.sample(actor, "charmander", "ember", world)
	var expected: Vector3 = actor.transform * skeleton.transform * (Vector3(0, 1, 0) + Vector3(0.05, 0, 0.195))
	assert(mouth.sources[0].is_equal_approx(expected))
	skeleton.set_bone_pose_position(0, Vector3(0.2, 1.5, -0.1))
	var rotation_value := Quaternion(Vector3.RIGHT, 0.65)
	skeleton.set_bone_pose_rotation(0, rotation_value)
	mouth = Attachments.sample(actor, "charmander@shiny", "ember", world)
	expected = actor.transform * skeleton.transform * (Vector3(0.2, 1.5, -0.1) + rotation_value * Vector3(0.05, 0, 0.195))
	assert(mouth.sources[0].is_equal_approx(expected), "Cached bindings must sample fresh bone poses")
	skeleton.set_bone_pose_position(1, Vector3(-0.5, 1, 0))
	skeleton.set_bone_pose_position(2, Vector3(0.5, 1, 0))
	var cannons: Dictionary = Attachments.sample(actor, "blastoise", "watergun", world)
	assert(cannons.sources.size() == 2 and cannons.part == "cannons")
	assert(cannons.sources[0].distance_to(cannons.sources[1]) > 0.9)
	assert(Attachments.sample(actor, "blastoise-mega", "watergun", world).is_empty())
	assert(Attachments.sample(actor, "unknown", "watergun", world).is_empty())
	assert(Attachments.part_for("charmander", "bite") == "mouth")
	assert(Attachments.part_for("charmander", "scratch") == "hand")
	assert(Attachments.part_for("pikachu", "tackle") == "body")
	assert(Attachments.part_for("pikachu@shiny", "thundershock") == "electric_body")
	for identity: String in ["zapdos", "zapdos@shiny", "zapdos-galar", "zapdos-galar@shiny"]:
		assert(Attachments.part_for(identity, "peck") == "beak_tip")
		assert(Attachments.part_for(identity, "hyperbeam") == "mouth")
		assert(Attachments.definitions_for(identity, "beak_tip").size() == 1)
		assert(Attachments.definitions_for(identity, "beak_tip")[0][0].bone == "head")
	for identity: String in ["zygarde-mega", "zygarde-mega@shiny"]:
		assert(Attachments.part_for(identity, "hyperbeam") == "cannon")
		assert(Attachments.definitions_for(identity, "cannon")[0][0].bone == "feeler_a_02")
		assert(Attachments.part_for(identity, "bite") == "face")
	assert(Attachments.part_for("zygarde-50", "hyperbeam") == "mouth")
	for species: String in ["regice", "regieleki", "regigigas", "regirock", "registeel", "staryu", "starmie"]:
		for identity: String in [species, species + "@shiny"]:
			var part := "gem" if species.begins_with("star") else "face"
			var move := "watergun" if part == "gem" else "hyperbeam"
			assert(Attachments.part_for(identity, move) == part)
			assert(Attachments.definitions_for(identity, part).size() == 1)
			assert(Attachments.definitions_for(identity, "mouth").is_empty())
			assert(Attachments.part_for(identity, "tackle") == "body")
	for identity: String in ["staryu", "staryu@shiny", "starmie", "starmie@shiny"]:
		for move: String in ["watergun", "bubblebeam", "icebeam", "flashcannon", "scald", "waterpulse"]:
			assert(Attachments.part_for(identity, move) == "gem")
	assert(Attachments.part_for("starmie", "hyperbeam") == "gem")
	assert(Attachments.definitions_for("starmie-mega", "gem") != Attachments.definitions_for("starmie", "gem"))
	for species: String in ["honedge", "doublade", "aegislash-blade", "aegislash-shield"]:
		for identity: String in [species, species+"@shiny"]:
			var count := 2 if species == "doublade" else 1
			assert(Attachments.definitions_for(identity,"eye").size() == count)
			assert(Attachments.definitions_for(identity,"eye","special_attack").size() == count)
			assert(Attachments.definitions_for(identity,"eye") != Attachments.definitions_for(identity,"eye","special_attack"))
			assert(Attachments.definitions_for(identity,"mouth").is_empty())
			for move_key: String in ["flashcannon","screech"]:
				assert(Attachments.part_for(identity,move_key) == "eye")
			if species.begins_with("aegislash"):
				for move_key: String in ["hyperbeam","shadowball"]: assert(Attachments.part_for(identity,move_key) == "eye")
	for route: Array in [["weedle","stringshot","face","physical_attack_2",0.2,1],["weedle","bugbite","face","physical_attack_2",1,1],["weedle","poisonsting","spike","physical_attack_2",0.15,1],["wurmple","stringshot","muzzle","special_attack",0.2,1],["wurmple","bugbite","muzzle","physical_attack",1,1],["wurmple","poisonsting","spike","physical_attack",0.2,1],["venipede","bite","muzzle","physical_attack_2",1,1],["venipede","bugbite","muzzle","physical_attack_2",1,1],["venipede","poisonsting","spikes","physical_attack_2",0.15,2],["venipede","screech","muzzle","physical_attack_2",1,1],["venipede","sludgebomb","muzzle","physical_attack_2",0.1,1],["venipede","solarbeam","muzzle","physical_attack_2",0.1,1],["whirlipede","bite","carapace_front","physical_attack_2",1,1],["whirlipede","bugbite","carapace_front","physical_attack_2",1,1],["whirlipede","poisonsting","spikes","special_attack",0.2,2],["whirlipede","screech","carapace_front","special_attack",1,1],["whirlipede","sludgebomb","carapace_front","special_attack",0.15,1],["whirlipede","solarbeam","carapace_front","special_attack",0.15,1],["surskit","watergun","face","special_attack",0.1,1],["surskit","icebeam","face","special_attack",0.1,1],["surskit","solarbeam","face","special_attack",0.1,1],["surskit","scald","face","special_attack",0.1,1],["surskit","shadowball","face","special_attack",0.07,1],["surskit","mudslap","face","special_attack",0.05,1],["surskit","stringshot","face","special_attack",0.2,1],["surskit","bubble","face","special_attack",0.12,1],["surskit","bubblebeam","face","special_attack",0.12,1],["surskit","waterpulse","face","special_attack",0.12,1],["surskit","bugbite","face","physical_attack",1,1],["masquerain","watergun","face","special_attack",0.12,1],["masquerain","icebeam","face","special_attack",0.12,1],["masquerain","solarbeam","face","special_attack",0.12,1],["masquerain","scald","face","special_attack",0.12,1],["masquerain","hyperbeam","face","special_attack",0.12,1],["masquerain","shadowball","face","special_attack",0.12,1],["masquerain","mudslap","face","special_attack",0.1,1],["masquerain","stringshot","face","special_attack",0.2,1],["masquerain","bubble","face","special_attack",0.15,1],["masquerain","bubblebeam","face","special_attack",0.15,1],["masquerain","waterpulse","face","special_attack",0.15,1],["masquerain","bugbite","face","physical_attack",1,1],["kricketot","growl","muzzle","special_attack",1,1],["kricketot","stringshot","muzzle","special_attack",0.2,1],["kricketot","mudslap","muzzle","special_attack",0.05,1],["kricketot","bugbite","muzzle","physical_attack_2",1,1],["kricketune","growl","muzzle","special_attack",1,1],["kricketune","stringshot","muzzle","special_attack",0.2,1],["kricketune","mudslap","muzzle","special_attack",0.1,1],["kricketune","bugbite","muzzle","physical_attack_2",1,1],["kricketune","hyperbeam","muzzle","special_attack",0.1,1],["kricketune","screech","muzzle","special_attack",1,1],["cottonee","solarbeam","cotton_front","special_attack",0.12,1],["cherrim","hyperbeam","bud","special_attack",0.15,1],["cherrim","solarbeam","bud","special_attack",0.15,1],["petilil","solarbeam","face","special_attack",0.08,1],["lilligant","hyperbeam","face","physical_attack_2",0.1,1],["lilligant","solarbeam","face","physical_attack_2",0.1,1],["fomantis","solarbeam","face","special_attack",0.08,1],["fomantis","bugbite","face","physical_attack_2",1,1],["lurantis","hyperbeam","face","physical_attack",0.1,1],["lurantis","solarbeam","face","physical_attack",0.1,1],["lurantis","bugbite","face","physical_attack",1,1],["morelull","solarbeam","face","special_attack",0.08,1],["morelull","sludgebomb","face","special_attack",0.05,1],["spoink","flashcannon","pearl","special_attack",0.12,1],["spoink","shadowball","pearl","special_attack",0.12,1],["spoink","growl","face","special_attack",1,1],["seedot","shadowball","face","special_attack",0.08,1],["seedot","solarbeam","face","special_attack",0.1,1],["pineco","solarbeam","face","special_attack",0.1,1],["pineco","stringshot","face","special_attack",0.25,1],["pineco","bugbite","face","physical_attack_2",1,1],["forretress","flashcannon","cannon","special_attack",0.12,1],["forretress","hyperbeam","cannon","special_attack",0.12,1],["forretress","solarbeam","cannon","special_attack",0.12,1],["forretress","voltswitch","cannon","special_attack",0.12,1],["pupitar","hyperbeam","face","special_attack",0.15,1],["pupitar","screech","face","special_attack",1,1],["pupitar","mudslap","face","special_attack",0.15,1],["pupitar","bite","face","physical_attack_2",1,1],["carbink","flashcannon","gem","special_attack",0.1,1],["carbink","hyperbeam","gem","special_attack",0.1,1],["cryogonal","flashcannon","mouth","special_attack",0.12,1],["cryogonal","hyperbeam","mouth","special_attack",0.12,1],["cryogonal","icebeam","mouth","special_attack",0.12,1],["cryogonal","solarbeam","mouth","special_attack",0.12,1],["cryogonal","waterpulse","mouth","special_attack",1,1],["glimmet","sludgebomb","face","special_attack",0.05,1],["glimmora","flashcannon","flower_core","special_attack",0.2,1],["glimmora","hyperbeam","flower_core","special_attack",0.2,1],["glimmora","solarbeam","flower_core","special_attack",0.2,1],["glimmora","sludgebomb","flower_core","special_attack",0.15,1],["gimmighoul","shadowball","mouth","special_attack",0.04,1],["meltan","flashcannon","eye","special_attack",0.08,1],["melmetal","flashcannon","eye","special_attack",0.12,1],["melmetal","hyperbeam","eye","special_attack",0.12,1],["melmetal","icebeam","eye","special_attack",0.12,1],["melmetal","solarbeam","eye","special_attack",0.12,1],["nosepass","flashcannon","nose","special_attack",0.15,1],["nosepass","voltswitch","nose","special_attack",0.15,1],["nacli","flashcannon","face","special_attack",0.06,1],["naclstack","flashcannon","face","special_attack",0.15,1],["naclstack","hyperbeam","face","special_attack",0.15,1],["rolycoly","mudslap","wheel_front","physical_attack_2",0.1,1],["voltorb","screech","face","special_attack",1,1],["voltorb-hisui","screech","face","physical_attack",1,1],["voltorb-hisui","solarbeam","face","physical_attack",0.15,1],["diglett","growl","face","special_attack",1,1],["diglett","screech","face","special_attack",1,1],["diglett","sludgebomb","face","special_attack",0.06,1],["diglett-alola","growl","face","special_attack",1,1],["diglett-alola","screech","face","special_attack",1,1],["diglett-alola","sludgebomb","face","special_attack",0.06,1],["diglett-alola","flashcannon","face","special_attack",0.06,1],["dugtrio","growl","face","physical_attack",1,3],["dugtrio","screech","face","physical_attack",1,3],["dugtrio","sludgebomb","face_primary","physical_attack",0.1,1],["dugtrio","hyperbeam","face_primary","physical_attack",0.1,1],["dugtrio-alola","growl","face","physical_attack",1,3],["dugtrio-alola","screech","face","physical_attack",1,3],["dugtrio-alola","sludgebomb","face_primary","physical_attack",0.1,1],["dugtrio-alola","hyperbeam","face_primary","physical_attack",0.1,1],["dugtrio-alola","flashcannon","face_primary","physical_attack",0.1,1]]:
		for identity: String in [route[0], route[0]+"@shiny"]:
			assert(Attachments.part_for(identity, route[1]) == route[2])
			assert(Attachments.definitions_for(identity,route[2],route[3]).size() == route[5])
			assert(Attachments.action_for(identity,route[1],{route[3]:{}}) == route[3])
			assert(is_equal_approx(Attachments.choreography_for(identity,route[1],route[3]).get("emission_scale",1),route[4]))
	for route: Array in [["magnemite","flashcannon","eye","special_attack",0.12],["magnemite","screech","eye","special_attack",1],["magnemite","supersonic","eye","special_attack",1],["magnezone","flashcannon","eye","physical_attack",0.18],["magnezone","hyperbeam","eye","physical_attack",0.18],["magnezone","screech","eye","physical_attack",1],["magnezone","supersonic","eye","physical_attack",1],["lampent","flamethrower","face","physical_attack_2",0.15],["lampent","solarbeam","face","physical_attack_2",0.15],["lampent","shadowball","face","physical_attack_2",0.12],["lampent","ember","face","physical_attack_2",0.15],["chandelure","flamethrower","face","physical_attack",0.15],["chandelure","solarbeam","face","physical_attack",0.15],["chandelure","hyperbeam","face","physical_attack",0.15],["chandelure","shadowball","face","physical_attack",0.12],["chandelure","ember","face","physical_attack",0.15],["bronzor","flashcannon","face","special_attack",0.12],["bronzor","solarbeam","face","special_attack",0.12],["bronzor","shadowball","face","special_attack",0.1],["bronzong","flashcannon","face","special_attack",0.2],["bronzong","solarbeam","face","special_attack",0.2],["bronzong","hyperbeam","face","special_attack",0.2],["bronzong","shadowball","face","special_attack",0.15],["cascoon","stringshot","face","special_attack",0.25],["cascoon","bugbite","face","physical_attack_2",1],["kakuna","stringshot","face","special_attack",0.25],["kakuna","bugbite","face","physical_attack_2",1]]:
		for suffix: String in ["","@shiny"]:
			var identity: String = route[0]+suffix
			assert(Attachments.part_for(identity,route[1]) == route[2])
			assert(Attachments.definitions_for(identity,route[2]).size() == 1)
			var choreography: Dictionary = Attachments.choreography_for(identity,route[1],route[3])
			assert(not choreography.is_empty())
			assert(is_equal_approx(float(choreography.get("emission_scale",1)),route[4]))
	for identity: String in ["silcoon","silcoon@shiny"]:
		assert(Attachments.part_for(identity,"poisonsting") == "spike")
		var spike := Attachments.definitions_for(identity,"spike")
		assert(spike.size() == 1 and spike[0].size() == 2)
		assert(spike[0][0].bone == "feeler_a_02")
		assert(is_equal_approx(Attachments.choreography_for(identity,"poisonsting","physical_attack_2").emission_scale,.2))
	for species: String in ["silcoon","spewpa"]:
		for identity: String in [species,species+"@shiny"]:
			assert(Attachments.definitions_for(identity,"face").size() == 1)
			assert(Attachments.definitions_for(identity,"mouth").is_empty())
			for move_key: String in ["bugbite","stringshot"]:
				assert(Attachments.part_for(identity,move_key) == "face")
				assert(Attachments.action_for(identity,move_key,{"physical_attack":{}}) == "physical_attack")
			assert(is_equal_approx(Attachments.choreography_for(identity,"stringshot","physical_attack").emission_scale,.25))
	for identity: String in ["sinistea", "sinistea@shiny"]:
		assert(Attachments.part_for(identity, "shadowball") == "spirit")
		assert(Attachments.definitions_for(identity, "spirit").is_empty())
		assert(Attachments.definitions_for(identity, "spirit", "physical_attack").is_empty())
		var spirit := Attachments.definitions_for(identity, "spirit", "special_attack")
		assert(spirit.size() == 3)
		for index in 3:
			assert(str(spirit[index][0].visible_mesh).ends_with(["top_b_mesh", "top_c_mesh", "top_d_mesh"][index]))
		assert(Attachments.action_for(identity, "shadowball", {"special_attack":{}}) == "special_attack")
	for route: Array in [["beldum", "forehead", "head", ["ironhead", "tackle"]], ["unown", "eye", "waist", ["hiddenpower"]], ["chandelure-mega", "face", "spine", ["ember", "flamethrower", "hyperbeam", "shadowball", "solarbeam"]], ["runerigus", "face", "feeler_a_03", ["hyperbeam", "shadowball"]]]:
		for identity: String in [route[0], route[0] + "@shiny"]:
			var definition := Attachments.definitions_for(identity, route[1])
			assert(definition.size() == 1 and definition[0][0].bone == route[2])
			for move: String in route[3]: assert(Attachments.part_for(identity, move) == route[1])
	assert(Attachments.definitions_for("chandelure", "face") != Attachments.definitions_for("chandelure-mega", "face"))
	assert(Attachments.definitions_for("yamask-galar", "face").is_empty())
	assert(is_equal_approx(Attachments.choreography_for("unown", "hiddenpower", "special_attack").emission_scale, .12))
	for species: String in ["grimer", "grimer-alola", "goodra", "gengar", "crobat", "bunnelby"]:
		for identity: String in [species, species + "@shiny"]:
			var emitters := Attachments.definitions_for(identity, "mouth")
			assert(emitters.size() == 1)
			assert(emitters[0].size() > 1 if species != "crobat" else emitters[0][0].bone == "head")
			assert(Attachments.part_for(identity, "sludgebomb") == "mouth")
	assert(Attachments.definitions_for("grimer", "mouth") != Attachments.definitions_for("grimer-alola", "mouth"))
	assert(Attachments.definitions_for("goodra", "mouth") != Attachments.definitions_for("goodra-hisui", "mouth"))
	assert(Attachments.definitions_for("gengar", "mouth") != Attachments.definitions_for("gengar-mega", "mouth"))

	for species: String in ["cetoddle", "drizzile", "crabominable", "lugia", "ho-oh", "houndstone", "minccino", "grumpig", "slaking", "sudowoodo", "wyrdeer", "slugma", "archaludon", "avalugg-hisui", "glalie-mega", "roaring-moon", "skarmory", "skarmory-mega", "sandaconda", "swinub", "steelix", "stonjourner", "mandibuzz", "swanna", "stunfisk", "snivy"]:
		for identity: String in [species, species + "@shiny"]:
			var emitters := Attachments.definitions_for(identity, "mouth")
			assert(emitters.size() == 1 and emitters[0].size() > 1)
			assert(Attachments.part_for(identity, "icebeam") == "mouth")

	for identity: String in ["arboliva", "arboliva@shiny"]:
		for move: String in ["hyperbeam", "solarbeam"]:
			assert(Attachments.part_for(identity, move) == "olive_nozzle")
			assert(Attachments.action_for(identity, move, {"physical_attack_2":{}}) == "physical_attack_2")
		assert(Attachments.definitions_for(identity, "olive_nozzle")[0][0].bone == "left_feeler_c_02")
		assert(Attachments.definitions_for(identity, "mouth").is_empty())
	for identity: String in ["cubone", "cubone@shiny"]:
		for move: String in ["bubblebeam", "flamethrower", "growl", "icebeam", "screech", "watergun"]:
			assert(Attachments.part_for(identity, move) == "muzzle")
		assert(Attachments.definitions_for(identity, "muzzle")[0][0].bone == "feeler_a")
		assert(Attachments.definitions_for(identity, "mouth").is_empty())
	assert(Attachments.definitions_for("dolliv", "olive_nozzle").is_empty())
	assert(Attachments.definitions_for("marowak", "muzzle").is_empty())

	for species: String in ["skarmory", "skarmory-mega"]:
		for identity: String in [species, species + "@shiny"]:
			assert(Attachments.part_for(identity, "peck") == "beak_tip")
			assert(Attachments.definitions_for(identity, "beak_tip")[0][0].bone == "head")
			assert(Attachments.part_for(identity, "hyperbeam") == "mouth")

	for identity: String in ["ariados", "ariados@shiny"]:
		assert(Attachments.definitions_for(identity, "mouth")[0][0].bone == "head")
		assert(Attachments.part_for(identity, "hyperbeam") == "mouth")

	for identity: String in ["wugtrio", "wugtrio@shiny"]:
		var muzzles := Attachments.definitions_for(identity, "muzzle")
		assert(muzzles.size() == 3)
		for i in 3:
			assert(muzzles[i][0].bone == ["nose_a", "nose_b", "nose_c"][i])
		for move: String in ["watergun", "icebeam", "hyperbeam"]:
			assert(Attachments.part_for(identity, move) == "muzzle")
	for identity: String in ["magneton", "magneton@shiny"]:
		var eyes := Attachments.definitions_for(identity, "face")
		assert(eyes.size() == 3)
		for i in 3:
			assert(eyes[i][0].bone == ["waist_a", "waist_b", "waist_c"][i])
		assert(Attachments.definitions_for(identity, "magnet_poles").size() == 12)
		for move: String in ["flashcannon", "hyperbeam"]:
			assert(Attachments.part_for(identity, move) == "face")
	for identity: String in ["starmie-mega", "starmie-mega@shiny"]:
		assert(Attachments.definitions_for(identity, "gem")[0][0].bone == "spine")
		for move: String in ["bubblebeam", "waterpulse", "scald", "watergun", "icebeam", "hyperbeam", "flashcannon"]:
			assert(Attachments.part_for(identity, move) == "gem")
	assert(Attachments.definitions_for("starmie", "gem")[0][0].bone == "waist")
	assert(Attachments.definitions_for("wiglett", "muzzle").is_empty())
	assert(Attachments.definitions_for("magnemite", "magnet_poles").is_empty())

	for species: String in ["venonat", "mamoswine"]:
		for identity: String in [species, species + "@shiny"]:
			assert(Attachments.definitions_for(identity, "mouth").is_empty(), "Concealed mouth outlet is explicitly named muzzle")
			assert(Attachments.definitions_for(identity, "muzzle").size() == 1)
			assert(Attachments.part_for(identity, "solarbeam" if species == "venonat" else "icebeam") == "muzzle")
	for identity: String in ["flabebe", "flabebe@shiny"]:
		assert(Attachments.part_for(identity, "solarbeam") == "flower_tip")
		assert(Attachments.part_for(identity, "disarmingvoice") == "mouth")
		assert(Attachments.definitions_for(identity, "flower_tip")[0][0].bone == "spine_b_06")
		assert(Attachments.definitions_for(identity, "mouth")[0][0].bone == "head")
	assert(is_equal_approx(Attachments.choreography_for("venonat", "sludgebomb", "special_attack").emission_scale, .12))

	for identity: String in ["hydrapple", "hydrapple@shiny"]:
		var mouths := Attachments.definitions_for(identity, "mouth")
		assert(mouths.size() == 1, "Only the exposed head emits; retracted heads stay inside the apple")
		assert(mouths[0].size() == 2)
		assert(mouths[0][0].bone == "nose_a" and mouths[0][1].bone == "jaw_a_02")
		assert(is_equal_approx(mouths[0][0].weight, .8))
		for move: String in ["hyperbeam", "solarbeam", "dragonbreath", "bugbite"]:
			assert(Attachments.part_for(identity, move) == "mouth")

	for species: String in ["doduo", "dodrio"]:
		for identity: String in [species, species + "@shiny"]:
			var heads := 2 if species == "doduo" else 3
			assert(Attachments.definitions_for(identity, "mouth").size() == heads)
			assert(Attachments.definitions_for(identity, "beak_tip").size() == heads)
			for move: String in ["peck", "furyattack"]:
				assert(Attachments.part_for(identity, move) == "beak_tip")
			for move: String in ["growl", "supersonic"]:
				assert(Attachments.part_for(identity, move) == "mouth")
	for identity: String in ["dodrio", "dodrio@shiny"]:
		assert(Attachments.part_for(identity, "hyperbeam") == "mouth_primary")
		assert(Attachments.definitions_for(identity, "mouth_primary").size() == 1)
		assert(Attachments.definitions_for(identity, "mouth_primary")[0] == Attachments.definitions_for(identity, "mouth")[0])
	for identity: String in ["zweilous", "zweilous@shiny"]:
		var heads := Attachments.definitions_for(identity, "mouth")
		assert(heads.size() == 2)
		assert(heads[0][0].bone == "right_head" and heads[1][0].bone == "left_head")
	for move: String in ["bugbite", "peck", "lick"]:
		assert(Attachments.part_for("charmander", move) == "mouth")
	for move: String in ["doublekick", "highjumpkick", "lowkick", "pyroball"]:
		assert(Attachments.part_for("cinderace", move) == "foot")
	assert(Attachments.part_for("snivy@shiny", "vinewhip") == "vines")
	assert(Attachments.definitions_for("snivy", "vines").size() == 2)
	assert(Attachments.action_for("snivy@shiny", "vinewhip", {"physical_attack_2": {}}) == "physical_attack_2")
	assert(Attachments.action_for("snivy", "vinewhip", {"physical_attack": {}}).is_empty())
	assert(Attachments.action_for("snivy", "tackle", {"physical_attack_2": {}}).is_empty())
	for species: String in ["scovillain", "scovillain@shiny"]:
		for move: String in ["bite", "flamethrower"]:
			assert(Attachments.part_for(species, move) == "mouth_red")
			assert(Attachments.action_for(species, move, {"physical_attack": {}, "special_attack": {}}) == "physical_attack")
		for move: String in ["hyperbeam", "solarbeam"]:
			assert(Attachments.part_for(species, move) == "mouth")
			assert(Attachments.action_for(species, move, {"physical_attack": {}, "special_attack": {}}) == "special_attack")
		assert(Attachments.definitions_for(species, "mouth").size() == 1)
		assert(Attachments.definitions_for(species, "mouth_red").size() == 1)
	assert(Attachments.action_for("scovillain-mega", "flamethrower", {"physical_attack": {}, "special_attack": {}}) == "physical_attack", "Mega has its own reviewed red-mouth clip")
	assert(Attachments.action_for("scovillain-mega", "bite", {"physical_attack": {}, "special_attack": {}}).is_empty(), "Unconfigured Mega moves must not inherit base-form action overrides")
	for route: Array in [["decidueye", "lowkick", "physical_attack_2"], ["glastrier", "doublekick", "physical_attack_2"], ["calyrex-ice", "doublekick", "physical_attack"], ["calyrex-shadow", "doublekick", "physical_attack"], ["exploud", "lowkick", "physical_attack"]]:
		for identity: String in [route[0], route[0] + "@shiny"]:
			assert(Attachments.part_for(identity, route[1]) == "foot")
			assert(Attachments.action_for(identity, route[1], {"physical_attack": {}, "physical_attack_2": {}}) == route[2])
			assert(Attachments.definitions_for(identity, "foot").size() == 1)
	assert(Attachments.action_for("decidueye-hisui", "lowkick", {"physical_attack": {}, "physical_attack_2": {}}).is_empty(), "Hisuian form must not inherit Decidueye's kick clip")
	var electric_actor := _rig(world, ["spine_02"])
	var electric_rig: Skeleton3D = electric_actor.get_node("Rig")
	electric_rig.set_bone_pose_position(0, Vector3(0, 0.8, 0))
	var discharge := Attachments.sample(electric_actor, "pikachu@shiny", "thundershock", world)
	assert(discharge.sources[0].is_equal_approx(Vector3(0,0.8,0)))
	electric_rig.set_bone_pose_position(0, Vector3(0, 1.2, 0))
	assert(Attachments.sample(electric_actor, "pikachu", "thundershock", world).sources[0].is_equal_approx(Vector3(0,1.2,0)))
	assert(Attachments.sample(electric_actor, "pikachu", "tackle", world).is_empty(), "Approved Tackle keeps its body fallback")
	electric_actor.free()
	var incomplete := _rig(world, ["left_feeler_b_02"])
	assert(Attachments.sample(incomplete, "blastoise", "watergun", world).is_empty())
	actor.free()
	actor = _rig(world, ["head"])
	assert(Attachments.sample(actor, "charmander", "ember", world).sources[0].is_equal_approx(Vector3(0.05, 0, 0.195)), "Replacement models must not inherit old bindings")
	var stage := Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	stage.world = world
	stage.identities[0] = "snivy"
	stage.entries.snivy = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Vine Whip", "p1") == "physical_attack_2")
	stage.entries.erase("snivy")
	stage.identities[0] = "scovillain"
	stage.entries.scovillain = {"action_timing": {"physical_attack": {}, "special_attack": {}}}
	assert(stage.attack_action_for("Flamethrower", "p1") == "physical_attack")
	assert(stage.attack_action_for("Solar Beam", "p1") == "special_attack")
	stage.entries.erase("scovillain")
	stage.identities[0] = "decidueye"
	stage.entries.decidueye = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Low Kick", "p1") == "physical_attack_2")
	stage.entries.erase("decidueye")
	stage.identities[0] = "glastrier"
	stage.entries.glastrier = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Double Kick", "p1") == "physical_attack_2")
	stage.entries.erase("glastrier")
	for i in 2:
		stage.actors[i] = _rig(world, ["head"])
		stage.actors[i].position.x = -2 if i == 0 else 2
		stage.identities[i] = "charmander"
		stage.combatants[i] = {"species": "charmander", "shiny": false}
		stage.actor_shown[i] = true
		stage.lifecycle[i] = "idle"
	stage.visual_bounds.charmander = {"idle": {"min": [-0.5,0,-0.5], "size": [1,2,1]}}
	var actual: Dictionary = stage._move_anchors("p1", "p2", "Ember")
	assert(actual.attachment_part == "mouth")
	assert(stage._move_anchors("p2", "p1", "Ember").attachment_part == "mouth")
	# Charmeleon previously used static idle bounds above its animated mouth.
	# Exercise the battle-stage route on both sides, including the shiny rig.
	for index in 2:
		stage.identities[index] = "charmeleon" if index == 0 else "charmeleon@shiny"
		stage.combatants[index] = {"species": "charmeleon", "shiny": index == 1}
		var rig: Skeleton3D = stage.actors[index].get_node("Rig")
		var ident := "p%d" % (index + 1)
		var target := "p%d" % (2 - index)
		stage.actors[index].rotation.y = 0.7 if index == 0 else -0.7
		stage.actors[index].scale = Vector3.ONE * 1.6
		for head_y in [0.8, 1.2]:
			rig.set_bone_pose_position(0, Vector3(0, head_y, 0))
			rig.set_bone_pose_rotation(0, Quaternion(Vector3.RIGHT, head_y))
			var flame: Dictionary = stage._move_anchors(ident, target, "Flamethrower")
			var lip := Vector3(-0.015, 0, 0.235)
			var expected_lip := world.to_local(rig.to_global(rig.get_bone_global_pose(0) * lip))
			assert(flame.attachment_part == "mouth" and flame.attachment_bones == ["head"])
			assert(flame.source.is_equal_approx(expected_lip), "Flamethrower must follow Charmeleon's animated mouth")
		stage.identities[index] = "charmander"
		stage.combatants[index] = {"species": "charmander", "shiny": false}
		stage.actors[index].rotation.y = 0
		stage.actors[index].scale = Vector3.ONE
		rig.reset_bone_pose(0)
	# The whole Moonblast orb must clear the attacker's silhouette on either
	# side, including rotated/scaled models; the moon keeps its own body anchor.
	var orb_radius: float = Stage.BatchFourMoveEffect.MOONBLAST_ORB_RADIUS * LegacyEffect.PRESENTATION_SCALES.moonblast
	for index in 2:
		for yaw in [0.0,PI/4]:
			for size in [0.75,2.0]:
				stage.actors[index].rotation.y = yaw
				stage.actors[index].scale = Vector3.ONE * size
				var charge: Dictionary = stage._move_anchors("p%d" % (index+1),"p%d" % (2-index),"Moonblast")
				var bounds: AABB = stage.actors[index].transform * AABB(Vector3(-0.5,0,-0.5),Vector3(1,2,1))
				var forward: Vector3 = charge.target-charge.source
				forward.y = 0
				forward = forward.normalized()
				for corner in 8:
					assert(charge.source.dot(forward)-orb_radius > bounds.get_endpoint(corner).dot(forward))
				assert(charge.moon_source.dot(forward)<charge.source.dot(forward))
		stage.actors[index].rotation.y = 0
		stage.actors[index].scale = Vector3.ONE
	# Orb presenters must honor an explicit anatomical route too. Their
	# independent moon anchor and unprofiled clearance fallback stay intact.
	var orb_test_profiles: Dictionary = Attachments.CALIBRATED.data.profiles
	var saved_orb_profile: Dictionary = orb_test_profiles["caterpie"].duplicate(true)
	stage.visual_bounds["caterpie"] = stage.visual_bounds.charmander.duplicate(true)
	stage.visual_bounds["caterpie@shiny"] = stage.visual_bounds.charmander.duplicate(true)
	orb_test_profiles["caterpie"] = {
		"parts":{"mouth":[[{"bone":"head","offset":[0.1,0.2,0.3],"weight":1}]]},
		"moves":{"moonblast":"mouth","dracometeor":"mouth"},
	}
	for index in 2:
		var actor_id := "p%d" % (index+1)
		var target_id := "p%d" % (2-index)
		var rig: Skeleton3D = stage.actors[index].get_node("Rig")
		for move_name: String in ["Moonblast","Draco Meteor"]:
			stage.identities[index] = "charmander"
			stage.combatants[index] = {"species":"charmander","shiny":false}
			var fallback: Dictionary = stage._move_anchors(actor_id,target_id,move_name)
			stage.identities[index] = "caterpie" + ("@shiny" if index else "")
			stage.combatants[index] = {"species":"caterpie","shiny":bool(index)}
			for head_y: float in [.5,1.3]:
				rig.set_bone_pose_position(0,Vector3(0,head_y,0))
				var anchored: Dictionary = stage._move_anchors(actor_id,target_id,move_name)
				var expected_orb_origin := world.to_local(rig.to_global(rig.get_bone_global_pose(0)*Vector3(.1,.2,.3)))
				assert(anchored.attachment_part=="mouth" and anchored.attachment_bones==["head"])
				assert(anchored.source.is_equal_approx(expected_orb_origin))
				assert(anchored.target.is_equal_approx(fallback.target))
				assert(anchored.moon_source.is_equal_approx(fallback.moon_source))
			var substitute := Doll.new()
			world.add_child(substitute)
			stage.substitute_models[index] = substitute
			assert(stage._move_anchors(actor_id,target_id,move_name).attachment_part=="bounds")
			substitute.free()
			stage.substitute_models[index] = null
			rig.reset_bone_pose(0)
		stage.identities[index] = "charmander"
		stage.combatants[index] = {"species":"charmander","shiny":false}
	orb_test_profiles["caterpie"] = saved_orb_profile
	stage.visual_bounds.erase("caterpie")
	stage.visual_bounds.erase("caterpie@shiny")
	var doll := Doll.new()
	world.add_child(doll)
	doll.position = Vector3(-3,0,1)
	stage.substitute_models[0] = doll
	assert(stage._move_anchors("p1", "p2", "Ember").attachment_part == "bounds", "Visible Substitute must own the emitter")
	stage.identities[0] = "charmeleon"
	stage.combatants[0].species = "charmeleon"
	assert(stage._move_anchors("p1", "p2", "Flamethrower").attachment_part == "bounds")
	stage.identities[0] = "charmander"
	stage.combatants[0].species = "charmander"
	var doll_charge: Dictionary = stage._move_anchors("p1","p2","Moonblast")
	assert(doll_charge.source.distance_to(doll.position)>orb_radius+doll.idle_scale*0.6)
	doll.hide()
	assert(stage._move_anchors("p1", "p2", "Ember").attachment_part == "mouth")
	stage.world = null # This fixture owns world separately from the stage.
	stage.free()
	# Both renderers emit two beams but keep one target splash and one effect clock.
	for script in [SourceEffect, LegacyEffect]:
		for outcome in ["hit", "miss", "block"]:
			seconds = 0
			var effect: Node3D = script.new()
			world.add_child(effect)
			var points := {"source": Vector3(-2,1,0), "sources": [Vector3(-2,1,-0.5), Vector3(-2,1,0.5)], "target": Vector3(2,1,0), "radius": 0.8}
			effect.start("watergun", {"frames": 60, "impact_frame": 27}, {"show_impact": outcome == "hit", "result": "miss" if outcome == "miss" else ""}, func(): return seconds, func(): return points, func(): return true)
			effect.set_process(false)
			seconds = 0.48
			effect._process(0)
			assert(effect.emission_sources.size() == 2 and effect.cursor < 90)
			if script == SourceEffect:
				var muzzle_count := 0
				var splash_count := 0
				for i in effect.cursor:
					if i >= effect.sprite_keys.size(): continue
					if effect.sprite_keys[i] == "water_muzzle": muzzle_count += 1
					if effect.sprite_keys[i] == "water_splash": splash_count += 1
				assert(muzzle_count == 2 and splash_count == (1 if outcome == "hit" else 0))
			effect.cancel()
			await get_tree().process_frame
			await get_tree().process_frame
	var lash_counts := []
	for count in [1, 2]:
		seconds = 0
		var lash := Stage.StagedMoveEffect.new()
		world.add_child(lash)
		var sources := [Vector3(-2,1,-0.5)]
		if count == 2: sources.append(Vector3(-2,1,0.5))
		var points := {"source": sources[0], "sources": sources, "target": Vector3(2,1,0), "radius": 0.8}
		lash.start("vinewhip", {"frames": 60, "launch_frame": 10, "impact_frame": 40}, {}, func(): return seconds, func(): return points, func(): return true)
		lash.set_process(false)
		seconds = 0.62
		lash._process(0)
		lash_counts.append(lash.cursor)
		lash.cancel()
		await get_tree().process_frame
	assert(lash_counts[1] - lash_counts[0] == 12, "Each vine tip must create its own twelve-segment lash")
	var lash_widths := []
	for part in ["hand", "vines"]:
		seconds = 0
		var lash := Stage.StagedMoveEffect.new()
		world.add_child(lash)
		var points := {"source": Vector3(-2,1,0), "sources": [Vector3(-2,1,0)], "target": Vector3(2,1,0), "radius": 0.8, "attachment_part": part}
		lash.start("vinewhip", {"frames": 60, "launch_frame": 10, "impact_frame": 40}, {}, func(): return seconds, func(): return points, func(): return true)
		lash.set_process(false)
		seconds = 0.62
		lash._process(0)
		var widths := []
		for i in lash.cursor:
			if lash.pieces[i].mesh == lash.tube and lash.pieces[i].material_override == lash.edge:
				widths.append(lash.pieces[i].basis.x.length())
		# Eight approach trails precede the twelve vine segments.
		assert(widths.size() == 20)
		lash_widths.append(widths[8])
		lash.cancel()
		await get_tree().process_frame
	assert(is_equal_approx(lash_widths[1] / lash_widths[0], .008 / .045), "Native vine tips must retain their narrower extension width")
	_check_paired_sound(world)
	_check_sound_scale(world)
	_check_heart_scale(world)
	_check_sludge_trail_scale(world)
	_check_effect_start(world)
	_check_lick_window(world)
	print("MOVE_ATTACHMENTS_3D_OK transforms=true moving_bones=true forms=true lifecycle=true paired_beams=true paired_vines=true paired_sound=true single_impact=true")
	get_tree().quit()

func _check_weighted_attachments(world: Node3D) -> void:
	var upper := {"bone": "upper", "offset": [0, 0, 0.2], "weight": 1.0}
	var lower := {"bone": "lower", "offset": [0, 0, 0.2], "weight": 3.0}
	var calibrated_profiles: Dictionary = Attachments.CALIBRATED.data.profiles
	calibrated_profiles["__weighted_test"] = {
		"parts": {"mouth": [[upper, lower]]},
		"actions": {"physical_attack_2": {"mouth": [[upper]]}},
	}
	var actor := _rig(world, ["upper", "lower"])
	actor.transform = Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(2, 3, 2)), Vector3(1, 2, 3))
	var rig: Skeleton3D = actor.get_node("Rig")
	rig.set_bone_pose_position(0, Vector3(0, 2, 0))
	rig.set_bone_pose_position(1, Vector3(0, 1, 0))
	var result := Attachments.sample(actor, "__weighted_test@shiny", "ember", world)
	assert(result.sources.size() == 1, "Blended lips must emit one projectile")
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 1.25, 0.2)))
	rig.set_bone_pose_position(1, Vector3(0, 0, 0))
	result = Attachments.sample(actor, "__weighted_test", "ember", world)
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 0.5, 0.2)), "Jaw movement must update cached blended attachments")
	result = Attachments.sample(actor, "__weighted_test", "ember", world, "physical_attack_2")
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 2, 0.2)), "Action overrides must have distinct cache entries")
	var partial := _rig(world, ["upper"])
	assert(Attachments.sample(partial, "__weighted_test", "ember", world).is_empty())
	assert(not Attachments.sample(partial, "__weighted_test", "ember", world, "physical_attack_2").is_empty())
	assert(Attachments._bind(actor, [[{"bone": "upper", "offset": [0, 0], "weight": 1}]]).is_empty())
	assert(Attachments._bind(actor, [[{"bone": "upper", "offset": [0, 0, 0], "weight": 0}]]).is_empty())
	var open_mesh := MeshInstance3D.new()
	open_mesh.name = "OpenMouth"
	actor.add_child(open_mesh)
	var closed_mesh := MeshInstance3D.new()
	closed_mesh.name = "ClosedMouth"
	actor.add_child(closed_mesh)
	var open_point := upper.duplicate()
	open_point["visible_mesh"] = "OpenMouth"
	var closed_point := lower.duplicate()
	closed_point["visible_mesh"] = "ClosedMouth"
	calibrated_profiles["__visibility_test"] = {"parts":{"mouth":[[open_point], [closed_point]]}}
	closed_mesh.hide()
	var open_result := Attachments.sample(actor, "__visibility_test", "ember", world)
	assert(open_result.sources.size() == 1)
	assert(open_result.sources[0].is_equal_approx(actor.transform * Vector3(0, 2, .2)))
	open_mesh.hide()
	closed_mesh.show()
	var closed_result := Attachments.sample(actor, "__visibility_test", "ember", world)
	assert(closed_result.sources.size() == 1)
	assert(closed_result.sources[0].is_equal_approx(actor.transform * Vector3(0, 0, .2)), "Cached bindings must follow mouth-mesh switches")
	closed_mesh.hide()
	assert(Attachments.sample(actor, "__visibility_test", "ember", world).is_empty())
	open_mesh.free()
	assert(Attachments.sample(actor, "__visibility_test", "ember", world).is_empty(), "Freed visibility predicates invalidate the attachment")
	assert(Attachments._bind(actor, [[open_point]]).is_empty(), "Missing visibility mesh invalidates the attachment")
	calibrated_profiles.erase("__visibility_test")
	actor.free()
	partial.free()
	calibrated_profiles.erase("__weighted_test")

func _check_paired_sound(world: Node3D) -> void:
	for move in ["Growl", "Supersonic", "Screech", "Disarming Voice"]:
		var impact_counts := []
		var counts := []
		for count in [1, 2, 3]:
			seconds = .1
			var effect := Stage.StagedMoveEffect.new()
			world.add_child(effect)
			var sources := [Vector3(-2,1,-.5)]
			if count >= 2: sources.append(Vector3(-2,1,.5))
			if count == 3: sources.append(Vector3(-2,1.7,0))
			var points := {"source":sources[0],"sources":sources,"target":Vector3(2,1,0),"radius":.8}
			effect.start(move,{"frames":60,"launch_frame":12,"impact_frame":36},{},func(): return seconds,func(): return points,func(): return true)
			effect.set_process(false)
			assert(effect.cursor == count, "Each mouth charges at its own point")
			for i in count: assert(effect.pieces[i].position.is_equal_approx(sources[i]))
			seconds = .4
			effect._process(0)
			counts.append(effect.cursor)
			assert(effect.sound_launch_sources.size() == count)
			var transforms: Array[Transform3D] = []
			for i in effect.cursor: transforms.append(effect.pieces[i].transform)
			points.sources = []
			for source: Vector3 in sources: points.sources.append(source + Vector3(1,1,0))
			points.source = points.sources[0]
			effect._process(0)
			for i in effect.cursor:
				assert(effect.pieces[i].transform.is_equal_approx(transforms[i]), "Released rings must retain their own launch path")
			assert(not effect.impact_drawn, "No target impact before the confirmed hit")
			seconds = .65
			effect._process(0)
			var source_count := effect.cursor
			effect.hit = true
			effect._process(0)
			impact_counts.append(effect.cursor-source_count)
			effect.cancel()
			assert(effect.cancelled and not effect.visible)
		assert(counts[1] == counts[0] * 2 and counts[0] > 0, "Both heads must emit the full sound pattern")
		assert(counts[2] == counts[0] * 3, "All three heads must emit the full sound pattern")
		assert(impact_counts[0] == impact_counts[1] and impact_counts[1] == impact_counts[2], "Multiple mouths keep one target impact")
		assert(impact_counts[0] > 0 if move == "Disarming Voice" else impact_counts[0] == 0)

func _check_sound_scale(world: Node3D) -> void:
	for move: String in ["Growl", "Supersonic", "Screech", "Disarming Voice"]:
		var effects: Array = []
		var points := {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,-.5),Vector3(-2,1,.5)],"target":Vector3(2,1,0),"radius":.8}
		for scale_value: float in [1., .25]:
			seconds = .1
			var effect := Stage.StagedMoveEffect.new()
			world.add_child(effect)
			effect.start(move,{"frames":60,"launch_frame":12,"impact_frame":36,"emission_scale":scale_value},{},func(): return seconds,func(): return points,func(): return true)
			effect.set_process(false)
			effects.append(effect)
		var full: Node3D = effects[0]
		var small: Node3D = effects[1]
		assert(full.cursor == 2 and small.cursor == 2)
		for i in 2:
			assert(small.pieces[i].position.is_equal_approx(full.pieces[i].position))
			assert(small.pieces[i].scale.is_equal_approx(full.pieces[i].scale*.25), "Each mouth charge honors the reviewed size")
		assert(is_equal_approx(small._sound_wave_scale(0), .25))
		assert(is_equal_approx(small._sound_wave_scale(.175), .625))
		assert(is_equal_approx(small._sound_wave_scale(.35), 1.0))
		assert(is_equal_approx(full._sound_wave_scale(.175), 1.0))
		# Inspect one complete ring and its two strokes before the next release.
		for effect: Node3D in effects:
			effect.cursor = 0
			effect._wave_rings(points.source,.085,1.,1.,Basis.IDENTITY,Vector3.RIGHT,Basis.IDENTITY)
		assert(full.cursor > 0 and full.cursor == small.cursor)
		var wave_scale: float = small._sound_wave_scale(.085)
		for i in full.cursor:
			assert(small.pieces[i].scale.is_equal_approx(full.pieces[i].scale*wave_scale), "Sound radius and strokes expand from the reviewed outlet size")
			if full.pieces[i].mesh == full.ring:
				assert(small.pieces[i].position.is_equal_approx(full.pieces[i].position), "Size must not change the released ring path")
		seconds = .65
		for effect: Node3D in effects: effect._process(0)
		var start: int = full.cursor
		assert(start == small.cursor)
		for effect: Node3D in effects:
			effect.hit = true
			effect._process(0)
		assert(full.cursor == small.cursor)
		if move == "Disarming Voice": assert(full.cursor > start)
		else: assert(full.cursor == start)
		for i in range(start,full.cursor):
			assert(small.pieces[i].transform.is_equal_approx(full.pieces[i].transform), "Target impact keeps its original size")
		for effect: Node3D in effects: effect.free()

func _check_lick_window(world: Node3D) -> void:
	for move: String in ["Lick", "Vine Whip"]:
		var widths: Array[float] = []
		for use_window in [false,true]:
			var effect := Stage.StagedMoveEffect.new()
			world.add_child(effect)
			var timing := {"frames":60,"launch_frame":6,"impact_frame":12}
			if use_window: timing.emission_end_frame = 16.2
			seconds = 0
			effect.start(move,timing,{},func(): return seconds,func(): return {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":.8},func(): return true)
			effect.set_process(false)
			for time: float in [.2,.235,.271,.65]:
				seconds = time
				effect._process(0)
				# Eight ground streaks precede twelve attached lash segments.
				var expected := 8 if use_window and move == "Lick" and time >= .27 else 20
				assert(effect.cursor == expected,"Only the reviewed tongue extension ends early")
				if time == .235:
					var width: float = effect.pieces[8].basis.x.length()
					widths.append(width)
			effect.free()
		assert(is_equal_approx(widths[1]/widths[0],.5 if move == "Lick" else 1.0),"Tongue fades before retraction; other lashes retain their lifetime")

func _check_family_routes() -> void:
	for route: Array in [
		["brambleghast", "mudslap", "face"],
		["bramblin", "mudslap", "face"],
		["cubone", "mudslap", "muzzle"],
		["darkrai-mega", "mudslap", "face"],
		["diglett", "mudslap", "face"],
		["diglett-alola", "mudslap", "face"],
		["dugtrio", "mudslap", "face_primary"],
		["dugtrio-alola", "mudslap", "face_primary"],
		["glimmora-mega", "mudslap", "spike"],
		["golisopod", "mudslap", "face"],
		["golisopod-mega", "mudslap", "face"],
		["magnemite", "mudslap", "eye"],
		["magneton", "mudslap", "face"],
		["magnezone", "mudslap", "eye"],
		["mimikyu", "mudslap", "casting"],
		["mimikyu-busted", "mudslap", "casting"],
		["necrozma", "mudslap", "face"],
		["nosepass", "mudslap", "nose"],
		["poltchageist", "mudslap", "spirit"],
		["regice", "mudslap", "face"],
		["regieleki", "mudslap", "face"],
		["regigigas", "mudslap", "face"],
		["regirock", "mudslap", "face"],
		["registeel", "mudslap", "face"],
		["sandy-shocks", "mudslap", "eye_upper"],
		["scovillain-mega", "mudslap", "mouth_red"],
		["voltorb", "mudslap", "face"],
		["voltorb-hisui", "mudslap", "face"],
		["wo-chien", "mudslap", "face"],
		["wugtrio", "mudslap", "muzzle"],
	]:
		for identity: String in [route[0], route[0]+"@shiny"]:
			assert(Attachments.part_for(identity, route[1]) == route[2])
			assert(not Attachments.definitions_for(identity, route[2]).is_empty())
	assert(Attachments.part_for("poltchageist", "scald") == "spoon")
	assert(Attachments.part_for("scovillain-mega", "solarbeam") == "mouth_green")
	for route: Array in [["bonsly","suckerpunch","body"],["exeggutor-alola","superpower","body"],["poliwag","pound","body"],["torchic","scratch","foot"],["torchic","rocksmash","foot"],["wooper","icepunch","body"],["scrafty-mega","closecombat","body"],["scrafty-mega","dragonclaw","body"],["dragalge-mega","watergun","muzzle"],["metagross-mega","rocksmash","claw_lower_right"],["doduo","furyattack","beak_tip"],["dodrio","furyattack","beak_tip"]]:
		for identity: String in [route[0], route[0]+"@shiny"]:
			assert(Attachments.part_for(identity,route[1]) == route[2])
	assert(Attachments.part_for("scrafty","closecombat") == "hand", "Alternate forms do not change base-form routes")
	var profiles: Dictionary = Attachments.CALIBRATED.data.profiles
	profiles["__family_test"] = {"moves":{"rocksmash":"explicit"},"family_attachments":{"strikes":"family"},"attachment_overrides":{"hand":"alias","mouth":"muzzle"}}
	assert(Attachments.part_for("__family_test","rocksmash") == "explicit")
	assert(Attachments.part_for("__family_test","superpower") == "family")
	assert(Attachments.part_for("__family_test","scratch") == "alias")
	assert(Attachments.part_for("__family_test","watergun") == "muzzle")
	assert(Attachments.part_for("__family_test","tackle") == "body")
	profiles.erase("__family_test")
	profiles["__family_timing_test"] = {
		"family_actions":{"beams":"physical_attack"},
		"family_choreography":{"beams":{"action":"physical_attack","launch_fraction":.3,"impact_fraction":.5,"emission_end_fraction":.7,"emission_scale":.15}},
		"move_actions":{"hyperbeam":"special_attack"},
		"move_choreography":{"hyperbeam":{"action":"special_attack","launch_fraction":.4,"impact_fraction":.6}}}
	var available := {"physical_attack":{},"special_attack":{}}
	assert(Attachments.action_for("__family_timing_test","voltswitch",available) == "physical_attack")
	assert(Attachments.action_for("__family_timing_test@shiny","voltswitch",available) == "physical_attack")
	assert(Attachments.action_for("__family_timing_test","hyperbeam",available) == "special_attack")
	assert(Attachments.action_for("__family_timing_test","voltswitch",{"special_attack":{}}).is_empty())
	assert(Attachments.action_for("__family_timing_test","scratch",available).is_empty())
	assert(is_equal_approx(Attachments.choreography_for("__family_timing_test","voltswitch","physical_attack").emission_scale,.15))
	assert(is_equal_approx(Attachments.choreography_for("__family_timing_test","hyperbeam","special_attack").launch_fraction,.4))
	assert(Attachments.choreography_for("__family_timing_test","hyperbeam","physical_attack").is_empty(),"Explicit move spec must not fall through to family timing")
	assert(Attachments.choreography_for("__family_timing_test","voltswitch","special_attack").is_empty())
	profiles["__family_timing_test"].family_choreography.beams.launch_fraction = .8
	assert(Attachments.choreography_for("__family_timing_test","voltswitch","physical_attack").is_empty())
	profiles.erase("__family_timing_test")

func _check_effect_start(world: Node3D) -> void:
	var calibrated: Dictionary = Attachments.CALIBRATED.data.profiles
	var spec := {"action":"special_attack","launch_fraction":.4,"impact_fraction":.6,"effect_start_fraction":.2}
	calibrated["__effect_start_test"] = {"move_choreography":{"shadowball":spec}}
	assert(is_equal_approx(Attachments.choreography_for("__effect_start_test","shadowball","special_attack").effect_start_fraction,.2))
	for invalid: float in [-.1, .41, INF, NAN]:
		spec.effect_start_fraction = invalid
		assert(Attachments.choreography_for("__effect_start_test","shadowball","special_attack").is_empty())
	calibrated.erase("__effect_start_test")
	for route: Array in [[Stage.BatchFourMoveEffect,"Shadow Ball"],[Stage.StagedMoveEffect,"Hyper Beam"]]:
		for start_fraction: float in [0., .2]:
			seconds = 0
			var effect: Node3D = route[0].new()
			world.add_child(effect)
			var timing := {"frames":60,"launch_frame":24,"impact_frame":36}
			if start_fraction > 0: timing.effect_start_frame = start_fraction*60
			effect.start(route[1],timing,{},func(): return seconds,func(): return {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":.8},func(): return true)
			effect.set_process(false)
			seconds = .1
			effect._process(0)
			assert((effect.cursor == 0) == (start_fraction > 0),"Delayed visuals must remain hidden before the selected native pose")
			seconds = .3
			effect._process(0)
			assert(effect.cursor > 0)
			assert(is_equal_approx(effect.charge_progress(),.5 if start_fraction > 0 else .75))
			assert(is_equal_approx(effect.launch,.4) and is_equal_approx(effect.impact,.6),"Delaying preparation must preserve release and impact")
			effect.free()
		seconds = 0
		var cancelled: Node3D = route[0].new()
		world.add_child(cancelled)
		cancelled.start(route[1],{"frames":60,"launch_frame":24,"impact_frame":36,"effect_start_frame":12},{},func(): return seconds,func(): return {},func(): return false)
		assert(cancelled.done and cancelled.cancelled,"Cancellation remains active before delayed visuals begin")

func _check_sludge_trail_scale(world: Node3D) -> void:
	var effects: Array = []
	var from := Vector3(-2,1,0)
	var to := Vector3(2,1,0)
	for scale_value: float in [1., .12]:
		seconds = 0
		var effect := Stage.BatchFourMoveEffect.new()
		world.add_child(effect)
		var timing := {"frames":60,"launch_frame":12,"impact_frame":36,"projectile_arc_height":.1}
		if scale_value != 1.: timing.emission_scale = scale_value
		effect.start("Sludge Bomb",timing,{},func(): return seconds,func(): return {"source":from,"sources":[from],"target":to,"radius":.8},func(): return true)
		effect.set_process(false)
		effect._build_surface()
		effect.elapsed = .2
		effects.append(effect)
	for travel: float in [0., .5]:
		for effect: Node3D in effects:
			effect.cursor = 0
			effect._draw_orb(from,to,travel,0.,Basis.IDENTITY,Basis.IDENTITY)
			assert(effect.cursor == 6)
			for i in 5:
				var p := maxf(travel-float(i+1)*.035,0.)
				var path := from.lerp(to,p)+Vector3.UP*sin(p*PI)*.1
				var expected: Vector3 = path-Vector3.UP*float(i)*.035*effect.emission_scale
				assert(effect.pieces[i+1].position.is_equal_approx(expected),"Sludge droplets must retain the arc and scale their downward offset at small emitters")
		for i in 6:
			assert(effects[1].pieces[i].scale.is_equal_approx(effects[0].pieces[i].scale*.12))
	for effect: Node3D in effects: effect.free()

func _check_heart_scale(world: Node3D) -> void:
	var effects: Array = []
	var points := {"source":Vector3(-2,1,0),"sources":[Vector3(-2,1,0)],"target":Vector3(2,1,0),"radius":.8}
	for scale_value: float in [1., .25]:
		seconds = 0
		var effect := Stage.StagedMoveEffect.new()
		world.add_child(effect)
		var timing := {"frames":60,"launch_frame":12,"impact_frame":36}
		if scale_value != 1.: timing.emission_scale = scale_value
		effect.start("Draining Kiss",timing,{},func(): return seconds,func(): return points,func(): return true)
		effect.set_process(false)
		effects.append(effect)
	var full: Node3D = effects[0]
	var small: Node3D = effects[1]
	for travel: float in [0., 1.3]:
		for effect: Node3D in effects:
			effect.cursor = 0
			effect._status_stage(travel,0.,1.,Basis.IDENTITY,Vector3.RIGHT,Basis.IDENTITY)
		assert(full.cursor == 20 and small.cursor == 20)
		var ratio := .25 if travel == 0. else 1.
		var center: Vector3 = full.origin if travel == 0. else full.aim
		for i in full.cursor:
			assert(small.pieces[i].scale.is_equal_approx(full.pieces[i].scale*ratio), "Heart geometry and sparkle fit the release point and grow during travel")
			assert((small.pieces[i].position-center).is_equal_approx((full.pieces[i].position-center)*ratio))
	for effect: Node3D in effects: effect.free()

func _check_reviewed_hand_routes() -> void:
	var bones := {"ampharos-mega":"right_arm_02", "kangaskhan":"right_hand_a", "kangaskhan-mega":"right_hand_a", "marill":"right_arm_02", "spinda":"RHand", "pichu":"right_arm", "plusle":"right_arm_02", "minun":"right_arm_02", "dusknoir":"right_hand_02"}
	for species: String in bones:
		for identity: String in [species, species+"@shiny"]:
			assert(Attachments.part_for(identity, "thunderpunch") == "hand")
			var hand := Attachments.definitions_for(identity, "hand")
			assert(hand.size() == 1 and hand[0].size() == 1)
			assert(hand[0][0].bone == bones[species])
			assert(not Attachments.definitions_for(identity, "left_hand").is_empty())
			assert(Attachments.part_for(identity, "lowkick") == "foot", "Hand calibration preserves foot routing")
			assert(Attachments.part_for(identity, "flamethrower") == "mouth", "Hand calibration preserves mouth routing")
	for identity: String in ["spinda", "spinda@shiny"]:
		assert(Attachments.action_for(identity, "drainpunch", {"physical_attack_2":{}}) == "physical_attack_2")
		assert(Attachments.action_for(identity, "firepunch", {"physical_attack":{}}).is_empty())
		assert(Attachments.action_for(identity, "lowkick", {"physical_attack_2":{}}).is_empty(), "Hand clip choice excludes kicks")

func _check_catalog_routes() -> void:
	for suffix: String in ["", "@shiny"]:
		for route: Array in [["aegislash-blade","closecombat","blade_tip"], ["aegislash-shield","closecombat","shield_front"], ["arbok","rocksmash","body"], ["tinkaton","rocksmash","hammer"], ["scyther","wingattack","wing"], ["scyther","closecombat","hand"], ["zygarde-mega","dragonbreath","cannon"], ["zygarde-mega","bite","face"], ["mawile-mega","bite","jaw"], ["cetitan","icebeam","muzzle"], ["sinistea","suckerpunch","hand"]]:
			var identity: String = route[0] + suffix
			assert(Attachments.part_for(identity, route[1]) == route[2])
			if route[2] != "body": assert(not Attachments.definitions_for(identity, route[2]).is_empty())
		for species: String in ["scyther", "tinkaton", "calyrex-ice", "calyrex-shadow", "iron-hands", "annihilape"]:
			for move_key: String in ["lowkick", "doublekick", "highjumpkick"]:
				assert(Attachments.part_for(species + suffix, move_key) == "foot", "Hand aliases must preserve explicit kick origins")
		assert(Attachments.action_for("scyther" + suffix,"wingattack",{"physical_attack_2":{}}) == "physical_attack_2")
		for move_key: String in ["astonish", "suckerpunch"]:
			var identity := "sinistea" + suffix
			assert(Attachments.action_for(identity,move_key,{"physical_attack":{}}) == "physical_attack")
			assert(Attachments.choreography_for(identity,move_key,"physical_attack").effect_start_fraction >= .3, "The hand must emerge before its effect")
		for move_key: String in ["hyperbeam", "icebeam", "growl"]:
			assert(Attachments.action_for("cetitan" + suffix,move_key,{"physical_attack":{}}) == "physical_attack")
			assert(Attachments.choreography_for("cetitan" + suffix,move_key,"physical_attack").launch_fraction < .25)
	assert(Attachments.definitions_for("scyther","wing") != Attachments.definitions_for("scyther","hand"))
	assert(Attachments.definitions_for("mawile-mega","jaw") != Attachments.definitions_for("mawile-mega","jaw_other"))
	for suffix: String in ["", "@shiny"]:
		for route: Array in [["cramorant", "furyattack", "mouth"], ["cramorant", "superpower", "hand"], ["deoxys", "hyperbeam", "core"], ["deoxys", "drainpunch", "hand"], ["deoxys", "lowkick", "foot"], ["minior", "hyperbeam", "body"], ["togedemaru", "hyperbeam", "mouth"], ["togedemaru", "voltswitch", "body"], ["hawlucha-mega", "hyperbeam", "mouth"], ["hawlucha-mega", "highjumpkick", "foot"]]:
			assert(Attachments.part_for(route[0] + suffix, route[1]) == route[2])
			assert(not Attachments.definitions_for(route[0] + suffix, route[2]).is_empty())
		assert(Attachments.action_for("togedemaru" + suffix, "hyperbeam", {"physical_attack": {}}) == "physical_attack")
		assert(Attachments.choreography_for("hawlucha-mega" + suffix, "hyperbeam", "special_attack").emission_end_fraction <= .5)
