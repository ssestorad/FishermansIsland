extends ColorRect

const WEATHER_COLORS := {
	"Sunny": Color(1.0, 1.0, 1.0, 0.0),
	"Rainy": Color(0.3, 0.4, 0.6, 0.18),
	"Foggy": Color(0.8, 0.8, 0.85, 0.25),
	"Stormy": Color(0.2, 0.15, 0.25, 0.3),
	"Blizzard": Color(0.85, 0.9, 1.0, 0.4),
}

func _process(_delta: float) -> void:
	color = WEATHER_COLORS[WorldClock.get_weather()]
