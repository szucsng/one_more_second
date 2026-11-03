extends Node
## Pure unit tests for scoring, difficulty limits and daily challenge catalog.
##   godot --headless --path . res://tests/ScoringTest.tscn

var failures: int = 0


func _ready() -> void:
	_test_scoring()
	_test_difficulty()
	_test_challenge_catalog()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _test_scoring() -> void:
	_check(Scoring.multiplier_for(0) == 1, "combo 0 is 1x")
	_check(Scoring.multiplier_for(4) == 1, "combo 4 is 1x")
	_check(Scoring.multiplier_for(5) == 2, "combo 5 is 2x")
	_check(Scoring.multiplier_for(9) == 2, "combo 9 is 2x")
	_check(Scoring.multiplier_for(10) == 3, "combo 10 is 3x")
	_check(Scoring.multiplier_for(19) == 3, "combo 19 is 3x")
	_check(Scoring.multiplier_for(20) == 4, "combo 20 is 4x")
	_check(Scoring.multiplier_for(29) == 4, "combo 29 is 4x")
	_check(Scoring.multiplier_for(30) == 5, "combo 30 is 5x")
	_check(Scoring.multiplier_for(999) == 5, "combo multiplier caps at 5x")
	_check(Scoring.obstacle_points(5) == 2, "fifth dodge scores 2 points")
	_check(Scoring.obstacle_points(10) == 3, "tenth dodge scores 3 points")
	var expected_total := 0
	for combo in range(1, 11):
		expected_total += Scoring.obstacle_points(combo)
	_check(expected_total == 17, "ten-dodge combo score total is 17")
	for milestone in [5, 10, 20, 30]:
		_check(Scoring.is_milestone(milestone), "combo %d is a milestone" % milestone)
	_check(not Scoring.is_milestone(6), "non-milestone combo is not a milestone")
	_check(Scoring.combo_progress(0) == 0.0, "combo progress starts at 0")
	_check(is_equal_approx(Scoring.combo_progress(5), 0.0), "combo progress resets at a milestone")
	_check(is_equal_approx(Scoring.combo_progress(7), 0.4), "combo progress moves to the next tier")
	_check(is_equal_approx(Scoring.combo_progress(30), 1.0), "max combo progress is full")
	_check(Scoring.PERFECT_WINDOW > Scoring.PERFECT_MIN_TIME, "perfect window is wider than the escape floor")
	_check(Scoring.perfect_distance(1500.0) > 300.0, "perfect distance scales with speed")


func _test_difficulty() -> void:
	_check(is_equal_approx(Difficulty.speed_at(0.0), Difficulty.START_SPEED), "start speed matches")
	_check(is_equal_approx(Difficulty.speed_at(10_000.0), Difficulty.MAX_SPEED), "speed caps at max")
	var previous := 0.0
	var monotonic := true
	for second in range(0, 130):
		var current := Difficulty.speed_at(float(second))
		if current + 0.001 < previous:
			monotonic = false
		previous = current
	_check(monotonic, "speed is monotonic")
	var interval_floor := 999.0
	for second in range(0, 130):
		interval_floor = minf(interval_floor, Difficulty.spawn_interval_at(float(second)))
	_check(interval_floor >= Difficulty.MIN_INTERVAL - 0.0001, "spawn interval respects its floor")
	_check(Difficulty.spawn_interval_at(10_000.0) >= Difficulty.MIN_INTERVAL - 0.0001, "endgame interval shrinks to the floor")

	var at_start := Difficulty.allowed_patterns(0.0)
	_check(at_start == ["single"], "only singles at the start")
	_check("stagger" in Difficulty.allowed_patterns(9.0), "stagger unlocks gradually")
	_check(not ("zigzag" in Difficulty.allowed_patterns(9.0)), "zigzag is locked early")
	_check("zigzag" in Difficulty.allowed_patterns(23.0), "zigzag unlocks at its threshold")
	_check("gauntlet" in Difficulty.allowed_patterns(80.0), "gauntlet is available late")
	_check(Difficulty.recovery_due(Difficulty.RECOVERY_TIMES[0], 0), "first recovery is due at its time")
	_check(not Difficulty.recovery_due(0.0, 0), "no recovery at run start")
	_check(Difficulty.RECOVERY_DURATION >= 2.0, "recovery lasts long enough to breathe")


func _test_challenge_catalog() -> void:
	var first := ChallengeCatalog.generate("2026-11-03")
	var repeat := ChallengeCatalog.generate("2026-11-03")
	var next_day := ChallengeCatalog.generate("2026-11-04")
	_check(first.size() == ChallengeCatalog.DAILY_SET_SIZE, "daily set has three challenges")
	_check(JSON.stringify(first) == JSON.stringify(repeat), "same date gives the same daily set")
	_check(JSON.stringify(first) != JSON.stringify(next_day), "different dates give different sets")
	_check(String(first[0]["type"]) == "dodges", "first challenge is always dodges")
	_check(String(first[1]["type"]) == "perfects", "second challenge is always perfects")
	_check(not String(first[2]["type"]).is_empty(), "third challenge rotates")
	var types := {}
	for challenge in first:
		types[String(challenge["type"])] = true
		_check(int(challenge["target"]) > 0, "challenge target is positive")
		_check(int(challenge["reward"]) > 0, "challenge has a score reward")
		_check(not String(challenge["description"]).is_empty(), "challenge has a description")
	_check(types.size() == 3, "daily challenge types are unique")
	var progress := {"dodges": 18, "perfects": 0, "max_combo": 0, "best_score": 0, "best_survival": 0.0}
	var dodge_challenge := first[0]
	_check(ChallengeCatalog.is_met(dodge_challenge, progress), "met challenge is detected")
	_check(not ChallengeCatalog.is_met(first[1], progress), "unmet challenge is detected")
	_check(ChallengeCatalog.progress_ratio(first[1], progress) == 0.0, "empty challenge progress is zero")
	_check(ChallengeCatalog.format_progress(first[1], progress).contains("/"), "progress text is readable")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
