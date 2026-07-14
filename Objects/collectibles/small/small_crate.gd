extends Collectible

@export var small_bullet: PackedScene

func _ready() -> void:
	bullet_scene = small_bullet
	ammo_type = 3
	super._ready()
