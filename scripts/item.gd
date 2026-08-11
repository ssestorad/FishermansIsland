class_name Item
extends RefCounted

## A piece of gear.
##
## Three things separate this from the flat "+6% speed" list it replaces:
##
##   * conditions are live. `effects` always apply; `bonus_effects` apply
##     only while `condition` matches the world clock. A storm rod is now
##     actually better in a storm, rather than merely rarer to buy.
##   * bait steers the catch. `habitat_bias` multiplies the pick weight of
##     species from those habitats, which is what makes choosing bait a
##     decision instead of another stat stick.
##   * every item belongs to a `family`, which carries its identity and
##     its set bonus.

const AXIS_LABELS := {
	"speed": "Speed",
	"luck": "Luck",
	"power": "Power",
	"endurance": "Endurance",
	"walk_speed": "Walk Speed",
	"rest_time": "Rest Time",
	"coin_gain": "Coin Gain",
	"scale_gain": "Scale Gain",
	"xp_gain": "XP Gain",
	"guarantee_rare": "Guaranteed Rare+ Catch",
	"skip_rest_chance": "Chance to Skip Resting",
}

var item_name: String
var slot: String
var rarity: String
var family: String
var description: String
## Always-on [axis, amount] pairs.
var effects: Array
## Extra [axis, amount] pairs that only count while `condition` holds.
var bonus_effects: Array
## {} = unconditional; may contain "weather", "season", "night", "spot".
var condition: Dictionary
## habitat name -> pick-weight multiplier, for Bait.
var habitat_bias: Dictionary
var cost: int
var currency: String  # "Coins" or "Scales"

func _init(data: Dictionary) -> void:
	item_name = data.get("name", "")
	slot = data.get("slot", "Rod")
	rarity = data.get("rarity", "Common")
	family = data.get("family", "")
	description = data.get("description", "")
	effects = data.get("effects", [])
	bonus_effects = data.get("bonus_effects", [])
	condition = data.get("condition", {})
	habitat_bias = data.get("habitat_bias", {})
	cost = data.get("cost", 1)
	currency = data.get("currency", "Coins")

## Total for `axis` right now, including the conditional half only when
## its condition currently holds. Everything that reads gear strength goes
## through here, so the live-condition rule is applied in exactly one place.
## `spot` is the wearer's fishing spot; an Item has no idea who holds it,
## so a spot-conditional bonus would otherwise always count. Callers that
## genuinely have no wearer (shop previews) pass nothing and see only the
## world-condition half.
func get_bonus(axis: String, spot: String = "") -> float:
	var total := 0.0
	for effect in effects:
		if effect[0] == axis:
			total += effect[1]
	if not bonus_effects.is_empty() and condition_active(spot):
		for effect in bonus_effects:
			if effect[0] == axis:
				total += effect[1]
	return total

func condition_active(spot: String = "") -> bool:
	if condition.is_empty():
		return true
	if condition.has("weather") and WorldClock.get_weather() != condition["weather"]:
		return false
	if condition.has("season") and WorldClock.get_season_name() != condition["season"]:
		return false
	if condition.has("night") and WorldClock.get_night_factor() < 0.5:
		return false
	if condition.has("spot") and condition["spot"] != spot:
		return false
	return true

func condition_text() -> String:
	if condition.is_empty():
		return ""
	var parts: Array = []
	if condition.has("season"):
		parts.append(condition["season"])
	if condition.has("weather"):
		parts.append(condition["weather"])
	if condition.has("night"):
		parts.append("Night")
	if condition.has("spot"):
		parts.append(FishingSpots.display_name(condition["spot"]))
	return " + ".join(parts)

static func format_effects(pairs: Array) -> String:
	var parts: Array = []
	for effect in pairs:
		var axis: String = effect[0]
		var amount: float = effect[1]
		var sign := "+" if amount >= 0.0 else "−"
		parts.append("%s%d%% %s" % [sign, roundi(abs(amount) * 100.0), AXIS_LABELS.get(axis, axis)])
	return " / ".join(parts)

func effects_text() -> String:
	var text := format_effects(effects)
	if not bonus_effects.is_empty():
		var window := condition_text()
		var extra := "%s in %s" % [format_effects(bonus_effects), window] if window != "" else format_effects(bonus_effects)
		text = extra if text == "" else "%s, %s" % [text, extra]
	return text

## One short line for list rows, which clip hard at the panel width.
##
## Leads with whatever actually distinguishes the item — its condition
## window or what its bait attracts — because those are the decisions the
## catalog is built around, and a truncated "+12% Luck / +6% XP Gai…"
## hides exactly the part worth reading. Full numbers live in the equip
## panel's comparison.
func summary_text() -> String:
	if not habitat_bias.is_empty():
		var habitats: Array = habitat_bias.keys()
		var lead: String = habitats[0]
		if habitats.size() > 1:
			return "Draws %s +%d more" % [lead, habitats.size() - 1]
		return "Draws %s" % lead
	if not bonus_effects.is_empty():
		return "%s: %s" % [condition_text(), format_effects(bonus_effects)]
	return format_effects(effects)

func habitat_bias_text() -> String:
	if habitat_bias.is_empty():
		return ""
	var parts: Array = []
	for habitat in habitat_bias:
		parts.append("%s x%.1f" % [habitat, float(habitat_bias[habitat])])
	return "Attracts " + ", ".join(parts)

