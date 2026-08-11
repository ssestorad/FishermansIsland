class_name MetaPanelController
extends Panel

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
const SPOT_COLOR := Color(0.28, 0.55, 0.62)
const SECRET_CHANCE_COLOR := Color(0.35, 0.22, 0.5)
const QUEST_SLOT_COLOR := Color(0.65, 0.5, 0.25)

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/MetaScroll/MetaRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _slot_row: ListRow
var _luck_row: ListRow
var _speed_row: ListRow
var _power_row: ListRow
var _endurance_row: ListRow
var _discount_row: ListRow
var _hire_discount_row: ListRow
var _coin_gain_row: ListRow
var _offline_row: ListRow
var _bench_row: ListRow
var _dock_capacity_row: ListRow
var _needs_service_row: ListRow
var _shop_rarity_row: ListRow
var _perk_slot_row: ListRow
var _secret_chance_row: ListRow
var _quest_slot_row: ListRow
## id -> row, for the buyable fishing spots (the pond is free).
var _spot_rows: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
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

	_slot_row = _make_row(_on_buy_slot)
	_luck_row = _make_row(_on_buy_luck)
	_speed_row = _make_row(_on_buy_speed)
	_power_row = _make_row(_on_buy_power)
	_endurance_row = _make_row(_on_buy_endurance)
	_discount_row = _make_row(_on_buy_discount)
	_hire_discount_row = _make_row(_on_buy_hire_discount)
	_coin_gain_row = _make_row(_on_buy_coin_gain)
	_offline_row = _make_row(_on_buy_offline_efficiency)
	_bench_row = _make_row(_on_buy_bench_capacity)
	_dock_capacity_row = _make_row(_on_buy_dock_capacity)
	_needs_service_row = _make_row(_on_buy_needs_service)
	_shop_rarity_row = _make_row(_on_buy_shop_rarity)
	_perk_slot_row = _make_row(_on_buy_perk_slot)
	_secret_chance_row = _make_row(_on_buy_secret_chance)
	_quest_slot_row = _make_row(_on_buy_quest_slot)

	refresh()

func _make_row(callback: Callable) -> ListRow:
	var row: ListRow = LIST_ROW_SCENE.instantiate()
	row.pressed.connect(callback)
	rows_container.add_child(row)
	return row

func refresh() -> void:
	if _slot_row == null:
		return

	_refresh_spots()
	_refresh_slot()
	_refresh_luck()
	_refresh_speed()
	_refresh_power()
	_refresh_endurance()
	_refresh_discount()
	_refresh_hire_discount()
	_refresh_coin_gain()
	_refresh_offline()
	_refresh_bench()
	_refresh_dock_capacity()
	_refresh_needs_service()
	_refresh_shop_rarity()
	_refresh_perk_slot()
	_refresh_secret_chance()
	_refresh_quest_slot()

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

func _refresh_slot() -> void:
	if MetaProgress.extra_slots >= SLOT_MAX_LEVEL:
		_slot_row.setup("Extra Fisherman Slot", "Maxed out (30 total)", "MAX", SLOT_COLOR)
		_slot_row.disabled = true
		return
	var slot_cost := _slot_cost()
	_slot_row.setup(
		"Extra Fisherman Slot",
		"Level %d" % MetaProgress.extra_slots,
		"%d Scales" % slot_cost,
		SLOT_COLOR
	)
	_slot_row.disabled = Economy.scales < slot_cost

func _refresh_luck() -> void:
	var luck_cost := _luck_cost()
	_luck_row.setup(
		"Global Luck +%.0f%%" % [MetaProgress.get_global_luck_bonus() * 100.0],
		"Level %d" % MetaProgress.luck_level,
		"%d Scales" % luck_cost,
		LUCK_COLOR
	)
	_luck_row.disabled = Economy.scales < luck_cost

func _refresh_speed() -> void:
	var speed_cost := _speed_cost()
	_speed_row.setup(
		"Global Speed +%.0f%%" % [MetaProgress.get_global_speed_bonus() * 100.0],
		"Level %d" % MetaProgress.speed_level,
		"%d Scales" % speed_cost,
		SPEED_COLOR
	)
	_speed_row.disabled = Economy.scales < speed_cost

