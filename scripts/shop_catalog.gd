class_name ShopCatalog
extends RefCounted

static func default_items() -> Array:
	return [
		Item.new("Old Rod", "Rod", "speed", 0.15, 8),
		Item.new("Lucky Cap", "Hat", "luck", 0.15, 8),
		Item.new("Work Boots", "Outfit", "power", 0.15, 8),
		Item.new("Charm of Patience", "Charm", "speed", 0.10, 6),
		Item.new("Wriggling Worm", "Bait", "luck", 0.10, 6),
	]
