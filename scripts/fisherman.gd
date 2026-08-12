extends Node2D

signal clicked(fisherman: Node2D)
signal stats_changed

## Only this fisherman's idle spawn point now — WALK_TO_STORAGE targets
## the shared NeedStations.storage_position instead (every catch goes to
## the same shed regardless of row).
@export var home_position: Vector2 = Vector2(100, 250)
@export var dock_position: Vector2 = Vector2(450, 200)
@export var move_speed: float = 80.0
@export var min_catch_time: float = 2.0
@export var max_catch_time: float = 5.0
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

## How often each need becomes due, in seconds of active work (accumulated
## only while WALK_TO_DOCK/FISHING/WALK_TO_STORAGE — not while already
## servicing a need). Tunable; not a balance decision that's been locked in.
const HUNGER_INTERVAL := 240.0
const THIRST_INTERVAL := 300.0
const REST_INTERVAL := 200.0
## The fourth need: wanting someone to talk to. Serviced either alone at
## the phone or, if there's room, at the shared gathering spot where two
## fishermen who overlap there end up talking to each other.
const SOCIAL_INTERVAL := 280.0

## Used only as a fallback threshold (see _fallback_need()): when the
## top-priority due need can't be serviced right now (Rest, bench full),
## a lower-priority need doesn't have to be fully due (100%) to be worth
## handling on this same Storage visit — 80% along is close enough.
const NEED_THRESHOLD := 0.8

## How long a need takes to service once the fisherman arrives at its
## station. Rest is additionally reduced by the Endurance stat (see
## _service_duration()); hunger/thirst stay flat so Endurance doesn't end
## up mattering for everything.
const NEED_SERVICE_TIME := Vector2(2.0, 4.0)

## Mood: a 0..1 value that lingers, unlike the needs it partly derives
## from. It is stored rather than recomputed on demand precisely so it can
## linger — a value derived from current state would snap back the instant
## a fisherman finished eating, which reads as a second hunger bar rather
## than a mood.
##
## All of these are tunable starting points, not locked balance, same as
## the need intervals above.
const MOOD_NEUTRAL := 0.5
## Swing at the extremes: mood 0.0 -> x0.9 on every stat, 1.0 -> x1.1.
const MOOD_STAT_SWING := 0.1
## Pull back toward neutral every second, so nothing stays extreme for
## long without something actively holding it there.
const MOOD_DRIFT_PER_SECOND := 0.004
## Lost per second for *each* need currently due — three at once outpaces
## the drift above, which is the whole point.
const MOOD_NEED_DRAIN_PER_SECOND := 0.008
## Gained on finishing a need, for the small "that's better" beat.
const MOOD_SERVICE_GAIN := 0.05
## On top of the above, for the social need specifically: a real
## conversation is worth far more than calling home alone, and talking to
## someone you already know is worth a little more again. This is what
## makes the friendship score feed back into the game rather than just
## decorating the Profile panel.
const MOOD_SOCIAL_CHAT_GAIN := 0.10
const MOOD_SOCIAL_FRIEND_BONUS := 0.05
const MOOD_SOCIAL_CALL_GAIN := 0.02
## Gained per live catch, multiplied by (1 + tier index), so a Mythic
## lifts the mood noticeably and a Common barely registers.
const MOOD_CATCH_GAIN := 0.02
## How fast mood settles back to neutral across an offline gap. At this
## rate a few hours away is enough to fully settle, so nobody comes back
## to a mood they never actually lived through.
const MOOD_OFFLINE_SETTLE_RATE := 0.0001
## Small continuous nudge while the current weather matches this
## fisherman's favorite_weather (see below) — additive on top of whatever
## _tick_mood()'s drift/drain branch is already doing, not a replacement
## for it, so a favorite storm can partially offset an otherwise-bad
## needs-neglected stretch rather than fighting it. Over a full 300s
## weather window this alone swings mood by roughly 0.3 — noticeable, not
## an instant jump to elated.
const MOOD_FAVORITE_WEATHER_RATE := 0.001

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

## Fishing bobs slowly between two near-identical rod angles. The strike
## frame plays in the last moments *before* the catch resolves rather
## than after it: the fisherman leaves for storage the instant a catch
## lands, so a post-catch flourish would never be seen, and an
## anticipation reads as the fish biting while costing no cycle time.
const FISH_FRAME_SEQUENCE := [3, 4]
const FISH_STRIKE_FRAME := 5
const FISH_ANIM_FPS := 1.5
const FISH_STRIKE_LEAD := 0.35

## Eating and drinking share one two-frame pose (see the sprite
## generator for why); resting sits still.
const CONSUME_FRAME_SEQUENCE := [6, 7]
const CONSUME_ANIM_FPS := 2.0
const SIT_FRAME := 8

## Where the line hangs from per fishing frame, in node-local pixels —
## the sheet's rod tip shifted by the Sprite2D offset. The strike frame
## is absent on purpose: the fish is out of the water by then.
const FISH_LINE_ORIGINS := {3: Vector2(7.0, -14.0), 4: Vector2(7.0, -13.0)}
const FISH_LINE_LENGTH := 16.0
const FISH_LINE_COLOR := Color(0.86, 0.89, 0.93, 0.9)

## RESTING is gone: rest is now one of three independent periodic needs
## (see current_need below), not a guaranteed step after every catch.
## WALK_TO_STORAGE is what WALK_HOME used to be — the fisherman always
## carries a catch to the storage point; needs are a separate detour from
## there, not folded into this leg. EXPEDITION is a hard interrupt from
## anywhere else (see send_on_expedition()) rather than a leg reached by
## walking — deliberately left out of both the `working` (needs-accrual)
## and `moving` (walk-cycle) checks below, so needs simply pause and the
## sprite simply stops for its duration, no extra condition needed.
enum State { WALK_TO_DOCK, FISHING, WALK_TO_STORAGE, WALK_TO_NEED, SERVICING_NEED, EXPEDITION }

