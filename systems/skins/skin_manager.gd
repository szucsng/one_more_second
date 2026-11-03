extends Node
## Cosmetic skin catalog and selection state.
##
## Skins are purely visual. The first five are free; premium entries are listed
## as "coming soon" so the store can be wired in later without faking purchases.

signal skin_changed(skin_id: String)

var _skins: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_skins = [
		{
			"id": "default",
			"name": "DEFAULT NEON",
			"tagline": "The original signal.",
			"primary": Color("#00F5FF"),
			"secondary": Color("#FFFFFF"),
			"accent": Color("#9D4EDD"),
			"trail": Color("#00F5FF"),
			"free": true,
			"coming_soon": false,
			"store_price": "",
		},
		{
			"id": "cyan",
			"name": "PURE CYAN",
			"tagline": "Cold, clean, precise.",
			"primary": Color("#00F5FF"),
			"secondary": Color("#B8FDFF"),
			"accent": Color("#00A8C0"),
			"trail": Color("#B8FDFF"),
			"free": true,
			"coming_soon": false,
			"store_price": "",
		},
		{
			"id": "purple",
			"name": "VIOLET SHIFT",
			"tagline": "After-hours frequency.",
			"primary": Color("#A66BFF"),
			"secondary": Color("#E6C9FF"),
			"accent": Color("#5A189A"),
			"trail": Color("#9D4EDD"),
			"free": true,
			"coming_soon": false,
			"store_price": "",
		},
		{
			"id": "pink",
			"name": "HOT SIGNAL",
			"tagline": "Loud on purpose.",
			"primary": Color("#FF2E93"),
			"secondary": Color("#FFC2DF"),
			"accent": Color("#B0005A"),
			"trail": Color("#FF2E93"),
			"free": true,
			"coming_soon": false,
			"store_price": "",
		},
		{
			"id": "gold",
			"name": "GOLD RUSH",
			"tagline": "For the record chasers.",
			"primary": Color("#FFC857"),
			"secondary": Color("#FFF1B8"),
			"accent": Color("#B8860B"),
			"trail": Color("#FFC857"),
			"free": true,
			"coming_soon": false,
			"store_price": "",
		},
		{
			"id": "aurora",
			"name": "AURORA",
			"tagline": "Premium skin.",
			"primary": Color("#00FFA3"),
			"secondary": Color("#C9FFE9"),
			"accent": Color("#9D4EDD"),
			"trail": Color("#00FFA3"),
			"free": false,
			"coming_soon": true,
			"store_price": "€0.99",
		},
		{
			"id": "solar",
			"name": "SOLAR FLARE",
			"tagline": "Premium skin.",
			"primary": Color("#FF8A00"),
			"secondary": Color("#FFE3B0"),
			"accent": Color("#FF2E93"),
			"trail": Color("#FF8A00"),
			"free": false,
			"coming_soon": true,
			"store_price": "€0.99",
		},
		{
			"id": "void",
			"name": "VOIDWALKER",
			"tagline": "Premium skin.",
			"primary": Color("#7B61FF"),
			"secondary": Color("#D8D2FF"),
			"accent": Color("#00F5FF"),
			"trail": Color("#7B61FF"),
			"free": false,
			"coming_soon": true,
			"store_price": "€0.99",
		},
	]


func get_all() -> Array[Dictionary]:
	return _skins


func get_definition(skin_id: String) -> Dictionary:
	for skin in _skins:
		if String(skin["id"]) == skin_id:
			return skin
	return _skins[0]


func get_selected_id() -> String:
	var id := SaveManager.get_selected_skin()
	if get_definition(id)["id"] != id:
		return "default"
	return id


func get_selected() -> Dictionary:
	return get_definition(get_selected_id())


func is_available(skin_id: String) -> bool:
	var definition := get_definition(skin_id)
	return bool(definition["free"]) or SaveManager.is_skin_unlocked(skin_id)


func select(skin_id: String) -> bool:
	if not is_available(skin_id):
		return false
	SaveManager.set_selected_skin(skin_id)
	Analytics.track("skin_selected", {"skin": skin_id})
	skin_changed.emit(skin_id)
	return true
