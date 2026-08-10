extends Control

@export var axis: String = "speed"

const COLORS := {
	"speed": Color(0.35, 0.55, 0.85),
	"luck": Color(0.45, 0.75, 0.4),
	"power": Color(0.85, 0.45, 0.3),
}
const SIZE := 16.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)

func _draw() -> void:
	var liquid_color: Color = COLORS.get(axis, Color(0.7, 0.7, 0.7))
	var neck_w := SIZE * 0.32
	var body_top := SIZE * 0.42

	# cork
	draw_rect(Rect2(SIZE / 2.0 - neck_w / 2.0, 0.0, neck_w, SIZE * 0.16), Color(0.5, 0.35, 0.2))
	# neck
	draw_rect(Rect2(SIZE / 2.0 - neck_w / 2.0, SIZE * 0.16, neck_w, SIZE * 0.26), Color(0.85, 0.9, 0.92, 0.7))
	# bottle body
	var body_points := PackedVector2Array([
		Vector2(SIZE / 2.0 - neck_w / 2.0, body_top),
		Vector2(SIZE / 2.0 + neck_w / 2.0, body_top),
		Vector2(SIZE * 0.88, SIZE),
		Vector2(SIZE * 0.12, SIZE),
	])
	draw_colored_polygon(body_points, liquid_color)
	draw_polyline(PackedVector2Array([body_points[0], body_points[1], body_points[2], body_points[3], body_points[0]]), Color(0.25, 0.22, 0.18, 0.6), 1.0)
