class_name Difficulty
extends RefCounted
## Difficulty curve. Kept pure and deterministic so it can be unit tested.

const START_SPEED := 620.0
const MAX_SPEED := 1500.0
const RAMP_SECONDS := 105.0

const START_INTERVAL := 1.05
const MIN_INTERVAL := 0.55
const INTERVAL_RAMP_SECONDS := 95.0

const STAGGER_UNLOCK := 7.0
const ZIGZAG_UNLOCK := 20.0
const RUSH_UNLOCK := 38.0


static func speed_at(elapsed: float) -> float:
	var t := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	# Ease-out ramp: noticeable early acceleration, then a steady climb.
	var eased := 1.0 - pow(1.0 - t, 1.7)
	return lerpf(START_SPEED, MAX_SPEED, eased)


static func spawn_interval_at(elapsed: float) -> float:
	var t := clampf(elapsed / INTERVAL_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(START_INTERVAL, MIN_INTERVAL, t)


static func allowed_patterns(elapsed: float) -> Array[String]:
	var patterns: Array[String] = ["single"]
	if elapsed >= STAGGER_UNLOCK:
		patterns.append("stagger")
	if elapsed >= ZIGZAG_UNLOCK:
		patterns.append("zigzag")
	if elapsed >= RUSH_UNLOCK:
		patterns.append("rush")
	return patterns


static func lane_switch_time(elapsed: float) -> float:
	# Human reaction budget used by the spawner's fairness guard.
	return clampf(0.16 + elapsed * 0.00035, 0.16, 0.22)
