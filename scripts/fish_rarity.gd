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
