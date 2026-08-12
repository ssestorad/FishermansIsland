class_name NameGenerator
extends RefCounted

const FIRST_NAMES := [
	"Tom", "Jack", "Sam", "Finn", "Mack", "Gus", "Walt", "Reed",
	"Cliff", "Hank", "Silas", "Otis", "Dale", "Wade", "Cole", "Abel",
	"Roy", "Bart", "Nate", "Gil", "Cal", "Owen", "Miles", "Fitz",
	"Jonas", "Barney", "Emmett", "Roscoe", "Duke", "Angus", "Fergus", "Clem",
]

const LAST_NAMES := [
	"Harbor", "Fischer", "Salt", "Tide", "Netley", "Piers", "Cod",
	"Hookman", "Marsh", "Byrne", "Finch", "Waters", "Cove", "Reel",
	"Anchor", "Driftwood", "Weir", "Sound", "Bay", "Shoal", "Keel",
	"Halyard", "Barnacle", "Gull", "Sprat", "Weller", "Trawler", "Fathom",
]

const MAX_REROLL_ATTEMPTS := 20

## `exclude` lets a caller avoid handing out a name already in use (e.g. the
## current roster, or the rest of a just-rolled hiring batch). Retries a
## bounded number of times rather than filtering the full cross product —
## with 32x28 = 896 combinations against a 30-fisherman roster plus a
## handful of in-flight candidates, a collision on every attempt is not a
## realistic case; if it somehow happens, the last roll is used anyway
## rather than getting stuck.
static func random_name(exclude: Array = []) -> String:
	var name := "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
	var attempts := 0
	while name in exclude and attempts < MAX_REROLL_ATTEMPTS:
		name = "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
		attempts += 1
	return name
