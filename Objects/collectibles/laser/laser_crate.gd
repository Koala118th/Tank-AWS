extends Collectible

@export var laser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = laser_bullet
	ammo_type = 4
	super._ready()
