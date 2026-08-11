class_name PixelArt
extends RefCounted

## Draws readable pixel maps onto Control/Node2D canvases.
##
## The UI icons used to be built from draw_circle/draw_colored_polygon,
## which produce anti-aliased shapes that sit between pixels -- fine on
## their own, obviously wrong next to a bitmap font and square panels. A
## map drawn as whole-pixel rects lands on the grid every time.
##
## Maps use the same '.' = empty convention as the sprite generators in
## tools/, so a shape can be moved between the two by copy-paste.

## Splits a pattern literal into rows, dropping blank lines so a map can
## be written with the opening triple-quote on its own line.
static func parse(pattern: String) -> Array:
	var rows: Array = []
	for line in pattern.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed != "":
			rows.append(trimmed)
	return rows

## Pixel dimensions of a parsed map, before any scale is applied.
static func map_size(rows: Array) -> Vector2:
	var widest := 0
	for row in rows:
		widest = maxi(widest, (row as String).length())
	return Vector2(widest, rows.size())

## `palette` maps a map character to a Color; characters missing from it
## (conventionally '.') are left transparent.
static func draw_map(canvas: CanvasItem, rows: Array, palette: Dictionary, scale: float = 1.0, origin: Vector2 = Vector2.ZERO) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row[x]
			if not palette.has(key):
				continue
			canvas.draw_rect(
				Rect2(origin + Vector2(x, y) * scale, Vector2(scale, scale)),
				palette[key]
			)
