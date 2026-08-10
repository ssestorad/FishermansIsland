class_name MetaPanelController
extends Panel

const SLOT_BASE_COST := 20
const SLOT_GROWTH := 1.3
const LUCK_BASE_COST := 10
const LUCK_GROWTH := 1.25
const DISCOUNT_BASE_COST := 15
const DISCOUNT_GROWTH := 1.3
const DISCOUNT_MAX_LEVEL := 15

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/MetaScroll/MetaRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _slot_button: Button
var _luck_button: Button
var _discount_button: Button

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_build()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func _process(_delta: float) -> void:
	if visible:
		refresh()

func _build() -> void:
	UiListUtils.clear_children(rows_container)

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.text = "Permanent Upgrades (Scales)"
	rows_container.add_child(header)

	_slot_button = _make_row(_on_buy_slot)
	_luck_button = _make_row(_on_buy_luck)
	_discount_button = _make_row(_on_buy_discount)

	refresh()

func _make_row(callback: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	rows_container.add_child(button)
	return button

func refresh() -> void:
	if _slot_button == null:
		return

	var slot_cost := _slot_cost()
	_slot_button.text = "Extra Fisherman Slot (Lvl %d) — %d Scales" % [MetaProgress.extra_slots, slot_cost]
	_slot_button.disabled = Economy.scales < slot_cost

	var luck_cost := _luck_cost()
	_luck_button.text = "Global Luck +%.0f%% (Lvl %d) — %d Scales" % [
		MetaProgress.get_global_luck_bonus() * 100.0, MetaProgress.luck_level, luck_cost
	]
	_luck_button.disabled = Economy.scales < luck_cost

	if MetaProgress.discount_level >= DISCOUNT_MAX_LEVEL:
		_discount_button.text = "Shop Discount %.0f%% (MAX)" % [MetaProgress.get_shop_discount() * 100.0]
		_discount_button.disabled = true
	else:
		var discount_cost := _discount_cost()
		_discount_button.text = "Shop Discount -%.0f%% (Lvl %d) — %d Scales" % [
			MetaProgress.get_shop_discount() * 100.0, MetaProgress.discount_level, discount_cost
		]
		_discount_button.disabled = Economy.scales < discount_cost

func _slot_cost() -> int:
	return int(round(SLOT_BASE_COST * pow(SLOT_GROWTH, MetaProgress.extra_slots)))

func _luck_cost() -> int:
	return int(round(LUCK_BASE_COST * pow(LUCK_GROWTH, MetaProgress.luck_level)))

func _discount_cost() -> int:
	return int(round(DISCOUNT_BASE_COST * pow(DISCOUNT_GROWTH, MetaProgress.discount_level)))

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

func _on_close_pressed() -> void:
	visible = false
