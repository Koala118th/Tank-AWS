extends Node

var bullet_scene: PackedScene =preload("res://Objects/projectile/bullet/bullet.tscn")
var sniper_scene: PackedScene =preload("res://Objects/projectile/sniper/sniper.tscn")
var chaser_scene: PackedScene =preload("res://Objects/projectile/chaser/chaser.tscn")
var small_scene: PackedScene =preload("res://Objects/projectile/small/small.tscn")
var laser_scene: PackedScene = preload("res://Objects/projectile/laser/laser.tscn")

var current_ammo: PackedScene = bullet_scene


@rpc("any_peer", "call_remote", "reliable")
func request_shoot(mouse_pos: Vector2, ammo: PackedScene):
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	var tank: Tank = GameServer.tankManager.find_tank_by_owner(sender_id)
	if tank == null:
		return
	
	tank.server_shoot(mouse_pos, ammo)


@rpc("authority", "call_remote", "reliable")
func spawn_projectile(pos: Vector2, rot: float, dir: Vector2, projectile_scene:PackedScene):
	var projectile = projectile_scene.instantiate()
	projectile.global_position = pos
	projectile.rotation = rot
	projectile.set_direction_from_vector(dir)
	
	get_parent().add_child(projectile)
