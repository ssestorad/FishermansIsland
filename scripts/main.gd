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
@onready var fishermen_panel: FishermenPanelController = $CanvasLayer/FishermenPanel
@onready var album_panel: AlbumPanelController = $CanvasLayer/AlbumPanel
@onready var profile_panel: FishermanProfilePanelController = $CanvasLayer/FishermanProfilePanel
@onready var shop_panel: ShopPanelController = $CanvasLayer/ShopPanel

var fishermen: Array = []

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

	fishermen_panel.fisherman_selected.connect(_show_profile)
	profile_panel.shop_requested.connect(_on_shop_requested)
	shop_panel.back_pressed.connect(_on_shop_back)

	_update_hire_button()

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
	fishermen_panel.toggle(fishermen)

func _on_album_button_pressed() -> void:
	fishermen_panel.visible = false
	album_panel.toggle()

func _show_profile(fisherman: Node) -> void:
	shop_panel.visible = false
	profile_panel.show_fisherman(fisherman)

func _on_shop_requested(fisherman: Node) -> void:
	profile_panel.visible = false
	shop_panel.open_for(fisherman)

func _on_shop_back() -> void:
	profile_panel.visible = true

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "Coins: %d" % new_total
	_update_hire_button()

func _update_scales_label(new_total: int) -> void:
	scales_label.text = "Scales: %d" % new_total

func _draw() -> void:
	draw_rect(Rect2(300, 100, 300, 200), Color(0.2, 0.4, 0.8))
