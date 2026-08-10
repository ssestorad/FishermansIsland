class_name FishermenPanelController
extends Panel

signal fisherman_selected(fisherman)

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")
const ROW_SWATCH_COLOR := Color(0.24, 0.45, 0.55)

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/FishermenScroll/FishermenRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _row_by_fisherman: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed() -> void:
	visible = false

func toggle(fishermen: Array) -> void:
	visible = not visible
	if visible:
		build(fishermen)

func build(fishermen: Array) -> void:
	UiListUtils.clear_children(rows_container)
	_row_by_fisherman.clear()
	for fisherman in fishermen:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.pressed.connect(_on_row_pressed.bind(fisherman))
		rows_container.add_child(row)
		_row_by_fisherman[fisherman] = row
	refresh()

func _on_row_pressed(fisherman) -> void:
	fisherman_selected.emit(fisherman)

func _process(_delta: float) -> void:
	if visible:
		refresh()

func refresh() -> void:
	for fisherman in _row_by_fisherman:
		if not is_instance_valid(fisherman):
			continue
		var row: ListRow = _row_by_fisherman[fisherman]
		row.setup(fisherman.display_name, fisherman.get_stats_text(), "", ROW_SWATCH_COLOR)
