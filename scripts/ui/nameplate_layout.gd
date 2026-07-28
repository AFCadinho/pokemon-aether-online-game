extends RefCounted

const NAMEPLATE_CENTER_X := 82.0
const NAMEPLATE_NAME_HEIGHT := 30.0
const NAMEPLATE_STACK_BOTTOM := 63.0
const NAMEPLATE_CARD_VERTICAL_INSET := 2.0
const NAMEPLATE_CARD_HORIZONTAL_PADDING := 5.0
const GUILD_EMBLEM_DISPLAY_SIZE := 24.0
const GUILD_EMBLEM_NAME_GAP := 3.0


static func calculate_name_card(name_width: float, has_guild_emblem: bool) -> Dictionary:
	var emblem_slot_width := (
		GUILD_EMBLEM_DISPLAY_SIZE + GUILD_EMBLEM_NAME_GAP
		if has_guild_emblem
		else 0.0
	)
	var card_width := (
		name_width
		+ emblem_slot_width
		+ (NAMEPLATE_CARD_HORIZONTAL_PADDING * 2.0)
	)
	var card_left := NAMEPLATE_CENTER_X - (card_width * 0.5)
	var content_left := card_left + NAMEPLATE_CARD_HORIZONTAL_PADDING
	var label_top := NAMEPLATE_STACK_BOTTOM - NAMEPLATE_NAME_HEIGHT
	var label_rect := Rect2(
		Vector2(content_left + emblem_slot_width, label_top),
		Vector2(name_width, NAMEPLATE_NAME_HEIGHT)
	)
	var background_rect := Rect2(
		Vector2(card_left, label_top + NAMEPLATE_CARD_VERTICAL_INSET),
		Vector2(
			card_width,
			NAMEPLATE_NAME_HEIGHT - (NAMEPLATE_CARD_VERTICAL_INSET * 2.0)
		)
	)
	var emblem_rect := Rect2()
	if has_guild_emblem:
		emblem_rect = Rect2(
			Vector2(
				content_left,
				label_top + ((NAMEPLATE_NAME_HEIGHT - GUILD_EMBLEM_DISPLAY_SIZE) * 0.5)
			),
			Vector2(GUILD_EMBLEM_DISPLAY_SIZE, GUILD_EMBLEM_DISPLAY_SIZE)
		)
	return {
		"backgroundRect": background_rect,
		"labelRect": label_rect,
		"emblemRect": emblem_rect,
	}