var display_name: String = ""
var state: State = State.WALK_TO_DOCK
var wait_timer: float = 0.0
var current_target: Vector2
var current_catch_duration: float = 0.0

## "hunger" / "thirst" / "rest" while WALK_TO_NEED/SERVICING_NEED; ignored
## otherwise. Determines both the station to walk to and which timer to
## reset once serviced.
var current_need: String = ""
var hunger_timer: float = 0.0
var thirst_timer: float = 0.0
var rest_timer: float = 0.0
var social_timer: float = 0.0
## Set only while current_need == "rest" and a bench slot is held, so it
## can be released back to NeedStations when servicing finishes.
var _claimed_bench_index: int = -1
## Same idea for the gathering spot. -1 while servicing the social need
## means the gathering spot was full and this fisherman went to the phone
## instead, which is also what makes a solo call distinguishable later.
var _claimed_gathering_index: int = -1

## Real-time seconds a trip takes, and which expedition-only habitat
## (FishCatalog.EXPEDITION_HABITATS) it's targeting. expedition_habitat is
## empty whenever state != EXPEDITION; both are persisted (see
## save_manager.gd) since this is the one state worth surviving a save/load,
## unlike every other State value which just resets to WALK_TO_DOCK.
const EXPEDITION_DURATION := 2400.0
var expedition_habitat: String = ""
var expedition_time_left: float = 0.0

## Stable identity, persisted. Needed because friendship scores are keyed
## between *pairs* of fishermen and display_name is not unique — the name
## generator has 224 combinations against a 30-fisherman roster.
var fisherman_id: int = 0
## Capped log of {with_name, with_id, topic, day}, newest last. Same shape
## and capping discipline as catch_history.
const CONVERSATION_LOG_CAP := 5
var conversations: Array = []

## Small talk, so the conversation log reads as something that happened
## rather than a bare timestamp.
const CONVERSATION_TOPICS := [
	"the tide",
	"the one that got away",
	"bait prices",
	"the weather turning",
	"a torn net",
	"who caught what",
	"the walk back",
]

## 0 = miserable, 0.5 = neutral, 1 = elated. See the MOOD_* constants.
var mood: float = MOOD_NEUTRAL

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
## Kept separate from the walk cycle's timer so a pose doesn't inherit
## part of a stride's progress when the state changes.
var _pose_anim_timer: float = 0.0
var _pose_frame: int = 0
## Which sheet column is showing, so _draw() knows where the rod tip is.
var _current_frame_column: int = 0
## Where to head once the current leg's waypoint is reached, or null when
## walking straight there. Only the offshore jetty needs one.
var _deferred_target = null

var appearance_variant: int = -1

## Rolled at hire time (see FishermanFactory.roll_candidates()), one of
## WorldClock.WEATHER_TYPES. Empty on legacy fishermen hired before this
## existed — MOOD_FAVORITE_WEATHER_RATE simply never applies to them.
var favorite_weather: String = ""

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

## Highest-ever tier this fisherman has landed — distinct from
## catch_history, which only keeps the most recent CATCH_HISTORY_CAP
## entries and rolls old ones off. Feeds get_rank_score().
var best_catch_tier: FishRarity.Tier = FishRarity.Tier.COMMON

## Purely cosmetic — surfaces in the Fishermen list (sorted first) and the
## Profile panel. No gameplay effect.
var is_favorite: bool = false

## Which fishing spot this one casts from, and the row it was spawned on.
## dock_position is derived from the two rather than stored, so switching
## spot moves the fisherman without main.gd having to re-place anyone.
var fishing_spot: String = FishingSpots.POND
var lane_y: float = 200.0

## Weighted so a single exceptional catch (rare tier) or a long grind
## (total_catches, uncapped) both move the needle, and level alone can't
## dominate (LEVEL_CAP=20 x 4 axes x 3 = 240, same order of magnitude as
## one Mythic catch). get_level() itself is uncapped display flavor (keeps
## climbing past LEVEL_CAP forever) — mini()'d here to LEVEL_CAP per axis
## so a long-lived fisherman's raw level count can't swamp the other two
## components. Cosmetic only — see RankCatalog.
func get_rank_score() -> int:
	var capped_level := mini(get_level(speed_xp), int(LEVEL_CAP)) \
		+ mini(get_level(luck_xp), int(LEVEL_CAP)) \
		+ mini(get_level(power_xp), int(LEVEL_CAP)) \
		+ mini(get_level(endurance_xp), int(LEVEL_CAP))
	return total_catches + capped_level * 3 + int(best_catch_tier) * 40

func get_rank_title() -> String:
	return RankCatalog.title_for(get_rank_score())

func toggle_favorite() -> void:
	is_favorite = not is_favorite

