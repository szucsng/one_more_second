class_name GameHUD
extends Control
## In-game HUD: score, best, pause and the one-time control hint.

signal pause_pressed

@onready var score_box: VBoxContainer = $ScoreBox
@onready var best_box: VBoxContainer = $BestBox
@onready var score_label: Label = %ScoreLabel
@onready var best_value: Label = %BestValue
@onready var pause_button: Button = %PauseButton
@onready var hint_label: Label = %HintLabel
@onready var intro_label: Label = %IntroLabel

var _score_tween: Tween
var _intro_tween: Tween


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	set_best(SaveManager.get_best_score())
	score_label.text = "0"
	hint_label.modulate.a = 0.0
	intro_label.modulate.a = 0.0
	var insets := Platform.get_safe_insets()
	var top_offset := int(insets["top"])
	if top_offset > 0:
		for box in [pause_button, score_box, best_box]:
			box.offset_top += top_offset
			box.offset_bottom += top_offset
	var bottom_offset := int(insets["bottom"])
	if bottom_offset > 0:
		hint_label.offset_top -= bottom_offset
		hint_label.offset_bottom -= bottom_offset


func set_best(value: int) -> void:
	best_value.text = GameConfig.format_score(value)


func set_score(value: int, pulse: bool = true) -> void:
	score_label.text = GameConfig.format_score(value)
	if not pulse:
		return
	score_label.pivot_offset = score_label.size * 0.5
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	score_label.scale = Vector2(1.12, 1.12)
	_score_tween = create_tween()
	_score_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.24)


func play_intro() -> void:
	score_label.text = "0"
	score_label.scale = Vector2.ONE
	hint_label.text = "TAP TO SWITCH LANE"
	hint_label.modulate.a = 1.0
	intro_label.text = "GET READY"
	intro_label.modulate.a = 0.0
	intro_label.scale = Vector2(0.96, 0.96)
	intro_label.pivot_offset = intro_label.size * 0.5
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(false)
	_intro_tween.tween_property(intro_label, "modulate:a", 1.0, 0.18)
	_intro_tween.parallel().tween_property(intro_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD)
	_intro_tween.tween_interval(0.65)
	_intro_tween.tween_property(intro_label, "modulate:a", 0.0, 0.35)
	_intro_tween.tween_property(hint_label, "modulate:a", 0.0, 0.7).set_delay(1.6)


func hide_hint() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	var tween := create_tween()
	tween.tween_property(hint_label, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(intro_label, "modulate:a", 0.0, 0.18)


func set_pause_enabled(enabled: bool) -> void:
	pause_button.disabled = not enabled
