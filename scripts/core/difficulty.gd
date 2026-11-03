class_name Difficulty
extends RefCounted
## Difficulty curve, pattern unlocks, recovery pacing and limits.
## Kept pure and deterministic so the fairness envelope can be unit tested.

const START_SPEED := 620.0
const MAX_SPEED := 1500.0
const RAMP_SECONDS := 105.0

const START_INTERVAL := 1.05
const MIN_INTERVAL := 0.55
const INTERVAL_RAMP_SECONDS := 95.0

## Minimum reaction time the spawner must preserve between lane-changing
## decisions. The player's actual switch takes well under this.
const MIN_REACTION_TIME := 0.24
const MIN_PATTERN_GAP := 0.30

## Pattern unlocks (seconds). Advanced patterns arrive gradually.
const PATTERN_UNLOCKS := {
	"single": 0.0,
	"stagger": 8.0,
	"zigzag": 22.0,
	"late_switch": 32.0,
	"rush": 42.0,
	"gauntlet": 74.0,
}

## Deliberate short recovery sections keep the pressure curve from becoming
## a flat, monotonous ramp.
const RECOVERY_TIMES := [20.0, 48.0, 78.0, 112.0]
const RECOVERY_DURATION := 2.3


static func speed_at(elapsed: float) -> float:
	var t := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	# Ease-out ramp: noticeable early acceleration, then a steady climb.
	var eased := 1.0 - pow(1.0 - t, 1.7)
	return lerpf(START_SPEED, MAX_SPEED, eased)


static func spawn_interval_at(elapsed: float) -> float:
	var t := clampf(elapsed / INTERVAL_RAMP_SECONDS, 0.0, 1.0)
	var base := lerpf(START_INTERVAL, MIN_INTERVAL, t)
	# A very mild pressure wave gives the cadence some texture without ever
	# crossing the configured fairness floor.
	var wave := 1.0 + 0.045 * sin(elapsed * 0.18)
	return clampf(base * wave, MIN_INTERVAL, START_INTERVAL)


static func allowed_patterns(elapsed: float) -> Array[String]:
	var patterns: Array[String] = []
	for pattern: String in PATTERN_UNLOCKS:
		if elapsed >= float(PATTERN_UNLOCKS[pattern]):
			patterns.append(pattern)
	# Dictionary iteration is stable in Godot, but sort for deterministic tests.
	patterns.sort_custom(func(a: String, b: String) -> bool:
		return float(PATTERN_UNLOCKS[a]) < float(PATTERN_UNLOCKS[b])
	)
	return patterns


static func lane_switch_time(elapsed: float) -> float:
	# Human reaction budget used by the spawner's fairness guard.
	return clampf(0.16 + elapsed * 0.00035, 0.16, 0.22)


static func recovery_due(elapsed: float, recovery_index: int) -> bool:
	return recovery_index >= 0 \
		and recovery_index < RECOVERY_TIMES.size() \
		and elapsed >= float(RECOVERY_TIMES[recovery_index])
