extends "res://docs/forum-guides/all-guides/capture/base.gd"

# Native service controls with public, illustrative fixtures. No service calls.
func setup() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	out = args[0]
	assert(not root.get_node("AuthService").is_authenticated())
	root.get_node("LocalizationManager").set_locale("en")
	view = SubViewport.new()
	view.size = Vector2i(1280, 960)
	view.gui_embed_subwindows = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)

func _run() -> void:
	await setup()
	var training = load("res://scenes/interface/daycare_popup.tscn").instantiate()
	view.add_child(training)
	training._apply_state({"pokemon": [{"pokemon": {"ownedPokemonId": 12, "species": "Pikachu", "level": 10, "experience": 1000, "evs": {}, "storedEvs": {}}, "location": {"type": "party", "partySlot": 0}}], "jobs": [], "money": 100000, "daycareLevelCap": 100})
	training.level_input.value = 100
	training.ev_check.button_pressed = true
	for stat in ["atk", "spe"]:
		training.ev_inputs[stat].value = 252
	training.ev_inputs["hp"].value = 6
	training._show_quote({"previewId": "illustrative", "price": 75950, "requiredExperience": 999000, "requiredEvs": 510, "durationSeconds": 6354, "expDurationSeconds": 6354, "evDurationSeconds": 983, "expSelected": true, "evSelected": true, "startLevel": 10, "targetLevel": 100, "targetEvs": {"atk": 252, "spe": 252, "hp": 6}, "priceBreakdown": {"start": 500, "experience": 49950, "evs": 25500}})
	training._set_busy(false)
	await shot(0, "01-training", training, "Illustrative training setup and calculated cost.", "## Offline EXP and EV training")
	var jobs: Array = []
	for i in range(2):
		jobs.append({"id": "illustrative-%s" % i, "bed": i, "pokemon": {"speciesId": "magikarp" if i == 0 else "eevee", "species": "Magikarp" if i == 0 else "Eevee", "shiny": false}, "remainingSeconds": 0 if i == 0 else 900, "plan": {"targetLevel": 30, "expSelected": true, "evSelected": true, "durationSeconds": 1800, "targetEvs": {"atk": 252, "spe": 252}}})
	training._apply_state({"pokemon": [], "jobs": jobs, "money": 100000, "daycareLevelCap": 100})
	training._set_busy(false)
	training.tabs.current_tab = 1
	training.set_process(false)
	await shot(0, "02-training-places", training, "Illustrative finished and active jobs; completed training can be collected.", "### Up to six Pokémon, including while offline")
	training.hide()
	var aethering = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	view.add_child(aethering)
	var left := {"hp": 31, "atk": 31, "def": 15, "spa": 0, "spd": 22, "spe": 22}
	var right := {"hp": 31, "atk": 12, "def": 31, "spa": 0, "spd": 12, "spe": 12}
	aethering.recipient = _entry(1, left)
	aethering.donor = _entry(2, right)
	aethering.candidates = [aethering.recipient, aethering.donor]
	aethering.resources_ready = true
	aethering.recipient_lock = "atk"
	aethering.donor_lock = "def"
	aethering.wing_availability = {"muscle-wing": 1, "resist-wing": 1}
	root.get_node("PlayerSave").money = 100000
	var stats := {}
	for stat in left:
		var mode := "recipient_lock" if stat == "atk" else "donor_lock" if stat == "def" else "equal" if left[stat] == right[stat] else "reroll"
		stats[stat] = {"mode": mode, "recipientIV": left[stat], "donorIV": right[stat], "guaranteedIV": right[stat] if stat == "def" else null if mode == "reroll" else left[stat]}
	aethering.plan = {"previewId": "11111111-1111-4111-8111-111111111111", "expiresAt": "2026-10-14T14:10:00Z", "shinyDonor": false, "requiredWings": [{"itemId": "muscle-wing", "quantity": 1}, {"itemId": "resist-wing", "quantity": 1}], "stats": stats}
	aethering._render()
	aethering.show()
	await settle()
	aethering.scroll.scroll_vertical = 120
	await shot(0, "03-aethering", aethering, "Illustrative IV comparison: keep ATK, copy DEF and reroll the unprotected differences.", "## Aethering: change IVs")
	aethering.hide()
	var nature = load("res://scenes/interface/nature_specialist_popup.tscn").instantiate()
	view.add_child(nature)
	nature._apply_state({"pokemon": [{"pokemon": {"ownedPokemonId": 123, "level": 50, "species": "Pikachu", "nature": "Hardy", "shiny": true, "ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}}, "price": 2500000, "rarity": "uncommon", "eligible": true, "location": {"type": "party", "partySlot": 0}}], "natures": [{"name": "Hardy"}, {"name": "Jolly", "boosted_stat": "spe", "lowered_stat": "spa"}], "serverTime": "2026-10-14T14:00:00+00:00", "nextAvailableAt": null, "money": 10000000})
	nature.nature_select.select(1)
	nature._show_quote({"previewId": "illustrative", "originalNature": "Hardy", "oldNature": "Hardy", "newNature": "Jolly", "price": 2500000, "oldStats": {"hp": 110, "atk": 75, "def": 60, "spa": 70, "spd": 70, "spe": 110}, "newStats": {"hp": 110, "atk": 75, "def": 60, "spa": 63, "spd": 70, "spe": 121}})
	nature._set_busy(false)
	await shot(0, "04-nature", nature, "Illustrative Nature-effect quote; original Hardy Nature remains recorded.", "## Nature Specialist: choose a stat effect")
	assert(not root.get_node("AuthService").is_authenticated())
	finish("daycare")

func _entry(id: int, ivs: Dictionary) -> Dictionary:
	return {"pokemonId": id, "pokemon": {"speciesId": "eevee", "species": "Eevee", "level": 30, "ivs": ivs}, "location": {"type": "party", "partySlot": id - 1}, "eggGroups": ["ground"], "recipientAllowed": true, "donorAllowed": true, "donorBlockedReason": null, "shiny": false}
