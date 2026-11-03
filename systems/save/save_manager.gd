extends Node
## Persistent local save system.
##
## Everything is stored in a single JSON file under `user://` with a rotating
## backup. Writes are verified before the live file is replaced, so a crash
## during save cannot silently wipe the player's records.

signal settings_changed
signal progress_changed
signal skin_changed

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const TEMP_PATH := "user://save.tmp"
const SAVE_VERSION := 2

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_now()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"best_score": 0,
		"stats": {
			"games_played": 0,
			"total_score": 0,
			"best_survival_time": 0.0,
			"total_play_time": 0.0,
			"obstacles_avoided": 0,
			"revives_used": 0,
			"best_combo": 0,
			"perfect_dodges": 0,
		},
		"settings": {
			"sfx": true,
			"music": true,
			"vibration": true,
			"volume": 0.8,
			"reduced_effects": false,
			"analytics": true,
			"fullscreen": false,
		},
		"skins": {
			"selected": "default",
			"unlocked": ["default", "cyan", "purple", "pink", "gold"],
		},
		"ads": {
			"rewarded_views": 0,
			"interstitial_views": 0,
			"last_interstitial_unix": 0,
			"runs_since_interstitial": 0,
		},
		"flags": {
			"onboarding_seen": false,
		},
		"challenges": {
			"date": "",
			"set": [],
			"progress": {
				"dodges": 0,
				"perfects": 0,
				"max_combo": 0,
				"best_score": 0,
				"best_survival": 0.0,
			},
			"completed": [],
			"total_completed": 0,
		},
	}


