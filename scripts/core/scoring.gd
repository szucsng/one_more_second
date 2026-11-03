class_name Scoring
extends RefCounted
## Central score and combo rules. Pure and deterministic for easy testing.

const MILESTONES := [5, 10, 20, 30]
const MULTIPLIERS := [1, 2, 3, 4, 5]
const PERFECT_WINDOW := 0.28
const PERFECT_MIN_TIME := 0.10
const PERFECT_BONUS := 2
const COLLISION_HALF_HEIGHT := 80.0


static func multiplier_for(combo: int) -> int:
	if combo >= 30:
		return 5
	if combo >= 20:
		return 4
	if combo >= 10:
		return 3
	if combo >= 5:
		return 2
	return 1


static func obstacle_points(combo: int) -> int:
	return multiplier_for(combo)


static func is_milestone(combo: int) -> bool:
	return MILESTONES.has(combo)


static func next_milestone(combo: int) -> int:
	for milestone in MILESTONES:
		if combo < milestone:
			return milestone
	return MILESTONES.back()


static func combo_progress(combo: int) -> float:
	if combo >= MILESTONES.back():
		return 1.0
	var previous := 0
	for milestone in MILESTONES:
		if combo < milestone:
			var span := float(milestone - previous)
			return clampf(float(combo - previous) / maxf(span, 1.0), 0.0, 1.0)
		previous = milestone
	return 1.0


## Distance ahead of the player where a switch still counts as perfect.
static func perfect_distance(speed: float) -> float:
	return COLLISION_HALF_HEIGHT + maxf(1.0, speed) * PERFECT_WINDOW
