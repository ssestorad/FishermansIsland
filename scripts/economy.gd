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
	FishRarity.Tier.SECRET: 400,
}

const COIN_TIERS := [FishRarity.Tier.COMMON, FishRarity.Tier.UNCOMMON]

func _catch_value(rarity: FishRarity.Tier, weight: float, bonus: float = 0.0) -> int:
	var base_value: float = RARITY_VALUES[rarity]
	var weight_multiplier: float = weight / FishRarity.average_weight(rarity)
	return roundi(base_value * weight_multiplier * (1.0 + bonus))

## Read-only preview of what a catch/dock sale would be worth, without
## granting it — used by the Dock panel to show a price before selling.
func preview_value(rarity: FishRarity.Tier, weight: float, bonus: float = 0.0) -> int:
	return _catch_value(rarity, weight, bonus)

func add_currency_for_catch(rarity: FishRarity.Tier, weight: float, coin_bonus: float = 0.0, scale_bonus: float = 0.0) -> Dictionary:
	if rarity in COIN_TIERS:
		var gained := _catch_value(rarity, weight, coin_bonus)
		coins += gained
		coins_changed.emit(coins)
		return {"currency": "Coins", "amount": gained}
	else:
		var gained := _catch_value(rarity, weight, scale_bonus)
		scales += gained
		scales_changed.emit(scales)
		return {"currency": "Scales", "amount": gained}

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func add_scales(amount: int) -> void:
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
