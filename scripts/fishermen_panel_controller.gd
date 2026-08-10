class_name FishermenPanelController
extends Panel

signal fisherman_selected(fisherman)

@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/FishermenRows

var _row_by_fisherman: Dictionary = {}

func toggle(fishermen: Array) -> void:
	visible = not visible
	if visible:
		build(fishermen)

func build(fishermen: Array) -> void:
	UiListUtils.clear_children(rows_container)
	_row_by_fisherman.clear()
	for fisherman in fishermen:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		var row: Button = _row_by_fisherman[fisherman]
		row.text = "%s — %s" % [fisherman.display_name, fisherman.get_stats_text()]
