class_name UnavailableAdProvider
extends AdProvider
## Explicit "no provider" result. Never pretends an ad exists.

var reason: String = "provider_not_configured"


func _init(provider_reason: String = "provider_not_configured") -> void:
	provider_name = "unavailable"
	reason = provider_reason
	uses_dom_reward_prompt = false


func initialize() -> bool:
	emit_signal("initialized", false, reason)
	emit_signal("rewarded_ready_changed", false, reason)
	return false


func prepare_rewarded_ad() -> bool:
	emit_signal("rewarded_ready_changed", false, reason)
	return false


func get_disclosure() -> String:
	return ""


func get_reason() -> String:
	return reason
