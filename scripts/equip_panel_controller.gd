class_name EquipPanelController
extends Panel

## The comparison label answers "is this better?"; the detail panel
## answers "what is this?". main.gd owns the latter.
signal item_detail_requested(item, spot)
signal item_detail_dismissed

signal changed
signal back_requested(fisherman)

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

@onready var back_button: Button = $MarginContainer/VBoxContainer/HeaderRow/BackButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/EquipScroll/EquipRows
@onready var comparison_label: RichTextLabel = $MarginContainer/VBoxContainer/ComparisonLabel
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/UnequipButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

const DEFAULT_COMPARISON_TEXT := "Hover an item to compare against what's equipped."
const BETTER_COLOR := "#4caf50"
const WORSE_COLOR := "#e05252"

var _fisherman: Node = null
var _slot: String = ""

func _ready() -> void:
	unequip_button.pressed.connect(_on_unequip_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	visibility_changed.connect(_on_visibility_changed)

## Closing the equip panel any way at all must take the read-out with it.
func _on_visibility_changed() -> void:
	if not visible:
		item_detail_dismissed.emit()

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

	comparison_label.text = DEFAULT_COMPARISON_TEXT
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
		row.setup(item.item_name, item.summary_text(), item.rarity, rarity_color)
		row.set_right_color(rarity_color)
		row.pressed.connect(_on_equip_pressed.bind(item))
		row.mouse_entered.connect(_on_row_hovered.bind(item))
		row.mouse_exited.connect(_on_row_unhovered)

## Diffs a hovered candidate item against whatever's currently equipped in
## this slot, one line per axis either of them touches.
func _on_row_hovered(candidate: Item) -> void:
	item_detail_requested.emit(candidate, _fisherman.fishing_spot if _fisherman != null else "")
	var current: Item = _fisherman.equipped_items.get(_slot)
	var axes: Dictionary = {}
	for effect in candidate.effects:
		axes[effect[0]] = true
	if current != null:
		for effect in current.effects:
			axes[effect[0]] = true
	if axes.is_empty():
		comparison_label.text = "No comparable stats."
		return
	var lines: Array = []
	for axis in axes:
		var cur_val: float = current.get_bonus(axis) if current != null else 0.0
		var new_val: float = candidate.get_bonus(axis)
		var delta := new_val - cur_val
		var sign := "+" if delta >= 0.0 else ""
		var arrow := ""
		if delta > 0.0001:
			arrow = " [color=%s]▲[/color]" % BETTER_COLOR
		elif delta < -0.0001:
			arrow = " [color=%s]▼[/color]" % WORSE_COLOR
		lines.append("%s: %d%% → %d%% (%s%d%%)%s" % [
			Item.AXIS_LABELS.get(axis, axis), roundi(cur_val * 100.0), roundi(new_val * 100.0), sign, roundi(delta * 100.0), arrow
		])
	comparison_label.text = "\n".join(lines)

func _on_row_unhovered() -> void:
	comparison_label.text = DEFAULT_COMPARISON_TEXT
	item_detail_dismissed.emit()

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
