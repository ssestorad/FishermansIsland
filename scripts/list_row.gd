class_name ListRow
extends Button

@onready var swatch: ColorRect = $Content/Swatch
@onready var title_label: Label = $Content/TextStack/TitleLabel
@onready var subtitle_label: Label = $Content/TextStack/SubtitleLabel
@onready var right_label: Label = $Content/RightLabel

func setup(title: String, subtitle: String, right_text: String, swatch_color: Color = Color(0.7, 0.7, 0.7)) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	right_label.text = right_text
	swatch.color = swatch_color

func set_right_color(color: Color) -> void:
	right_label.add_theme_color_override("font_color", color)

func clear_right_color() -> void:
	right_label.remove_theme_color_override("font_color")
