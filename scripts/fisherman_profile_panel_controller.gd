class_name FishermanProfilePanelController
extends Panel

signal dismiss_requested(fisherman)
signal slot_clicked(fisherman, slot_name)

@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderRow/NameLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/RankLabel
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
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

## Needs tick continuously (not just on a catch, unlike the XP bars above),
## so they need their own lightweight poll while the panel is open — same
## throttled-ticker pattern as the Shop's restock/potion countdowns
## (shop_panel_controller.gd), not a naive full-speed _process.
const NEEDS_TICK_INTERVAL := 0.2  # 5/sec

var _fisherman: Node = null
var _dismiss_armed: bool = false
var _needs_tick_accumulator: float = 0.0

func _ready() -> void:
	for slot_button in equipment_slots.get_children():
		var slot_name: String = slot_button.name.trim_suffix("Slot")
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_name))
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	favorite_button.pressed.connect(_on_favorite_button_pressed)
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

func _update_favorite_button() -> void:
	favorite_button.text = "★" if _fisherman.is_favorite else "☆"

func _on_favorite_button_pressed() -> void:
	if _fisherman == null:
		return
	_fisherman.toggle_favorite()
	_update_favorite_button()

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
