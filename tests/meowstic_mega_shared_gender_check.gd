extends SceneTree

const ReviewedModels = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const OnDemandModels = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const BattlePresenter = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const PokedexPreview = preload("res://scripts/ui/pokedex_model_preview.gd")


func _init() -> void:
	var normal: Dictionary = ReviewedModels.DATA.data.models["meowstic-m-mega"]
	var shiny: Dictionary = ReviewedModels.DATA.data.models["meowstic-m-mega@shiny"]
	assert(ReviewedModels.canonical_identity("meowstic-f-mega") == "meowstic-m-mega")
	assert(ReviewedModels.canonical_identity("meowstic-f-mega@shiny") == "meowstic-m-mega@shiny")
	assert(ReviewedModels.aliases_for("meowstic-m-mega") == ["meowstic-f-mega"])
	assert(ReviewedModels.aliases_for("meowstic-m-mega@shiny") == ["meowstic-f-mega@shiny"])
	assert(OnDemandModels.asset_id_for_identity("meowstic-f-mega") == "pokemon_3d:meowstic-m:mega")
	assert(OnDemandModels.asset_id_for_identity("meowstic-f-mega@shiny") == "pokemon_3d:meowstic-m:mega")
	assert(ReviewedModels.supports("meowstic-f-mega"))
	assert(ReviewedModels.supports("meowstic-f-mega@shiny"))
	var entries := {"meowstic-m-mega": {"species": "meowstic-m-mega", "variant": "normal", "runtime_sha256": normal.sha256, "runtime_path": "shared.scn"},
		"meowstic-m-mega@shiny": {"species": "meowstic-m-mega", "variant": "shiny", "runtime_sha256": shiny.sha256, "runtime_path": "shared-shiny.scn"}}
	ReviewedModels.add_alias_entries(entries)
	assert(entries["meowstic-f-mega"].runtime_sha256 == normal.sha256)
	assert(entries["meowstic-f-mega"].runtime_path == "shared.scn")
	assert(entries["meowstic-f-mega@shiny"].runtime_sha256 == shiny.sha256)
	assert(entries["meowstic-f-mega@shiny"].runtime_path == "shared-shiny.scn")
	assert(ReviewedModels.resolve("meowstic-f-mega", normal.sha256) ==
		ReviewedModels.resolve("meowstic-m-mega", normal.sha256))
	assert(ReviewedModels.resolve("meowstic-f-mega@shiny", shiny.sha256) ==
		ReviewedModels.resolve("meowstic-m-mega@shiny", shiny.sha256))
	print("MEOWSTIC_MEGA_SHARED_GENDER_OK normal=true shiny=true")
	quit()
