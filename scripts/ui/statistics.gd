extends Control
## Local statistics. No network calls, no identifiers.

@onready var back_button: Button = %BackButton
@onready var hero_value: Label = %HeroValue
@onready var hero_rank: Label = %HeroRank
@onready var grid: GridContainer = %Grid

var _hero_tween: Tween


func _ready() -> void:
	Platform.apply_safe_margins($Content, 76, 62, 76, 52)
	back_button.pressed.connect(_go_back)
	_fill()
	back_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	SceneRouter.go_menu()


func _fill() -> void:
	var stats := SaveManager.get_stats()
	var best := SaveManager.get_best_score()
	var games := int(stats.get("games_played", 0))
	var total_score := int(stats.get("total_score", 0))
	var average := 0 if games == 0 else int(round(float(total_score) / float(games)))

	hero_value.text = "0"
	hero_rank.text = "RANK  •  %s" % GameConfig.rank_for(best)
	if _hero_tween != null and _hero_tween.is_valid():
		_hero_tween.kill()
	_hero_tween = create_tween()
	_hero_tween.tween_method(_set_hero_value, 0.0, float(best), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var entries := [
		["RUNS PLAYED", str(games)],
		["TOTAL POINTS", GameConfig.format_score(total_score)],
		["BEST SURVIVAL", GameConfig.format_time(float(stats.get("best_survival_time", 0.0)))],
		["TOTAL PLAY TIME", GameConfig.format_time(float(stats.get("total_play_time", 0.0)))],
		["OBSTACLES AVOIDED", GameConfig.format_score(int(stats.get("obstacles_avoided", 0)))],
		["BEST COMBO", str(int(stats.get("best_combo", 0)))],
		["PERFECT DODGES", str(int(stats.get("perfect_dodges", 0)))],
		["REVIVES USED", str(int(stats.get("revives_used", 0)))],
		["AVG SCORE / RUN", str(average)],
		["HIGHEST RANK", GameConfig.rank_for(best)],
	]
	for i in entries.size():
		var card := _build_card(String(entries[i][0]), String(entries[i][1]))
		grid.add_child(card)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(card, "modulate:a", 1.0, 0.28)


func _set_hero_value(value: float) -> void:
	hero_value.text = GameConfig.format_score(int(round(value)))


func _build_card(caption: String, value: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 168)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = &"RowPanel"
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.theme_type_variation = &"CaptionLabel"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.theme_type_variation = &"ValueLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value_label)
	return panel
