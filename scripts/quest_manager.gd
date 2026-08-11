extends Node

## Global, continuously-refilled quest board. ACTIVE_QUEST_COUNT quests are
## active at once (plus any bought via the Quest Slot meta-upgrade, see
## _target_quest_count()); claiming one immediately generates a
## replacement, so the board never goes stale and never needs a
## daily/weekly reset timer.
##
## Quests are plain JSON-safe Dictionaries (see _generate_quest()) rather
## than a class, matching DockInventory.entries' existing precedent — no
## serialize/deserialize step is needed for save/load.

signal quests_updated

const ACTIVE_QUEST_COUNT := 3
const CATCH_COUNT_MIN := 10
const CATCH_COUNT_MAX := 30

## Reward tuning — starting points, not locked balance, same spirit as
## every other fresh-system constant in this project.
const CATCH_COUNT_COIN_PER_GOAL := 3
const CATCH_SPECIES_VALUE_MULTIPLIER := 2
const BUY_UPGRADE_REWARD_SCALES := 60

## Every MetaProgress upgrade a quest is allowed to target. Secret Catch
## Chance is excluded (hidden until a Secret fish is caught — a quest
## naming it would spoil the reveal) and the two fishing-spot unlocks are
## excluded (id-based, different shape from a leveled/one-time upgrade).
const UPGRADE_LABELS := {
	"luck": "Global Luck",
	"discount": "Shop Discount",
	"coin_gain": "Global Coin Gain",
	"offline_efficiency": "Offline Efficiency",
	"bench_capacity": "Folding Benches",
	"speed": "Global Speed",
	"power": "Global Power",
	"endurance": "Global Endurance",
	"shop_rarity": "Shop Rarity Odds",
	"needs_service": "Needs Service Time",
	"dock_capacity": "Dock Capacity",
	"hire_discount": "Hire Cost Discount",
	"extra_slots": "Extra Fisherman Slot",
	"extra_perk_slot": "Extra Perk Slot",
}

var active_quests: Array = []
var _next_id: int = 0

func _ready() -> void:
	MetaProgress.updated.connect(_on_meta_updated)
	if active_quests.is_empty():
		_refill()

## Called once per catch (fisherman.gd::_roll_and_apply_catch, right after
## Album.record_catch) — covers both live and offline-batch catches since
## both route through that one function.
func record_catch(species: FishSpecies, rarity: int) -> void:
	var changed := false
	for quest in active_quests:
		if quest.completed:
			continue
		match quest.type:
			"catch_count":
				quest.progress += 1
				changed = true
			"catch_species":
				if rarity == quest.tier and (quest.habitat == "" or species.habitat == quest.habitat):
					quest.progress += 1
					changed = true
		if quest.progress >= quest.goal:
			quest.completed = true
	if changed:
		quests_updated.emit()

func _on_meta_updated() -> void:
	var changed := false
	for quest in active_quests:
		if quest.completed or quest.type != "buy_upgrade":
			continue
		quest.progress = _upgrade_level(quest.upgrade_key)
		if quest.progress >= quest.goal:
			quest.completed = true
		changed = true
	# Buying the Quest Slot meta-upgrade grows the board immediately rather
	# than waiting for the next claim to notice there's room for more.
	var before_size := active_quests.size()
	_refill()
	if active_quests.size() != before_size:
		changed = true
	if changed:
		quests_updated.emit()

## Grants the reward and immediately generates a replacement quest so the
## board stays at ACTIVE_QUEST_COUNT. No-ops for an unknown id or a quest
## that isn't actually complete yet (defensive — the UI already disables
## the claim action until then).
func claim(quest_id: String) -> void:
	var idx := active_quests.find_custom(func(q): return q.id == quest_id)
	if idx == -1 or not active_quests[idx].completed:
		return
	var quest: Dictionary = active_quests[idx]
	if quest.reward_currency == "coins":
		Economy.add_coins(quest.reward_amount)
	else:
		Economy.add_scales(quest.reward_amount)
	active_quests.remove_at(idx)
	_refill()
	quests_updated.emit()

## Base board size plus whatever the Quest Slot meta-upgrade has bought —
## read live rather than cached, so a level bought mid-game takes effect
## immediately.
func _target_quest_count() -> int:
	return ACTIVE_QUEST_COUNT + MetaProgress.get_quest_slot_bonus()

func _refill() -> void:
	while active_quests.size() < _target_quest_count():
		active_quests.append(_generate_quest())

func _generate_quest() -> Dictionary:
	var eligible_upgrades := _eligible_upgrade_keys()
	var type_pool := ["catch_count", "catch_species"]
	if not eligible_upgrades.is_empty():
		type_pool.append("buy_upgrade")
	var type: String = type_pool[randi() % type_pool.size()]
	var quest: Dictionary
	match type:
		"catch_count":
			quest = _generate_catch_count_quest()
		"catch_species":
			quest = _generate_catch_species_quest()
		_:
			quest = _generate_buy_upgrade_quest(eligible_upgrades)
	quest.id = "q_%d" % _next_id
	_next_id += 1
	return quest

