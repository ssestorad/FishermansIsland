extends Node2D

## One movable need station: the grill, the beer crate, the bench cluster
## or the storage shed.
##
## The art moved here from main.gd::_draw_need_stations() unchanged --
## these used to be plain draw calls on the world with no node behind
## them, which is exactly why they could not be hovered or clicked.
##
## This node stays deliberately dumb: it draws itself, reports hover, and
## asks to be picked up. main.gd owns the carry/placement state, so there
## is one place that knows what is currently in hand.

signal pickup_requested(station)

@export var station_id: String = "grill"

const HOVER_COLOR := Color(1.0, 0.98, 0.85, 0.9)
const VALID_COLOR := Color(0.5, 1.0, 0.5, 0.85)
const INVALID_COLOR := Color(1.0, 0.4, 0.35, 0.9)

var is_hovered: bool = false
## Set by main.gd while this station is following the cursor.
var is_carried: bool = false
var placement_valid: bool = true

@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

func _ready() -> void:
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	# The bench cluster's footprint grows with the purchased capacity, so
	# its hit box has to be rebuilt whenever that changes.
	MetaProgress.updated.connect(_refresh_hitbox)
	_refresh_hitbox()

func _refresh_hitbox() -> void:
	var footprint := NeedStations.footprint_at(station_id, Vector2.ZERO)
	var shape := RectangleShape2D.new()
	shape.size = footprint.size
	collision_shape.shape = shape
	collision_shape.position = footprint.position + footprint.size / 2.0
	queue_redraw()

func _draw() -> void:
	match station_id:
		"grill":
			_draw_grill()
		"beer":
			_draw_beer()
		"storage":
			_draw_storage()
		"benches":
			_draw_benches()
	if is_carried:
		_draw_outline(VALID_COLOR if placement_valid else INVALID_COLOR)
	elif is_hovered:
		_draw_outline(HOVER_COLOR)

func _draw_outline(color: Color) -> void:
	# 1px so the highlight stays on the pixel grid like everything else.
	draw_rect(NeedStations.footprint_at(station_id, Vector2.ZERO), color, false, 1.0)

## Dark base with a warm coal glow on top.
func _draw_grill() -> void:
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(-4, -6, 8, 4), Color(0.85, 0.4, 0.15))

## Wooden box with a couple of bottle caps peeking out.
func _draw_beer() -> void:
	draw_rect(Rect2(-7, -6, 14, 12), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(-4, -9, 3, 4), Color(0.75, 0.65, 0.2))
	draw_rect(Rect2(1, -9, 3, 4), Color(0.75, 0.65, 0.2))

func _draw_storage() -> void:
	draw_rect(Rect2(-8, -6, 16, 14), Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(-10, -10, 20, 6), Color(0.32, 0.22, 0.14))

## One plank per currently-available slot, so the drawn count always
## matches what the meta-shop upgrade actually grants. Planks are laid
## out relative to this node, which is the cluster origin.
func _draw_benches() -> void:
	for bench_pos in NeedStations.bench_positions():
		var offset: Vector2 = bench_pos - NeedStations.bench_origin
		draw_rect(Rect2(offset + Vector2(-7, -2), Vector2(14, 4)), Color(0.55, 0.4, 0.24))

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		pickup_requested.emit(self)

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()
