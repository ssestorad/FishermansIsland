class_name MetaPanelController
extends PanelController

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

const SLOT_BASE_COST := 20
const SLOT_GROWTH := 1.3
## MAX_FISHERMEN_SLOTS(6, main.gd) + this = the 30-fisherman island cap.
const SLOT_MAX_LEVEL := MetaProgress.MAX_EXTRA_SLOTS
const LUCK_BASE_COST := 10
const LUCK_GROWTH := 1.25
const SPEED_BASE_COST := 10
const SPEED_GROWTH := 1.25
const POWER_BASE_COST := 10
const POWER_GROWTH := 1.25
const ENDURANCE_BASE_COST := 10
const ENDURANCE_GROWTH := 1.25
const DISCOUNT_BASE_COST := 15
const DISCOUNT_GROWTH := 1.3
const DISCOUNT_MAX_LEVEL := 15
const HIRE_DISCOUNT_BASE_COST := 12
const HIRE_DISCOUNT_GROWTH := 1.3
const HIRE_DISCOUNT_MAX_LEVEL := 15
const COIN_GAIN_BASE_COST := 12
const COIN_GAIN_GROWTH := 1.25
const OFFLINE_BASE_COST := 18
const OFFLINE_GROWTH := 1.3
const OFFLINE_MAX_LEVEL := 15
const BENCH_BASE_COST := 14
const BENCH_GROWTH := 1.3
const DOCK_CAPACITY_BASE_COST := 15
const DOCK_CAPACITY_GROWTH := 1.3
const NEEDS_SERVICE_BASE_COST := 16
const NEEDS_SERVICE_GROWTH := 1.35
const NEEDS_SERVICE_MAX_LEVEL := MetaProgress.MAX_NEEDS_SERVICE_LEVEL
const SHOP_RARITY_BASE_COST := 16
const SHOP_RARITY_GROWTH := 1.3
const SHOP_RARITY_MAX_LEVEL := MetaProgress.MAX_SHOP_RARITY_LEVEL
const SECRET_CHANCE_BASE_COST := 30
const SECRET_CHANCE_GROWTH := 1.35
const SECRET_CHANCE_MAX_LEVEL := MetaProgress.MAX_SECRET_CHANCE_LEVEL
const QUEST_SLOT_BASE_COST := 25
const QUEST_SLOT_GROWTH := 1.35
const QUEST_SLOT_MAX_LEVEL := MetaProgress.MAX_QUEST_SLOT_LEVEL

const SLOT_COLOR := Color(0.3, 0.5, 0.65)
const LUCK_COLOR := Color(0.45, 0.75, 0.4)
const SPEED_COLOR := Color(0.35, 0.55, 0.85)
const POWER_COLOR := Color(0.85, 0.45, 0.3)
const ENDURANCE_COLOR := Color(0.55, 0.4, 0.75)
const DISCOUNT_COLOR := Color(0.85, 0.6, 0.25)
const HIRE_DISCOUNT_COLOR := Color(0.75, 0.5, 0.3)
const COIN_GAIN_COLOR := Color(0.95, 0.78, 0.25)
const OFFLINE_COLOR := Color(0.55, 0.45, 0.85)
const BENCH_COLOR := Color(0.5, 0.62, 0.35)
const DOCK_CAPACITY_COLOR := Color(0.3, 0.6, 0.7)
const NEEDS_SERVICE_COLOR := Color(0.6, 0.55, 0.35)
const SHOP_RARITY_COLOR := Color(0.75, 0.55, 0.85)
const PERK_SLOT_COLOR := Color(0.4, 0.65, 0.55)
const EXPEDITIONS_COLOR := Color(0.32, 0.3, 0.55)
const SPOT_COLOR := Color(0.28, 0.55, 0.62)
const SECRET_CHANCE_COLOR := Color(0.35, 0.22, 0.5)
const QUEST_SLOT_COLOR := Color(0.65, 0.5, 0.25)

