class_name TrainerBattleMusicResolver
extends RefCounted

const RIVAL_BATTLE_MUSIC_ID := "battle.rival.blue_green_remix_zame"


static func resolve_track_id(metadata: Dictionary) -> String:
	var trainer_class := str(
		metadata.get("trainer_class", metadata.get("trainerClass", ""))
	).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if trainer_class == "rival":
		return RIVAL_BATTLE_MUSIC_ID
	return ""
