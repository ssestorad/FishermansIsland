extends Node2D

@export var home_position: Vector2 = Vector2(100, 250)
@export var dock_position: Vector2 = Vector2(450, 200)
@export var move_speed: float = 80.0
@export var min_catch_time: float = 2.0
@export var max_catch_time: float = 5.0
@export var min_rest_time: float = 1.0
@export var max_rest_time: float = 3.0

enum State { WALK_TO_DOCK, FISHING, WALK_HOME, RESTING }

var state: State = State.WALK_TO_DOCK
var wait_timer: float = 0.0

func _ready() -> void:
	position = home_position
	queue_redraw()

func _process(delta: float) -> void:
	match state:
		State.WALK_TO_DOCK:
			_move_toward(dock_position, delta)
			if position.distance_to(dock_position) < 2.0:
				state = State.FISHING
				wait_timer = randf_range(min_catch_time, max_catch_time)
		State.FISHING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				var caught_rarity := FishRarity.roll()
				Economy.add_coins_for_catch(caught_rarity)
				print(name, " caught a ", FishRarity.name_for(caught_rarity), " fish!")
				state = State.WALK_HOME
		State.WALK_HOME:
			_move_toward(home_position, delta)
			if position.distance_to(home_position) < 2.0:
				state = State.RESTING
				wait_timer = randf_range(min_rest_time, max_rest_time)
		State.RESTING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				state = State.WALK_TO_DOCK

func _move_toward(target: Vector2, delta: float) -> void:
	var direction: Vector2 = (target - position).normalized()
	position += direction * move_speed * delta

func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color.ORANGE)
