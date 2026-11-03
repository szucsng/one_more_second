class_name Obstacle
extends Area2D
## A single hazardous block in one of the two lanes.
## Collision width is deliberately smaller than the art so near-misses feel fair.

signal passed

const WIDTH := 292.0
const HEIGHT := 92.0
const COLLISION_WIDTH := 262.0
const COLLISION_HEIGHT := 78.0
const PASS_Y := 1590.0
const DESPAWN_Y := 2120.0
const SPAWN_Y := -170.0

var lane: int = 0
var speed: float = 620.0
var variant: int = 0
var moving: bool = true

var _counted: bool = false
var _time: float = 0.0
var _accent: Color = Palette.PINK
var _glow_box: StyleBoxFlat
var _body_box: StyleBoxFlat
var _reduced: bool = false


func setup(lane_index: int, travel_speed: float, obstacle_variant: int = 0) -> void:
	lane = clampi(lane_index, 0, 1)
	speed = maxf(1.0, travel_speed)
	variant = obstacle_variant
	position = Vector2(540.0 + (-Palette.LANE_OFFSET if lane == 0 else Palette.LANE_OFFSET), SPAWN_Y)
	match variant:
		1:
			_accent = Palette.PURPLE
		2:
			_accent = Color("#FF5C5C")
		_:
			_accent = Palette.PINK


func _ready() -> void:
	add_to_group("obstacle")
	collision_layer = 2
	collision_mask = 1
	monitorable = true
	monitoring = false
	_reduced = bool(SaveManager.get_setting("reduced_effects"))

	var shape := RectangleShape2D.new()
	shape.size = Vector2(COLLISION_WIDTH, COLLISION_HEIGHT)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

	_glow_box = StyleBoxFlat.new()
	_glow_box.bg_color = Color(0, 0, 0, 0)
	_glow_box.border_color = Palette.with_alpha(_accent, 0.22)
	_glow_box.set_border_width_all(2)
	_glow_box.set_corner_radius_all(22)
	_glow_box.shadow_color = Palette.with_alpha(_accent, 0.4 if not _reduced else 0.22)
	_glow_box.shadow_size = 26 if not _reduced else 12
	_glow_box.expand_margin_left = 14
	_glow_box.expand_margin_right = 14
	_glow_box.expand_margin_top = 14
	_glow_box.expand_margin_bottom = 14

	_body_box = StyleBoxFlat.new()
	_body_box.bg_color = Color("#170A14")
	_body_box.border_color = _accent
	_body_box.set_border_width_all(3)
	_body_box.set_corner_radius_all(18)
	_body_box.content_margin_left = 12
	_body_box.content_margin_right = 12


func _process(delta: float) -> void:
	_time += delta
	if moving:
		position.y += speed * delta
		if not _counted and position.y >= PASS_Y:
			_counted = true
			passed.emit()
		if position.y > DESPAWN_Y:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH, HEIGHT)
	var pulse := 0.75 + 0.25 * sin(_time * 5.0 + float(lane))
	if variant == 1:
		pulse = 0.55 + 0.45 * absf(sin(_time * 3.2))
	draw_style_box(_glow_box, rect)
	_body_box.border_color = Palette.with_alpha(_accent, pulse)
	draw_style_box(_body_box, rect)

	# Hazard chevrons.
	for x in [-82.0, 0.0, 82.0]:
		var points := PackedVector2Array([
			Vector2(x - 14, -14), Vector2(x, -2), Vector2(x + 14, -14),
		])
		draw_polyline(points, Palette.with_alpha(_accent, 0.55), 3.0, true)

	# Top warning strip.
	draw_rect(Rect2(-WIDTH * 0.5 + 12, -HEIGHT * 0.5 + 10, WIDTH - 24, 4), Palette.with_alpha(_accent, 0.8), true)
	draw_rect(Rect2(-WIDTH * 0.5 + 12, HEIGHT * 0.5 - 14, WIDTH - 24, 4), Palette.with_alpha(_accent, 0.35), true)

	# Side accents.
	draw_line(Vector2(-WIDTH * 0.5 + 10, -20), Vector2(-WIDTH * 0.5 + 10, 20), Palette.with_alpha(_accent, 0.9), 3.0, true)
	draw_line(Vector2(WIDTH * 0.5 - 10, -20), Vector2(WIDTH * 0.5 - 10, 20), Palette.with_alpha(_accent, 0.9), 3.0, true)

	if variant == 2:
		draw_rect(Rect2(-WIDTH * 0.5 + 20, -HEIGHT * 0.5 + 20, WIDTH - 40, HEIGHT - 40), Palette.with_alpha(_accent, 0.08), true)
