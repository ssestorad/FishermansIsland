extends Node2D

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")
const STARTING_FISHERMEN_COUNT := 1
const MAX_FISHERMEN_SLOTS := 6
const ROW_SPACING := 35.0
const BASE_HIRE_COST := 5
const HIRE_COST_GROWTH := 1.25

@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var scales_label: Label = $CanvasLayer/ScalesLabel
@onready var fishermen_button: Button = $CanvasLayer/FishermenButton
@onready var hire_button: Button = $CanvasLayer/HireButton
@onready var album_button: Button = $CanvasLayer/AlbumButton
@onready var fishermen_panel: Panel = $CanvasLayer/FishermenPanel
@onready var fishermen_rows: VBoxContainer = $CanvasLayer/FishermenPanel/MarginContainer/VBoxContainer/FishermenRows
@onready var album_panel: Panel = $CanvasLayer/AlbumPanel
@onready var album_title_label: Label = $CanvasLayer/AlbumPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var album_rows: VBoxContainer = $CanvasLayer/AlbumPanel/MarginContainer/VBoxContainer/AlbumScroll/AlbumRows
@onready var profile_panel: Panel = $CanvasLayer/FishermanProfilePanel
@onready var profile_name_label: Label = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/NameLabel
@onready var profile_speed_label: Label = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/SpeedLabel
@onready var profile_luck_label: Label = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/LuckLabel
@onready var profile_power_label: Label = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/PowerLabel
@onready var profile_equipment_slots: HBoxContainer = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/EquipmentSlots
@onready var profile_shop_button: Button = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/ShopButton
@onready var profile_close_button: Button = $CanvasLayer/FishermanProfilePanel/MarginContainer/VBoxContainer/CloseButton
@onready var shop_panel: Panel = $CanvasLayer/ShopPanel
@onready var shop_rows: VBoxContainer = $CanvasLayer/ShopPanel/MarginContainer/VBoxContainer/ShopRows
@onready var shop_back_button: Button = $CanvasLayer/ShopPanel/MarginContainer/VBoxContainer/BackButton

var fishermen: Array = []
var fisherman_row_labels: Dictionary = {}
var selected_fisherman: Node = null
var shop_items: Array = []

func _ready() -> void:
	get_viewport().physics_object_picking = true
	_update_coins_label(Economy.coins)
	_update_scales_label(Economy.scales)
	Economy.coins_changed.connect(_update_coins_label)
	Economy.scales_changed.connect(_update_scales_label)
	_spawn_starting_fishermen()
	fishermen_button.pressed.connect(_on_fishermen_button_pressed)
	hire_button.pressed.connect(_on_hire_button_pressed)
	album_button.pressed.connect(_on_album_button_pressed)
	profile_close_button.pressed.connect(_on_profile_close_pressed)
	profile_shop_button.pressed.connect(_on_shop_button_pressed)
	shop_back_button.pressed.connect(_on_shop_back_pressed)
	Album.updated.connect(_on_album_updated)
	_update_hire_button()

func _process(_delta: float) -> void:
	if fishermen_panel.visible:
		_refresh_fishermen_list()
	if profile_panel.visible:
		_refresh_profile_panel()
	if shop_panel.visible:
		_refresh_shop_list()

func _spawn_starting_fishermen() -> void:
	for i in range(STARTING_FISHERMEN_COUNT):
		var fisherman := _spawn_fisherman()
		fisherman.speed_xp = randf_range(0.0, 40.0)
		fisherman.luck_xp = randf_range(0.0, 40.0)
		fisherman.power_xp = randf_range(0.0, 40.0)

func _spawn_fisherman() -> Node:
	var index := fishermen.size()
	var fisherman := FISHERMAN_SCENE.instantiate()
	fisherman.name = "Fisherman_%d" % (index + 1)
	var row_y := 110.0 + index * ROW_SPACING
	fisherman.home_position = Vector2(80, row_y)
	fisherman.dock_position = Vector2(320, row_y)
	add_child(fisherman)
	fishermen.append(fisherman)
	fisherman.clicked.connect(_on_fisherman_clicked)
	return fisherman

func _on_hire_button_pressed() -> void:
	if fishermen.size() >= MAX_FISHERMEN_SLOTS:
		return
	var cost := _hire_cost_for_next_slot()
	if Economy.spend_coins(cost):
		_spawn_fisherman()
		_update_hire_button()

func _hire_cost_for_next_slot() -> int:
	return int(round(BASE_HIRE_COST * pow(HIRE_COST_GROWTH, fishermen.size() - 1)))

