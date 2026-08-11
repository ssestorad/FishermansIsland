class_name AlbumPanelController
extends Panel

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var card_scroll: ScrollContainer = $MarginContainer/VBoxContainer/CardScroll
@onready var page_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/PageLabel
@onready var icon: Sprite2D = $MarginContainer/VBoxContainer/CardScroll/CardArea/IconPanel/FishIcon
@onready var icon_question_mark: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/IconPanel/QuestionMark
@onready var species_name_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/SpeciesNameLabel
@onready var tier_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/TierLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/StatsLabel
@onready var detail_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/DetailLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/CardScroll/CardArea/DescriptionLabel
@onready var stats_area: VBoxContainer = $MarginContainer/VBoxContainer/StatsArea
@onready var overview_title: Label = $MarginContainer/VBoxContainer/StatsArea/OverviewTitle
@onready var rarity_mode_button: Button = $MarginContainer/VBoxContainer/StatsArea/ModeRow/RarityModeButton
@onready var habitat_mode_button: Button = $MarginContainer/VBoxContainer/StatsArea/ModeRow/HabitatModeButton
@onready var stat_rows_container: VBoxContainer = $MarginContainer/VBoxContainer/StatsArea/StatsScroll/StatRows
@onready var prev_button: Button = $MarginContainer/VBoxContainer/NavRow/PrevButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/NavRow/NextButton
@onready var tab_overview: Button = $MarginContainer/VBoxContainer/TierTabs/OverviewTab
@onready var tab_common: Button = $MarginContainer/VBoxContainer/TierTabs/CommonTab
@onready var tab_uncommon: Button = $MarginContainer/VBoxContainer/TierTabs/UncommonTab
@onready var tab_rare: Button = $MarginContainer/VBoxContainer/TierTabs/RareTab
@onready var tab_epic: Button = $MarginContainer/VBoxContainer/TierTabs/EpicTab
@onready var tab_legendary: Button = $MarginContainer/VBoxContainer/TierTabs/LegendaryTab
@onready var tab_mythic: Button = $MarginContainer/VBoxContainer/TierTabs/MythicTab
@onready var tab_secret: Button = $MarginContainer/VBoxContainer/TierTabs/SecretTab

const HABITAT_COLOR := Color(0.36, 0.55, 0.5)

var _all_species: Array = []
var _tier_start_index: Dictionary = {}
var _tier_tabs: Dictionary = {}

## The list Prev/Next currently walks: every species, or one habitat's.
var _view: Array = []
## "" while browsing everything, otherwise the habitat being browsed.
var _view_habitat: String = ""
var _current_index: int = -1  # -1 = overview page
## Which breakdown the overview page shows: "rarity" or "habitat".
var _overview_mode: String = "rarity"

