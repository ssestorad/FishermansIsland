class_name FishSpecies
extends RefCounted

var species_name: String
var tier: FishRarity.Tier
var required_weather: String
var required_season: String

## null = no time-of-day requirement, true = night only, false = day only.
## Untyped so it can hold either a bool or null.
var required_night = null

func _init(p_name: String, p_tier: FishRarity.Tier, p_required_weather: String = "", p_required_season: String = "", p_required_night = null) -> void:
	species_name = p_name
	tier = p_tier
	required_weather = p_required_weather
	required_season = p_required_season
	required_night = p_required_night

func condition_text() -> String:
	var parts: Array = []
	if required_season != "":
		parts.append(required_season)
	if required_weather != "":
		parts.append(required_weather)
	if required_night == true:
		parts.append("Night")
	elif required_night == false:
		parts.append("Day")
	if parts.is_empty():
		return "Any weather, any season"
	return " + ".join(parts) + " only"

func conditions_met(current_weather: String, current_season: String, is_night: bool) -> bool:
	if required_weather != "" and required_weather != current_weather:
		return false
	if required_season != "" and required_season != current_season:
		return false
	if required_night != null and required_night != is_night:
		return false
	return true
