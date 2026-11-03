extends Control
## Audio, comfort, privacy and destructive actions.

@onready var back_button: Button = %BackButton
@onready var sfx_row: ToggleRow = %SfxRow
@onready var music_row: ToggleRow = %MusicRow
@onready var vibration_row: ToggleRow = %VibrationRow
@onready var effects_row: ToggleRow = %EffectsRow
@onready var fullscreen_row: ToggleRow = %FullscreenRow
@onready var analytics_row: ToggleRow = %AnalyticsRow
@onready var volume_bar: ProgressBar = %VolumeBar
@onready var volume_label: Label = %VolumeLabel
@onready var volume_down: Button = %VolumeDown
@onready var volume_up: Button = %VolumeUp
@onready var reset_button: Button = %ResetButton
@onready var status_label: Label = %StatusLabel
@onready var version_label: Label = %VersionLabel

var _reset_armed: bool = false
var _reset_timer: Tween


func _ready() -> void:
	Platform.apply_safe_margins($Content, 76, 64, 76, 52)
	back_button.pressed.connect(_go_back)
	sfx_row.value_changed.connect(_on_toggle.bind("sfx"))
	music_row.value_changed.connect(_on_toggle.bind("music"))
	vibration_row.value_changed.connect(_on_toggle.bind("vibration"))
	effects_row.value_changed.connect(_on_toggle.bind("reduced_effects"))
	fullscreen_row.value_changed.connect(_on_fullscreen_toggle)
	analytics_row.value_changed.connect(_on_analytics_toggle)

	sfx_row.set_value(bool(SaveManager.get_setting("sfx")))
	music_row.set_value(bool(SaveManager.get_setting("music")))
	vibration_row.set_value(bool(SaveManager.get_setting("vibration")))
	effects_row.set_value(bool(SaveManager.get_setting("reduced_effects")))
	analytics_row.set_value(bool(SaveManager.get_setting("analytics")))
	fullscreen_row.set_value(bool(SaveManager.get_setting("fullscreen")))
	fullscreen_row.visible = Platform.can_toggle_fullscreen()
	if not Platform.supports_haptics():
		vibration_row.set_enabled(false, "Available on mobile builds only.")

	volume_down.pressed.connect(_adjust_volume.bind(-0.1))
	volume_up.pressed.connect(_adjust_volume.bind(0.1))
	reset_button.pressed.connect(_on_reset_pressed)
	status_label.visible = false
	version_label.text = "ONE MORE SECOND  •  v%s" % GameConfig.VERSION
	_refresh_volume()
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


func _on_toggle(value: bool, key: String) -> void:
	SaveManager.set_setting(key, value)
	Analytics.track("settings_changed", {key: value})


func _on_fullscreen_toggle(value: bool) -> void:
	SaveManager.set_setting("fullscreen", value)
	Platform.set_fullscreen(value)
	Analytics.track("settings_changed", {"fullscreen": value})


func _on_analytics_toggle(value: bool) -> void:
	SaveManager.set_setting("analytics", value)
	Analytics.track("settings_changed", {"analytics": value})


func _adjust_volume(delta_value: float) -> void:
	var volume := clampf(snappedf(float(SaveManager.get_setting("volume")) + delta_value, 0.1), 0.0, 1.0)
	SaveManager.set_setting("volume", volume)
	_refresh_volume()


func _refresh_volume() -> void:
	var volume := float(SaveManager.get_setting("volume"))
	volume_bar.value = round(volume * 100.0)
	volume_label.text = "%d%%" % int(round(volume * 100.0))


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "TAP AGAIN TO ERASE PROGRESS"
		status_label.text = "This removes your best score and statistics. Settings and skins are kept."
		status_label.visible = true
		if _reset_timer != null and _reset_timer.is_valid():
			_reset_timer.kill()
		_reset_timer = create_tween()
		_reset_timer.tween_interval(4.0)
		_reset_timer.tween_callback(_disarm_reset)
		return
	SaveManager.reset_progress()
	_disarm_reset()
	status_label.text = "Progress erased. A fresh run awaits."
	status_label.visible = true
	AudioManager.play_sfx("revive", -6.0)
	Platform.vibrate(18)


func _disarm_reset() -> void:
	_reset_armed = false
	reset_button.text = "RESET PROGRESS"
