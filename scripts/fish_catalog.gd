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

## The Secret tier's entire roster. Unlike every other tier these are never
## reachable through FishRarity.roll() — Fisherman grants them through a
## separate, independent chance that only applies while a species' combo
## of weather/season/time-of-day is actually in effect.
const SECRET_SPECIES := [
	{"name": "The Drowned King", "weather": "Stormy", "season": "Winter", "night": true},
	{"name": "Glassfin Wraith", "weather": "Foggy", "night": true},
	{"name": "Sunlit Mirage", "weather": "Sunny", "season": "Summer", "night": false},
]

static var _catalog_by_tier: Dictionary = {}

static func _build_catalog() -> void:
	if not _catalog_by_tier.is_empty():
		return
	for tier in FishRarity.NORMAL_TIERS:
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
	var secret_list: Array = []
	for entry in SECRET_SPECIES:
		secret_list.append(FishSpecies.new(
			entry["name"], FishRarity.Tier.SECRET,
			entry.get("weather", ""), entry.get("season", ""), entry.get("night")
		))
	_catalog_by_tier[FishRarity.Tier.SECRET] = secret_list

static func species_for_tier(tier: FishRarity.Tier) -> Array:
	_build_catalog()
	return _catalog_by_tier[tier]

## Picks a random species of `tier` eligible under the current weather/
## season/time-of-day. Returns null if none qualify right now — routine
## for SECRET (which is condition-only), rare for every other tier (which
## always has at least a few ungated entries in the base grid).
static func roll_species(tier: FishRarity.Tier) -> FishSpecies:
	var species_list: Array = species_for_tier(tier)
	var current_weather: String = WorldClock.get_weather()
	var current_season: String = WorldClock.get_season_name()
	var is_night: bool = WorldClock.get_night_factor() >= 0.5
	var eligible: Array = []
	for species in species_list:
		if species.conditions_met(current_weather, current_season, is_night):
			eligible.append(species)
	if eligible.is_empty():
		return null
	return eligible.pick_random()
