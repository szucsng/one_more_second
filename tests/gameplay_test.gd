extends Node
## Headless integration test for the core loop, combo/perfect scoring, save
## system, daily challenge rewards and revive flow.
##   godot --headless --path . res://tests/GameplayTest.tscn

var failures: int = 0
var _gameplay: Node
var _original_challenges: Dictionary = {}
var _challenge_snapshot_ready: bool = false


func _ready() -> void:
	_prepare_isolated_challenges()
	await _run()
	_restore_challenges()
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

	# Score one obstacle manually. Combo must increment exactly once.
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
	_check(int(_gameplay.get("score")) == 1, "passing an obstacle scores one point")
	_check(int(_gameplay.get("combo")) == 1, "first dodge starts a combo")

	# Collision kills the player, resets combo and shows game over.
	var score_before := int(_gameplay.get("score"))
	var games_before := int(SaveManager.get_stats().get("games_played", 0))
	obstacle.global_position = player.global_position
	obstacle.moving = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.1)
	_check(not player.alive, "obstacle collision kills the player")
	_check(int(_gameplay.get("combo")) == 0, "collision resets the combo")
	await _wait(1.0)
	_check(game_over.visible, "game over overlay appears after death")
	_check(int(_gameplay.get("state")) == 3, "state is GAME_OVER")

	# Restart records the run exactly once and resets combo state.
	_gameplay.call("_restart_from_game_over")
	await _wait(0.3)
	_check(int(_gameplay.get("score")) == 0, "restart resets score")
	_check(int(_gameplay.get("combo")) == 0, "restart resets combo")
	_check(player.alive, "restart revives player")
	var stats := SaveManager.get_stats()
	_check(int(stats.get("games_played", 0)) == games_before + 1, "restart records exactly one game")
	_check(SaveManager.get_best_score() >= score_before, "best score is updated")
	_check(FileAccess.file_exists(GameConfig.SAVE_PATH), "save file exists")

	# Combo and multiplier scoring. Ten safe-lane dodges must produce exactly:
	# 1+1+1+1+2 (combo 5) then 2+2+2+2+3 (combo 10) = 17 points.
	spawner.set_frozen(true)
	spawner.clear_all()
	await _wait(0.05)
	var expected_scores := [1, 2, 3, 4, 6, 8, 10, 12, 14, 17]
	var combo_sequence_ok := true
	for index in 10:
		await _force_pass(spawner, 1)
		if int(_gameplay.get("combo")) != index + 1:
			combo_sequence_ok = false
		if int(_gameplay.get("score")) != expected_scores[index]:
			combo_sequence_ok = false
	_check(combo_sequence_ok, "combo increments once per dodge and multipliers apply")
	_check(int(_gameplay.get("combo")) == 10, "combo reaches 10")
	_check(int(_gameplay.get("max_combo")) == 10, "max combo tracks the peak")
	_check(int(_gameplay.get("dodges")) == 10, "dodge counter matches obstacles")
	_check(hud.get_node("%ComboChip").visible, "HUD shows the active combo")

	# Perfect dodge: a near switch marks the obstacle, and the bonus is only
	# confirmed when the obstacle passes. Repeated switches cannot double-award.
	spawner.clear_all()
	await _wait(0.05)
	var perfect_obstacle := await _spawn_obstacle(spawner, 0)
	perfect_obstacle.speed = 700.0
	perfect_obstacle.position = Vector2(PlayerShip.LANE_X[0], Palette.PLAYER_Y - 140.0)
	perfect_obstacle.moving = false
	var perfect_before := int(_gameplay.get("perfect_dodges"))
	var perfect_score_before := int(_gameplay.get("score"))
	await _wait(0.12)
	_gameplay.call("_switch_lane")
	await _wait(0.12)
	_check(perfect_obstacle.perfect_pending, "near switch marks a perfect dodge")
	_gameplay.call("_switch_lane")
	await _wait(0.12)
	_gameplay.call("_switch_lane")
	await _wait(0.12)
	perfect_obstacle.position.y = Obstacle.PASS_Y - 4.0
	perfect_obstacle.moving = true
	await _wait(0.25)
	_check(int(_gameplay.get("perfect_dodges")) == perfect_before + 1, "perfect dodge awards exactly once")
	_check(perfect_obstacle.perfect_awarded, "obstacle is marked as awarded")
	_check(not perfect_obstacle.perfect_pending, "pending flag clears after the pass")
	_check(
		int(_gameplay.get("score")) == perfect_score_before + Scoring.obstacle_points(11) + Scoring.PERFECT_BONUS,
		"perfect dodge adds the expected bonus points"
	)
	var perfect_after_award := int(_gameplay.get("perfect_dodges"))
	_gameplay.call("_award_perfect_dodge", perfect_obstacle)
	await get_tree().process_frame
	_check(int(_gameplay.get("perfect_dodges")) == perfect_after_award, "duplicate perfect award is blocked")
	spawner.clear_all()
	await _wait(0.05)
	var perfect_after := int(_gameplay.get("perfect_dodges"))
	_gameplay.call("_switch_lane")
	await _wait(0.12)
	_check(int(_gameplay.get("perfect_dodges")) == perfect_after, "a safe switch awards no perfect dodge")

	# Pause / resume keeps combo state.
	var combo_before_pause := int(_gameplay.get("combo"))
	spawner.set_frozen(true)
	_gameplay.call("pause_game")
	await _wait(0.1)
	_check(int(_gameplay.get("state")) == 1, "pause sets PAUSED")
	_check(spawner.frozen, "spawner freezes while paused")
	_gameplay.call("resume_game")
	await _wait(0.1)
	_check(int(_gameplay.get("state")) == 0, "resume returns to RUNNING")
	_check(int(_gameplay.get("combo")) == combo_before_pause, "combo survives pause/resume")

	# Rewarded revive (simulated test placement).
	var games_before_death := int((SaveManager.data["stats"] as Dictionary)["games_played"])
	var best_before_death := SaveManager.get_best_score()
	spawner.stop()
	player.kill()
	await _wait(1.0)
	_check(game_over.visible, "second game over shows")
	_check(int((SaveManager.data["stats"] as Dictionary)["games_played"]) == games_before_death + 1, "game over persists run stats immediately")
	_check(SaveManager.get_best_score() >= int(_gameplay.get("score")), "game over persists the record immediately")
	_check(int(_gameplay.get("combo")) == 0, "death clears combo before revive")
	_check(str(game_over.get_node("%ComboValue").text) == str(int(_gameplay.get("max_combo"))), "game over reports max combo")
	_gameplay.call("_request_continue")
	await _wait(0.2)
	_check(Ads.is_ad_open(), "test rewarded overlay opens")
	var overlay: Node = _find_test_ad(get_tree().root)
	if overlay != null:
		overlay.set("_remaining", 0.0)
		overlay.call("_on_claim")
		await _wait(0.4)
	_check(bool(_gameplay.get("revive_used")), "revive was consumed")
	_check(int((SaveManager.data["stats"] as Dictionary)["games_played"]) == games_before_death, "revive rolls back the provisional run record")
	_check(SaveManager.get_best_score() == best_before_death, "provisional record is rolled back on revive")
	_check(int(_gameplay.get("state")) == 0, "game continues after reward")
	_check(player.alive, "player is revived")

	# A run can be revived only once; the second death offers no ad reward.
	spawner.stop()
	player.kill()
	await _wait(1.0)
	_check(game_over.visible, "game over returns after the revived run")
	_check(int((SaveManager.data["stats"] as Dictionary)["games_played"]) == games_before_death + 1, "the revived run is recorded once on its final death")
	_check(bool(_gameplay.get("revive_used")), "revive limit remains consumed")
	_check(not Ads.can_show_rewarded_ad(), "no rewarded ad is offered after the revive limit")
	_check(not game_over.get_node("%ContinueButton").visible, "continue button is hidden after one revive")
	_gameplay.call("_restart_from_game_over")
	await _wait(0.3)
	_check(int((SaveManager.data["stats"] as Dictionary)["games_played"]) == games_before_death + 1, "restart does not double-count the run")

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

	# Challenge reward integration: one fresh dodge challenge, one reward, no
	# duplicate reward when the same event is recorded again.
	var reward_before := int(_gameplay.get("score"))
	var isolated := _original_challenges.duplicate(true)
	isolated["date"] = Time.get_date_string_from_system()
	isolated["completed"] = []
	isolated["progress"] = {
		"dodges": 0,
		"perfects": 0,
		"max_combo": 0,
		"best_score": 0,
		"best_survival": 0.0,
	}
	var reward_value := 20
	if not (isolated["set"] as Array).is_empty():
		(isolated["set"][0] as Dictionary)["target"] = 1
		reward_value = int((isolated["set"][0] as Dictionary)["reward"])
	SaveManager.set_challenge_data(isolated, false)
	Challenges.reload()
	Challenges.record_dodge(1)
	await get_tree().process_frame
	_check(int(_gameplay.get("score")) == reward_before + reward_value, "challenge reward is added to the run score")
	var score_after_reward := int(_gameplay.get("score"))
	Challenges.record_dodge(1)
	await get_tree().process_frame
	_check(int(_gameplay.get("score")) == score_after_reward, "completed challenge does not reward twice")


