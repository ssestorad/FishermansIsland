class_name ShopCatalog
extends RefCounted

## Builds the gear catalog from GearFamilies plus the hand-written
## signature pieces below.
##
## The previous catalog was 213 rows typed out individually, which is why
## its numbers wandered: eight Common rods sat between +5% and +9% Speed
## for no reason anyone could name. Family expansion keeps a line
## internally consistent, and anything that genuinely should break the
## pattern is written out by hand instead of hidden among the rest.

## Only the Bait piece of a family carries its habitat bias. Every family
## that steers fish still has to earn it through the one slot dedicated to
## steering fish, rather than a rod quietly doing a bait's job.
const BIAS_SLOT := "Bait"

## Hand-written pieces: capstones, real trade-offs, and the oddities that
## give the top of the catalog character. These deliberately ignore the
## rarity curve.
const SIGNATURE_ITEMS := [
	{
		"name": "The Endless Line", "slot": "Rod", "rarity": "Mythic", "family": "Signature",
		"description": "It has never once needed re-spooling. Nobody asks why.",
		"effects": [["speed", 0.46], ["luck", 0.2]],
		"cost": 78, "currency": "Scales",
	},
	{
		"name": "Sirensong Reel", "slot": "Rod", "rarity": "Mythic", "family": "Signature",
		"description": "Reels beautifully. Reels whether you want it to or not.",
		"effects": [["luck", 0.55], ["speed", -0.18]],
		"cost": 72, "currency": "Scales",
	},
	{
		"name": "Leviathan's Reach", "slot": "Rod", "rarity": "Legendary", "family": "Signature",
		"description": "Two arm-spans of something that used to be a rib.",
		"effects": [["power", 0.36], ["speed", 0.1], ["walk_speed", -0.12]],
		"cost": 34, "currency": "Scales",
	},
	{
		"name": "Wyrm's Fang", "slot": "Rod", "rarity": "Mythic", "family": "Signature",
		"description": "Still warm. Still sharp. Still, apparently, hungry.",
		"effects": [["speed", 0.34], ["luck", 0.34], ["power", -0.2]],
		"bonus_effects": [["power", 0.5]], "condition": {"weather": "Blizzard"},
		"cost": 80, "currency": "Scales",
	},
	{
		"name": "Drowned Crown", "slot": "Hat", "rarity": "Mythic", "family": "Signature",
		"description": "Fits anyone. Nobody wears it twice.",
		"effects": [["luck", 0.48], ["endurance", -0.15]],
		"cost": 74, "currency": "Scales",
	},
	{
		"name": "Lighthouse Keeper's Hood", "slot": "Hat", "rarity": "Legendary", "family": "Signature",
		"description": "Forty years of nights, and he never once sat down.",
		"effects": [["luck", 0.2]],
		"bonus_effects": [["luck", 0.3], ["endurance", 0.15]], "condition": {"night": true},
		"cost": 32, "currency": "Scales",
	},
	{
		"name": "Salt-Cured Regalia", "slot": "Outfit", "rarity": "Mythic", "family": "Signature",
		"description": "Stiff as board, warm as a hearth, smells like a tide pool.",
		"effects": [["power", 0.4], ["endurance", 0.2], ["walk_speed", -0.15]],
		"cost": 76, "currency": "Scales",
	},
	{
		"name": "Stormforged Mantle", "slot": "Outfit", "rarity": "Legendary", "family": "Signature",
		"description": "Struck twice. Improved both times.",
		"effects": [["power", 0.18]],
		"bonus_effects": [["power", 0.3], ["speed", 0.14]], "condition": {"weather": "Stormy"},
		"cost": 33, "currency": "Scales",
	},
	{
		"name": "Tireless Charm", "slot": "Charm", "rarity": "Legendary", "family": "Signature",
		"description": "You will not rest. You may not want to.",
		"effects": [["skip_rest_chance", 0.35], ["endurance", 0.15]],
		"cost": 30, "currency": "Scales",
	},
	{
		"name": "Cartographer's Relic", "slot": "Charm", "rarity": "Mythic", "family": "Signature",
		"description": "The island is drawn slightly wrong, and slightly smaller.",
		"effects": [["walk_speed", 0.4], ["xp_gain", 0.2]],
		"cost": 66, "currency": "Scales",
	},
	{
		"name": "Hook of Certainty", "slot": "Charm", "rarity": "Mythic", "family": "Signature",
		"description": "Nothing common has taken it yet. Nothing common ever will.",
		"effects": [["guarantee_rare", 1.0], ["speed", -0.25]],
		"cost": 88, "currency": "Scales",
	},
	{
		"name": "Purser's Sigil", "slot": "Charm", "rarity": "Legendary", "family": "Signature",
		"description": "Counts faster than you do, and is never wrong.",
		"effects": [["coin_gain", 0.35], ["scale_gain", 0.15]],
		"cost": 31, "currency": "Scales",
	},
	{
		"name": "The Last Minnow", "slot": "Bait", "rarity": "Mythic", "family": "Signature",
		"description": "Every deep thing in the world knows this shape.",
		"effects": [["luck", 0.3]],
		"habitat_bias": {"The Deep": 3.2, "Sunken Ruins": 3.2, "Open Water": 2.0},
		"cost": 70, "currency": "Scales",
	},
	{
		"name": "Kingfisher's Offering", "slot": "Bait", "rarity": "Legendary", "family": "Signature",
		"description": "Freshwater only. Freshwater exclusively. Freshwater proudly.",
		"effects": [["luck", 0.24], ["power", 0.1]],
		"habitat_bias": {"Reedbeds": 3.0, "River Bend": 3.0},
		"cost": 28, "currency": "Scales",
	},
	{
		"name": "Bottled Storm", "slot": "Bait", "rarity": "Mythic", "family": "Signature",
		"description": "Uncork upwind. This is not advice, it is a warning.",
		"effects": [["luck", 0.2]],
		"bonus_effects": [["luck", 0.35], ["speed", 0.2]], "condition": {"weather": "Stormy"},
		"habitat_bias": {"Storm Front": 3.4},
		"cost": 82, "currency": "Scales",
	},
	{
		"name": "Beginner's Luck", "slot": "Charm", "rarity": "Common", "family": "Signature",
		"description": "It only works once, but it works spectacularly.",
		"effects": [["luck", 0.14], ["xp_gain", -0.1]],
		"cost": 9, "currency": "Coins",
	},
	{
		"name": "Borrowed Boots", "slot": "Outfit", "rarity": "Common", "family": "Signature",
		"description": "A size too large. You will grow into them or fall over.",
		"effects": [["walk_speed", 0.16], ["power", -0.05]],
		"cost": 8, "currency": "Coins",
	},
	{
		"name": "Lucky Stone", "slot": "Charm", "rarity": "Uncommon", "family": "Signature",
		"description": "Ordinary in every measurable way.",
		"effects": [["luck", 0.16]],
		"cost": 20, "currency": "Coins",
	},
	{
		"name": "Patchwork Sail Coat", "slot": "Outfit", "rarity": "Rare", "family": "Signature",
		"description": "Nine ships contributed. None of them willingly.",
		"effects": [["power", 0.14], ["endurance", 0.1], ["walk_speed", 0.06]],
		"cost": 45, "currency": "Coins",
	},
	{
		"name": "Ledger of Small Fish", "slot": "Hat", "rarity": "Rare", "family": "Signature",
		"description": "Worn as a hat because there is nowhere else to keep it.",
		"effects": [["xp_gain", 0.18], ["coin_gain", 0.1]],
		"cost": 44, "currency": "Coins",
	},
	{
		"name": "Deadwater Lure", "slot": "Bait", "rarity": "Epic", "family": "Signature",
		"description": "Sinks like it means it.",
		"effects": [["power", 0.2]],
		"habitat_bias": {"The Deep": 2.6},
		"cost": 17, "currency": "Scales",
	},
	{
		"name": "Ice Auger Charm", "slot": "Charm", "rarity": "Epic", "family": "Signature",
		"description": "Opens water that would rather stay shut.",
		"effects": [["power", 0.12]],
		"bonus_effects": [["power", 0.24], ["endurance", 0.12]], "condition": {"season": "Winter"},
		"cost": 16, "currency": "Scales",
	},
	{
		"name": "Jetty Boots", "slot": "Outfit", "rarity": "Epic", "family": "Signature",
		"description": "Grip for wet planks a long way from shore.",
		"effects": [["endurance", 0.14]],
		"bonus_effects": [["power", 0.22], ["speed", 0.1]], "condition": {"spot": "offshore"},
		"cost": 18, "currency": "Scales",
	},
	{
		"name": "Pondside Stool", "slot": "Charm", "rarity": "Uncommon", "family": "Signature",
		"description": "Three legs, one of them optimistic.",
		"effects": [["rest_time", 0.14]],
		"bonus_effects": [["luck", 0.14]], "condition": {"spot": "pond"},
		"cost": 19, "currency": "Coins",
	},
	{
		"name": "Harbour Permit", "slot": "Charm", "rarity": "Rare", "family": "Signature",
		"description": "Stamped, countersigned, and almost certainly forged.",
		"effects": [["coin_gain", 0.12]],
		"bonus_effects": [["coin_gain", 0.2], ["speed", 0.1]], "condition": {"spot": "pier"},
		"cost": 46, "currency": "Coins",
	},
]

