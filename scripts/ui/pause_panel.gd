class_name PausePanelScreen
extends Control
## Pause overlay. The gameplay state machine owns pause semantics; this panel
## only presents the actions and forwards signals.

signal resume_pressed
signal restart_pressed
signal menu_pressed

@onready var panel: PanelContainer = %Panel
@onready var score_value: Label = %ScoreValue
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())


func open(current_score: int) -> void:
	score_value.text = GameConfig.format_score(current_score)
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()


func close() -> void:
	visible = false
