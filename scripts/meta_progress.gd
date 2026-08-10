extends Node

signal updated

const LUCK_PER_LEVEL := 0.02
const DISCOUNT_PER_LEVEL := 0.02
const MAX_DISCOUNT := 0.3

var extra_slots: int = 0
var luck_level: int = 0
var discount_level: int = 0

func get_global_luck_bonus() -> float:
	return luck_level * LUCK_PER_LEVEL

func get_shop_discount() -> float:
	return clampf(discount_level * DISCOUNT_PER_LEVEL, 0.0, MAX_DISCOUNT)

func buy_slot() -> void:
	extra_slots += 1
	updated.emit()

func buy_luck() -> void:
	luck_level += 1
	updated.emit()

func buy_discount() -> void:
	discount_level += 1
	updated.emit()

func load_state(data: Dictionary) -> void:
	extra_slots = int(data.get("extra_slots", 0))
	luck_level = int(data.get("luck_level", 0))
	discount_level = int(data.get("discount_level", 0))
	updated.emit()
