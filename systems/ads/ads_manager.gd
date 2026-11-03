extends Node
## Ad mediation layer: provider selection, lifecycle, policy and timeouts.
##
## The game never talks to a network SDK directly. Production ads are disabled
## by default via AdConfig.PRODUCTION_ADS_ENABLED. Mock ads are development-only.
##
## Rewarded flow:
##   prepare -> provider says reward prompt is available -> player opts in
##   -> provider confirms shown -> provider confirms reward -> close -> grant
##
## The manager grants at most one reward per attempt and blocks a second
## granted signal even if a provider sends duplicate callbacks.

signal ad_loaded(format: String)
signal ad_shown(format: String)
signal ad_closed(format: String)
signal ad_failed(format: String, reason: String)
signal rewarded_ready_changed(available: bool, reason: String)
signal rewarded_granted
signal rewarded_dismissed(reason: String)
signal interstitial_finished(shown: bool)

var _provider: AdProvider = null
var _initialized: bool = false
var _reward_token: int = 0
var _reward_active: bool = false
var _reward_ready: bool = false
var _reward_shown: bool = false
var _reward_earned: bool = false
var _reward_granted_this_attempt: bool = false
var _reward_dismiss_reason: String = ""
var _interstitial_token: int = 0
var _interstitial_pending: bool = false
var _interstitial_shown: bool = false
var _last_failure_reason: String = ""

## Overridable in tests; production values live in AdConfig.
var ready_timeout: float = AdConfig.REWARDED_READY_TIMEOUT
var close_timeout: float = AdConfig.AD_CLOSE_TIMEOUT
var interstitial_timeout: float = AdConfig.INTERSTITIAL_TIMEOUT
var _interstitial_test_override: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.settings_changed.connect(_apply_sound_setting)
	_install_provider(_create_provider())


func _create_provider() -> AdProvider:
	if AdConfig.PRODUCTION_ADS_ENABLED:
		if Platform.is_web:
			return WebH5AdProvider.new()
		if Platform.is_mobile:
			return NativeAdMobProvider.new()
		return UnavailableAdProvider.new("desktop_ads_not_supported")
	if AdConfig.MOCK_ADS_ENABLED and OS.is_debug_build() and not Platform.is_mobile:
		if not Platform.is_web or (AdConfig.ALLOW_MOCK_ON_WEB and OS.is_debug_build()):
			return MockAdProvider.new()
	return UnavailableAdProvider.new("production_ads_disabled")


func _install_provider(provider: AdProvider) -> void:
	if _provider != null:
		if _provider.get_parent() == self:
			remove_child(_provider)
		_provider.queue_free()
	_provider = provider
	_initialized = false
	if _provider == null:
		return
	add_child(_provider)
	_provider.initialized.connect(_on_provider_initialized)
	_provider.rewarded_ready_changed.connect(_on_rewarded_ready_changed)
	_provider.rewarded_shown.connect(_on_rewarded_shown)
	_provider.reward_earned.connect(_on_reward_earned)
	_provider.rewarded_dismissed.connect(_on_rewarded_dismissed)
	_provider.rewarded_closed.connect(_on_rewarded_closed)
	_provider.interstitial_shown.connect(_on_interstitial_shown)
	_provider.interstitial_closed.connect(_on_interstitial_closed)
	_provider.failed.connect(_on_provider_failed)
	_initialized = _provider.initialize()
	_apply_sound_setting()


func _on_provider_initialized(success: bool, reason: String) -> void:
	_initialized = success
	if not success:
		_last_failure_reason = reason


func _apply_sound_setting() -> void:
	if _provider == null:
		return
	var volume := float(SaveManager.get_setting("volume"))
	var enabled := volume > 0.001 and (bool(SaveManager.get_setting("sfx")) or bool(SaveManager.get_setting("music")))
	_provider.set_sound_enabled(enabled)


# --- Public capability API ------------------------------------------------

func can_show_rewarded_ad() -> bool:
	return _provider != null \
		and _initialized \
		and _reward_ready \
		and not _reward_shown \
		and not _interstitial_pending \
		and _provider.can_show_rewarded_ad()


func can_show_interstitial() -> bool:
	if not AdConfig.INTERSTITIAL_ENABLED and not _interstitial_test_override:
		return false
	if _provider == null or not _initialized or not _provider.can_show_interstitial():
		return false
	if _reward_active or _reward_ready or _reward_shown or _interstitial_pending:
		return false
	if Monetization.ads_removed():
		return false
	var ads: Dictionary = SaveManager.data.get("ads", {})
	return AdPolicy.can_show_interstitial(
		true,
		int(ads.get("runs_since_interstitial", 0)),
		float(ads.get("last_interstitial_unix", 0.0)),
		Time.get_unix_time_from_system(),
		AdConfig.INTERSTITIAL_MIN_RUNS,
		AdConfig.INTERSTITIAL_MIN_SECONDS
	)


