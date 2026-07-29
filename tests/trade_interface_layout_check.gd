extends SceneTree

const WORKSPACE_PATH := "res://scripts/ui/trade_workspace.gd"
const INVITATION_PATH := "res://scripts/ui/trade_invitation_dialog.gd"
const TRADE_ICON_PATH := "res://assets/ui/player_trade.svg"

var failures := 0


func _init() -> void:
	var workspace := FileAccess.get_file_as_string(WORKSPACE_PATH)
	var invitation := FileAccess.get_file_as_string(INVITATION_PATH)

	_check(FileAccess.file_exists(TRADE_ICON_PATH), "Trade flow has a dedicated exchange icon")
	_check(workspace.contains('const TRADE_ICON: Texture2D = preload("res://assets/ui/player_trade.svg")'), "Trade workspace uses the exchange icon")
	_check(invitation.contains('const TRADE_ICON: Texture2D = preload("res://assets/ui/player_trade.svg")'), "Trade request uses the exchange icon")
	_check(workspace.contains("const DESIRED_WINDOW_SIZE := Vector2i(1120, 680)"), "Trade workspace has room for side-by-side offers")
	_check(workspace.contains('"ui.trade.title"'), "Workspace has a localized player-facing title")
	_check(workspace.contains('"ui.trade.subtitle"'), "Workspace explains the complete trade flow through localization")
	_check(workspace.contains('phase_chip.name = "TradePhaseChip"'), "Trade phase has a dedicated status chip")
	_check(workspace.contains('columns.name = "OfferColumns"'), "Both offers remain directly comparable")
	_check(workspace.contains('"ui.trade.offer.yours"') and workspace.contains('"ui.trade.offer.theirs"'), "Localized offer ownership remains unambiguous")
	_check(workspace.contains('"ui.trade.ready_indicator"'), "Localized readiness is visible per trainer")
	_check(workspace.contains('"ui.trade.offer.pokemon_drag"'), "Local Pokémon offer explains drag and drop through localization")
	_check(workspace.contains("func _render_empty_offer_slot("), "Empty Pokémon offer slots retain structure")
	_check(workspace.contains('"ui.trade.slot.drop" if accepts_drop else "ui.trade.slot.empty"'), "Only local offer slots invite localized drops")
	_check(workspace.contains("func _render_empty_item_offer("), "Empty item offers remain explicit")
	_check(workspace.contains('action_panel.name = "TradeActionBar"'), "Offer actions share a dedicated action bar")
	_check(workspace.contains('"ui.trade.ready"'), "Localized readiness action is explicit")
	_check(workspace.contains('"ui.trade.items.title"'), "Item selection has a localized task-oriented title")
	_check(workspace.contains('"ui.trade.items.search"'), "Item selector supports localized scalable search")
	_check(workspace.contains('"ui.trade.items.owned"'), "Item rows separate localized identity and owned quantity")
	_check(workspace.contains('review_banner.name = "LockedReviewBanner"'), "Final review has a visible locked state")
	_check(workspace.contains('"ui.trade.review.give"'), "Final review clearly labels outgoing assets")
	_check(workspace.contains('"ui.trade.review.receive"'), "Final review clearly labels incoming assets")
	_check(workspace.contains('"ui.trade.review.changed"'), "Final review explains why offers are locked")
	_check(workspace.contains('"ui.trade.review.tooltip"'), "Trade safety is localized without technical verification terms")
	_check(workspace.contains('confirmation_label.text = ('), "Final confirmation includes a dedicated safety message")
	_check(workspace.contains("service.replace_offer("), "Workspace revamp preserves authoritative offer replacement")
	_check(workspace.contains("service.confirm_trade("), "Workspace revamp preserves locked confirmation")
	_check(workspace.contains("service.leave_trade("), "Workspace revamp preserves authoritative trade cancellation")
	_check(invitation.contains("const DIALOG_SIZE := Vector2i(510, 300)"), "Trade request has a readable compact layout")
	_check(invitation.contains('"ui.trade.invitation.title"'), "Invitation uses concise localized player-facing language")
	_check(invitation.contains('"ui.trade.invitation.subtitle"'), "Invitation establishes its localized scope")
	_check(invitation.contains('"ui.trade.invitation.safety"'), "Invitation explains the confirmation safeguard")
	_check(invitation.contains('"ui.trade.invitation.accept"'), "Invitation primary action is localized and unambiguous")
	_check(invitation.contains('close_button.text = "×"'), "Invitation uses compact custom chrome")
	_check(not invitation.contains("grab_focus()"), "Trade requests cannot become stale Spacebar targets")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