## Every "leveled, cost = base * growth^level, buy via one MetaProgress
## call" upgrade drives off this table through one generic
## refresh/cost/buy path (_refresh_upgrade/_upgrade_cost/_on_buy_upgrade
## below) instead of a hand-written triplet per upgrade. `max_level` of -1
## means uncapped. Title/subtitle text still varies per upgrade (a %
## bonus, a raw count, a static name...), so those are read through a
## small `match` dispatch (_upgrade_title/_upgrade_subtitle) — the same
## id-keyed idiom QuestManager.UPGRADE_LABELS/_upgrade_level() already
## uses for reading MetaProgress state generically.
##
## Four upgrades stay hand-written rather than forced into this table:
## fishing spots (id-keyed one-time unlocks, not leveled), Extra Perk Slot
## and Expeditions (both one-time flat-cost unlocks, no level), and Secret
## Catch Chance (hidden until Album.has_caught_secret(), needs its own
## visibility gate).
const UPGRADES := [
	{"id": "slot", "color": SLOT_COLOR, "base_cost": SLOT_BASE_COST, "growth": SLOT_GROWTH,
	 "max_level": SLOT_MAX_LEVEL, "max_subtitle": "Maxed out (30 total)"},
	{"id": "luck", "color": LUCK_COLOR, "base_cost": LUCK_BASE_COST, "growth": LUCK_GROWTH, "max_level": -1},
	{"id": "speed", "color": SPEED_COLOR, "base_cost": SPEED_BASE_COST, "growth": SPEED_GROWTH, "max_level": -1},
	{"id": "power", "color": POWER_COLOR, "base_cost": POWER_BASE_COST, "growth": POWER_GROWTH, "max_level": -1},
	{"id": "endurance", "color": ENDURANCE_COLOR, "base_cost": ENDURANCE_BASE_COST, "growth": ENDURANCE_GROWTH, "max_level": -1},
	{"id": "discount", "color": DISCOUNT_COLOR, "base_cost": DISCOUNT_BASE_COST, "growth": DISCOUNT_GROWTH, "max_level": DISCOUNT_MAX_LEVEL},
	{"id": "hire_discount", "color": HIRE_DISCOUNT_COLOR, "base_cost": HIRE_DISCOUNT_BASE_COST, "growth": HIRE_DISCOUNT_GROWTH, "max_level": HIRE_DISCOUNT_MAX_LEVEL},
	{"id": "coin_gain", "color": COIN_GAIN_COLOR, "base_cost": COIN_GAIN_BASE_COST, "growth": COIN_GAIN_GROWTH, "max_level": -1},
	{"id": "offline", "color": OFFLINE_COLOR, "base_cost": OFFLINE_BASE_COST, "growth": OFFLINE_GROWTH, "max_level": OFFLINE_MAX_LEVEL},
	{"id": "bench", "color": BENCH_COLOR, "base_cost": BENCH_BASE_COST, "growth": BENCH_GROWTH, "max_level": -1},
	{"id": "dock_capacity", "color": DOCK_CAPACITY_COLOR, "base_cost": DOCK_CAPACITY_BASE_COST, "growth": DOCK_CAPACITY_GROWTH, "max_level": MetaProgress.MAX_DOCK_CAPACITY_LEVEL},
	{"id": "needs_service", "color": NEEDS_SERVICE_COLOR, "base_cost": NEEDS_SERVICE_BASE_COST, "growth": NEEDS_SERVICE_GROWTH, "max_level": NEEDS_SERVICE_MAX_LEVEL},
	{"id": "shop_rarity", "color": SHOP_RARITY_COLOR, "base_cost": SHOP_RARITY_BASE_COST, "growth": SHOP_RARITY_GROWTH, "max_level": SHOP_RARITY_MAX_LEVEL},
	{"id": "quest_slot", "color": QUEST_SLOT_COLOR, "base_cost": QUEST_SLOT_BASE_COST, "growth": QUEST_SLOT_GROWTH, "max_level": QUEST_SLOT_MAX_LEVEL},
]

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/MetaScroll/MetaRows

## id -> row, for every table-driven upgrade above.
var _upgrade_rows: Dictionary = {}
var _perk_slot_row: ListRow
var _secret_chance_row: ListRow
var _expeditions_row: ListRow
## id -> row, for the buyable fishing spots (the pond is free).
var _spot_rows: Dictionary = {}

func _on_ready() -> void:
	Economy.scales_changed.connect(_on_state_changed)
	MetaProgress.updated.connect(_on_state_changed)
	# Secret Catch Chance stays hidden until the first Secret-tier catch —
	# needs its own refresh trigger since that's an Album event, not a
	# MetaProgress/Economy one.
	Album.updated.connect(_on_state_changed)
	_build()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func _on_state_changed(_value = null) -> void:
	if visible:
		refresh()

func _build() -> void:
	UiListUtils.clear_children(rows_container)

	# Spots first: they gate what everything else is worth.
	_spot_rows.clear()
	for id in MetaProgress.SPOT_COSTS:
		_spot_rows[id] = _make_row(_on_buy_spot.bind(id))

	_upgrade_rows.clear()
	for upgrade in UPGRADES:
		_upgrade_rows[upgrade.id] = _make_row(_on_buy_upgrade.bind(upgrade))

	_perk_slot_row = _make_row(_on_buy_perk_slot)
	_secret_chance_row = _make_row(_on_buy_secret_chance)
	_expeditions_row = _make_row(_on_buy_expeditions)

	refresh()

