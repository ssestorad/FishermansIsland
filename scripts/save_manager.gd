extends Node

const SAVE_PATH := "user://savegame.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(fishermen: Array) -> void:
	var fishermen_data: Array = []
	for fisherman in fishermen:
		fishermen_data.append(_serialize_fisherman(fisherman))

	var data := {
		"coins": Economy.coins,
		"scales": Economy.scales,
		"elapsed_time": WorldClock.elapsed_time,
		"album": {
			"caught_counts": Album.caught_counts,
			"best_weights": Album.best_weights,
		},
		"fishermen": fishermen_data,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing")
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_data() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _serialize_fisherman(fisherman: Node) -> Dictionary:
	var equipped := {}
	for slot in fisherman.equipped_items:
		var item = fisherman.equipped_items[slot]
		equipped[slot] = item.item_name if item != null else null
	return {
		"display_name": fisherman.display_name,
		"speed_xp": fisherman.speed_xp,
		"luck_xp": fisherman.luck_xp,
		"power_xp": fisherman.power_xp,
		"equipped_items": equipped,
	}

## Items are looked up by name from the live catalog rather than
## serialized in full, so the save stays valid if item balance changes.
func find_item_by_name(item_name: String) -> Item:
	for item in ShopCatalog.all_items():
		if item.item_name == item_name:
			return item
	return null
