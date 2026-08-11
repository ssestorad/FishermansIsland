extends Node

signal updated

var caught_counts: Dictionary = {}
var best_weights: Dictionary = {}
var record_holders: Dictionary = {}  # species_name -> fisherman display_name for the best_weights entry

func record_catch(species: FishSpecies, weight: float, caught_by: String = "") -> void:
	var key: String = species.species_name
	caught_counts[key] = caught_counts.get(key, 0) + 1
	if weight > best_weights.get(key, 0.0):
		best_weights[key] = weight
		if caught_by != "":
			record_holders[key] = caught_by
	updated.emit()

func is_discovered(species_name: String) -> bool:
	return caught_counts.get(species_name, 0) > 0

## True once any Secret-tier species has been caught. Shared by the Album
## panel (hides the Secret tab/rows until discovered) and the meta-shop
## (keeps the Secret Catch Chance upgrade hidden until it's relevant).
func has_caught_secret() -> bool:
	for species in FishCatalog.species_for_tier(FishRarity.Tier.SECRET):
		if is_discovered(species.species_name):
			return true
	return false

func get_record_holder(species_name: String) -> String:
	return record_holders.get(species_name, "")

func load_state(new_caught_counts: Dictionary, new_best_weights: Dictionary, new_record_holders: Dictionary = {}) -> void:
	caught_counts = new_caught_counts
	best_weights = new_best_weights
	record_holders = new_record_holders
	updated.emit()
