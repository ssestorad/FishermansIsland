class_name EquipPanelController
extends Panel

signal changed

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/EquipScroll/EquipRows
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/UnequipButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _fisherman: Node = null
var _slot: String = ""

func _ready() -> void:
	unequip_button.pressed.connect(_on_unequip_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func open_for(fisherman: Node, slot: String) -> void:
	_fisherman = fisherman
	_slot = slot
	visible = true
	build()

func build() -> void:
	if _fisherman == null or not is_instance_valid(_fisherman):
		visible = false
		return

	title_label.text = "%s — currently: %s" % [_slot, _fisherman.get_slot_display(_slot)]
	unequip_button.disabled = _fisherman.equipped_items.get(_slot) == null

	UiListUtils.clear_children(rows_container)
	for item in Inventory.items_for_slot(_slot):
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s [%s] — %s" % [item.item_name, item.rarity, item.effects_text()]
		row.pressed.connect(_on_equip_pressed.bind(item))
		rows_container.add_child(row)

func _on_equip_pressed(item: Item) -> void:
	var previous = _fisherman.equipped_items.get(_slot)
	if previous != null:
		Inventory.add_item(previous)
	Inventory.remove_item(item)
	_fisherman.equipped_items[_slot] = item
	changed.emit()
	build()

func _on_unequip_pressed() -> void:
	var current = _fisherman.equipped_items.get(_slot)
	if current != null:
		Inventory.add_item(current)
		_fisherman.equipped_items[_slot] = null
		changed.emit()
	build()

func _on_close_button_pressed() -> void:
	visible = false
