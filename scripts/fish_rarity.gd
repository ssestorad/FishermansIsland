class_name FishRarity
extends RefCounted

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const WEIGHTS := {
	Tier.COMMON: 50.0,
	Tier.UNCOMMON: 25.0,
	Tier.RARE: 15.0,
	Tier.EPIC: 7.0,
	Tier.LEGENDARY: 2.5,
	Tier.MYTHIC: 0.5,
}

const NAMES := {
	Tier.COMMON: "Common",
	Tier.UNCOMMON: "Uncommon",
	Tier.RARE: "Rare",
	Tier.EPIC: "Epic",
	Tier.LEGENDARY: "Legendary",
	Tier.MYTHIC: "Mythic",
}

static func roll() -> Tier:
	var total := 0.0
	for w in WEIGHTS.values():
		total += w
	var roll_value := randf() * total
	var cumulative := 0.0
	for tier in WEIGHTS.keys():
		cumulative += WEIGHTS[tier]
		if roll_value <= cumulative:
			return tier
	return Tier.COMMON

static func name_for(tier: Tier) -> String:
	return NAMES[tier]

const WEIGHT_RANGES := {
	Tier.COMMON: Vector2(0.3, 2.0),
	Tier.UNCOMMON: Vector2(1.0, 4.0),
	Tier.RARE: Vector2(2.0, 8.0),
	Tier.EPIC: Vector2(4.0, 15.0),
	Tier.LEGENDARY: Vector2(8.0, 25.0),
	Tier.MYTHIC: Vector2(15.0, 50.0),
}

## Rolls a weight (kg) within the tier's range. `power` in [0, 1] biases
## the roll toward the top of the range (0 = uniform, 1 = always max).
static func roll_weight(tier: Tier, power: float = 0.0) -> float:
	var w_range: Vector2 = WEIGHT_RANGES[tier]
	var t := randf()
	t = t + (1.0 - t) * clampf(power, 0.0, 1.0)
	return lerpf(w_range.x, w_range.y, t)

static func average_weight(tier: Tier) -> float:
	var w_range: Vector2 = WEIGHT_RANGES[tier]
	return (w_range.x + w_range.y) / 2.0
