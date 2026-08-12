extends Node

signal updated

const LUCK_PER_LEVEL := 0.02
const DISCOUNT_PER_LEVEL := 0.02
const MAX_DISCOUNT := 0.3
const COIN_GAIN_PER_LEVEL := 0.03
const OFFLINE_EFFICIENCY_PER_LEVEL := 0.02
const MAX_OFFLINE_EFFICIENCY_BONUS := 0.3
const BASE_BENCH_COUNT := 2

## Extra Fisherman Slot is capped so MAX_FISHERMEN_SLOTS(6, main.gd) +
## MAX_EXTRA_SLOTS lands exactly on the originally-envisioned 30-fisherman
## island cap, rather than growing forever.
const MAX_EXTRA_SLOTS := 24

## Global Speed/Power/Endurance mirror Luck's existing pattern (flat
## uncapped %/level, folded into Fisherman.get_effective_stat()'s
## environment_bonus) — added for symmetry across all four stat axes.
const SPEED_PER_LEVEL := 0.02
const POWER_PER_LEVEL := 0.02
const ENDURANCE_PER_LEVEL := 0.02

## Biases the shop rotation's weighted rarity sample toward higher tiers
## (see ShopRotation._weight_for()) — capped so Common items never
## actually disappear from the rotation, just get less likely.
const SHOP_RARITY_PER_LEVEL := 0.08
const MAX_SHOP_RARITY_LEVEL := 20
const MAX_SHOP_RARITY_BONUS := SHOP_RARITY_PER_LEVEL * MAX_SHOP_RARITY_LEVEL

## Shortens how long servicing any of the three needs takes (on top of
## Rest's existing separate Endurance-based reduction) — the account-wide
## counterpart to what Endurance already does per-fisherman for Rest alone.
const NEEDS_SERVICE_PER_LEVEL := 0.04
const MAX_NEEDS_SERVICE_LEVEL := 10
const MAX_NEEDS_SERVICE_BONUS := NEEDS_SERVICE_PER_LEVEL * MAX_NEEDS_SERVICE_LEVEL

## Raw-count upgrade, same shape as bench capacity: DockInventory's base
## capacity (60) plus this many extra slots per level. Capped (unlike
## bench capacity) at a 200-entry dock — DockPanelController rebuilds
## every row from scratch on each DockInventory.updated signal while the
## panel is open, and past ~200 entries that full rebuild noticeably
## stutters the game.
const DOCK_CAPACITY_PER_LEVEL := 10
const MAX_DOCK_CAPACITY_LEVEL := 14

## Extra concurrent slots on the Quest board, on top of
## QuestManager.ACTIVE_QUEST_COUNT. Capped (unlike bench/dock capacity) so
## the board can't grow past a size where "one quest at a time" stops
## meaning anything.
const MAX_QUEST_SLOT_LEVEL := 5

## Discounts the Coins cost of hiring the next fisherman
## (main.gd::_hire_cost_for_next_slot) — separate lever from Shop
## Discount, which only affects gear bought with Scales.
const HIRE_DISCOUNT_PER_LEVEL := 0.02
const MAX_HIRE_DISCOUNT := 0.3

## Boosts the (1 + luck + bonus) multiplier on SECRET_CATCH_BASE_CHANCE
## (fisherman.gd). Stays hidden/unbuyable in the shop until the player has
## actually caught a Secret-tier fish once (Album.has_caught_secret()) —
## same "discovery before disclosure" spirit as the Album's Secret tab.
const SECRET_CHANCE_PER_LEVEL := 0.1
const MAX_SECRET_CHANCE_LEVEL := 10
const MAX_SECRET_CHANCE_BONUS := SECRET_CHANCE_PER_LEVEL * MAX_SECRET_CHANCE_LEVEL

## One-time flat-cost unlock (not leveled): raises the perk roll for newly
## hired fishermen from 1-2 to 2-3 perks.
const PERK_SLOT_COST := 250

## Fishing spots are one-time unlocks too. The pond is always available,
## so only these two are ever bought. Offshore is priced steeply because
## every catch there is Rare or better, which routes straight to the dock.
const SPOT_COSTS := {"river_mouth": 30, "pier": 60, "offshore": 400}

var extra_slots: int = 0
var luck_level: int = 0
var discount_level: int = 0
var coin_gain_level: int = 0
var offline_efficiency_level: int = 0
var bench_capacity_level: int = 0
var speed_level: int = 0
var power_level: int = 0
var endurance_level: int = 0
var shop_rarity_level: int = 0
var needs_service_level: int = 0
var dock_capacity_level: int = 0
var hire_discount_level: int = 0
var secret_chance_level: int = 0
var extra_perk_slot_unlocked: bool = false
var quest_slot_level: int = 0
var unlocked_spots: Array = []

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

