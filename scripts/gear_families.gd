class_name GearFamilies
extends RefCounted

## The spine of the gear catalog.
##
## Items are not written out one by one. Each family declares its identity
## — which slots it covers, which rarity band, which axes it leans on,
## whether it has a condition or steers bait — and ShopCatalog expands
## that into the individual pieces along a shared rarity curve. The old
## catalog was 213 hand-typed rows whose numbers drifted with no pattern;
## this keeps a family internally consistent by construction.
##
## Hand-written exceptions still exist: see ShopCatalog.SIGNATURE_ITEMS
## for the capstones and trade-off pieces that shouldn't follow a curve.

const RARITY_ORDER := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

## Total effect budget for a piece at each rarity, before it is split
## between axes and between the always-on and conditional halves.
const RARITY_BUDGET := {
	"Common": 0.07,
	"Uncommon": 0.13,
	"Rare": 0.20,
	"Epic": 0.28,
	"Legendary": 0.38,
	"Mythic": 0.50,
}

## Coins early, Scales once an item is worth banking rare fish for.
const RARITY_COST := {
	"Common": {"cost": 7, "currency": "Coins"},
	"Uncommon": {"cost": 18, "currency": "Coins"},
	"Rare": {"cost": 42, "currency": "Coins"},
	"Epic": {"cost": 15, "currency": "Scales"},
	"Legendary": {"cost": 30, "currency": "Scales"},
	"Mythic": {"cost": 62, "currency": "Scales"},
}

## A conditional family trades away part of its always-on strength for a
## much larger payoff inside its window: 60% of budget baseline, plus 75%
## on top when the condition holds. Out of window it is clearly worse than
## an unconditional peer; inside it is clearly better. That tension is the
## whole point of making conditions live.
const CONDITIONAL_BASE_SHARE := 0.6
const CONDITIONAL_BONUS_SHARE := 0.75

## Two-axis families put most of the budget on the first axis so they
## still read as "a Speed piece with a little Luck".
const PRIMARY_SHARE := 0.72
const SECONDARY_SHARE := 0.34

## Slot nouns per rarity index, so a family's pieces read as a progression
## rather than "Stormchaser Rod 1..6".
##
## All six must differ within a slot: a family may reuse the same stem at
## two rarities, so the noun is what keeps "Backwater Rod" (Common) and
## its Uncommon sibling from colliding — and item names are the save's
## lookup key, so a collision is not cosmetic.
const SLOT_NOUNS := {
	"Rod": ["Rod", "Pole", "Longrod", "Caster", "Reach", "Spire"],
	"Hat": ["Cap", "Brim", "Hat", "Hood", "Crown", "Diadem"],
	"Outfit": ["Vest", "Jacket", "Coat", "Mantle", "Regalia", "Shroud"],
	"Charm": ["Trinket", "Token", "Charm", "Talisman", "Sigil", "Relic"],
	"Bait": ["Bait", "Lure", "Rig", "Chum", "Offering", "Temptation"],
}

