extends Collectible

@export var laser_bullet: PackedScene

func _ready() -> void:
	bullet_scene = GameServer.projectileManager.AmmoType.LASER
	super._ready()