func _refresh_power() -> void:
	var power_cost := _power_cost()
	_power_row.setup(
		"Global Power +%.0f%%" % [MetaProgress.get_global_power_bonus() * 100.0],
		"Level %d" % MetaProgress.power_level,
		"%d Scales" % power_cost,
		POWER_COLOR
	)
	_power_row.disabled = Economy.scales < power_cost

func _refresh_endurance() -> void:
	var endurance_cost := _endurance_cost()
	_endurance_row.setup(
		"Global Endurance +%.0f%%" % [MetaProgress.get_global_endurance_bonus() * 100.0],
		"Level %d" % MetaProgress.endurance_level,
		"%d Scales" % endurance_cost,
		ENDURANCE_COLOR
	)
	_endurance_row.disabled = Economy.scales < endurance_cost

func _refresh_discount() -> void:
	if MetaProgress.discount_level >= DISCOUNT_MAX_LEVEL:
		_discount_row.setup(
			"Shop Discount %.0f%%" % [MetaProgress.get_shop_discount() * 100.0],
			"Maxed out",
			"MAX",
			DISCOUNT_COLOR
		)
		_discount_row.disabled = true
		return
	var discount_cost := _discount_cost()
	_discount_row.setup(
		"Shop Discount -%.0f%%" % [MetaProgress.get_shop_discount() * 100.0],
		"Level %d" % MetaProgress.discount_level,
		"%d Scales" % discount_cost,
		DISCOUNT_COLOR
	)
	_discount_row.disabled = Economy.scales < discount_cost

func _refresh_hire_discount() -> void:
	if MetaProgress.hire_discount_level >= HIRE_DISCOUNT_MAX_LEVEL:
		_hire_discount_row.setup(
			"Hire Cost -%.0f%%" % [MetaProgress.get_hire_discount() * 100.0],
			"Maxed out",
			"MAX",
			HIRE_DISCOUNT_COLOR
		)
		_hire_discount_row.disabled = true
		return
	var hire_discount_cost := _hire_discount_cost()
	_hire_discount_row.setup(
		"Hire Cost -%.0f%%" % [MetaProgress.get_hire_discount() * 100.0],
		"Level %d" % MetaProgress.hire_discount_level,
		"%d Scales" % hire_discount_cost,
		HIRE_DISCOUNT_COLOR
	)
	_hire_discount_row.disabled = Economy.scales < hire_discount_cost

func _refresh_coin_gain() -> void:
	var coin_gain_cost := _coin_gain_cost()
	_coin_gain_row.setup(
		"Global Coin Gain +%.0f%%" % [MetaProgress.get_global_coin_gain_bonus() * 100.0],
		"Level %d" % MetaProgress.coin_gain_level,
		"%d Scales" % coin_gain_cost,
		COIN_GAIN_COLOR
	)
	_coin_gain_row.disabled = Economy.scales < coin_gain_cost

func _refresh_offline() -> void:
	if MetaProgress.offline_efficiency_level >= OFFLINE_MAX_LEVEL:
		_offline_row.setup(
			"Offline Efficiency +%.0f%%" % [MetaProgress.get_offline_efficiency_bonus() * 100.0],
			"Maxed out",
			"MAX",
			OFFLINE_COLOR
		)
		_offline_row.disabled = true
		return
	var offline_cost := _offline_cost()
	_offline_row.setup(
		"Offline Efficiency +%.0f%%" % [MetaProgress.get_offline_efficiency_bonus() * 100.0],
		"Level %d" % MetaProgress.offline_efficiency_level,
		"%d Scales" % offline_cost,
		OFFLINE_COLOR
	)
	_offline_row.disabled = Economy.scales < offline_cost

func _refresh_bench() -> void:
	var bench_cost := _bench_cost()
	_bench_row.setup(
		"Folding Benches",
		"%d benches" % MetaProgress.get_bench_capacity(),
		"%d Scales" % bench_cost,
		BENCH_COLOR
	)
	_bench_row.disabled = Economy.scales < bench_cost

func _refresh_dock_capacity() -> void:
	var dock_capacity_cost := _dock_capacity_cost()
	_dock_capacity_row.setup(
		"Dock Capacity",
		"%d slots" % DockInventory.capacity(),
		"%d Scales" % dock_capacity_cost,
		DOCK_CAPACITY_COLOR
	)
	_dock_capacity_row.disabled = Economy.scales < dock_capacity_cost

