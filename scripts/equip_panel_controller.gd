class_name EquipPanelController
extends Panel

signal changed
signal back_requested(fisherman)

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

@onready var back_button: Button = $MarginContainer/VBoxContainer/HeaderRow/BackButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/EquipScroll/EquipRows
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/UnequipButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _fisherman: Node = null
var _slot: String = ""

func _ready() -> void:
	unequip_button.pressed.connect(_on_unequip_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

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
	var available_items := Inventory.items_for_slot(_slot)
	if available_items.is_empty():
		var empty_label := Label.new()
		empty_label.theme_type_variation = &"MutedLabel"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.text = "No other %s items in your inventory yet." % _slot
		rows_container.add_child(empty_label)
	for item in available_items:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		rows_container.add_child(row)
		var rarity_color := RarityColors.for_name(item.rarity)
		row.setup(item.item_name, item.effects_text(), item.rarity, rarity_color)
		row.set_right_color(rarity_color)
		row.pressed.connect(_on_equip_pressed.bind(item))

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

func _on_back_button_pressed() -> void:
	back_requested.emit(_fisherman)
