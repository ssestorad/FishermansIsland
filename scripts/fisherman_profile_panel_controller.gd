class_name FishermanProfilePanelController
extends PanelController

signal dismiss_requested(fisherman)
signal slot_clicked(fisherman, slot_name)

@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderRow/NameLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/RankLabel
@onready var spot_button: Button = $MarginContainer/VBoxContainer/SpotButton
@onready var favorite_button: Button = $MarginContainer/VBoxContainer/HeaderRow/FavoriteButton
@onready var speed_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SpeedLabel
@onready var speed_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/SpeedBar
@onready var luck_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/LuckLabel
@onready var luck_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/LuckBar
@onready var power_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/PowerLabel
@onready var power_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/PowerBar
@onready var endurance_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/EnduranceLabel
@onready var endurance_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/EnduranceBar
@onready var hunger_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/HungerLabel
@onready var hunger_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/HungerBar
@onready var thirst_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/ThirstLabel
@onready var thirst_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/ThirstBar
@onready var rest_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/RestLabel
@onready var rest_bar: ProgressBar = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/RestBar
@onready var equipment_slots: HBoxContainer = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/EquipmentSlots
@onready var perks_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/PerksLabel
@onready var history_label: Label = $MarginContainer/VBoxContainer/StatsScroll/StatsBlock/HistoryLabel
@onready var dismiss_button: Button = $MarginContainer/VBoxContainer/DismissButton

## Needs tick continuously (not just on a catch, unlike the XP bars above),
## so they need their own lightweight poll while the panel is open — same
## throttled-ticker pattern as the Shop's restock/potion countdowns
## (shop_panel_controller.gd), not a naive full-speed _process.
const NEEDS_TICK_INTERVAL := 0.2  # 5/sec

var _fisherman: Node = null
var _dismiss_armed: bool = false
var _needs_tick_accumulator: float = 0.0

func _on_ready() -> void:
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_name))
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	favorite_button.pressed.connect(_on_favorite_button_pressed)
	spot_button.pressed.connect(_on_spot_button_pressed)
	visibility_changed.connect(_on_visibility_changed)

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
	_refresh_needs()

## Separate from refresh() because needs change every frame (not just on a
## catch) — called both here for an immediate value on open/catch, and
## from the throttled _process ticker above while the panel stays open.
func _refresh_needs() -> void:
	_set_need_row(hunger_label, hunger_bar, "Hunger", "hunger")
	_set_need_row(thirst_label, thirst_bar, "Thirst", "thirst")
	_set_need_row(rest_label, rest_bar, "Rest", "rest")

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
## broken when pressing it does nothing.
func _update_spot_button() -> void:
	var available := FishingSpots.unlocked_ids()
	spot_button.text = "Fishing: %s" % FishingSpots.display_name(_fisherman.fishing_spot)
	spot_button.disabled = available.size() < 2
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
