class_name PanelController
extends Panel

## Shared close-button wiring and toggle/build skeleton every zone-A panel
## used to hand-roll identically. `$MarginContainer/VBoxContainer/HeaderRow/
## CloseButton` is the same relative path in every panel scene that has one
## — panels without a close button (ItemDetailPanel, WelcomeBackPanel) stay
## on plain `Panel` rather than inheriting a dangling reference here.

@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	_on_ready()

## Override point for whatever setup used to live in a subclass's own
## _ready() — this class already claims _ready() itself.
func _on_ready() -> void:
	pass

## The common no-arg case. Panels that need an argument (e.g.
## `toggle(fishermen)`) or that rebuild via a differently-named method
## (e.g. `refresh()` instead of `build()`) override this entirely.
func toggle() -> void:
	visible = not visible
	if visible:
		build()

## Override point: what toggle() should do once it's just turned this
## panel on.
func build() -> void:
	pass

func _on_close_button_pressed() -> void:
	visible = false
