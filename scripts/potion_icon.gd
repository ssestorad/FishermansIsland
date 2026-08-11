extends Control

@export var axis: String = "speed"

## o = outline, c = cork, : = glass, l = liquid (tinted per axis)
const MAP := """
......oooo......
......occo......
......occo......
......o::o......
.....oo::oo.....
.....o::::o.....
....o::::::o....
...o::::::::o...
...o:llllll:o...
..o:llllllll:o..
..o:llllllll:o..
..o:llllllll:o..
..o:llllllll:o..
..o:llllllll:o..
...oo::::::oo...
....oooooooo....
"""

const LIQUID_COLORS := {
	"speed": Color(0.35, 0.55, 0.85),
	"luck": Color(0.45, 0.75, 0.4),
	"power": Color(0.85, 0.45, 0.3),
}

const OUTLINE_COLOR := Color(0.25, 0.22, 0.18)
const CORK_COLOR := Color(0.5, 0.35, 0.2)
const GLASS_COLOR := Color(0.85, 0.9, 0.92, 0.75)

var _rows: Array = []

func _ready() -> void:
	_rows = PixelArt.parse(MAP)
	custom_minimum_size = PixelArt.map_size(_rows)

func _draw() -> void:
	var palette := {
		"o": OUTLINE_COLOR,
		"c": CORK_COLOR,
		":": GLASS_COLOR,
		"l": LIQUID_COLORS.get(axis, Color(0.7, 0.7, 0.7)),
	}
	PixelArt.draw_map(self, _rows, palette)
