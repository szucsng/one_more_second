class_name NativeAdMobProvider
extends AdProvider
## Prepared native adapter boundary.
##
## No native AdMob plugin is bundled. This provider intentionally fails closed:
## it never fakes native ads and never grants rewards. See docs/monetization.md
## and docs/android-build.md for the remaining integration steps.

func _init() -> void:
	provider_name = "admob_native"
	uses_dom_reward_prompt = false


func initialize() -> bool:
	initialized_ok = false
	var reason := "native_admob_plugin_not_installed"
	if not AdConfig.native_adapter_configured():
		reason = "native_admob_ids_not_configured"
	emit_signal("initialized", false, reason)
	return false


func prepare_rewarded_ad() -> bool:
	emit_signal("rewarded_ready_changed", false, "native_adapter_unavailable")
	return false


func can_show_interstitial() -> bool:
	return false


func get_disclosure() -> String:
	return ""