func get_global_speed_bonus() -> float:
	return speed_level * SPEED_PER_LEVEL

func get_global_power_bonus() -> float:
	return power_level * POWER_PER_LEVEL

func get_global_endurance_bonus() -> float:
	return endurance_level * ENDURANCE_PER_LEVEL

func get_shop_rarity_bonus() -> float:
	return clampf(shop_rarity_level * SHOP_RARITY_PER_LEVEL, 0.0, MAX_SHOP_RARITY_BONUS)

func get_needs_service_bonus() -> float:
	return clampf(needs_service_level * NEEDS_SERVICE_PER_LEVEL, 0.0, MAX_NEEDS_SERVICE_BONUS)

func get_dock_capacity_bonus() -> int:
	# Defensive floor to match buy_dock_capacity()'s cap, same
	# getter-clamps-too spirit as _max_fishermen_slots() in main.gd — also
	# what actually retroactively shrinks a save whose dock_capacity_level
	# was bought past 14 before this cap existed.
	return mini(dock_capacity_level, MAX_DOCK_CAPACITY_LEVEL) * DOCK_CAPACITY_PER_LEVEL

func get_hire_discount() -> float:
	return clampf(hire_discount_level * HIRE_DISCOUNT_PER_LEVEL, 0.0, MAX_HIRE_DISCOUNT)

func get_secret_chance_bonus() -> float:
	return clampf(secret_chance_level * SECRET_CHANCE_PER_LEVEL, 0.0, MAX_SECRET_CHANCE_BONUS)

func has_extra_perk_slot() -> bool:
	return extra_perk_slot_unlocked

func get_quest_slot_bonus() -> int:
	return quest_slot_level

func is_spot_unlocked(id: String) -> bool:
	return unlocked_spots.has(id)

func unlock_spot(id: String) -> void:
	if unlocked_spots.has(id):
		return
	unlocked_spots.append(id)
	updated.emit()

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

func buy_speed() -> void:
	speed_level += 1
	updated.emit()

func buy_power() -> void:
	power_level += 1
	updated.emit()

func buy_endurance() -> void:
	endurance_level += 1
	updated.emit()

func buy_shop_rarity() -> void:
	shop_rarity_level += 1
	updated.emit()

func buy_needs_service() -> void:
	needs_service_level += 1
	updated.emit()

func buy_dock_capacity() -> void:
	if dock_capacity_level >= MAX_DOCK_CAPACITY_LEVEL:
		return
	dock_capacity_level += 1
	updated.emit()

func buy_hire_discount() -> void:
	hire_discount_level += 1
	updated.emit()

func buy_secret_chance() -> void:
	secret_chance_level += 1
	updated.emit()

func buy_perk_slot() -> void:
	extra_perk_slot_unlocked = true
	updated.emit()

func buy_quest_slot() -> void:
	if quest_slot_level >= MAX_QUEST_SLOT_LEVEL:
		return
	quest_slot_level += 1
	updated.emit()

func load_state(data: Dictionary) -> void:
	extra_slots = int(data.get("extra_slots", 0))
	luck_level = int(data.get("luck_level", 0))
	discount_level = int(data.get("discount_level", 0))
	coin_gain_level = int(data.get("coin_gain_level", 0))
	offline_efficiency_level = int(data.get("offline_efficiency_level", 0))
	bench_capacity_level = int(data.get("bench_capacity_level", 0))
	speed_level = int(data.get("speed_level", 0))
	power_level = int(data.get("power_level", 0))
	endurance_level = int(data.get("endurance_level", 0))
	shop_rarity_level = int(data.get("shop_rarity_level", 0))
	needs_service_level = int(data.get("needs_service_level", 0))
	dock_capacity_level = int(data.get("dock_capacity_level", 0))
	hire_discount_level = int(data.get("hire_discount_level", 0))
	secret_chance_level = int(data.get("secret_chance_level", 0))
	extra_perk_slot_unlocked = bool(data.get("extra_perk_slot_unlocked", false))
	quest_slot_level = int(data.get("quest_slot_level", 0))
	# Saves from before fishing spots existed had everyone at the pier, so
	# it is granted rather than sold back to them.
	unlocked_spots = data.get("unlocked_spots", ["pier"])
	updated.emit()
