extends Node2D

signal clicked(fisherman: Node2D)
signal stats_changed

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
## Levels are spread across 20 (was 10) so leveling one axis to cap takes
## twice as long at the same per-catch XP rate — a fully-leveled fisherman
## is a longer-term milestone, and each level along the way is a smaller,
## more gradual step.
const LEVEL_CAP := 20.0
const XP_PER_CATCH := 2.0
const WALK_ANIM_FPS := 6.0

## Base chance per catch to land a Secret-tier fish instead, checked only
## when a Secret species' weather/season/night combo is currently met.
## Scales up with the fisherman's Luck stat, same as get_effective_stat().
const SECRET_CATCH_BASE_CHANCE := 0.05

## One pre-baked sheet per look (shirt/hair/beard/hat combo), laid out as
## a 3x3 grid of 16x24 frames: columns are stand/walk-A/walk-B, rows are
## the facing direction (see DIRECTION_ROWS). A new fisherman picks a
## sheet at random instead of recoloring a shared texture at runtime.
## Regenerate them with tools/generate_fisherman_sprites.py.
const APPEARANCE_VARIANTS := [
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

## Sheet row per facing. "left" reuses the right-facing row mirrored with
## flip_h, so only three directions need art.
const DIRECTION_ROWS := {"down": 0, "right": 1, "left": 1, "up": 2}

## Column order the walk cycle steps through: contact pose, passing pose,
## opposite contact, passing again.
const WALK_FRAME_SEQUENCE := [1, 0, 2, 0]
const STAND_FRAME := 0

enum State { WALK_TO_DOCK, FISHING, WALK_HOME, RESTING }

var display_name: String = ""
var state: State = State.WALK_TO_DOCK
var wait_timer: float = 0.0
var current_target: Vector2
var current_catch_duration: float = 0.0

var speed_xp: float = 0.0
var luck_xp: float = 0.0
var power_xp: float = 0.0
## Fourth stat axis: reduces rest time, same additive+leveled treatment as
## the other three via get_effective_stat(). Gains XP from every completed
## catch cycle regardless of what was caught — endurance is built by simply
## staying out fishing, not by catch quality the way the other axes are.
var endurance_xp: float = 0.0
var is_hovered: bool = false
var _walk_anim_timer: float = 0.0
var _walk_frame: int = 0

var appearance_variant: int = -1

## "left"/"right"/"up"/"down", updated every move step from the direction
## vector and mapped to a sheet row through DIRECTION_ROWS.
var facing: String = "down"

var equipped_items: Dictionary = {
	"Rod": null,
	"Hat": null,
	"Outfit": null,
	"Charm": null,
	"Bait": null,
}

## Perk names rolled at hire time (1-2), looked up in PerkCatalog. Fixed
## for the fisherman's lifetime — never re-rolled or changed after hire.
var perks: Array = []

## Lifetime catch count (uncapped) and a bounded recent-catches log for
## display. total_catches keeps counting past CATCH_HISTORY_CAP even once
## the log itself starts dropping the oldest entries.
const CATCH_HISTORY_CAP := 50
var total_catches: int = 0
var catch_history: Array = []  # [{species, tier, weight, day}, ...] oldest first

@onready var click_area: Area2D = $ClickArea
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if display_name.is_empty():
		display_name = NameGenerator.random_name()
	if appearance_variant < 0:
		appearance_variant = randi() % APPEARANCE_VARIANTS.size()
	position = home_position
	current_target = _random_dock_point()
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	sprite.texture = APPEARANCE_VARIANTS[appearance_variant]
	_apply_sprite_frame(STAND_FRAME)
	queue_redraw()

func set_appearance_variant(variant: int) -> void:
	if variant >= 0 and variant < APPEARANCE_VARIANTS.size():
		appearance_variant = variant

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
				if randf() < get_equipment_bonus("skip_rest_chance"):
					current_target = _random_dock_point()
					state = State.WALK_TO_DOCK
				else:
					state = State.RESTING
					# Resting is the one idle pose that isn't aimed at the
					# water, so turn to face the camera while standing around.
					facing = "down"
					var rest_reduction := clampf(get_effective_stat(endurance_xp, "endurance") + get_equipment_bonus("rest_time") + get_perk_bonus("rest_time"), 0.0, 0.9)
					wait_timer = randf_range(min_rest_time, max_rest_time) * (1.0 - rest_reduction)
		State.RESTING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				current_target = _random_dock_point()
				state = State.WALK_TO_DOCK
	_update_sprite_animation(delta)
	queue_redraw()

func _update_sprite_animation(delta: float) -> void:
	var moving := state == State.WALK_TO_DOCK or state == State.WALK_HOME
	if moving:
		_walk_anim_timer += delta
		if _walk_anim_timer >= 1.0 / WALK_ANIM_FPS:
			_walk_anim_timer = 0.0
			_walk_frame = (_walk_frame + 1) % WALK_FRAME_SEQUENCE.size()
		_apply_sprite_frame(WALK_FRAME_SEQUENCE[_walk_frame])
	else:
		_walk_frame = 0
		_walk_anim_timer = 0.0
		_apply_sprite_frame(STAND_FRAME)

## Points the sprite at one cell of the appearance sheet: `column` picks
## the pose, the current facing picks the row.
func _apply_sprite_frame(column: int) -> void:
	sprite.flip_h = facing == "left"
	sprite.frame_coords = Vector2i(column, DIRECTION_ROWS[facing])

func _resolve_catch() -> void:
	var result := _roll_and_apply_catch(current_catch_duration)
	print("%s caught a %s (%s, %.1f kg)! [Spd %d / Lck %d / Pwr %d / End %d]" % [
		display_name, result.species.species_name, FishRarity.name_for(result.rarity), result.weight,
		get_level(speed_xp), get_level(luck_xp), get_level(power_xp), get_level(endurance_xp)
	])

## Rolls and applies one catch (currency, album, XP). `catch_duration` feeds
## the speed-XP shaping; pass -1 (default) to have one rolled on the spot,
## which is what offline batch catches do since they skip the real timer.
## `forced_rarity` skips the luck roll and the Secret check entirely (used
## by the dev console).
func _roll_and_apply_catch(catch_duration: float = -1.0, forced_rarity: int = -1) -> Dictionary:
	if catch_duration < 0.0:
		catch_duration = _rolled_catch_time()
	var caught_rarity: FishRarity.Tier
	var caught_species: FishSpecies = null
	if forced_rarity >= 0:
		caught_rarity = forced_rarity
	else:
		# Secret catches sit outside the normal Luck roll: they only become
		# possible when a hidden species' weather/season/time-of-day combo
		# is currently in effect, and even then only a small independent
		# chance actually lands one instead of a normal-tier catch.
		var secret_species := FishCatalog.roll_species(FishRarity.Tier.SECRET)
		var secret_chance := SECRET_CATCH_BASE_CHANCE * (1.0 + get_effective_stat(luck_xp, "luck"))
		if secret_species != null and randf() < secret_chance:
			caught_rarity = FishRarity.Tier.SECRET
			caught_species = secret_species
		else:
			caught_rarity = FishRarity.roll(get_effective_stat(luck_xp, "luck"))
			if caught_rarity < FishRarity.Tier.RARE and get_equipment_bonus("guarantee_rare") > 0.0:
				caught_rarity = FishRarity.Tier.RARE
	if caught_species == null:
		# Every species of a tier can be condition-locked at once as the
		# catalog grows, so step down tiers rather than failing the catch.
		var tier: int = caught_rarity
		while caught_species == null and tier >= 0:
			caught_species = FishCatalog.roll_species(tier)
			if caught_species != null:
				caught_rarity = tier
			tier -= 1
	var caught_weight := caught_species.roll_weight(get_effective_stat(power_xp, "power"))

	# Common/Uncommon auto-sell for Coins on the spot, same as always. Rare+
	# no longer auto-sells for Scales — it lands in the dock so the player
	# can choose to sell it or keep it.
	var currency := ""
	var amount := 0
	var docked := false
	if caught_rarity in Economy.COIN_TIERS:
		var coin_bonus := get_equipment_bonus("coin_gain") + MetaProgress.get_global_coin_gain_bonus()
		var earned := Economy.add_currency_for_catch(caught_rarity, caught_weight, coin_bonus, get_equipment_bonus("scale_gain"), caught_species.species_name)
		currency = earned.currency
		amount = earned.amount
	else:
		DockInventory.add_catch(caught_species, caught_weight, caught_rarity)
		docked = true
	Album.record_catch(caught_species, caught_weight, display_name)

	var speed_range := _catch_time_range()
	var normalized_speed := 1.0 - inverse_lerp(speed_range.x, speed_range.y, catch_duration)
	var normalized_luck := float(caught_rarity) / float(FishRarity.MAX_ROLLABLE_TIER)
	var weight_range: Vector2 = caught_species.weight_range
	var normalized_power := inverse_lerp(weight_range.x, weight_range.y, caught_weight)

	var xp_multiplier := 1.0 + get_equipment_bonus("xp_gain")
	speed_xp += normalized_speed * XP_PER_CATCH * xp_multiplier
	luck_xp += normalized_luck * XP_PER_CATCH * xp_multiplier
	power_xp += normalized_power * XP_PER_CATCH * xp_multiplier
	# Flat, not tied to any catch trait — endurance comes from having worked
	# the cycle at all, not from what was caught.
	endurance_xp += XP_PER_CATCH * xp_multiplier

	total_catches += 1
	catch_history.append({
		"species": caught_species.species_name,
		"tier": caught_rarity,
		"weight": caught_weight,
		"day": WorldClock.get_day_number(),
	})
	if catch_history.size() > CATCH_HISTORY_CAP:
		catch_history.pop_front()

	stats_changed.emit()

	return {
		"species": caught_species,
		"rarity": caught_rarity,
		"weight": caught_weight,
		"currency": currency,
		"amount": amount,
		"docked": docked,
	}

## Dev-console hook: forces a catch of the given rarity (skips the luck
## roll) through the normal currency/album/XP pipeline. Returns {} if no
## species is currently eligible for that rarity (e.g. a weather-gated tier).
func debug_force_catch(tier: FishRarity.Tier) -> Dictionary:
	if FishCatalog.roll_species(tier) == null:
		return {}
	return _roll_and_apply_catch(-1.0, tier)

## Simulates `duration` seconds of offline fishing without moving the
## fisherman: estimates how many walk/catch/rest cycles would have fit and
## rolls that many catches on the spot. Returns aggregate totals for the
## "while you were away" summary.
func resolve_offline_catches(duration: float) -> Dictionary:
	var summary := {"catches": 0, "coins": 0, "docked": 0, "best_species": "", "best_rarity": FishRarity.Tier.COMMON, "best_weight": 0.0}
	if duration <= 0.0:
		return summary
	var cycle_time := _estimate_cycle_time()
	if cycle_time <= 0.0:
		return summary
	var cycles_f := duration / cycle_time
	var cycles := int(cycles_f)
	if randf() < fmod(cycles_f, 1.0):
		cycles += 1
	for i in range(cycles):
		var result := _roll_and_apply_catch()
		summary.catches += 1
		if result.docked:
			summary.docked += 1
		elif result.currency == "Coins":
			summary.coins += result.amount
		if summary.catches == 1 or result.rarity > summary.best_rarity or (result.rarity == summary.best_rarity and result.weight > summary.best_weight):
			summary.best_species = result.species.species_name
			summary.best_rarity = result.rarity
			summary.best_weight = result.weight
	return summary

## Average time for one full walk-to-dock/catch/walk-home/rest cycle, used
## to estimate how many catches fit in an offline duration.
func _estimate_cycle_time() -> float:
	var catch_range := _catch_time_range()
	var avg_catch := (catch_range.x + catch_range.y) / 2.0
	var rest_reduction := clampf(get_effective_stat(endurance_xp, "endurance") + get_equipment_bonus("rest_time") + get_perk_bonus("rest_time"), 0.0, 0.9)
	var skip_rest_chance := clampf(get_equipment_bonus("skip_rest_chance"), 0.0, 1.0)
	var avg_rest := (min_rest_time + max_rest_time) / 2.0 * (1.0 - rest_reduction) * (1.0 - skip_rest_chance)
	var effective_speed := move_speed * (1.0 + get_equipment_bonus("walk_speed") + get_perk_bonus("walk_speed"))
	if effective_speed <= 0.0:
		return avg_catch + avg_rest
	var round_trip_distance := absf(dock_position.x - home_position.x) * 2.0
	var avg_walk := round_trip_distance / effective_speed
	return avg_catch + avg_rest + avg_walk

func _move_toward(target: Vector2, delta: float) -> void:
	var direction: Vector2 = (target - position).normalized()
	_update_facing(direction)
	var effective_speed := move_speed * (1.0 + get_equipment_bonus("walk_speed") + get_perk_bonus("walk_speed"))
	position += direction * effective_speed * delta

func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) >= absf(direction.y):
		facing = "right" if direction.x >= 0.0 else "left"
	else:
		facing = "down" if direction.y >= 0.0 else "up"

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

