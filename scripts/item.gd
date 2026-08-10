class_name Item
extends RefCounted

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
var effects: Array  # Array of [axis: String, amount: float]
var condition: Dictionary  # {} = always available; may contain "weather", "season", "night"
var cost: int
var currency: String  # "Coins" or "Scales"
var set_name: String  # "" = not part of a themed set

func _init(p_name: String, p_slot: String, p_rarity: String, p_effects: Array, p_condition: Dictionary, p_cost: int, p_currency: String, p_set_name: String = "") -> void:
	item_name = p_name
	slot = p_slot
	rarity = p_rarity
	effects = p_effects
	condition = p_condition
	cost = p_cost
	currency = p_currency
	set_name = p_set_name

func get_bonus(axis: String) -> float:
	var total := 0.0
	for effect in effects:
		if effect[0] == axis:
			total += effect[1]
	return total

func is_available_now() -> bool:
	if condition.is_empty():
		return true
	if condition.has("weather") and WorldClock.get_weather() != condition["weather"]:
		return false
	if condition.has("season") and WorldClock.get_season_name() != condition["season"]:
		return false
	if condition.has("night") and WorldClock.get_night_factor() < 0.5:
		return false
	return true

func condition_text() -> String:
	if condition.is_empty():
		return "Always"
	var parts: Array = []
	if condition.has("season"):
		parts.append(condition["season"])
	if condition.has("weather"):
		parts.append(condition["weather"])
	if condition.has("night"):
		parts.append("Night")
	return " + ".join(parts) + " only"

func effects_text() -> String:
	var parts: Array = []
	for effect in effects:
		var axis: String = effect[0]
		var amount: float = effect[1]
		var sign := "+" if amount >= 0.0 else "−"
		parts.append("%s%d%% %s" % [sign, roundi(abs(amount) * 100.0), AXIS_LABELS.get(axis, axis)])
	return " / ".join(parts)
