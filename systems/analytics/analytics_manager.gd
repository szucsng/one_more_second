extends Node
## Privacy-first analytics layer.
##
## v1 writes JSONL files locally under `user://analytics/` and never sends any
## data over the network. A future backend adapter can be attached by replacing
## `_write_event`, without changing any call sites.

const SESSION_HEADER := "ONE MORE SECOND analytics"
const MAX_FILE_BYTES := 512 * 1024
const ALLOWED_EVENTS := [
	"session_started",
	"session_ended",
	"game_started",
	"game_over",
	"score_reached",
	"new_record",
	"combo_milestone",
	"perfect_dodge",
	"challenge_completed",
	"skin_selected",
	"rewarded_ad_requested",
	"rewarded_ad_completed",
	"rewarded_ad_failed",
	"interstitial_shown",
	"settings_changed",
	"analytics_toggled",
	"revive_used",
	"screen_view",
]

var enabled: bool = true
var session_id: String = ""
var _log_file: FileAccess = null
var _current_log_path: String = ""
var _session_ended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = bool(SaveManager.get_setting("analytics"))
	session_id = _generate_session_id()
	ensure_log_dir()
	_rotate_if_needed()
	track("session_started", {
		"version": GameConfig.VERSION,
		"platform": Platform.get_platform_name(),
		"debug": OS.is_debug_build(),
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_end_session()


func _exit_tree() -> void:
	_end_session()


func _end_session() -> void:
	if _session_ended:
		return
	_session_ended = true
	track("session_ended", {"duration": Time.get_ticks_msec() / 1000.0})
	flush()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	if not value:
		track("analytics_toggled", {"enabled": false})
		flush()
	enabled = value
	if value:
		track("analytics_toggled", {"enabled": true})


func track(event_name: String, params: Dictionary = {}) -> void:
	if not enabled:
		return
	if not ALLOWED_EVENTS.has(event_name):
		if OS.is_debug_build():
			push_warning("Analytics: ignored unknown event '%s'." % event_name)
		return
	var event := {
		"name": event_name,
		"session": session_id,
		"unix": Time.get_unix_time_from_system(),
		"data": params,
	}
	_write_event(event)
	if OS.is_debug_build():
		print("[analytics] %s %s" % [event_name, JSON.stringify(params)])


func flush() -> void:
	if _log_file != null:
		_log_file.flush()


func get_log_directory() -> String:
	return ProjectSettings.globalize_path(GameConfig.ANALYTICS_DIR)


func ensure_log_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(GameConfig.ANALYTICS_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameConfig.ANALYTICS_DIR))


func _write_event(event: Dictionary) -> void:
	ensure_log_dir()
	var day := Time.get_date_string_from_system()
	var path := "%s/events-%s.jsonl" % [GameConfig.ANALYTICS_DIR, day]
	if path != _current_log_path:
		flush()
		if _log_file != null:
			_log_file.close()
			_log_file = null
		_current_log_path = path
	if _log_file == null:
		_rotate_if_needed()
		if not FileAccess.file_exists(path):
			var created := FileAccess.open(path, FileAccess.WRITE)
			if created != null:
				created.close()
		_log_file = FileAccess.open(path, FileAccess.READ_WRITE)
		if _log_file == null:
			push_warning("Analytics: cannot open local log (%d)." % FileAccess.get_open_error())
			return
		_log_file.seek_end()
	_log_file.store_line(JSON.stringify(event))
	_log_file.flush()


func _rotate_if_needed() -> void:
	var path := "%s/events-%s.jsonl" % [GameConfig.ANALYTICS_DIR, Time.get_date_string_from_system()]
	if not FileAccess.file_exists(path):
		return
	var size := FileAccess.get_file_as_bytes(path).size()
	if size < MAX_FILE_BYTES:
		return
	var previous := "%s/events-%s.1.jsonl" % [GameConfig.ANALYTICS_DIR, Time.get_date_string_from_system()]
	var absolute_previous := ProjectSettings.globalize_path(previous)
	if FileAccess.file_exists(previous):
		DirAccess.remove_absolute(absolute_previous)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), absolute_previous)


func _generate_session_id() -> String:
	var alphabet := "0123456789abcdef"
	var result := ""
	for i in 12:
		result += alphabet[randi() % alphabet.length()]
	return result
