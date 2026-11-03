extends Node
## Ads lifecycle, duplicate reward, failure, timeout and policy tests.
##   godot --headless --path . res://tests/AdsTest.tscn

var failures: int = 0
var _ads_snapshot: Dictionary = {}
var _stats_snapshot: Dictionary = {}
var _grant_count: int = 0
var _dismiss_count: int = 0
var _failure_count: int = 0
var _ready_count: int = 0


func _ready() -> void:
	_ads_snapshot = (SaveManager.data.get("ads", {}) as Dictionary).duplicate(true)
	_stats_snapshot = (SaveManager.data.get("stats", {}) as Dictionary).duplicate(true)
	Ads.rewarded_granted.connect(_on_granted)
	Ads.rewarded_dismissed.connect(_on_dismissed)
	Ads.ad_failed.connect(_on_failed)
	Ads.rewarded_ready_changed.connect(_on_ready_changed)
	await _run()
	SaveManager.data["ads"] = _ads_snapshot
	SaveManager.data["stats"] = _stats_snapshot
	SaveManager.save_now()
	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _run() -> void:
	_check(not AdConfig.PRODUCTION_ADS_ENABLED, "production ads are disabled by default")
	_check(not AdConfig.INTERSTITIAL_ENABLED, "interstitials are disabled by default")
	_check(AdConfig.ADMOB_TEST_APP_ID.contains("3940256099942544"), "native test app id is used as placeholder")

	# Pure policy: cooldown and minimum run count.
	_check(not AdPolicy.can_show_interstitial(false, 10, 0.0, 1000.0, 3, 150.0), "disabled policy blocks interstitials")
	_check(not AdPolicy.can_show_interstitial(true, 2, 0.0, 1000.0, 3, 150.0), "minimum run count blocks interstitials")
	_check(not AdPolicy.can_show_interstitial(true, 3, 900.0, 1000.0, 3, 150.0), "cooldown blocks interstitials")
	_check(AdPolicy.can_show_interstitial(true, 3, 800.0, 1000.0, 3, 150.0), "cooldown expires correctly")
	_check(not Ads.can_show_interstitial(), "live manager keeps interstitials disabled")

	# Provider unavailable.
	Ads.set_test_provider(UnavailableAdProvider.new("test_unavailable"))
	await get_tree().process_frame
	_check(not Ads.prepare_rewarded_ad(), "unavailable provider fails preparation")
	_check(not Ads.can_show_rewarded_ad(), "unavailable provider exposes no rewarded ad")
	_check(Ads.get_last_failure_reason() == "test_unavailable" or Ads.get_last_failure_reason() == "", "unavailable reason is recorded safely")

	# Successful rewarded flow, with duplicate provider reward callbacks.
	var fake := FakeAdProvider.new()
	Ads.set_test_provider(fake)
	Ads.set_test_timeouts(0.3, 0.3, 0.3)
	await get_tree().process_frame
	_grant_count = 0
	_dismiss_count = 0
	_ready_count = 0
	_check(Ads.prepare_rewarded_ad(), "reward preparation is accepted")
	_check(fake.rewarded_ready, "fake provider reports ready")
	_check(Ads.can_show_rewarded_ad(), "manager exposes ready rewarded ad")
	_check(_ready_count == 1, "ready signal is emitted once")
	_check(Ads.show_rewarded_ad(), "rewarded ad starts")
	_check(Ads.is_ad_open(), "manager reports the ad open")
	await get_tree().process_frame
	_check(_grant_count == 0, "no reward is granted merely for showing")
	fake.complete_reward()
	await get_tree().process_frame
	_check(_grant_count == 1, "duplicate reward callbacks grant exactly once")
	_check(not Ads.is_ad_open(), "ad closes after reward")
	_check(int((SaveManager.data.get("ads", {}) as Dictionary).get("rewarded_views", 0)) == int(_ads_snapshot.get("rewarded_views", 0)) + 1, "reward view is recorded")

	# Dismissed without reward.
	_grant_count = 0
	_dismiss_count = 0
	_check(Ads.prepare_rewarded_ad(), "second rewarded prompt prepares")
	await get_tree().process_frame
	_check(Ads.show_rewarded_ad(), "second rewarded ad starts")
	await get_tree().process_frame
	fake.dismiss_ad("dismissed")
	await get_tree().process_frame
	_check(_grant_count == 0, "dismissed ad grants no reward")
	_check(_dismiss_count == 1, "dismissed ad emits one dismissal")
	_check(not Ads.can_show_rewarded_ad(), "dismissed attempt does not stay ready")

	# Load failure.
	fake.fail_prepare = true
	_grant_count = 0
	_failure_count = 0
	_check(not Ads.prepare_rewarded_ad(), "load failure fails preparation")
	_check(not Ads.can_show_rewarded_ad(), "load failure exposes no rewarded ad")
	_check(_failure_count >= 1, "load failure reports a failure")
	fake.fail_prepare = false

	# Display failure.
	_check(Ads.prepare_rewarded_ad(), "display failure setup prepares")
	await get_tree().process_frame
	fake.fail_show = true
	_grant_count = 0
	_failure_count = 0
	_check(not Ads.show_rewarded_ad(), "display failure fails show")
	_check(_grant_count == 0, "display failure grants no reward")
	_check(_failure_count >= 1, "display failure reports a failure")
	fake.fail_show = false

	# Ready timeout.
	fake.silent_prepare = true
	Ads.set_test_timeouts(0.12, 0.3, 0.12)
	_check(Ads.prepare_rewarded_ad(), "silent provider accepts preparation")
	await _wait(0.25)
	_check(not Ads.can_show_rewarded_ad(), "ready timeout exposes no rewarded ad")
	_check(Ads.get_last_failure_reason() == "timeout", "ready timeout is reported")
	fake.silent_prepare = false

	# Close timeout: shown ad never closes, no reward is granted.
	Ads.set_test_timeouts(0.3, 0.12, 0.3)
	_check(Ads.prepare_rewarded_ad(), "close-timeout setup prepares")
	await get_tree().process_frame
	_grant_count = 0
	_check(Ads.show_rewarded_ad(), "close-timeout setup shows")
	fake.silent_close = true
	await _wait(0.25)
	_check(_grant_count == 0, "close timeout never grants a reward")
	_check(not Ads.is_ad_open(), "close timeout clears the open state")
	fake.silent_close = false

	# Interstitial manager flow with a fake provider and a test-only config override.
	fake.interstitial_available = true
	Ads.set_test_interstitial_enabled(true)
	var ads_data: Dictionary = SaveManager.data.get("ads", {})
	ads_data["runs_since_interstitial"] = AdConfig.INTERSTITIAL_MIN_RUNS
	ads_data["last_interstitial_unix"] = 0.0
	SaveManager.data["ads"] = ads_data
	_check(Ads.can_show_interstitial(), "interstitial policy allows an eligible attempt")
	var interstitial_shown: Array[bool] = []
	Ads.interstitial_finished.connect(func(shown: bool) -> void: interstitial_shown.append(shown))
	var views_before := int(ads_data.get("interstitial_views", 0))
	_check(Ads.show_interstitial(), "interstitial request starts")
	await get_tree().process_frame
	_check(interstitial_shown.size() == 1 and interstitial_shown[0], "interstitial completion reports shown")
	_check(int(SaveManager.data["ads"].get("interstitial_views", 0)) == views_before + 1, "interstitial view counter increments only when shown")
	_check(not Ads.can_show_interstitial(), "interstitial cooldown starts after an impression")
	Ads.set_test_interstitial_enabled(false)

	# Restoring the previous data must leave the save readable.
	SaveManager.data["ads"] = _ads_snapshot
	SaveManager.data["stats"] = _stats_snapshot
	SaveManager.save_now()
	SaveManager.load_game()
	_check(SaveManager.get_stats().has("games_played"), "save remains readable after ad tests")


func _on_granted() -> void:
	_grant_count += 1


func _on_dismissed(_reason: String) -> void:
	_dismiss_count += 1


func _on_failed(_format: String, _reason: String) -> void:
	_failure_count += 1


func _on_ready_changed(available: bool, _reason: String) -> void:
	if available:
		_ready_count += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		failures += 1
		printerr("  FAIL  ", message)
