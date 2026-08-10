extends Node

signal coins_changed(new_total: int)

var coins: int = 0

const RARITY_VALUES := {
	FishRarity.Tier.COMMON: 1,
	FishRarity.Tier.UNCOMMON: 3,
	FishRarity.Tier.RARE: 8,
	FishRarity.Tier.EPIC: 20,
	FishRarity.Tier.LEGENDARY: 50,
	FishRarity.Tier.MYTHIC: 150,
}

func add_coins_for_catch(rarity: FishRarity.Tier) -> void:
	coins += RARITY_VALUES[rarity]
	coins_changed.emit(coins)
