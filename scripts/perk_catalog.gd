class_name PerkCatalog
extends RefCounted

# Each entry: {name, description, effects: [[axis, amount], ...], condition}.
# condition mirrors Item's ({} = always active; may contain weather/season/night).
const PERKS := [
	{"name": "Powerhouse", "description": "+8% Power", "effects": [["power", 0.08]], "condition": {}},
	{"name": "Nimble", "description": "+8% Speed", "effects": [["speed", 0.08]], "condition": {}},
	{"name": "Lucky", "description": "+8% Luck", "effects": [["luck", 0.08]], "condition": {}},
	{"name": "Night Owl", "description": "+10% Luck at night", "effects": [["luck", 0.1]], "condition": {"night": true}},
	{"name": "Storm Chaser", "description": "+10% Luck in storms", "effects": [["luck", 0.1]], "condition": {"weather": "Stormy"}},
	{"name": "Cold-Blooded", "description": "+10% Speed in Winter", "effects": [["speed", 0.1]], "condition": {"season": "Winter"}},
	{"name": "Quick Feet", "description": "+15% walking speed", "effects": [["walk_speed", 0.15]], "condition": {}},
	{"name": "Well-Rested", "description": "-15% rest time", "effects": [["rest_time", 0.15]], "condition": {}},
	{"name": "Second Wind", "description": "+10% Endurance", "effects": [["endurance", 0.1]], "condition": {}},
	{"name": "Iron Grip", "description": "+6% Power", "effects": [["power", 0.06]], "condition": {}},
	{"name": "Steady Hands", "description": "+6% Speed", "effects": [["speed", 0.06]], "condition": {}},
	{"name": "Foggy Sense", "description": "+10% Luck in fog", "effects": [["luck", 0.1]], "condition": {"weather": "Foggy"}},
	{"name": "Rainy Focus", "description": "+8% Luck in rain", "effects": [["luck", 0.08]], "condition": {"weather": "Rainy"}},
	{"name": "Blizzard Blood", "description": "+12% Endurance in blizzards", "effects": [["endurance", 0.12]], "condition": {"weather": "Blizzard"}},
	{"name": "Summer Hustle", "description": "+10% Speed in Summer", "effects": [["speed", 0.1]], "condition": {"season": "Summer"}},
	{"name": "Autumn Grind", "description": "+8% Power in Autumn", "effects": [["power", 0.08]], "condition": {"season": "Autumn"}},
	{"name": "Spring Step", "description": "+12% walking speed in Spring", "effects": [["walk_speed", 0.12]], "condition": {"season": "Spring"}},
]

static func find(perk_name: String) -> Dictionary:
	for perk in PERKS:
		if perk.name == perk_name:
			return perk
	return {}

## Rolls `count` distinct perk names for a newly hired fisherman.
static func roll_perk_names(count: int) -> Array:
	var pool: Array = PERKS.duplicate()
	pool.shuffle()
	var picked: Array = []
	for i in range(mini(count, pool.size())):
		picked.append(pool[i].name)
	return picked
