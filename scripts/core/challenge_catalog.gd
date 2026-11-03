class_name ChallengeCatalog
extends RefCounted
## Deterministic local daily challenge definitions.
## No network, no accounts: the date is the seed.

const DAILY_SET_SIZE := 3

const DODGE_TARGETS := [18, 22, 26]
const PERFECT_TARGETS := [2, 3, 4]
const COMBO_TARGETS := [8, 10, 12]
const SCORE_TARGETS := [35, 50, 65]
const SURVIVAL_TARGETS := [30, 40, 50]

const ROTATING_TYPES := ["combo", "score", "survival"]


static func generate(date_string: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(date_string.replace("-", ""))

	var dodge_target: int = DODGE_TARGETS[rng.randi_range(0, DODGE_TARGETS.size() - 1)]
	var perfect_target: int = PERFECT_TARGETS[rng.randi_range(0, PERFECT_TARGETS.size() - 1)]
	var third_type: String = ROTATING_TYPES[rng.randi_range(0, ROTATING_TYPES.size() - 1)]

	var set: Array[Dictionary] = [
		_make(date_string, "dodges", dodge_target),
		_make(date_string, "perfects", perfect_target),
		_make(date_string, third_type, _target_for(third_type, rng)),
	]
	return set


static func progress_value(challenge: Dictionary, progress: Dictionary) -> float:
	var type := String(challenge.get("type", ""))
	match type:
		"dodges":
			return float(progress.get("dodges", 0))
		"perfects":
			return float(progress.get("perfects", 0))
		"combo":
			return float(progress.get("max_combo", 0))
		"score":
			return float(progress.get("best_score", 0))
		"survival":
			return float(progress.get("best_survival", 0.0))
	return 0.0


static func progress_ratio(challenge: Dictionary, progress: Dictionary) -> float:
	var target := maxf(1.0, float(challenge.get("target", 1)))
	return clampf(progress_value(challenge, progress) / target, 0.0, 1.0)


static func is_met(challenge: Dictionary, progress: Dictionary) -> bool:
	return progress_value(challenge, progress) >= float(challenge.get("target", 1))


static func format_progress(challenge: Dictionary, progress: Dictionary) -> String:
	var current := progress_value(challenge, progress)
	var target := float(challenge.get("target", 1))
	if String(challenge.get("type", "")) == "survival":
		return "%d / %d s" % [int(current), int(target)]
	return "%d / %d" % [int(current), int(target)]


static func _target_for(type: String, rng: RandomNumberGenerator) -> int:
	match type:
		"combo":
			return COMBO_TARGETS[rng.randi_range(0, COMBO_TARGETS.size() - 1)]
		"score":
			return SCORE_TARGETS[rng.randi_range(0, SCORE_TARGETS.size() - 1)]
		"survival":
			return SURVIVAL_TARGETS[rng.randi_range(0, SURVIVAL_TARGETS.size() - 1)]
	return 10


static func _make(date_string: String, type: String, target: int) -> Dictionary:
	var definition := {
		"id": "%s:%s" % [date_string, type],
		"type": type,
		"target": target,
		"reward": 0,
		"title": "",
		"description": "",
	}
	match type:
		"dodges":
			definition["title"] = "CLEAN SWEEP"
			definition["description"] = "Dodge %d obstacles today." % target
			definition["reward"] = 20
		"perfects":
			definition["title"] = "PRECISION"
			definition["description"] = "Land %d perfect dodges today." % target
			definition["reward"] = 30
		"combo":
			definition["title"] = "CHAIN REACTION"
			definition["description"] = "Reach a %d combo in one run." % target
			definition["reward"] = 25
		"score":
			definition["title"] = "HIGH VOLTAGE"
			definition["description"] = "Score %d points in one run." % target
			definition["reward"] = 30
		"survival":
			definition["title"] = "HOLD THE LINE"
			definition["description"] = "Survive %d seconds in one run." % target
			definition["reward"] = 35
	return definition
