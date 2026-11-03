class_name NeonTrail
extends Node2D
## Tapered, additive ribbon that follows the ship. Lives in world space.

@export var max_points: int = 22
@export var point_life: float = 0.33

var color: Color = Palette.CYAN
var _points: Array[Dictionary] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func set_color(new_color: Color) -> void:
	color = new_color


func push_point(world_position: Vector2) -> void:
	_points.insert(0, {"position": world_position, "life": point_life})
	while _points.size() > max_points:
		_points.pop_back()


func clear() -> void:
	_points.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _points.is_empty():
		return
	var alive: Array[Dictionary] = []
	for point in _points:
		point["life"] = float(point["life"]) - delta
		if float(point["life"]) > 0.0:
			alive.append(point)
	_points = alive
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var count := _points.size()
	for i in range(1, count):
		var current: Dictionary = _points[i]
		var previous: Dictionary = _points[i - 1]
		var ratio := 1.0 - float(i) / float(count)
		var width := 14.0 * ratio + 1.0
		var alpha := ratio * (float(current["life"]) / point_life) * 0.35
		draw_line(previous["position"], current["position"], Palette.with_alpha(color, alpha), width, true)
		if i % 3 == 0:
			draw_circle(current["position"], width * 0.6, Palette.with_alpha(color, alpha * 0.8))