func uses_dom_reward_prompt() -> bool:
	return _provider != null and _provider.uses_dom_reward_prompt


func get_provider_name() -> String:
	return _provider.provider_name if _provider != null else "none"


func get_reward_disclosure() -> String:
	return _provider.get_disclosure() if _provider != null else ""


func get_last_failure_reason() -> String:
	return _last_failure_reason


func is_ad_open() -> bool:
	return _reward_shown or _interstitial_shown


# --- Rewarded flow -------------------------------------------------------

func prepare_rewarded_ad() -> bool:
	if _provider == null or _interstitial_pending:
		return false
	if _reward_ready:
		return true
	if _reward_active:
		return true
	_reward_token += 1
	_reward_active = true
	_reward_ready = false
	_reward_shown = false
	_reward_earned = false
	_reward_granted_this_attempt = false
	_reward_dismiss_reason = ""
	_last_failure_reason = ""
	Analytics.track("rewarded_ad_requested", {"provider": get_provider_name()})

	var accepted := _provider.prepare_rewarded_ad()
	if not accepted:
		if _reward_active and not _reward_ready:
			_reward_active = false
			emit_signal("rewarded_ready_changed", false, "adapter_unavailable")
			emit_signal("ad_failed", "rewarded", "adapter_unavailable")
		return false
	if _reward_active and not _reward_ready:
		_start_ready_timeout(_reward_token)
	return true


func show_rewarded_ad() -> bool:
	if not can_show_rewarded_ad():
		return false
	_reward_ready = false
	var accepted := _provider.show_rewarded_ad()
	if not accepted:
		_reward_active = false
		_reward_shown = false
		emit_signal("rewarded_ready_changed", false, "display_failed")
		emit_signal("ad_failed", "rewarded", "display_failed")
		return false
	return true


func cancel_rewarded_prompt() -> void:
	_reward_token += 1
	_reward_active = false
	_reward_ready = false
	_reward_shown = false
	_reward_earned = false
	_reward_dismiss_reason = ""
	if _provider != null:
		_provider.cancel_rewarded_prompt()


func _on_rewarded_ready_changed(available: bool, reason: String) -> void:
	if not _reward_active:
		# A late callback from a cancelled/old attempt must not re-open the UI.
		return
	_reward_ready = available
	if available:
		emit_signal("ad_loaded", "rewarded")
		emit_signal("rewarded_ready_changed", true, reason)
	else:
		_reward_active = false
		_reward_ready = false
		_last_failure_reason = reason
		emit_signal("rewarded_ready_changed", false, reason)


func _on_rewarded_shown() -> void:
	if not _reward_active:
		return
	_reward_shown = true
	_reward_ready = false
	_reward_earned = false
	_reward_dismiss_reason = ""
	emit_signal("ad_shown", "rewarded")
	_start_close_timeout(_reward_token)


func _on_reward_earned() -> void:
	if _reward_active and _reward_shown:
		_reward_earned = true


func _on_rewarded_dismissed(reason: String) -> void:
	if not _reward_active:
		return
	_reward_dismiss_reason = reason
	if not _reward_shown:
		_reward_active = false
		_reward_ready = false
		_last_failure_reason = reason
		Analytics.track("rewarded_ad_failed", {"provider": get_provider_name(), "reason": reason})
		emit_signal("rewarded_ready_changed", false, reason)
		emit_signal("rewarded_dismissed", reason)


func _on_rewarded_closed() -> void:
	if not _reward_active:
		return
	_finish_rewarded()


func _finish_rewarded() -> void:
	if not _reward_active:
		return
	var was_shown := _reward_shown
	var earned := _reward_earned
	var reason := _reward_dismiss_reason if not _reward_dismiss_reason.is_empty() else "dismissed"
	_reward_active = false
	_reward_ready = false
	_reward_shown = false
	_reward_earned = false
	if earned and !_reward_granted_this_attempt:
		_reward_granted_this_attempt = true
		SaveManager.record_rewarded_view()
		Analytics.track("rewarded_ad_completed", {"provider": get_provider_name()})
		emit_signal("rewarded_granted")
		emit_signal("ad_closed", "rewarded")
	elif was_shown:
		Analytics.track("rewarded_ad_failed", {"provider": get_provider_name(), "reason": reason})
		emit_signal("rewarded_dismissed", reason)
		emit_signal("ad_closed", "rewarded")
	_reward_dismiss_reason = ""
	_reward_granted_this_attempt = false


