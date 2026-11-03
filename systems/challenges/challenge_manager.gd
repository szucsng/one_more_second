extends Node
## Local daily challenges. Deterministic date-seeded set, persisted through the
## existing SaveManager. No accounts, network or backend.

signal challenge_completed(challenge: Dictionary)
signal progress_changed

var _data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_daily()


## Must be called when entering the menu/gameplay/Challenge screen so a session
## left open across midnight rolls over cleanly.
func refresh_daily() -> void:
	var today := Time.get_date_string_from_system()
	var raw := SaveManager.get_challenge_data()
	var valid := String(raw.get("date", "")) == today \
		and raw.get("set") is Array and (raw["set"] as Array).size() == ChallengeCatalog.DAILY_SET_SIZE

	if valid:
		_data = raw
		_sanitize_loaded()
	else:
		var previous_total := int(raw.get("total_completed", 0))
		_data = {
			"date": today,
			"set": ChallengeCatalog.generate(today),
			"progress": {
				"dodges": 0,
				"perfects": 0,
				"max_combo": 0,
				"best_score": 0,
				"best_survival": 0.0,
			},
			"completed": [],
			"total_completed": maxi(0, previous_total),
		}
		SaveManager.set_challenge_data(_data, true)
	progress_changed.emit()


func reload() -> void:
	refresh_daily()


func get_date() -> String:
	return String(_data.get("date", ""))


func get_challenges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var progress: Dictionary = _progress()
	var completed: Array = _data.get("completed", [])
	for raw in _data.get("set", []):
		if not (raw is Dictionary):
			continue
		var challenge: Dictionary = (raw as Dictionary).duplicate(true)
		challenge["target"] = maxi(1, int(challenge.get("target", 1)))
		challenge["reward"] = maxi(0, int(challenge.get("reward", 0)))
		challenge["completed"] = completed.has(String(challenge.get("id", "")))
		challenge["progress_value"] = ChallengeCatalog.progress_value(challenge, progress)
		challenge["progress_ratio"] = ChallengeCatalog.progress_ratio(challenge, progress)
		challenge["progress_text"] = ChallengeCatalog.format_progress(challenge, progress)
		result.append(challenge)
	return result


func get_completed_count() -> int:
	var completed: Array = _data.get("completed", [])
	return mini(completed.size(), get_total_count())


func get_total_count() -> int:
	var set: Array = _data.get("set", [])
	return set.size()


func get_total_completed_lifetime() -> int:
	return int(_data.get("total_completed", 0))


func record_dodge(count: int = 1) -> void:
	var progress := _progress()
	progress["dodges"] = int(progress.get("dodges", 0)) + maxi(1, count)
	_save_progress(progress)
	_evaluate()


func record_perfect(count: int = 1) -> void:
	var progress := _progress()
	progress["perfects"] = int(progress.get("perfects", 0)) + maxi(1, count)
	_save_progress(progress)
	_evaluate()


func record_combo(value: int) -> void:
	var progress := _progress()
	if value > int(progress.get("max_combo", 0)):
		progress["max_combo"] = value
		_save_progress(progress)
		_evaluate()


func record_score(value: int) -> void:
	var progress := _progress()
	if value > int(progress.get("best_score", 0)):
		progress["best_score"] = value
		_save_progress(progress)
		_evaluate()


func record_survival(value: float) -> void:
	var progress := _progress()
	if value > float(progress.get("best_survival", 0.0)):
		progress["best_survival"] = value
		_save_progress(progress)
		_evaluate()


func _progress() -> Dictionary:
	var progress: Dictionary = _data.get("progress", {})
	return progress


func _save_progress(progress: Dictionary) -> void:
	_data["progress"] = progress
	SaveManager.set_challenge_data(_data, false)
	progress_changed.emit()


func _evaluate() -> void:
	var completed: Array = _data.get("completed", [])
	for raw in _data.get("set", []):
		if not (raw is Dictionary):
			continue
		var challenge: Dictionary = (raw as Dictionary).duplicate(true)
		challenge["target"] = maxi(1, int(challenge.get("target", 1)))
		challenge["reward"] = maxi(0, int(challenge.get("reward", 0)))
		var id := String(challenge.get("id", ""))
		if id.is_empty() or completed.has(id):
			continue
		if not ChallengeCatalog.is_met(challenge, _progress()):
			continue
		completed.append(id)
		_data["completed"] = completed
		_data["total_completed"] = int(_data.get("total_completed", 0)) + 1
		# Persist the completion before emitting, so a reward can never be claimed
		# twice - even if the scene is reloaded immediately.
		SaveManager.set_challenge_data(_data, true)
		challenge_completed.emit(challenge)
	progress_changed.emit()


func _sanitize_loaded() -> void:
	if not (_data.get("progress") is Dictionary):
		_data["progress"] = {}
	var progress: Dictionary = _data["progress"]
	progress["dodges"] = maxi(0, int(progress.get("dodges", 0)))
	progress["perfects"] = maxi(0, int(progress.get("perfects", 0)))
	progress["max_combo"] = maxi(0, int(progress.get("max_combo", 0)))
	progress["best_score"] = maxi(0, int(progress.get("best_score", 0)))
	progress["best_survival"] = maxf(0.0, float(progress.get("best_survival", 0.0)))
	if not (_data.get("completed") is Array):
		_data["completed"] = []
	_data["total_completed"] = maxi(0, int(_data.get("total_completed", 0)))