@onready var click_area: Area2D = $ClickArea
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if display_name.is_empty():
		display_name = NameGenerator.random_name()
	if appearance_variant < 0:
		appearance_variant = randi() % APPEARANCE_VARIANTS.size()
	# Needs timers aren't saved (see save_manager.gd), so every fresh spawn —
	# a brand new hire or every single game load — would otherwise start
	# all three at exactly 0 for every fisherman at once, making the whole
	# roster visibly hungry/thirsty/tired in lockstep. Stagger them instead.
	hunger_timer = randf_range(0.0, HUNGER_INTERVAL)
	thirst_timer = randf_range(0.0, THIRST_INTERVAL)
	rest_timer = randf_range(0.0, REST_INTERVAL)
	social_timer = randf_range(0.0, SOCIAL_INTERVAL)
	# A brand new hire gets an id here; a loaded one already had its saved
	# id written in by FishermanFactory before this ran.
	if fisherman_id <= 0:
		fisherman_id = SocialHub.next_fisherman_id()
	SocialHub.register_fisherman(fisherman_id, display_name)
	position = home_position
	current_target = _random_dock_point()
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	NeedStations.stations_moved.connect(_on_stations_moved)
	sprite.texture = APPEARANCE_VARIANTS[appearance_variant]
	_apply_sprite_frame(STAND_FRAME)
	# A fisherman loaded mid-expedition starts in that state already (see
	# fisherman_factory.gd) — set this here too so there's no one-frame
	# flash of the sprite before the first _process() tick corrects it.
	sprite.visible = state != State.EXPEDITION
	queue_redraw()

func set_appearance_variant(variant: int) -> void:
	if variant >= 0 and variant < APPEARANCE_VARIANTS.size():
		appearance_variant = variant

func _process(delta: float) -> void:
	# Needs build up from real working time only — not while already off
	# servicing a need — so a hungry fisherman doesn't also rack up thirst
	# credit while standing at the grill.
	var working := state == State.WALK_TO_DOCK or state == State.FISHING or state == State.WALK_TO_STORAGE
	if working:
		hunger_timer += delta
		thirst_timer += delta
		rest_timer += delta
		social_timer += delta

	_tick_mood(delta)

	match state:
		State.WALK_TO_DOCK:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0 and not _consume_waypoint():
				state = State.FISHING
				# The water is east, and the fishing pose only exists in
				# the right-facing row — without this a fisherman whose
				# last step happened to be vertical would fall back to
				# standing for the whole cast.
				facing = "right"
				current_catch_duration = _rolled_catch_time()
				wait_timer = current_catch_duration
		State.FISHING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				_resolve_catch()
				_walk_to(_random_home_point(), State.WALK_TO_STORAGE)
		State.WALK_TO_STORAGE:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0 and not _consume_waypoint():
				_start_next_leg()
		State.WALK_TO_NEED:
			_move_toward(current_target, delta)
			if position.distance_to(current_target) < 2.0 and not _consume_waypoint():
				state = State.SERVICING_NEED
				# Servicing a need is the one idle pose that isn't aimed at
				# the water, so turn to face the camera while it happens.
				facing = "down"
				wait_timer = _service_duration(current_need)
				# Presence is registered on *arrival*, not when the slot was
				# claimed — someone still walking over shouldn't count as
				# company for a fisherman finishing their chat right now.
				if current_need == "social" and _claimed_gathering_index >= 0:
					SocialHub.begin_social(fisherman_id)
		State.SERVICING_NEED:
			wait_timer -= delta
			if wait_timer <= 0.0:
				_finish_servicing_need()
				_walk_to(_random_dock_point(), State.WALK_TO_DOCK)
		State.EXPEDITION:
			expedition_time_left -= delta
			if expedition_time_left <= 0.0:
				_resolve_expedition()
	sprite.visible = state != State.EXPEDITION
	_update_sprite_animation(delta)
	queue_redraw()

## Called on arrival at the storage point (every catch passes through
## here): dispatches to the highest-priority due need, or heads straight
## back to the dock if nothing's due. Only ever starts one need per visit —
## a second due need just waits for the next storage trip, unless the
## top-priority pick turns out to be blocked (see _fallback_need()).
func _start_next_leg() -> void:
	var need := _due_need()
	if need == "":
		_walk_to(_random_dock_point(), State.WALK_TO_DOCK)
		return
	var station = _claim_need_station(need)
	if station == null:
		# Couldn't get a station (bench cluster full) — rather than wasting
		# this Storage visit entirely, check whether a lower-priority need
		# is already close enough to due to be worth handling instead.
		need = _fallback_need(need)
		if need == "":
			_walk_to(_random_dock_point(), State.WALK_TO_DOCK)
			return
		station = _claim_need_station(need)
	current_need = need
	_walk_to(station, State.WALK_TO_NEED)

## The top-priority need (`blocked`) couldn't be serviced this visit (only
## possible for "rest", when every bench is occupied). Rather than the
## fisherman walking straight back to the dock empty-handed, check the
## other two needs against NEED_THRESHOLD (80%) — close enough to due to
## be worth bundling into this same Storage stop. Confirmed by the user:
## fine to go fulfill a different need as long as it clears the threshold.
func _fallback_need(blocked: String) -> String:
	if blocked != "hunger" and get_need_progress("hunger") >= NEED_THRESHOLD:
		return "hunger"
	if blocked != "thirst" and get_need_progress("thirst") >= NEED_THRESHOLD:
		return "thirst"
	if blocked != "social" and get_need_progress("social") >= NEED_THRESHOLD:
		return "social"
	return ""

## A station the player just moved may be the one this fisherman is
## walking to, so re-resolve the destination rather than finishing a trip
## to bare ground. Someone mid-SERVICING_NEED is left alone: they are
## standing still and snapping them across the island would read worse
## than letting them finish where they are.
func _on_stations_moved() -> void:
	match state:
		State.WALK_TO_STORAGE:
			current_target = _random_home_point()
		State.WALK_TO_NEED:
			var slot_index := _claimed_gathering_index if current_need == "social" else _claimed_bench_index
			var station = NeedStations.position_for_need(current_need, slot_index)
			if station != null:
				current_target = station

