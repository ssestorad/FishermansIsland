extends Node2D

signal clicked(fisherman: Node2D)

@export var home_position: Vector2 = Vector2(100, 250)
@export var dock_position: Vector2 = Vector2(450, 200)
@export var move_speed: float = 80.0
@export var min_catch_time: float = 2.0
@export var max_catch_time: float = 5.0
@export var min_rest_time: float = 1.0
@export var max_rest_time: float = 3.0
@export var dock_wander_range: float = 14.0
@export var home_wander_range: float = 14.0
@export var dock_y_bounds: Vector2 = Vector2(105.0, 295.0)

const MAX_SPEED_REDUCTION := 0.6
const XP_PER_LEVEL := 10.0
const LEVEL_CAP := 10.0
const XP_PER_CATCH := 2.0

enum State { WALK_TO_DOCK, FISHING, WALK_HOME, RESTING }

var display_name: String = ""
var state: State = State.WALK_TO_DOCK
var wait_timer: float = 0.0
var current_target: Vector2
var current_catch_duration: float = 0.0

var speed_xp: float = 0.0
var luck_xp: float = 0.0
var power_xp: float = 0.0
var is_hovered: bool = false

var equipped_items: Dictionary = {
	"Rod": null,
	"Hat": null,
	"Outfit": null,
	"Charm": null,
	"Bait": null,
}

@onready var click_area: Area2D = $ClickArea

func _ready() -> void:
	if display_name.is_empty():
		display_name = NameGenerator.random_name()
	position = home_position
	current_target = _random_dock_point()
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	queue_redraw()

func _process(delta: float) -> void:
	match state:
		State.WALK_TO_DOCK:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0:
				state = State.FISHING
				current_catch_duration = _rolled_catch_time()
				wait_timer = current_catch_duration
		State.FISHING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				_resolve_catch()
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
	queue_redraw()

func _resolve_catch() -> void:
	var caught_rarity := FishRarity.roll(get_effective_stat(luck_xp, "luck"))
	var caught_species := FishCatalog.roll_species(caught_rarity)
	var caught_weight := FishRarity.roll_weight(caught_rarity, get_effective_stat(power_xp, "power"))
	Economy.add_currency_for_catch(caught_rarity, caught_weight)
	Album.record_catch(caught_species, caught_weight)
	print("%s caught a %s (%s, %.1f kg)! [Spd %d / Lck %d / Pwr %d]" % [
		display_name, caught_species.species_name, FishRarity.name_for(caught_rarity), caught_weight,
		get_level(speed_xp), get_level(luck_xp), get_level(power_xp)
	])

	var speed_range := _catch_time_range()
	var normalized_speed := 1.0 - inverse_lerp(speed_range.x, speed_range.y, current_catch_duration)
	var normalized_luck := float(caught_rarity) / float(FishRarity.Tier.size() - 1)
	var weight_range: Vector2 = FishRarity.WEIGHT_RANGES[caught_rarity]
	var normalized_power := inverse_lerp(weight_range.x, weight_range.y, caught_weight)

	speed_xp += normalized_speed * XP_PER_CATCH
	luck_xp += normalized_luck * XP_PER_CATCH
	power_xp += normalized_power * XP_PER_CATCH

func _move_toward(target: Vector2, delta: float) -> void:
	var direction: Vector2 = (target - position).normalized()
	position += direction * move_speed * delta

func _random_dock_point() -> Vector2:
	var y := clampf(dock_position.y + randf_range(-dock_wander_range, dock_wander_range), dock_y_bounds.x, dock_y_bounds.y)
	return Vector2(dock_position.x, y)

func _random_home_point() -> Vector2:
	return home_position + Vector2(randf_range(-home_wander_range, home_wander_range), randf_range(-home_wander_range, home_wander_range))

func _catch_time_range() -> Vector2:
	var reduction := get_effective_stat(speed_xp, "speed") * MAX_SPEED_REDUCTION
	return Vector2(min_catch_time * (1.0 - reduction), max_catch_time * (1.0 - reduction))

func _rolled_catch_time() -> float:
	var r := _catch_time_range()
	return randf_range(r.x, r.y)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_mouse_entered() -> void:
	is_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	queue_redraw()

func get_level_fraction(xp: float) -> float:
	return clampf(get_level(xp) / LEVEL_CAP, 0.0, 1.0)

func get_level(xp: float) -> int:
	return int(xp / XP_PER_LEVEL)

func get_equipment_bonus(axis: String) -> float:
	var total := 0.0
	for item in equipped_items.values():
		if item != null and item.axis == axis:
			total += item.bonus
	return total

func get_effective_stat(xp: float, axis: String) -> float:
	var environment_bonus := 0.0
	match axis:
		"luck":
			environment_bonus = WorldClock.get_weather_luck_bonus() + WorldClock.get_season_luck_bonus()
		"speed":
			environment_bonus = WorldClock.get_weather_speed_bonus() + WorldClock.get_season_speed_bonus()
		"power":
			environment_bonus = WorldClock.get_season_power_bonus()
	return clampf(get_level_fraction(xp) + get_equipment_bonus(axis) + environment_bonus, 0.0, 1.0)

func equip_item(item) -> void:
	equipped_items[item.slot] = item

func get_stats_text() -> String:
	return "Spd %d / Lck %d / Pwr %d" % [get_level(speed_xp), get_level(luck_xp), get_level(power_xp)]

func get_slot_display(slot_name: String) -> String:
	var item = equipped_items.get(slot_name)
	return item.item_name if item != null else "—"

func _draw() -> void:
	draw_rect(Rect2(-5, 0, 4, 9), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(1, 0, 4, 9), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(-6, -8, 12, 10), Color(0.85, 0.55, 0.2))
	draw_circle(Vector2(0, -12), 5, Color(0.92, 0.75, 0.6))
	if state == State.FISHING:
		draw_line(Vector2(4, -6), Vector2(15, 4), Color(0.35, 0.25, 0.15), 1.5)
	if is_hovered:
		draw_rect(Rect2(-9, -18, 18, 28), Color.WHITE, false, 2.0)
