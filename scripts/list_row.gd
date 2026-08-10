class_name ListRow
extends Button

@onready var swatch: ColorRect = $Content/Swatch
@onready var icon_slot: Control = $Content/IconSlot
@onready var title_label: Label = $Content/TextStack/TitleLabel
@onready var subtitle_label: Label = $Content/TextStack/SubtitleLabel
@onready var right_label: Label = $Content/RightLabel

func setup(title: String, subtitle: String, right_text: String, swatch_color: Color = Color(0.7, 0.7, 0.7)) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	right_label.text = right_text
	swatch.color = swatch_color

## Optional leading icon (e.g. a potion vial). Rows that never call this
## keep IconSlot at zero size, so it's invisible and unused space isn't
## reserved for every row type.
func set_icon(icon_node: Control) -> void:
	for child in icon_slot.get_children():
		child.queue_free()
	icon_slot.add_child(icon_node)
	icon_slot.custom_minimum_size = icon_node.custom_minimum_size

func set_right_color(color: Color) -> void:
	right_label.add_theme_color_override("font_color", color)

func clear_right_color() -> void:
	right_label.remove_theme_color_override("font_color")
