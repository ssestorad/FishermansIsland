extends Node

signal updated

## The dock is a small "manage it before it fills up" space, not an
## archive — capping it keeps the Dock panel's row count (and the save
## file) sane even after a long offline session floods it with catches.
## Upgradable via the meta-shop's Dock Capacity row.
const BASE_CAPACITY := 60

func capacity() -> int:
	return BASE_CAPACITY + MetaProgress.get_dock_capacity_bonus()

# Each entry: {species_name: String, tier: FishRarity.Tier, weight: float}
var entries: Array = []

## Adds a catch to the dock, or — if it's full — auto-sells it for Scales
## on the spot as an overflow safety valve so nothing is silently lost.
func add_catch(species: FishSpecies, weight: float, tier: FishRarity.Tier) -> void:
	if entries.size() >= capacity():
		Economy.add_currency_for_catch(tier, weight, 0.0, 0.0, species.species_name)
		updated.emit()
		return
	entries.append({"species_name": species.species_name, "tier": tier, "weight": weight})
	updated.emit()

## Sells one entry for Scales (via the same rarity/weight formula a live
## catch uses) and returns the amount gained.
func sell(index: int) -> int:
	if index < 0 or index >= entries.size():
		return 0
	var entry: Dictionary = entries[index]
	entries.remove_at(index)
	var earned := Economy.add_currency_for_catch(entry.tier, entry.weight, 0.0, 0.0, entry.species_name)
	updated.emit()
	return earned.amount

func sell_all() -> int:
	var total := 0
	for entry in entries:
		total += Economy.add_currency_for_catch(entry.tier, entry.weight, 0.0, 0.0, entry.species_name).amount
	entries.clear()
	updated.emit()
	return total

## Restores saved entries, keeping only the most recent capacity() and
## auto-selling any older overflow — handles saves from before the cap
## existed (or a dock that grew past it) without losing that value.
func load_state(data: Array) -> void:
	var parsed: Array = []
	for raw in data:
		if raw is Dictionary and raw.has("species_name") and raw.has("tier") and raw.has("weight"):
			parsed.append({
				"species_name": raw.species_name,
				"tier": int(raw.tier),
				"weight": float(raw.weight),
			})
	var cap := capacity()
	if parsed.size() > cap:
		var overflow: Array = parsed.slice(0, parsed.size() - cap)
		parsed = parsed.slice(parsed.size() - cap, parsed.size())
		for entry in overflow:
			Economy.add_currency_for_catch(entry.tier, entry.weight, 0.0, 0.0, entry.species_name)
	entries = parsed
	updated.emit()
