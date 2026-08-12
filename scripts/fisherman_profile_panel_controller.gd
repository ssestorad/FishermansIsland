class_name FishermanProfilePanelController
extends PanelController

signal dismiss_requested(fisherman)
signal slot_clicked(fisherman, slot_name)
signal friend_selected(friend_id: int)

const LIST_ROW_SCENE := preload("res://scenes/ui/ListRow.tscn")

@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderRow/NameLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/RankLabel
@onready var spot_button: Button = $MarginContainer/VBoxContainer/SpotButton
@onready var expedition_button: Button = $MarginContainer/VBoxContainer/ExpeditionButton
@onready var favorite_button: Button = $MarginContainer/VBoxContainer/HeaderRow/FavoriteButton
@onready var skills_tab: VBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab
@onready var needs_tab: VBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab
@onready var social_tab: VBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SocialTab
@onready var skills_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/SkillsTabButton
@onready var needs_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/NeedsTabButton
@onready var social_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/SocialTabButton
@onready var speed_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/SpeedLabel
@onready var speed_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/SpeedBar
@onready var luck_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/LuckLabel
@onready var luck_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/LuckBar
@onready var power_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/PowerLabel
@onready var power_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/PowerBar
@onready var endurance_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/EnduranceLabel
@onready var endurance_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/EnduranceBar
@onready var hunger_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/HungerLabel
@onready var hunger_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/HungerBar
@onready var thirst_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/ThirstLabel
@onready var thirst_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/ThirstBar
@onready var rest_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/RestLabel
@onready var rest_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/RestBar
@onready var social_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/SocialLabel
@onready var social_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/SocialBar
@onready var mood_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/MoodLabel
@onready var mood_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/MoodBar
@onready var favorite_weather_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/NeedsTab/FavoriteWeatherLabel
@onready var friends_empty_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SocialTab/FriendsEmptyLabel
@onready var friends_list: VBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SocialTab/FriendsList
@onready var conversations_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SocialTab/ConversationsLabel
@onready var equipment_slots: HBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/EquipmentSlots
@onready var perks_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/PerksLabel
@onready var history_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SkillsTab/HistoryLabel
@onready var dismiss_button: Button = $MarginContainer/VBoxContainer/DismissButton

## Needs tick continuously (not just on a catch, unlike the XP bars above),
## so they need their own lightweight poll while the panel is open — same
## throttled-ticker pattern as the Shop's restock/potion countdowns
## (shop_panel_controller.gd), not a naive full-speed _process.
const NEEDS_TICK_INTERVAL := 0.2  # 5/sec

## The panel had grown to four stat bars, five equipment slots, five need
## bars, perks, catch history and the social log all stacked in one
## scroll — split into three cards instead.
const TAB_SKILLS := "skills"
const TAB_NEEDS := "needs"
const TAB_SOCIAL := "social"

var _fisherman: Node = null
var _dismiss_armed: bool = false
var _needs_tick_accumulator: float = 0.0
var _active_tab: String = TAB_SKILLS

func _on_ready() -> void:
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_name))
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	favorite_button.pressed.connect(_on_favorite_button_pressed)
	spot_button.pressed.connect(_on_spot_button_pressed)
	expedition_button.pressed.connect(_on_expedition_button_pressed)
	skills_tab_button.pressed.connect(_on_tab_pressed.bind(TAB_SKILLS))
	needs_tab_button.pressed.connect(_on_tab_pressed.bind(TAB_NEEDS))
	social_tab_button.pressed.connect(_on_tab_pressed.bind(TAB_SOCIAL))
	visibility_changed.connect(_on_visibility_changed)
	_update_tabs()

func _on_tab_pressed(tab: String) -> void:
	_active_tab = tab
	_update_tabs()

## Selected tab is marked by disabling its own button, the same way the
## Shop and Album panels already show which tab is active.
func _update_tabs() -> void:
	skills_tab.visible = _active_tab == TAB_SKILLS
	needs_tab.visible = _active_tab == TAB_NEEDS
	social_tab.visible = _active_tab == TAB_SOCIAL
	skills_tab_button.disabled = _active_tab == TAB_SKILLS
	needs_tab_button.disabled = _active_tab == TAB_NEEDS
	social_tab_button.disabled = _active_tab == TAB_SOCIAL

func _process(delta: float) -> void:
	if not visible or _fisherman == null or not is_instance_valid(_fisherman):
		return
	_needs_tick_accumulator += delta
	if _needs_tick_accumulator >= NEEDS_TICK_INTERVAL:
		_needs_tick_accumulator = 0.0
		_refresh_needs()

