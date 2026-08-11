extends Node

## Shared world positions for the three fisherman needs. Grill and Beer are
## fixed, uncapped points — fishermen already visually overlap at the dock
## via wander jitter today, so simultaneous use isn't a problem worth
## solving. Benches are the one capacity-limited station (the meta-shop
## upgrade is specifically "more benches"), so they get real slot tracking.

## The single shared point every fisherman's catch gets carried to,
## regardless of which row they fish from — previously each fisherman
## walked to their own per-row home_position, so the drawn shed marker
## (near the top of the home-lane column) only matched what the first row
## actually walked to. main.gd's shed marker is drawn centered on this
## same constant so the two can't drift apart again.
const STORAGE_POSITION := Vector2(80.0, 90.0)

## y=84 sits just below the HUD's nav row (which runs to y=70) so these
## markers aren't hidden behind the UI; x starts past the storage shed
## marker near the home lane column (x=70-90) so nothing overlaps.
const GRILL_POSITION := Vector2(120.0, 84.0)
const BEER_POSITION := Vector2(170.0, 84.0)
const BENCH_BASE_POSITION := Vector2(220.0, 84.0)
const BENCH_SPACING := 20.0
## Wrap into a new row after this many, so a heavily-upgraded bench count
## doesn't march off into the sand/water instead of staying on open land.
const BENCH_PER_ROW := 3
const BENCH_ROW_SPACING := 14.0

## slot index -> true while a fisherman is occupying it.
var _claimed: Dictionary = {}

func bench_positions() -> Array:
	var count := MetaProgress.get_bench_capacity()
	var result: Array = []
	for i in range(count):
		var col := i % BENCH_PER_ROW
		var row := i / BENCH_PER_ROW
		result.append(BENCH_BASE_POSITION + Vector2(col * BENCH_SPACING, row * BENCH_ROW_SPACING))
	return result

## Claims the first free bench slot. Returns {"index": int, "position":
## Vector2} on success, or {} if every current slot (per
## MetaProgress.get_bench_capacity()) is occupied.
func claim_bench() -> Dictionary:
	var positions := bench_positions()
	for i in range(positions.size()):
		if not _claimed.get(i, false):
			_claimed[i] = true
			return {"index": i, "position": positions[i]}
	return {}

func release_bench(index: int) -> void:
	_claimed.erase(index)
