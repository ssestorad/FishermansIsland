extends Node2D

const STARTING_FISHERMEN_COUNT := 1
const MAX_FISHERMEN_SLOTS := 6
const BASE_HIRE_COST := 5
const HIRE_COST_GROWTH := 1.25

const OFFLINE_EFFICIENCY := 0.5
const OFFLINE_CAP_SECONDS := 12.0 * 3600.0
const MIN_OFFLINE_SECONDS_TO_SHOW := 60.0

@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var scales_label: Label = $CanvasLayer/ScalesLabel
@onready var fishermen_button: Button = $CanvasLayer/NavRow/FishermenButton
@onready var hire_button: Button = $CanvasLayer/NavRow/HireButton
@onready var album_button: Button = $CanvasLayer/NavRow/AlbumButton
@onready var shop_button: Button = $CanvasLayer/NavRow/ShopButton
@onready var meta_button: Button = $CanvasLayer/NavRow/MetaButton
@onready var dock_button: Button = $CanvasLayer/NavRow/DockButton
@onready var stats_button: Button = $CanvasLayer/NavRow/StatsButton
@onready var quests_button: Button = $CanvasLayer/NavRow/QuestsButton
@onready var menu_button: Button = $CanvasLayer/NavRow/MenuButton
@onready var fishermen_panel: FishermenPanelController = $CanvasLayer/FishermenPanel
@onready var album_panel: AlbumPanelController = $CanvasLayer/AlbumPanel
@onready var shop_panel: ShopPanelController = $CanvasLayer/ShopPanel
@onready var meta_panel: MetaPanelController = $CanvasLayer/MetaPanel
@onready var dock_panel: DockPanelController = $CanvasLayer/DockPanel
@onready var stats_panel: StatsPanelController = $CanvasLayer/StatsPanel
@onready var quest_panel: QuestPanelController = $CanvasLayer/QuestPanel
@onready var profile_panel: FishermanProfilePanelController = $CanvasLayer/FishermanProfilePanel
@onready var equip_panel: EquipPanelController = $CanvasLayer/EquipPanel
@onready var item_detail_panel: ItemDetailPanelController = $CanvasLayer/ItemDetailPanel
@onready var welcome_back_panel: WelcomeBackPanelController = $CanvasLayer/WelcomeBackPanel
@onready var autosave_timer: Timer = $AutosaveTimer
@onready var world_renderer: WorldRenderer = $WorldRenderer
@onready var station_carry: StationCarryController = $StationCarry

var fishermen: Array = []
var _zone_a_panels: Array = []

