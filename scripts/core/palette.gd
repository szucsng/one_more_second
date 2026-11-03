class_name Palette
extends RefCounted
## Central color and layout palette for ONE MORE SECOND.
## Keep every screen on this palette so the visual identity stays consistent.

const BACKGROUND := Color("#050505")
const SURFACE := Color("#0C0C0C")
const SURFACE_RAISED := Color("#121212")
const CYAN := Color("#00F5FF")
const PURPLE := Color("#9D4EDD")
const PINK := Color("#FF2E93")
const WHITE := Color("#FFFFFF")
const MUTED := Color("#858585")
const GOLD := Color("#FFC857")
const GREEN := Color("#00FFA3")
const RED := Color("#FF3860")

const LANE_OFFSET := 182.0
const PLAYER_Y := 1470.0
const LANE_MIN_X := 540.0 - LANE_OFFSET
const LANE_MAX_X := 540.0 + LANE_OFFSET


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


static func mix(a: Color, b: Color, weight: float) -> Color:
	return a.lerp(b, clampf(weight, 0.0, 1.0))
