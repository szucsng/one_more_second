class_name FakeAdProvider
extends AdProvider
## Controllable test double for AdsManager lifecycle tests.

var rewarded_ready: bool = false
var fail_prepare: bool = false
var fail_show: bool = false
var silent_prepare: bool = false
var silent_close: bool = false
var interstitial_available: bool = false


func _init() -> void:
	provider_name = "fake_test"
	uses_dom_reward_prompt = false


func initialize() -> bool:
	initialized_ok = true
	emit_signal("initialized", true, "fake_ready")
	return true


func prepare_rewarded_ad() -> bool:
	if silent_prepare:
		return true
	if fail_prepare:
		rewarded_ready = false
		emit_signal("rewarded_ready_changed", false, "load_failure")
		emit_signal("failed", "rewarded", "load_failure")
		return false
	rewarded_ready = true
	emit_signal("rewarded_ready_changed", true, "ready")
	return true


func can_show_rewarded_ad() -> bool:
	return rewarded_ready


func show_rewarded_ad() -> bool:
	if not rewarded_ready:
		return false
	rewarded_ready = false
	if fail_show:
		emit_signal("failed", "rewarded", "display_failure")
		return false
	emit_signal("rewarded_shown")
	return true


func cancel_rewarded_prompt() -> void:
	rewarded_ready = false


func complete_reward() -> void:
	emit_signal("reward_earned")
	emit_signal("reward_earned")
	if not silent_close:
		emit_signal("rewarded_closed")


func dismiss_ad(reason: String = "dismissed") -> void:
	emit_signal("rewarded_dismissed", reason)
	if not silent_close:
		emit_signal("rewarded_closed")


func close_ad() -> void:
	emit_signal("rewarded_closed")


func can_show_interstitial() -> bool:
	return interstitial_available


func show_interstitial_ad() -> bool:
	if not interstitial_available:
		return false
	emit_signal("interstitial_shown")
	emit_signal("interstitial_closed", true)
	return true


func get_disclosure() -> String:
	return "OPTIONAL • TEST AD"
