class_name ShopPanelController
extends Panel

const POTION_COST := 8
const POTION_AXES := ["speed", "luck", "power"]
const POTION_LABELS := {"speed": "Speed Potion", "luck": "Luck Potion", "power": "Power Potion"}

@onready var gear_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/GearTabButton
@onready var potions_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/PotionsTabButton
@onready var gear_scroll: ScrollContainer = $MarginContainer/VBoxContainer/ShopScroll
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/ShopScroll/ShopRows
@onready var potions_container: VBoxContainer = $MarginContainer/VBoxContainer/PotionRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _items: Array = []
var _potion_buttons: Dictionary = {}
var _showing_potions: bool = false

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	gear_tab_button.pressed.connect(_on_gear_tab_pressed)
	potions_tab_button.pressed.connect(_on_potions_tab_pressed)
	_build_potion_rows()

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
	_items = ShopCatalog.available_items()
	for item in _items:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rows_container.add_child(row)
		row.pressed.connect(_on_buy_item.bind(item))
	refresh()

func _build_potion_rows() -> void:
	for axis in POTION_AXES:
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_drink_potion.bind(axis))
		potions_container.add_child(button)
		_potion_buttons[axis] = button

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	for i in range(rows_container.get_child_count()):
		var button: Button = rows_container.get_child(i)
		var item: Item = _items[i]
		var cost := _discounted_cost(item)
		button.text = "%s (%s) [%s] — %s — %d %s" % [
			item.item_name, item.slot, item.rarity, item.effects_text(), cost, item.currency
		]
		var balance: int = Economy.coins if item.currency == "Coins" else Economy.scales
		button.disabled = balance < cost

	for axis in POTION_AXES:
		var button: Button = _potion_buttons[axis]
		var remaining := PotionManager.get_remaining(axis)
		if remaining > 0.0:
			button.text = "%s — active (%ds left)" % [POTION_LABELS[axis], ceili(remaining)]
			button.disabled = false
		else:
			button.text = "%s — %d Coins" % [POTION_LABELS[axis], POTION_COST]
			button.disabled = Economy.coins < POTION_COST

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
