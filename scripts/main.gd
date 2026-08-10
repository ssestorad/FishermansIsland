extends Node2D

const FISHERMAN_SCENE := preload("res://scenes/entities/Fisherman.tscn")
const STARTING_FISHERMEN_COUNT := 1
const MAX_FISHERMEN_SLOTS := 6
const ROW_SPACING := 35.0
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
	# The bench count in the world drawing depends on the meta upgrade —
	# without this, buying more benches wouldn't visually show up until
	# something else happened to trigger a redraw.
	MetaProgress.updated.connect(func(): queue_redraw())

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
	DockInventory.load_state(data.get("dock", []))
	MetaProgress.load_state(data.get("meta_progress", {}))
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
	var row_y := 110.0 + index * ROW_SPACING
	fisherman.home_position = Vector2(80, row_y)
	fisherman.dock_position = Vector2(320, row_y)

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
		fisherman.perks = PerkCatalog.roll_perk_names(randi_range(1, 2))

	add_child(fisherman)
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
	return MAX_FISHERMEN_SLOTS + MetaProgress.extra_slots

func _hire_cost_for_next_slot() -> int:
	return int(round(BASE_HIRE_COST * pow(HIRE_COST_GROWTH, fishermen.size() - 1)))

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

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.55, 0.72, 0.38))
	draw_rect(Rect2(280, 80, 40, 240), Color(0.82, 0.72, 0.5))
	draw_rect(Rect2(300, 100, 300, 200), Color(0.22, 0.45, 0.65))
	for i in range(4):
		var y := 130.0 + i * 45.0
		draw_line(Vector2(320, y), Vector2(580, y), Color(0.35, 0.58, 0.75, 0.5), 2.0)
	draw_rect(Rect2(305, 95, 22, 210), Color(0.5, 0.35, 0.2))
	_draw_need_stations()

## Flat-rect markers for the storage/grill/beer/bench points, matching the
## rest of this placeholder world's style — no new art assets, per the
## "mechanic only for now" scope of the needs system.
func _draw_need_stations() -> void:
	# Storage: a small shed near the top of the home lane column (x=80),
	# where every catch gets carried regardless of which row a fisherman
	# is on.
	draw_rect(Rect2(72, 84, 16, 14), Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(70, 80, 20, 6), Color(0.32, 0.22, 0.14))

	# Grill: dark base + a warm coal glow on top.
	var grill_pos := NeedStations.GRILL_POSITION
	draw_rect(Rect2(grill_pos + Vector2(-6, -4), Vector2(12, 8)), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(grill_pos + Vector2(-4, -6), Vector2(8, 4)), Color(0.85, 0.4, 0.15))

	# Beer crate: a wooden box with a couple of bottle caps peeking out.
	var beer_pos := NeedStations.BEER_POSITION
	draw_rect(Rect2(beer_pos + Vector2(-7, -6), Vector2(14, 12)), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(beer_pos + Vector2(-4, -9), Vector2(3, 4)), Color(0.75, 0.65, 0.2))
	draw_rect(Rect2(beer_pos + Vector2(1, -9), Vector2(3, 4)), Color(0.75, 0.65, 0.2))

	# Benches: one small plank per currently-available slot, so the drawn
	# count always matches what the meta-shop upgrade actually grants.
	for bench_pos in NeedStations.bench_positions():
		draw_rect(Rect2(bench_pos + Vector2(-7, -2), Vector2(14, 4)), Color(0.55, 0.4, 0.24))
