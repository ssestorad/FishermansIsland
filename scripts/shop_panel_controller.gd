class_name ShopPanelController
extends Panel

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

const POTION_COST := 8
const POTION_AXES := ["speed", "luck", "power"]
const POTION_LABELS := {"speed": "Speed Potion", "luck": "Luck Potion", "power": "Power Potion"}
const POTION_COLORS := {
	"speed": Color(0.35, 0.55, 0.85),
	"luck": Color(0.45, 0.75, 0.4),
	"power": Color(0.85, 0.45, 0.3),
}

@onready var restock_label: Label = $MarginContainer/VBoxContainer/RestockLabel
@onready var gear_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/GearTabButton
@onready var potions_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/PotionsTabButton
@onready var gear_scroll: ScrollContainer = $MarginContainer/VBoxContainer/ShopScroll
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/ShopScroll/ShopRows
@onready var potions_container: VBoxContainer = $MarginContainer/VBoxContainer/PotionRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _items: Array = []
var _potion_rows: Dictionary = {}
var _showing_potions: bool = false

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	gear_tab_button.pressed.connect(_on_gear_tab_pressed)
	potions_tab_button.pressed.connect(_on_potions_tab_pressed)
	ShopRotation.rotated.connect(_on_shop_rotated)
	_build_potion_rows()

func _on_shop_rotated() -> void:
	if visible and not _showing_potions:
		build()

func toggle() -> void:
	visible = not visible
	if visible:
		_showing_potions = false
		_update_tabs()
		build()

func _on_gear_tab_pressed() -> void:
	_showing_potions = false
	_update_tabs()

func _on_potions_tab_pressed() -> void:
	_showing_potions = true
	_update_tabs()

func _update_tabs() -> void:
	gear_scroll.visible = not _showing_potions
	potions_container.visible = _showing_potions
	gear_tab_button.disabled = not _showing_potions
	potions_tab_button.disabled = _showing_potions

func build() -> void:
	UiListUtils.clear_children(rows_container)
	_items = ShopRotation.current_items
	for item in _items:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		rows_container.add_child(row)
		row.pressed.connect(_on_buy_item.bind(item))
	refresh()

func _build_potion_rows() -> void:
	for axis in POTION_AXES:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.pressed.connect(_on_drink_potion.bind(axis))
		potions_container.add_child(row)
		_potion_rows[axis] = row

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	restock_label.text = "Restocks in %ds" % ceili(ShopRotation.get_time_until_rotation())
	for i in range(rows_container.get_child_count()):
		var row: ListRow = rows_container.get_child(i)
		var item: Item = _items[i]
		var cost := _discounted_cost(item)
		row.setup(
			item.item_name,
			"%s · %s · %s" % [item.slot, item.rarity, item.effects_text()],
			"%d %s" % [cost, item.currency],
			RarityColors.for_name(item.rarity)
		)
		var balance: int = Economy.coins if item.currency == "Coins" else Economy.scales
		row.disabled = balance < cost

	for axis in POTION_AXES:
		var row: ListRow = _potion_rows[axis]
		var remaining := PotionManager.get_remaining(axis)
		if remaining > 0.0:
			row.setup(POTION_LABELS[axis], "Active", "%ds left" % ceili(remaining), POTION_COLORS[axis])
			row.disabled = false
		else:
			row.setup(POTION_LABELS[axis], "Temporary buff", "%d Coins" % POTION_COST, POTION_COLORS[axis])
			row.disabled = Economy.coins < POTION_COST

func _discounted_cost(item: Item) -> int:
	return int(round(item.cost * (1.0 - MetaProgress.get_shop_discount())))

func _on_buy_item(item: Item) -> void:
	var cost := _discounted_cost(item)
	var spent: bool = Economy.spend_coins(cost) if item.currency == "Coins" else Economy.spend_scales(cost)
	if spent:
		Inventory.add_item(item)

func _on_drink_potion(axis: String) -> void:
	if Economy.spend_coins(POTION_COST):
		PotionManager.activate(axis)

func _on_close_button_pressed() -> void:
	visible = false
