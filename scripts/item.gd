class_name Item
extends RefCounted

var item_name: String
var slot: String
var axis: String
var bonus: float
var cost: int

func _init(p_name: String, p_slot: String, p_axis: String, p_bonus: float, p_cost: int) -> void:
	item_name = p_name
	slot = p_slot
	axis = p_axis
	bonus = p_bonus
	cost = p_cost