func _refresh_needs_service() -> void:
	if MetaProgress.needs_service_level >= NEEDS_SERVICE_MAX_LEVEL:
		_needs_service_row.setup(
			"Needs Service Time -%.0f%%" % [MetaProgress.get_needs_service_bonus() * 100.0],
			"Maxed out",
			"MAX",
			NEEDS_SERVICE_COLOR
		)
		_needs_service_row.disabled = true
		return
	var needs_service_cost := _needs_service_cost()
	_needs_service_row.setup(
		"Needs Service Time -%.0f%%" % [MetaProgress.get_needs_service_bonus() * 100.0],
		"Level %d" % MetaProgress.needs_service_level,
		"%d Scales" % needs_service_cost,
		NEEDS_SERVICE_COLOR
	)
	_needs_service_row.disabled = Economy.scales < needs_service_cost

func _refresh_shop_rarity() -> void:
	if MetaProgress.shop_rarity_level >= SHOP_RARITY_MAX_LEVEL:
		_shop_rarity_row.setup(
			"Shop Rarity Odds",
			"Maxed out",
			"MAX",
			SHOP_RARITY_COLOR
		)
		_shop_rarity_row.disabled = true
		return
	var shop_rarity_cost := _shop_rarity_cost()
	_shop_rarity_row.setup(
		"Shop Rarity Odds",
		"Level %d" % MetaProgress.shop_rarity_level,
		"%d Scales" % shop_rarity_cost,
		SHOP_RARITY_COLOR
	)
	_shop_rarity_row.disabled = Economy.scales < shop_rarity_cost

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

func _refresh_quest_slot() -> void:
	if MetaProgress.quest_slot_level >= QUEST_SLOT_MAX_LEVEL:
		_quest_slot_row.setup(
			"Extra Quest Slot",
			"Maxed out",
			"MAX",
			QUEST_SLOT_COLOR
		)
		_quest_slot_row.disabled = true
		return
	var quest_slot_cost := _quest_slot_cost()
	_quest_slot_row.setup(
		"Extra Quest Slot",
		"%d active quests" % (QuestManager.ACTIVE_QUEST_COUNT + MetaProgress.get_quest_slot_bonus()),
		"%d Scales" % quest_slot_cost,
		QUEST_SLOT_COLOR
	)
	_quest_slot_row.disabled = Economy.scales < quest_slot_cost

func _slot_cost() -> int:
	return int(round(SLOT_BASE_COST * pow(SLOT_GROWTH, MetaProgress.extra_slots)))

func _luck_cost() -> int:
	return int(round(LUCK_BASE_COST * pow(LUCK_GROWTH, MetaProgress.luck_level)))

func _speed_cost() -> int:
	return int(round(SPEED_BASE_COST * pow(SPEED_GROWTH, MetaProgress.speed_level)))

func _power_cost() -> int:
	return int(round(POWER_BASE_COST * pow(POWER_GROWTH, MetaProgress.power_level)))

func _endurance_cost() -> int:
	return int(round(ENDURANCE_BASE_COST * pow(ENDURANCE_GROWTH, MetaProgress.endurance_level)))

func _discount_cost() -> int:
	return int(round(DISCOUNT_BASE_COST * pow(DISCOUNT_GROWTH, MetaProgress.discount_level)))

func _hire_discount_cost() -> int:
	return int(round(HIRE_DISCOUNT_BASE_COST * pow(HIRE_DISCOUNT_GROWTH, MetaProgress.hire_discount_level)))

func _coin_gain_cost() -> int:
	return int(round(COIN_GAIN_BASE_COST * pow(COIN_GAIN_GROWTH, MetaProgress.coin_gain_level)))

func _offline_cost() -> int:
	return int(round(OFFLINE_BASE_COST * pow(OFFLINE_GROWTH, MetaProgress.offline_efficiency_level)))

func _bench_cost() -> int:
	return int(round(BENCH_BASE_COST * pow(BENCH_GROWTH, MetaProgress.bench_capacity_level)))