## Priority order: Hunger, Thirst, Rest, then Social. A fisherman with
## several needs due at once resolves them one storage visit at a time
## rather than chaining several detours into one long trip. Social sits
## last because wanting company is the least urgent thing on the list.
func _due_need() -> String:
	if hunger_timer >= HUNGER_INTERVAL:
		return "hunger"
	if thirst_timer >= THIRST_INTERVAL:
		return "thirst"
	if rest_timer >= REST_INTERVAL:
		# Existing unique-item axis, repurposed: it used to mean "skip the
		# guaranteed rest after this catch"; now that rest is periodic
		# rather than guaranteed, it means "skip servicing it just this
		# once" — rest_timer is left as-is so it's still due next visit.
		if randf() < get_equipment_bonus("skip_rest_chance"):
			return ""
		return "rest"
	if social_timer >= SOCIAL_INTERVAL:
		return "social"
	return ""

## Returns the world position to walk to for `need`, claiming a slot where
## one is needed (released in _finish_servicing_need()). Null if the need
## can't be serviced right now — only possible for "rest", when every
## bench is occupied. "social" never returns null: a full gathering spot
## sends the fisherman to the phone instead of blocking the visit.
func _claim_need_station(need: String):
	match need:
		"hunger":
			return NeedStations.grill_position
		"thirst":
			return NeedStations.beer_position
		"rest":
			var claim: Dictionary = NeedStations.claim_bench()
			if claim.is_empty():
				return null
			_claimed_bench_index = claim.index
			return claim.position
		"social":
			var spot: Dictionary = SocialHub.claim_gathering_slot(fisherman_id)
			if spot.is_empty():
				# Everyone else is already over there — call home instead.
				_claimed_gathering_index = -1
				return NeedStations.phone_position
			_claimed_gathering_index = spot.index
			return spot.position
	return null

## Global reduction from the meta-shop's Needs Service Time upgrade,
## applied to all three needs — on top of it, Rest gets its own separate
## per-fisherman Endurance-based reduction, same as before.
func _service_duration(need: String) -> float:
	var base := randf_range(NEED_SERVICE_TIME.x, NEED_SERVICE_TIME.y)
	var global_reduction := MetaProgress.get_needs_service_bonus()
	if need == "rest":
		var rest_reduction := clampf(get_effective_stat(endurance_xp, "endurance") + get_equipment_bonus("rest_time") + get_perk_bonus("rest_time"), 0.0, 0.9)
		return base * (1.0 - rest_reduction) * (1.0 - global_reduction)
	return base * (1.0 - global_reduction)

func _finish_servicing_need() -> void:
	match current_need:
		"hunger":
			hunger_timer = 0.0
		"thirst":
			thirst_timer = 0.0
		"rest":
			rest_timer = 0.0
			if _claimed_bench_index >= 0:
				NeedStations.release_bench(_claimed_bench_index)
				_claimed_bench_index = -1
		"social":
			social_timer = 0.0
			_finish_social()
	adjust_mood(MOOD_SERVICE_GAIN)
	current_need = ""

## Works out whether this was an actual conversation or just a call home,
## and pays out mood, friendship and a log entry accordingly. Anyone else
## standing at the gathering spot right now counts as company.
func _finish_social() -> void:
	if _claimed_gathering_index < 0:
		# Phone: a small lift, no friendships, but still worth logging so
		# the Social card shows something for a quiet fisherman.
		adjust_mood(MOOD_SOCIAL_CALL_GAIN)
		_log_conversation("", 0, "called home")
		return

	SocialHub.release_gathering_slot(_claimed_gathering_index)
	_claimed_gathering_index = -1
	var partners: Array = SocialHub.end_social(fisherman_id)
	if partners.is_empty():
		# Stood around and nobody came — same payoff as calling home.
		adjust_mood(MOOD_SOCIAL_CALL_GAIN)
		_log_conversation("", 0, "waited for company")
		return

	var topic: String = CONVERSATION_TOPICS[randi() % CONVERSATION_TOPICS.size()]
	var gain := MOOD_SOCIAL_CHAT_GAIN
	for partner_id in partners:
		if SocialHub.is_friend(fisherman_id, partner_id):
			gain += MOOD_SOCIAL_FRIEND_BONUS
			break
	for partner_id in partners:
		SocialHub.record_conversation(fisherman_id, partner_id)
	adjust_mood(gain)
	_log_conversation(SocialHub.name_for(partners[0]), partners[0], topic)

## Hands back any shared slot this fisherman is holding. Called when they
## are dismissed mid-need — queue_free() alone leaves the slot claimed
## forever, since the pools track indices rather than node references.
func release_claimed_slots() -> void:
	if _claimed_bench_index >= 0:
		NeedStations.release_bench(_claimed_bench_index)
		_claimed_bench_index = -1
	if _claimed_gathering_index >= 0:
		SocialHub.release_gathering_slot(_claimed_gathering_index)
		_claimed_gathering_index = -1

## Player-initiated hard interrupt from whatever this fisherman is currently
## doing — same immediate-redirect spirit as set_fishing_spot(), not a leg
## reached by walking. Returns false if already away or if no expedition
## habitat exists yet (FishCatalog.EXPEDITION_HABITATS empty).
func send_on_expedition() -> bool:
	if state == State.EXPEDITION:
		return false
	if FishCatalog.EXPEDITION_HABITATS.is_empty():
		return false
	release_claimed_slots()
	current_need = ""
	expedition_habitat = FishCatalog.EXPEDITION_HABITATS.pick_random()
	expedition_time_left = EXPEDITION_DURATION
	state = State.EXPEDITION
	stats_changed.emit()
	return true

