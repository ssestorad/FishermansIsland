class_name MetaPanelController
extends Panel

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

const SLOT_BASE_COST := 20
const SLOT_GROWTH := 1.3
const LUCK_BASE_COST := 10
const LUCK_GROWTH := 1.25
const DISCOUNT_BASE_COST := 15
const DISCOUNT_GROWTH := 1.3
const DISCOUNT_MAX_LEVEL := 15
const COIN_GAIN_BASE_COST := 12
const COIN_GAIN_GROWTH := 1.25
const OFFLINE_BASE_COST := 18
const OFFLINE_GROWTH := 1.3
const OFFLINE_MAX_LEVEL := 15
const BENCH_BASE_COST := 14
const BENCH_GROWTH := 1.3

const SLOT_COLOR := Color(0.3, 0.5, 0.65)
const LUCK_COLOR := Color(0.45, 0.75, 0.4)
const DISCOUNT_COLOR := Color(0.85, 0.6, 0.25)
const COIN_GAIN_COLOR := Color(0.95, 0.78, 0.25)
const OFFLINE_COLOR := Color(0.55, 0.45, 0.85)
const BENCH_COLOR := Color(0.5, 0.62, 0.35)

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/MetaScroll/MetaRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _slot_row: ListRow
var _luck_row: ListRow
var _discount_row: ListRow
var _coin_gain_row: ListRow
var _offline_row: ListRow
var _bench_row: ListRow

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	Economy.scales_changed.connect(_on_state_changed)
	MetaProgress.updated.connect(_on_state_changed)
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

	_slot_row = _make_row(_on_buy_slot)
	_luck_row = _make_row(_on_buy_luck)
	_discount_row = _make_row(_on_buy_discount)
	_coin_gain_row = _make_row(_on_buy_coin_gain)
	_offline_row = _make_row(_on_buy_offline_efficiency)
	_bench_row = _make_row(_on_buy_bench_capacity)

	refresh()

func _make_row(callback: Callable) -> ListRow:
	var row: ListRow = LIST_ROW_SCENE.instantiate()
	row.pressed.connect(callback)
	rows_container.add_child(row)
	return row

func refresh() -> void:
	if _slot_row == null:
		return

	var slot_cost := _slot_cost()
	_slot_row.setup(
		"Extra Fisherman Slot",
		"Level %d" % MetaProgress.extra_slots,
		"%d Scales" % slot_cost,
		SLOT_COLOR
	)
	_slot_row.disabled = Economy.scales < slot_cost

	var luck_cost := _luck_cost()
	_luck_row.setup(
		"Global Luck +%.0f%%" % [MetaProgress.get_global_luck_bonus() * 100.0],
		"Level %d" % MetaProgress.luck_level,
		"%d Scales" % luck_cost,
		LUCK_COLOR
	)
	_luck_row.disabled = Economy.scales < luck_cost

	if MetaProgress.discount_level >= DISCOUNT_MAX_LEVEL:
		_discount_row.setup(
			"Shop Discount %.0f%%" % [MetaProgress.get_shop_discount() * 100.0],
			"Maxed out",
			"MAX",
			DISCOUNT_COLOR
		)
		_discount_row.disabled = true
	else:
		var discount_cost := _discount_cost()
		_discount_row.setup(
			"Shop Discount -%.0f%%" % [MetaProgress.get_shop_discount() * 100.0],
			"Level %d" % MetaProgress.discount_level,
			"%d Scales" % discount_cost,
			DISCOUNT_COLOR
		)
		_discount_row.disabled = Economy.scales < discount_cost

	var coin_gain_cost := _coin_gain_cost()
	_coin_gain_row.setup(
		"Global Coin Gain +%.0f%%" % [MetaProgress.get_global_coin_gain_bonus() * 100.0],
		"Level %d" % MetaProgress.coin_gain_level,
		"%d Scales" % coin_gain_cost,
		COIN_GAIN_COLOR
	)
	_coin_gain_row.disabled = Economy.scales < coin_gain_cost

	if MetaProgress.offline_efficiency_level >= OFFLINE_MAX_LEVEL:
		_offline_row.setup(
			"Offline Efficiency +%.0f%%" % [MetaProgress.get_offline_efficiency_bonus() * 100.0],
			"Maxed out",
			"MAX",
			OFFLINE_COLOR
		)
		_offline_row.disabled = true
	else:
		var offline_cost := _offline_cost()
		_offline_row.setup(
			"Offline Efficiency +%.0f%%" % [MetaProgress.get_offline_efficiency_bonus() * 100.0],
			"Level %d" % MetaProgress.offline_efficiency_level,
			"%d Scales" % offline_cost,
			OFFLINE_COLOR
		)
		_offline_row.disabled = Economy.scales < offline_cost

	var bench_cost := _bench_cost()
	_bench_row.setup(
		"Folding Benches",
		"%d benches" % MetaProgress.get_bench_capacity(),
		"%d Scales" % bench_cost,
		BENCH_COLOR
	)
	_bench_row.disabled = Economy.scales < bench_cost

func _slot_cost() -> int:
	return int(round(SLOT_BASE_COST * pow(SLOT_GROWTH, MetaProgress.extra_slots)))

func _luck_cost() -> int:
	return int(round(LUCK_BASE_COST * pow(LUCK_GROWTH, MetaProgress.luck_level)))

func _discount_cost() -> int:
	return int(round(DISCOUNT_BASE_COST * pow(DISCOUNT_GROWTH, MetaProgress.discount_level)))

func _coin_gain_cost() -> int:
	return int(round(COIN_GAIN_BASE_COST * pow(COIN_GAIN_GROWTH, MetaProgress.coin_gain_level)))

func _offline_cost() -> int:
	return int(round(OFFLINE_BASE_COST * pow(OFFLINE_GROWTH, MetaProgress.offline_efficiency_level)))

func _bench_cost() -> int:
	return int(round(BENCH_BASE_COST * pow(BENCH_GROWTH, MetaProgress.bench_capacity_level)))

func _on_buy_slot() -> void:
	if Economy.spend_scales(_slot_cost()):
		MetaProgress.buy_slot()

func _on_buy_luck() -> void:
	if Economy.spend_scales(_luck_cost()):
		MetaProgress.buy_luck()

func _on_buy_discount() -> void:
	if MetaProgress.discount_level >= DISCOUNT_MAX_LEVEL:
		return
	if Economy.spend_scales(_discount_cost()):
		MetaProgress.buy_discount()

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

func _on_close_pressed() -> void:
	visible = false
