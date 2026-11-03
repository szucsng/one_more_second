extends SceneTree
## Generates assets/theme/ui_theme.tres from the palette and the bundled OFL
## fonts. Run once after changing the design system:
##   godot --headless --path . --script tools/build_theme.gd

const OUTPUT := "res://assets/theme/ui_theme.tres"


func _init() -> void:
	var audiowide: FontFile = load("res://assets/fonts/Audiowide-Regular.ttf")
	var rajdhani_medium: FontFile = load("res://assets/fonts/Rajdhani-Medium.ttf")
	var rajdhani_semibold: FontFile = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	var rajdhani_bold: FontFile = load("res://assets/fonts/Rajdhani-Bold.ttf")

	var theme := Theme.new()
	theme.default_font = rajdhani_medium
	theme.default_font_size = 32

	var kicker_font := FontVariation.new()
	kicker_font.base_font = rajdhani_semibold
	kicker_font.spacing_glyph = 7

	var caption_font := FontVariation.new()
	caption_font.base_font = rajdhani_medium
	caption_font.spacing_glyph = 3

	# ---- Labels -----------------------------------------------------------
	theme.set_color("font_color", "Label", Color("#FFFFFF"))
	theme.set_font("font", "Label", rajdhani_medium)
	theme.set_font_size("font_size", "Label", 32)

	_label_variation(theme, "TitleLabel", audiowide, 94, Color("#FFFFFF"))
	theme.set_color("font_outline_color", "TitleLabel", Palette.with_alpha(Palette.CYAN, 0.18))
	theme.set_constant("outline_size", "TitleLabel", 10)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.65))
	theme.set_constant("shadow_offset_y", "TitleLabel", 5)

	_label_variation(theme, "HugeLabel", rajdhani_bold, 158, Color("#FFFFFF"))
	theme.set_color("font_outline_color", "HugeLabel", Palette.with_alpha(Palette.CYAN, 0.16))
	theme.set_constant("outline_size", "HugeLabel", 10)

	_label_variation(theme, "HeadingLabel", audiowide, 52, Color("#FFFFFF"))
	_label_variation(theme, "SubheadingLabel", audiowide, 34, Color("#FFFFFF"))
	_label_variation(theme, "KickerLabel", kicker_font, 28, Palette.CYAN)
	_label_variation(theme, "CaptionLabel", caption_font, 26, Palette.MUTED)
	_label_variation(theme, "BodyLabel", rajdhani_medium, 32, Color(1, 1, 1, 0.88))
	_label_variation(theme, "ValueLabel", rajdhani_bold, 48, Color("#FFFFFF"))
	_label_variation(theme, "SmallValueLabel", rajdhani_bold, 36, Color("#FFFFFF"))
	_label_variation(theme, "GoldLabel", rajdhani_bold, 34, Palette.GOLD)
	_label_variation(theme, "BadgeLabel", audiowide, 28, Palette.GOLD)
	_label_variation(theme, "AccentLabel", rajdhani_semibold, 32, Palette.CYAN)
	_label_variation(theme, "DangerLabel", rajdhani_semibold, 30, Palette.RED)
	_label_variation(theme, "MutedLabel", rajdhani_medium, 28, Palette.MUTED)
	_label_variation(theme, "ScoreLabel", rajdhani_bold, 126, Color("#FFFFFF"))
	theme.set_color("font_outline_color", "ScoreLabel", Palette.with_alpha(Palette.CYAN, 0.2))
	theme.set_constant("outline_size", "ScoreLabel", 8)

	# ---- Buttons ----------------------------------------------------------
	theme.set_font("font", "Button", rajdhani_semibold)
	theme.set_font_size("font_size", "Button", 34)
	theme.set_color("font_color", "Button", Color("#FFFFFF"))
	theme.set_color("font_hover_color", "Button", Color("#FFFFFF"))
	theme.set_color("font_pressed_color", "Button", Palette.CYAN)
	theme.set_color("font_disabled_color", "Button", Palette.with_alpha(Palette.MUTED, 0.55))
	theme.set_color("font_focus_color", "Button", Color("#FFFFFF"))

	var button_normal := _box(Color("#0C0C0C") * Color(1, 1, 1, 0.94), Palette.with_alpha(Palette.CYAN, 0.32), 2, 16)
	button_normal.shadow_color = Palette.with_alpha(Palette.CYAN, 0.12)
	button_normal.shadow_size = 12
	button_normal.content_margin_left = 38
	button_normal.content_margin_right = 38
	button_normal.content_margin_top = 22
	button_normal.content_margin_bottom = 22

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Palette.with_alpha(Palette.CYAN, 0.09)
	button_hover.border_color = Palette.with_alpha(Palette.CYAN, 0.85)
	button_hover.shadow_color = Palette.with_alpha(Palette.CYAN, 0.28)
	button_hover.shadow_size = 20

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Palette.with_alpha(Palette.CYAN, 0.18)
	button_pressed.border_color = Palette.CYAN
	button_pressed.shadow_color = Palette.with_alpha(Palette.CYAN, 0.34)
	button_pressed.shadow_size = 26

	var button_disabled := button_normal.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Palette.with_alpha(Palette.SURFACE, 0.38)
	button_disabled.border_color = Palette.with_alpha(Palette.MUTED, 0.22)
	button_disabled.shadow_size = 0

	var button_focus := StyleBoxFlat.new()
	button_focus.bg_color = Color(0, 0, 0, 0)
	button_focus.border_color = Palette.with_alpha(Palette.CYAN, 0.9)
	button_focus.set_border_width_all(2)
	button_focus.set_corner_radius_all(18)
	button_focus.set_content_margin_all(0)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", button_focus)

	# Primary filled CTA.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_font("font", "PrimaryButton", audiowide)
	theme.set_font_size("font_size", "PrimaryButton", 36)
	theme.set_color("font_color", "PrimaryButton", Color("#050505"))
	theme.set_color("font_hover_color", "PrimaryButton", Color("#050505"))
	theme.set_color("font_pressed_color", "PrimaryButton", Color("#050505"))
	theme.set_color("font_focus_color", "PrimaryButton", Color("#050505"))

	var primary_normal := _box(Palette.CYAN, Color("#B8FDFF"), 0, 18)
	primary_normal.shadow_color = Palette.with_alpha(Palette.CYAN, 0.5)
	primary_normal.shadow_size = 30
	primary_normal.content_margin_left = 40
	primary_normal.content_margin_right = 40
	primary_normal.content_margin_top = 26
	primary_normal.content_margin_bottom = 26
	var primary_hover := primary_normal.duplicate() as StyleBoxFlat
	primary_hover.bg_color = Color("#7DFBFF")
	primary_hover.shadow_color = Palette.with_alpha(Palette.CYAN, 0.72)
	primary_hover.shadow_size = 38
	var primary_pressed := primary_normal.duplicate() as StyleBoxFlat
	primary_pressed.bg_color = Color("#00C5CE")
	primary_pressed.shadow_color = Palette.with_alpha(Palette.CYAN, 0.3)
	primary_pressed.shadow_size = 18
	var primary_disabled := primary_normal.duplicate() as StyleBoxFlat
	primary_disabled.bg_color = Palette.with_alpha(Palette.CYAN, 0.24)
	primary_disabled.shadow_size = 0
	theme.set_stylebox("normal", "PrimaryButton", primary_normal)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("disabled", "PrimaryButton", primary_disabled)

	# Ghost text button.
	theme.set_type_variation("GhostButton", "Button")
	theme.set_font("font", "GhostButton", rajdhani_semibold)
	theme.set_font_size("font_size", "GhostButton", 30)
	theme.set_color("font_color", "GhostButton", Palette.MUTED)
	theme.set_color("font_hover_color", "GhostButton", Palette.WHITE)
	theme.set_color("font_pressed_color", "GhostButton", Palette.CYAN)
	var ghost_normal := _flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12)
	ghost_normal.content_margin_left = 24
	ghost_normal.content_margin_right = 24
	ghost_normal.content_margin_top = 16
	ghost_normal.content_margin_bottom = 16
	var ghost_hover := ghost_normal.duplicate() as StyleBoxFlat
	ghost_hover.bg_color = Color(1, 1, 1, 0.045)
	theme.set_stylebox("normal", "GhostButton", ghost_normal)
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", ghost_normal)
	theme.set_stylebox("focus", "GhostButton", button_focus)

	# Compact icon/HUD button.
	theme.set_type_variation("IconButton", "Button")
	theme.set_font("font", "IconButton", audiowide)
	theme.set_font_size("font_size", "IconButton", 28)
	var icon_normal := _box(Palette.with_alpha(Palette.SURFACE, 0.82), Palette.with_alpha(Palette.WHITE, 0.14), 2, 18)
	icon_normal.content_margin_left = 18
	icon_normal.content_margin_right = 18
	icon_normal.content_margin_top = 12
	icon_normal.content_margin_bottom = 12
	var icon_hover := icon_normal.duplicate() as StyleBoxFlat
	icon_hover.border_color = Palette.with_alpha(Palette.CYAN, 0.75)
	icon_hover.shadow_color = Palette.with_alpha(Palette.CYAN, 0.25)
	icon_hover.shadow_size = 16
	theme.set_stylebox("normal", "IconButton", icon_normal)
	theme.set_stylebox("hover", "IconButton", icon_hover)
	theme.set_stylebox("pressed", "IconButton", button_pressed)
	theme.set_stylebox("focus", "IconButton", button_focus)

	# Settings toggle.
	theme.set_type_variation("ToggleButton", "Button")
	theme.set_font("font", "ToggleButton", rajdhani_bold)
	theme.set_font_size("font_size", "ToggleButton", 26)
	theme.set_color("font_color", "ToggleButton", Palette.MUTED)
	theme.set_color("font_pressed_color", "ToggleButton", Color("#050505"))
	theme.set_color("font_hover_color", "ToggleButton", Palette.WHITE)
	theme.set_color("font_hover_pressed_color", "ToggleButton", Color("#050505"))
	var toggle_off := _box(Palette.with_alpha(Palette.SURFACE, 0.9), Palette.with_alpha(Palette.MUTED, 0.35), 1, 999)
	toggle_off.content_margin_left = 26
	toggle_off.content_margin_right = 26
	toggle_off.content_margin_top = 12
	toggle_off.content_margin_bottom = 12
	var toggle_on := toggle_off.duplicate() as StyleBoxFlat
	toggle_on.bg_color = Palette.CYAN
	toggle_on.border_color = Palette.CYAN
	toggle_on.shadow_color = Palette.with_alpha(Palette.CYAN, 0.4)
	toggle_on.shadow_size = 16
	theme.set_stylebox("normal", "ToggleButton", toggle_off)
	theme.set_stylebox("hover", "ToggleButton", toggle_off)
	theme.set_stylebox("pressed", "ToggleButton", toggle_on)
	theme.set_stylebox("hover_pressed", "ToggleButton", toggle_on)
	theme.set_stylebox("focus", "ToggleButton", button_focus)

	# Skin card.
	theme.set_type_variation("SkinCard", "Button")
	var card_normal := _box(Palette.with_alpha(Palette.SURFACE, 0.86), Palette.with_alpha(Palette.WHITE, 0.07), 2, 24)
	card_normal.content_margin_left = 0
	card_normal.content_margin_right = 0
	card_normal.content_margin_top = 0
	card_normal.content_margin_bottom = 0
	var card_hover := card_normal.duplicate() as StyleBoxFlat
	card_hover.bg_color = Palette.with_alpha(Palette.SURFACE, 0.98)
	card_hover.border_color = Palette.with_alpha(Palette.CYAN, 0.5)
	var card_pressed := card_normal.duplicate() as StyleBoxFlat
	card_pressed.border_color = Palette.CYAN
	card_pressed.shadow_color = Palette.with_alpha(Palette.CYAN, 0.3)
	card_pressed.shadow_size = 22
	var card_disabled := card_normal.duplicate() as StyleBoxFlat
	card_disabled.bg_color = Palette.with_alpha(Palette.SURFACE, 0.55)
	theme.set_stylebox("normal", "SkinCard", card_normal)
	theme.set_stylebox("hover", "SkinCard", card_hover)
	theme.set_stylebox("pressed", "SkinCard", card_pressed)
	theme.set_stylebox("disabled", "SkinCard", card_disabled)
	theme.set_stylebox("focus", "SkinCard", button_focus)

	# Danger action.
	theme.set_type_variation("DangerButton", "Button")
	theme.set_font("font", "DangerButton", rajdhani_semibold)
	theme.set_font_size("font_size", "DangerButton", 28)
	theme.set_color("font_color", "DangerButton", Palette.with_alpha(Palette.RED, 0.85))
	theme.set_color("font_hover_color", "DangerButton", Palette.WHITE)
	var danger_normal := _flat_box(Color(0, 0, 0, 0), Palette.with_alpha(Palette.RED, 0.25), 1, 12)
	danger_normal.content_margin_left = 24
	danger_normal.content_margin_right = 24
	danger_normal.content_margin_top = 16
	danger_normal.content_margin_bottom = 16
	var danger_hover := danger_normal.duplicate() as StyleBoxFlat
	danger_hover.bg_color = Palette.with_alpha(Palette.RED, 0.12)
	danger_hover.border_color = Palette.RED
	theme.set_stylebox("normal", "DangerButton", danger_normal)
	theme.set_stylebox("hover", "DangerButton", danger_hover)
	theme.set_stylebox("pressed", "DangerButton", danger_hover)

	# ---- Panels -----------------------------------------------------------
	var card_panel := _box(Palette.with_alpha(Palette.SURFACE, 0.94), Palette.with_alpha(Palette.WHITE, 0.07), 2, 26)
	card_panel.content_margin_left = 44
	card_panel.content_margin_right = 44
	card_panel.content_margin_top = 40
	card_panel.content_margin_bottom = 40
	card_panel.shadow_color = Color(0, 0, 0, 0.5)
	card_panel.shadow_size = 30
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", card_panel)
	theme.set_type_variation("CardPanelPanel", "Panel")
	theme.set_stylebox("panel", "CardPanelPanel", card_panel)
	theme.set_stylebox("panel", "PanelContainer", card_panel)
	theme.set_stylebox("panel", "Panel", card_panel)

	var chip_panel := _box(Palette.with_alpha(Palette.SURFACE, 0.9), Palette.with_alpha(Palette.CYAN, 0.22), 1, 999)
	chip_panel.content_margin_left = 22
	chip_panel.content_margin_right = 22
	chip_panel.content_margin_top = 8
	chip_panel.content_margin_bottom = 8
	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", chip_panel)

	var hud_panel := _box(Palette.with_alpha(Palette.SURFACE, 0.58), Palette.with_alpha(Palette.WHITE, 0.05), 1, 16)
	hud_panel.content_margin_left = 18
	hud_panel.content_margin_right = 18
	hud_panel.content_margin_top = 10
	hud_panel.content_margin_bottom = 10
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", hud_panel)

	var row_panel := _box(Palette.with_alpha(Palette.SURFACE, 0.5), Palette.with_alpha(Palette.WHITE, 0.045), 1, 18)
	row_panel.content_margin_left = 28
	row_panel.content_margin_right = 24
	row_panel.content_margin_top = 18
	row_panel.content_margin_bottom = 18
	theme.set_type_variation("RowPanel", "PanelContainer")
	theme.set_stylebox("panel", "RowPanel", row_panel)

	# ---- Progress bar / scroll -------------------------------------------
	var bar_bg := _box(Palette.with_alpha(Palette.WHITE, 0.07), Color(0, 0, 0, 0), 0, 999)
	bar_bg.content_margin_top = 7
	bar_bg.content_margin_bottom = 7
	var bar_fill := _box(Palette.CYAN, Color(0, 0, 0, 0), 0, 999)
	bar_fill.shadow_color = Palette.with_alpha(Palette.CYAN, 0.35)
	bar_fill.shadow_size = 8
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", Palette.WHITE)
	theme.set_font_size("font_size", "ProgressBar", 24)

	theme.set_stylebox("panel", "ScrollContainer", _flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))

	var scroll_bg := _box(Palette.with_alpha(Palette.WHITE, 0.04), Color(0, 0, 0, 0), 0, 999)
	var grabber := _box(Palette.with_alpha(Palette.CYAN, 0.45), Color(0, 0, 0, 0), 0, 999)
	var grabber_hot := _box(Palette.with_alpha(Palette.CYAN, 0.8), Color(0, 0, 0, 0), 0, 999)
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hot)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_hot)

	var line := StyleBoxLine.new()
	line.color = Palette.with_alpha(Palette.WHITE, 0.08)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 24)

	# Tooltip.
	var tooltip := _box(Color("#0C0C0C"), Palette.with_alpha(Palette.CYAN, 0.3), 1, 10)
	tooltip.content_margin_left = 16
	tooltip.content_margin_right = 16
	tooltip.content_margin_top = 8
	tooltip.content_margin_bottom = 8
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", Palette.WHITE)
	theme.set_font_size("font_size", "TooltipLabel", 24)

	var error := ResourceSaver.save(theme, OUTPUT)
	if error == OK:
		print("Theme written to ", OUTPUT)
	else:
		push_error("Could not save theme: %d" % error)
	quit()


func _label_variation(theme: Theme, name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _flat_box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	return _box(bg, border, border_width, radius)
