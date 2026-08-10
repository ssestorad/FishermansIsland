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
@onready var stats_area: VBoxContainer = $MarginContainer/VBoxContainer/StatsArea
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

var _all_species: Array = []
var _tier_start_index: Dictionary = {}
var _stat_rows: Dictionary = {}
var _tier_tabs: Dictionary = {}
var _current_index: int = -1  # -1 = overview page

func _ready() -> void:
	for tier in FishRarity.Tier.values():
		_tier_start_index[tier] = _all_species.size()
		_all_species.append_array(FishCatalog.species_for_tier(tier))
	_tier_tabs = {
		FishRarity.Tier.COMMON: tab_common,
		FishRarity.Tier.UNCOMMON: tab_uncommon,
		FishRarity.Tier.RARE: tab_rare,
		FishRarity.Tier.EPIC: tab_epic,
		FishRarity.Tier.LEGENDARY: tab_legendary,
		FishRarity.Tier.MYTHIC: tab_mythic,
		FishRarity.Tier.SECRET: tab_secret,
	}
	_build_stat_rows()
	Album.updated.connect(_on_album_updated)
	close_button.pressed.connect(_on_close_button_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	tab_overview.pressed.connect(_on_overview_tab_pressed)
	tab_common.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.COMMON))
	tab_uncommon.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.UNCOMMON))
	tab_rare.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.RARE))
	tab_epic.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.EPIC))
	tab_legendary.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.LEGENDARY))
	tab_mythic.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.MYTHIC))
	tab_secret.pressed.connect(_on_tier_tab_pressed.bind(FishRarity.Tier.SECRET))

func _build_stat_rows() -> void:
	for tier in FishRarity.Tier.values():
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_rows_container.add_child(row)
		_stat_rows[tier] = row

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

## True once at least one Secret-tier species has been caught. Drives
## whether the Secret tab/stat row reveal themselves at all — until then
## the tier's existence stays hidden, not just its individual species.
func _is_secret_unlocked() -> bool:
	for species in FishCatalog.species_for_tier(FishRarity.Tier.SECRET):
		if Album.is_discovered(species.species_name):
			return true
	return false

func refresh() -> void:
	var total_discovered := 0
	for species in _all_species:
		if Album.is_discovered(species.species_name):
			total_discovered += 1
	title_label.text = "Fish Album (%d/%d)" % [total_discovered, _all_species.size()]
	tab_secret.visible = _is_secret_unlocked()
	_update_tab_selection()

	if _current_index == -1:
		card_scroll.visible = false
		stats_area.visible = true
		_refresh_stats()
		return

	card_scroll.visible = true
	stats_area.visible = false

	var species: FishSpecies = _all_species[_current_index]
	var discovered: bool = Album.is_discovered(species.species_name)
	# An undiscovered Secret species must not leak its own tier name/color —
	# that would announce "there's a hidden category" before the player has
	# actually found it. Every other tier's name is fair to show undiscovered.
	var reveal_tier: bool = discovered or species.tier != FishRarity.Tier.SECRET
	var tier_color: Color = RarityColors.for_tier(species.tier) if reveal_tier else RarityColors.for_tier(FishRarity.Tier.COMMON)

	page_label.text = "%d / %d" % [_current_index + 1, _all_species.size()]
	icon.set_species(species.species_name, discovered, tier_color)
	icon_question_mark.visible = not discovered
	tier_label.text = FishRarity.name_for(species.tier) if reveal_tier else "???"
	tier_label.add_theme_color_override("font_color", tier_color)

	if discovered:
		var key: String = species.species_name
		species_name_label.text = key
		var record_holder := Album.get_record_holder(key)
		var record_text := " · record: %s" % record_holder if record_holder != "" else ""
		stats_label.text = "Caught %d, best %.1f kg%s" % [Album.caught_counts[key], Album.best_weights[key], record_text]
		var weight_range: Vector2 = FishRarity.WEIGHT_RANGES[species.tier]
		if species.tier == FishRarity.Tier.SECRET:
			detail_label.text = "A hidden catch, not from the normal odds · %.1f–%.1f kg · %s" % [
				weight_range.x, weight_range.y, species.condition_text()
			]
		else:
			detail_label.text = "≈%.1f%% of catches before Luck · %.1f–%.1f kg · %s" % [
				FishRarity.base_chance_percent(species.tier), weight_range.x, weight_range.y, species.condition_text()
			]
	else:
		species_name_label.text = "???"
		stats_label.text = "Not yet discovered"
		detail_label.text = ""

func _refresh_stats() -> void:
	var secret_unlocked := _is_secret_unlocked()
	for tier in FishRarity.Tier.values():
		var row: ListRow = _stat_rows[tier]
		if tier == FishRarity.Tier.SECRET and not secret_unlocked:
			row.visible = false
			continue
		row.visible = true
		var species_list: Array = FishCatalog.species_for_tier(tier)
		var discovered := 0
		for species in species_list:
			if Album.is_discovered(species.species_name):
				discovered += 1
		var color := RarityColors.for_tier(tier)
		row.setup(FishRarity.name_for(tier), "", "%d/%d" % [discovered, species_list.size()], color)
		row.set_right_color(color)

func _current_tier() -> int:
	if _current_index == -1:
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