func get_level_progress(xp: float) -> float:
	if get_level(xp) >= LEVEL_CAP:
		return 1.0
	return fmod(xp, XP_PER_LEVEL) / XP_PER_LEVEL

func get_equipment_bonus(axis: String) -> float:
	var total := 0.0
	for item in equipped_items.values():
		if item != null:
			total += item.get_bonus(axis)
	return total

## Multi-piece set bonuses (e.g. 2x "Storm Chaser" pieces equipped). Only the
## highest piece-count threshold met applies, not every threshold stacked.
func get_set_bonus(axis: String) -> float:
	var set_counts: Dictionary = {}
	for item in equipped_items.values():
		if item != null and item.set_name != "":
			set_counts[item.set_name] = set_counts.get(item.set_name, 0) + 1
	var total := 0.0
	for set_name in set_counts:
		var count: int = set_counts[set_name]
		var thresholds: Dictionary = ShopCatalog.SET_BONUSES.get(set_name, {})
		var best_threshold := 0
		for threshold in thresholds:
			if count >= threshold and threshold > best_threshold:
				best_threshold = threshold
		if best_threshold > 0:
			for effect in thresholds[best_threshold]:
				if effect[0] == axis:
					total += effect[1]
	return total

func get_perk_bonus(axis: String) -> float:
	var total := 0.0
	for perk_name in perks:
		var perk := PerkCatalog.find(perk_name)
		if perk.is_empty() or not _perk_condition_met(perk.get("condition", {})):
			continue
		for effect in perk.effects:
			if effect[0] == axis:
				total += effect[1]
	return total

