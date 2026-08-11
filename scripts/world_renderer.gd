class_name WorldRenderer
extends Node2D

## Painted from WorldLayout so station placement validates against the
## same geometry that is drawn here.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WorldLayout.WORLD_SIZE), WorldLayout.LAND_COLOR)
	draw_rect(WorldLayout.SAND_RECT, WorldLayout.SAND_COLOR)
	draw_rect(WorldLayout.WATER_RECT, WorldLayout.WATER_COLOR)
	for i in range(4):
		var y := 130.0 + i * 45.0
		draw_line(Vector2(320, y), Vector2(580, y), WorldLayout.WAVE_COLOR, 2.0)
	draw_rect(WorldLayout.PIER_RECT, WorldLayout.PIER_COLOR)
	_draw_pond()
	# Only exists once bought, so the purchase visibly builds something.
	if FishingSpots.is_unlocked(FishingSpots.OFFSHORE):
		draw_rect(WorldLayout.JETTY_RECT, WorldLayout.JETTY_COLOR)
		draw_rect(
			Rect2(WorldLayout.JETTY_RECT.position + Vector2(0.0, WorldLayout.JETTY_RECT.size.y - 4.0),
				Vector2(WorldLayout.JETTY_RECT.size.x, 4.0)),
			WorldLayout.JETTY_PLANK_COLOR
		)

func _draw_pond() -> void:
	var pond := WorldLayout.POND_RECT
	draw_rect(pond, WorldLayout.POND_COLOR)
	# A lighter rim reads as shallows and keeps the pond from looking like
	# a hole punched in the grass.
	draw_rect(Rect2(pond.position, Vector2(pond.size.x, 3.0)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position + Vector2(0.0, pond.size.y - 3.0), Vector2(pond.size.x, 3.0)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position, Vector2(3.0, pond.size.y)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position + Vector2(pond.size.x - 3.0, 0.0), Vector2(3.0, pond.size.y)), WorldLayout.POND_SHALLOW_COLOR)
