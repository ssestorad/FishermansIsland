class_name ItemDetailPanelController
extends Panel

## Full read-out for one item, shown while the cursor rests on a shop row.
##
## The list rows clip hard at the panel width, so Item.summary_text() has
## to drop most of what the gear remake added — the always-on half of a
## conditional piece, the exact bait multipliers, the family it belongs
## to. This panel is where all of that actually fits.

@onready var icon_frame: Panel = $MarginContainer/VBoxContainer/HeaderRow/IconFrame
@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleBlock/NameLabel
@onready var kind_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleBlock/KindLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var effects_label: Label = $MarginContainer/VBoxContainer/EffectsLabel
@onready var conditional_label: Label = $MarginContainer/VBoxContainer/ConditionalLabel
@onready var bias_label: Label = $MarginContainer/VBoxContainer/BiasLabel
@onready var family_label: Label = $MarginContainer/VBoxContainer/FamilyLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel

## Colour used for the conditional line while its window is actually open,
## so a glance tells you whether the bonus is live right now.
const ACTIVE_COLOR := Color(0.24, 0.5, 0.3)
const INACTIVE_COLOR := Color(0.5, 0.42, 0.32)

## Two parking spots. The shop sits on the left, so the read-out goes
## right; the equip panel already occupies the right, so it goes left
## instead. Without this the detail panel would open directly on top of
## the very list the player is hovering.
const RIGHT_SLOT := Rect2(340.0, 76.0, 280.0, 212.0)
const LEFT_SLOT := Rect2(12.0, 76.0, 308.0, 212.0)

func _place(on_left: bool) -> void:
	var slot_rect: Rect2 = LEFT_SLOT if on_left else RIGHT_SLOT
	offset_left = slot_rect.position.x
	offset_top = slot_rect.position.y
	offset_right = slot_rect.end.x
	offset_bottom = slot_rect.end.y

func show_item(item: Item, spot: String = "", on_left: bool = false) -> void:
	if item == null:
		visible = false
		return
	_place(on_left)
	visible = true
	name_label.text = item.item_name
	kind_label.text = "%s · %s" % [item.slot, item.rarity]
	kind_label.add_theme_color_override("font_color", RarityColors.for_name(item.rarity))
	# The frame is reserved for the item icon that doesn't exist yet; it is
	# tinted by rarity so the space reads as deliberate rather than empty.
	icon_frame.modulate = RarityColors.for_name(item.rarity)
	description_label.text = item.description

	var base := Item.format_effects(item.effects)
	effects_label.text = "Always: %s" % base if base != "" else "No standing bonus"

	if item.bonus_effects.is_empty():
		conditional_label.visible = false
	else:
		conditional_label.visible = true
		var live := item.condition_active(spot)
		conditional_label.text = "%s: %s%s" % [
			item.condition_text(),
			Item.format_effects(item.bonus_effects),
			"  (active now)" if live else "",
		]
		conditional_label.add_theme_color_override("font_color", ACTIVE_COLOR if live else INACTIVE_COLOR)

	bias_label.visible = not item.habitat_bias.is_empty()
	if bias_label.visible:
		bias_label.text = item.habitat_bias_text()

	family_label.visible = item.family != "" and item.family != "Signature"
	if family_label.visible:
		family_label.text = "Part of the %s line" % item.family

	cost_label.text = "%d %s" % [item.cost, item.currency]

## Potions aren't Items — they're a temporary bonus on one axis — so they
## get their own read-out rather than being forced into the Item shape.
func show_potion(axis: String, cost: int, tint: Color, on_left: bool = false) -> void:
	_place(on_left)
	visible = true
	name_label.text = "%s Potion" % Item.AXIS_LABELS.get(axis, axis)
	kind_label.text = "Potion · Temporary"
	kind_label.add_theme_color_override("font_color", tint)
	icon_frame.modulate = tint
	description_label.text = "Drunk on the spot. Applies to every fisherman at once."
	effects_label.text = "Always: %s" % Item.format_effects([[axis, PotionManager.POTION_BONUS]])

	var remaining := PotionManager.get_remaining(axis)
	conditional_label.visible = true
	if remaining > 0.0:
		conditional_label.text = "Active for another %ds" % ceili(remaining)
		conditional_label.add_theme_color_override("font_color", ACTIVE_COLOR)
	else:
		conditional_label.text = "Lasts %ds. Re-drinking refreshes rather than stacks." % int(PotionManager.DURATION)
		conditional_label.add_theme_color_override("font_color", INACTIVE_COLOR)

	bias_label.visible = false
	family_label.visible = false
	cost_label.text = "%d Coins" % cost

func hide_item() -> void:
	visible = false