func load_game() -> void:
	data = _defaults()
	var loaded := _read_json(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read_json(BACKUP_PATH)
		if not loaded.is_empty():
			push_warning("SaveManager: primary save unreadable, restored from backup.")
	if not loaded.is_empty():
		_merge_into(loaded, _defaults())
		data = loaded
	_sanitize()
	if loaded.is_empty() and not FileAccess.file_exists(SAVE_PATH):
		save_now()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open %s (error %d)." % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		push_warning("SaveManager: invalid save data at %s." % path)
		return {}
	return parser.data as Dictionary


func _merge_into(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		var fallback: Variant = defaults[key]
		if not target.has(key):
			target[key] = _copy_value(fallback)
			continue
		var current: Variant = target[key]
		if fallback is int and (current is int or current is float):
			target[key] = int(current)
		elif fallback is float and (current is int or current is float):
			target[key] = float(current)
		elif fallback is Dictionary and current is Dictionary:
			_merge_into(current as Dictionary, fallback as Dictionary)
		elif fallback is Array and current is Array:
			pass
		elif typeof(current) != typeof(fallback):
			target[key] = _copy_value(fallback)


func _copy_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _sanitize() -> void:
	if not (data.get("settings") is Dictionary) or not (data.get("stats") is Dictionary):
		data = _defaults()
		return
	var settings: Dictionary = data["settings"]
	settings["volume"] = clampf(float(settings.get("volume", 0.8)), 0.0, 1.0)
	for flag: String in ["sfx", "music", "vibration", "reduced_effects", "analytics", "fullscreen"]:
		settings[flag] = bool(settings.get(flag, true))
	settings["fullscreen"] = bool(settings.get("fullscreen", false))

	var stats: Dictionary = data["stats"]
	stats["games_played"] = maxi(0, int(stats.get("games_played", 0)))
	stats["total_score"] = maxi(0, int(stats.get("total_score", 0)))
	stats["best_survival_time"] = maxf(0.0, float(stats.get("best_survival_time", 0.0)))
	stats["total_play_time"] = maxf(0.0, float(stats.get("total_play_time", 0.0)))
	stats["obstacles_avoided"] = maxi(0, int(stats.get("obstacles_avoided", 0)))
	stats["revives_used"] = maxi(0, int(stats.get("revives_used", 0)))
	stats["best_combo"] = maxi(0, int(stats.get("best_combo", 0)))
	stats["perfect_dodges"] = maxi(0, int(stats.get("perfect_dodges", 0)))
	data["best_score"] = maxi(0, int(data.get("best_score", 0)))

	var skins: Dictionary = data.get("skins", {})
	if not (skins.get("unlocked") is Array):
		skins["unlocked"] = ["default", "cyan", "purple", "pink", "gold"]
	var selected := String(skins.get("selected", "default"))
	if selected.is_empty():
		selected = "default"
	skins["selected"] = selected
	data["skins"] = skins

	var ads: Dictionary = data.get("ads", {})
	ads["rewarded_views"] = maxi(0, int(ads.get("rewarded_views", 0)))
	ads["interstitial_views"] = maxi(0, int(ads.get("interstitial_views", 0)))
	ads["last_interstitial_unix"] = maxf(0.0, float(ads.get("last_interstitial_unix", 0)))
	ads["runs_since_interstitial"] = maxi(0, int(ads.get("runs_since_interstitial", 0)))
	data["ads"] = ads

	var challenges: Dictionary = data.get("challenges", {})
	if challenges.get("date") is String:
		pass
	else:
		challenges["date"] = ""
	if not (challenges.get("set") is Array):
		challenges["set"] = []
	if not (challenges.get("completed") is Array):
		challenges["completed"] = []
	if not (challenges.get("progress") is Dictionary):
		challenges["progress"] = {}
	var progress: Dictionary = challenges["progress"]
	progress["dodges"] = maxi(0, int(progress.get("dodges", 0)))
	progress["perfects"] = maxi(0, int(progress.get("perfects", 0)))
	progress["max_combo"] = maxi(0, int(progress.get("max_combo", 0)))
	progress["best_score"] = maxi(0, int(progress.get("best_score", 0)))
	progress["best_survival"] = maxf(0.0, float(progress.get("best_survival", 0.0)))
	challenges["progress"] = progress
	challenges["total_completed"] = maxi(0, int(challenges.get("total_completed", 0)))
	data["challenges"] = challenges


func save_now() -> void:
	if data.is_empty():
		return
	data["version"] = SAVE_VERSION
	var payload := JSON.stringify(data, "\t")
	var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp == null:
		push_error("SaveManager: cannot write save file (%d)." % FileAccess.get_open_error())
		return
	temp.store_string(payload)
	temp.flush()
	temp.close()

	var verify := _read_json(TEMP_PATH)
	if verify.is_empty():
		push_error("SaveManager: save verification failed, keeping previous file.")
		return

	if FileAccess.file_exists(SAVE_PATH):
		var existing := FileAccess.get_file_as_bytes(SAVE_PATH)
		if not existing.is_empty():
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_buffer(existing)
				backup.flush()
				backup.close()

	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_target := ProjectSettings.globalize_path(SAVE_PATH)
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if rename_error != OK:
		# Some platforms cannot atomically replace; fall back to a direct copy.
		var target := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if target == null:
			push_error("SaveManager: rename and fallback write failed (%d)." % rename_error)
			return
		target.store_string(payload)
		target.flush()
		target.close()
		DirAccess.remove_absolute(absolute_temp)


func get_setting(key: String) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, null)


func set_setting(key: String, value: Variant) -> bool:
	var settings: Dictionary = data.get("settings", {})
	if not settings.has(key):
		push_warning("SaveManager: unknown setting '%s'." % key)
		return false
	if typeof(settings[key]) != typeof(value):
		push_warning("SaveManager: setting '%s' type mismatch." % key)
		return false
	if settings[key] == value:
		return true
	settings[key] = value
	save_now()
	if key == "analytics":
		Analytics.set_enabled(bool(value))
	settings_changed.emit()
	return true


func get_best_score() -> int:
	return int(data.get("best_score", 0))


func get_stats() -> Dictionary:
	return data.get("stats", {}).duplicate(true)


func get_selected_skin() -> String:
	var skins: Dictionary = data.get("skins", {})
	return String(skins.get("selected", "default"))


func set_selected_skin(skin_id: String) -> void:
	var skins: Dictionary = data.get("skins", {})
	if skins.get("selected", "") == skin_id:
		return
	skins["selected"] = skin_id
	data["skins"] = skins
	save_now()
	skin_changed.emit()


func is_skin_unlocked(skin_id: String) -> bool:
	var skins: Dictionary = data.get("skins", {})
	var unlocked: Array = skins.get("unlocked", [])
	return unlocked.has(skin_id)


func unlock_skin(skin_id: String) -> void:
	var skins: Dictionary = data.get("skins", {})
	var unlocked: Array = skins.get("unlocked", [])
	if not unlocked.has(skin_id):
		unlocked.append(skin_id)
		skins["unlocked"] = unlocked
		data["skins"] = skins
		save_now()
		skin_changed.emit()


## Records a finished (or abandoned) run. Returns the previous best score.
func record_run(score: int, duration: float, obstacles: int = 0, max_combo: int = 0, perfects: int = 0) -> int:
	var previous_best := get_best_score()
	var stats: Dictionary = data["stats"]
	stats["games_played"] = int(stats["games_played"]) + 1
	stats["total_score"] = int(stats["total_score"]) + maxi(0, score)
	stats["best_survival_time"] = maxf(float(stats["best_survival_time"]), maxf(0.0, duration))
	stats["total_play_time"] = float(stats["total_play_time"]) + maxf(0.0, duration)
	stats["obstacles_avoided"] = int(stats["obstacles_avoided"]) + maxi(0, obstacles)
	stats["best_combo"] = maxi(int(stats["best_combo"]), maxi(0, max_combo))
	stats["perfect_dodges"] = int(stats["perfect_dodges"]) + maxi(0, perfects)
	data["best_score"] = maxi(previous_best, score)

	var ads: Dictionary = data["ads"]
	ads["runs_since_interstitial"] = int(ads["runs_since_interstitial"]) + 1

	save_now()
	progress_changed.emit()
	return previous_best


func record_rewarded_view() -> void:
	data["ads"]["rewarded_views"] = int(data["ads"]["rewarded_views"]) + 1
	data["stats"]["revives_used"] = int(data["stats"]["revives_used"]) + 1
	save_now()


func record_interstitial_view() -> void:
	var ads: Dictionary = data["ads"]
	ads["interstitial_views"] = int(ads["interstitial_views"]) + 1
	ads["last_interstitial_unix"] = Time.get_unix_time_from_system()
	ads["runs_since_interstitial"] = 0
	save_now()


func get_challenge_data() -> Dictionary:
	return data.get("challenges", {}).duplicate(true)


func set_challenge_data(challenge_data: Dictionary, persist: bool = true) -> void:
	data["challenges"] = challenge_data.duplicate(true)
	if persist:
		save_now()


func reset_progress() -> void:
	var best_before := get_best_score()
	data["best_score"] = 0
	var settings: Dictionary = data["settings"]
	var skins: Dictionary = data["skins"]
	var ads: Dictionary = data["ads"]
	data = _defaults()
	data["settings"] = settings
	data["skins"] = skins
	data["ads"] = ads
	save_now()
	if best_before != 0:
		progress_changed.emit()
