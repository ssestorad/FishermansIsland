class_name FishingSpots
extends RefCounted

## The three places a fisherman can cast from, and which slice of the
## fish catalog each one reaches.
##
## The habitat split is not arbitrary: the 120-species catalog was already
## authored with this progression baked in. Reedbeds/Harbour top out at
## Rare, while The Deep and Sunken Ruins contain no Common or Uncommon
## species at all, so grouping habitats by depth produces a clean rarity
## curve without retuning a single species.
##
##   pond      30 species, Common..Epic
##   pier      49 species, Common..Legendary (+1 Secret)
##   offshore  41 species, Rare..Mythic      (+5 Secret)
##
## Everything casts eastward so the right-facing fishing pose always
## applies (see Fisherman._process on entering FISHING).

const POND := "pond"
const PIER := "pier"
const OFFSHORE := "offshore"

const SPOTS := {
	POND: {
		"name": "Pond",
		"habitats": ["Reedbeds", "River Bend"],
		# Stands on the bank west of the pond, casting east across it. The
		# line leaves the sprite at local x=7, so this has to be close
		# enough that it lands past POND_RECT's left edge (x=56) rather
		# than on the grass beside it.
		"cast_x": 52.0,
		"lane_bounds": Vector2(258.0, 326.0),
		"blurb": "Calm and shallow. Nothing rare, nothing dangerous.",
	},
	PIER: {
		"name": "Pier",
		"habitats": ["Harbour", "Kelp Forest", "Coral Shallows"],
		"cast_x": 320.0,
		"lane_bounds": Vector2(105.0, 295.0),
		"blurb": "The open coast. A broad mix, up to the occasional legend.",
	},
	OFFSHORE: {
		"name": "Offshore",
		"habitats": ["Open Water", "Storm Front", "Ice Shelf", "The Deep", "Sunken Ruins"],
		"cast_x": 440.0,
		"lane_bounds": Vector2(186.0, 194.0),
		"blurb": "Deep water. Every catch is Rare or better.",
		# Fishermen walk in straight lines, so without a waypoint at the
		# landward end of the jetty they cut the corner and stroll across
		# open sea to reach it.
		"approach": Vector2(330.0, 190.0),
	},
}

## Order matters: it drives the profile panel's cycle button and the
## meta-shop rows, and it reads as the intended progression.
const ORDER := [POND, PIER, OFFSHORE]

static func get_spot(id: String) -> Dictionary:
	return SPOTS.get(id, SPOTS[POND])

static func display_name(id: String) -> String:
	return get_spot(id).name

static func habitats(id: String) -> Array:
	return get_spot(id).habitats

## Where a fisherman assigned to `id` casts from.
##
## The row is *wrapped* into the spot's usable span rather than clamped:
## the home rows run y=110..320, so clamping piled everyone whose row sat
## outside a spot's span onto its first pixel — the pond had six
## fishermen standing on the same spot. Wrapping spreads them along the
## bank instead.
static func cast_position(id: String, lane_y: float) -> Vector2:
	var spot := get_spot(id)
	var bounds: Vector2 = spot.lane_bounds
	var span: float = bounds.y - bounds.x
	if span <= 0.0:
		return Vector2(spot.cast_x, bounds.x)
	return Vector2(spot.cast_x, bounds.x + fposmod(lane_y - bounds.x, span))

static func lane_bounds(id: String) -> Vector2:
	return get_spot(id).lane_bounds

## Point that must be crossed both on the way out and on the way back, or
## null for spots reachable in a straight line over land.
static func approach_point(id: String):
	return get_spot(id).get("approach")

## The pond is always available; the other two are meta-shop purchases.
static func is_unlocked(id: String) -> bool:
	if id == POND:
		return true
	return MetaProgress.is_spot_unlocked(id)

static func unlocked_ids() -> Array:
	var result: Array = []
	for id in ORDER:
		if is_unlocked(id):
			result.append(id)
	return result
