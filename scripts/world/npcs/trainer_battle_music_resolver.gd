class_name TrainerBattleMusicResolver
extends RefCounted

const RIVAL_BATTLE_MUSIC_ID := "battle.rival.blue_green_remix_zame"


static func resolve_track_id(metadata: Dictionary) -> String:
	var trainer_class := str(
		metadata.get("trainer_class", metadata.get("trainerClass", ""))
	).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	var trainer_id := str(metadata.get("id", "")).strip_edges().to_lower()
	var trainer_name := str(metadata.get("name", "")).strip_edges().to_lower()
	# Gary/Blue is represented by the reusable trainer_class_blue profile in
	# overworld scenes, while other rival content may use trainer_class_rival.
	if (
		trainer_class in ["rival", "blue"]
		or trainer_id.contains("gary")
		or trainer_name == "gary oak"
	):
		return RIVAL_BATTLE_MUSIC_ID
	return ""
