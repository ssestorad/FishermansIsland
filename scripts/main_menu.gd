extends Control

@onready var menu_box: VBoxContainer = $CenterContainer/VBoxContainer
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var settings_panel: Panel = $SettingsPanel
@onready var fullscreen_checkbox: CheckBox = $SettingsPanel/MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var settings_back_button: Button = $SettingsPanel/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	fullscreen_checkbox.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

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

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
