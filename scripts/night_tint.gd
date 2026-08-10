extends ColorRect

const MAX_ALPHA := 0.55

func _process(_delta: float) -> void:
	color = Color(0.05, 0.05, 0.2, WorldClock.get_night_factor() * MAX_ALPHA)