## name stem per rarity index; families list one stem each, or several to
## rename themselves as they climb.
const FAMILIES := [
	# --- Starter lines: unconditional, single axis, cheap ----------------
	{
		"family": "Backwater", "stems": ["Backwater", "Backwater", "Riverstone"],
		"slots": ["Rod", "Hat", "Outfit"], "rarities": ["Common", "Uncommon", "Rare"],
		"axes": ["speed"],
		"blurb": "Plain tackle that has outlived three owners.",
		"set": {2: [["speed", 0.04]], 3: [["speed", 0.09]]},
	},
	{
		"family": "Hand-Me-Down", "stems": ["Hand-Me-Down", "Patched", "Mended"],
		"slots": ["Rod", "Hat", "Outfit", "Charm", "Bait"], "rarities": ["Common", "Uncommon", "Rare"],
		"axes": ["luck"],
		"blurb": "Nothing matches. Everything works.",
		"set": {3: [["luck", 0.05]], 5: [["luck", 0.12]]},
	},
	{
		"family": "Reedcutter", "stems": ["Reedcutter", "Reedcutter", "Marshwarden", "Marshwarden"],
		"slots": ["Rod", "Outfit", "Bait"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["luck", "speed"],
		"habitat_bias": {"Reedbeds": 2.2},
		"blurb": "Cut for still water and patient mornings.",
		"set": {2: [["luck", 0.05]], 3: [["luck", 0.11]]},
	},
	{
		"family": "Riverworn", "stems": ["Riverworn", "Riverworn", "Rapidsborn", "Rapidsborn"],
		"slots": ["Outfit", "Charm", "Bait"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["power"],
		"habitat_bias": {"River Bend": 2.2},
		"blurb": "Smoothed by current until it fits the hand.",
		"set": {2: [["power", 0.05]], 3: [["power", 0.11]]},
	},
	{
		"family": "Brackwater", "stems": ["Brackwater", "Brackwater", "Estuary-Forged", "Estuary-Forged"],
		"slots": ["Rod", "Outfit", "Bait"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["luck", "power"],
		"habitat_bias": {"Brackish Shallows": 2.2},
		"blurb": "Half river, half sea — rusts if you don't rinse it.",
		"set": {2: [["luck", 0.05]], 3: [["luck", 0.11]]},
	},
	{
		"family": "Tideworn", "stems": ["Tideworn", "Tideworn", "Lowtide", "Lowtide"],
		"slots": ["Outfit", "Charm", "Bait"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["speed"],
		"habitat_bias": {"Tidal Flats": 2.2},
		"blurb": "Cracked and pale from drying out twice a day.",
		"set": {2: [["speed", 0.05]], 3: [["speed", 0.11]]},
	},

	# --- Coastal lines: habitat-steering, mid band -----------------------
	{
		"family": "Harbourhand", "stems": ["Harbourhand", "Harbourhand", "Dockmaster", "Dockmaster"],
		"slots": ["Rod", "Outfit", "Charm", "Bait"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["speed", "coin_gain"],
		"habitat_bias": {"Harbour": 2.4},
		"blurb": "Working gear, bought secondhand off the quay.",
		"set": {2: [["speed", 0.06]], 4: [["coin_gain", 0.12]]},
	},
	{
		"family": "Kelpweave", "stems": ["Kelpweave", "Kelpweave", "Fronded", "Fronded"],
		"slots": ["Hat", "Outfit", "Bait"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["luck", "power"],
		"habitat_bias": {"Kelp Forest": 2.4},
		"blurb": "Woven damp and left to stiffen in the sun.",
		"set": {2: [["luck", 0.06]], 3: [["luck", 0.13]]},
	},
	{
		"family": "Coralcut", "stems": ["Coralcut", "Coralcut", "Reefborn", "Reefborn"],
		"slots": ["Rod", "Hat", "Charm", "Bait"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["power", "luck"],
		"habitat_bias": {"Coral Shallows": 2.4},
		"blurb": "Sharp edges, bright colours, unkind to nets.",
		"set": {2: [["power", 0.06]], 4: [["power", 0.14]]},
	},

	# --- Weather and time lines: the conditional heart of the system -----
	{
		"family": "Stormchaser", "stems": ["Stormchaser", "Stormchaser", "Tempest", "Tempest"],
		"slots": ["Rod", "Hat", "Charm"], "rarities": ["Rare", "Epic", "Legendary", "Mythic"],
		"axes": ["speed", "luck"],
		"condition": {"weather": "Stormy"},
		"blurb": "Only a fool fishes a storm. Only a fool gets rich.",
		"set": {2: [["luck", 0.07]], 3: [["luck", 0.15]]},
	},
	{
		"family": "Frostbound", "stems": ["Frostbound", "Frostbound", "Glacierborn", "Glacierborn"],
		"slots": ["Hat", "Outfit", "Charm"], "rarities": ["Rare", "Epic", "Legendary", "Mythic"],
		"axes": ["power", "endurance"],
		"condition": {"season": "Winter"},
		"blurb": "Lined for a season that does not forgive.",
		"set": {2: [["power", 0.07]], 3: [["endurance", 0.15]]},
	},
	{
		"family": "Fogwalker", "stems": ["Fogwalker", "Fogwalker", "Mistbound"],
		"slots": ["Hat", "Charm", "Bait"], "rarities": ["Rare", "Epic", "Legendary"],
		"axes": ["luck"],
		"condition": {"weather": "Foggy"},
		"blurb": "You hear the catch long before you see it.",
		"set": {2: [["luck", 0.08]], 3: [["luck", 0.16]]},
	},
	{
		"family": "Nightwatch", "stems": ["Nightwatch", "Nightwatch", "Moonless", "Moonless"],
		"slots": ["Rod", "Hat", "Charm", "Outfit"], "rarities": ["Rare", "Epic", "Legendary", "Mythic"],
		"axes": ["luck", "speed"],
		"condition": {"night": true},
		"blurb": "The good water only shows itself after dark.",
		"set": {2: [["luck", 0.07]], 4: [["luck", 0.16]]},
	},
	{
		"family": "Emberfall", "stems": ["Emberfall", "Emberfall", "Ashfall"],
		"slots": ["Rod", "Outfit", "Bait"], "rarities": ["Rare", "Epic", "Legendary"],
		"axes": ["speed", "xp_gain"],
		"condition": {"season": "Autumn"},
		"blurb": "Cut from the short weeks when everything bites.",
		"set": {2: [["speed", 0.07]], 3: [["xp_gain", 0.14]]},
	},
	{
		"family": "Sunbleached", "stems": ["Sunbleached", "Sunbleached", "Highsummer"],
		"slots": ["Hat", "Outfit", "Charm"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["speed", "walk_speed"],
		"condition": {"season": "Summer"},
		"blurb": "Faded pale by seasons of standing still in the light.",
		"set": {2: [["walk_speed", 0.08]], 3: [["speed", 0.12]]},
	},
	{
		"family": "Tidewatcher", "stems": ["Tidewatcher", "Tidewatcher", "Rainkeeper"],
		"slots": ["Hat", "Charm", "Outfit"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["luck", "endurance"],
		"condition": {"weather": "Rainy"},
		"blurb": "Rain flattens the water and loosens the fish.",
		"set": {2: [["luck", 0.06]], 3: [["endurance", 0.13]]},
	},

	# --- Deep water lines: offshore payoff, real drawbacks ---------------
	{
		"family": "Deepwarden", "stems": ["Deepwarden", "Deepwarden", "Trenchlord"],
		"slots": ["Rod", "Outfit", "Charm", "Bait"], "rarities": ["Epic", "Legendary", "Mythic"],
		"axes": ["power", "endurance"],
		"habitat_bias": {"The Deep": 2.6, "Open Water": 1.6},
		"condition": {"spot": "offshore"},
		"blurb": "Weighted to reach water that never sees light.",
		"set": {2: [["power", 0.09]], 4: [["power", 0.2]]},
	},
	{
		"family": "Abyssal", "stems": ["Abyssal", "Abyssal", "Voidtouched"],
		"slots": ["Rod", "Hat", "Bait"], "rarities": ["Epic", "Legendary", "Mythic"],
		"axes": ["luck", "power"],
		"habitat_bias": {"The Deep": 2.4, "Sunken Ruins": 2.4},
		"blurb": "Something down there is fishing back.",
		"set": {2: [["luck", 0.09]], 3: [["luck", 0.19]]},
	},
	{
		"family": "Icebreaker", "stems": ["Icebreaker", "Icebreaker", "Floeborn"],
		"slots": ["Rod", "Outfit", "Bait"], "rarities": ["Rare", "Epic", "Legendary"],
		"axes": ["power", "speed"],
		"habitat_bias": {"Ice Shelf": 2.6},
		"condition": {"season": "Winter"},
		"blurb": "Half tackle, half crowbar.",
		"set": {2: [["power", 0.08]], 3: [["power", 0.17]]},
	},
	{
		"family": "Ruinsalvage", "stems": ["Ruinsalvage", "Ruinsalvage", "Drowned Court"],
		"slots": ["Outfit", "Charm", "Bait"], "rarities": ["Epic", "Legendary", "Mythic"],
		"axes": ["scale_gain", "coin_gain"],
		"habitat_bias": {"Sunken Ruins": 2.8},
		"blurb": "Whoever owned it last is still down there.",
		"set": {2: [["scale_gain", 0.1]], 3: [["coin_gain", 0.2]]},
	},
	{
		"family": "Galewind", "stems": ["Galewind", "Galewind", "Squallborn"],
		"slots": ["Rod", "Hat", "Bait"], "rarities": ["Rare", "Epic", "Legendary"],
		"axes": ["speed", "luck"],
		"habitat_bias": {"Storm Front": 2.6},
		"condition": {"weather": "Stormy"},
		"blurb": "Cast into the weather, not away from it.",
		"set": {2: [["speed", 0.08]], 3: [["speed", 0.16]]},
	},
	{
		"family": "Openwater", "stems": ["Bluewater", "Bluewater", "Farhorizon"],
		"slots": ["Rod", "Outfit", "Bait"], "rarities": ["Rare", "Epic", "Legendary"],
		"axes": ["power", "speed"],
		"habitat_bias": {"Open Water": 2.6},
		"blurb": "Built for the long empty stretch past the shelf.",
		"set": {2: [["power", 0.07]], 3: [["speed", 0.14]]},
	},

	# --- Utility lines: the axes nothing else touches --------------------
	{
		"family": "Wayfarer", "stems": ["Wayfarer", "Wayfarer", "Longstride", "Longstride"],
		"slots": ["Outfit", "Charm"], "rarities": ["Common", "Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["walk_speed", "endurance"],
		"blurb": "The island is bigger than it looks.",
		"set": {2: [["walk_speed", 0.1]]},
	},
	{
		"family": "Tireless", "stems": ["Tireless", "Tireless", "Unwearied"],
		"slots": ["Outfit", "Charm", "Hat"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["rest_time", "endurance"],
		"blurb": "Sleep is a rumour from the mainland.",
		"set": {2: [["rest_time", 0.09]], 3: [["endurance", 0.14]]},
	},
	{
		"family": "Coinpurse", "stems": ["Coinpurse", "Coinpurse", "Merchant's", "Merchant's"],
		"slots": ["Hat", "Charm"], "rarities": ["Common", "Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["coin_gain"],
		"blurb": "Every fish is a number to somebody.",
		"set": {2: [["coin_gain", 0.12]]},
	},
	{
		"family": "Scaleward", "stems": ["Scaleward", "Scaleward", "Hoardkeeper"],
		"slots": ["Hat", "Charm", "Outfit"], "rarities": ["Rare", "Epic", "Legendary", "Mythic"],
		"axes": ["scale_gain"],
		"blurb": "Keeps the good ones worth keeping.",
		"set": {2: [["scale_gain", 0.11]], 3: [["scale_gain", 0.2]]},
	},
	{
		"family": "Scholar", "stems": ["Scholar's", "Scholar's", "Archivist's"],
		"slots": ["Hat", "Charm", "Outfit"], "rarities": ["Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["xp_gain", "luck"],
		"blurb": "Notes on every bite, in a hand nobody else can read.",
		"set": {2: [["xp_gain", 0.1]], 3: [["xp_gain", 0.2]]},
	},

	# --- Bait-only lines -------------------------------------------------
	{
		"family": "Chumline", "stems": ["Chumline", "Chumline", "Bloodline"],
		"slots": ["Bait"], "rarities": ["Common", "Uncommon", "Rare", "Epic", "Legendary"],
		"axes": ["luck"],
		"habitat_bias": {"Open Water": 1.8, "Storm Front": 1.8},
		"blurb": "Crude, effective, and deeply unpleasant to carry.",
		"set": {},
	},
	{
		"family": "Glowlure", "stems": ["Glowlure", "Glowlure", "Lanternlure"],
		"slots": ["Bait"], "rarities": ["Rare", "Epic", "Legendary", "Mythic"],
		"axes": ["luck"],
		"condition": {"night": true},
		"habitat_bias": {"The Deep": 2.2, "Sunken Ruins": 2.2},
		"blurb": "Cold light, and something rising toward it.",
		"set": {},
	},
	{
		"family": "Springspawn", "stems": ["Springspawn", "Springspawn", "Firstthaw"],
		"slots": ["Bait", "Charm"], "rarities": ["Common", "Uncommon", "Rare", "Epic"],
		"axes": ["luck", "xp_gain"],
		"condition": {"season": "Spring"},
		"habitat_bias": {"Reedbeds": 1.8, "River Bend": 1.8},
		"blurb": "Everything is hungry after the thaw.",
		"set": {2: [["luck", 0.07]]},
	},
]

static func stem_for(family: Dictionary, rarity_index: int) -> String:
	var stems: Array = family.stems
	return stems[mini(rarity_index, stems.size() - 1)]

static func set_bonuses() -> Dictionary:
	var result := {}
	for family in FAMILIES:
		var bonuses: Dictionary = family.get("set", {})
		if not bonuses.is_empty():
			result[family.family] = bonuses
	return result

static func find(family_name: String) -> Dictionary:
	for family in FAMILIES:
		if family.family == family_name:
			return family
	return {}
