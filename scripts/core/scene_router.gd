extends Node
## Screen routing with a short, consistent neon-black fade.
## The router owns exactly one active screen; overlays (pause, game over, ads)
## live inside their screen instead of polluting the global scene tree.

signal screen_changed(path: String)

const MENU_SCENE := "res://scenes/menu/Menu.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/Gameplay.tscn"
const SETTINGS_SCENE := "res://scenes/settings/Settings.tscn"
const SKINS_SCENE := "res://scenes/skins/Skins.tscn"
const STATS_SCENE := "res://scenes/stats/Statistics.tscn"

var _host: Control
var _current: Node
var _current_path: String = ""
var _busy: bool = false
var _layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 1000
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 1.0
	_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func attach(host: Control) -> void:
	_host = host


func get_current_path() -> String:
	return _current_path


func get_current_screen() -> Node:
	return _current


func go_menu() -> void:
	change_screen(MENU_SCENE)


func go_gameplay() -> void:
	change_screen(GAMEPLAY_SCENE)


func go_settings() -> void:
	change_screen(SETTINGS_SCENE)


func go_skins() -> void:
	change_screen(SKINS_SCENE)


func go_stats() -> void:
	change_screen(STATS_SCENE)


func change_screen(path: String, animate: bool = true) -> void:
	if _host == null:
		push_error("SceneRouter: no screen host attached.")
		return
	if _busy:
		return
	if _current_path == path and _current != null:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if animate and _current != null:
		await _fade_to(1.0, 0.14)
	else:
		_fade.modulate.a = 1.0
	_swap(path)
	await get_tree().process_frame
	await _fade_to(0.0, 0.2)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished


func _swap(path: String) -> void:
	if _current != null:
		if _current.get_parent() == _host:
			_host.remove_child(_current)
		_current.queue_free()
		_current = null
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneRouter: failed to load scene: %s" % path)
		return
	var instance := packed.instantiate()
	if instance == null:
		push_error("SceneRouter: failed to instantiate scene: %s" % path)
		return
	_current = instance
	_current_path = path
	_host.add_child(instance)
	if instance is Control:
		(instance as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Analytics.track("screen_view", {"screen": path.get_file().get_basename()})
	screen_changed.emit(path)
