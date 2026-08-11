class_name WorldLayout
extends RefCounted

## Single source of truth for the island's geometry.
##
## main.gd::_draw() paints from these and station placement validates
## against them, so the two can't drift apart. That drift is a mistake
## this project has already made once: the storage shed marker was drawn
## from its own literals while fishermen walked somewhere else entirely.

const WORLD_SIZE := Vector2(640.0, 360.0)

const LAND_COLOR := Color(0.55, 0.72, 0.38)
const SAND_RECT := Rect2(280.0, 80.0, 40.0, 240.0)
const SAND_COLOR := Color(0.82, 0.72, 0.5)
const WATER_RECT := Rect2(300.0, 100.0, 300.0, 200.0)
const WATER_COLOR := Color(0.22, 0.45, 0.65)
const WAVE_COLOR := Color(0.35, 0.58, 0.75, 0.5)
const PIER_RECT := Rect2(305.0, 95.0, 22.0, 210.0)
const PIER_COLOR := Color(0.5, 0.35, 0.2)

## The HUD is a CanvasLayer painted over the world, and its nav row runs
## to y=70 — anything placed above this is invisible in play no matter
## how correct it looks in the editor. The needs stations shipped at y=40
## once and were completely hidden until a rendered screenshot caught it.
const HUD_BOTTOM := 76.0

## Placement snaps to whole pixels in this step, which keeps the pixel art
## aligned and makes dropping a station forgiving of an imprecise cursor.
const PLACEMENT_GRID := 4.0

static func placement_bounds() -> Rect2:
	return Rect2(
		4.0,
		HUD_BOTTOM,
		WORLD_SIZE.x - 8.0,
		WORLD_SIZE.y - HUD_BOTTOM - 4.0
	)

static func snap(position: Vector2) -> Vector2:
	return Vector2(
		roundf(position.x / PLACEMENT_GRID) * PLACEMENT_GRID,
		roundf(position.y / PLACEMENT_GRID) * PLACEMENT_GRID
	)

## True when `footprint` sits fully on dry, visible land. Stations are
## land objects: the pier is the only thing that belongs over water, and
## it isn't movable.
static func is_placeable(footprint: Rect2) -> bool:
	if not placement_bounds().encloses(footprint):
		return false
	return not footprint.intersects(WATER_RECT)

## Keeps a footprint inside the world without trying to resolve a water
## overlap — placement rejects those outright instead. Used as a
## load-time safety net so a save written before a layout change (or by
## hand) can't strand a station off-screen.
static func clamp_position(position: Vector2, footprint_size: Vector2) -> Vector2:
	var bounds := placement_bounds()
	var half := footprint_size / 2.0
	return Vector2(
		clampf(position.x, bounds.position.x + half.x, bounds.end.x - half.x),
		clampf(position.y, bounds.position.y + half.y, bounds.end.y - half.y)
	)