static var _catalog: Array = []

static func _build_catalog() -> void:
	if not _catalog.is_empty():
		return
	for family in GearFamilies.FAMILIES:
		for item_data in _expand_family(family):
			_catalog.append(Item.new(item_data))
	for data in SIGNATURE_ITEMS:
		_catalog.append(Item.new(data))

## Splits a family's budget across its axes and turns it into one item per
## slot per rarity in its band.
static func _expand_family(family: Dictionary) -> Array:
	var result: Array = []
	var axes: Array = family.axes
	var condition: Dictionary = family.get("condition", {})
	var is_conditional := not condition.is_empty()
	for rarity in family.rarities:
		var rarity_index: int = GearFamilies.RARITY_ORDER.find(rarity)
		var budget: float = GearFamilies.RARITY_BUDGET[rarity]
		var base_budget: float = budget * (GearFamilies.CONDITIONAL_BASE_SHARE if is_conditional else 1.0)
		var bonus_budget: float = budget * GearFamilies.CONDITIONAL_BONUS_SHARE if is_conditional else 0.0
		var stem: String = GearFamilies.stem_for(family, rarity_index)
		var pricing: Dictionary = GearFamilies.RARITY_COST[rarity]
		for slot in family.slots:
			var noun: String = GearFamilies.SLOT_NOUNS[slot][rarity_index]
			var data := {
				"name": "%s %s" % [stem, noun],
				"slot": slot,
				"rarity": rarity,
				"family": family.family,
				"description": family.blurb,
				"effects": _split_budget(base_budget, axes),
				"condition": condition,
				"cost": pricing.cost,
				"currency": pricing.currency,
			}
			if is_conditional:
				data["bonus_effects"] = _split_budget(bonus_budget, axes)
			if slot == BIAS_SLOT and family.has("habitat_bias"):
				data["habitat_bias"] = family.habitat_bias
			result.append(data)
	return result

