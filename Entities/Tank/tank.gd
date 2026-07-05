extends CharacterBody2D
class_name Tank

const MAX_HEALTH: int = 100

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

var explosion_scene: PackedScene =preload("res://Entities/Explosion/explosion.tscn")

@export var current_ammo = AmmoType.LASER
@export var pause_menu: CanvasLayer

@export var speed: float = 150.0
@export var turn_speed: float = 5.0
@export var acceleration: float = 2500.0
@export_range(0, MAX_HEALTH) var health: float = 100:
	get:
		return _health
	set(value):
		var new_health :float = clamp(value, 0, MAX_HEALTH)

		if _health > 0 and new_health == 0:
			die()

		_health = new_health
		
var _health: float = 100

@onready var body: Node2D = $Body
@onready var turret: Node2D = $Turret
@onready var health_bar: ProgressBar = $ProgressBar
@onready var fire_timer: Timer = $FireTimer
@onready var aim_ray: RayCast2D = $AimRay
@onready var aim_line: Line2D = $AimLine

var owner_id

var next_bullet_id = 0


func _process(delta):
	health_bar.value = lerp(health_bar.value, _health, 10 * delta)

var paused := false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if paused:
			_resume()
		else:
			_pause()

func _ready():
	GameServer.tankManager.tank_moved.connect(_on_tank_moved)
	if pause_menu != null:
		pause_menu.resumed.connect(_resume)

func _pause():
	paused = true
	pause_menu.open()

func _resume():
	paused = false
	pause_menu.close()

func _physics_process(delta: float):
	if paused:
		return
	
	if not is_multiplayer_authority():
		return

	turret.look_at(get_global_mouse_position())
	turret.rotation += deg_to_rad(90)
	var turn = Input.get_axis("turn_left", "turn_right")
	body.rotation += turn * turn_speed * delta
	$CollisionShape2D.rotation += turn * turn_speed * delta

	var forward = Input.get_axis("move_backward", "move_forward")
	velocity = Vector2.UP.rotated(body.rotation) * forward * speed
	
	if Input.is_action_pressed("shoot") == true:
		shoot_request()
	
	#if current_ammo == laser_scene:
	aim()

	move_and_slide()
	
	GameServer.tankManager.update_transform.rpc(multiplayer.get_unique_id(), position, body.rotation, turret.rotation)


func aim():
	var tank_pos = global_position
	var current_dir = (get_global_mouse_position() - tank_pos).normalized()
	
	var current_pos = tank_pos + current_dir * 25

	var points = []
	points.append(current_pos)

	aim_ray.global_position = current_pos
	aim_ray.target_position = current_dir * 2000
	aim_ray.force_raycast_update()

	if aim_ray.is_colliding():
		var end_point = aim_ray.get_collision_point()
		points.append(end_point)
	else:
		points.append(current_pos + current_dir * 2000)

	aim_line.clear_points()
	for p in points:
		aim_line.add_point(aim_line.to_local(p))


func shoot_request():
	if not fire_timer.is_stopped():
		return
	
	var mouse_pos = get_global_mouse_position()
	GameServer.projectileManager.request_shoot.rpc_id(1, multiplayer.get_unique_id(), mouse_pos, current_ammo) # 1 = server


#func shoot(projectile_scene: PackedScene):
	#if not fire_timer.is_stopped():
		#return
	#var projectile = projectile_scene.instantiate()
	#projectile.shooter = self
	#var mouse_pos = get_global_mouse_position()
	#var bullet_dir = (mouse_pos - global_position).normalized()
#
	#projectile.global_position = global_position + bullet_dir * 25
#
	#var dir = mouse_pos
	#projectile.set_direction(dir)
#
	#get_parent().add_child(projectile)
	#
	#fire_timer.start(projectile.fire_cooldown)


func server_shoot(shooter_id: int, mouse_pos: Vector2, ammo_type: int):
	if not fire_timer.is_stopped():
		return
	
	var projectile = ammo_scenes[ammo_type].instantiate()
	projectile.shooter_id = shooter_id

	var bullet_dir = (mouse_pos - global_position).normalized()
	projectile.global_position = global_position + bullet_dir * 25
	projectile.set_direction(mouse_pos)

	get_parent().add_child(projectile)
	
	# generate unique incremental ID
	next_bullet_id += 1
	var bullet_id = str(multiplayer.get_unique_id()) + "_" + str(next_bullet_id)
	projectile.projectile_id = bullet_id

	# tell all clients to spawn it visually
	GameServer.projectileManager.spawn_projectile.rpc(
		bullet_id,
		projectile.global_position,
		projectile.rotation,
		bullet_dir,
		ammo_type
	)

	fire_timer.start(projectile.fire_cooldown)


func get_hit(damage: float):
	health -= damage


func die():
	set_physics_process(false)

	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	queue_free()


func _on_tank_moved(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float):
	if peer_id != get_multiplayer_authority():
		return
	position = pos
	body.rotation = body_rot
	turret.rotation = turret_rot