func _make_row(callback: Callable) -> ListRow:
	var row: ListRow = LIST_ROW_SCENE.instantiate()
	row.pressed.connect(callback)
	rows_container.add_child(row)
	return row

func refresh() -> void:
	if _upgrade_rows.is_empty():
		return

	_refresh_spots()
	for upgrade in UPGRADES:
		_refresh_upgrade(upgrade)
	_refresh_perk_slot()
	_refresh_secret_chance()
	_refresh_expeditions()

## One-time unlocks rather than levels, so a bought spot shows what it
## gives rather than a price.
func _refresh_spots() -> void:
	for id in _spot_rows:
		var row: ListRow = _spot_rows[id]
		var cost: int = MetaProgress.SPOT_COSTS[id]
		var label := "Unlock %s" % FishingSpots.display_name(id)
		if MetaProgress.is_spot_unlocked(id):
			row.setup(label, FishingSpots.get_spot(id).blurb, "OWNED", SPOT_COLOR)
			row.disabled = true
			continue
		row.setup(label, FishingSpots.get_spot(id).blurb, "%d Scales" % cost, SPOT_COLOR)
		row.disabled = Economy.scales < cost

func _on_buy_spot(id: String) -> void:
	if MetaProgress.is_spot_unlocked(id):
		return
	if Economy.spend_scales(MetaProgress.SPOT_COSTS[id]):
		MetaProgress.unlock_spot(id)

func _refresh_upgrade(upgrade: Dictionary) -> void:
	var row: ListRow = _upgrade_rows[upgrade.id]
	var id: String = upgrade.id
	var max_level: int = upgrade.max_level
	var level := _upgrade_level(id)
	if max_level >= 0 and level >= max_level:
		row.setup(_upgrade_title(id), upgrade.get("max_subtitle", "Maxed out"), "MAX", upgrade.color)
		row.disabled = true
		return
	var cost := _upgrade_cost(upgrade)
	row.setup(_upgrade_title(id), _upgrade_subtitle(id), "%d Scales" % cost, upgrade.color)
	row.disabled = Economy.scales < cost

func _upgrade_cost(upgrade: Dictionary) -> int:
	return int(round(float(upgrade.base_cost) * pow(float(upgrade.growth), float(_upgrade_level(upgrade.id)))))

func _on_buy_upgrade(upgrade: Dictionary) -> void:
	var max_level: int = upgrade.max_level
	if max_level >= 0 and _upgrade_level(upgrade.id) >= max_level:
		return
	if Economy.spend_scales(_upgrade_cost(upgrade)):
		_upgrade_buy(upgrade.id)

func _upgrade_level(id: String) -> int:
	match id:
		"slot": return MetaProgress.extra_slots
		"luck": return MetaProgress.luck_level
		"speed": return MetaProgress.speed_level
		"power": return MetaProgress.power_level
		"endurance": return MetaProgress.endurance_level
		"discount": return MetaProgress.discount_level
		"hire_discount": return MetaProgress.hire_discount_level
		"coin_gain": return MetaProgress.coin_gain_level
		"offline": return MetaProgress.offline_efficiency_level
		"bench": return MetaProgress.bench_capacity_level
		"dock_capacity": return MetaProgress.dock_capacity_level
		"needs_service": return MetaProgress.needs_service_level
		"shop_rarity": return MetaProgress.shop_rarity_level
		"quest_slot": return MetaProgress.quest_slot_level
		_: return 0

func _upgrade_title(id: String) -> String:
	match id:
		"slot": return "Extra Fisherman Slot"
		"luck": return "Global Luck +%.0f%%" % [MetaProgress.get_global_luck_bonus() * 100.0]
		"speed": return "Global Speed +%.0f%%" % [MetaProgress.get_global_speed_bonus() * 100.0]
		"power": return "Global Power +%.0f%%" % [MetaProgress.get_global_power_bonus() * 100.0]
		"endurance": return "Global Endurance +%.0f%%" % [MetaProgress.get_global_endurance_bonus() * 100.0]
		"discount": return "Shop Discount -%.0f%%" % [MetaProgress.get_shop_discount() * 100.0]
		"hire_discount": return "Hire Cost -%.0f%%" % [MetaProgress.get_hire_discount() * 100.0]
		"coin_gain": return "Global Coin Gain +%.0f%%" % [MetaProgress.get_global_coin_gain_bonus() * 100.0]
		"offline": return "Offline Efficiency +%.0f%%" % [MetaProgress.get_offline_efficiency_bonus() * 100.0]
		"bench": return "Folding Benches"
		"dock_capacity": return "Dock Capacity"
		"needs_service": return "Needs Service Time -%.0f%%" % [MetaProgress.get_needs_service_bonus() * 100.0]
		"shop_rarity": return "Shop Rarity Odds"
		"quest_slot": return "Extra Quest Slot"
		_: return ""