func _update_hire_button() -> void:
	if fishermen.size() >= MAX_FISHERMEN_SLOTS:
		hire_button.text = "Slots full (%d/%d)" % [fishermen.size(), MAX_FISHERMEN_SLOTS]
		hire_button.disabled = true
	else:
		var cost := _hire_cost_for_next_slot()
		hire_button.text = "Hire (%d coins)" % cost
		hire_button.disabled = Economy.coins < cost

func _on_fishermen_button_pressed() -> void:
	fishermen_panel.visible = not fishermen_panel.visible
	if fishermen_panel.visible:
		album_panel.visible = false
		_build_fishermen_list()

func _on_album_button_pressed() -> void:
	album_panel.visible = not album_panel.visible
	if album_panel.visible:
		fishermen_panel.visible = false
		_build_album_list()

func _on_album_updated() -> void:
	if album_panel.visible:
		_build_album_list()

func _build_album_list() -> void:
	for child in album_rows.get_children():
		album_rows.remove_child(child)
		child.queue_free()

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
		album_rows.add_child(header)

		for species in discovered_species:
			var key: String = species.species_name
			var row := Label.new()
			row.text = "   %s — caught %d, best %.1f kg" % [key, Album.caught_counts[key], Album.best_weights[key]]
			album_rows.add_child(row)

	album_title_label.text = "Fish Album (%d/%d)" % [total_discovered, total_species]

func _build_fishermen_list() -> void:
	for child in fishermen_rows.get_children():
		fishermen_rows.remove_child(child)
		child.queue_free()
	fisherman_row_labels.clear()
	for fisherman in fishermen:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_on_fisherman_clicked.bind(fisherman))
		fishermen_rows.add_child(row)
		fisherman_row_labels[fisherman] = row
	_refresh_fishermen_list()

func _refresh_fishermen_list() -> void:
	for fisherman in fisherman_row_labels:
		var row: Button = fisherman_row_labels[fisherman]
		row.text = "%s — %s" % [fisherman.display_name, fisherman.get_stats_text()]

func _on_fisherman_clicked(fisherman: Node) -> void:
	selected_fisherman = fisherman
	shop_panel.visible = false
	profile_panel.visible = true
	_refresh_profile_panel()

func _on_profile_close_pressed() -> void:
	profile_panel.visible = false
	selected_fisherman = null

func _refresh_profile_panel() -> void:
	if selected_fisherman == null or not is_instance_valid(selected_fisherman):
		profile_panel.visible = false
		return
	profile_name_label.text = selected_fisherman.display_name
	profile_speed_label.text = "Speed: Lvl %d" % selected_fisherman.get_level(selected_fisherman.speed_xp)
	profile_luck_label.text = "Luck: Lvl %d" % selected_fisherman.get_level(selected_fisherman.luck_xp)
	profile_power_label.text = "Power: Lvl %d" % selected_fisherman.get_level(selected_fisherman.power_xp)
	for slot_label in profile_equipment_slots.get_children():
		var slot_name: String = slot_label.name.trim_suffix("Slot")
		slot_label.text = "%s\n%s" % [slot_name, selected_fisherman.get_slot_display(slot_name)]

func _on_shop_button_pressed() -> void:
	if selected_fisherman == null:
		return
	profile_panel.visible = false
	shop_panel.visible = true
	_build_shop_list()

func _on_shop_back_pressed() -> void:
	shop_panel.visible = false
	profile_panel.visible = true

func _build_shop_list() -> void:
	for child in shop_rows.get_children():
		shop_rows.remove_child(child)
		child.queue_free()
	shop_items = ShopCatalog.default_items()
	for item in shop_items:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s (%s, +%d%% %s) — %d coins" % [item.item_name, item.slot, roundi(item.bonus * 100), item.axis.capitalize(), item.cost]
		row.pressed.connect(_on_buy_item.bind(item))
		shop_rows.add_child(row)
	_refresh_shop_list()

func _refresh_shop_list() -> void:
	for i in range(shop_rows.get_child_count()):
		var button: Button = shop_rows.get_child(i)
		var item: Item = shop_items[i]
		button.disabled = Economy.coins < item.cost

func _on_buy_item(item: Item) -> void:
	if selected_fisherman == null or not is_instance_valid(selected_fisherman):
		return
	if Economy.spend_coins(item.cost):
		selected_fisherman.equip_item(item)

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "Coins: %d" % new_total
	_update_hire_button()

func _update_scales_label(new_total: int) -> void:
	scales_label.text = "Scales: %d" % new_total

func _draw() -> void:
	draw_rect(Rect2(300, 100, 300, 200), Color(0.2, 0.4, 0.8))
