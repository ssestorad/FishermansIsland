extends Node2D

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")
const STATION_SCENE := preload("res://scenes/entities/Station.tscn")
const STATION_IDS := ["storage", "grill", "beer", "benches"]
const STARTING_FISHERMEN_COUNT := 1
const MAX_FISHERMEN_SLOTS := 6
const ROW_SPACING := 35.0
## Per-fisherman rows are laid out top-to-bottom starting at y=110; without
## a ceiling this runs straight off the 360px-tall world once the roster
## grows past ~7 (extra_slots is uncapped, so that's routine, not an edge
## case). Rows beyond this clamp stack on the last one instead of walking
## fishermen off-screen — visually crowded at a big roster, but never
## invisible. dock_y_bounds already protects the fishing point the same
## way; this is the equivalent guard for home/storage.
const MAX_HOME_ROW_Y := 320.0
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
@onready var menu_button: Button = $CanvasLayer/NavRow/MenuButton
@onready var fishermen_panel: FishermenPanelController = $CanvasLayer/FishermenPanel
@onready var album_panel: AlbumPanelController = $CanvasLayer/AlbumPanel
@onready var shop_panel: ShopPanelController = $CanvasLayer/ShopPanel
@onready var meta_panel: MetaPanelController = $CanvasLayer/MetaPanel
@onready var dock_panel: DockPanelController = $CanvasLayer/DockPanel
@onready var stats_panel: StatsPanelController = $CanvasLayer/StatsPanel
@onready var profile_panel: FishermanProfilePanelController = $CanvasLayer/FishermanProfilePanel
@onready var equip_panel: EquipPanelController = $CanvasLayer/EquipPanel
@onready var welcome_back_panel: WelcomeBackPanelController = $CanvasLayer/WelcomeBackPanel
@onready var autosave_timer: Timer = $AutosaveTimer

var fishermen: Array = []
var _zone_a_panels: Array = []

## Station currently stuck to the cursor, or null. Right-click picks one
## up, the next click drops it, Escape puts it back.
var _carried_station: Node = null
var _carried_origin := Vector2.ZERO
var _stations: Array = []

func _ready() -> void:
	get_viewport().physics_object_picking = true
	DevConsole.register_main(self)
	_zone_a_panels = [fishermen_panel, album_panel, shop_panel, meta_panel, dock_panel, stats_panel]

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
	menu_button.pressed.connect(_on_menu_button_pressed)

	fishermen_panel.fisherman_selected.connect(_show_profile)
	profile_panel.dismiss_requested.connect(_on_dismiss_requested)
	profile_panel.slot_clicked.connect(_on_slot_clicked)
	equip_panel.back_requested.connect(_on_equip_back_requested)

	autosave_timer.timeout.connect(_on_autosave_timeout)
	MetaProgress.updated.connect(_update_hire_button)
	# The jetty only appears once Offshore is bought, and nothing else
	# repaints the world layer.
	MetaProgress.updated.connect(func(): queue_redraw())

	_spawn_stations()
	_update_hire_button()

func _spawn_stations() -> void:
	for id in STATION_IDS:
		var station := STATION_SCENE.instantiate()
		station.station_id = id
		station.position = NeedStations.get_station_position(id)
		station.pickup_requested.connect(_on_station_pickup_requested)
		add_child(station)
		_stations.append(station)
	# Covers both a station being dropped somewhere new and the bench
	# cluster's layout shifting when its capacity is upgraded.
	NeedStations.stations_moved.connect(_sync_station_positions)

func _sync_station_positions() -> void:
	for station in _stations:
		if station != _carried_station:
			station.position = NeedStations.get_station_position(station.station_id)
		station.queue_redraw()

func _on_station_pickup_requested(station: Node) -> void:
	if _carried_station != null:
		return
	_carried_station = station
	_carried_origin = station.position
	station.is_carried = true
	_update_carried_station(get_global_mouse_position())

## Snaps the carried station to the placement grid and tells it whether
## the spot under the cursor is legal, which drives its green/red outline.
func _update_carried_station(mouse_position: Vector2) -> void:
	var snapped := WorldLayout.snap(mouse_position)
	_carried_station.position = snapped
	var footprint := NeedStations.footprint_at(_carried_station.station_id, snapped)
	_carried_station.placement_valid = WorldLayout.is_placeable(footprint)
	_carried_station.queue_redraw()

func _drop_carried_station() -> void:
	if not _carried_station.placement_valid:
		return
	var station := _carried_station
	_carried_station = null
	station.is_carried = false
	# move_station() re-snaps and emits stations_moved, which is what
	# nudges any fisherman already walking to re-target.
	NeedStations.move_station(station.station_id, station.position)

