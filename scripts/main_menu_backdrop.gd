extends Control

## Procedural pixel-art backdrop for the main menu.
##
## Drawn rather than authored as a PNG for the same reason the world in
## main.gd is: every shape here is a whole-pixel rect, so it stays crisp
## at any window scale and costs nothing to retune. Everything is laid
## out against the 640x360 design viewport.

const DESIGN := Vector2(640.0, 360.0)
const HORIZON := 200.0

## Top-to-bottom sky bands. Banding rather than a smooth gradient is the
## point -- a real gradient would dither and fight the pixel look.
const SKY_BANDS := [
	[0.0, Color(0.13, 0.19, 0.38)],
	[44.0, Color(0.18, 0.27, 0.47)],
	[86.0, Color(0.27, 0.39, 0.57)],
	[124.0, Color(0.40, 0.52, 0.65)],
	[158.0, Color(0.58, 0.64, 0.68)],
	# Warm, but deliberately not sand-coloured: a tan band running the full
	# width right above the waterline reads as a beach rather than as haze.
	[180.0, Color(0.74, 0.72, 0.67)],
]

const SEA_BANDS := [
	[200.0, Color(0.17, 0.37, 0.50)],
	[232.0, Color(0.14, 0.31, 0.45)],
	[272.0, Color(0.11, 0.26, 0.39)],
	[320.0, Color(0.09, 0.21, 0.33)],
]

## Kept clear of the island (which is drawn later and would cover it) and
## clear of the centred title, so it sits over open sky on the left.
const SUN_CENTER := Vector2(154.0, 150.0)
const SUN_RADIUS := 17.0
const SUN_COLOR := Color(0.97, 0.83, 0.52)
const SUN_GLOW := Color(0.93, 0.76, 0.53, 0.28)

const ISLAND_CENTER_X := 452.0
const ISLAND_HALF_W := 118.0
const ISLAND_HEIGHT := 56.0
const ISLAND_COLOR := Color(0.20, 0.34, 0.24)
const ISLAND_SHADE := Color(0.15, 0.26, 0.19)
const SAND_COLOR := Color(0.78, 0.69, 0.47)

const DOCK_COLOR := Color(0.36, 0.25, 0.15)
const DOCK_PLANK := Color(0.45, 0.32, 0.19)

const WAVE_COLOR := Color(0.34, 0.55, 0.66, 0.5)
const BIRD_COLOR := Color(0.16, 0.18, 0.24, 0.75)

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	_draw_bands(SKY_BANDS, HORIZON)
	_draw_sun()
	_draw_bands(SEA_BANDS, DESIGN.y)
	_draw_island()
	_draw_waves()
	_draw_dock()
	_draw_birds()

## Fills from each band's start y to the next band's start (or `bottom`).
func _draw_bands(bands: Array, bottom: float) -> void:
	for i in range(bands.size()):
		var top: float = bands[i][0]
		var next: float = bands[i + 1][0] if i + 1 < bands.size() else bottom
		draw_rect(Rect2(0.0, top, DESIGN.x, next - top), bands[i][1])

## Filled circle built from whole-pixel horizontal spans, so the edge
## steps like pixel art instead of being anti-aliased like draw_circle.
func _draw_disc(center: Vector2, radius: float, color: Color) -> void:
	var r := int(round(radius))
	for offset in range(-r, r + 1):
		var half := int(round(sqrt(maxf(0.0, radius * radius - offset * offset))))
		if half <= 0:
			continue
		draw_rect(Rect2(center.x - half, center.y + offset, half * 2.0, 1.0), color)

func _draw_sun() -> void:
	_draw_disc(SUN_CENTER, SUN_RADIUS + 5.0, SUN_GLOW)
	_draw_disc(SUN_CENTER, SUN_RADIUS, SUN_COLOR)
	# Reflection on the water, fading as it runs toward the viewer.
	for i in range(7):
		var y := HORIZON + 6.0 + i * 9.0
		var half := 13.0 - i * 1.2
		draw_rect(
			Rect2(SUN_CENTER.x - half, y, half * 2.0, 3.0),
			Color(0.93, 0.78, 0.5, 0.3 - i * 0.035)
		)

