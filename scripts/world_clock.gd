extends Node

const DAY_NIGHT_CYCLE_DURATION := 1200.0  # 20 min
const SEASON_DURATION := 3600.0  # 1 hour
const WEATHER_CHANGE_INTERVAL := 300.0  # 5 min
const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]

const WEATHER_TYPES := ["Sunny", "Rainy", "Foggy", "Stormy", "Blizzard"]

# Blizzard's weight only applies while it's Winter (see _reroll_weather).
const WEATHER_WEIGHTS := {
	"Sunny": 40.0,
	"Rainy": 25.0,
	"Foggy": 20.0,
	"Stormy": 12.0,
	"Blizzard": 3.0,
}

const WEATHER_LUCK_BONUS := {
	"Sunny": 0.0,
	"Rainy": 0.05,
	"Foggy": 0.05,
	"Stormy": 0.15,
	"Blizzard": 0.25,
}
const WEATHER_SPEED_BONUS := {
	"Sunny": 0.0,
	"Rainy": 0.0,
	"Foggy": -0.05,
	"Stormy": -0.15,
	"Blizzard": -0.20,
}

const SEASON_LUCK_BONUS := {
	"Spring": 0.10,
	"Summer": 0.0,
	"Autumn": 0.0,
	"Winter": 0.15,
}
const SEASON_SPEED_BONUS := {
	"Spring": 0.0,
	"Summer": 0.10,
	"Autumn": 0.0,
	"Winter": -0.10,
}
const SEASON_POWER_BONUS := {
	"Spring": 0.0,
	"Summer": 0.0,
	"Autumn": 0.10,
	"Winter": 0.0,
}

var elapsed_time: float = 0.0
var _current_weather: String = WEATHER_TYPES[0]
var _weather_timer: float = 0.0

func _ready() -> void:
	_reroll_weather()

func load_state(new_elapsed_time: float) -> void:
	elapsed_time = new_elapsed_time

func _process(delta: float) -> void:
	elapsed_time += delta
	_weather_timer += delta
	if _weather_timer >= WEATHER_CHANGE_INTERVAL:
		_weather_timer = 0.0
		_reroll_weather()

func _reroll_weather() -> void:
	var weights := WEATHER_WEIGHTS.duplicate()
	if get_season_name() != "Winter":
		weights["Blizzard"] = 0.0
	_current_weather = _weighted_pick(weights)
	if _current_weather == "Blizzard":
		print("A blizzard rolls in!")

func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for key in weights.keys():
		cumulative += weights[key]
		if roll <= cumulative:
			return key
	return WEATHER_TYPES[0]

func get_weather() -> String:
	return _current_weather

func get_weather_luck_bonus() -> float:
	return WEATHER_LUCK_BONUS[_current_weather]

func get_weather_speed_bonus() -> float:
	return WEATHER_SPEED_BONUS[_current_weather]

func get_season_luck_bonus() -> float:
	return SEASON_LUCK_BONUS[get_season_name()]

func get_season_speed_bonus() -> float:
	return SEASON_SPEED_BONUS[get_season_name()]

func get_season_power_bonus() -> float:
	return SEASON_POWER_BONUS[get_season_name()]

func get_day_progress() -> float:
	return fmod(elapsed_time, DAY_NIGHT_CYCLE_DURATION) / DAY_NIGHT_CYCLE_DURATION

func get_clock_hour() -> float:
	return get_day_progress() * 24.0

func get_day_number() -> int:
	return int(elapsed_time / DAY_NIGHT_CYCLE_DURATION) + 1

## 1.0 at midnight, 0.0 at noon, smoothly interpolated through dawn/dusk.
func get_night_factor() -> float:
	return (cos(get_day_progress() * TAU) + 1.0) / 2.0

func get_clock_text() -> String:
	var hour := get_clock_hour()
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]

func get_season_progress() -> float:
	var year_duration := SEASON_DURATION * SEASON_NAMES.size()
	return fmod(elapsed_time, year_duration) / year_duration

func get_season_index() -> int:
	return int(get_season_progress() * SEASON_NAMES.size())

func get_season_name() -> String:
	return SEASON_NAMES[get_season_index()]
