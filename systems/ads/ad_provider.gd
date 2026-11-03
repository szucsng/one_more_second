class_name AdProvider
extends Node
## Contract between the game and any ad network implementation.
##
## Providers must never grant a reward without a provider-confirmed completion
## callback. The manager owns policy, timeouts and duplicate-reward protection.

signal initialized(success: bool, reason: String)
signal rewarded_ready_changed(available: bool, reason: String)
signal rewarded_shown
signal reward_earned
signal rewarded_dismissed(reason: String)
signal rewarded_closed
signal interstitial_shown
signal interstitial_closed(shown: bool)
signal failed(format: String, reason: String)

var provider_name: String = "none"
var uses_dom_reward_prompt: bool = false
var initialized_ok: bool = false


func initialize() -> bool:
	return false


func prepare_rewarded_ad() -> bool:
	return false


func can_show_rewarded_ad() -> bool:
	return false


func show_rewarded_ad() -> bool:
	return false


func cancel_rewarded_prompt() -> void:
	pass


func can_show_interstitial() -> bool:
	return false


func show_interstitial_ad() -> bool:
	return false


func show_banner() -> bool:
	return false


func hide_banner() -> void:
	pass


func set_sound_enabled(_enabled: bool) -> void:
	pass


func get_disclosure() -> String:
	return "OPTIONAL AD"


func shutdown() -> void:
	pass