## Rolls the guaranteed catch and puts the fisherman back into the normal
## fishing loop. Returns the same result shape _roll_and_apply_catch()
## always does, so both the live-timer path above and the offline path
## below (_advance_expedition_offline()) can share it.
func _resolve_expedition() -> Dictionary:
	var habitat := expedition_habitat
	expedition_habitat = ""
	expedition_time_left = 0.0
	state = State.WALK_TO_DOCK
	current_target = _random_dock_point()
	var result := _roll_and_apply_catch(-1.0, -1, [habitat])
	adjust_mood(MOOD_CATCH_GAIN * (1 + int(result.rarity)))
	stats_changed.emit()
	return result

func _log_conversation(with_name: String, with_id: int, topic: String) -> void:
	conversations.append({
		"with_name": with_name,
		"with_id": with_id,
		"topic": topic,
		"day": WorldClock.get_day_number(),
	})
	if conversations.size() > CONVERSATION_LOG_CAP:
		conversations.pop_front()
	# Unlike mood (which moves every frame and deliberately stays silent),
	# a conversation is a discrete event roughly every SOCIAL_INTERVAL, so
	# it is cheap to announce and keeps the open Profile panel's Social
	# section from going stale.
	stats_changed.emit()

func _update_sprite_animation(delta: float) -> void:
	var moving := state == State.WALK_TO_DOCK or state == State.WALK_TO_STORAGE or state == State.WALK_TO_NEED
	if moving:
		_walk_anim_timer += delta
		if _walk_anim_timer >= 1.0 / WALK_ANIM_FPS:
			_walk_anim_timer = 0.0
			_walk_frame = (_walk_frame + 1) % WALK_FRAME_SEQUENCE.size()
		_apply_sprite_frame(WALK_FRAME_SEQUENCE[_walk_frame])
		return
	_walk_frame = 0
	_walk_anim_timer = 0.0
	match state:
		State.FISHING:
			_animate_fishing(delta)
		State.SERVICING_NEED:
			_animate_need(delta)
		_:
			_apply_sprite_frame(STAND_FRAME)

func _animate_fishing(delta: float) -> void:
	# Scaled against the actual roll so a fast fisherman on a very short
	# countdown doesn't spend the whole cast in the strike pose.
	var lead := minf(FISH_STRIKE_LEAD, current_catch_duration * 0.35)
	if wait_timer <= lead:
		_apply_sprite_frame(FISH_STRIKE_FRAME)
		return
	_advance_pose(delta, FISH_ANIM_FPS, FISH_FRAME_SEQUENCE)

func _animate_need(delta: float) -> void:
	if current_need == "rest":
		_apply_sprite_frame(SIT_FRAME)
		return
	_advance_pose(delta, CONSUME_ANIM_FPS, CONSUME_FRAME_SEQUENCE)

func _advance_pose(delta: float, fps: float, frames: Array) -> void:
	_pose_anim_timer += delta
	if _pose_anim_timer >= 1.0 / fps:
		_pose_anim_timer = 0.0
		_pose_frame = (_pose_frame + 1) % frames.size()
	_apply_sprite_frame(frames[_pose_frame])

## Points the sprite at one cell of the appearance sheet: `column` picks
## the pose, the current facing picks the row.
func _apply_sprite_frame(column: int) -> void:
	_current_frame_column = column
	sprite.flip_h = facing == "left"
	sprite.frame_coords = Vector2i(column, DIRECTION_ROWS[facing])

func _resolve_catch() -> void:
	var result := _roll_and_apply_catch(current_catch_duration)
	# The mood nudge lives here rather than in _roll_and_apply_catch()
	# because this is the live-catch path only. Offline batches call that
	# function directly, thousands of times, and would otherwise pin mood
	# to its maximum for free after every absence — resolve_offline_catches()
	# settles mood toward neutral once instead.
	adjust_mood(MOOD_CATCH_GAIN * (1 + int(result.rarity)))
	print("%s caught a %s (%s, %.1f kg)! [Spd %d / Lck %d / Pwr %d / End %d]" % [
		display_name, result.species.species_name, FishRarity.name_for(result.rarity), result.weight,
		get_level(speed_xp), get_level(luck_xp), get_level(power_xp), get_level(endurance_xp)
	])

