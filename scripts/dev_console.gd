extends CanvasLayer

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

@onready var panel: Panel = $Panel
@onready var time_input: LineEdit = $Panel/MarginContainer/VBoxContainer/TimeRow/TimeInput
@onready var coins_input: LineEdit = $Panel/MarginContainer/VBoxContainer/CoinsRow/CoinsInput
@onready var scales_input: LineEdit = $Panel/MarginContainer/VBoxContainer/ScalesRow/ScalesInput
@onready var rarity_option: OptionButton = $Panel/MarginContainer/VBoxContainer/CatchRow/RarityOption
@onready var offline_input: LineEdit = $Panel/MarginContainer/VBoxContainer/OfflineRow/OfflineInput
@onready var log_label: Label = $Panel/MarginContainer/VBoxContainer/LogLabel

var _main: Node = null

func _ready() -> void:
	if not OS.has_feature("debug"):
		queue_free()
		return
	panel.visible = false
	for rarity_name in RARITY_NAMES:
		rarity_option.add_item(rarity_name)
	$Panel/MarginContainer/VBoxContainer/TimeRow/TimeButton.pressed.connect(_on_advance_time)
	$Panel/MarginContainer/VBoxContainer/CoinsRow/CoinsButton.pressed.connect(_on_add_coins)
	$Panel/MarginContainer/VBoxContainer/ScalesRow/ScalesButton.pressed.connect(_on_add_scales)
	$Panel/MarginContainer/VBoxContainer/CatchRow/CatchButton.pressed.connect(_on_force_catch)
	$Panel/MarginContainer/VBoxContainer/OfflineRow/OfflineButton.pressed.connect(_on_simulate_offline)
	$Panel/CloseButton.pressed.connect(_on_close_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event: InputEventKey = event
	# physical_keycode is layout-independent (the "~" key stays in the same
	# physical spot even on non-US layouts); keycode/F1 are backups in case
	# that still doesn't match on a given keyboard.
	var is_toggle_key: bool = (
		key_event.physical_keycode == KEY_QUOTELEFT
		or key_event.keycode == KEY_QUOTELEFT
		or key_event.keycode == KEY_F1
	)
	if is_toggle_key:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	panel.visible = false

## main.gd registers itself here so the console can reach the live
## fisherman roster; unset automatically if the scene goes away.
func register_main(main_node: Node) -> void:
	_main = main_node

func unregister_main(main_node: Node) -> void:
	if _main == main_node:
		_main = null

func _log(text: String) -> void:
	log_label.text = text

func _on_advance_time() -> void:
	var seconds := time_input.text.to_float()
	if seconds <= 0.0:
		_log("Enter a positive number of seconds.")
		return
	WorldClock.elapsed_time += seconds
	_log("Advanced time by %.0fs." % seconds)

func _on_add_coins() -> void:
	var amount := coins_input.text.to_int()
	if amount == 0:
		_log("Enter a non-zero coin amount.")
		return
	Economy.add_coins(amount)
	_log("Added %d coins." % amount)

func _on_add_scales() -> void:
	var amount := scales_input.text.to_int()
	if amount == 0:
		_log("Enter a non-zero scale amount.")
		return
	Economy.add_scales(amount)
	_log("Added %d scales." % amount)

func _on_force_catch() -> void:
	if not _has_main():
		return
	if _main.fishermen.is_empty():
		_log("No fishermen hired yet.")
		return
	var fisherman = _main.fishermen[0]
	var tier: int = rarity_option.selected
	var result: Dictionary = fisherman.debug_force_catch(tier)
	if result.is_empty():
		_log("No %s species eligible under current weather/season." % RARITY_NAMES[tier])
		return
	var outcome: String = "+%d %s" % [result.amount, result.currency] if not result.docked else "sent to dock"
	_log("%s caught a forced %s %s (%.1f kg) — %s." % [
		fisherman.display_name, RARITY_NAMES[tier], result.species.species_name,
		result.weight, outcome
	])

func _on_simulate_offline() -> void:
	if not _has_main():
		return
	var hours := offline_input.text.to_float()
	if hours <= 0.0:
		_log("Enter a positive number of hours.")
		return
	var effective_seconds: float = hours * 3600.0 * (_main.OFFLINE_EFFICIENCY + MetaProgress.get_offline_efficiency_bonus())
	var total_catches := 0
	var total_coins := 0
	var total_scales := 0
	for fisherman in _main.fishermen:
		var summary: Dictionary = fisherman.resolve_offline_catches(effective_seconds)
		total_catches += summary.catches
		total_coins += summary.coins
		total_scales += summary.scales
	_log("Simulated %.1fh offline: %d catches, +%d coins, +%d scales." % [hours, total_catches, total_coins, total_scales])

func _has_main() -> bool:
	if _main == null or not is_instance_valid(_main):
		_log("Open the main game scene first.")
		return false
	return true
