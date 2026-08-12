class_name StationCarryController
extends Node2D

## Owns the four world stations (storage/grill/beer/benches) and the
## pickup/drag/drop/cancel flow: right-click a station to pick it up, the
## next click drops it, Escape puts it back. Self-contained — no
## dependency on fishermen, panels, or save data beyond NeedStations.

const STATION_SCENE := preload("res://scenes/entities/Station.tscn")
const STATION_IDS := ["storage", "grill", "beer", "benches", "phone", "gathering"]

## Station currently stuck to the cursor, or null.
var _carried_station: Node = null
var _carried_origin := Vector2.ZERO
var _stations: Array = []

func spawn_stations() -> void:
	for id in STATION_IDS:
		var station := STATION_SCENE.instantiate()
		station.station_id = id
		station.position = NeedStations.get_station_position(id)
		station.pickup_requested.connect(_on_station_pickup_requested)
		add_child(station)
		_stations.append(station)
	# Covers both a station being dropped somewhere new and the bench
	# cluster's layout shifting when its capacity is upgraded.
	NeedStations.stations_moved.connect(_sync_station_positions)

func is_carrying() -> bool:
	return _carried_station != null

func _sync_station_positions() -> void:
	for station in _stations:
		if station != _carried_station:
			station.position = NeedStations.get_station_position(station.station_id)
		station.queue_redraw()

func _on_station_pickup_requested(station: Node) -> void:
	if _carried_station != null:
		return
	_carried_station = station
	_carried_origin = station.position
	station.is_carried = true
	_update_carried_station(get_global_mouse_position())

## Snaps the carried station to the placement grid and tells it whether
## the spot under the cursor is legal, which drives its green/red outline.
func _update_carried_station(mouse_position: Vector2) -> void:
	var snapped := WorldLayout.snap(mouse_position)
	_carried_station.position = snapped
	var footprint := NeedStations.footprint_at(_carried_station.station_id, snapped)
	_carried_station.placement_valid = WorldLayout.is_placeable(footprint)
	_carried_station.queue_redraw()

func _drop_carried_station() -> void:
	if not _carried_station.placement_valid:
		return
	var station := _carried_station
	_carried_station = null
	station.is_carried = false
	# move_station() re-snaps and emits stations_moved, which is what
	# nudges any fisherman already walking to re-target.
	NeedStations.move_station(station.station_id, station.position)

func _cancel_carried_station() -> void:
	var station := _carried_station
	_carried_station = null
	station.is_carried = false
	station.position = _carried_origin
	station.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _carried_station == null:
		return
	if event is InputEventMouseMotion:
		_update_carried_station(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_drop_carried_station()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_carried_station()
		get_viewport().set_input_as_handled()