func _ready() -> void:
	get_viewport().physics_object_picking = true
	DevConsole.register_main(self)
	_zone_a_panels = [fishermen_panel, album_panel, shop_panel, meta_panel, dock_panel, stats_panel, quest_panel]

	if SaveManager.has_save():
		_load_game()
	else:
		_spawn_starting_fishermen()

	_update_coins_label(Economy.coins)
	_update_scales_label(Economy.scales)
	Economy.coins_changed.connect(_update_coins_label)
	Economy.scales_changed.connect(_update_scales_label)

	fishermen_button.pressed.connect(_on_fishermen_button_pressed)
	hire_button.pressed.connect(_on_hire_button_pressed)
	album_button.pressed.connect(_on_album_button_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	meta_button.pressed.connect(_on_meta_button_pressed)
	dock_button.pressed.connect(_on_dock_button_pressed)
	stats_button.pressed.connect(_on_stats_button_pressed)
	quests_button.pressed.connect(_on_quests_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

	fishermen_panel.fisherman_selected.connect(_show_profile)
	profile_panel.dismiss_requested.connect(_on_dismiss_requested)
	profile_panel.slot_clicked.connect(_on_slot_clicked)
	equip_panel.back_requested.connect(_on_equip_back_requested)
	shop_panel.item_detail_requested.connect(_on_item_detail_requested)
	shop_panel.potion_detail_requested.connect(_on_potion_detail_requested)
	equip_panel.item_detail_requested.connect(_on_equip_item_detail_requested)
	equip_panel.item_detail_dismissed.connect(item_detail_panel.hide_item)
	shop_panel.item_detail_dismissed.connect(item_detail_panel.hide_item)

	autosave_timer.timeout.connect(_on_autosave_timeout)
	MetaProgress.updated.connect(_update_hire_button)
	# The jetty only appears once Offshore is bought, and nothing else
	# repaints the world layer.
	MetaProgress.updated.connect(func(): world_renderer.queue_redraw())

	station_carry.spawn_stations()
	_update_hire_button()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game(fishermen)
		get_tree().quit()

func _exit_tree() -> void:
	DevConsole.unregister_main(self)

func _load_game() -> void:
	var data := SaveManager.load_data()
	Economy.load_state(int(data.get("coins", 0)), int(data.get("scales", 0)))
	var album_data: Dictionary = data.get("album", {})
	Album.load_state(album_data.get("caught_counts", {}), album_data.get("best_weights", {}), album_data.get("record_holders", {}))
	WorldClock.load_state(float(data.get("elapsed_time", 0.0)))
	Inventory.load_state(data.get("inventory", []))
	# MetaProgress must load before DockInventory: DockInventory.load_state()
	# trims to capacity() immediately, which reads MetaProgress's dock
	# capacity level — loading in the other order would treat a
	# capacity-upgraded save's real entries as overflow and auto-sell them.
	MetaProgress.load_state(data.get("meta_progress", {}))
	DockInventory.load_state(data.get("dock", []))
	# Same ordering trap: NeedStations clamps each station against its
	# footprint, and the bench cluster's footprint grows with the purchased
	# bench capacity.
	NeedStations.load_state(data.get("stations", {}))
	# Must load before the fisherman loop below: it holds the id counter,
	# and every fisherman either reserves its saved id against it or mints
	# a fresh one from it.
	SocialHub.load_state(data.get("social", {}))
	QuestManager.load_state(data.get("quests", {}))
	var saved_fishermen: Array = data.get("fishermen", [])
	if saved_fishermen.is_empty():
		_spawn_starting_fishermen()
		return
	for fisherman_data in saved_fishermen:
		_spawn_fisherman(fisherman_data)
	_apply_offline_progress(data)

func _apply_offline_progress(data: Dictionary) -> void:
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at <= 0.0:
		return
	var real_elapsed := maxf(0.0, float(Time.get_unix_time_from_system()) - saved_at)
	var capped_elapsed := minf(real_elapsed, OFFLINE_CAP_SECONDS)
	var effective_seconds := capped_elapsed * (OFFLINE_EFFICIENCY + MetaProgress.get_offline_efficiency_bonus())
	if effective_seconds < MIN_OFFLINE_SECONDS_TO_SHOW:
		return

	var result := _resolve_offline_batch(effective_seconds)
	if result.catches > 0:
		welcome_back_panel.show_summary(real_elapsed, result.catches, result.coins, result.docked, result.best)

## Rolls `effective_seconds` worth of offline catches for every fisherman
## and accumulates the totals. Shared by the real load path above and the
## dev console's "Simulate Offline" button, so this loop only lives once.
func _resolve_offline_batch(effective_seconds: float) -> Dictionary:
	var total_catches := 0
	var total_coins := 0
	var total_docked := 0
	var best_summary: Dictionary = {}
	for fisherman in fishermen:
		var summary: Dictionary = fisherman.resolve_offline_catches(effective_seconds)
		total_catches += summary.catches
		total_coins += summary.coins
		total_docked += summary.docked
		if summary.catches > 0 and (
			best_summary.is_empty()
			or summary.best_rarity > best_summary.best_rarity
			or (summary.best_rarity == best_summary.best_rarity and summary.best_weight > best_summary.best_weight)
		):
			best_summary = {
				"best_species": summary.best_species,
				"best_rarity": summary.best_rarity,
				"best_weight": summary.best_weight,
			}
	return {
		"catches": total_catches,
		"coins": total_coins,
		"docked": total_docked,
		"best": best_summary,
	}

func _spawn_starting_fishermen() -> void:
	for i in range(STARTING_FISHERMEN_COUNT):
		var fisherman := _spawn_fisherman()
		fisherman.speed_xp = randf_range(0.0, 40.0)
		fisherman.luck_xp = randf_range(0.0, 40.0)
		fisherman.power_xp = randf_range(0.0, 40.0)
		fisherman.endurance_xp = randf_range(0.0, 40.0)

func _spawn_fisherman(saved_data: Dictionary = {}) -> Node:
	var fisherman := FishermanFactory.build(fishermen.size(), saved_data)
	add_child(fisherman)
	# After add_child so _ready() has run and the node can react to the
	# assignment; also drops a spot the player has since lost access to.
	if not FishingSpots.is_unlocked(fisherman.fishing_spot):
		fisherman.fishing_spot = FishingSpots.POND
	fisherman.set_fishing_spot(fisherman.fishing_spot)
	fisherman.position = fisherman.home_position
	fishermen.append(fisherman)
	fisherman.clicked.connect(_show_profile)
	return fisherman

func _on_hire_button_pressed() -> void:
	if fishermen.size() >= _max_fishermen_slots():
		return
	var cost := _hire_cost_for_next_slot()
	if Economy.spend_coins(cost):
		_spawn_fisherman()
		_update_hire_button()

func _max_fishermen_slots() -> int:
	# Extra Fisherman Slot is meant to be purchasable up to MAX_EXTRA_SLOTS
	# (30 total, the originally-envisioned island cap) — the meta panel's
	# buy handler already stops the player there, this is the defensive
	# match to that, same spirit as get_shop_discount()'s value clamp.
	return MAX_FISHERMEN_SLOTS + mini(MetaProgress.extra_slots, MetaProgress.MAX_EXTRA_SLOTS)

func _hire_cost_for_next_slot() -> int:
	var base_cost := BASE_HIRE_COST * pow(HIRE_COST_GROWTH, fishermen.size() - 1)
	return int(round(base_cost * (1.0 - MetaProgress.get_hire_discount())))

func _update_hire_button() -> void:
	var max_slots := _max_fishermen_slots()
	if fishermen.size() >= max_slots:
		hire_button.text = "Full (%d/%d)" % [fishermen.size(), max_slots]
		hire_button.disabled = true
	else:
		var cost := _hire_cost_for_next_slot()
		hire_button.text = "Hire (%d)" % cost
		hire_button.disabled = Economy.coins < cost

## All zone-A panels (Fishermen/Album/Shop/Meta/Dock/Stats) share the same
## screen rect and are mutually exclusive — this hides every one of them
## except whichever the caller is about to toggle.
func _hide_other_zone_a_panels(except_panel: Node) -> void:
	for panel in _zone_a_panels:
		if panel != except_panel:
			panel.visible = false

func _on_fishermen_button_pressed() -> void:
	_hide_other_zone_a_panels(fishermen_panel)
	fishermen_panel.open(fishermen)

func _on_album_button_pressed() -> void:
	_hide_other_zone_a_panels(album_panel)
	album_panel.toggle()

func _on_shop_button_pressed() -> void:
	_hide_other_zone_a_panels(shop_panel)
	shop_panel.toggle()

func _on_meta_button_pressed() -> void:
	_hide_other_zone_a_panels(meta_panel)
	meta_panel.toggle()

func _on_dock_button_pressed() -> void:
	_hide_other_zone_a_panels(dock_panel)
	dock_panel.toggle()

func _on_stats_button_pressed() -> void:
	_hide_other_zone_a_panels(stats_panel)
	stats_panel.open(fishermen)

func _on_quests_button_pressed() -> void:
	_hide_other_zone_a_panels(quest_panel)
	quest_panel.toggle()

func _on_menu_button_pressed() -> void:
	SaveManager.save_game(fishermen)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

## Shown without a wearer: a shop preview has no fisherman, so the spot
## argument is left empty and spot-conditional bonuses read as inactive.
func _on_item_detail_requested(item: Item) -> void:
	item_detail_panel.show_item(item)

func _on_potion_detail_requested(axis: String, cost: int, tint: Color) -> void:
	item_detail_panel.show_potion(axis, cost, tint)

## The equip panel occupies the right-hand slot, so its read-out opens on
## the left, and it can pass the wearer's spot so spot-conditional gear
## reports whether it would actually pay out for this fisherman.
func _on_equip_item_detail_requested(item: Item, spot: String) -> void:
	item_detail_panel.show_item(item, spot, true)

func _show_profile(fisherman: Node) -> void:
	# The click that drops a carried station would otherwise also open the
	# profile of whichever fisherman happened to be under the cursor.
	if station_carry.is_carrying():
		return
	equip_panel.visible = false
	fishermen_panel.visible = false
	profile_panel.show_fisherman(fisherman)

func _on_slot_clicked(fisherman: Node, slot_name: String) -> void:
	profile_panel.visible = false
	equip_panel.open_for(fisherman, slot_name)

func _on_equip_back_requested(fisherman: Node) -> void:
	equip_panel.visible = false
	if fisherman != null and is_instance_valid(fisherman):
		profile_panel.show_fisherman(fisherman)

func _on_dismiss_requested(fisherman: Node) -> void:
	for slot in fisherman.equipped_items:
		var item = fisherman.equipped_items[slot]
		if item != null:
			Inventory.add_item(item)
	# Someone dismissed mid-need still holds a slot, and freeing the node
	# is not what releases it — without this a bench (or a spot at the
	# gathering point) stays occupied by a fisherman who no longer exists.
	fisherman.release_claimed_slots()
	SocialHub.forget_fisherman(fisherman.fisherman_id)
	fishermen.erase(fisherman)
	fisherman.queue_free()
	_update_hire_button()

func _on_autosave_timeout() -> void:
	SaveManager.save_game(fishermen)

func _update_coins_label(new_total: int) -> void:
	coins_label.text = "%d" % new_total
	_update_hire_button()

func _update_scales_label(new_total: int) -> void:
	scales_label.text = "%d" % new_total
