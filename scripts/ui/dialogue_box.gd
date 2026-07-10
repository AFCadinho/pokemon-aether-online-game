extends Control

signal dialogue_finished

@onready var name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NPCName
@onready var portrait_panel: Panel = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/PortraitPanel
@onready var npc_sprite: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/PortraitPanel/PortraitMargin/NPCSprite
@onready var text_label: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/RichTextLabel

var default_mugshot: Texture2D

var is_open := false
var just_started := false

var lines: Array = []
var current_line_index := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_mugshot = npc_sprite.texture
	hide_dialogue()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not is_open:
		return
	
	if just_started:
		just_started = false
		return
		
	if Input.is_action_just_pressed("interact"):
		current_line_index += 1
		
		if current_line_index >= lines.size():
			hide_dialogue()
		else:
			show_current_line()
	
func start_dialogue(new_lines: Array, speaker_name := "", mugshot: Texture2D = null, show_mugshot := true) -> void:
	lines = new_lines
	name_label.text = speaker_name
	name_label.visible = speaker_name != ""
	portrait_panel.visible = show_mugshot
	if show_mugshot:
		npc_sprite.texture = mugshot if mugshot != null else default_mugshot
	else:
		npc_sprite.texture = null
	
	current_line_index = 0
	is_open = true
	just_started = true
	visible = true
	
	GameState.lock_input()
	
	show_current_line()
	
func show_current_line() -> void:
	text_label.text = str(lines[current_line_index])
		
	
func hide_dialogue() -> void:
	var was_open := is_open
	
	is_open = false
	just_started = false
	visible = false
	lines = []
	current_line_index = 0
	
	GameState.unlock_input()
	
	if was_open:
		dialogue_finished.emit()
	
