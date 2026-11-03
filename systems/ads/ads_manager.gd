extends Node
## Ad mediation layer. Owns the provider and all frequency rules.
##
## v1 uses a visible "TEST AD" simulation. It never shows an interstitial
## during gameplay, never shows ads automatically on restart, and always lets
## the player continue without watching anything.

signal ad_opened
signal ad_closed
signal rewarded_granted
signal rewarded_dismissed

const OVERLAY_SCENE := "res://scenes/components/TestAdOverlay.tscn"

var _overlay: CanvasLayer = null
var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_rewarded_available() -> bool:
	if not AdConfig.TEST_MODE or _showing:
		return false
	if Platform.is_web and not AdConfig.ALLOW_TEST_ADS_ON_WEB:
		return false
	return true


func get_provider_name() -> String:
	return "simulated_test" if AdConfig.TEST_MODE else "none"


func show_rewarded() -> bool:
	if not is_rewarded_available():
		return false
	if not ResourceLoader.exists(OVERLAY_SCENE):
		push_error("AdsManager: test ad overlay scene is missing.")
		return false
	Analytics.track("rewarded_ad_requested", {"provider": get_provider_name()})
	_showing = true
	_overlay = load(OVERLAY_SCENE).instantiate() as CanvasLayer
	add_child(_overlay)
	_overlay.connect("completed", _on_reward_completed)
	_overlay.connect("dismissed", _on_reward_dismissed)
	ad_opened.emit()
	return true


func _on_reward_completed() -> void:
	Analytics.track("rewarded_ad_completed", {"provider": get_provider_name()})
	SaveManager.record_rewarded_view()
	_finish_overlay()
	rewarded_granted.emit()


func _on_reward_dismissed() -> void:
	Analytics.track("rewarded_ad_failed", {"provider": get_provider_name(), "reason": "dismissed"})
	_finish_overlay()
	rewarded_dismissed.emit()


func _finish_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_showing = false
	ad_closed.emit()


## Interstitials are intentionally disabled in v1. This is the policy hook for
## a future release: at most one after a run, never during play, never on every
## restart, and never without a loaded creative.
func can_show_interstitial() -> bool:
	if not AdConfig.INTERSTITIAL_ENABLED or _showing:
		return false
	var ads: Dictionary = SaveManager.data.get("ads", {})
	if int(ads.get("runs_since_interstitial", 0)) < AdConfig.INTERSTITIAL_MIN_RUNS:
		return false
	var last := float(ads.get("last_interstitial_unix", 0.0))
	var now := Time.get_unix_time_from_system()
	return now - last >= AdConfig.INTERSTITIAL_MIN_SECONDS


func show_interstitial() -> bool:
	if not can_show_interstitial():
		return false
	SaveManager.record_interstitial_view()
	Analytics.track("interstitial_shown", {"provider": get_provider_name()})
	return true


func show_banner() -> bool:
	# Banner placements are prepared but disabled for launch.
	return false


func hide_banner() -> void:
	pass


func is_ad_open() -> bool:
	return _showing
