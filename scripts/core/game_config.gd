class_name GameConfig
extends RefCounted
## Tunable, gameplay-wide constants. Values are in the 1080x1920 design space.

const GAME_NAME := "ONE MORE SECOND"
const VERSION := "1.1.0"
const BASE_WIDTH := 1080.0
const BASE_HEIGHT := 1920.0
const DESIGN_FPS := 60

## Optional: set this to a real support page (itch.io, Ko-fi, ...) before release.
## The SUPPORT button stays hidden while the string is empty.
const SUPPORT_URL := ""
const SUPPORT_LABEL := "SUPPORT THE DEVELOPER"

const REVIVED_RUNS_LIMIT := 1
const REVIVE_INVULNERABILITY := 2.2
const MAX_ANALYTICS_BYTES := 512 * 1024

const SAVE_PATH := "user://save.json"
const SAVE_BACKUP_PATH := "user://save.bak.json"
const ANALYTICS_DIR := "user://analytics"

const RANK_THRESHOLDS := [
	{"score": 220, "title": "UNREAL"},
	{"score": 120, "title": "MACHINE"},
	{"score": 60, "title": "SHARP"},
	{"score": 30, "title": "REFLEX"},
	{"score": 10, "title": "WARMED UP"},
	{"score": 0, "title": "ROOKIE"},
]


static func rank_for(score: int) -> String:
	for entry in RANK_THRESHOLDS:
		if score >= int(entry["score"]):
			return String(entry["title"])
	return "ROOKIE"


static func format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var minutes := total / 60
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]


static func format_score(score: int) -> String:
	return str(maxi(0, score))
