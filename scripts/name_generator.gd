class_name NameGenerator
extends RefCounted

const FIRST_NAMES := [
	"Tom", "Jack", "Sam", "Finn", "Mack", "Gus", "Walt", "Reed",
	"Cliff", "Hank", "Silas", "Otis", "Dale", "Wade", "Cole", "Abel",
]

const LAST_NAMES := [
	"Harbor", "Fischer", "Salt", "Tide", "Netley", "Piers", "Cod",
	"Hookman", "Marsh", "Byrne", "Finch", "Waters", "Cove", "Reel",
]

static func random_name() -> String:
	return "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
