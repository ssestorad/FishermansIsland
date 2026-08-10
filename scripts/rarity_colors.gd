class_name RarityColors
extends RefCounted

const BY_TIER := {
	FishRarity.Tier.COMMON: Color(0.7, 0.7, 0.7),
	FishRarity.Tier.UNCOMMON: Color(0.4, 0.75, 0.4),
	FishRarity.Tier.RARE: Color(0.3, 0.5, 0.9),
	FishRarity.Tier.EPIC: Color(0.6, 0.35, 0.85),
	FishRarity.Tier.LEGENDARY: Color(0.9, 0.65, 0.15),
	FishRarity.Tier.MYTHIC: Color(0.85, 0.2, 0.25),
	FishRarity.Tier.SECRET: Color(0.12, 0.08, 0.2),
}

const BY_NAME := {
	"Common": Color(0.7, 0.7, 0.7),
	"Uncommon": Color(0.4, 0.75, 0.4),
	"Rare": Color(0.3, 0.5, 0.9),
	"Epic": Color(0.6, 0.35, 0.85),
	"Legendary": Color(0.9, 0.65, 0.15),
	"Mythic": Color(0.85, 0.2, 0.25),
	"Secret": Color(0.12, 0.08, 0.2),
}

static func for_tier(tier: FishRarity.Tier) -> Color:
	return BY_TIER.get(tier, Color(0.7, 0.7, 0.7))

static func for_name(rarity_name: String) -> Color:
	return BY_NAME.get(rarity_name, Color(0.7, 0.7, 0.7))