func _prepare_isolated_challenges() -> void:
	_original_challenges = SaveManager.get_challenge_data()
	var isolated := _original_challenges.duplicate(true)
	isolated["date"] = Time.get_date_string_from_system()
	if not (isolated.get("set") is Array) or (isolated["set"] as Array).size() != ChallengeCatalog.DAILY_SET_SIZE:
		isolated["set"] = ChallengeCatalog.generate(String(isolated["date"]))
	isolated["progress"] = {
		"dodges": 0,
		"perfects": 0,
		"max_combo": 0,
		"best_score": 0,
		"best_survival": 0.0,
	}
	var completed: Array = []
	for raw in isolated["set"]:
		if raw is Dictionary:
			completed.append(String((raw as Dictionary).get("id", "")))
	isolated["completed"] = completed
	SaveManager.set_challenge_data(isolated, false)
	Challenges.reload()
	_challenge_snapshot_ready = true


func _restore_challenges() -> void:
	if not _challenge_snapshot_ready:
		return
	SaveManager.set_challenge_data(_original_challenges, true)
	Challenges.reload()


func _spawn_obstacle(spawner: ObstacleSpawner, lane: int) -> Obstacle:
	spawner.call("_spawn_obstacle", lane, 0, 0)
	await get_tree().physics_frame
	var container: Node2D = _gameplay.get_node("World/Obstacles")
	for index in range(container.get_child_count() - 1, -1, -1):
		var child := container.get_child(index)
		if child is Obstacle and (child as Obstacle).lane == lane:
			return child as Obstacle
	return null


func _force_pass(spawner: ObstacleSpawner, lane: int) -> void:
	var obstacle := await _spawn_obstacle(spawner, lane)
	if obstacle == null:
		return
	obstacle.position.y = Obstacle.PASS_Y - 4.0
	obstacle.moving = true
	await _wait(0.2)


func _find_test_ad(node: Node) -> Node:
	if node.get_script() != null and String(node.get_script().resource_path).ends_with("test_ad_overlay.gd"):
		return node
	for child in node.get_children():
		var found := _find_test_ad(child)
		if found != null:
			return found
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
