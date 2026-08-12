class_name FishermanFactory
extends RefCounted

## Parses a save dict (or rolls a fresh hire) into a configured Fisherman
## node. Deliberately does NOT add it to the tree or touch main.gd's own
## bookkeeping (fishermen array, clicked signal) — those steps are
## order-sensitive (add_child() must run before set_fishing_spot() so
## _ready() has already fired) and stay with the caller.

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")

## Duplicates Fisherman.APPEARANCE_VARIANTS so a portrait/candidate can be
## built without a live Fisherman instance to read it off — fisherman.gd
## has no class_name, so it can't be referenced statically from here. Same
## accepted duplication precedent as fish_icon.gd's own COLUMNS/ROWS copy
## of the sprite generator's grid; keep this list's size in lockstep with
## the one in fisherman.gd if new appearances are ever added.
const APPEARANCE_TEXTURES := [
	preload("res://assets/sprites/fisherman/v0.png"),
	preload("res://assets/sprites/fisherman/v1.png"),
	preload("res://assets/sprites/fisherman/v2.png"),
	preload("res://assets/sprites/fisherman/v3.png"),
	preload("res://assets/sprites/fisherman/v4.png"),
	preload("res://assets/sprites/fisherman/v5.png"),
	preload("res://assets/sprites/fisherman/v6.png"),
	preload("res://assets/sprites/fisherman/v7.png"),
	preload("res://assets/sprites/fisherman/v8.png"),
	preload("res://assets/sprites/fisherman/v9.png"),
]
const APPEARANCE_VARIANT_COUNT := 10
## Stand pose, facing down — the top-left 16x24 cell of every sheet
## (STAND_FRAME=0, DIRECTION_ROWS["down"]=0 in fisherman.gd).
const PORTRAIT_REGION := Rect2(0.0, 0.0, 16.0, 24.0)

const ROW_SPACING := 35.0
## Per-fisherman rows are laid out top-to-bottom starting at y=110; without
## a ceiling this runs straight off the 360px-tall world once the roster
## grows past ~7 (extra_slots is uncapped, so that's routine, not an edge
## case). Rows beyond this clamp stack on the last one instead of walking
## fishermen off-screen — visually crowded at a big roster, but never
## invisible.
const MAX_HOME_ROW_Y := 320.0

static func build(index: int, saved_data: Dictionary = {}, candidate: Dictionary = {}) -> Node:
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
		# Saves predating the mood system load everyone at neutral. The
		# constant is read off the instance because fisherman.gd has no
		# class_name — same duck typing the rest of this function uses.
		fisherman.mood = float(saved_data.get("mood", fisherman.MOOD_NEUTRAL))
		# A save predating the social system has no id; leaving it at 0
		# makes _ready() mint a fresh one. Reserving a loaded id keeps the
		# counter ahead so a later hire can't be handed a duplicate.
		fisherman.fisherman_id = int(saved_data.get("fisherman_id", 0))
		# Saves predating this feature simply get no favorite weather — the
		# mood nudge just never applies rather than backfilling a guess.
		fisherman.favorite_weather = str(saved_data.get("favorite_weather", ""))
		if fisherman.fisherman_id > 0:
			SocialHub.reserve_id(fisherman.fisherman_id)
		var raw_conversations: Array = saved_data.get("conversations", [])
		var loaded_conversations: Array = []
		for raw in raw_conversations:
			if raw is Dictionary and raw.has("topic") and raw.has("day"):
				loaded_conversations.append({
					"with_name": str(raw.get("with_name", "")),
					"with_id": int(raw.get("with_id", 0)),
					"topic": str(raw.topic),
					"day": int(raw.day),
				})
		fisherman.conversations = loaded_conversations
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
	elif not candidate.is_empty():
		# A hire picked from roll_candidates() — every field below was
		# already rolled and shown to the player, so it's applied verbatim
		# rather than re-rolled (re-rolling here would hire something
		# different from what was actually chosen).
		fisherman.display_name = candidate.get("display_name", "")
		fisherman.perks = candidate.get("perks", [])
		fisherman.favorite_weather = candidate.get("favorite_weather", "")
		fisherman.set_appearance_variant(int(candidate.get("appearance_variant", -1)))
	else:
		var perk_count_range := Vector2i(2, 3) if MetaProgress.has_extra_perk_slot() else Vector2i(1, 2)
		fisherman.perks = PerkCatalog.roll_perk_names(randi_range(perk_count_range.x, perk_count_range.y))

	return fisherman

## Static thumbnail for a UI card — the stand/down cell out of whichever
## appearance sheet, rather than the live animated Sprite2D a walking
## Fisherman uses.
static func portrait_texture(appearance_variant: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = APPEARANCE_TEXTURES[clampi(appearance_variant, 0, APPEARANCE_TEXTURES.size() - 1)]
	atlas.region = PORTRAIT_REGION
	return atlas

## Rolls `count` hire candidates for the picker: distinct names (against
## both the existing roster and each other), distinct portraits (only
## APPEARANCE_VARIANT_COUNT exist, so a shuffled sample never repeats
## within one batch), a fresh perk roll each (same range a direct hire
## would get), and a favorite weather. None of this touches the scene tree
## — these are plain data dicts for FishermenPanelController/HirePanel to
## display, and whichever one gets chosen is later passed to build() as
## `candidate` unchanged.
static func roll_candidates(count: int, existing_names: Array) -> Array:
	var perk_count_range := Vector2i(2, 3) if MetaProgress.has_extra_perk_slot() else Vector2i(1, 2)
	var appearance_pool: Array = range(APPEARANCE_VARIANT_COUNT)
	appearance_pool.shuffle()
	var used_names: Array = existing_names.duplicate()
	var candidates: Array = []
	for i in range(count):
		var name := NameGenerator.random_name(used_names)
		used_names.append(name)
		candidates.append({
			"display_name": name,
			"appearance_variant": appearance_pool[i % appearance_pool.size()],
			"perks": PerkCatalog.roll_perk_names(randi_range(perk_count_range.x, perk_count_range.y)),
			"favorite_weather": WorldClock.WEATHER_TYPES.pick_random(),
		})
	return candidates