func _draw_island() -> void:
	# Sand shelf first, so the hill sits on top of it at the waterline.
	draw_rect(
		Rect2(ISLAND_CENTER_X - ISLAND_HALF_W - 9.0, HORIZON - 4.0, (ISLAND_HALF_W + 9.0) * 2.0, 8.0),
		SAND_COLOR
	)
	var top := HORIZON - ISLAND_HEIGHT
	for y in range(int(top), int(HORIZON)):
		var t := (HORIZON - y) / ISLAND_HEIGHT  # 1 at the apex, 0 at the base
		var half := ISLAND_HALF_W * sqrt(maxf(0.0, 1.0 - t * t))
		if half <= 0.0:
			continue
		draw_rect(Rect2(ISLAND_CENTER_X - half, y, half * 2.0, 1.0), ISLAND_COLOR)
		# Right flank falls away from the sun, so shade it.
		draw_rect(Rect2(ISLAND_CENTER_X + half * 0.35, y, half * 0.65, 1.0), ISLAND_SHADE)
	_draw_tree(Vector2(ISLAND_CENTER_X - 46.0, HORIZON - 30.0), 1.0)
	_draw_tree(Vector2(ISLAND_CENTER_X + 6.0, HORIZON - 44.0), 1.2)
	_draw_tree(Vector2(ISLAND_CENTER_X + 54.0, HORIZON - 22.0), 0.85)

## Blocky conifer: trunk plus three stacked canopy tiers.
func _draw_tree(base: Vector2, scale: float) -> void:
	var trunk_w := roundf(3.0 * scale)
	var trunk_h := roundf(9.0 * scale)
	draw_rect(Rect2(base.x - trunk_w / 2.0, base.y, trunk_w, trunk_h), Color(0.29, 0.19, 0.12))
	var tiers := [
		[roundf(15.0 * scale), roundf(8.0 * scale)],
		[roundf(11.0 * scale), roundf(8.0 * scale)],
		[roundf(7.0 * scale), roundf(7.0 * scale)],
	]
	var y := base.y
	for tier in tiers:
		var w: float = tier[0]
		var h: float = tier[1]
		y -= h
		draw_rect(Rect2(base.x - w / 2.0, y, w, h), Color(0.16, 0.31, 0.21))
		draw_rect(Rect2(base.x - w / 2.0, y, w * 0.45, h), Color(0.21, 0.38, 0.25))

func _draw_waves() -> void:
	# Fixed offsets rather than randf() so the backdrop is identical every
	# time the menu is opened.
	const DASHES := [
		[38, 224, 14], [96, 238, 10], [150, 231, 16], [214, 246, 12],
		[26, 262, 18], [120, 272, 12], [196, 258, 15], [268, 279, 11],
		[60, 296, 20], [172, 306, 14], [286, 292, 16], [352, 268, 12],
		[402, 246, 10], [470, 288, 14], [540, 262, 12], [588, 302, 16],
		[330, 320, 18], [110, 332, 14], [430, 336, 12], [244, 226, 9],
	]
	for dash in DASHES:
		draw_rect(Rect2(dash[0], dash[1], dash[2], 2.0), WAVE_COLOR)

func _draw_dock() -> void:
	# Runs off the left edge toward the water, giving the eye somewhere to
	# stand and balancing the island on the right.
	draw_rect(Rect2(0.0, 236.0, 132.0, 9.0), DOCK_PLANK)
	draw_rect(Rect2(0.0, 245.0, 132.0, 3.0), DOCK_COLOR)
	for post_x in [22, 58, 94, 122]:
		draw_rect(Rect2(post_x, 248.0, 5.0, 26.0), DOCK_COLOR)

func _draw_birds() -> void:
	for bird in [[132, 74, 1.0], [152, 64, 0.8], [176, 82, 0.9]]:
		var x: float = bird[0]
		var y: float = bird[1]
		var s: float = bird[2]
		draw_rect(Rect2(x, y, 3.0 * s, 1.0), BIRD_COLOR)
		draw_rect(Rect2(x + 3.0 * s, y - 1.0, 2.0 * s, 1.0), BIRD_COLOR)
		draw_rect(Rect2(x + 5.0 * s, y, 3.0 * s, 1.0), BIRD_COLOR)
