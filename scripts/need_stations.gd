extends Node

## Where the three needs get serviced, plus the shared storage point.
##
## Positions used to be constants. They are player-movable now (right-click
## a station to pick it up), so they live as vars, persist through the save
## and announce changes via stations_moved. The DEFAULT_* constants below
## are still the one place the starting layout is written down.

signal stations_moved

## y=84 sits just below the HUD's nav row so these markers aren't hidden
## behind the UI; x starts past the storage shed so nothing overlaps.
const DEFAULT_GRILL_POSITION := Vector2(120.0, 84.0)
const DEFAULT_BEER_POSITION := Vector2(170.0, 84.0)
const DEFAULT_BENCH_ORIGIN := Vector2(220.0, 84.0)
## The single shared point every catch is carried to, whichever row the
## fisherman fishes from.
const DEFAULT_STORAGE_POSITION := Vector2(80.0, 90.0)
## Social need: a phone on a pole to call home from alone, and a shared
## patch of ground where two fishermen who happen to be there at the same
## time end up talking to each other.
const DEFAULT_PHONE_POSITION := Vector2(120.0, 120.0)
const DEFAULT_GATHERING_POSITION := Vector2(180.0, 120.0)

const BENCH_SPACING := 20.0
## Wrap into a new row after this many, so a heavily-upgraded bench count
## doesn't march off into the sand/water instead of staying on open land.
const BENCH_PER_ROW := 3
const BENCH_ROW_SPACING := 14.0

## Footprints are what placement validates against, so they need to match
## what station.gd actually draws.
const FOOTPRINTS := {
	"grill": Vector2(14.0, 12.0),
	"beer": Vector2(16.0, 16.0),
	"storage": Vector2(22.0, 18.0),
	"phone": Vector2(8.0, 20.0),
	"gathering": Vector2(40.0, 14.0),
}
const BENCH_FOOTPRINT := Vector2(16.0, 6.0)

var grill_position := DEFAULT_GRILL_POSITION
var beer_position := DEFAULT_BEER_POSITION
var bench_origin := DEFAULT_BENCH_ORIGIN
var storage_position := DEFAULT_STORAGE_POSITION
var phone_position := DEFAULT_PHONE_POSITION
var gathering_position := DEFAULT_GATHERING_POSITION

## slot index -> true while a fisherman is occupying it.
var _claimed: Dictionary = {}

func bench_positions() -> Array:
	var count := MetaProgress.get_bench_capacity()
	var result: Array = []
	for i in range(count):
		var col := i % BENCH_PER_ROW
		var row := i / BENCH_PER_ROW
		result.append(bench_origin + Vector2(col * BENCH_SPACING, row * BENCH_ROW_SPACING))
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

## Current world position for a need, so a fisherman already walking can
## re-resolve its target after a station moves instead of finishing a trip
## to where the station used to be. Bench slots keep their index across a
## move, so a claim stays valid.
## `slot_index` covers both the bench pool and the gathering spot's
## standing spots; -1 means the caller holds no slot, which for "social"
## means they went to the phone instead.
func position_for_need(need: String, slot_index: int = -1):
	match need:
		"hunger":
			return grill_position
		"thirst":
			return beer_position
		"rest":
			var positions := bench_positions()
			if slot_index >= 0 and slot_index < positions.size():
				return positions[slot_index]
			return null
		"social":
			if slot_index < 0:
				return phone_position
			var spots := SocialHub.gathering_positions()
			if slot_index < spots.size():
				return spots[slot_index]
			return null
	return null

func get_station_position(id: String) -> Vector2:
	match id:
		"grill":
			return grill_position
		"beer":
			return beer_position
		"benches":
			return bench_origin
		"storage":
			return storage_position
		"phone":
			return phone_position
		"gathering":
			return gathering_position
	return Vector2.ZERO

## The whole bench cluster moves as one object, so its footprint spans
## every plank the current capacity lays out rather than a single seat.
func footprint_size(id: String) -> Vector2:
	if id != "benches":
		return FOOTPRINTS.get(id, Vector2(12.0, 12.0))
	var count := maxi(1, MetaProgress.get_bench_capacity())
	var cols := mini(count, BENCH_PER_ROW)
	var rows := int(ceil(float(count) / float(BENCH_PER_ROW)))
	return Vector2(
		(cols - 1) * BENCH_SPACING + BENCH_FOOTPRINT.x,
		(rows - 1) * BENCH_ROW_SPACING + BENCH_FOOTPRINT.y
	)

## Footprint centred on where the station would sit at `position`. The
## bench cluster grows right and down from its origin rather than around
## it, so its centre is offset.
func footprint_at(id: String, position: Vector2) -> Rect2:
	var size := footprint_size(id)
	if id == "benches":
		return Rect2(position - BENCH_FOOTPRINT / 2.0, size)
	return Rect2(position - size / 2.0, size)

func move_station(id: String, position: Vector2) -> void:
	var snapped := WorldLayout.snap(position)
	match id:
		"grill":
			grill_position = snapped
		"beer":
			beer_position = snapped
		"benches":
			bench_origin = snapped
		"storage":
			storage_position = snapped
		"phone":
			phone_position = snapped
		"gathering":
			gathering_position = snapped
		_:
			return
	stations_moved.emit()

func save_state() -> Dictionary:
	return {
		"grill": [grill_position.x, grill_position.y],
		"beer": [beer_position.x, beer_position.y],
		"benches": [bench_origin.x, bench_origin.y],
		"storage": [storage_position.x, storage_position.y],
		"phone": [phone_position.x, phone_position.y],
		"gathering": [gathering_position.x, gathering_position.y],
	}

## Must run after MetaProgress.load_state(): the bench footprint depends
## on the purchased bench capacity, and clamping uses that footprint.
func load_state(data: Dictionary) -> void:
	grill_position = _read(data, "grill", DEFAULT_GRILL_POSITION)
	beer_position = _read(data, "beer", DEFAULT_BEER_POSITION)
	bench_origin = _read(data, "benches", DEFAULT_BENCH_ORIGIN)
	storage_position = _read(data, "storage", DEFAULT_STORAGE_POSITION)
	phone_position = _read(data, "phone", DEFAULT_PHONE_POSITION)
	gathering_position = _read(data, "gathering", DEFAULT_GATHERING_POSITION)
	for id in ["grill", "beer", "benches", "storage", "phone", "gathering"]:
		var clamped := WorldLayout.clamp_position(get_station_position(id), footprint_size(id))
		match id:
			"grill":
				grill_position = clamped
			"beer":
				beer_position = clamped
			"benches":
				bench_origin = clamped
			"storage":
				storage_position = clamped
			"phone":
				phone_position = clamped
			"gathering":
				gathering_position = clamped
	stations_moved.emit()

func _read(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw = data.get(key)
	if raw is Array and raw.size() == 2:
		return WorldLayout.snap(Vector2(float(raw[0]), float(raw[1])))
	return fallback
