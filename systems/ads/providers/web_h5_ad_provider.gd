class_name WebH5AdProvider
extends AdProvider
## Google AdSense H5 Games Ads adapter.
##
## The game only talks to the local `OMSAdsBridge` global from
## web/ads-bridge.js. That bridge owns all Google Ad Placement API details,
## consent gating, AdSense script loading and the DOM reward prompt.
##
## Rewarded ads use the API's inverted flow: prepare -> beforeReward shows the
## provider prompt -> the DOM button calls showAdFn directly (preserving the
## user gesture) -> beforeAd/adViewed/afterAd. The game never grants a reward
## until `reward_earned` has arrived.

var _js: Object
var _bridge: Object
var _callback: Object
var _available: bool = false
var _reward_ready: bool = false
var _interstitial_supported: bool = false
var _sound_enabled: bool = true


func _init() -> void:
	provider_name = "adsense_h5"
	uses_dom_reward_prompt = true


func initialize() -> bool:
	if not Platform.is_web:
		emit_signal("initialized", false, "not_web")
		return false
	_js = Engine.get_singleton("JavaScriptBridge")
	if _js == null:
		emit_signal("initialized", false, "javascript_bridge_unavailable")
		return false
	_bridge = _js.call("get_interface", "OMSAdsBridge")
	if _bridge == null:
		emit_signal("initialized", false, "web_bridge_missing")
		return false

	_callback = _js.call("create_callback", _on_js_event)
	_bridge.call("setGodotCallback", _callback)
	_bridge.call("init")
	_bridge.call("setSound", _sound_enabled)

	var status := _parse_status()
	if not bool(status.get("enabled", false)):
		_available = false
		initialized_ok = false
		emit_signal("initialized", false, String(status.get("reason", "ads_unavailable")))
		return false

	_available = true
	initialized_ok = true
	_interstitial_supported = bool(status.get("interstitial_supported", false))
	emit_signal("initialized", true, "adsense_h5")
	return true


func prepare_rewarded_ad() -> bool:
	_refresh_if_needed()
	if not _available:
		emit_signal("rewarded_ready_changed", false, "provider_unavailable")
		return false
	var accepted := bool(_bridge.call("requestRewarded"))
	if not accepted:
		emit_signal("failed", "rewarded", "request_rejected")
	return accepted


func can_show_rewarded_ad() -> bool:
	return _available and _reward_ready


func show_rewarded_ad() -> bool:
	if not can_show_rewarded_ad():
		return false
	_reward_ready = false
	var shown := bool(_bridge.call("showRewarded"))
	if not shown:
		emit_signal("failed", "rewarded", "show_rejected")
	return shown


func cancel_rewarded_prompt() -> void:
	_reward_ready = false
	if _bridge != null:
		_bridge.call("cancelRewardedPrompt")


func can_show_interstitial() -> bool:
	_refresh_if_needed()
	return _available and _interstitial_supported


func show_interstitial_ad() -> bool:
	if not can_show_interstitial():
		return false
	return bool(_bridge.call("showInterstitial"))


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	if _bridge != null:
		_bridge.call("setSound", enabled)


func get_disclosure() -> String:
	return "OPTIONAL • AD PROVIDED BY GOOGLE"


func shutdown() -> void:
	if _bridge != null:
		_bridge.call("cancelRewardedPrompt")


func _refresh_if_needed() -> void:
	if _available or _bridge == null:
		return
	var status := _parse_status()
	if not bool(status.get("enabled", false)):
		return
	_available = true
	initialized_ok = true
	_interstitial_supported = bool(status.get("interstitial_supported", false))
	_bridge.call("init")
	_bridge.call("setSound", _sound_enabled)
	emit_signal("initialized", true, "adsense_h5_refreshed")


func _parse_status() -> Dictionary:
	var raw: Variant = _bridge.call("getStatus")
	if raw is String:
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			return parsed
	return {}


func _on_js_event(args: Array) -> void:
	if args.is_empty():
		return
	var payload: Variant = args[0]
	if not (payload is String):
		return
	var parsed: Variant = JSON.parse_string(payload)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var event_type := String(data.get("type", ""))
	var reason := String(data.get("reason", "unknown"))
	match event_type:
		"rewarded_ready":
			var available := bool(data.get("available", false))
			_reward_ready = available
			emit_signal("rewarded_ready_changed", available, reason)
		"rewarded_shown":
			_reward_ready = false
			emit_signal("rewarded_shown")
		"reward_earned":
			emit_signal("reward_earned")
		"rewarded_dismissed":
			_reward_ready = false
			emit_signal("rewarded_dismissed", reason)
		"rewarded_closed":
			_reward_ready = false
			emit_signal("rewarded_closed")
		"interstitial_shown":
			emit_signal("interstitial_shown")
		"interstitial_closed":
			emit_signal("interstitial_closed", bool(data.get("shown", false)))
		"failed":
			_reward_ready = false
			emit_signal("failed", String(data.get("format", "rewarded")), reason)
		"initialized":
			initialized_ok = bool(data.get("success", false))
