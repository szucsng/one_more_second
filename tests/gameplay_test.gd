extends Node
## Headless integration test for the core loop, save system and revive flow.
##   godot --headless --path . res://tests/GameplayTest.tscn

var failures: int = 0
var _gameplay: Node


func _ready() -> void:
	await _run()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.8)
	_check(SceneRouter.get_current_screen() != null, "menu screen boots")

	SceneRouter.go_gameplay()
	await _wait(0.9)
	_gameplay = SceneRouter.get_current_screen()
	_check(_gameplay != null, "gameplay screen loads")
	if _gameplay == null:
		return

	var spawner: ObstacleSpawner = _gameplay.get_node("%Spawner")
	var player: PlayerShip = _gameplay.get_node("%Player")
	var game_over: GameOverScreen = _gameplay.get_node("%GameOver")
	var hud: GameHUD = _gameplay.get_node("%HUD")
	spawner.set_frozen(true)
	await _wait(0.1)

	_check(spawner.active, "spawner is running")
	_check(player.alive, "player is alive at start")
	_check(hud.visible, "HUD is present")

	# Actual pointer events must reach the playfield rather than being swallowed by
	# the root Control. This catches UI mouse-filter regressions.
	var lane_before := player.lane
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(540, 800)
	Input.parse_input_event(touch)
	await get_tree().process_frame
	await _wait(0.12)
	_check(player.lane != lane_before, "touch tap switches lanes")
	lane_before = player.lane
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(540, 800)
	Input.parse_input_event(click)
	await get_tree().process_frame
	await _wait(0.12)
	_check(player.lane != lane_before, "mouse click switches lanes")

	# Score one obstacle manually.
	spawner.call("_spawn_obstacle", 0, 0, 0)
	await get_tree().physics_frame
	var container: Node2D = _gameplay.get_node("World/Obstacles")
	_check(container.get_child_count() > 0, "obstacle spawns")
	var obstacle: Obstacle = null
	for child in container.get_children():
		if child is Obstacle:
			obstacle = child
			break
	if obstacle == null:
		_check(false, "obstacle instance exists")
		return
	obstacle.position.y = Obstacle.PASS_Y - 4.0
	obstacle.moving = true
	await _wait(0.2)
	_check(int(_gameplay.get("score")) >= 1, "passing an obstacle scores a point")

	# Collision kills the player and shows game over.
	var score_before := int(_gameplay.get("score"))
	var games_before := int(SaveManager.get_stats().get("games_played", 0))
	obstacle.global_position = player.global_position
	obstacle.moving = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.1)
	_check(not player.alive, "obstacle collision kills the player")
	await _wait(1.0)
	_check(game_over.visible, "game over overlay appears after death")
	_check(int(_gameplay.get("state")) == 3, "state is GAME_OVER")

	# Restart records the run exactly once.
	_gameplay.call("_restart_from_game_over")
	await _wait(0.3)
	_check(int(_gameplay.get("score")) == 0, "restart resets score")
	_check(player.alive, "restart revives player")
	var stats := SaveManager.get_stats()
	_check(int(stats.get("games_played", 0)) == games_before + 1, "restart records exactly one game")
	_check(SaveManager.get_best_score() >= score_before, "best score is updated")
	_check(FileAccess.file_exists(GameConfig.SAVE_PATH), "save file exists")

	# Pause / resume.
	spawner.set_frozen(true)
	_gameplay.call("pause_game")
	await _wait(0.1)
	_check(int(_gameplay.get("state")) == 1, "pause sets PAUSED")
	_check(spawner.frozen, "spawner freezes while paused")
	_gameplay.call("resume_game")
	await _wait(0.1)
	_check(int(_gameplay.get("state")) == 0, "resume returns to RUNNING")

	# Rewarded revive (simulated test placement).
	spawner.stop()
	player.kill()
	await _wait(1.0)
	_check(game_over.visible, "second game over shows")
	_gameplay.call("_request_continue")
	await _wait(0.2)
	_check(Ads.is_ad_open(), "test rewarded overlay opens")
	var overlay: CanvasLayer = Ads.get("_overlay")
	if overlay != null:
		overlay.set("_remaining", 0.0)
		overlay.call("_on_claim")
		await _wait(0.2)
	_check(bool(_gameplay.get("revive_used")), "revive was consumed")
	_check(int(_gameplay.get("state")) == 0, "game continues after reward")
	_check(player.alive, "player is revived")

	# Persistence round-trip.
	SaveManager.save_now()
	var best_before := SaveManager.get_best_score()
	SaveManager.load_game()
	_check(SaveManager.get_best_score() == best_before, "best score survives save reload")
	_check(FileAccess.file_exists("%s/events-%s.jsonl" % [GameConfig.ANALYTICS_DIR, Time.get_date_string_from_system()]), "local analytics log is written")

	# Skin and settings persistence round-trip (restore the original values).
	var original_skin := SaveManager.get_selected_skin()
	var alternate_skin := "pink" if original_skin != "pink" else "cyan"
	_check(SkinManager.select(alternate_skin), "alternate skin selects")
	_check(SaveManager.get_selected_skin() == alternate_skin, "selected skin is stored")
	SaveManager.load_game()
	_check(SaveManager.get_selected_skin() == alternate_skin, "selected skin survives reload")
	SkinManager.select(original_skin)

	var original_volume := float(SaveManager.get_setting("volume"))
	SaveManager.set_setting("volume", 0.42)
	SaveManager.load_game()
	_check(is_equal_approx(float(SaveManager.get_setting("volume")), 0.42), "volume survives reload")
	SaveManager.set_setting("volume", original_volume)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
