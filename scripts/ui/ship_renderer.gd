class_name ShipRenderer
extends RefCounted
## Shared vector renderer for the player ship, menu previews and skin cards.
## Keeps the silhouette identical everywhere without exporting textures.

const SHIP_POINTS := [
	Vector2(0, -58),
	Vector2(14, -22),
	Vector2(44, 18),
	Vector2(18, 8),
	Vector2(10, 38),
	Vector2(0, 27),
	Vector2(-10, 38),
	Vector2(-18, 8),
	Vector2(-44, 18),
	Vector2(-14, -22),
]


static func draw_ship(
	canvas: CanvasItem,
	center: Vector2,
	rotation: float,
	scale_factor: float,
	primary: Color,
	secondary: Color,
	accent: Color,
	glow: float = 1.0,
	opacity: float = 1.0,
	shield: float = 0.0
) -> void:
	canvas.draw_set_transform(center, rotation, Vector2(scale_factor, scale_factor))
	var shape := PackedVector2Array(SHIP_POINTS)

	if glow > 0.01:
		canvas.draw_colored_polygon(_scaled(shape, 1.85), Palette.with_alpha(primary, 0.035 * glow * opacity))
		canvas.draw_colored_polygon(_scaled(shape, 1.45), Palette.with_alpha(primary, 0.075 * glow * opacity))
		canvas.draw_colored_polygon(_scaled(shape, 1.15), Palette.with_alpha(primary, 0.1 * glow * opacity))

	canvas.draw_colored_polygon(shape, Palette.with_alpha(primary, opacity))
	canvas.draw_polyline(_closed(shape), Palette.with_alpha(secondary, 0.85 * opacity), 2.0, true)

	var inner := PackedVector2Array([
		Vector2(0, -34), Vector2(8, -10), Vector2(14, 2), Vector2(0, -4), Vector2(-14, 2), Vector2(-8, -10),
	])
	canvas.draw_colored_polygon(inner, Palette.with_alpha(secondary, opacity))
	canvas.draw_line(Vector2(0, -34), Vector2(0, 4), Palette.with_alpha(Color.WHITE, opacity), 2.0, true)

	canvas.draw_line(Vector2(-18, 8), Vector2(-30, 24), Palette.with_alpha(accent, opacity), 3.0, true)
	canvas.draw_line(Vector2(18, 8), Vector2(30, 24), Palette.with_alpha(accent, opacity), 3.0, true)
	canvas.draw_line(Vector2(-6, 30), Vector2(-9, 52), Palette.with_alpha(accent, 0.75 * opacity), 3.0, true)
	canvas.draw_line(Vector2(6, 30), Vector2(9, 52), Palette.with_alpha(accent, 0.75 * opacity), 3.0, true)

	if shield > 0.01:
		var radius := 82.0 + sin(shield * 16.0) * 3.0
		canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Palette.with_alpha(Palette.CYAN, 0.45 * shield), 3.0, true)
		canvas.draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 64, Palette.with_alpha(Palette.CYAN, 0.12 * shield), 10.0, true)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * factor)
	return result


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	result.append(points[0])
	return result
