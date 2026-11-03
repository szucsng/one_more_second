extends Control
## Main menu. Fast, focused and fully keyboard/touch operable.

@onready var content: MarginContainer = %Content
@onready var logo_second: Label = %LogoSecond
@onready var best_value: Label = %BestValue
@onready var play_button: Button = %PlayButton
@onready var skins_button: Button = %SkinsButton
@onready var stats_button: Button = %StatsButton
@onready var settings_button: Button = %SettingsButton
@onready var sound_button: Button = %SoundButton
@onready var support_button: Button = %SupportButton
@onready var version_label: Label = %VersionLabel
@onready var menu_ship: SkinPreview = %MenuShip
@onready var menu_ship_name: Label = %MenuShipName


func _ready() -> void:
	Platform.apply_safe_margins(content, 96, 72, 96, 64)
	version_label.text = "v%s" % GameConfig.VERSION
	support_button.visible = not GameConfig.SUPPORT_URL.is_empty()
	_refresh_best()
	_refresh_sound_label()
	_refresh_ship()

	play_button.pressed.connect(_on_play)
	skins_button.pressed.connect(func() -> void: SceneRouter.go_skins())
	stats_button.pressed.connect(func() -> void: SceneRouter.go_stats())
	settings_button.pressed.connect(func() -> void: SceneRouter.go_settings())
	sound_button.pressed.connect(_on_sound_toggle)
	support_button.pressed.connect(func() -> void: Platform.open_url(GameConfig.SUPPORT_URL))

	SaveManager.progress_changed.connect(_refresh_best)
	SaveManager.settings_changed.connect(_refresh_sound_label)
	SkinManager.skin_changed.connect(func(_id: String) -> void: _refresh_ship())

	_animate_in()
	play_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _refresh_best() -> void:
	best_value.text = GameConfig.format_score(SaveManager.get_best_score())


func _refresh_ship() -> void:
	var definition := SkinManager.get_selected()
	menu_ship.set_skin(definition)
	menu_ship_name.text = String(definition.get("name", "DEFAULT NEON")).to_upper()


func _refresh_sound_label() -> void:
	var enabled := bool(SaveManager.get_setting("sfx")) or bool(SaveManager.get_setting("music"))
	sound_button.text = "SOUND ON" if enabled else "SOUND OFF"
	sound_button.tooltip_text = "Toggle all audio"


func _on_sound_toggle() -> void:
	var currently_enabled := bool(SaveManager.get_setting("sfx")) or bool(SaveManager.get_setting("music"))
	SaveManager.set_setting("sfx", not currently_enabled)
	SaveManager.set_setting("music", not currently_enabled)
	Analytics.track("settings_changed", {"sound": not currently_enabled})
	_refresh_sound_label()


func _on_play() -> void:
	SceneRouter.go_gameplay()


func _animate_in() -> void:
	content.modulate.a = 0.0
	content.position.y = 24.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(content, "modulate:a", 1.0, 0.45)
	tween.tween_property(content, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(logo_second, "modulate:a", 0.82, 1.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(logo_second, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
