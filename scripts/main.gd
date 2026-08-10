extends Node2D

@onready var coins_label: Label = $CanvasLayer/CoinsLabel

func _ready() -> void:
	_update_coins_label(Economy.coins)
	Economy.coins_changed.connect(_update_coins_label)

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "Coins: %d" % new_total

func _draw() -> void:
	draw_rect(Rect2(300, 100, 300, 200), Color(0.2, 0.4, 0.8))
