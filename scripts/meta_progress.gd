extends Node

signal updated

const LUCK_PER_LEVEL := 0.02
const DISCOUNT_PER_LEVEL := 0.02
const MAX_DISCOUNT := 0.3
const COIN_GAIN_PER_LEVEL := 0.03
const OFFLINE_EFFICIENCY_PER_LEVEL := 0.02
const MAX_OFFLINE_EFFICIENCY_BONUS := 0.3
const BASE_BENCH_COUNT := 2

var extra_slots: int = 0
var luck_level: int = 0
var discount_level: int = 0
var coin_gain_level: int = 0
var offline_efficiency_level: int = 0
var bench_capacity_level: int = 0

func get_global_luck_bonus() -> float:
	return luck_level * LUCK_PER_LEVEL

func get_shop_discount() -> float:
	return clampf(discount_level * DISCOUNT_PER_LEVEL, 0.0, MAX_DISCOUNT)

func get_global_coin_gain_bonus() -> float:
	return coin_gain_level * COIN_GAIN_PER_LEVEL

func get_offline_efficiency_bonus() -> float:
	return clampf(offline_efficiency_level * OFFLINE_EFFICIENCY_PER_LEVEL, 0.0, MAX_OFFLINE_EFFICIENCY_BONUS)

func get_bench_capacity() -> int:
	return BASE_BENCH_COUNT + bench_capacity_level

func buy_slot() -> void:
	extra_slots += 1
	updated.emit()

func buy_luck() -> void:
	luck_level += 1
	updated.emit()

func buy_discount() -> void:
	discount_level += 1
	updated.emit()

func buy_coin_gain() -> void:
	coin_gain_level += 1
	updated.emit()

func buy_offline_efficiency() -> void:
	offline_efficiency_level += 1
	updated.emit()

func buy_bench_capacity() -> void:
	bench_capacity_level += 1
	updated.emit()

func load_state(data: Dictionary) -> void:
	extra_slots = int(data.get("extra_slots", 0))
	luck_level = int(data.get("luck_level", 0))
	discount_level = int(data.get("discount_level", 0))
	coin_gain_level = int(data.get("coin_gain_level", 0))
	offline_efficiency_level = int(data.get("offline_efficiency_level", 0))
	bench_capacity_level = int(data.get("bench_capacity_level", 0))
	updated.emit()
