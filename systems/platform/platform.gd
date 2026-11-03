extends Node
## Thin platform abstraction. Every OS-specific call in the project goes here
## so web, Android, iOS and desktop builds never crash on missing features.

var is_web: bool = false
var is_android: bool = false
var is_ios: bool = false
var is_mobile: bool = false
var is_desktop: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web")
	is_android = OS.has_feature("android")
	is_ios = OS.has_feature("ios")
	is_mobile = OS.has_feature("mobile") or is_android or is_ios
	is_desktop = not is_web and not is_mobile
	if is_desktop:
		DisplayServer.window_set_min_size(Vector2i(360, 640))


## Safe-area insets in the 1080x1920 design space. Returns zeros on desktop
## and web; on notched phones it keeps HUD and headers clear of the camera.
func get_safe_insets() -> Dictionary:
	var zero := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not is_mobile:
		return zero
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return zero
	var safe := DisplayServer.get_display_safe_area()
	var scale_x := GameConfig.BASE_WIDTH / float(window_size.x)
	var scale_y := GameConfig.BASE_HEIGHT / float(window_size.y)
	return {
		"top": clampf(float(safe.position.y) * scale_y, 0.0, 280.0),
		"bottom": clampf(float(window_size.y - safe.end.y) * scale_y, 0.0, 280.0),
		"left": clampf(float(safe.position.x) * scale_x, 0.0, 220.0),
		"right": clampf(float(window_size.x - safe.end.x) * scale_x, 0.0, 220.0),
	}


func apply_safe_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	var insets := get_safe_insets()
	container.add_theme_constant_override("margin_left", left + int(insets["left"]))
	container.add_theme_constant_override("margin_top", top + int(insets["top"]))
	container.add_theme_constant_override("margin_right", right + int(insets["right"]))
	container.add_theme_constant_override("margin_bottom", bottom + int(insets["bottom"]))


func get_platform_name() -> String:
	if is_web:
		return "web"
	if is_android:
		return "android"
	if is_ios:
		return "ios"
	if OS.has_feature("macos"):
		return "macos"
	if OS.has_feature("windows"):
		return "windows"
	if OS.has_feature("linux"):
		return "linux"
	return "unknown"


func vibrate(duration_ms: int = 18) -> void:
	if not is_mobile:
		return
	if not bool(SaveManager.get_setting("vibration")):
		return
	Input.vibrate_handheld(duration_ms)


func open_url(url: String) -> void:
	if url.is_empty() or (not url.begins_with("https://") and not url.begins_with("http://")):
		push_warning("Platform.open_url: refusing invalid URL.")
		return
	if is_web:
		var js := Engine.get_singleton("JavaScriptBridge")
		if js != null:
			js.eval("window.open(%s, '_blank', 'noopener');" % JSON.stringify(url))
			return
	OS.shell_open(url)


func set_fullscreen(enabled: bool) -> void:
	if is_mobile:
		# Immersive/fullscreen is configured in the mobile export presets.
		return
	if is_web:
		var js := Engine.get_singleton("JavaScriptBridge")
		if js != null:
			if enabled:
				js.eval("document.documentElement.requestFullscreen().catch(function(){});")
			else:
				js.eval("if(document.fullscreenElement){document.exitFullscreen();}")
			return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_saved_display_settings() -> void:
	var wants_fullscreen := bool(SaveManager.get_setting("fullscreen"))
	# Browsers only allow fullscreen from a user gesture, so never auto-request it.
	if wants_fullscreen and is_desktop:
		set_fullscreen(true)


func can_toggle_fullscreen() -> bool:
	return is_web or is_desktop


func supports_haptics() -> bool:
	return is_mobile


func has_web_audio_gesture_requirement() -> bool:
	return is_web
