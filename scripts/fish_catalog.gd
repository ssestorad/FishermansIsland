class_name FishCatalog
extends RefCounted

const BASE_NAMES := {
	FishRarity.Tier.COMMON: ["Minnow", "Sardine", "Gudgeon", "Bream", "Roach"],
	FishRarity.Tier.UNCOMMON: ["Perch", "Carp", "Trout", "Chub", "Rudd"],
	FishRarity.Tier.RARE: ["Bass", "Pike", "Catfish", "Eel", "Grayling"],
	FishRarity.Tier.EPIC: ["Salmon", "Sturgeon", "Barracuda", "Marlin", "Tarpon"],
	FishRarity.Tier.LEGENDARY: ["Swordfish", "Anglerfish", "Manta Ray", "Moray Eel", "Nautilus"],
	FishRarity.Tier.MYTHIC: ["Leviathan", "Kraken", "Siren", "Behemoth", "Wyrm"],
}

const ADJECTIVES := {
	FishRarity.Tier.COMMON: ["Common", "Small", "Grey", "Plain", "River"],
	FishRarity.Tier.UNCOMMON: ["Spotted", "Striped", "Silver", "Pond", "Creek"],
	FishRarity.Tier.RARE: ["Golden", "Shadow", "Deep", "Amber", "Coral"],
	FishRarity.Tier.EPIC: ["Crimson", "Storm", "Glacial", "Obsidian", "Radiant"],
	FishRarity.Tier.LEGENDARY: ["Ancient", "Celestial", "Phantom", "Runic", "Eternal"],
	FishRarity.Tier.MYTHIC: ["Abyssal", "Void", "Cosmic", "Primordial", "Draconic"],
}

static var _catalog_by_tier: Dictionary = {}

static func _build_catalog() -> void:
	if not _catalog_by_tier.is_empty():
		return
	for tier in FishRarity.Tier.values():
		var species_list: Array = []
		for adjective in ADJECTIVES[tier]:
			for base_name in BASE_NAMES[tier]:
				species_list.append(FishSpecies.new("%s %s" % [adjective, base_name], tier))
		_catalog_by_tier[tier] = species_list

static func species_for_tier(tier: FishRarity.Tier) -> Array:
	_build_catalog()
	return _catalog_by_tier[tier]

static func roll_species(tier: FishRarity.Tier) -> FishSpecies:
	var species_list: Array = species_for_tier(tier)
	return species_list.pick_random()
