class_name FishermanFactory
extends RefCounted

## Parses a save dict (or rolls a fresh hire) into a configured Fisherman
## node. Deliberately does NOT add it to the tree or touch main.gd's own
## bookkeeping (fishermen array, clicked signal) — those steps are
## order-sensitive (add_child() must run before set_fishing_spot() so
## _ready() has already fired) and stay with the caller.

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")
const ROW_SPACING := 35.0
## Per-fisherman rows are laid out top-to-bottom starting at y=110; without
## a ceiling this runs straight off the 360px-tall world once the roster
## grows past ~7 (extra_slots is uncapped, so that's routine, not an edge
## case). Rows beyond this clamp stack on the last one instead of walking
## fishermen off-screen — visually crowded at a big roster, but never
## invisible.
const MAX_HOME_ROW_Y := 320.0

static func build(index: int, saved_data: Dictionary = {}) -> Node:
	var fisherman := FISHERMAN_SCENE.instantiate()
	fisherman.name = "Fisherman_%d" % (index + 1)
	var row_y := minf(110.0 + index * ROW_SPACING, MAX_HOME_ROW_Y)
	fisherman.home_position = Vector2(80, row_y)
	fisherman.lane_y = row_y
	# dock_position follows from the spot; the caller applies the saved
	# assignment (if any) via set_fishing_spot() after add_child().

	if not saved_data.is_empty():
		fisherman.display_name = saved_data.get("display_name", "")
		fisherman.speed_xp = float(saved_data.get("speed_xp", 0.0))
		fisherman.luck_xp = float(saved_data.get("luck_xp", 0.0))
		fisherman.power_xp = float(saved_data.get("power_xp", 0.0))
		fisherman.endurance_xp = float(saved_data.get("endurance_xp", 0.0))
		fisherman.perks = saved_data.get("perks", [])
		fisherman.total_catches = int(saved_data.get("total_catches", 0))
		var raw_history: Array = saved_data.get("catch_history", [])
		var loaded_history: Array = []
		for raw in raw_history:
			if raw is Dictionary and raw.has("species") and raw.has("tier") and raw.has("weight") and raw.has("day"):
				loaded_history.append({
					"species": raw.species,
					"tier": int(raw.tier),
					"weight": float(raw.weight),
					"day": int(raw.day),
				})
		fisherman.catch_history = loaded_history
		fisherman.best_catch_tier = int(saved_data.get("best_catch_tier", 0))
		fisherman.is_favorite = bool(saved_data.get("is_favorite", false))
		# Saves from before fishing spots existed have everyone at the
		# pier, which is where they all used to stand.
		fisherman.fishing_spot = str(saved_data.get("fishing_spot", FishingSpots.PIER))
		var equipped: Dictionary = saved_data.get("equipped_items", {})
		for slot in equipped:
			var item_name = equipped[slot]
			if item_name is String:
				var item := SaveManager.find_item_by_name(item_name)
				if item != null:
					fisherman.equipped_items[slot] = item
		if saved_data.has("appearance_variant"):
			fisherman.set_appearance_variant(int(saved_data.get("appearance_variant")))
	else:
		var perk_count_range := Vector2i(2, 3) if MetaProgress.has_extra_perk_slot() else Vector2i(1, 2)
		fisherman.perks = PerkCatalog.roll_perk_names(randi_range(perk_count_range.x, perk_count_range.y))

	return fisherman
