extends Label

func _process(_delta: float) -> void:
	text = "Day %d — %s (%s, %s)" % [
		WorldClock.get_day_number(), WorldClock.get_clock_text(), WorldClock.get_season_name(), WorldClock.get_weather()
	]
