extends Control

## o = rim, : = scale face, s = shine
const MAP := """
.....oo.....
....o::o....
...o::::o...
..o::s:::o..
.o::s:::::o.
o::::::::::o
o::::::::::o
.o::::::::o.
..o::::::o..
...o::::o...
....o::o....
.....oo.....
"""

const PALETTE := {
	"o": Color(0.2, 0.45, 0.5),
	":": Color(0.45, 0.75, 0.8),
	"s": Color(0.75, 0.94, 0.96),
}

var _rows: Array = []

func _ready() -> void:
	_rows = PixelArt.parse(MAP)
	custom_minimum_size = PixelArt.map_size(_rows)

func _draw() -> void:
	PixelArt.draw_map(self, _rows, PALETTE)
