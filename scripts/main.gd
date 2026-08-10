extends Node2D

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")
const STARTING_FISHERMEN_COUNT := 5
const ROW_SPACING := 35.0

@onready var coins_label: Label = $CanvasLayer/CoinsLabel

func _ready() -> void:
	_update_coins_label(Economy.coins)
	Economy.coins_changed.connect(_update_coins_label)
	_spawn_starting_fishermen()

func _spawn_starting_fishermen() -> void:
	for i in range(STARTING_FISHERMEN_COUNT):
		var fisherman := FISHERMAN_SCENE.instantiate()
		fisherman.name = "Fisherman_%d" % (i + 1)
		var row_y := 110.0 + i * ROW_SPACING
		fisherman.home_position = Vector2(80, row_y)
		fisherman.dock_position = Vector2(320, row_y)
		fisherman.power = randf_range(0.0, 0.8)
		add_child(fisherman)

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "Coins: %d" % new_total

func _draw() -> void:
	draw_rect(Rect2(300, 100, 300, 200), Color(0.2, 0.4, 0.8))
