class_name FishSpecies
extends RefCounted

var species_name: String
var tier: FishRarity.Tier

func _init(p_name: String, p_tier: FishRarity.Tier) -> void:
	species_name = p_name
	tier = p_tier
