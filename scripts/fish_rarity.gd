class_name FishRarity
extends RefCounted

## SECRET is deliberately last and absent from WEIGHTS: roll() only ever
## iterates WEIGHTS' keys, so a normal Luck roll can never produce it. It's
## granted through its own condition-gated chance in Fisherman instead.
enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, SECRET }

## The rarest tier reachable through a normal Luck roll — used to normalize
## luck-XP gain so adding SECRET above it doesn't shift that math.
const MAX_ROLLABLE_TIER := Tier.MYTHIC

## The six tiers that make up the generated fish grid. Code that means
## "every ordinary tier" (building the catalog, Album tabs before Secret
## is unlocked) should iterate this instead of Tier.values(), which also
## includes SECRET.
const NORMAL_TIERS := [Tier.COMMON, Tier.UNCOMMON, Tier.RARE, Tier.EPIC, Tier.LEGENDARY, Tier.MYTHIC]

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
	Tier.SECRET: "Secret",
}

## Rolls a rarity tier. `luck` in [0, 1] biases the roll toward rarer
## tiers (0 = the raw weighted table, 1 = always the rarest tier),
## using the same skew as roll_weight().
static func roll(luck: float = 0.0) -> Tier:
	var total := 0.0
	for w in WEIGHTS.values():
		total += w
	var t := randf()
	t = t + (1.0 - t) * clampf(luck, 0.0, 1.0)
	var roll_value := t * total
	var cumulative := 0.0
	for tier in WEIGHTS.keys():
		cumulative += WEIGHTS[tier]
		if roll_value <= cumulative:
			return tier
	return Tier.MYTHIC

static func name_for(tier: Tier) -> String:
	return NAMES[tier]

## Reverse of name_for(), so the species catalog can spell tiers as short
## readable strings instead of repeating FishRarity.Tier.X 120 times.
static func tier_from_name(tier_name: String) -> Tier:
	for tier in NAMES:
		if NAMES[tier] == tier_name:
			return tier
	push_error("Unknown fish tier name: %s" % tier_name)
	return Tier.COMMON

## Fallback weight bands. Species carry their own ranges now; these only
## cover entries whose species can no longer be looked up — dock items and
## catch-history rows saved under a species name that has since been
## retired from the catalog.
const WEIGHT_RANGES := {
	Tier.COMMON: Vector2(0.3, 2.0),
	Tier.UNCOMMON: Vector2(1.0, 4.0),
	Tier.RARE: Vector2(2.0, 8.0),
	Tier.EPIC: Vector2(4.0, 15.0),
	Tier.LEGENDARY: Vector2(8.0, 25.0),
	Tier.MYTHIC: Vector2(15.0, 50.0),
	Tier.SECRET: Vector2(20.0, 60.0),
}

## Fallback average for the tier band; prefer FishSpecies.average_weight().
static func average_weight(tier: Tier) -> float:
	var w_range: Vector2 = WEIGHT_RANGES[tier]
	return (w_range.x + w_range.y) / 2.0
