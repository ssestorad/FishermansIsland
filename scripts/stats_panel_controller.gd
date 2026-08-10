class_name StatsPanelController
extends Panel

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")
const TOP_N := 5
const ROW_COLOR := Color(0.24, 0.45, 0.55)

@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsRows

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

func toggle(fishermen: Array) -> void:
	visible = not visible
	if visible:
		build(fishermen)

func build(fishermen: Array) -> void:
	UiListUtils.clear_children(rows_container)
	_add_section("Most Catches", fishermen, func(f): return f.total_catches, "")
	_add_section("Highest Speed", fishermen, func(f): return f.get_level(f.speed_xp), " Lvl")
	_add_section("Highest Luck", fishermen, func(f): return f.get_level(f.luck_xp), " Lvl")
	_add_section("Highest Power", fishermen, func(f): return f.get_level(f.power_xp), " Lvl")

func _add_section(section_title: String, fishermen: Array, value_fn: Callable, suffix: String) -> void:
	var header := Label.new()
	header.theme_type_variation = &"MutedLabel"
	header.text = section_title
	rows_container.add_child(header)

	if fishermen.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"MutedLabel"
		empty.text = "No fishermen yet."
		rows_container.add_child(empty)
		return

	var sorted: Array = fishermen.duplicate()
	sorted.sort_custom(func(a, b): return value_fn.call(a) > value_fn.call(b))
	var count := mini(TOP_N, sorted.size())
	for i in range(count):
		var fisherman = sorted[i]
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows_container.add_child(row)
		var value = value_fn.call(fisherman)
		row.setup("#%d %s" % [i + 1, fisherman.display_name], "", "%s%s" % [value, suffix], ROW_COLOR)

func _on_close_button_pressed() -> void:
	visible = false
