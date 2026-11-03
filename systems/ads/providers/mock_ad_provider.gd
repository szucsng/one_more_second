class_name MockAdProvider
extends AdProvider
## Development-only local ad simulation.
##
## This is never used for production web builds. It exists so the revive flow
## can be exercised without a network, account, real ad units or reward fraud.

const OVERLAY_SCENE := preload("res://scenes/components/TestAdOverlay.tscn")

var _overlay: CanvasLayer
var _ready: bool = false
var _busy: bool = false


func _init() -> void:
	provider_name = "mock_test"
	uses_dom_reward_prompt = false


func initialize() -> bool:
	initialized_ok = true
	emit_signal("initialized", true, "local_mock")
	return true


func prepare_rewarded_ad() -> bool:
	if _busy:
		return false
	_ready = true
	emit_signal("rewarded_ready_changed", true, "local_mock")
	return true


func can_show_rewarded_ad() -> bool:
	return initialized_ok and _ready and not _busy


func show_rewarded_ad() -> bool:
	if not can_show_rewarded_ad():
		return false
	_ready = false
	_busy = true
	_overlay = OVERLAY_SCENE.instantiate() as CanvasLayer
	if _overlay == null:
		_busy = false
		emit_signal("failed", "rewarded", "overlay_missing")
		return false
	add_child(_overlay)
	_overlay.connect("completed", _on_completed)
	_overlay.connect("dismissed", _on_dismissed)
	emit_signal("rewarded_shown")
	return true


func cancel_rewarded_prompt() -> void:
	_ready = false


func _on_completed() -> void:
	emit_signal("reward_earned")
	_finish()


func _on_dismissed() -> void:
	emit_signal("rewarded_dismissed", "dismissed")
	_finish()


func _finish() -> void:
	if not _busy:
		return
	_busy = false
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	emit_signal("rewarded_closed")


func get_disclosure() -> String:
	return "OPTIONAL • SIMULATED TEST AD"
