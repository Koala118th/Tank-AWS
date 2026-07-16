extends Node

enum AmmoType {
	BULLET,   # 0
	SNIPER,   # 1
	CHASER,   # 2
	SMALL,    # 3
	LASER     # 4
}

var ammo_cooldown:= {
	AmmoType.BULLET: 0.5,
	AmmoType.SNIPER: 2.0,
	AmmoType.CHASER: 1.0,
	AmmoType.SMALL: 0.1,
	AmmoType.LASER: 1.0
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


func clear_all_projectiles() -> void:
	for id in projectiles.keys():
		var p = projectiles[id]
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()


@rpc("authority", "call_local", "reliable")
func receive_clear_all() -> void:
	clear_all_projectiles()


@rpc("any_peer", "call_remote", "reliable")
func request_shoot(shooter_id: int, mouse_pos: Vector2, spawn_index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != shooter_id:
		return

	var ammo_type: int = GameServer.tankManager.get_tank_ammo(shooter_id)
	var tank = GameServer.tankManager.find_tank_by_owner(shooter_id)
	if tank:
		tank.server_shoot(shooter_id, mouse_pos, ammo_type, spawn_index)
		GameServer.tankManager.consume_ammo(shooter_id)
	else:
		push_warning("[ProjectileManager] No tank found for shooter_id %d" % shooter_id)


@rpc("authority", "call_remote", "reliable")
func spawn_projectile(id, pos: Vector2, rot: float, dir: Vector2, ammo_type: int, shooter_id: int, spawn_index: int):
	var projectile = ammo_scenes[ammo_type].instantiate()
	projectile.global_position = pos
	projectile.rotation = rot
	projectile.target_pos = pos
	projectile.target_rot = rot
	projectile.set_direction(dir)
	
	projectiles[id] = projectile
	
	get_parent().add_child(projectile)
	projectile.set_visual_by_index(spawn_index)
	
	var tank = GameServer.tankManager.find_tank_by_owner(shooter_id)
	tank.trigger_muzzle_flash()


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
	
	p.target_pos = pos
	p.target_rot = rot
	p.velocity = vel


@rpc("authority", "call_remote", "unreliable")
func sync_laser(id, points: PackedVector2Array):
	if multiplayer.is_server():
		return

	if not projectiles.has(id):
		return

	var p = projectiles[id]

	if not is_instance_valid(p):
		projectiles.erase(id)
		return

	if p.has_method("apply_laser_points"):
		p.apply_laser_points(points)


@rpc("authority", "call_remote", "reliable")
func sync_delete(id):
	if multiplayer.is_server():
		return

	if not projectiles.has(id):
		return

	var p = projectiles[id]
	if is_instance_valid(p):
		if not p is LaserProjectile:
			p.explode()
		p.queue_free()
	projectiles.erase(id)
