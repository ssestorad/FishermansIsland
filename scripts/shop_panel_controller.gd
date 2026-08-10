class_name ShopPanelController
extends Panel

signal back_pressed

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/ShopRows
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

var _current_fisherman: Node = null
var _items: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)

func open_for(fisherman: Node) -> void:
	_current_fisherman = fisherman
	visible = true
	build()

func build() -> void:
	UiListUtils.clear_children(rows_container)
	_items = ShopCatalog.default_items()
	for item in _items:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s (%s, +%d%% %s) — %d coins" % [item.item_name, item.slot, roundi(item.bonus * 100), item.axis.capitalize(), item.cost]
		row.pressed.connect(_on_buy_item.bind(item))
		rows_container.add_child(row)
	refresh()

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	for i in range(rows_container.get_child_count()):
		var button: Button = rows_container.get_child(i)
		var item: Item = _items[i]
		button.disabled = Economy.coins < item.cost

func _on_buy_item(item: Item) -> void:
	if _current_fisherman == null or not is_instance_valid(_current_fisherman):
		return
	if Economy.spend_coins(item.cost):
		_current_fisherman.equip_item(item)

func _on_back_button_pressed() -> void:
	visible = false
	back_pressed.emit()
