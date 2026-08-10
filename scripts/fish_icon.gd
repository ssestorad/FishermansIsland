extends Sprite2D

const TEXTURES := [
	preload("res://assets/sprites/fish/fish_0_classic.png"),
	preload("res://assets/sprites/fish/fish_1_puffer.png"),
	preload("res://assets/sprites/fish/fish_2_eel.png"),
	preload("res://assets/sprites/fish/fish_3_shark.png"),
	preload("res://assets/sprites/fish/fish_4_ray.png"),
	preload("res://assets/sprites/fish/fish_5_bigeye.png"),
	preload("res://assets/sprites/fish/fish_6_swordfish.png"),
	preload("res://assets/sprites/fish/fish_7_finned.png"),
	preload("res://assets/sprites/fish/fish_8_fancy.png"),
	preload("res://assets/sprites/fish/fish_9_serpent.png"),
]

const UNDISCOVERED_COLOR := Color(0.28, 0.28, 0.28)

func set_species(species_name: String, discovered: bool, tier_color: Color) -> void:
	var index: int = abs(species_name.hash()) % TEXTURES.size()
	texture = TEXTURES[index]
	modulate = tier_color if discovered else UNDISCOVERED_COLOR
