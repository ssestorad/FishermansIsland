extends Node

signal rotated

const ROTATION_INTERVAL := 20.0  # placeholder for testing; design target is 300s (5 min)
const SLOTS_COUNT := 8

const RARITY_WEIGHTS := {
	"Common": 50.0,
	"Uncommon": 25.0,
	"Rare": 15.0,
	"Epic": 7.0,
	"Legendary": 2.5,
	"Mythic": 0.5,
}

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
			total += RARITY_WEIGHTS.get(item.rarity, 1.0)
		var roll := randf() * total
		var cumulative := 0.0
		var chosen_index := 0
		for i in range(remaining.size()):
			cumulative += RARITY_WEIGHTS.get(remaining[i].rarity, 1.0)
			if roll <= cumulative:
				chosen_index = i
				break
		picked.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)
	return picked