func _dock_capacity_cost() -> int:
	return int(round(DOCK_CAPACITY_BASE_COST * pow(DOCK_CAPACITY_GROWTH, MetaProgress.dock_capacity_level)))

func _needs_service_cost() -> int:
	return int(round(NEEDS_SERVICE_BASE_COST * pow(NEEDS_SERVICE_GROWTH, MetaProgress.needs_service_level)))

func _shop_rarity_cost() -> int:
	return int(round(SHOP_RARITY_BASE_COST * pow(SHOP_RARITY_GROWTH, MetaProgress.shop_rarity_level)))

func _secret_chance_cost() -> int:
	return int(round(SECRET_CHANCE_BASE_COST * pow(SECRET_CHANCE_GROWTH, MetaProgress.secret_chance_level)))

func _quest_slot_cost() -> int:
	return int(round(QUEST_SLOT_BASE_COST * pow(QUEST_SLOT_GROWTH, MetaProgress.quest_slot_level)))

func _on_buy_slot() -> void:
	if MetaProgress.extra_slots >= SLOT_MAX_LEVEL:
		return
	if Economy.spend_scales(_slot_cost()):
		MetaProgress.buy_slot()

func _on_buy_luck() -> void:
	if Economy.spend_scales(_luck_cost()):
		MetaProgress.buy_luck()

func _on_buy_speed() -> void:
	if Economy.spend_scales(_speed_cost()):
		MetaProgress.buy_speed()

func _on_buy_power() -> void:
	if Economy.spend_scales(_power_cost()):
		MetaProgress.buy_power()

func _on_buy_endurance() -> void:
	if Economy.spend_scales(_endurance_cost()):
		MetaProgress.buy_endurance()

func _on_buy_discount() -> void:
	if MetaProgress.discount_level >= DISCOUNT_MAX_LEVEL:
		return
	if Economy.spend_scales(_discount_cost()):
		MetaProgress.buy_discount()

func _on_buy_hire_discount() -> void:
	if MetaProgress.hire_discount_level >= HIRE_DISCOUNT_MAX_LEVEL:
		return
	if Economy.spend_scales(_hire_discount_cost()):
		MetaProgress.buy_hire_discount()

func _on_buy_coin_gain() -> void:
	if Economy.spend_scales(_coin_gain_cost()):
		MetaProgress.buy_coin_gain()

func _on_buy_offline_efficiency() -> void:
	if MetaProgress.offline_efficiency_level >= OFFLINE_MAX_LEVEL:
		return
	if Economy.spend_scales(_offline_cost()):
		MetaProgress.buy_offline_efficiency()

func _on_buy_bench_capacity() -> void:
	if Economy.spend_scales(_bench_cost()):
		MetaProgress.buy_bench_capacity()

func _on_buy_dock_capacity() -> void:
	if Economy.spend_scales(_dock_capacity_cost()):
		MetaProgress.buy_dock_capacity()

func _on_buy_needs_service() -> void:
	if MetaProgress.needs_service_level >= NEEDS_SERVICE_MAX_LEVEL:
		return
	if Economy.spend_scales(_needs_service_cost()):
		MetaProgress.buy_needs_service()

func _on_buy_shop_rarity() -> void:
	if MetaProgress.shop_rarity_level >= SHOP_RARITY_MAX_LEVEL:
		return
	if Economy.spend_scales(_shop_rarity_cost()):
		MetaProgress.buy_shop_rarity()

func _on_buy_perk_slot() -> void:
	if MetaProgress.has_extra_perk_slot():
		return
	if Economy.spend_scales(MetaProgress.PERK_SLOT_COST):
		MetaProgress.buy_perk_slot()

func _on_buy_secret_chance() -> void:
	if not Album.has_caught_secret():
		return
	if MetaProgress.secret_chance_level >= SECRET_CHANCE_MAX_LEVEL:
		return
	if Economy.spend_scales(_secret_chance_cost()):
		MetaProgress.buy_secret_chance()

func _on_buy_quest_slot() -> void:
	if MetaProgress.quest_slot_level >= QUEST_SLOT_MAX_LEVEL:
		return
	if Economy.spend_scales(_quest_slot_cost()):
		MetaProgress.buy_quest_slot()

func _on_close_pressed() -> void:
	visible = false