func _ready() -> void:
	for tier in FishRarity.Tier.values():
		_tier_start_index[tier] = _all_species.size()
		_all_species.append_array(FishCatalog.species_for_tier(tier))
	_view = _all_species
	_tier_tabs = {
		FishRarity.Tier.COMMON: tab_common,
		FishRarity.Tier.UNCOMMON: tab_uncommon,
		FishRarity.Tier.RARE: tab_rare,
		FishRarity.Tier.EPIC: tab_epic,
		FishRarity.Tier.LEGENDARY: tab_legendary,
		FishRarity.Tier.MYTHIC: tab_mythic,
		FishRarity.Tier.SECRET: tab_secret,
	}
	Album.updated.connect(_on_album_updated)
	close_button.pressed.connect(_on_close_button_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	tab_overview.pressed.connect(_on_overview_tab_pressed)
	rarity_mode_button.pressed.connect(_on_overview_mode_pressed.bind("rarity"))
	habitat_mode_button.pressed.connect(_on_overview_mode_pressed.bind("habitat"))
	for tier in _tier_tabs:
		_tier_tabs[tier].pressed.connect(_on_tier_tab_pressed.bind(tier))

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func _on_album_updated() -> void:
	if visible:
		refresh()

func _on_close_button_pressed() -> void:
	visible = false

func _on_prev_pressed() -> void:
	_current_index -= 1
	if _current_index < -1:
		_current_index = _view.size() - 1
	refresh()

func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _view.size():
		_current_index = -1
	refresh()

func _on_overview_tab_pressed() -> void:
	_current_index = -1
	refresh()

func _on_overview_mode_pressed(mode: String) -> void:
	_overview_mode = mode
	_current_index = -1
	refresh()

func _on_tier_tab_pressed(tier: FishRarity.Tier) -> void:
	# Tier tabs always browse the full roster, so they clear any habitat
	# the player had drilled into.
	_view = _all_species
	_view_habitat = ""
	_current_index = _tier_start_index[tier]
	refresh()

func _on_habitat_pressed(habitat: String) -> void:
	_view = _visible_species_for_habitat(habitat)
	_view_habitat = habitat
	_current_index = 0
	refresh()

## Until any Secret species has been caught, the tier's very existence
## stays hidden — its tab, its overview row, and its members inside
## habitat listings. Album.has_caught_secret() is shared with the
## meta-shop's Secret Catch Chance upgrade, which stays hidden the same way.
func _is_secret_unlocked() -> bool:
	return Album.has_caught_secret()

func _visible_species_for_habitat(habitat: String) -> Array:
	var secret_unlocked := _is_secret_unlocked()
	var result: Array = []
	for species in FishCatalog.species_for_habitat(habitat):
		if species.tier == FishRarity.Tier.SECRET and not secret_unlocked:
			continue
		result.append(species)
	return result

func refresh() -> void:
	var total_discovered := 0
	for species in _all_species:
		if Album.is_discovered(species.species_name):
			total_discovered += 1
	title_label.text = "Fish Album (%d/%d)" % [total_discovered, _all_species.size()]
	tab_secret.visible = _is_secret_unlocked()
	_update_tab_selection()

	if _current_index == -1 or _view.is_empty():
		card_scroll.visible = false
		stats_area.visible = true
		_refresh_overview()
		return

	card_scroll.visible = true
	stats_area.visible = false

	var species: FishSpecies = _view[_current_index]
	var discovered: bool = Album.is_discovered(species.species_name)
	# An undiscovered Secret species must not leak its own tier name or
	# colour — that would announce a hidden category before it's found.
	var reveal_tier: bool = discovered or species.tier != FishRarity.Tier.SECRET
	var tier_color: Color = RarityColors.for_tier(species.tier) if reveal_tier else RarityColors.for_tier(FishRarity.Tier.COMMON)

	var scope := _view_habitat if _view_habitat != "" else "All"
	page_label.text = "%s — %d / %d" % [scope, _current_index + 1, _view.size()]
	icon.set_species(species.model, discovered, tier_color)
	icon_question_mark.visible = not discovered
	tier_label.text = FishRarity.name_for(species.tier) if reveal_tier else "???"
	tier_label.add_theme_color_override("font_color", tier_color)

	if discovered:
		var key: String = species.species_name
		species_name_label.text = key
		var record_holder := Album.get_record_holder(key)
		var record_text := " · record: %s" % record_holder if record_holder != "" else ""
		stats_label.text = "Caught %d, best %.1f kg%s" % [Album.caught_counts[key], Album.best_weights[key], record_text]
		detail_label.text = "%s · %s · %s" % [species.habitat, species.weight_text(), species.condition_text()]
		description_label.text = species.description
	else:
		species_name_label.text = "???"
		stats_label.text = "Not yet discovered"
		# The habitat is a fair hint for an undiscovered fish — it tells the
		# player where to go looking without giving the catch away.
		detail_label.text = "%s · not yet discovered" % species.habitat if reveal_tier else ""
		description_label.text = ""

func _refresh_overview() -> void:
	UiListUtils.clear_children(stat_rows_container)
	rarity_mode_button.disabled = _overview_mode == "rarity"
	habitat_mode_button.disabled = _overview_mode == "habitat"
	if _overview_mode == "habitat":
		overview_title.text = "Discovery by Habitat"
		_build_habitat_rows()
	else:
		overview_title.text = "Discovery by Rarity"
		_build_rarity_rows()

func _build_rarity_rows() -> void:
	var secret_unlocked := _is_secret_unlocked()
	for tier in FishRarity.Tier.values():
		if tier == FishRarity.Tier.SECRET and not secret_unlocked:
			continue
		var species_list: Array = FishCatalog.species_for_tier(tier)
		var discovered := 0
		for species in species_list:
			if Album.is_discovered(species.species_name):
				discovered += 1
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_rows_container.add_child(row)
		var color := RarityColors.for_tier(tier)
		row.setup(FishRarity.name_for(tier), "", "%d/%d" % [discovered, species_list.size()], color)
		row.set_right_color(color)

func _build_habitat_rows() -> void:
	for habitat in FishCatalog.HABITATS:
		var species_list := _visible_species_for_habitat(habitat)
		if species_list.is_empty():
			continue
		var discovered := 0
		for species in species_list:
			if Album.is_discovered(species.species_name):
				discovered += 1
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		stat_rows_container.add_child(row)
		row.setup(habitat, "", "%d/%d" % [discovered, species_list.size()], HABITAT_COLOR)
		row.set_right_color(HABITAT_COLOR)
		row.pressed.connect(_on_habitat_pressed.bind(habitat))

## Index of the tier the card is currently showing, or -1 on the overview
## page. Only meaningful while browsing the full roster: inside a habitat
## the tier tabs stop tracking the card.
func _current_tier() -> int:
	if _current_index == -1 or _view != _all_species:
		return -1
	var tiers := FishRarity.Tier.values()
	for i in range(tiers.size() - 1, -1, -1):
		if _current_index >= _tier_start_index[tiers[i]]:
			return tiers[i]
	return tiers[0]

func _update_tab_selection() -> void:
	var active_tier := _current_tier()
	tab_overview.disabled = _current_index == -1
	for tier in _tier_tabs:
		_tier_tabs[tier].disabled = tier == active_tier
