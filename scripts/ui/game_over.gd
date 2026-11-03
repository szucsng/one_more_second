class_name GameOverScreen
extends Control
## Post-run reward screen. Presentation only; gameplay owns recording/revive.

signal restart_pressed
signal menu_pressed
signal continue_pressed

@onready var panel: PanelContainer = %Panel
@onready var rank_label: Label = %RankLabel
@onready var score_label: Label = %ScoreLabel
@onready var best_value: Label = %BestValue
@onready var time_value: Label = %TimeValue
@onready var combo_value: Label = %ComboValue
@onready var perfect_value: Label = %PerfectValue
@onready var new_record_panel: PanelContainer = %NewRecordPanel
@onready var continue_button: Button = %ContinueButton
@onready var ad_caption: Label = %AdCaption
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var effects: ParticleFX = %Effects

var _score_tween: Tween
var _is_record: bool = false


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())


func show_result(score: int, best: int, is_record: bool, duration: float, rank: String, can_continue: bool, max_combo: int = 0, perfect_dodges: int = 0) -> void:
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	panel.pivot_offset = panel.size * 0.5
	rank_label.text = rank
	best_value.text = GameConfig.format_score(best)
	time_value.text = GameConfig.format_time(duration)
	combo_value.text = str(max_combo)
	perfect_value.text = str(perfect_dodges)
	score_label.text = "0"
	_is_record = is_record
	new_record_panel.visible = is_record
	new_record_panel.modulate.a = 1.0 if is_record else 0.0
	continue_button.visible = can_continue
	ad_caption.visible = can_continue
	set_buttons_enabled(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_number, 0.0, float(score), clampf(0.35 + score * 0.012, 0.35, 1.0))
	restart_button.grab_focus()

	if is_record:
		AudioManager.play_sfx("record", -2.0)
		new_record_panel.pivot_offset = new_record_panel.size * 0.5
		var badge_tween := create_tween()
		badge_tween.tween_property(new_record_panel, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK)
		badge_tween.tween_property(new_record_panel, "scale", Vector2.ONE, 0.24)
		_celebrate()


func _set_score_number(value: float) -> void:
	score_label.text = GameConfig.format_score(int(round(value)))


func _celebrate() -> void:
	effects.emit_burst(Vector2(540, 520), Palette.GOLD, 26, 520.0, 0.9)
	effects.emit_burst(Vector2(400, 460), Palette.CYAN, 14, 380.0, 0.8)
	effects.emit_ring(Vector2(540, 540), Palette.GOLD, 260.0, 0.8)
	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree() or not visible:
		return
	effects.emit_burst(Vector2(700, 480), Palette.PINK, 16, 420.0, 0.8)
	effects.emit_ring(Vector2(540, 540), Palette.CYAN, 340.0, 0.7)


func hide_result() -> void:
	visible = false


func set_buttons_enabled(enabled: bool) -> void:
	continue_button.disabled = not enabled
	restart_button.disabled = not enabled
	menu_button.disabled = not enabled


func refresh_continue_visibility(can_continue: bool) -> void:
	continue_button.visible = can_continue
	ad_caption.visible = can_continue


func show_continue_available(available: bool, disclosure: String) -> void:
	continue_button.visible = available
	ad_caption.text = disclosure
	ad_caption.visible = not disclosure.is_empty()


func set_ad_status(text: String) -> void:
	continue_button.visible = false
	ad_caption.text = text
	ad_caption.visible = not text.is_empty()
