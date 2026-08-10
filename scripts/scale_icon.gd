extends Control

const SIZE := 12.0
const FILL_COLOR := Color(0.45, 0.75, 0.8)
const RIM_COLOR := Color(0.2, 0.45, 0.5)

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)

func _draw() -> void:
	var half := SIZE / 2.0
	var points := PackedVector2Array([
		Vector2(half, 0.0),
		Vector2(SIZE, half),
		Vector2(half, SIZE),
		Vector2(0.0, half),
	])
	draw_colored_polygon(points, RIM_COLOR)
	var inset := 1.5
	var inner := PackedVector2Array([
		Vector2(half, inset),
		Vector2(SIZE - inset, half),
		Vector2(half, SIZE - inset),
		Vector2(inset, half),
	])
	draw_colored_polygon(inner, FILL_COLOR)
