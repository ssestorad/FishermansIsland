class_name FishermenPanelController
extends Panel

signal fisherman_selected(fisherman)

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")
const ROW_SWATCH_COLOR := Color(0.24, 0.45, 0.55)

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/FishermenScroll/FishermenRows
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _row_by_fisherman: Dictionary = {}
var _connected_fishermen: Array = []

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	visibility_changed.connect(_on_visibility_changed)

## Any code path that hides this panel — toggle(), the close button, or main.gd
## switching to a different panel — ends up here, so connections never leak.
func _on_visibility_changed() -> void:
	if not visible:
		_disconnect_all()

func _on_close_button_pressed() -> void:
	visible = false

func toggle(fishermen: Array) -> void:
	visible = not visible
	if visible:
		build(fishermen)

func build(fishermen: Array) -> void:
	_disconnect_all()
	UiListUtils.clear_children(rows_container)
	_row_by_fisherman.clear()
	for fisherman in fishermen:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.pressed.connect(_on_row_pressed.bind(fisherman))
		rows_container.add_child(row)
		_row_by_fisherman[fisherman] = row
		fisherman.stats_changed.connect(refresh)
		_connected_fishermen.append(fisherman)
	refresh()

func _disconnect_all() -> void:
	for fisherman in _connected_fishermen:
		if is_instance_valid(fisherman) and fisherman.stats_changed.is_connected(refresh):
			fisherman.stats_changed.disconnect(refresh)
	_connected_fishermen.clear()

func _on_row_pressed(fisherman) -> void:
	fisherman_selected.emit(fisherman)

func refresh() -> void:
	for fisherman in _row_by_fisherman:
		if not is_instance_valid(fisherman):
			continue
		var row: ListRow = _row_by_fisherman[fisherman]
		row.setup(fisherman.display_name, fisherman.get_stats_text(), "", ROW_SWATCH_COLOR)
