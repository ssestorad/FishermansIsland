extends Node

signal updated

var items: Array = []

func add_item(item: Item) -> void:
	items.append(item)
	updated.emit()

func remove_item(item: Item) -> void:
	items.erase(item)
	updated.emit()

func items_for_slot(slot: String) -> Array:
	var result: Array = []
	for item in items:
		if item.slot == slot:
			result.append(item)
	return result

func load_state(item_names: Array) -> void:
	items.clear()
	for item_name in item_names:
		if item_name is String:
			var item := SaveManager.find_item_by_name(item_name)
			if item != null:
				items.append(item)
	updated.emit()
