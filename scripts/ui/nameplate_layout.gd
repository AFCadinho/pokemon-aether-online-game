extends RefCounted

const NAMEPLATE_CENTER_X := 82.0
const NAMEPLATE_STACK_BOTTOM := 63.0
const NAMEPLATE_CARD_VERTICAL_PADDING := 2.0
const NAMEPLATE_CARD_HORIZONTAL_PADDING := 5.0
const GUILD_EMBLEM_DISPLAY_SIZE := 24.0
const GUILD_EMBLEM_NAME_GAP := 1.0


static func calculate_name_card(name_size: Vector2, has_guild_emblem: bool) -> Dictionary:
	var emblem_slot_width := (
		GUILD_EMBLEM_DISPLAY_SIZE + GUILD_EMBLEM_NAME_GAP
		if has_guild_emblem
		else 0.0
	)
	var card_width := (
		name_size.x
		+ emblem_slot_width
		+ (NAMEPLATE_CARD_HORIZONTAL_PADDING * 2.0)
	)
	var content_height := maxf(
		name_size.y,
		GUILD_EMBLEM_DISPLAY_SIZE if has_guild_emblem else 0.0
	)
	var card_height := content_height + (NAMEPLATE_CARD_VERTICAL_PADDING * 2.0)
	var card_left := NAMEPLATE_CENTER_X - (card_width * 0.5)
	var card_top := NAMEPLATE_STACK_BOTTOM - card_height
	var content_left := card_left + NAMEPLATE_CARD_HORIZONTAL_PADDING
	var label_rect := Rect2(
		Vector2(
			content_left + emblem_slot_width,
			card_top + NAMEPLATE_CARD_VERTICAL_PADDING + ((content_height - name_size.y) * 0.5)
		),
		name_size
	)
	var background_rect := Rect2(
		Vector2(card_left, card_top),
		Vector2(card_width, card_height)
	)
	var emblem_rect := Rect2()
	if has_guild_emblem:
		emblem_rect = Rect2(
			Vector2(
				content_left,
				card_top + NAMEPLATE_CARD_VERTICAL_PADDING
			),
			Vector2(GUILD_EMBLEM_DISPLAY_SIZE, GUILD_EMBLEM_DISPLAY_SIZE)
		)
	return {
		"backgroundRect": background_rect,
		"labelRect": label_rect,
		"emblemRect": emblem_rect,
	}
