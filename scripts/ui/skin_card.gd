class_name SkinCard
extends Button
## One selectable skin tile. Premium tiles are inert and clearly labelled.

@onready var preview: SkinPreview = %Preview
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var accent_line: ColorRect = %AccentLine
@onready var lock_dim: ColorRect = %LockDim

var skin_id: String = ""


func setup(definition: Dictionary, selected: bool) -> void:
	skin_id = String(definition.get("id", "default"))
	preview.set_skin(definition)
	name_label.text = String(definition.get("name", "SKIN"))
	var coming_soon := bool(definition.get("coming_soon", false))
	disabled = coming_soon
	lock_dim.visible = coming_soon
	preview.modulate = Color(1, 1, 1, 0.35) if coming_soon else Color.WHITE
	if coming_soon:
		status_label.text = "COMING SOON"
		status_label.add_theme_color_override("font_color", Palette.GOLD)
	else:
		status_label.remove_theme_color_override("font_color")
		set_equipped(selected)
	tooltip_text = String(definition.get("tagline", ""))
	focus_mode = Control.FOCUS_NONE if coming_soon else Control.FOCUS_ALL


func set_equipped(selected: bool) -> void:
	if disabled:
		return
	accent_line.visible = selected
	status_label.text = "EQUIPPED" if selected else "TAP TO EQUIP"
	status_label.modulate = Palette.CYAN if selected else Palette.MUTED
	if selected:
		status_label.add_theme_color_override("font_color", Palette.CYAN)
	else:
		status_label.remove_theme_color_override("font_color")