static func _split_budget(budget: float, axes: Array) -> Array:
	if budget <= 0.0 or axes.is_empty():
		return []
	if axes.size() == 1:
		return [[axes[0], snappedf(budget, 0.01)]]
	var pairs: Array = [[axes[0], snappedf(budget * GearFamilies.PRIMARY_SHARE, 0.01)]]
	for i in range(1, axes.size()):
		var amount := snappedf(budget * GearFamilies.SECONDARY_SHARE, 0.01)
		if amount > 0.0:
			pairs.append([axes[i], amount])
	return pairs

static func all_items() -> Array:
	_build_catalog()
	return _catalog

## Conditions are live effects now rather than shelf filters, so the whole
## catalog is always purchasable (see Item.is_available_now).
static func available_items() -> Array:
	return all_items()

static func items_for_slot(slot: String) -> Array:
	_build_catalog()
	var result: Array = []
	for item in _catalog:
		if item.slot == slot:
			result.append(item)
	return result

static func find(item_name: String) -> Item:
	_build_catalog()
	for item in _catalog:
		if item.item_name == item_name:
			return item
	return null

static func set_bonuses() -> Dictionary:
	return GearFamilies.set_bonuses()

## Kept for compatibility with earlier callers expecting a small default set.
static func default_items() -> Array:
	return available_items()