func _cancel_carried_station() -> void:
	var station := _carried_station
	_carried_station = null
	station.is_carried = false
	station.position = _carried_origin
	station.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _carried_station == null:
		return
	if event is InputEventMouseMotion:
		_update_carried_station(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_drop_carried_station()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_carried_station()
		get_viewport().set_input_as_handled()

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

	if total_catches > 0:
		welcome_back_panel.show_summary(real_elapsed, total_catches, total_coins, total_docked, best_summary)

func _spawn_starting_fishermen() -> void:
	for i in range(STARTING_FISHERMEN_COUNT):
		var fisherman := _spawn_fisherman()
		fisherman.speed_xp = randf_range(0.0, 40.0)
		fisherman.luck_xp = randf_range(0.0, 40.0)
		fisherman.power_xp = randf_range(0.0, 40.0)
		fisherman.endurance_xp = randf_range(0.0, 40.0)

func _spawn_fisherman(saved_data: Dictionary = {}) -> Node:
	var index := fishermen.size()
	var fisherman := FISHERMAN_SCENE.instantiate()
	fisherman.name = "Fisherman_%d" % (index + 1)
	var row_y := minf(110.0 + index * ROW_SPACING, MAX_HOME_ROW_Y)
	fisherman.home_position = Vector2(80, row_y)
	fisherman.lane_y = row_y
	# dock_position follows from the spot; set_fishing_spot() is called
	# once the saved assignment (if any) has been read below.

	if not saved_data.is_empty():
		fisherman.display_name = saved_data.get("display_name", "")
		fisherman.speed_xp = float(saved_data.get("speed_xp", 0.0))
		fisherman.luck_xp = float(saved_data.get("luck_xp", 0.0))
		fisherman.power_xp = float(saved_data.get("power_xp", 0.0))
		fisherman.endurance_xp = float(saved_data.get("endurance_xp", 0.0))
		fisherman.perks = saved_data.get("perks", [])
		fisherman.total_catches = int(saved_data.get("total_catches", 0))
		var raw_history: Array = saved_data.get("catch_history", [])
		var loaded_history: Array = []
		for raw in raw_history:
			if raw is Dictionary and raw.has("species") and raw.has("tier") and raw.has("weight") and raw.has("day"):
				loaded_history.append({
					"species": raw.species,
					"tier": int(raw.tier),
					"weight": float(raw.weight),
					"day": int(raw.day),
				})
		fisherman.catch_history = loaded_history
		fisherman.best_catch_tier = int(saved_data.get("best_catch_tier", 0))
		fisherman.is_favorite = bool(saved_data.get("is_favorite", false))
		# Saves from before fishing spots existed have everyone at the
		# pier, which is where they all used to stand.
		fisherman.fishing_spot = str(saved_data.get("fishing_spot", FishingSpots.PIER))
		var equipped: Dictionary = saved_data.get("equipped_items", {})
		for slot in equipped:
			var item_name = equipped[slot]
			if item_name is String:
				var item := SaveManager.find_item_by_name(item_name)
				if item != null:
					fisherman.equipped_items[slot] = item
		if saved_data.has("appearance_variant"):
			fisherman.set_appearance_variant(int(saved_data.get("appearance_variant")))
	else:
		var perk_count_range := Vector2i(2, 3) if MetaProgress.has_extra_perk_slot() else Vector2i(1, 2)
		fisherman.perks = PerkCatalog.roll_perk_names(randi_range(perk_count_range.x, perk_count_range.y))

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
	fishermen_panel.toggle(fishermen)

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
	stats_panel.toggle(fishermen)

func _on_menu_button_pressed() -> void:
	SaveManager.save_game(fishermen)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _show_profile(fisherman: Node) -> void:
	# The click that drops a carried station would otherwise also open the
	# profile of whichever fisherman happened to be under the cursor.
	if _carried_station != null:
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

## Painted from WorldLayout so station placement validates against the
## same geometry that is drawn here.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WorldLayout.WORLD_SIZE), WorldLayout.LAND_COLOR)
	draw_rect(WorldLayout.SAND_RECT, WorldLayout.SAND_COLOR)
	draw_rect(WorldLayout.WATER_RECT, WorldLayout.WATER_COLOR)
	for i in range(4):
		var y := 130.0 + i * 45.0
		draw_line(Vector2(320, y), Vector2(580, y), WorldLayout.WAVE_COLOR, 2.0)
	draw_rect(WorldLayout.PIER_RECT, WorldLayout.PIER_COLOR)
	_draw_pond()
	# Only exists once bought, so the purchase visibly builds something.
	if FishingSpots.is_unlocked(FishingSpots.OFFSHORE):
		draw_rect(WorldLayout.JETTY_RECT, WorldLayout.JETTY_COLOR)
		draw_rect(
			Rect2(WorldLayout.JETTY_RECT.position + Vector2(0.0, WorldLayout.JETTY_RECT.size.y - 4.0),
				Vector2(WorldLayout.JETTY_RECT.size.x, 4.0)),
			WorldLayout.JETTY_PLANK_COLOR
		)

func _draw_pond() -> void:
	var pond := WorldLayout.POND_RECT
	draw_rect(pond, WorldLayout.POND_COLOR)
	# A lighter rim reads as shallows and keeps the pond from looking like
	# a hole punched in the grass.
	draw_rect(Rect2(pond.position, Vector2(pond.size.x, 3.0)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position + Vector2(0.0, pond.size.y - 3.0), Vector2(pond.size.x, 3.0)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position, Vector2(3.0, pond.size.y)), WorldLayout.POND_SHALLOW_COLOR)
	draw_rect(Rect2(pond.position + Vector2(pond.size.x - 3.0, 0.0), Vector2(3.0, pond.size.y)), WorldLayout.POND_SHALLOW_COLOR)
