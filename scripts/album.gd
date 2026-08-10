extends Node

signal updated

var caught_counts: Dictionary = {}
var best_weights: Dictionary = {}

func record_catch(species: FishSpecies, weight: float) -> void:
	var key: String = species.species_name
	caught_counts[key] = caught_counts.get(key, 0) + 1
	if weight > best_weights.get(key, 0.0):
		best_weights[key] = weight
	updated.emit()

func is_discovered(species_name: String) -> bool:
	return caught_counts.get(species_name, 0) > 0
