class_name NeonBackdrop
extends Control
## Animated tech-grid background shared by every screen.
## Pure canvas drawing: no shaders, no textures beyond two cached gradients,
## so it stays fast on low-end phones and the GL compatibility web renderer.

@export var mode: String = "menu"
@export var show_lanes: bool = false
@export var scroll_speed: float = 26.0
@export var accent: Color = Palette.CYAN
@export var secondary_accent: Color = Palette.PURPLE

var _time: float = 0.0
var _grid_offset: float = 0.0
var _particles: Array[Dictionary] = []
var _reduced_effects: bool = false
var _vignette: GradientTexture2D
var _glow: GradientTexture2D
var _initialized: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_effects = bool(SaveManager.get_setting("reduced_effects"))
	_build_textures()
	_build_particles()
	_initialized = true
	SaveManager.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	_reduced_effects = bool(SaveManager.get_setting("reduced_effects"))
	_build_particles()
	queue_redraw()


func _build_textures() -> void:
	var vignette_gradient := Gradient.new()
	vignette_gradient.offsets = PackedFloat32Array([0.0, 0.52, 0.78, 1.0])
	vignette_gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0.02), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.82),
	])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = vignette_gradient
	_vignette.width = 384
	_vignette.height = 384
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 1.0)

	var glow_gradient := Gradient.new()
	glow_gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	glow_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	_glow = GradientTexture2D.new()
	_glow.gradient = glow_gradient
	_glow.width = 256
	_glow.height = 256
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 1.0)


func _build_particles() -> void:
	var count := 14 if _reduced_effects else 30
	_particles.clear()
	for i in count:
		_particles.append({
			"x": randf_range(40.0, 1040.0),
			"y": randf_range(0.0, 1920.0),
			"radius": randf_range(1.2, 3.2),
			"speed": randf_range(8.0, 34.0),
			"phase": randf() * TAU,
			"tint": accent if i % 3 != 0 else secondary_accent,
		})


func _process(delta: float) -> void:
	if not _initialized:
		return
	_time += delta
	_grid_offset = fmod(_grid_offset + delta * scroll_speed, 150.0)
	for particle in _particles:
		particle["y"] = fmod(float(particle["y"]) - float(particle["speed"]) * delta + 1920.0, 1920.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BACKGROUND, true)

	if not _reduced_effects:
		draw_texture_rect(_glow, Rect2(140, -520, 800, 900), false, Palette.with_alpha(accent, 0.055))
		draw_texture_rect(_glow, Rect2(-420, 1240, 1100, 900), false, Palette.with_alpha(secondary_accent, 0.045))
		draw_texture_rect(_glow, Rect2(560, 900, 700, 600), false, Palette.with_alpha(Palette.PINK, 0.02))

	var grid_alpha := 0.028 if _reduced_effects else 0.05
	for i in range(13):
		var x := float(i) * 90.0
		var strong := i % 4 == 0
		var color := Palette.with_alpha(accent, grid_alpha * (1.8 if strong else 1.0))
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0, true)

	var y := -150.0 + _grid_offset
	while y < size.y + 150.0:
		var distance_fade := 1.0 - clampf(absf(y - size.y * 0.55) / (size.y * 0.8), 0.0, 0.8)
		draw_line(Vector2(0, y), Vector2(size.x, y), Palette.with_alpha(accent, grid_alpha * 0.75 * distance_fade), 1.0, true)
		y += 150.0

	if show_lanes:
		for lane_x in [Palette.LANE_MIN_X, Palette.LANE_MAX_X]:
			draw_line(Vector2(lane_x, 0), Vector2(lane_x, size.y), Palette.with_alpha(accent, 0.07), 2.0, true)
		draw_line(Vector2(540, 0), Vector2(540, size.y), Palette.with_alpha(Palette.WHITE, 0.018), 1.0, true)

	for particle in _particles:
		var twinkle := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 1.5 + float(particle["phase"])))
		var color: Color = particle["tint"]
		draw_circle(Vector2(float(particle["x"]), float(particle["y"])), float(particle["radius"]), Palette.with_alpha(color, 0.18 * twinkle))

	if not _reduced_effects:
		var scan_y := fmod(_time * 60.0, 2200.0) - 120.0
		draw_rect(Rect2(0, scan_y, size.x, 2.0), Palette.with_alpha(accent, 0.055))

	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 1))
