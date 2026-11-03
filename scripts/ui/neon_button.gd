class_name NeonButton
extends Button
## Small reusable motion layer for every interactive button.
## Styling comes from the project theme; this only adds feel and the tap sound.

@export var hover_scale: float = 1.02
@export var press_scale: float = 0.975
@export var plays_sound: bool = true

var _scale_tween: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size * 0.5
	resized.connect(_refresh_pivot)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover() -> void:
	if disabled:
		return
	_animate_scale(hover_scale, 0.12)


func _on_unhover() -> void:
	_animate_scale(1.0, 0.14)


func _on_button_down() -> void:
	if disabled:
		return
	_animate_scale(press_scale, 0.06)


func _on_button_up() -> void:
	_animate_scale(hover_scale if is_hovered() else 1.0, 0.12)


func _on_pressed() -> void:
	if plays_sound:
		AudioManager.play_ui_tap()


func _animate_scale(target: float, duration: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2(target, target), duration)
