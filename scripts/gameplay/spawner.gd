class_name ObstacleSpawner
extends Node
## Pattern-based spawner. Every sequence is guaranteed to be survivable:
## alternating lanes, minimum reaction gaps, and no same-lane stacking.

signal obstacle_passed
signal obstacle_spawned(obstacle: Obstacle)

const OBSTACLE_SCENE := preload("res://scenes/obstacles/Obstacle.tscn")
const SPAWN_X := [540.0 - Palette.LANE_OFFSET, 540.0 + Palette.LANE_OFFSET]

@export var obstacles_path: NodePath = ^"../Obstacles"

var elapsed: float = 0.0
var speed: float = Difficulty.START_SPEED
var active: bool = false
var frozen: bool = false

var _container: Node2D
var _obstacles: Array[Obstacle] = []
var _pending: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _spawn_count: int = 0


func _ready() -> void:
	_container = get_node_or_null(obstacles_path) as Node2D
	if _container == null:
		push_error("ObstacleSpawner: obstacles container missing at %s." % obstacles_path)


func start() -> void:
	clear_all()
	elapsed = 0.0
	speed = Difficulty.START_SPEED
	_spawn_timer = 0.9
	_spawn_count = 0
	_pending.clear()
	frozen = false
	active = true


func stop() -> void:
	active = false
	_pending.clear()
	for obstacle in _obstacles:
		if is_instance_valid(obstacle):
			obstacle.moving = false


func set_frozen(value: bool) -> void:
	frozen = value
	for obstacle in _obstacles:
		if is_instance_valid(obstacle):
			obstacle.moving = not value


func clear_all() -> void:
	_pending.clear()
	for obstacle in _obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_obstacles.clear()


func revive_cleanup(min_elapsed: float = -1.0) -> void:
	clear_all()
	if min_elapsed >= 0.0:
		elapsed = minf(elapsed, min_elapsed)
	speed = Difficulty.speed_at(elapsed)
	_spawn_timer = 1.4
	active = true
	frozen = false


func get_obstacle_count() -> int:
	return _obstacles.size()


func _process(delta: float) -> void:
	if not active or frozen:
		return
	elapsed += delta
	speed = Difficulty.speed_at(elapsed)

	for i in range(_pending.size() - 1, -1, -1):
		var item: Dictionary = _pending[i]
		item["time"] = float(item["time"]) - delta
		if float(item["time"]) <= 0.0:
			_pending.remove_at(i)
			_spawn_obstacle(int(item["lane"]), int(item["variant"]), int(item.get("attempts", 0)))

	_spawn_timer = maxf(0.0, _spawn_timer - delta)
	if _spawn_timer <= 0.0 and _pending.is_empty():
		_spawn_pattern()

	var valid: Array[Obstacle] = []
	for obstacle in _obstacles:
		if is_instance_valid(obstacle):
			valid.append(obstacle)
	_obstacles = valid


func _spawn_pattern() -> void:
	var patterns := Difficulty.allowed_patterns(elapsed)
	var pattern := _weighted_choice(patterns)
	_spawn_count += 1
	var base_lane := randi() % 2
	var items: Array[Dictionary] = []

	match pattern:
		"single":
			items = [{"lane": base_lane, "delay": 0.0}]
		"stagger":
			items = [
				{"lane": base_lane, "delay": 0.0},
				{"lane": 1 - base_lane, "delay": 0.58},
			]
		"zigzag":
			items = [
				{"lane": base_lane, "delay": 0.0},
				{"lane": 1 - base_lane, "delay": 0.6},
				{"lane": base_lane, "delay": 1.2},
			]
		"rush":
			items = [
				{"lane": base_lane, "delay": 0.0},
				{"lane": 1 - base_lane, "delay": 0.54},
				{"lane": base_lane, "delay": 1.08},
				{"lane": 1 - base_lane, "delay": 1.62},
			]
		_:
			items = [{"lane": base_lane, "delay": 0.0}]

	for item in items:
		var variant := 0
		if _spawn_count > 3 and elapsed > 12.0 and randf() < 0.22:
			variant = 1
		if _spawn_count > 10 and elapsed > 30.0 and randf() < 0.12:
			variant = 2
		_pending.append({
			"lane": int(item["lane"]),
			"time": float(item["delay"]),
			"variant": variant,
			"attempts": 0,
		})

	# Start the next pattern only after the last item of this one, keeping a
	# full interval of breathing room. This is what makes overlapping patterns
	# impossible at every speed.
	var max_delay := 0.0
	for item in items:
		max_delay = maxf(max_delay, float(item["delay"]))
	var jitter := randf_range(-0.04, 0.08)
	_spawn_timer = maxf(0.3, Difficulty.spawn_interval_at(elapsed) + max_delay + jitter)


func _weighted_choice(patterns: Array[String]) -> String:
	var weights := {
		"single": 4.0,
		"stagger": 3.2,
		"zigzag": 2.2,
		"rush": 1.1,
	}
	var total := 0.0
	for pattern in patterns:
		total += float(weights.get(pattern, 1.0))
	if total <= 0.0:
		return "single"
	var roll := randf() * total
	for pattern in patterns:
		roll -= float(weights.get(pattern, 1.0))
		if roll <= 0.0:
			return pattern
	return patterns.back()


func _spawn_obstacle(lane: int, variant: int, attempts: int) -> void:
	if _container == null:
		return
	if _is_too_close(lane) and attempts < 10:
		_pending.append({
			"lane": lane,
			"time": 0.14,
			"variant": variant,
			"attempts": attempts + 1,
		})
		return

	var obstacle := OBSTACLE_SCENE.instantiate() as Obstacle
	if obstacle == null:
		push_error("ObstacleSpawner: obstacle scene root is not an Obstacle.")
		return
	obstacle.setup(lane, speed, variant)
	obstacle.passed.connect(_on_obstacle_passed.bind(obstacle))
	_container.add_child(obstacle)
	_obstacles.append(obstacle)
	obstacle_spawned.emit(obstacle)


func _is_too_close(lane: int) -> bool:
	# Same-lane blocks need roughly a third of a second of visual separation.
	var min_gap := speed * 0.36
	for obstacle in _obstacles:
		if not is_instance_valid(obstacle) or obstacle.lane != lane:
			continue
		if obstacle.position.y > Obstacle.SPAWN_Y and obstacle.position.y < Obstacle.SPAWN_Y + min_gap:
			return true
	return false


func _on_obstacle_passed(obstacle: Obstacle) -> void:
	obstacle_passed.emit(obstacle)
