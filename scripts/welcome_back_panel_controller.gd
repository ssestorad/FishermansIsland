class_name WelcomeBackPanelController
extends Panel

@onready var duration_label: Label = $MarginContainer/VBoxContainer/DurationLabel
@onready var catches_label: Label = $MarginContainer/VBoxContainer/CatchesLabel
@onready var coins_label: Label = $MarginContainer/VBoxContainer/CurrencyRow/CoinsEarnedLabel
@onready var scales_label: Label = $MarginContainer/VBoxContainer/CurrencyRow/ScalesEarnedLabel
@onready var best_catch_label: Label = $MarginContainer/VBoxContainer/BestCatchLabel
@onready var ok_button: Button = $MarginContainer/VBoxContainer/OkButton

func _ready() -> void:
	ok_button.pressed.connect(_on_ok_pressed)

func show_summary(away_seconds: float, catches: int, coins: int, scales: int, best: Dictionary) -> void:
	duration_label.text = "You were away for %s" % _format_duration(away_seconds)
	catches_label.text = "%d fish caught while you were gone" % catches
	coins_label.text = "+%d" % coins
	scales_label.text = "+%d" % scales

	if best.is_empty():
		best_catch_label.visible = false
	else:
		var rarity: FishRarity.Tier = best.best_rarity
		best_catch_label.visible = true
		best_catch_label.text = "Best catch: %s (%s, %.1f kg)" % [best.best_species, FishRarity.name_for(rarity), best.best_weight]
		best_catch_label.add_theme_color_override("font_color", RarityColors.for_tier(rarity))

	visible = true

func _format_duration(seconds: float) -> String:
	var total_minutes := int(seconds / 60.0)
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % maxi(minutes, 1)

func _on_ok_pressed() -> void:
	visible = false