## Rolls and applies one catch (currency, album, XP). `catch_duration` feeds
## the speed-XP shaping; pass -1 (default) to have one rolled on the spot,
## which is what offline batch catches do since they skip the real timer.
## `forced_rarity` skips the luck roll and the Secret check entirely (used
## by the dev console). `override_habitats`, when non-empty, rolls from
## those habitats instead of this fisherman's spot — used by expeditions to
## target an EXPEDITION_HABITATS entry no spot can reach. Secret catches are
## deliberately skipped in that case: Secret stays exclusive to normal spot
## fishing, and expedition habitats were built with no Secret entries.
func _roll_and_apply_catch(catch_duration: float = -1.0, forced_rarity: int = -1, override_habitats: Array = []) -> Dictionary:
	if catch_duration < 0.0:
		catch_duration = _rolled_catch_time()
	var habitats := override_habitats if not override_habitats.is_empty() else _spot_habitats()
	var caught_rarity: FishRarity.Tier
	var caught_species: FishSpecies = null
	if forced_rarity >= 0:
		caught_rarity = forced_rarity
	elif override_habitats.is_empty():
		# Secret catches sit outside the normal Luck roll: they only become
		# possible when a hidden species' weather/season/time-of-day combo
		# is currently in effect, and even then only a small independent
		# chance actually lands one instead of a normal-tier catch.
		var secret_species := FishCatalog.roll_species(FishRarity.Tier.SECRET, habitats, _habitat_bias())
		var secret_chance := SECRET_CATCH_BASE_CHANCE * (1.0 + get_effective_stat(luck_xp, "luck") + MetaProgress.get_secret_chance_bonus())
		if secret_species != null and randf() < secret_chance:
			caught_rarity = FishRarity.Tier.SECRET
			caught_species = secret_species
		else:
			caught_rarity = FishRarity.roll(get_effective_stat(luck_xp, "luck"))
			if caught_rarity < FishRarity.Tier.RARE and get_equipment_bonus("guarantee_rare") > 0.0:
				caught_rarity = FishRarity.Tier.RARE
	else:
		caught_rarity = FishRarity.roll(get_effective_stat(luck_xp, "luck"))
	if caught_species == null:
		var resolved := _nearest_available_tier(caught_rarity, habitats)
		caught_species = resolved.species
		caught_rarity = resolved.tier
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
	QuestManager.record_catch(caught_species, caught_rarity)

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
	if caught_rarity > best_catch_tier:
		best_catch_tier = caught_rarity
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

func _spot_habitats() -> Array:
	return FishingSpots.habitats(fishing_spot)

## Habitat pick-weight multipliers from the equipped bait. This is the
## whole point of the Bait slot — it steers which species come up, rather
## than being a fifth source of flat percentages.
func _bait_bias() -> Dictionary:
	var bait = equipped_items.get("Bait")
	if bait == null:
		return {}
	return bait.habitat_bias

## Bait bias plus species-mastery bias (Album.get_habitat_mastery_bias()),
## multiplied together per habitat — the roll-weighting call sites use this
## instead of _bait_bias() directly so mastery applies regardless of what's
## equipped. Mastery entries are only added where they actually differ from
## 1.0, so an unmastered roster keeps the exact same bias dict bait alone
## would have produced.
func _habitat_bias() -> Dictionary:
	var bias := _bait_bias().duplicate()
	for habitat in FishCatalog.HABITATS:
		var mastery_mult: float = Album.get_habitat_mastery_bias(habitat)
		if mastery_mult != 1.0:
			bias[habitat] = float(bias.get(habitat, 1.0)) * mastery_mult
	return bias

## Finds the closest tier this fisherman's spot can actually produce.
##
## Steps down first (a rolled Legendary settling for an Epic reads as bad
## luck), then up. Searching upward is not optional: Offshore contains no
## Common or Uncommon species at all, so a downward-only walk would run
## past tier 0 and leave the caller holding a null species. `habitats`
## defaults to this fisherman's spot when empty; an expedition passes its
## target habitat explicitly instead — same walk, different search space,
## and what guarantees an expedition catch (Abyssal Trench has nothing
## below Rare, so the walk simply climbs until it finds something).
func _nearest_available_tier(rolled: FishRarity.Tier, habitats: Array = []) -> Dictionary:
	if habitats.is_empty():
		habitats = _spot_habitats()
	var bias := _habitat_bias()
	for tier in range(int(rolled), -1, -1):
		var species := FishCatalog.roll_species(tier, habitats, bias)
		if species != null:
			return {"species": species, "tier": tier}
	for tier in range(int(rolled) + 1, int(FishRarity.MAX_ROLLABLE_TIER) + 1):
		var species := FishCatalog.roll_species(tier, habitats, bias)
		if species != null:
			return {"species": species, "tier": tier}
	# Only reachable if a spot's entire slice is condition-locked at once.
	return {"species": FishCatalog.roll_species(FishRarity.Tier.COMMON), "tier": FishRarity.Tier.COMMON}

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
	if state == State.EXPEDITION:
		return _advance_expedition_offline(duration)
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
	# Mood is settled once for the whole gap rather than nudged per catch:
	# nobody comes back to a mood they never actually lived through, in
	# either direction.
	mood = lerpf(mood, MOOD_NEUTRAL, clampf(duration * MOOD_OFFLINE_SETTLE_RATE, 0.0, 1.0))
	return summary

## Counterpart to the offline-catch simulation above, for a fisherman who
## was mid-expedition when the game closed: the trip keeps counting down
## against real elapsed time and can complete while offline, same as it
## would live. Returns the same summary shape resolve_offline_catches()
## does — a zero'd one if the trip is still running, or one built from the
## single guaranteed catch if it just finished — so it plugs straight into
## main.gd's existing per-fisherman aggregation and Welcome Back summary
## with no changes needed there.
func _advance_expedition_offline(duration: float) -> Dictionary:
	var summary := {"catches": 0, "coins": 0, "docked": 0, "best_species": "", "best_rarity": FishRarity.Tier.COMMON, "best_weight": 0.0}
	expedition_time_left -= duration
	if expedition_time_left > 0.0:
		return summary
	var result := _resolve_expedition()
	summary.catches = 1
	if result.docked:
		summary.docked = 1
	elif result.currency == "Coins":
		summary.coins = result.amount
	summary.best_species = result.species.species_name
	summary.best_rarity = result.rarity
	summary.best_weight = result.weight
	return summary

