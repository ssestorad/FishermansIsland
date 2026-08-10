class_name FishSpecies
extends RefCounted

var species_name: String
var tier: FishRarity.Tier
var required_weather: String
var required_season: String

func _init(p_name: String, p_tier: FishRarity.Tier, p_required_weather: String = "", p_required_season: String = "") -> void:
	species_name = p_name
	tier = p_tier
	required_weather = p_required_weather
	required_season = p_required_season
