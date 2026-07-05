extends Node

enum AmmoType {
	BULLET,
	SNIPER,
	CHASER,
	SMALL,
	LASER
}

var ammo_scenes := {
	AmmoType.BULLET : preload("res://Objects/projectile/bullet/bullet.tscn"),
	AmmoType.SNIPER : preload("res://Objects/projectile/sniper/sniper.tscn"),
	AmmoType.CHASER : preload("res://Objects/projectile/chaser/chaser.tscn"),
	AmmoType.SMALL : preload("res://Objects/projectile/small/small.tscn"),
	AmmoType.LASER : preload("res://Objects/projectile/laser/laser.tscn"),
}

var current_ammo = AmmoType.BULLET

var projectiles := {}


@rpc("any_peer", "call_remote", "reliable")
func request_shoot(shooter_id: int, mouse_pos: Vector2, ammo_type: int):
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	var tank: Tank = GameServer.tankManager.find_tank_by_owner(sender_id)
	if tank == null:
		return
	
	tank.server_shoot(shooter_id, mouse_pos, ammo_type)


@rpc("authority", "call_remote", "reliable")
func spawn_projectile(id, pos: Vector2, rot: float, dir: Vector2, ammo_type: int):
	var projectile = ammo_scenes[ammo_type].instantiate()
	projectile.global_position = pos
	projectile.rotation = rot
	projectile.set_direction(dir)
	
	projectiles[id] = projectile
	
	get_parent().add_child(projectile)


@rpc("authority", "call_remote", "unreliable")
func sync_transform(id, pos: Vector2, rot: float, vel: Vector2):
	if multiplayer.is_server():
		return
	
	if not projectiles.has(id):
		return
	
	var p = projectiles[id]
	
	if not is_instance_valid(p):
		projectiles.erase(id)
		return
	
	p.global_position = pos
	p.rotation = rot
	p.velocity = vel
