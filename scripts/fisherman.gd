extends Node2D

@export var home_position: Vector2 = Vector2(100, 250)
@export var dock_position: Vector2 = Vector2(450, 200)
@export var move_speed: float = 80.0
@export var min_catch_time: float = 2.0
@export var max_catch_time: float = 5.0
@export var min_rest_time: float = 1.0
@export var max_rest_time: float = 3.0
@export_range(0.0, 1.0) var power: float = 0.0
@export var dock_wander_range: float = 14.0
@export var home_wander_range: float = 14.0
@export var dock_y_bounds: Vector2 = Vector2(105.0, 295.0)

enum State { WALK_TO_DOCK, FISHING, WALK_HOME, RESTING }

var state: State = State.WALK_TO_DOCK
var wait_timer: float = 0.0
var current_target: Vector2

func _ready() -> void:
	position = home_position
	current_target = _random_dock_point()
	queue_redraw()

func _process(delta: float) -> void:
	match state:
		State.WALK_TO_DOCK:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0:
				state = State.FISHING
				wait_timer = randf_range(min_catch_time, max_catch_time)
		State.FISHING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				var caught_rarity := FishRarity.roll()
				var caught_weight := FishRarity.roll_weight(caught_rarity, power)
				Economy.add_coins_for_catch(caught_rarity, caught_weight)
				print(name, " caught a ", FishRarity.name_for(caught_rarity), " fish (%.1f kg)!" % caught_weight)
				current_target = _random_home_point()
				state = State.WALK_HOME
		State.WALK_HOME:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0:
				state = State.RESTING
				wait_timer = randf_range(min_rest_time, max_rest_time)
		State.RESTING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				current_target = _random_dock_point()
				state = State.WALK_TO_DOCK

func _move_toward(target: Vector2, delta: float) -> void:
	var direction: Vector2 = (target - position).normalized()
	position += direction * move_speed * delta

func _random_dock_point() -> Vector2:
	var y := clampf(dock_position.y + randf_range(-dock_wander_range, dock_wander_range), dock_y_bounds.x, dock_y_bounds.y)
	return Vector2(dock_position.x, y)

func _random_home_point() -> Vector2:
	return home_position + Vector2(randf_range(-home_wander_range, home_wander_range), randf_range(-home_wander_range, home_wander_range))

func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color.ORANGE)