## Any code path that hides this panel — the close/dismiss buttons, or
## main.gd switching to a different panel — ends up here, so the stats
## subscription never leaks onto a fisherman we're no longer showing.
func _on_visibility_changed() -> void:
	if not visible:
		_unsubscribe()

func show_fisherman(fisherman: Node) -> void:
	_unsubscribe()
	_fisherman = fisherman
	_fisherman.stats_changed.connect(refresh)
	_dismiss_armed = false
	dismiss_button.text = "Dismiss"
	visible = true
	_update_perks_label()
	refresh()

## Perks never change after hire, so this only needs to run once per
## fisherman shown, not on every refresh().
func _update_perks_label() -> void:
	if _fisherman.perks.is_empty():
		perks_label.text = "No perks"
		return
	var parts: Array = []
	for perk_name in _fisherman.perks:
		parts.append("%s (%s)" % [perk_name, _fisherman.get_perk_description(perk_name)])
	perks_label.text = "Perks: " + ", ".join(parts)

func _unsubscribe() -> void:
	if _fisherman != null and is_instance_valid(_fisherman) and _fisherman.stats_changed.is_connected(refresh):
		_fisherman.stats_changed.disconnect(refresh)

func refresh() -> void:
	if _fisherman == null or not is_instance_valid(_fisherman):
		visible = false
		return
	name_label.text = _fisherman.display_name
	rank_label.text = _fisherman.get_rank_title()
	_update_favorite_button()
	_update_spot_button()
	_update_expedition_button()
	# Can't dismiss someone who isn't on the island right now.
	dismiss_button.disabled = _fisherman.state == _fisherman.State.EXPEDITION
	speed_label.text = "Speed: Lvl %d" % _fisherman.get_level(_fisherman.speed_xp)
	speed_bar.value = _fisherman.get_level_progress(_fisherman.speed_xp)
	luck_label.text = "Luck: Lvl %d" % _fisherman.get_level(_fisherman.luck_xp)
	luck_bar.value = _fisherman.get_level_progress(_fisherman.luck_xp)
	power_label.text = "Power: Lvl %d" % _fisherman.get_level(_fisherman.power_xp)
	power_bar.value = _fisherman.get_level_progress(_fisherman.power_xp)
	endurance_label.text = "Endurance: Lvl %d" % _fisherman.get_level(_fisherman.endurance_xp)
	endurance_bar.value = _fisherman.get_level_progress(_fisherman.endurance_xp)
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.text = "%s\n%s" % [slot_name, _fisherman.get_slot_display(slot_name)]
	history_label.text = _fisherman.get_recent_catches_text()
	_refresh_friends()
	conversations_label.text = _fisherman.get_conversations_text()
	_refresh_needs()

## Friends never change composition mid-open the way needs do, but a chat
## finishing while the panel is open should still be reflected — cheap
## enough to just rebuild on every refresh() rather than diffing rows.
func _refresh_friends() -> void:
	for child in friends_list.get_children():
		child.queue_free()
	var friends: Array = SocialHub.top_friends(_fisherman.fisherman_id)
	friends_empty_label.visible = friends.is_empty()
	for friend in friends:
		var row: ListRow = LIST_ROW_SCENE.instantiate()
		row.pressed.connect(_on_friend_row_pressed.bind(friend.id))
		friends_list.add_child(row)
		row.setup(SocialHub.name_for(friend.id), "", "%d/100" % int(friend.score))

func _on_friend_row_pressed(friend_id: int) -> void:
	friend_selected.emit(friend_id)

## Separate from refresh() because needs change every frame (not just on a
## catch) — called both here for an immediate value on open/catch, and
## from the throttled _process ticker above while the panel stays open.
func _refresh_needs() -> void:
	_set_need_row(hunger_label, hunger_bar, "Hunger", "hunger")
	_set_need_row(thirst_label, thirst_bar, "Thirst", "thirst")
	_set_need_row(rest_label, rest_bar, "Rest", "rest")
	_set_need_row(social_label, social_bar, "Company", "social")
	_refresh_mood()

## Named bands for the 0..1 mood value, coarse enough that the label isn't
## flickering between words while the bar moves. Ascending; the first
## entry whose ceiling the mood clears names it.
const MOOD_BANDS := [
	{"below": 0.2, "name": "Miserable"},
	{"below": 0.4, "name": "Down"},
	{"below": 0.6, "name": "Content"},
	{"below": 0.8, "name": "Cheerful"},
	{"below": 1.01, "name": "Elated"},
]

