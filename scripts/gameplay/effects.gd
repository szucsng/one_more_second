class_name ParticleFX
extends Node2D
## Lightweight custom particle system for menu and gameplay effects.
## Canvas-drawn particles avoid texture imports and allocate far less than
## spawn-per-hit nodes on mobile.

var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _reduced: bool = false
var _additive_material: CanvasItemMaterial


func _ready() -> void:
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_material
	_reduced = bool(SaveManager.get_setting("reduced_effects"))


func emit_burst(position: Vector2, color: Color, count: int = 18, speed: float = 460.0, life: float = 0.7) -> void:
	if _reduced:
		count = maxi(5, count / 3)
	for i in count:
		var angle := randf() * TAU
		var magnitude := speed * randf_range(0.25, 1.0)
		_particles.append({
			"position": position,
			"velocity": Vector2(cos(angle), sin(angle)) * magnitude,
			"life": life * randf_range(0.6, 1.2),
			"max_life": life,
			"color": color,
			"size": randf_range(2.0, 6.0),
			"drag": randf_range(1.5, 4.5),
		})


func emit_sparks(position: Vector2, color: Color, count: int = 5) -> void:
	if _reduced:
		count = 2
	for i in count:
		_particles.append({
			"position": position + Vector2(randf_range(-18, 18), randf_range(-4, 14)),
			"velocity": Vector2(randf_range(-90, 90), randf_range(80, 260)),
			"life": randf_range(0.18, 0.42),
			"max_life": 0.4,
			"color": color,
			"size": randf_range(1.5, 4.0),
			"drag": 2.0,
		})


func emit_ring(position: Vector2, color: Color, radius: float = 140.0, life: float = 0.55) -> void:
	_rings.append({
		"position": position,
		"radius": radius,
		"life": life,
		"max_life": life,
		"color": color,
	})


func _process(delta: float) -> void:
	var active := false
	if not _particles.is_empty():
		active = true
		var alive: Array[Dictionary] = []
		for particle in _particles:
			particle["life"] = float(particle["life"]) - delta
			if float(particle["life"]) <= 0.0:
				continue
			var velocity: Vector2 = particle["velocity"]
			velocity *= maxf(0.0, 1.0 - float(particle["drag"]) * delta)
			particle["velocity"] = velocity
			particle["position"] = (particle["position"] as Vector2) + velocity * delta
			alive.append(particle)
		_particles = alive
	if not _rings.is_empty():
		active = true
		var alive_rings: Array[Dictionary] = []
		for ring in _rings:
			ring["life"] = float(ring["life"]) - delta
			if float(ring["life"]) > 0.0:
				alive_rings.append(ring)
		_rings = alive_rings
	if active:
		queue_redraw()


func _draw() -> void:
	for particle in _particles:
		var ratio: float = clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		var color: Color = particle["color"]
		draw_circle(particle["position"], float(particle["size"]) * ratio, Palette.with_alpha(color, ratio * 0.9))
	for ring in _rings:
		var ratio: float = clampf(float(ring["life"]) / float(ring["max_life"]), 0.0, 1.0)
		var radius: float = float(ring["radius"]) * (1.0 - ratio) + 10.0
		draw_arc(ring["position"], radius, 0.0, TAU, 48, Palette.with_alpha(ring["color"], ratio * 0.5), 3.0, true)
