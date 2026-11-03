class_name ToggleRow
extends HBoxContainer
## Label + ON/OFF pill used across the settings screen.

signal value_changed(value: bool)

@export var title: String = "OPTION"
@export var hint: String = ""
@export var initial_value: bool = true

@onready var name_label: Label = $TextBox/NameLabel
@onready var hint_label: Label = $TextBox/HintLabel
@onready var toggle_button: Button = $ToggleButton

var value: bool = true
var _updating: bool = false


func _ready() -> void:
	name_label.text = title
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()
	toggle_button.toggle_mode = true
	toggle_button.button_pressed = initial_value
	value = initial_value
	toggle_button.toggled.connect(_on_toggled)
	_refresh()


func set_value(new_value: bool) -> void:
	_updating = true
	value = new_value
	toggle_button.button_pressed = new_value
	_updating = false
	_refresh()


func set_enabled(enabled: bool, disabled_hint: String = "") -> void:
	toggle_button.disabled = not enabled
	if not disabled_hint.is_empty():
		hint_label.text = disabled_hint
		hint_label.visible = true


func _on_toggled(enabled: bool) -> void:
	if _updating:
		return
	value = enabled
	_refresh()
	AudioManager.play_ui_tap()
	value_changed.emit(value)


func _refresh() -> void:
	toggle_button.text = "ON" if value else "OFF"