## Unlike the three need bars above, this one is NOT inverted — mood is
## already "more is better", so the bar fills as the fisherman cheers up.
## The percentage is spelled out because mood actually moves every stat;
## hiding that would make a fisherman quietly underperform for no visible
## reason.
func _refresh_mood() -> void:
	mood_bar.value = _fisherman.mood
	var band_name := "Content"
	for band in MOOD_BANDS:
		if _fisherman.mood < band.below:
			band_name = band.name
			break
	var percent := roundi((_fisherman.get_mood_multiplier() - 1.0) * 100.0)
	var sign_text := "+" if percent >= 0 else ""
	mood_label.text = "Mood: %s (%s%d%%)" % [band_name, sign_text, percent]
	favorite_weather_label.text = "Favorite weather: %s" % (_fisherman.favorite_weather if not _fisherman.favorite_weather.is_empty() else "—")

func _set_need_row(label: Label, bar: ProgressBar, title: String, need: String) -> void:
	# get_need_progress() is "how close to due" (0 = just serviced, 1 = due) —
	# the right shape for game logic, but a satisfaction meter that empties
	# out as a need grows reads more naturally than one that fills up, so
	# the bar shows the inverse of the raw progress value.
	bar.value = 1.0 - _fisherman.get_need_progress(need)
	var status := "OK"
	if _fisherman.current_need == need:
		status = "Handling..."
	elif _fisherman.is_need_due(need):
		status = "Due"
	label.text = "%s: %s" % [title, status]

## A hollow ☆ is unreadable at the pixel font's 7px cap height, so both
## states use the filled star and colour carries the meaning instead.
## Every state colour is overridden, otherwise hovering an unfavourited
## star would light it up as though it were already set.
const FAVORITE_ON := Color(0.95, 0.75, 0.2)
const FAVORITE_OFF := Color(0.55, 0.5, 0.42)

func _update_favorite_button() -> void:
	var color := FAVORITE_ON if _fisherman.is_favorite else FAVORITE_OFF
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		favorite_button.add_theme_color_override(state, color)

func _on_favorite_button_pressed() -> void:
	if _fisherman == null:
		return
	_fisherman.toggle_favorite()
	_update_favorite_button()

## Cycles through the spots the player owns. With only the pond unlocked
## there is nothing to choose, so the button says why instead of looking
## broken when pressing it does nothing. Also disabled while away on
## expedition — there's no spot to reassign someone who isn't there.
func _update_spot_button() -> void:
	var away: bool = _fisherman.state == _fisherman.State.EXPEDITION
	var available := FishingSpots.unlocked_ids()
	spot_button.text = "Fishing: %s" % FishingSpots.display_name(_fisherman.fishing_spot)
	spot_button.disabled = away or available.size() < 2
	if away:
		spot_button.tooltip_text = "Away on an expedition."
	else:
		spot_button.tooltip_text = FishingSpots.get_spot(_fisherman.fishing_spot).blurb \
			if available.size() > 1 else "Unlock another spot in the Meta shop."

func _on_spot_button_pressed() -> void:
	if _fisherman == null:
		return
	var available := FishingSpots.unlocked_ids()
	if available.size() < 2:
		return
	var index := available.find(_fisherman.fishing_spot)
	_fisherman.set_fishing_spot(available[(index + 1) % available.size()])
	_update_spot_button()

## Hidden until Expeditions is unlocked in the Meta shop; while away, shows
## the countdown instead of the call-to-action and disables the button so
## it can't be pressed again mid-trip.
func _update_expedition_button() -> void:
	expedition_button.visible = MetaProgress.has_expeditions_unlocked()
	if not expedition_button.visible:
		return
	var away: bool = _fisherman.state == _fisherman.State.EXPEDITION
	expedition_button.disabled = away
	if away:
		expedition_button.text = "On expedition — back in %s" % _fisherman.get_expedition_time_left_text()
		expedition_button.tooltip_text = "This fisherman is off-island and will return with a catch."
	else:
		expedition_button.text = "Send on Expedition"
		expedition_button.tooltip_text = "40 minutes away, earns nothing and needs pause, but guarantees a rare+ catch no fishing spot can reach."

func _on_expedition_button_pressed() -> void:
	if _fisherman == null:
		return
	_fisherman.send_on_expedition()
	_update_expedition_button()
	_update_spot_button()

func _on_slot_pressed(slot_name: String) -> void:
	if _fisherman != null:
		slot_clicked.emit(_fisherman, slot_name)

func _on_dismiss_button_pressed() -> void:
	if _fisherman == null:
		return
	if not _dismiss_armed:
		_dismiss_armed = true
		dismiss_button.text = "Confirm dismiss?"
		return
	dismiss_requested.emit(_fisherman)
	visible = false
	_fisherman = null

func _on_close_button_pressed() -> void:
	visible = false
	_fisherman = null
