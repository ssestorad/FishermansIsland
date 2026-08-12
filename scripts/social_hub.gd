extends Node

## Brokers everything about fishermen that a single Fisherman node can't
## reach on its own: stable identity, who is currently standing at the
## gathering spot, and how well any two of them know each other.
##
## A Fisherman has no reference to main, the scene tree or the roster — it
## only talks to autoloads — so pairing two of them for a conversation has
## to go through here, the same way NeedStations already brokers the
## limited bench pool.

## How many fishermen can use the gathering spot at once. Anyone who finds
## it full falls back to the phone, so this doubles as the knob that
## decides how much use the phone actually gets.
const GATHERING_SLOTS := 4
const GATHERING_SPACING := 10.0

## Score added to a pair every time they talk. No decay for now — the
## top-friends list then simply reflects who someone has talked to most,
## which is the behaviour asked for.
const FRIENDSHIP_PER_CHAT := 1.0
## At or above this, a partner counts as a friend and the conversation is
## worth a little extra mood.
const FRIEND_THRESHOLD := 3.0

## Ids start at 1 so 0 can mean "not assigned yet".
var _next_id: int = 1
## "loId|hiId" -> float. Stored once per unordered pair, so the score is
## symmetric by construction rather than duplicated on both fishermen and
## kept in sync by hand.
var friendships: Dictionary = {}

## Live runtime state, deliberately not persisted (same call as
## NeedStations._claimed): slot index -> fisherman id, held from the moment
## a fisherman sets off until it finishes talking.
var _gathering_slots: Dictionary = {}
## fisherman id -> true, but only while actually standing at the spot. Kept
## separate from the claim above so somebody still walking over doesn't
## count as company for someone finishing right now.
var _present: Dictionary = {}

## id -> display_name for everyone currently on the island. Also live
## state, rebuilt as fishermen spawn: friendships persist by id, and names
## are looked up from whoever actually exists right now.
var _names: Dictionary = {}

func register_fisherman(id: int, display_name: String) -> void:
	_names[id] = display_name

## Falls back rather than returning empty: a friendship can outlive the
## fisherman it points at if a save is edited or a dismissal is missed.
func name_for(id: int) -> String:
	return _names.get(id, "Someone")

func next_fisherman_id() -> int:
	var id := _next_id
	_next_id += 1
	return id

## Keeps the counter ahead of ids read back from a save, so a later hire
## can't be handed an id somebody already has.
func reserve_id(id: int) -> void:
	if id >= _next_id:
		_next_id = id + 1

## Standing spots spread across the drawn square, centred on it rather
## than running right from its origin — otherwise the last slot lands
## outside the marker the player can see, which is exactly the kind of
## drift between drawn art and real geometry this project has been bitten
## by before.
func gathering_positions() -> Array:
	var result: Array = []
	var centre_offset := (GATHERING_SLOTS - 1) / 2.0
	for i in range(GATHERING_SLOTS):
		result.append(NeedStations.gathering_position + Vector2((i - centre_offset) * GATHERING_SPACING, 0.0))
	return result

## Claims a standing spot. Returns {"index": int, "position": Vector2}, or
## {} when the spot is full — the caller is expected to fall back to the
## phone rather than treat that as a failure.
func claim_gathering_slot(fisherman_id: int) -> Dictionary:
	var positions := gathering_positions()
	for i in range(positions.size()):
		if not _gathering_slots.has(i):
			_gathering_slots[i] = fisherman_id
			return {"index": i, "position": positions[i]}
	return {}

func release_gathering_slot(index: int) -> void:
	_gathering_slots.erase(index)

## Called on arrival, not on claim: presence has to mean "actually here".
func begin_social(fisherman_id: int) -> void:
	_present[fisherman_id] = true

## Ends this fisherman's turn at the spot and reports who else was there
## to talk to. Clears presence first so a partner finishing in the same
## frame doesn't count them twice.
func end_social(fisherman_id: int) -> Array:
	_present.erase(fisherman_id)
	var partners: Array = []
	for other_id in _present:
		partners.append(other_id)
	return partners

func record_conversation(a_id: int, b_id: int) -> void:
	if a_id == b_id:
		return
	var key := _pair_key(a_id, b_id)
	friendships[key] = float(friendships.get(key, 0.0)) + FRIENDSHIP_PER_CHAT

func friendship_between(a_id: int, b_id: int) -> float:
	return float(friendships.get(_pair_key(a_id, b_id), 0.0))

func is_friend(a_id: int, b_id: int) -> bool:
	return friendship_between(a_id, b_id) >= FRIEND_THRESHOLD

## The `count` fishermen this one has the highest scores with, best first,
## as [{"id": int, "score": float}, ...].
func top_friends(fisherman_id: int, count: int = 3) -> Array:
	var found: Array = []
	for key in friendships:
		var ids := _ids_from_key(key)
		if ids.is_empty():
			continue
		var other_id := -1
		if ids[0] == fisherman_id:
			other_id = ids[1]
		elif ids[1] == fisherman_id:
			other_id = ids[0]
		else:
			continue
		found.append({"id": other_id, "score": float(friendships[key])})
	found.sort_custom(func(a, b): return a.score > b.score)
	return found.slice(0, count)

## Drops every pair entry touching a dismissed fisherman, so scores don't
## accumulate against people who no longer exist.
func forget_fisherman(fisherman_id: int) -> void:
	_present.erase(fisherman_id)
	_names.erase(fisherman_id)
	for index in _gathering_slots.keys():
		if _gathering_slots[index] == fisherman_id:
			_gathering_slots.erase(index)
	for key in friendships.keys():
		var ids := _ids_from_key(key)
		if ids.size() == 2 and (ids[0] == fisherman_id or ids[1] == fisherman_id):
			friendships.erase(key)

func _pair_key(a_id: int, b_id: int) -> String:
	return "%d|%d" % [mini(a_id, b_id), maxi(a_id, b_id)]

func _ids_from_key(key: String) -> Array:
	var parts := key.split("|")
	if parts.size() != 2:
		return []
	return [int(parts[0]), int(parts[1])]

func save_state() -> Dictionary:
	return {
		"next_id": _next_id,
		"friendships": friendships,
	}

func load_state(data: Dictionary) -> void:
	_next_id = maxi(1, int(data.get("next_id", 1)))
	friendships = data.get("friendships", {})
	# Live state never survives a load — nobody is standing anywhere yet.
	_gathering_slots.clear()
	_present.clear()