func _perk_condition_met(condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
	if condition.has("weather") and WorldClock.get_weather() != condition["weather"]:
		return false
	if condition.has("season") and WorldClock.get_season_name() != condition["season"]:
		return false
	if condition.has("night") and WorldClock.get_night_factor() < 0.5:
		return false
	return true

func get_perk_description(perk_name: String) -> String:
	var perk := PerkCatalog.find(perk_name)
	return perk.get("description", "") if not perk.is_empty() else ""

## Below max level (10) alone contributes, capped so a fully-leveled axis with
## no gear at all can't get anywhere near the ceiling — gear, perks and
## environment need to carry the rest, for the whole game, not just early on.
const LEVEL_STAT_WEIGHT := 0.55

## Hard ceiling on the value FishRarity.roll()/roll_weight() ever see. Strictly
## below 1.0: at exactly 1.0 those two skew formulas stop being probabilistic
## and collapse onto a single guaranteed outcome (see their docs) — a maxed
## Luck/Power fisherman should still roll, not always land Mythic-at-max-weight.
const EFFECTIVE_STAT_CEILING := 0.95

func get_effective_stat(xp: float, axis: String) -> float:
	var environment_bonus := 0.0
	match axis:
		"luck":
			environment_bonus = WorldClock.get_weather_luck_bonus() + WorldClock.get_season_luck_bonus() + MetaProgress.get_global_luck_bonus()
		"speed":
			environment_bonus = WorldClock.get_weather_speed_bonus() + WorldClock.get_season_speed_bonus()
		"power":
			environment_bonus = WorldClock.get_season_power_bonus()
	environment_bonus += PotionManager.get_bonus(axis)
	environment_bonus += get_perk_bonus(axis)
	environment_bonus += get_set_bonus(axis)
	var raw := get_level_fraction(xp) * LEVEL_STAT_WEIGHT + get_equipment_bonus(axis) + environment_bonus
	return clampf(raw, 0.0, EFFECTIVE_STAT_CEILING)

func equip_item(item) -> void:
	equipped_items[item.slot] = item

func get_stats_text() -> String:
	return "Spd %d / Lck %d / Pwr %d / End %d" % [get_level(speed_xp), get_level(luck_xp), get_level(power_xp), get_level(endurance_xp)]

func get_slot_display(slot_name: String) -> String:
	var item = equipped_items.get(slot_name)
	return item.item_name if item != null else "—"

func get_recent_catches_text(count: int = 5) -> String:
	if catch_history.is_empty():
		return "No catches yet."
	var lines: Array = []
	var start := maxi(0, catch_history.size() - count)
	for i in range(catch_history.size() - 1, start - 1, -1):
		var entry: Dictionary = catch_history[i]
		lines.append("Day %d: %s (%s, %.1f kg)" % [entry.day, entry.species, FishRarity.name_for(entry.tier), entry.weight])
	return "\n".join(lines)

func _draw() -> void:
	if state == State.FISHING:
		draw_line(Vector2(6, -10), Vector2(17, -2), Color(0.35, 0.25, 0.15), 1.5)
	if is_hovered:
		draw_rect(Rect2(-9, -26, 18, 28), Color.WHITE, false, 2.0)
