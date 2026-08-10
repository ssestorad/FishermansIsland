class_name FishermanProfilePanelController
extends Panel

signal shop_requested(fisherman)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var luck_label: Label = $MarginContainer/VBoxContainer/LuckLabel
@onready var power_label: Label = $MarginContainer/VBoxContainer/PowerLabel
@onready var equipment_slots: HBoxContainer = $MarginContainer/VBoxContainer/EquipmentSlots
@onready var shop_button: Button = $MarginContainer/VBoxContainer/ShopButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _fisherman: Node = null

func _ready() -> void:
	shop_button.pressed.connect(_on_shop_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func show_fisherman(fisherman: Node) -> void:
	_fisherman = fisherman
	visible = true
	refresh()

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	if _fisherman == null or not is_instance_valid(_fisherman):
		visible = false
		return
	name_label.text = _fisherman.display_name
	speed_label.text = "Speed: Lvl %d" % _fisherman.get_level(_fisherman.speed_xp)
	luck_label.text = "Luck: Lvl %d" % _fisherman.get_level(_fisherman.luck_xp)
	power_label.text = "Power: Lvl %d" % _fisherman.get_level(_fisherman.power_xp)
	for slot_label in equipment_slots.get_children():
		var slot_name: String = slot_label.name.trim_suffix("Slot")
		slot_label.text = "%s\n%s" % [slot_name, _fisherman.get_slot_display(slot_name)]

func _on_shop_button_pressed() -> void:
	if _fisherman != null:
		shop_requested.emit(_fisherman)

func _on_close_button_pressed() -> void:
	visible = false
	_fisherman = null
