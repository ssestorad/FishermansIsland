extends Control

const SEASON_COLORS := [
	Color(0.55, 0.8, 0.4),
	Color(0.95, 0.85, 0.3),
	Color(0.85, 0.5, 0.2),
	Color(0.7, 0.85, 0.95),
]

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var segment_w := size.x / SEASON_COLORS.size()
	for i in range(SEASON_COLORS.size()):
		draw_rect(Rect2(i * segment_w, 0, segment_w, size.y), SEASON_COLORS[i])
	var marker_x := WorldClock.get_season_progress() * size.x
	draw_line(Vector2(marker_x, 0), Vector2(marker_x, size.y), Color.WHITE, 3.0)