## Average time for one walk-to-dock/catch/walk-to-storage cycle, plus the
## amortized cost of the three periodic needs, used to estimate how many
## catches fit in an offline duration. Needs are periodic rather than
## per-cycle now, so their cost is spread across the cycles between
## visits rather than added to every single one.
func _estimate_cycle_time() -> float:
	var catch_range := _catch_time_range()
	var avg_catch := (catch_range.x + catch_range.y) / 2.0
	var effective_speed := move_speed * (1.0 + get_equipment_bonus("walk_speed") + get_perk_bonus("walk_speed"))
	var avg_walk := 0.0
	if effective_speed > 0.0:
		# Storage is a shared point now (NeedStations.storage_position), not
		# this fisherman's own home_position, so the dock<->storage leg can
		# have a real y-offset too — full distance, not just the x delta.
		var round_trip_distance := dock_position.distance_to(NeedStations.storage_position) * 2.0
		avg_walk = round_trip_distance / effective_speed
	var base_cycle := avg_catch + avg_walk
	return base_cycle + _average_needs_overhead(base_cycle)

## Expected extra seconds per cycle from the four periodic needs: each
## costs its average service time (plus a flat approximation of the extra
## detour walk, since exact station geometry isn't worth modeling here)
## roughly once every interval/base_cycle cycles.
func _average_needs_overhead(base_cycle: float) -> float:
	if base_cycle <= 0.0:
		return 0.0
	const DETOUR_WALK_APPROX := 1.5
	var global_reduction := MetaProgress.get_needs_service_bonus()
	var avg_service := (NEED_SERVICE_TIME.x + NEED_SERVICE_TIME.y) / 2.0 * (1.0 - global_reduction) + DETOUR_WALK_APPROX
	var rest_reduction := clampf(get_effective_stat(endurance_xp, "endurance") + get_equipment_bonus("rest_time") + get_perk_bonus("rest_time"), 0.0, 0.9)
	var skip_rest_chance := clampf(get_equipment_bonus("skip_rest_chance"), 0.0, 1.0)
	var avg_rest_service := avg_service * (1.0 - rest_reduction) * (1.0 - skip_rest_chance)
	var overhead := 0.0
	overhead += avg_service * (base_cycle / HUNGER_INTERVAL)
	overhead += avg_service * (base_cycle / THIRST_INTERVAL)
	overhead += avg_rest_service * (base_cycle / REST_INTERVAL)
	overhead += avg_service * (base_cycle / SOCIAL_INTERVAL)
	return overhead

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

## Routes a walk through the spot's approach point when either end of the
## trip is out past it, so nobody strolls across open water to reach the
## jetty (or back off it). Everything that starts a walk goes through here.
func _walk_to(destination: Vector2, next_state: State) -> void:
	var approach = FishingSpots.approach_point(fishing_spot)
	var beyond: bool = approach != null and (position.x > approach.x + 2.0 or destination.x > approach.x + 2.0)
	if beyond:
		_deferred_target = destination
		current_target = approach
	else:
		_deferred_target = null
		current_target = destination
	state = next_state

## True when the leg just finished was only the waypoint; advances to the
## real destination and reports that the caller should not treat this as
## an arrival yet.
func _consume_waypoint() -> bool:
	if _deferred_target == null:
		return false
	current_target = _deferred_target
	_deferred_target = null
	return true

## Re-derives the casting point from the assigned spot. Called on spawn
## and whenever the player reassigns the fisherman.
func set_fishing_spot(id: String) -> void:
	fishing_spot = id
	dock_position = FishingSpots.cast_position(id, lane_y)
	dock_y_bounds = FishingSpots.lane_bounds(id)
	# Someone already on their way is heading to the old spot's water.
	if state == State.WALK_TO_DOCK or state == State.FISHING:
		_walk_to(_random_dock_point(), State.WALK_TO_DOCK)
	stats_changed.emit()

## Re-rolled every trip back out to the water (after each catch is carried
## home) across the spot's full lane_bounds span — the same range
## cast_position() wraps the whole roster into — rather than just wobbling
## around one fixed anchor, so a fisherman doesn't return to the same spot
## on the bank every time.
func _random_dock_point() -> Vector2:
	var y := randf_range(dock_y_bounds.x, dock_y_bounds.y)
	return Vector2(dock_position.x, y)

## Every fisherman's catch is carried to the same shared point regardless
## of which row they fish from — home_position is only their idle spawn
## spot now. The independent per-arrival jitter is also what keeps a big
## roster from rendering stacked exactly on top of each other at Storage.
func _random_home_point() -> Vector2:
	var storage_pos: Vector2 = NeedStations.storage_position
	return storage_pos + Vector2(randf_range(-home_wander_range, home_wander_range), randf_range(-home_wander_range, home_wander_range))

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

## 0..1 progress toward a need becoming due, for UI display. 1.0 means due
## (or overdue — the timer keeps climbing past the interval while a bench
## is unavailable or skip_rest_chance procs, but this stays clamped).
func get_need_progress(need: String) -> float:
	match need:
		"hunger":
			return clampf(hunger_timer / HUNGER_INTERVAL, 0.0, 1.0)
		"thirst":
			return clampf(thirst_timer / THIRST_INTERVAL, 0.0, 1.0)
		"rest":
			return clampf(rest_timer / REST_INTERVAL, 0.0, 1.0)
		"social":
			return clampf(social_timer / SOCIAL_INTERVAL, 0.0, 1.0)
	return 0.0

## True once get_need_progress() would show full — used to flag "due" in
## the UI without every caller re-deriving the same threshold check.
func is_need_due(need: String) -> bool:
	return get_need_progress(need) >= 1.0

