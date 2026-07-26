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
	_check(workspace.contains('heading.text = "Player Trade"'), "Workspace has a clear player-facing title")
	_check(workspace.contains('subtitle.text = "Build both offers, lock them, then confirm the exact exchange"'), "Workspace explains the complete trade flow")
	_check(workspace.contains('phase_chip.name = "TradePhaseChip"'), "Trade phase has a dedicated status chip")
	_check(workspace.contains('columns.name = "OfferColumns"'), "Both offers remain directly comparable")
	_check(workspace.contains('side_caption.text = "YOUR OFFER"') and workspace.contains('"THEIR OFFER"'), "Offer ownership remains unambiguous")
	_check(workspace.contains('ready_indicator.text = "●  READY"'), "Readiness is visible per trainer")
	_check(workspace.contains('pokemon_caption.text = "POKÉMON  ·  DRAG FROM YOUR PARTY"'), "Local Pokémon offer explains drag and drop")
	_check(workspace.contains("func _render_empty_offer_slot("), "Empty Pokémon offer slots retain structure")
	_check(workspace.contains('hint.text = "DROP" if accepts_drop else "EMPTY"'), "Only local offer slots invite drops")
	_check(workspace.contains("func _render_empty_item_offer("), "Empty item offers remain explicit")
	_check(workspace.contains('action_panel.name = "TradeActionBar"'), "Offer actions share a dedicated action bar")
	_check(workspace.contains('ready_button.text = "Ready Offer"'), "Readiness action is explicit")
	_check(workspace.contains('heading.text = "Add Items to Offer"'), "Item selection has a task-oriented title")
	_check(workspace.contains('placeholder_text = "Search tradable items by name or category"'), "Item selector supports scalable search")
	_check(workspace.contains('item_meta.text = "%s  ·  %d owned"'), "Item rows separate identity and owned quantity")
	_check(workspace.contains('review_banner.name = "LockedReviewBanner"'), "Final review has a visible locked state")
	_check(workspace.contains('review_give_list = _section(review_columns, "YOU GIVE")'), "Final review clearly labels outgoing assets")
	_check(workspace.contains('review_receive_list = _section(review_columns, "YOU RECEIVE")'), "Final review clearly labels incoming assets")
	_check(workspace.contains('review_trust_label.text = "Offers locked · Any change requires both trainers to review again"'), "Final review explains why offers are locked")
	_check(workspace.contains('review_trust_label.tooltip_text = "The offers are locked. If either trainer changes anything, both trainers must check the trade again."'), "Trade safety is explained without technical verification terms")
	_check(workspace.contains('confirmation_label.text = ('), "Final confirmation includes a dedicated safety message")
	_check(workspace.contains("service.replace_offer("), "Workspace revamp preserves authoritative offer replacement")
	_check(workspace.contains("service.confirm_trade("), "Workspace revamp preserves locked confirmation")
	_check(workspace.contains("service.leave_trade("), "Workspace revamp preserves authoritative trade cancellation")
	_check(invitation.contains("const DIALOG_SIZE := Vector2i(510, 300)"), "Trade request has a readable compact layout")
	_check(invitation.contains('window_title.text = "Trade Request"'), "Invitation uses concise player-facing language")
	_check(invitation.contains('window_subtitle.text = "Secure player-to-player exchange"'), "Invitation establishes its scope")
	_check(invitation.contains('safety_label.text = "Nothing is exchanged until both trainers confirm the final review."'), "Invitation explains the confirmation safeguard")
	_check(invitation.contains('accept_button.text = "Accept Trade"'), "Invitation primary action is unambiguous")
	_check(invitation.contains('close_button.text = "×"'), "Invitation uses compact custom chrome")
	_check(not invitation.contains("grab_focus()"), "Trade requests cannot become stale Spacebar targets")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
