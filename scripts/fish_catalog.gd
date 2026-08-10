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

# Bonus species layered on top of the generated grid, only catchable
# while the given weather is active.
const WEATHER_EXCLUSIVE_SPECIES := [
	{"name": "Frostbound Wyrm", "tier": FishRarity.Tier.MYTHIC, "weather": "Blizzard"},
]

# Bonus species layered on top of the generated grid, only catchable
# during the given season (any weather).
const SEASON_EXCLUSIVE_SPECIES := [
	{"name": "Bloomtail Carp", "tier": FishRarity.Tier.LEGENDARY, "season": "Spring"},
	{"name": "Sunscale Marlin", "tier": FishRarity.Tier.LEGENDARY, "season": "Summer"},
	{"name": "Harvest Salmon", "tier": FishRarity.Tier.LEGENDARY, "season": "Autumn"},
	{"name": "Icebound Sturgeon", "tier": FishRarity.Tier.LEGENDARY, "season": "Winter"},
]

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
	for entry in WEATHER_EXCLUSIVE_SPECIES:
		_catalog_by_tier[entry["tier"]].append(
			FishSpecies.new(entry["name"], entry["tier"], entry["weather"], "")
		)
	for entry in SEASON_EXCLUSIVE_SPECIES:
		_catalog_by_tier[entry["tier"]].append(
			FishSpecies.new(entry["name"], entry["tier"], "", entry["season"])
		)

static func species_for_tier(tier: FishRarity.Tier) -> Array:
	_build_catalog()
	return _catalog_by_tier[tier]

static func roll_species(tier: FishRarity.Tier) -> FishSpecies:
	var species_list: Array = species_for_tier(tier)
	var current_weather: String = WorldClock.get_weather()
	var current_season: String = WorldClock.get_season_name()
	var eligible: Array = []
	for species in species_list:
		var weather_ok: bool = species.required_weather == "" or species.required_weather == current_weather
		var season_ok: bool = species.required_season == "" or species.required_season == current_season
		if weather_ok and season_ok:
			eligible.append(species)
	return eligible.pick_random()