## Drift toward neutral, minus a drain for every need currently left due.
## Deliberately does *not* emit stats_changed: mood moves every frame, and
## that signal drives a full row re-format in the Fishermen panel. The
## Profile panel reads mood off its own throttled ticker instead.
func _tick_mood(delta: float) -> void:
	var drain := 0.0
	for need in ["hunger", "thirst", "rest", "social"]:
		if is_need_due(need):
			drain += MOOD_NEED_DRAIN_PER_SECOND
	var target: float = MOOD_NEUTRAL if drain <= 0.0 else 0.0
	var rate := MOOD_DRIFT_PER_SECOND if drain <= 0.0 else drain
	mood = move_toward(mood, target, rate * delta)
	if not favorite_weather.is_empty() and WorldClock.get_weather() == favorite_weather:
		adjust_mood(MOOD_FAVORITE_WEATHER_RATE * delta)

func get_equipment_bonus(axis: String) -> float:
	var total := 0.0
	for item in equipped_items.values():
		if item != null:
			# Passing the spot is what lets spot-conditional gear know
			# whether it's earning its bonus right now.
			total += item.get_bonus(axis, fishing_spot)
	return total

## Multi-piece family bonuses (e.g. 2x Stormchaser pieces equipped). Only
## the highest piece-count threshold met applies, not every threshold
## stacked. Families replaced the old barely-used `set_name`: every item
## belongs to one now, so wearing a matching line is a real choice.
func get_set_bonus(axis: String) -> float:
	var set_counts: Dictionary = {}
	for item in equipped_items.values():
		if item != null and item.family != "":
			set_counts[item.family] = set_counts.get(item.family, 0) + 1
	var total := 0.0
	var all_bonuses := ShopCatalog.set_bonuses()
	for set_name in set_counts:
		var count: int = set_counts[set_name]
		var thresholds: Dictionary = all_bonuses.get(set_name, {})
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
			environment_bonus = WorldClock.get_weather_speed_bonus() + WorldClock.get_season_speed_bonus() + MetaProgress.get_global_speed_bonus()
		"power":
			environment_bonus = WorldClock.get_season_power_bonus() + MetaProgress.get_global_power_bonus()
		"endurance":
			environment_bonus = MetaProgress.get_global_endurance_bonus()
	environment_bonus += PotionManager.get_bonus(axis)
	environment_bonus += get_perk_bonus(axis)
	environment_bonus += get_set_bonus(axis)
	# Mood scales the whole stat, and must do so *inside* the clamp below.
	# Applying it to this function's return value at a call site instead
	# would bypass EFFECTIVE_STAT_CEILING and let a good mood push the
	# value to 1.0, which is exactly the determinism bug that ceiling
	# exists to prevent.
	var raw := (get_level_fraction(xp) * LEVEL_STAT_WEIGHT + get_equipment_bonus(axis) + environment_bonus) * get_mood_multiplier()
	return clampf(raw, 0.0, EFFECTIVE_STAT_CEILING)

## Every stat is scaled by this, so a miserable fisherman is worse at
## everything rather than mysteriously only at one thing.
func get_mood_multiplier() -> float:
	return 1.0 + (mood - MOOD_NEUTRAL) * 2.0 * MOOD_STAT_SWING

func adjust_mood(delta_mood: float) -> void:
	mood = clampf(mood + delta_mood, 0.0, 1.0)

func equip_item(item) -> void:
	equipped_items[item.slot] = item

func get_stats_text() -> String:
	if state == State.EXPEDITION:
		return "Away — expedition, back in %s" % get_expedition_time_left_text()
	return "Spd %d / Lck %d / Pwr %d / End %d" % [get_level(speed_xp), get_level(luck_xp), get_level(power_xp), get_level(endurance_xp)]

## Minute-rounded, matching the coarseness of the rest of the Profile
## panel's status text — a live mm:ss countdown isn't worth the churn.
func get_expedition_time_left_text() -> String:
	var minutes := int(ceil(expedition_time_left / 60.0))
	return "<1m" if minutes <= 0 else "%dm" % minutes

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

## Newest conversation first, same ordering as the catch log above. Solo
## entries (a phone call, or standing at the spot with nobody around) have
## no partner name and read as the thing they were.
func get_conversations_text() -> String:
	if conversations.is_empty():
		return "Hasn't talked to anyone yet."
	var lines: Array = []
	for i in range(conversations.size() - 1, -1, -1):
		var entry: Dictionary = conversations[i]
		var who: String = entry.get("with_name", "")
		if who == "":
			lines.append("Day %d: %s" % [entry.day, entry.topic])
		else:
			lines.append("Day %d: %s — %s" % [entry.day, who, entry.topic])
	return "\n".join(lines)

## The fishermen this one talks to most. Names are resolved live through
## SocialHub rather than stored, so a rename or dismissal can't leave a
## stale name sitting in the list.
func get_friends_text() -> String:
	var friends: Array = SocialHub.top_friends(fisherman_id)
	if friends.is_empty():
		return "No friends yet."
	var parts: Array = []
	for friend in friends:
		parts.append("%s (%d)" % [SocialHub.name_for(friend.id), int(friend.score)])
	return "Friends: " + ", ".join(parts)

func _draw() -> void:
	# The rod itself is part of the sprite now; only the line is drawn,
	# as a whole-pixel rect. It used to be an anti-aliased diagonal
	# draw_line() — the last thing in the world ignoring the pixel grid.
	if state == State.FISHING and FISH_LINE_ORIGINS.has(_current_frame_column):
		var origin: Vector2 = FISH_LINE_ORIGINS[_current_frame_column]
		draw_rect(Rect2(origin.x, origin.y, 1.0, FISH_LINE_LENGTH), FISH_LINE_COLOR)
	if is_hovered:
		draw_rect(Rect2(-9, -26, 18, 28), Color.WHITE, false, 1.0)