func _upgrade_subtitle(id: String) -> String:
	match id:
		"bench": return "%d benches" % MetaProgress.get_bench_capacity()
		"dock_capacity": return "%d slots" % DockInventory.capacity()
		"quest_slot": return "%d active quests" % (QuestManager.ACTIVE_QUEST_COUNT + MetaProgress.get_quest_slot_bonus())
		_: return "Level %d" % _upgrade_level(id)

func _upgrade_buy(id: String) -> void:
	match id:
		"slot": MetaProgress.buy_slot()
		"luck": MetaProgress.buy_luck()
		"speed": MetaProgress.buy_speed()
		"power": MetaProgress.buy_power()
		"endurance": MetaProgress.buy_endurance()
		"discount": MetaProgress.buy_discount()
		"hire_discount": MetaProgress.buy_hire_discount()
		"coin_gain": MetaProgress.buy_coin_gain()
		"offline": MetaProgress.buy_offline_efficiency()
		"bench": MetaProgress.buy_bench_capacity()
		"dock_capacity": MetaProgress.buy_dock_capacity()
		"needs_service": MetaProgress.buy_needs_service()
		"shop_rarity": MetaProgress.buy_shop_rarity()
		"quest_slot": MetaProgress.buy_quest_slot()

func _refresh_perk_slot() -> void:
	if MetaProgress.has_extra_perk_slot():
		_perk_slot_row.setup("Extra Perk Slot", "New hires roll 2-3 perks", "MAX", PERK_SLOT_COLOR)
		_perk_slot_row.disabled = true
		return
	_perk_slot_row.setup(
		"Extra Perk Slot",
		"New hires roll 1-2 perks",
		"%d Scales" % MetaProgress.PERK_SLOT_COST,
		PERK_SLOT_COLOR
	)
	_perk_slot_row.disabled = Economy.scales < MetaProgress.PERK_SLOT_COST

## Stays hidden entirely until the player has caught a Secret-tier fish at
## least once — same discovery-gated spirit as the Album's Secret tab.
func _refresh_secret_chance() -> void:
	var unlocked := Album.has_caught_secret()
	_secret_chance_row.visible = unlocked
	if not unlocked:
		return
	if MetaProgress.secret_chance_level >= SECRET_CHANCE_MAX_LEVEL:
		_secret_chance_row.setup(
			"Secret Catch Chance",
			"Maxed out",
			"MAX",
			SECRET_CHANCE_COLOR
		)
		_secret_chance_row.disabled = true
		return
	var secret_chance_cost := _secret_chance_cost()
	_secret_chance_row.setup(
		"Secret Catch Chance",
		"Level %d" % MetaProgress.secret_chance_level,
		"%d Scales" % secret_chance_cost,
		SECRET_CHANCE_COLOR
	)
	_secret_chance_row.disabled = Economy.scales < secret_chance_cost

func _secret_chance_cost() -> int:
	return int(round(SECRET_CHANCE_BASE_COST * pow(SECRET_CHANCE_GROWTH, MetaProgress.secret_chance_level)))

func _on_buy_perk_slot() -> void:
	if MetaProgress.has_extra_perk_slot():
		return
	if Economy.spend_scales(MetaProgress.PERK_SLOT_COST):
		MetaProgress.buy_perk_slot()

func _refresh_expeditions() -> void:
	if MetaProgress.has_expeditions_unlocked():
		_expeditions_row.setup("Expeditions", "Send a fisherman off-island for a rare catch", "MAX", EXPEDITIONS_COLOR)
		_expeditions_row.disabled = true
		return
	_expeditions_row.setup(
		"Expeditions",
		"Unlocks a long off-island trip with a guaranteed rare+ catch",
		"%d Scales" % MetaProgress.EXPEDITIONS_COST,
		EXPEDITIONS_COLOR
	)
	_expeditions_row.disabled = Economy.scales < MetaProgress.EXPEDITIONS_COST

func _on_buy_expeditions() -> void:
	if MetaProgress.has_expeditions_unlocked():
		return
	if Economy.spend_scales(MetaProgress.EXPEDITIONS_COST):
		MetaProgress.buy_expeditions()

func _on_buy_secret_chance() -> void:
	if not Album.has_caught_secret():
		return
	if MetaProgress.secret_chance_level >= SECRET_CHANCE_MAX_LEVEL:
		return
	if Economy.spend_scales(_secret_chance_cost()):
		MetaProgress.buy_secret_chance()
