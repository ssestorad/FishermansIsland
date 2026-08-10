extends Control

const RADIUS := 6.0
const FILL_COLOR := Color(0.95, 0.78, 0.25)
const RIM_COLOR := Color(0.65, 0.48, 0.1)

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)

func _draw() -> void:
	var center := Vector2(RADIUS, RADIUS)
	draw_circle(center, RADIUS, RIM_COLOR)
	draw_circle(center, RADIUS - 1.5, FILL_COLOR)
