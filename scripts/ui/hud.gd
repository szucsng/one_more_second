class_name GameHUD
extends Control
## In-game HUD: score, combo multiplier, daily progress, pause and feedback.

signal pause_pressed

@onready var top_fade: TextureRect = $TopFade
@onready var score_box: VBoxContainer = $ScoreBox
@onready var best_box: VBoxContainer = $BestBox
@onready var score_label: Label = %ScoreLabel
@onready var best_value: Label = %BestValue
@onready var daily_value: Label = %DailyValue
@onready var pause_button: Button = %PauseButton
@onready var hint_label: Label = %HintLabel
@onready var intro_label: Label = %IntroLabel
@onready var combo_chip: PanelContainer = %ComboChip
@onready var combo_value: Label = %ComboValue
@onready var multiplier_label: Label = %Multiplier
@onready var combo_bar: ProgressBar = %ComboBar
@onready var combo_milestone_label: Label = %ComboMilestoneLabel
@onready var perfect_label: Label = %PerfectLabel
@onready var challenge_toast: PanelContainer = %ChallengeToast
@onready var challenge_toast_label: Label = %ChallengeToastLabel
@onready var recovery_label: Label = %RecoveryLabel

var _score_tween: Tween
var _intro_tween: Tween
var _combo_tween: Tween
var _milestone_tween: Tween
var _perfect_tween: Tween
var _challenge_tween: Tween
var _recovery_tween: Tween


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	Challenges.progress_changed.connect(_refresh_daily)
	_build_top_fade()
	set_best(SaveManager.get_best_score())
	score_label.text = "0"
	hint_label.modulate.a = 0.0
	intro_label.modulate.a = 0.0
	combo_chip.visible = false
	combo_bar.value = 0.0
	combo_milestone_label.modulate.a = 0.0
	perfect_label.modulate.a = 0.0
	challenge_toast.modulate.a = 0.0
	recovery_label.modulate.a = 0.0
	_refresh_daily()

	var insets := Platform.get_safe_insets()
	var top_offset := int(insets["top"])
	if top_offset > 0:
		for box in [pause_button, score_box, best_box, combo_chip, challenge_toast]:
			box.offset_top += top_offset
			box.offset_bottom += top_offset
	var bottom_offset := int(insets["bottom"])
	if bottom_offset > 0:
		hint_label.offset_top -= bottom_offset
		hint_label.offset_bottom -= bottom_offset


func _build_top_fade() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0196, 0.0196, 0.0196, 0.9),
		Color(0.0196, 0.0196, 0.0196, 0.5),
		Color(0.0196, 0.0196, 0.0196, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 430
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	top_fade.texture = texture


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


func set_combo(combo: int, multiplier: int, progress: float) -> void:
	combo_chip.visible = combo >= 1
	if not combo_chip.visible:
		combo_bar.value = 0.0
		return
	combo_value.text = str(combo)
	multiplier_label.text = "×%d" % multiplier
	combo_bar.value = clampf(progress, 0.0, 1.0)
	combo_chip.pivot_offset = combo_chip.size * 0.5
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	combo_chip.scale = Vector2(1.04, 1.04)
	_combo_tween = create_tween()
	_combo_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(combo_chip, "scale", Vector2.ONE, 0.2)


func set_daily_progress(completed: int, total: int) -> void:
	daily_value.text = "DAILY %d/%d" % [completed, total]


func play_intro() -> void:
	clear_feedback()
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


func flash_combo_milestone(combo: int, multiplier: int) -> void:
	combo_milestone_label.text = "COMBO %d  •  %d×" % [combo, multiplier]
	combo_milestone_label.visible = true
	combo_milestone_label.modulate.a = 0.0
	combo_milestone_label.scale = Vector2(0.86, 0.86)
	combo_milestone_label.pivot_offset = combo_milestone_label.size * 0.5
	if _milestone_tween != null and _milestone_tween.is_valid():
		_milestone_tween.kill()
	_milestone_tween = create_tween()
	_milestone_tween.set_parallel(true)
	_milestone_tween.tween_property(combo_milestone_label, "modulate:a", 1.0, 0.12)
	_milestone_tween.tween_property(combo_milestone_label, "scale", Vector2(1.04, 1.04), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_milestone_tween.set_parallel(false)
	_milestone_tween.tween_interval(0.55)
	_milestone_tween.tween_property(combo_milestone_label, "modulate:a", 0.0, 0.35)
	_milestone_tween.tween_callback(func() -> void: combo_milestone_label.visible = false)


func show_perfect_dodge(bonus: int) -> void:
	perfect_label.text = "PERFECT DODGE  +%d" % bonus
	perfect_label.visible = true
	perfect_label.modulate.a = 0.0
	perfect_label.scale = Vector2(0.9, 0.9)
	perfect_label.pivot_offset = perfect_label.size * 0.5
	if _perfect_tween != null and _perfect_tween.is_valid():
		_perfect_tween.kill()
	_perfect_tween = create_tween()
	_perfect_tween.set_parallel(true)
	_perfect_tween.tween_property(perfect_label, "modulate:a", 1.0, 0.1)
	_perfect_tween.tween_property(perfect_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_perfect_tween.set_parallel(false)
	_perfect_tween.tween_interval(0.5)
	_perfect_tween.tween_property(perfect_label, "modulate:a", 0.0, 0.28)
	_perfect_tween.tween_callback(func() -> void: perfect_label.visible = false)


func show_challenge_complete(title: String, reward: int) -> void:
	challenge_toast_label.text = "DAILY  •  %s  +%d" % [title, reward]
	challenge_toast.visible = true
	challenge_toast.modulate.a = 0.0
	challenge_toast.scale = Vector2(0.94, 0.94)
	challenge_toast.pivot_offset = challenge_toast.size * 0.5
	if _challenge_tween != null and _challenge_tween.is_valid():
		_challenge_tween.kill()
	_challenge_tween = create_tween()
	_challenge_tween.set_parallel(true)
	_challenge_tween.tween_property(challenge_toast, "modulate:a", 1.0, 0.14)
	_challenge_tween.tween_property(challenge_toast, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_challenge_tween.set_parallel(false)
	_challenge_tween.tween_interval(1.5)
	_challenge_tween.tween_property(challenge_toast, "modulate:a", 0.0, 0.35)
	_challenge_tween.tween_callback(func() -> void: challenge_toast.visible = false)


func show_recovery() -> void:
	recovery_label.visible = true
	recovery_label.modulate.a = 0.0
	if _recovery_tween != null and _recovery_tween.is_valid():
		_recovery_tween.kill()
	_recovery_tween = create_tween()
	_recovery_tween.tween_property(recovery_label, "modulate:a", 1.0, 0.2)
	_recovery_tween.tween_interval(0.8)
	_recovery_tween.tween_property(recovery_label, "modulate:a", 0.0, 0.35)
	_recovery_tween.tween_callback(func() -> void: recovery_label.visible = false)


func clear_feedback() -> void:
	for tween in [_milestone_tween, _perfect_tween, _challenge_tween, _recovery_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	combo_milestone_label.visible = false
	perfect_label.visible = false
	challenge_toast.visible = false
	recovery_label.visible = false


func _refresh_daily() -> void:
	daily_value.text = "DAILY %d/%d" % [Challenges.get_completed_count(), Challenges.get_total_count()]
