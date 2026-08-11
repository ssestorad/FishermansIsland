class_name DockPanelController
extends PanelController

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/DockScroll/DockRows
@onready var sell_all_button: Button = $MarginContainer/VBoxContainer/SellAllButton

func _on_ready() -> void:
	sell_all_button.pressed.connect(_on_sell_all_pressed)
	DockInventory.updated.connect(_on_dock_updated)

func _on_dock_updated() -> void:
	if visible:
		build()

func build() -> void:
	UiListUtils.clear_children(rows_container)
	title_label.text = "Dock (%d/%d)" % [DockInventory.entries.size(), DockInventory.capacity()]
	sell_all_button.disabled = DockInventory.entries.is_empty()
	for i in range(DockInventory.entries.size()):
		var entry: Dictionary = DockInventory.entries[i]
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		rows_container.add_child(row)
		var color := RarityColors.for_tier(entry.tier)
		var value := Economy.preview_value(entry.tier, entry.weight, 0.0, entry.species_name)
		row.setup(
			entry.species_name,
			"%s · %.1f kg" % [FishRarity.name_for(entry.tier), entry.weight],
			"%d Scales" % value,
			color
		)
		row.set_right_color(color)
		row.pressed.connect(_on_sell_pressed.bind(i))

## Selling a row shifts every later row's index down, so always resolve
## against the freshest DockInventory.entries rather than trusting a stale
## captured list — build() gets called again via the `updated` signal.
func _on_sell_pressed(index: int) -> void:
	DockInventory.sell(index)

func _on_sell_all_pressed() -> void:
	DockInventory.sell_all()
