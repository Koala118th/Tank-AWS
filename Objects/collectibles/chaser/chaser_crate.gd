extends Collectible

@export var chaser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = chaser_bullet
	ammo_type = 2
	super._ready()
