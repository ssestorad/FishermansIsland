extends Node

signal rotated

const ROTATION_INTERVAL := 300.0  # 5 min
const SLOTS_COUNT := 8

const RARITY_WEIGHTS := {
	"Common": 50.0,
	"Uncommon": 25.0,
	"Rare": 15.0,
	"Epic": 7.0,
	"Legendary": 2.5,
	"Mythic": 0.5,
}

## Tier index for each rarity, used to scale MetaProgress's Shop Rarity
## Odds bonus proportionally to how rare the item already is — a Mythic
## gets 5x the boost a Rare does, so the upgrade meaningfully shifts the
## rotation toward the top instead of nudging everything equally.
const RARITY_ORDER := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

var current_items: Array = []
var _timer: float = 0.0

func _ready() -> void:
	_reroll()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= ROTATION_INTERVAL:
		_timer = 0.0
		_reroll()

func get_time_until_rotation() -> float:
	return maxf(0.0, ROTATION_INTERVAL - _timer)

func _reroll() -> void:
	current_items = _weighted_sample(ShopCatalog.available_items(), SLOTS_COUNT)
	rotated.emit()

func _weighted_sample(pool: Array, count: int) -> Array:
	var remaining: Array = pool.duplicate()
	var picked: Array = []
	while remaining.size() > 0 and picked.size() < count:
		var total := 0.0
		for item in remaining:
			total += _weight_for(item)
		var roll := randf() * total
		var cumulative := 0.0
		var chosen_index := 0
		for i in range(remaining.size()):
			cumulative += _weight_for(remaining[i])
			if roll <= cumulative:
				chosen_index = i
				break
		picked.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)
	return picked

func _weight_for(item) -> float:
	var base_weight: float = RARITY_WEIGHTS.get(item.rarity, 1.0)
	var tier_index := RARITY_ORDER.find(item.rarity)
	if tier_index <= 0:
		return base_weight
	return base_weight * (1.0 + MetaProgress.get_shop_rarity_bonus() * tier_index)
