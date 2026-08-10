class_name AlbumPanelController
extends Panel

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/AlbumScroll/AlbumRows

func _ready() -> void:
	Album.updated.connect(_on_album_updated)

func toggle() -> void:
	visible = not visible
	if visible:
		build()

func _on_album_updated() -> void:
	if visible:
		build()

func build() -> void:
	UiListUtils.clear_children(rows_container)

	var total_discovered := 0
	var total_species := 0

	for tier in FishRarity.Tier.values():
		var species_list: Array = FishCatalog.species_for_tier(tier)
		var discovered_species: Array = []
		for species in species_list:
			if Album.is_discovered(species.species_name):
				discovered_species.append(species)

		total_discovered += discovered_species.size()
		total_species += species_list.size()

		var header := Label.new()
		header.add_theme_font_size_override("font_size", 16)
		header.text = "%s — %d/%d discovered" % [FishRarity.name_for(tier), discovered_species.size(), species_list.size()]
		rows_container.add_child(header)

		for species in discovered_species:
			var key: String = species.species_name
			var row := Label.new()
			row.text = "   %s — caught %d, best %.1f kg" % [key, Album.caught_counts[key], Album.best_weights[key]]
			rows_container.add_child(row)

	title_label.text = "Fish Album (%d/%d)" % [total_discovered, total_species]
