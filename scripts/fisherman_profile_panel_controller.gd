class_name FishermanProfilePanelController
extends Panel

signal dismiss_requested(fisherman)
signal slot_clicked(fisherman, slot_name)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var luck_label: Label = $MarginContainer/VBoxContainer/LuckLabel
@onready var power_label: Label = $MarginContainer/VBoxContainer/PowerLabel
@onready var equipment_slots: HBoxContainer = $MarginContainer/VBoxContainer/EquipmentSlots
@onready var dismiss_button: Button = $MarginContainer/VBoxContainer/DismissButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var _fisherman: Node = null
var _dismiss_armed: bool = false

func _ready() -> void:
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_name))
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func show_fisherman(fisherman: Node) -> void:
	_fisherman = fisherman
	_dismiss_armed = false
	dismiss_button.text = "Dismiss"
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
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.text = "%s\n%s" % [slot_name, _fisherman.get_slot_display(slot_name)]

func _on_slot_pressed(slot_name: String) -> void:
	if _fisherman != null:
		slot_clicked.emit(_fisherman, slot_name)

func _on_dismiss_button_pressed() -> void:
	if _fisherman == null:
		return
	if not _dismiss_armed:
		_dismiss_armed = true
		dismiss_button.text = "Confirm dismiss?"
		return
	dismiss_requested.emit(_fisherman)
	visible = false
	_fisherman = null

func _on_close_button_pressed() -> void:
	visible = false
	_fisherman = null
