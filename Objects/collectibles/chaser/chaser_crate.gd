extends Collectible

@export var chaser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = chaser_bullet
	super._ready()
