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

## Species mastery: rewards *repeat* catches of an already-discovered
## species, not just the first one (which is all caught_counts otherwise
## pays off, via the Album checklist). Deliberately derived from
## caught_counts rather than a second persisted counter — every catch
## already increments it, so mastery just reads it grouped by habitat
## instead of tracking anything new.
const MASTERY_THRESHOLDS := [10, 25, 50]
## +15%/level pick-weight bias, well under Bait's own habitat_bias values
## (1.6x-3.4x in gear_families.gd) — mastery is meant to nudge, not replace
## choosing the right bait for a habitat.
const MASTERY_BIAS_PER_LEVEL := 0.15

func get_habitat_catch_count(habitat: String) -> int:
	var total := 0
	for species in FishCatalog.species_for_habitat(habitat):
		total += caught_counts.get(species.species_name, 0)
	return total

func get_habitat_mastery_level(habitat: String) -> int:
	var count := get_habitat_catch_count(habitat)
	var level := 0
	for threshold in MASTERY_THRESHOLDS:
		if count >= threshold:
			level += 1
	return level

## Pick-weight multiplier for FishCatalog.roll_species()'s `bias` param —
## 1.0 at level 0, so a caller can skip merging it in when unmastered.
func get_habitat_mastery_bias(habitat: String) -> float:
	return 1.0 + get_habitat_mastery_level(habitat) * MASTERY_BIAS_PER_LEVEL

func load_state(new_caught_counts: Dictionary, new_best_weights: Dictionary, new_record_holders: Dictionary = {}) -> void:
	caught_counts = new_caught_counts
	best_weights = new_best_weights
	record_holders = new_record_holders
	updated.emit()
