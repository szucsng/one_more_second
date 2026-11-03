extends Node
## Daily challenge persistence / duplicate-reward integration test.
##   godot --headless --path . res://tests/ChallengeTest.tscn

var failures: int = 0
var _original: Dictionary = {}
var _reward_count: int = 0


func _ready() -> void:
	_original = SaveManager.get_challenge_data()
	await _run()
	SaveManager.set_challenge_data(_original, true)
	Challenges.reload()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	# Start from a clean copy of today's set.
	var state := _original.duplicate(true)
	state["date"] = Time.get_date_string_from_system()
	if not (state.get("set") is Array) or (state["set"] as Array).size() != ChallengeCatalog.DAILY_SET_SIZE:
		state["set"] = ChallengeCatalog.generate(String(state["date"]))
	state["completed"] = []
	state["progress"] = {
		"dodges": 0,
		"perfects": 0,
		"max_combo": 0,
		"best_score": 0,
		"best_survival": 0.0,
	}
	SaveManager.set_challenge_data(state, false)
	Challenges.reload()
	Challenges.challenge_completed.connect(func(_challenge: Dictionary) -> void:
		_reward_count += 1
	)

	var challenges := Challenges.get_challenges()
	_check(challenges.size() == 3, "three daily challenges load")
	_check(Challenges.get_completed_count() == 0, "daily progress starts clean")

	var dodge_target := 0
	for challenge in challenges:
		if String(challenge.get("type", "")) == "dodges":
			dodge_target = int(challenge.get("target", 0))
			break
	_check(dodge_target > 0, "dodges challenge is present")
	Challenges.record_dodge(dodge_target)
	_check(Challenges.get_completed_count() == 1, "dodge challenge completes at its target")
	_check(_reward_count == 1, "completion emits exactly one reward")

	Challenges.record_dodge(1)
	_check(_reward_count == 1, "same challenge cannot reward twice")
	_check(Challenges.get_completed_count() == 1, "completed count stays stable")

	# Progress is persisted through the existing save file.
	SaveManager.save_now()
	SaveManager.load_game()
	Challenges.reload()
	_check(Challenges.get_completed_count() == 1, "completed challenge survives save reload")

	# A stale date rolls into a fresh local set while preserving lifetime count.
	var old := SaveManager.get_challenge_data()
	old["date"] = "2000-01-01"
	old["total_completed"] = 7
	old["progress"] = {"dodges": 5, "perfects": 5, "max_combo": 5, "best_score": 5, "best_survival": 5.0}
	old["completed"] = ["2000-01-01:dodges"]
	SaveManager.set_challenge_data(old, false)
	Challenges.reload()
	_check(Challenges.get_date() == Time.get_date_string_from_system(), "stale date rolls to today")
	_check(Challenges.get_completed_count() == 0, "stale completion list is cleared")
	_check(Challenges.get_total_completed_lifetime() == 7, "lifetime completion count is preserved")
	_check(int(SaveManager.get_challenge_data().get("progress", {}).get("dodges", -1)) == 0, "daily counters reset on a new day")

	# The manager's progress values are exposed to the UI.
	Challenges.record_dodge(2)
	var refreshed := Challenges.get_challenges()
	var dodge_progress := -1
	var dodge_ratio := 0.0
	for challenge in refreshed:
		if String(challenge.get("type", "")) == "dodges":
			dodge_progress = int(challenge.get("progress_value", 0))
			dodge_ratio = float(challenge.get("progress_ratio", 0.0))
	_check(dodge_progress == 2, "daily dodge progress is exposed to the UI")
	_check(dodge_ratio > 0.0, "daily progress ratio is positive")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
