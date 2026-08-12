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

## Inland pond, the starting fishing spot. Sits low and left of the lane
## fishermen walk from storage to the pier, so they don't tramp through it.
const POND_RECT := Rect2(56.0, 250.0, 116.0, 84.0)
const POND_COLOR := Color(0.26, 0.48, 0.6)
const POND_SHALLOW_COLOR := Color(0.34, 0.57, 0.68)

## Jetty out into deep water — the offshore spot. Only drawn once bought,
## so the meta-shop purchase visibly builds something.
const JETTY_RECT := Rect2(327.0, 180.0, 130.0, 20.0)
const JETTY_COLOR := Color(0.46, 0.32, 0.18)
const JETTY_PLANK_COLOR := Color(0.38, 0.26, 0.14)

## Brackish estuary — the River Mouth spot. Sits in the gap between the
## pond (ends x=172) and the sand/pier strip (starts x=280), which was
## plain undrawn land until now — a literal as well as thematic bridge
## between the freshwater pond and the coastal pier. Only drawn once
## bought, same as the jetty.
const RIVER_MOUTH_RECT := Rect2(180.0, 260.0, 90.0, 60.0)
const RIVER_MOUTH_COLOR := Color(0.32, 0.52, 0.58)
const RIVER_MOUTH_SHALLOW_COLOR := Color(0.4, 0.6, 0.62)

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
	if footprint.intersects(POND_RECT):
		return false
	if footprint.intersects(RIVER_MOUTH_RECT):
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
