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
		"saved_at": Time.get_unix_time_from_system(),
		"elapsed_time": WorldClock.elapsed_time,
		"album": {
			"caught_counts": Album.caught_counts,
			"best_weights": Album.best_weights,
			"record_holders": Album.record_holders,
		},
		"inventory": Inventory.items.map(func(item): return item.item_name),
		"dock": DockInventory.entries,
		"meta_progress": {
			"extra_slots": MetaProgress.extra_slots,
			"luck_level": MetaProgress.luck_level,
			"discount_level": MetaProgress.discount_level,
			"coin_gain_level": MetaProgress.coin_gain_level,
			"offline_efficiency_level": MetaProgress.offline_efficiency_level,
			"bench_capacity_level": MetaProgress.bench_capacity_level,
			"speed_level": MetaProgress.speed_level,
			"power_level": MetaProgress.power_level,
			"endurance_level": MetaProgress.endurance_level,
			"shop_rarity_level": MetaProgress.shop_rarity_level,
			"needs_service_level": MetaProgress.needs_service_level,
			"dock_capacity_level": MetaProgress.dock_capacity_level,
			"hire_discount_level": MetaProgress.hire_discount_level,
			"secret_chance_level": MetaProgress.secret_chance_level,
			"extra_perk_slot_unlocked": MetaProgress.extra_perk_slot_unlocked,
			"quest_slot_level": MetaProgress.quest_slot_level,
			"unlocked_spots": MetaProgress.unlocked_spots,
		},
		"stations": NeedStations.save_state(),
		"quests": QuestManager.save_state(),
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
		"endurance_xp": fisherman.endurance_xp,
		"equipped_items": equipped,
		"appearance_variant": fisherman.appearance_variant,
		"perks": fisherman.perks,
		"total_catches": fisherman.total_catches,
		"catch_history": fisherman.catch_history,
		"best_catch_tier": fisherman.best_catch_tier,
		"is_favorite": fisherman.is_favorite,
		"fishing_spot": fisherman.fishing_spot,
	}

## Items are looked up by name from the live catalog rather than
## serialized in full, so the save stays valid if item balance changes.
func find_item_by_name(item_name: String) -> Item:
	for item in ShopCatalog.all_items():
		if item.item_name == item_name:
			return item
	return null
