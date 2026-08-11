extends Control

@onready var menu_box: VBoxContainer = $MenuBox
@onready var play_button: Button = $MenuBox/PlayButton
@onready var settings_button: Button = $MenuBox/SettingsButton
@onready var quit_button: Button = $MenuBox/QuitButton
@onready var settings_panel: Panel = $SettingsPanel
@onready var fullscreen_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/FullscreenButton
@onready var settings_back_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_update_fullscreen_button()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_settings_pressed() -> void:
	menu_box.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	menu_box.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

## A plain Button rather than a CheckBox: CheckBox draws its tick from
## Godot's built-in vector icons, which have no pixel-art counterpart in
## the theme and stood out badly next to everything else.
func _on_fullscreen_pressed() -> void:
	var going_fullscreen := not _is_fullscreen()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if going_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_update_fullscreen_button()

func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _update_fullscreen_button() -> void:
	fullscreen_button.text = "Fullscreen: On" if _is_fullscreen() else "Fullscreen: Off"
