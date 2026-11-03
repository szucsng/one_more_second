class_name PlayerShip
extends Area2D
## Two-lane player ship. Movement is cosmetic; collision is a forgiving box.

signal died
signal lane_changed(lane: int, from_lane: int)

const LANE_X := [540.0 - Palette.LANE_OFFSET, 540.0 + Palette.LANE_OFFSET]
const SWITCH_COOLDOWN := 0.055

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trail: NeonTrail = $Trail

var lane: int = 0
var alive: bool = true
var movement_enabled: bool = true
var invulnerable_time: float = 0.0
var _target_x: float = LANE_X[0]
var _tilt: float = 0.0
var _switch_cooldown: float = 0.0
var _time: float = 0.0
var _primary: Color = Palette.CYAN
var _secondary: Color = Color.WHITE
var _accent: Color = Palette.PURPLE
var _glow: float = 1.0
var _dead_fade: float = 1.0


func _ready() -> void:
	position = Vector2(_target_x, Palette.PLAYER_Y)
	collision_layer = 1
	collision_mask = 2
	add_to_group("player")
	_apply_skin(SkinManager.get_selected())
	SkinManager.skin_changed.connect(_on_skin_changed)
	area_entered.connect(_on_area_entered)
	_glow = 0.45 if bool(SaveManager.get_setting("reduced_effects")) else 1.0


func _on_skin_changed(_skin_id: String) -> void:
	_apply_skin(SkinManager.get_selected())
	trail.set_color(_primary)


func _apply_skin(definition: Dictionary) -> void:
	_primary = definition.get("primary", Palette.CYAN)
	_secondary = definition.get("secondary", Color.WHITE)
	_accent = definition.get("accent", Palette.PURPLE)
	if is_instance_valid(trail):
		trail.set_color(definition.get("trail", _primary))
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not alive:
		_dead_fade = maxf(0.0, _dead_fade - delta * 4.0)
		queue_redraw()
		return

	if movement_enabled:
		_switch_cooldown = maxf(0.0, _switch_cooldown - delta)
		var previous_x := position.x
		var weight := 1.0 - exp(-22.0 * delta)
		position.x = lerpf(position.x, _target_x, weight)
		var velocity := (position.x - previous_x) / maxf(delta, 0.0001)
		_tilt = lerpf(_tilt, clampf(velocity * 0.00022, -0.16, 0.16), 1.0 - exp(-14.0 * delta))
		if invulnerable_time > 0.0:
			invulnerable_time = maxf(0.0, invulnerable_time - delta)
		trail.push_point(global_position + Vector2(0, 30))
	queue_redraw()


func reset_for_run() -> void:
	alive = true
	_dead_fade = 1.0
	lane = 0
	position = Vector2(LANE_X[0], Palette.PLAYER_Y)
	_target_x = position.x
	_tilt = 0.0
	rotation = 0.0
	_switch_cooldown = 0.0
	invulnerable_time = 0.0
	movement_enabled = true
	trail.clear()
	queue_redraw()


func switch_lane() -> void:
	if not alive or not movement_enabled or _switch_cooldown > 0.0:
		return
	var previous := lane
	lane = 1 - lane
	_target_x = LANE_X[lane]
	_switch_cooldown = SWITCH_COOLDOWN
	lane_changed.emit(lane, previous)


func set_active(active: bool) -> void:
	movement_enabled = active


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0


func grant_invulnerability(duration: float) -> void:
	invulnerable_time = maxf(invulnerable_time, duration)


func revive() -> void:
	alive = true
	_dead_fade = 1.0
	position.x = LANE_X[lane]
	_target_x = position.x
	grant_invulnerability(GameConfig.REVIVE_INVULNERABILITY)
	set_active(true)
	trail.clear()


func kill() -> void:
	if not alive:
		return
	alive = false
	movement_enabled = false
	invulnerable_time = 0.0
	trail.clear()
	died.emit()


func _on_area_entered(area: Area2D) -> void:
	if not alive or not movement_enabled:
		return
	if area.is_in_group("obstacle") and not is_invulnerable():
		kill()


func _draw() -> void:
	var bob := sin(_time * 2.4) * 3.0
	var shield_ratio := 0.0
	if invulnerable_time > 0.0:
		shield_ratio = clampf(invulnerable_time / GameConfig.REVIVE_INVULNERABILITY, 0.0, 1.0)
		shield_ratio = 0.35 + 0.65 * absf(sin(_time * 8.0))
	var opacity := _dead_fade
	ShipRenderer.draw_ship(
		self, Vector2(0, bob), _tilt, 1.0,
		_primary, _secondary, _accent, _glow, opacity, shield_ratio
	)
	if alive and movement_enabled:
		var flame := 0.7 + 0.3 * sin(_time * 22.0)
		draw_line(Vector2(-7, 44), Vector2(-4, 62 + flame * 8), Palette.with_alpha(_primary, 0.35), 4.0, true)
		draw_line(Vector2(7, 44), Vector2(4, 62 + flame * 8), Palette.with_alpha(_primary, 0.35), 4.0, true)
