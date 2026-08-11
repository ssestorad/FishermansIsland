extends Control

## o = rim, : = gold face, s = shine
const MAP := """
....oooo....
..oo::::oo..
.o::::::::o.
.o::ss::::o.
o::ss::::::o
o::::::::::o
o::::::::::o
o::::::::::o
.o::::::::o.
.o::::::::o.
..oo::::oo..
....oooo....
"""

const PALETTE := {
	"o": Color(0.55, 0.4, 0.08),
	":": Color(0.95, 0.78, 0.25),
	"s": Color(1.0, 0.93, 0.62),
}

var _rows: Array = []

func _ready() -> void:
	_rows = PixelArt.parse(MAP)
	custom_minimum_size = PixelArt.map_size(_rows)

func _draw() -> void:
	PixelArt.draw_map(self, _rows, PALETTE)
