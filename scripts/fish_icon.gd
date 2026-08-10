extends Control

var discovered: bool = false
var tier_color: Color = Color.WHITE

func set_state(p_discovered: bool, p_tier_color: Color) -> void:
	discovered = p_discovered
	tier_color = p_tier_color
	queue_redraw()

func _draw() -> void:
	var body_color := tier_color if discovered else Color(0.25, 0.25, 0.25)
	var w := size.x
	var h := size.y
	draw_circle(Vector2(w * 0.42, h * 0.5), h * 0.4, body_color)
	var tail := PackedVector2Array([
		Vector2(w * 0.72, h * 0.5),
		Vector2(w * 0.95, h * 0.2),
		Vector2(w * 0.95, h * 0.8),
	])
	draw_colored_polygon(tail, body_color)
