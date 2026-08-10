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

func add_coins_for_catch(rarity: FishRarity.Tier, weight: float) -> void:
	var base_value: float = RARITY_VALUES[rarity]
	var weight_multiplier: float = weight / FishRarity.average_weight(rarity)
	coins += roundi(base_value * weight_multiplier)
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
