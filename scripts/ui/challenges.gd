extends Control
## Local daily challenge overview. The set and progress come from ChallengeManager.

@onready var back_button: Button = %BackButton
@onready var summary_value: Label = %SummaryValue
@onready var summary_caption: Label = %SummaryCaption
@onready var date_label: Label = %DateLabel
@onready var cards_box: VBoxContainer = %Cards


func _ready() -> void:
	Platform.apply_safe_margins($Content, 76, 62, 76, 48)
	Challenges.refresh_daily()
	back_button.pressed.connect(_go_back)
	_build()
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


func _build() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	var challenges := Challenges.get_challenges()
	var completed := Challenges.get_completed_count()
	summary_value.text = "%d / %d" % [completed, challenges.size()]
	summary_caption.text = "ALL CHALLENGES COMPLETE" if completed >= challenges.size() and challenges.size() > 0 else "CHALLENGES COMPLETE TODAY"
	date_label.text = "TODAY  •  %s  •  RESETS AT MIDNIGHT (LOCAL TIME)" % Challenges.get_date()

	for index in challenges.size():
		var card := _build_card(challenges[index])
		cards_box.add_child(card)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(index * 0.06)
		tween.tween_property(card, "modulate:a", 1.0, 0.26)


func _build_card(challenge: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 222)
	card.theme_type_variation = &"RowPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 3)
	accent.color = Palette.with_alpha(Palette.CYAN, 0.8) if bool(challenge.get("completed", false)) else Palette.with_alpha(Palette.WHITE, 0.06)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(accent)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	var title := Label.new()
	title.text = String(challenge.get("title", "CHALLENGE"))
	title.theme_type_variation = &"SubheadingLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var status := Label.new()
	status.text = "COMPLETE" if bool(challenge.get("completed", false)) else "IN PROGRESS"
	status.theme_type_variation = &"AccentLabel" if bool(challenge.get("completed", false)) else &"CaptionLabel"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(status)

	var description := Label.new()
	description.text = String(challenge.get("description", ""))
	description.theme_type_variation = &"BodyLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(description)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 18)
	progress.max_value = 1.0
	progress.step = 0.01
	progress.value = float(challenge.get("progress_ratio", 0.0))
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(progress)

	var footer := HBoxContainer.new()
	box.add_child(footer)
	var progress_label := Label.new()
	progress_label.text = String(challenge.get("progress_text", "0 / 0"))
	progress_label.theme_type_variation = &"CaptionLabel"
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(progress_label)
	var reward := Label.new()
	var completed := bool(challenge.get("completed", false))
	reward.text = ("EARNED  +%d PTS" if completed else "REWARD  +%d PTS") % int(challenge.get("reward", 0))
	reward.theme_type_variation = &"GoldLabel"
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(reward)
	return card
