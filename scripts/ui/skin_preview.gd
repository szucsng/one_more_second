class_name SkinPreview
extends Control
## Animated ship showcase used in the skins screen and inside skin cards.

@export var compact: bool = false

var primary: Color = Palette.CYAN
var secondary: Color = Color.WHITE
var accent: Color = Palette.PURPLE
var trail_color: Color = Palette.CYAN

var _time: float = 0.0
var _reduced: bool = false
var _hue_glow: Color = Palette.CYAN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced = bool(SaveManager.get_setting("reduced_effects"))


func set_skin(definition: Dictionary) -> void:
	primary = definition.get("primary", Palette.CYAN)
	secondary = definition.get("secondary", Color.WHITE)
	accent = definition.get("accent", Palette.PURPLE)
	trail_color = definition.get("trail", primary)
	_hue_glow = primary
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5 + Vector2(0, sin(_time * 1.8) * (3.0 if compact else 5.0))
	var scale_factor := 0.9 if compact else 1.6
	if not compact:
		draw_circle(center, 220.0, Palette.with_alpha(primary, 0.03))
		draw_circle(center, 150.0, Palette.with_alpha(primary, 0.05))
		draw_arc(center, 168.0, 0.0, TAU, 96, Palette.with_alpha(primary, 0.12), 2.0, true)
		draw_arc(center, 208.0, 0.0, TAU, 96, Palette.with_alpha(secondary, 0.05), 1.0, true)
		for i in 6:
			var y := center.y + 120.0 + i * 26.0
			draw_line(Vector2(center.x - 180 + i * 8, y), Vector2(center.x + 180 - i * 8, y), Palette.with_alpha(primary, 0.08 * (1.0 - i * 0.15)), 2.0, true)
	else:
		draw_circle(center, 74.0, Palette.with_alpha(primary, 0.05))
		draw_arc(center, 72.0, 0.0, TAU, 64, Palette.with_alpha(primary, 0.12), 1.5, true)

	# Afterimage trail.
	var trail_count := 4 if compact else 7
	for i in range(trail_count, 0, -1):
		var ratio := 1.0 - float(i) / float(trail_count + 1)
		var offset := Vector2(0, float(i) * (18.0 if compact else 30.0))
		var ghost_alpha := ratio * (0.05 if compact else 0.08)
		ShipRenderer.draw_ship(self, center + offset, 0.0, scale_factor * (1.0 - i * 0.035), trail_color, secondary, accent, 0.0, ghost_alpha, 0.0)

	ShipRenderer.draw_ship(self, center, sin(_time * 1.3) * 0.025, scale_factor, primary, secondary, accent, 0.0 if _reduced else 1.0, 1.0, 0.0)

	if not compact:
		draw_circle(center + Vector2(0, 6), 2.5, Palette.with_alpha(Color.WHITE, 0.8))
