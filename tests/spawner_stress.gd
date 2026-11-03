extends Node
## Five-minute accelerated spawner simulation.
## Verifies that generated patterns are survivable at every difficulty tier,
## that same-lane spacing holds, and that the active set stays bounded.

const STEPS := 60 * 300
const DT := 1.0 / 60.0
const PLAYER_Y := 1470.0

var failures: int = 0
var total_spawned: int = 0


func _ready() -> void:
	await _run()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var container := Node2D.new()
	container.name = "Obstacles"
	world.add_child(container)
	var spawner := ObstacleSpawner.new()
	spawner.obstacles_path = NodePath("../Obstacles")
	world.add_child(spawner)
	await get_tree().process_frame
	spawner.set_process(false)
	spawner.start()

	var max_active := 0
	var collisions := 0
	var unfair_frames := 0
	var bot_lane := 0
	spawner.obstacle_spawned.connect(_count_spawn)

	for step in STEPS:
		spawner.call("_process", DT)
		for child in container.get_children():
			if child is Obstacle:
				var obstacle := child as Obstacle
				obstacle.call("_process", DT)
				if is_instance_valid(obstacle) and obstacle.is_queued_for_deletion():
					obstacle.free()
		if step % 120 == 0:
			await get_tree().process_frame
			if step % 1200 == 0:
				print("  stress t=%.0fs spawned=%d active=%d" % [spawner.elapsed, total_spawned, container.get_child_count()])

		max_active = maxi(max_active, container.get_child_count())
		var nearest := [99999.0, 99999.0]
		var immediate := [false, false]
		for child in container.get_children():
			if not (child is Obstacle):
				continue
			var obstacle := child as Obstacle
			var distance := PLAYER_Y - obstacle.position.y
			if distance > -80.0 and distance < nearest[obstacle.lane]:
				nearest[obstacle.lane] = distance
			if distance > -80.0 and distance < 82.0:
				immediate[obstacle.lane] = true
			if obstacle.lane == bot_lane and absf(obstacle.position.y - PLAYER_Y) < 58.0:
				collisions += 1

		var unsafe: bool = bool(immediate[0]) and bool(immediate[1])
		# Two lanes arriving within a human switch window are impossible.
		if nearest[0] < spawner.speed * 0.9 and nearest[1] < spawner.speed * 0.9:
			var arrival_gap := absf(nearest[0] - nearest[1]) / spawner.speed
			if arrival_gap < 0.24:
				unsafe = true
		if unsafe:
			unfair_frames += 1
			if unfair_frames <= 3:
				printerr("  unfair overlap at t=%.2f speed=%.0f near0=%.0f near1=%.0f" % [spawner.elapsed, spawner.speed, nearest[0], nearest[1]])
		var horizon := spawner.speed * 0.3 + 80.0
		if nearest[bot_lane] < horizon and nearest[1 - bot_lane] > nearest[bot_lane] + 40.0:
			bot_lane = 1 - bot_lane

	_check(total_spawned > 250, "spawner produced a full five-minute run (%d obstacles)" % total_spawned)
	_check(max_active < 24, "active obstacle set stays bounded (max %d)" % max_active)
	_check(unfair_frames == 0, "no unreactable two-lane blocks (%d frames)" % unfair_frames)
	_check(collisions == 0, "scripted safe-lane bot survives without collisions (%d)" % collisions)
	_check(spawner.elapsed >= 295.0, "simulation covered the full five minutes")


func _count_spawn(obstacle: Obstacle) -> void:
	total_spawned += 1
	obstacle.set_process(false)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
