class_name FishSpecies
extends RefCounted

## One hand-authored species. Everything that used to be shared across a
## whole tier — weight range, value — now lives here, so two Commons can
## differ as much as a minnow differs from an eel.

var species_name: String
var tier: FishRarity.Tier
var habitat: String
var description: String

## Frame index into the fish atlas (see tools/generate_fish_sprites.py).
## Assigned deliberately per species rather than hashed from the name, so
## a pike gets the pike silhouette.
##
## The catalog names the model it wants ("m": "pike") and this resolves it
## through the generated FishModels.MODEL map. It used to be a raw frame
## number in all 238 entries, which meant inserting one spec into the
## middle of the generator's SPECS list silently repointed every species at
## the wrong sprite, with nothing recording what any of them had meant.
var model: int = 0

var weight_range: Vector2 = Vector2(0.3, 2.0)

## Base value before the weight multiplier and any gear bonus. Compared
## against other species of the same tier, so a prize catch can be worth
## noticeably more than its tier-mates.
var value: int = 1

## Relative odds of being picked among the eligible species of its tier.
## 1.0 is the norm; lower makes a species a genuinely uncommon find even
## once its tier comes up.
var pick_weight: float = 1.0

var required_weather: String = ""
var required_season: String = ""

## null = no time-of-day requirement, true = night only, false = day only.
## Untyped so it can hold either a bool or null.
var required_night = null

func _init(data: Dictionary) -> void:
	species_name = data["n"]
	tier = FishRarity.tier_from_name(data["t"])
	habitat = data["h"]
	model = _resolve_model(data["m"], data["n"])
	var w: Array = data["w"]
	weight_range = Vector2(w[0], w[1])
	value = data["v"]
	description = data["d"]
	pick_weight = data.get("pick", 1.0)
	required_weather = data.get("weather", "")
	required_season = data.get("season", "")
	required_night = data.get("night")

## Looks a model name up in the generated map. A name that isn't there is
## a real authoring error — a typo, or a model removed from the generator
## without updating the species that used it — so it is reported loudly
## rather than quietly rendering frame 0, which is how a wrong sprite would
## otherwise slip through unnoticed.
static func _resolve_model(model_name: String, species_name_for_error: String) -> int:
	if not FishModels.MODEL.has(model_name):
		push_error("Species \"%s\" wants sprite model \"%s\", which is not in FishModels.MODEL — check the spelling, or re-run tools/generate_fish_sprites.py if the model was just added" % [species_name_for_error, model_name])
		return 0
	return FishModels.MODEL[model_name]

func conditions_met(current_weather: String, current_season: String, is_night: bool) -> bool:
	if required_weather != "" and required_weather != current_weather:
		return false
	if required_season != "" and required_season != current_season:
		return false
	if required_night != null and required_night != is_night:
		return false
	return true

func condition_text() -> String:
	var parts: Array = []
	if required_season != "":
		parts.append(required_season)
	if required_weather != "":
		parts.append(required_weather)
	if required_night == true:
		parts.append("Night")
	elif required_night == false:
		parts.append("Day")
	if parts.is_empty():
		return "Any conditions"
	return " + ".join(parts) + " only"

## Rolls a weight within this species' own range. `power` in [0, 1] biases
## the roll toward the top of the range (0 = uniform, 1 = always max).
func roll_weight(power: float = 0.0) -> float:
	var t := randf()
	t = t + (1.0 - t) * clampf(power, 0.0, 1.0)
	return lerpf(weight_range.x, weight_range.y, t)

func average_weight() -> float:
	return (weight_range.x + weight_range.y) / 2.0

func weight_text() -> String:
	return "%.1f–%.1f kg" % [weight_range.x, weight_range.y]
