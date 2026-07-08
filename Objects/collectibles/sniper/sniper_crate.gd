extends Collectible

@export var sniper_bullet: PackedScene

func _ready() -> void:
	bullet_scene = GameServer.projectileManager.AmmoType.SNIPER
	super._ready()
