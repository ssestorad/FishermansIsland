extends Node

signal coins_changed(new_total: int)
signal scales_changed(new_total: int)

var coins: int = 0
var scales: int = 0

const RARITY_VALUES := {
	FishRarity.Tier.COMMON: 1,
	FishRarity.Tier.UNCOMMON: 3,
	FishRarity.Tier.RARE: 8,
	FishRarity.Tier.EPIC: 20,
	FishRarity.Tier.LEGENDARY: 50,
	FishRarity.Tier.MYTHIC: 150,
}

const COIN_TIERS := [FishRarity.Tier.COMMON, FishRarity.Tier.UNCOMMON]

func add_currency_for_catch(rarity: FishRarity.Tier, weight: float) -> void:
	var base_value: float = RARITY_VALUES[rarity]
	var weight_multiplier: float = weight / FishRarity.average_weight(rarity)
	var amount := roundi(base_value * weight_multiplier)
	if rarity in COIN_TIERS:
		coins += amount
		coins_changed.emit(coins)
	else:
		scales += amount
		scales_changed.emit(scales)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func spend_scales(amount: int) -> bool:
	if scales < amount:
		return false
	scales -= amount
	scales_changed.emit(scales)
	return true

func load_state(new_coins: int, new_scales: int) -> void:
	coins = new_coins
	scales = new_scales
	coins_changed.emit(coins)
	scales_changed.emit(scales)
