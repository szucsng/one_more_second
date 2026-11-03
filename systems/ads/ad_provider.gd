class_name AdProvider
extends RefCounted
## Contract for every ad network adapter.
##
## A real AdMob adapter (Poing Studios plugin or a platform-native bridge) can
## be dropped in later by implementing these methods. The game only ever talks
## to AdsManager, never to a network SDK directly.

signal rewarded_ready_changed(ready: bool)
signal rewarded_granted
signal rewarded_dismissed
signal interstitial_closed

var provider_name: String = "none"


func initialize() -> bool:
	return false


func is_rewarded_available() -> bool:
	return false


func show_rewarded() -> bool:
	return false


func show_interstitial() -> bool:
	return false


func show_banner() -> bool:
	return false


func hide_banner() -> void:
	pass
