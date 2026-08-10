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
@onready var shop_button: Button = $CanvasLayer/ShopButton
@onready var menu_button: Button = $CanvasLayer/MenuButton
@onready var fishermen_panel: FishermenPanelController = $CanvasLayer/FishermenPanel
@onready var album_panel: AlbumPanelController = $CanvasLayer/AlbumPanel
@onready var shop_panel: ShopPanelController = $CanvasLayer/ShopPanel
@onready var profile_panel: FishermanProfilePanelController = $CanvasLayer/FishermanProfilePanel
@onready var equip_panel: EquipPanelController = $CanvasLayer/EquipPanel
@onready var autosave_timer: Timer = $AutosaveTimer

var fishermen: Array = []

func _ready() -> void:
	get_viewport().physics_object_picking = true

	if SaveManager.has_save():
		_load_game()
	else:
		_spawn_starting_fishermen()

	_update_coins_label(Economy.coins)
	_update_scales_label(Economy.scales)
	Economy.coins_changed.connect(_update_coins_label)
	Economy.scales_changed.connect(_update_scales_label)

	fishermen_button.pressed.connect(_on_fishermen_button_pressed)
	hire_button.pressed.connect(_on_hire_button_pressed)
	album_button.pressed.connect(_on_album_button_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

	fishermen_panel.fisherman_selected.connect(_show_profile)
	profile_panel.dismiss_requested.connect(_on_dismiss_requested)
	profile_panel.slot_clicked.connect(_on_slot_clicked)

	autosave_timer.timeout.connect(_on_autosave_timeout)

	_update_hire_button()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game(fishermen)
		get_tree().quit()

func _load_game() -> void:
	var data := SaveManager.load_data()
	Economy.load_state(int(data.get("coins", 0)), int(data.get("scales", 0)))
	var album_data: Dictionary = data.get("album", {})
	Album.load_state(album_data.get("caught_counts", {}), album_data.get("best_weights", {}))
	WorldClock.load_state(float(data.get("elapsed_time", 0.0)))
	Inventory.load_state(data.get("inventory", []))
	var saved_fishermen: Array = data.get("fishermen", [])
	if saved_fishermen.is_empty():
		_spawn_starting_fishermen()
		return
	for fisherman_data in saved_fishermen:
		_spawn_fisherman(fisherman_data)

func _spawn_starting_fishermen() -> void:
	for i in range(STARTING_FISHERMEN_COUNT):
		var fisherman := _spawn_fisherman()
		fisherman.speed_xp = randf_range(0.0, 40.0)
		fisherman.luck_xp = randf_range(0.0, 40.0)
		fisherman.power_xp = randf_range(0.0, 40.0)

func _spawn_fisherman(saved_data: Dictionary = {}) -> Node:
	var index := fishermen.size()
	var fisherman := FISHERMAN_SCENE.instantiate()
	fisherman.name = "Fisherman_%d" % (index + 1)
	var row_y := 110.0 + index * ROW_SPACING
	fisherman.home_position = Vector2(80, row_y)
	fisherman.dock_position = Vector2(320, row_y)

	if not saved_data.is_empty():
		fisherman.display_name = saved_data.get("display_name", "")
		fisherman.speed_xp = float(saved_data.get("speed_xp", 0.0))
		fisherman.luck_xp = float(saved_data.get("luck_xp", 0.0))
		fisherman.power_xp = float(saved_data.get("power_xp", 0.0))
		var equipped: Dictionary = saved_data.get("equipped_items", {})
		for slot in equipped:
			var item_name = equipped[slot]
			if item_name is String:
				var item := SaveManager.find_item_by_name(item_name)
				if item != null:
					fisherman.equipped_items[slot] = item
		if saved_data.has("appearance_variant"):
			fisherman.set_appearance_variant(int(saved_data.get("appearance_variant")))

	add_child(fisherman)
	fishermen.append(fisherman)
	fisherman.clicked.connect(_show_profile)
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
	album_panel.visible = false
	shop_panel.visible = false
	fishermen_panel.toggle(fishermen)

func _on_album_button_pressed() -> void:
	fishermen_panel.visible = false
	shop_panel.visible = false
	album_panel.toggle()

func _on_shop_button_pressed() -> void:
	fishermen_panel.visible = false
	album_panel.visible = false
	shop_panel.toggle()

func _on_menu_button_pressed() -> void:
	SaveManager.save_game(fishermen)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _show_profile(fisherman: Node) -> void:
	equip_panel.visible = false
	fishermen_panel.visible = false
	profile_panel.show_fisherman(fisherman)

func _on_slot_clicked(fisherman: Node, slot_name: String) -> void:
	profile_panel.visible = false
	equip_panel.open_for(fisherman, slot_name)

func _on_dismiss_requested(fisherman: Node) -> void:
	for slot in fisherman.equipped_items:
		var item = fisherman.equipped_items[slot]
		if item != null:
			Inventory.add_item(item)
	fishermen.erase(fisherman)
	fisherman.queue_free()
	_update_hire_button()

func _on_autosave_timeout() -> void:
	SaveManager.save_game(fishermen)

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "Coins: %d" % new_total
	_update_hire_button()

func _update_scales_label(new_total: int) -> void:
	scales_label.text = "Scales: %d" % new_total

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.55, 0.72, 0.38))
	draw_rect(Rect2(280, 80, 40, 240), Color(0.82, 0.72, 0.5))
	draw_rect(Rect2(300, 100, 300, 200), Color(0.22, 0.45, 0.65))
	for i in range(4):
		var y := 130.0 + i * 45.0
		draw_line(Vector2(320, y), Vector2(580, y), Color(0.35, 0.58, 0.75, 0.5), 2.0)
	draw_rect(Rect2(305, 95, 22, 210), Color(0.5, 0.35, 0.2))
