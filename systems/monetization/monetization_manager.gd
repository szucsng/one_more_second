extends Node
## Store abstraction, intentionally inactive in v1.
##
## No fake purchase flow is exposed. When the platform billing plugins are
## added, implement `purchase()`/`restore()` here and the skins screen can turn
## the "COMING SOON" labels into buy buttons without touching game code.

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)

const PRODUCTS := [
	{
		"id": "skin_aurora",
		"type": "skin",
		"skin": "aurora",
		"title": "AURORA SKIN",
		"price": "€0.99",
		"description": "A green-violet signal from the edge of the grid.",
	},
	{
		"id": "skin_solar",
		"type": "skin",
		"skin": "solar",
		"title": "SOLAR FLARE SKIN",
		"price": "€0.99",
		"description": "Burn brighter than the record you are chasing.",
	},
	{
		"id": "skin_void",
		"type": "skin",
		"skin": "void",
		"title": "VOIDWALKER SKIN",
		"price": "€0.99",
		"description": "A quiet silhouette with a cyan afterimage.",
	},
	{
		"id": "skin_pack_neon",
		"type": "pack",
		"skins": ["aurora", "solar", "void"],
		"title": "NEON PACK",
		"price": "€1.99",
		"description": "All three premium skins in one bundle.",
	},
	{
		"id": "remove_ads",
		"type": "no_ads",
		"title": "REMOVE ADS",
		"price": "€1.99",
		"description": "One-time purchase. Rewarded ads stay optional.",
	},
]

var store_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_products() -> Array:
	return PRODUCTS


func is_product_owned(product_id: String) -> bool:
	return SaveManager.data.get("store", {}).get("owned", []).has(product_id)


func get_product(product_id: String) -> Dictionary:
	for product: Dictionary in PRODUCTS:
		if String(product["id"]) == product_id:
			return product
	return {}


## Returns false while the store is not configured. UI must show "coming soon"
## instead of pretending a transaction happened.
func purchase(product_id: String) -> bool:
	if not store_available:
		purchase_failed.emit(product_id, "store_unavailable")
		return false
	purchase_failed.emit(product_id, "not_implemented")
	return false


func restore_purchases() -> void:
	if not store_available:
		return


func ads_removed() -> bool:
	return is_product_owned("remove_ads")
