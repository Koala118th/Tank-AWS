extends Collectible

@export var laser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = laser_bullet
	super._ready()
