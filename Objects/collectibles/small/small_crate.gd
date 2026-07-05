extends Collectible

@export var small_bullet: PackedScene

func _ready() -> void:
	bullet_scene = GameServer.projectileManager.AmmoType.SMALL
	super._ready()
