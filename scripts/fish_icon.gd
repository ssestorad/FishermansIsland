extends Sprite2D

## Fish models live in two aligned atlases: a full-colour body and a white
## outline ring. Splitting them lets the card tint the outline with the
## fish's rarity colour without multiplying that colour through the body
## art, which is why the body itself is no longer modulated by tier.
## Regenerate both with tools/generate_fish_sprites.py.
const BODY_ATLAS := preload("res://assets/sprites/fish/fish_atlas.png")
const OUTLINE_ATLAS := preload("res://assets/sprites/fish/fish_atlas_outline.png")
const COLUMNS := 8
const ROWS := 4
const MODEL_COUNT := COLUMNS * ROWS

## Undiscovered fish flatten to a dark silhouette. Applied as
## self_modulate, not modulate, so it doesn't propagate to the outline
## child and swallow the rarity colour with it.
const UNDISCOVERED_COLOR := Color(0.22, 0.22, 0.24)

var _outline: Sprite2D = null

func _ready() -> void:
	_ensure_layers()

func _ensure_layers() -> void:
	if _outline != null:
		return
	texture = BODY_ATLAS
	hframes = COLUMNS
	vframes = ROWS
	_outline = Sprite2D.new()
	_outline.texture = OUTLINE_ATLAS
	_outline.hframes = COLUMNS
	_outline.vframes = ROWS
	_outline.show_behind_parent = true
	add_child(_outline)

## `model` is the species' own atlas frame, assigned in the catalog rather
## than hashed from the name, so each fish gets a silhouette that suits it.
func set_species(model: int, discovered: bool, tier_color: Color) -> void:
	_ensure_layers()
	var index: int = clampi(model, 0, MODEL_COUNT - 1)
	frame = index
	_outline.frame = index
	self_modulate = Color.WHITE if discovered else UNDISCOVERED_COLOR
	_outline.modulate = tier_color