func _start_ready_timeout(token: int) -> void:
	if ready_timeout <= 0.0:
		return
	await get_tree().create_timer(ready_timeout).timeout
	if token != _reward_token or not _reward_active or _reward_ready or _reward_shown:
		return
	_reward_active = false
	_last_failure_reason = "timeout"
	Analytics.track("rewarded_ad_failed", {"provider": get_provider_name(), "reason": "timeout"})
	if _provider != null:
		_provider.cancel_rewarded_prompt()
	emit_signal("rewarded_ready_changed", false, "timeout")
	emit_signal("ad_failed", "rewarded", "timeout")


func _start_close_timeout(token: int) -> void:
	if close_timeout <= 0.0:
		return
	await get_tree().create_timer(close_timeout).timeout
	if token != _reward_token or not _reward_active or not _reward_shown:
		return
	_last_failure_reason = "close_timeout"
	emit_signal("ad_failed", "rewarded", "close_timeout")
	_finish_rewarded()


func _on_provider_failed(format: String, reason: String) -> void:
	_last_failure_reason = reason
	if format == "rewarded":
		var was_shown := _reward_shown
		_reward_active = false
		_reward_ready = false
		_reward_shown = false
		_reward_earned = false
		Analytics.track("rewarded_ad_failed", {"provider": get_provider_name(), "reason": reason})
		emit_signal("rewarded_ready_changed", false, reason)
		emit_signal("ad_failed", "rewarded", reason)
		if was_shown:
			emit_signal("ad_closed", "rewarded")
	elif format == "interstitial":
		emit_signal("ad_failed", "interstitial", reason)
		_finish_interstitial(false)


# --- Interstitial flow ---------------------------------------------------

func show_interstitial() -> bool:
	if not can_show_interstitial():
		return false
	_interstitial_token += 1
	_interstitial_pending = true
	_interstitial_shown = false
	var accepted := _provider.show_interstitial_ad()
	if not accepted:
		_finish_interstitial(false)
		emit_signal("ad_failed", "interstitial", "request_rejected")
		return false
	_start_interstitial_timeout(_interstitial_token)
	return true


func _on_interstitial_shown() -> void:
	if not _interstitial_pending:
		return
	if not _interstitial_shown:
		_interstitial_shown = true
		SaveManager.record_interstitial_view()
		Analytics.track("interstitial_shown", {"provider": get_provider_name()})
		emit_signal("ad_shown", "interstitial")
	_start_close_timeout_interstitial(_interstitial_token)


func _on_interstitial_closed(shown: bool) -> void:
	if not _interstitial_pending:
		return
	_finish_interstitial(shown)


func _finish_interstitial(shown: bool) -> void:
	if not _interstitial_pending:
		return
	_interstitial_pending = false
	_interstitial_shown = false
	emit_signal("ad_closed", "interstitial")
	emit_signal("interstitial_finished", shown)


func _start_interstitial_timeout(token: int) -> void:
	if interstitial_timeout <= 0.0:
		return
	await get_tree().create_timer(interstitial_timeout).timeout
	if token != _interstitial_token or not _interstitial_pending or _interstitial_shown:
		return
	_finish_interstitial(false)


func _start_close_timeout_interstitial(token: int) -> void:
	if close_timeout <= 0.0:
		return
	await get_tree().create_timer(close_timeout).timeout
	if token != _interstitial_token or not _interstitial_pending or not _interstitial_shown:
		return
	_finish_interstitial(false)


# --- Legacy aliases and tests --------------------------------------------

func is_rewarded_available() -> bool:
	return can_show_rewarded_ad()


func show_rewarded() -> bool:
	return show_rewarded_ad()


func show_banner() -> bool:
	return false


func hide_banner() -> void:
	pass


func get_provider() -> AdProvider:
	return _provider


## Test-only injection. Disabled in release builds.
func set_test_provider(provider: AdProvider) -> void:
	if not OS.is_debug_build():
		push_warning("AdsManager: test provider injection is debug-only.")
		return
	_install_provider(provider)


func set_test_timeouts(ready: float, close: float, interstitial: float) -> void:
	if not OS.is_debug_build():
		return
	ready_timeout = ready
	close_timeout = close
	interstitial_timeout = interstitial


func set_test_interstitial_enabled(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	_interstitial_test_override = enabled
