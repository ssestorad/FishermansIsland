class_name AlbumPanelController
extends Panel

const TIER_COLORS := {
	FishRarity.Tier.COMMON: Color(0.7, 0.7, 0.7),
	FishRarity.Tier.UNCOMMON: Color(0.4, 0.75, 0.4),
	FishRarity.Tier.RARE: Color(0.3, 0.5, 0.9),
	FishRarity.Tier.EPIC: Color(0.6, 0.35, 0.85),
	FishRarity.Tier.LEGENDARY: Color(0.9, 0.65, 0.15),
	FishRarity.Tier.MYTHIC: Color(0.85, 0.2, 0.25),
}

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var card_area: VBoxContainer = $MarginContainer/VBoxContainer/CardArea
@onready var page_label: Label = $MarginContainer/VBoxContainer/CardArea/PageLabel
@onready var icon: Sprite2D = $MarginContainer/VBoxContainer/CardArea/IconPanel/FishIcon
@onready var icon_question_mark: Label = $MarginContainer/VBoxContainer/CardArea/IconPanel/QuestionMark
@onready var species_name_label: Label = $MarginContainer/VBoxContainer/CardArea/SpeciesNameLabel
@onready var tier_label: Label = $MarginContainer/VBoxContainer/CardArea/TierLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/CardArea/StatsLabel
@onready var stats_area: VBoxContainer = $MarginContainer/VBoxContainer/StatsArea
@onready var prev_button: Button = $MarginContainer/VBoxContainer/NavRow/PrevButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavRow/NextButton
@onready var tab_overview: Button = $MarginContainer/VBoxContainer/TierTabs/OverviewTab
@onready var tab_common: Button = $MarginContainer/VBoxContainer/TierTabs/CommonTab
@onready var tab_uncommon: Button = $MarginContainer/VBoxContainer/TierTabs/UncommonTab
@onready var tab_rare: Button = $MarginContainer/VBoxContainer/TierTabs/RareTab
@onready var tab_epic: Button = $MarginContainer/VBoxContainer/TierTabs/EpicTab
@onready var tab_legendary: Button = $MarginContainer/VBoxContainer/TierTabs/LegendaryTab
@onready var tab_mythic: Button = $MarginContainer/VBoxContainer/TierTabs/MythicTab
@onready var stat_common: Label = $MarginContainer/VBoxContainer/StatsArea/CommonStat
@onready var stat_uncommon: Label = $MarginContainer/VBoxContainer/StatsArea/UncommonStat
@onready var stat_rare: Label = $MarginContainer/VBoxContainer/StatsArea/RareStat
@onready var stat_epic: Label = $MarginContainer/VBoxContainer/StatsArea/EpicStat
@onready var stat_legendary: Label = $MarginContainer/VBoxContainer/StatsArea/LegendaryStat
@onready var stat_mythic: Label = $MarginContainer/VBoxContainer/StatsArea/MythicStat

var _all_species: Array = []
var _tier_start_index: Dictionary = {}
var _stat_labels: Dictionary = {}
var _current_index: int = -1  # -1 = overview page

func _ready() -> void:
	for tier in FishRarity.Tier.values():
		_tier_start_index[tier] = _all_species.size()
		_all_species.append_array(FishCatalog.species_for_tier(tier))
	_stat_labels = {
		FishRarity.Tier.COMMON: stat_common,
		FishRarity.Tier.UNCOMMON: stat_uncommon,
		FishRarity.Tier.RARE: stat_rare,
		FishRarity.Tier.EPIC: stat_epic,
		FishRarity.Tier.LEGENDARY: stat_legendary,
		FishRarity.Tier.MYTHIC: stat_mythic,
	}
	Album.updated.connect(_on_album_updated)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	tab_overview.pressed.connect(_on_overview_tab_pressed)
	tab_common.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.COMMON))
	tab_uncommon.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.UNCOMMON))
	tab_rare.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.RARE))
	tab_epic.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.EPIC))
	tab_legendary.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.LEGENDARY))
	tab_mythic.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.MYTHIC))

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func _on_album_updated() -> void:
	if visible:
		refresh()

func _on_prev_pressed() -> void:
	_current_index -= 1
	if _current_index < -1:
		_current_index = _all_species.size() - 1
	refresh()

func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _all_species.size():
		_current_index = -1
	refresh()

func _on_overview_tab_pressed() -> void:
	_current_index = -1
	refresh()

func _on_tier_tab_pressed(tier: FishRarity.Tier) -> void:
	_current_index = _tier_start_index[tier]
	refresh()

func refresh() -> void:
	var total_discovered := 0
	for species in _all_species:
		if Album.is_discovered(species.species_name):
			total_discovered += 1
	title_label.text = "Fish Album (%d/%d)" % [total_discovered, _all_species.size()]

	if _current_index == -1:
		card_area.visible = false
		stats_area.visible = true
		_refresh_stats()
		return

	card_area.visible = true
	stats_area.visible = false

	var species: FishSpecies = _all_species[_current_index]
	var discovered: bool = Album.is_discovered(species.species_name)
	var tier_color: Color = TIER_COLORS[species.tier]

	page_label.text = "%d / %d" % [_current_index + 1, _all_species.size()]
	icon.set_species(species.species_name, discovered, tier_color)
	icon_question_mark.visible = not discovered
	tier_label.text = FishRarity.name_for(species.tier)
	tier_label.add_theme_color_override("font_color", tier_color)

	if discovered:
		var key: String = species.species_name
		species_name_label.text = key
		stats_label.text = "Caught %d, best %.1f kg" % [Album.caught_counts[key], Album.best_weights[key]]
	else:
		species_name_label.text = "???"
		stats_label.text = "Not yet discovered"

func _refresh_stats() -> void:
	for tier in FishRarity.Tier.values():
		var species_list: Array = FishCatalog.species_for_tier(tier)
		var discovered := 0
		for species in species_list:
			if Album.is_discovered(species.species_name):
				discovered += 1
		var label: Label = _stat_labels[tier]
		label.text = "%s — %d/%d" % [FishRarity.name_for(tier), discovered, species_list.size()]
		label.add_theme_color_override("font_color", TIER_COLORS[tier])
