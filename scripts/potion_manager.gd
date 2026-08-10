extends Node

signal updated

const POTION_BONUS := 0.15
const DURATION := 60.0  # placeholder for testing; design target is 300s (5 min)

var _active_until: Dictionary = {"speed": 0.0, "luck": 0.0, "power": 0.0}

func activate(axis: String) -> void:
	_active_until[axis] = Time.get_ticks_msec() / 1000.0 + DURATION
	updated.emit()

func get_bonus(axis: String) -> float:
	return POTION_BONUS if is_active(axis) else 0.0

func get_remaining(axis: String) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(0.0, _active_until.get(axis, 0.0) - now)

func is_active(axis: String) -> bool:
	return get_remaining(axis) > 0.0
