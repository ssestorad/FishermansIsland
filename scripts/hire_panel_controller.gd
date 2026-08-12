class_name HirePanelController
extends PanelController

## Lets the player choose one of several rolled candidates instead of an
## instant random hire. Built and shown by main.gd's hire flow; a card's
## own "Hire" button is what actually commits — closing the panel any
## other way (CloseButton, from the PanelController base) backs out with
## no charge and no roster change.
##
## Own `open(candidates, cost)` entry point rather than overriding
## `build()`/`toggle()` — this project's established fix for the same
## GDScript constraint that already hit FishermenPanelController/
## StatsPanelController: a typed-argument override is a hard parse error
## against the base's zero-arg virtual.

signal candidate_chosen(candidate: Dictionary)

@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel
@onready var candidates_list: VBoxContainer = $MarginContainer/VBoxContainer/CandidatesScroll/CandidatesList

func open(candidates: Array, cost: int) -> void:
	visible = true
	cost_label.text = "Cost: %d Coins" % cost
	for child in candidates_list.get_children():
		child.queue_free()
	for candidate in candidates:
		candidates_list.add_child(_build_card(candidate))

func _build_card(candidate: Dictionary) -> Control:
	var card := PanelContainer.new()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(32, 48)
	portrait.texture = FishermanFactory.portrait_texture(candidate.get("appearance_variant", 0))
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.text = candidate.get("display_name", "")
	info.add_child(name_label)

	var perks: Array = candidate.get("perks", [])
	var perks_label := Label.new()
	perks_label.add_theme_font_size_override("font_size", 10)
	perks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if perks.is_empty():
		perks_label.text = "No perks"
	else:
		var parts: Array = []
		for perk_name in perks:
			var perk: Dictionary = PerkCatalog.find(perk_name)
			parts.append("%s (%s)" % [perk_name, perk.get("description", "")])
		perks_label.text = "Perks: " + ", ".join(parts)
	info.add_child(perks_label)

	var weather_label := Label.new()
	weather_label.theme_type_variation = &"MutedLabel"
	weather_label.text = "Favorite weather: %s" % candidate.get("favorite_weather", "")
	info.add_child(weather_label)

	var hire_button := Button.new()
	hire_button.text = "Hire"
	hire_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hire_button.pressed.connect(_on_candidate_hire_pressed.bind(candidate))
	row.add_child(hire_button)

	return card

func _on_candidate_hire_pressed(candidate: Dictionary) -> void:
	candidate_chosen.emit(candidate)
	visible = false
