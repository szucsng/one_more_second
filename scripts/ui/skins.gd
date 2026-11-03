extends Control
## Skin gallery. Selection is instant, free, and cosmetic only.

const CARD_SCENE := preload("res://scenes/skins/SkinCard.tscn")

@onready var back_button: Button = %BackButton
@onready var preview: SkinPreview = %Preview
@onready var skin_name: Label = %SkinName
@onready var skin_tagline: Label = %SkinTagline
@onready var grid: GridContainer = %Grid
@onready var footer: Label = %Footer

var _cards: Array[SkinCard] = []


func _ready() -> void:
	Platform.apply_safe_margins($Content, 76, 62, 76, 44)
	back_button.pressed.connect(_go_back)
	_build_cards()
	_refresh_preview(SkinManager.get_selected_id())
	back_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	SceneRouter.go_menu()


func _build_cards() -> void:
	var definitions := SkinManager.get_all()
	var selected := SkinManager.get_selected_id()
	var unlocked_count := 0
	for definition in definitions:
		var card := CARD_SCENE.instantiate() as SkinCard
		grid.add_child(card)
		card.setup(definition, String(definition["id"]) == selected)
		_cards.append(card)
		if not bool(definition["coming_soon"]):
			unlocked_count += 1
		var id := String(definition["id"])
		if not bool(definition["coming_soon"]):
			card.pressed.connect(_on_skin_pressed.bind(id))
	footer.text = "%d FREE / %d TOTAL  •  PREMIUM SKINS LATER  •  STORE INACTIVE" % [unlocked_count, definitions.size()]


func _on_skin_pressed(skin_id: String) -> void:
	if not SkinManager.select(skin_id):
		return
	for card in _cards:
		card.set_equipped(card.skin_id == skin_id)
	_refresh_preview(skin_id)
	AudioManager.play_ui_tap()
	Platform.vibrate(10)


func _refresh_preview(skin_id: String) -> void:
	var definition := SkinManager.get_definition(skin_id)
	preview.set_skin(definition)
	skin_name.text = String(definition.get("name", "DEFAULT NEON"))
	skin_tagline.text = String(definition.get("tagline", ""))