func _generate_catch_count_quest() -> Dictionary:
	var goal := randi_range(CATCH_COUNT_MIN, CATCH_COUNT_MAX)
	return {
		"type": "catch_count",
		"description": "Catch %d fish" % goal,
		"progress": 0,
		"goal": goal,
		"completed": false,
		"reward_currency": "coins",
		"reward_amount": goal * CATCH_COUNT_COIN_PER_GOAL,
	}

## Tier + habitat rather than one exact species name — many species are
## weather/season/night-gated, so pinning one could stall a quest for a
## long time through no fault of the player's. Habitat is sometimes left
## blank ("any") for a broader, easier variant.
func _generate_catch_species_quest() -> Dictionary:
	var tier: int = _weighted_normal_tier()
	var habitat := ""
	if randf() < 0.6:
		var pool := FishCatalog.species_for_tier(tier)
		var pick: FishSpecies = pool[randi() % pool.size()]
		habitat = pick.habitat
	var tier_name := FishRarity.name_for(tier)
	var description := "Catch a %s fish" % tier_name
	if habitat != "":
		description += " from %s" % habitat
	var currency := "coins" if tier in Economy.COIN_TIERS else "scales"
	var reward: int = Economy.RARITY_VALUES[tier] * CATCH_SPECIES_VALUE_MULTIPLIER
	return {
		"type": "catch_species",
		"description": description,
		"progress": 0,
		"goal": 1,
		"completed": false,
		"reward_currency": currency,
		"reward_amount": reward,
		"tier": tier,
		"habitat": habitat,
	}

func _generate_buy_upgrade_quest(eligible: Array) -> Dictionary:
	var key: String = eligible[randi() % eligible.size()]
	var current_level := _upgrade_level(key)
	return {
		"type": "buy_upgrade",
		"description": "Buy: %s" % UPGRADE_LABELS[key],
		"progress": current_level,
		"goal": current_level + 1,
		"completed": false,
		"reward_currency": "scales",
		"reward_amount": BUY_UPGRADE_REWARD_SCALES,
		"upgrade_key": key,
	}

## Weighted like FishRarity.WEIGHTS, restricted to NORMAL_TIERS so Secret
## is never a quest target (it isn't a normal Luck-roll outcome at all).
func _weighted_normal_tier() -> int:
	var total := 0.0
	for tier in FishRarity.NORMAL_TIERS:
		total += FishRarity.WEIGHTS[tier]
	var roll := randf() * total
	var cumulative := 0.0
	for tier in FishRarity.NORMAL_TIERS:
		cumulative += FishRarity.WEIGHTS[tier]
		if roll <= cumulative:
			return tier
	return FishRarity.NORMAL_TIERS[0]

func _eligible_upgrade_keys() -> Array:
	var result: Array = []
	for key in UPGRADE_LABELS:
		if not _is_maxed(key):
			result.append(key)
	return result

func _upgrade_level(key: String) -> int:
	match key:
		"luck": return MetaProgress.luck_level
		"discount": return MetaProgress.discount_level
		"coin_gain": return MetaProgress.coin_gain_level
		"offline_efficiency": return MetaProgress.offline_efficiency_level
		"bench_capacity": return MetaProgress.bench_capacity_level
		"speed": return MetaProgress.speed_level
		"power": return MetaProgress.power_level
		"endurance": return MetaProgress.endurance_level
		"shop_rarity": return MetaProgress.shop_rarity_level
		"needs_service": return MetaProgress.needs_service_level
		"dock_capacity": return MetaProgress.dock_capacity_level
		"hire_discount": return MetaProgress.hire_discount_level
		"extra_slots": return MetaProgress.extra_slots
		"extra_perk_slot": return 1 if MetaProgress.extra_perk_slot_unlocked else 0
		_: return 0

## Most upgrades only clamp the *bonus they produce*, not how many levels
## can be bought, so buying further never becomes invalid for them. Only
## these few have a real level/one-time ceiling worth checking, so a quest
## is never generated for something the player literally cannot complete.
func _is_maxed(key: String) -> bool:
	match key:
		"shop_rarity": return MetaProgress.shop_rarity_level >= MetaProgress.MAX_SHOP_RARITY_LEVEL
		"needs_service": return MetaProgress.needs_service_level >= MetaProgress.MAX_NEEDS_SERVICE_LEVEL
		"extra_slots": return MetaProgress.extra_slots >= MetaProgress.MAX_EXTRA_SLOTS
		"extra_perk_slot": return MetaProgress.extra_perk_slot_unlocked
		_: return false

func save_state() -> Dictionary:
	return {
		"active_quests": active_quests,
		"next_id": _next_id,
	}

func load_state(data: Dictionary) -> void:
	active_quests = data.get("active_quests", [])
	_next_id = int(data.get("next_id", 0))
	_refill()
	quests_updated.emit()
