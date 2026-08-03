extends CharacterBody2D
class_name Tank

const MAX_HEALTH: int = 100

var explosion_scene: PackedScene =preload("res://Assets/VFX Scenes/Explosion/explosion.tscn")

var tank_textures := [
	{
		"body": preload("res://Assets/PNG/tankBody_green.png"),
		"turret": preload("res://Assets/PNG/tankGreen_barrel1.png")
	},
	{
		"body": preload("res://Assets/PNG/tankBody_blue.png"),
		"turret": preload("res://Assets/PNG/tankBlue_barrel1.png")
	},
	{
		"body": preload("res://Assets/PNG/tankBody_red.png"),
		"turret": preload("res://Assets/PNG/tankRed_barrel1.png")
	},
	{
		"body": preload("res://Assets/PNG/tankBody_sand.png"),
		"turret": preload("res://Assets/PNG/tankSand_barrel1.png")
	}
]

var muzzle_flash_texture = preload("res://Assets/PNG/shotLarge.png")
var sniper_muzzle_flash_texture = preload("res://Assets/PNG/shotRed.png")

var colors := [
	Color(0.188, 1.0, 0.455),
	Color(0x378cc4ff),
	Color.RED,
	Color(0.76, 0.70, 0.50)
]

var track_scene: PackedScene = preload("res://Assets/VFX Scenes/Track/track.tscn")
var last_track_pos: Vector2
var track_timer := 0.0
var elapsed_cooldown := 0
@export var track_interval := 0.07
@export var track_distance := 7.0

@export var current_ammo = GameServer.projectileManager.AmmoType.BULLET

@export var speed: float = 150.0
@export var turn_speed: float = 5.0
@export var acceleration: float = 2500.0
@export_range(0, MAX_HEALTH) var health: float = 100:
	get:
		return _health
	set(value):
		var new_health: float = clamp(value, 0, MAX_HEALTH)

		# Only the server is allowed to change health
		if not multiplayer.is_server():
			return

		if _health > 0 and new_health == 0:
			die(_last_attacker_id)

		_health = new_health

		# Broadcast to all clients
		GameServer.tankManager.sync_health.rpc(owner_id, _health)

var _health: float = 100
var _last_attacker_id: int = -1

@onready var body: Node2D = $Body
@onready var turret: Node2D = $Turret
@onready var body_sprite: Sprite2D = $Body/Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var turret_sprite: Sprite2D = $Turret/Sprite2D
@onready var health_bar: ProgressBar = $ProgressBar
@onready var fire_timer: Timer = $FireTimer
@onready var aim_ray: RayCast2D = $AimRay
@onready var aim_line: Line2D = $AimLine
@onready var muzzle_flash: Sprite2D = $Turret/MuzzleFlash
@onready var muzzle_timer: Timer = $Turret/MuzzleTimer
@onready var direction_arrow: Polygon2D = $Body/Polygon2D
@onready var pause_menu = get_node("/root/Game/PauseMenu")
@onready var cooldown_progress: TextureProgressBar = $TextureProgressBar
@onready var pickup_label: Label = $PickupLabel

var owner_id

var spawn_index

var next_bullet_id = 0

var target_pos: Vector2
var target_body_rot: float
var target_turret_rot: float

var interp_speed := 16.0

var reconcile_threshold := 20.0

var current_input := {
	"forward": 0.0,
	"turn": 0.0,
	"mouse": Vector2.ZERO,
	"seq": 0,
	"delta": 0,
}
var input_sequence: int = 0
var input_buffer: Array = []

func _process(delta):
	health_bar.value = lerp(health_bar.value, _health, 10 * delta)
	
	if fire_timer.time_left > 0:
		var progress = 1.0 - (fire_timer.time_left / fire_timer.wait_time)
		cooldown_progress.value = progress * 100
	else:
		cooldown_progress.value = 100

func _ready():
	target_pos = global_position
	target_body_rot = body.rotation
	target_turret_rot = turret.rotation
	
	var style = StyleBoxFlat.new()
	if owner_id == multiplayer.get_unique_id():
		style.bg_color = Color(0.286, 0.71, 0.0)
	else:
		style.bg_color = Color(1.0, 0.0, 0.0)
	health_bar.add_theme_stylebox_override("fill", style)

func _physics_process(delta: float):
	if multiplayer.multiplayer_peer == null:
		set_physics_process(false)
		return
	
	if multiplayer.is_server():
		apply_input(current_input, delta)
		
		GameServer.tankManager.sync_state.rpc(
			owner_id,
			global_position,
			body.rotation,
			turret.rotation,
			current_input.get("seq", 0)
		)
	
	elif is_multiplayer_authority():
		if pause_menu != null and pause_menu.is_paused():
			return
		
		# prediction
		var input = get_input_state()
		input_sequence += 1
		input["seq"] = input_sequence
		input["delta"] = delta
		input_buffer.append(input.duplicate())
		GameServer.tankManager.send_input.rpc_id(1, input)
		apply_input(input, delta)
		spawn_tracks(delta)
		
		if Input.is_action_pressed("shoot") == true:
			shoot_request()
		
		if current_ammo == GameServer.projectileManager.AmmoType.LASER:
			aim(get_global_mouse_position())
		else:
			aim_line.clear_points()
	else:
		# interpolation
		var t = clamp(delta * interp_speed, 0.0, 1.0)
		
		global_position = global_position.lerp(target_pos, t)
		body.rotation = lerp_angle(body.rotation, target_body_rot, t)
		collision_shape.rotation = body.rotation
		turret.rotation = lerp_angle(turret.rotation, target_turret_rot, t)
		
		spawn_tracks(delta)
		if current_ammo == GameServer.projectileManager.AmmoType.LASER:
			var dir = Vector2.UP.rotated(turret.rotation)
			var point = global_position + dir * 1000
			aim(point)
		else:
			aim_line.clear_points()


func get_input_state():
	return {
		"forward": Input.get_axis("move_backward", "move_forward"),
		"turn": Input.get_axis("turn_left", "turn_right"),
		"mouse": get_global_mouse_position(),
	}


func apply_input(input: Dictionary, delta: float):
	# BODY ROTATION
	var turn = input["turn"]
	body.rotation += turn * turn_speed * delta
	collision_shape.rotation = body.rotation
	
	# MOVEMENT
	var forward = input["forward"]
	var motion = Vector2.UP.rotated(body.rotation) * forward * speed * delta

	var collision = move_and_collide(motion)
	if collision:
		# Slide along the collision surface, but don't push
		var slide_motion = collision.get_remainder().slide(collision.get_normal())
		move_and_collide(slide_motion)
	
	# TURRET
	turret.look_at(input["mouse"])
	turret.rotation += deg_to_rad(90)


func reconcile(server_pos, server_body_rot, server_turret_rot, last_seq: int):
	# hard reset to authoritative state (PAST)
	global_position = server_pos
	body.rotation = server_body_rot
	turret.rotation = server_turret_rot
	collision_shape.rotation = body.rotation

	# drop acknowledged inputs
	while input_buffer.size() > 0 and input_buffer[0]["seq"] <= last_seq:
		input_buffer.pop_front()

	# replay remaining inputs (FUTURE)
	for input in input_buffer:
		apply_input(input, input["delta"])


func apply_server_state(pos, body_rot, turret_rot, last_seq: int):
	if is_multiplayer_authority():
		reconcile(pos, body_rot, turret_rot, last_seq)
	else:
		target_pos = pos
		target_body_rot = body_rot
		target_turret_rot = turret_rot


func aim(point_position: Vector2):
	var current_dir = (point_position - global_position).normalized()
	var current_pos = global_position + current_dir * 25
	
	var points = []
	points.append(current_pos)

	var has_bounced = false

	for i in range(10):
		aim_ray.global_position = current_pos
		aim_ray.target_position = current_dir * 1000
		aim_ray.force_raycast_update()

		if not aim_ray.is_colliding():
			points.append(current_pos + current_dir * 1000)
			break

		var collider = aim_ray.get_collider()
		var hit_point = aim_ray.get_collision_point()

		if collider.is_in_group("tank"):
			# pass through
			current_pos = hit_point + current_dir * 1
			continue

		elif collider.is_in_group("wall") and not has_bounced:
			points.append(hit_point)

			var normal = aim_ray.get_collision_normal()
			current_dir = current_dir.bounce(normal).normalized()
			current_pos = hit_point + current_dir * 2

			has_bounced = true
			continue

		else:
			points.append(hit_point)
			break

	# DRAW
	aim_line.clear_points()
	for p in points:
		aim_line.add_point(aim_line.to_local(p))


func shoot_request():
	if not fire_timer.is_stopped():
		return
	var mouse_pos = get_global_mouse_position()
	# No ammo type sent — server decides from its own tank_ammo dict
	GameServer.projectileManager.request_shoot.rpc_id(1, owner_id, mouse_pos, spawn_index)


func trigger_muzzle_flash():
	fire_timer.start(GameServer.projectileManager.ammo_cooldown[current_ammo]) # Spam blocker
	if not current_ammo == GameServer.projectileManager.AmmoType.LASER:
		if current_ammo == GameServer.projectileManager.AmmoType.SNIPER:
			muzzle_flash.texture = sniper_muzzle_flash_texture
		else:
			muzzle_flash.texture = muzzle_flash_texture
		muzzle_flash.visible = true
		muzzle_timer.start()


func server_shoot(shooter_id: int, mouse_pos: Vector2, ammo_type: int, spawn_indx: int):
	if not fire_timer.is_stopped():
		return
	
	GameServer.tankManager.consume_ammo(shooter_id)
	
	var projectile = GameServer.projectileManager.ammo_scenes[ammo_type].instantiate()
	projectile.shooter_id = shooter_id

	var bullet_dir = (mouse_pos - global_position).normalized()
	projectile.global_position = global_position + bullet_dir * 25
	projectile.set_direction(mouse_pos)

	get_parent().add_child(projectile)
	
	# generate unique incremental ID
	next_bullet_id += 1
	var bullet_id = str(owner_id) + "_" + str(next_bullet_id)
	projectile.projectile_id = bullet_id

	# tell all clients to spawn it visually
	GameServer.projectileManager.spawn_projectile.rpc(
		bullet_id,
		projectile.global_position,
		projectile.rotation,
		bullet_dir,
		ammo_type,
		shooter_id,
		spawn_indx
	)

	fire_timer.start(projectile.fire_cooldown)


func get_hit(damage: float, attacker_id: int):
	health -= damage
	_last_attacker_id = attacker_id


func die(killer_id: int = -1):
	set_physics_process(false)

	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	# ADD THIS
	AudioManager.play_game(AudioManager.sfx_explosion, global_position)
	
	if multiplayer.is_server():
		# Prevent invalid kills
		if killer_id != -1 and killer_id != owner_id:
			GameServer.leaderboardManager.add_kill(killer_id)

	queue_free()


var flash_tween: Tween
func flash_red():
	if flash_tween:
		flash_tween.kill()
	
	body.modulate = Color(2, 0.2, 0.2)
	
	flash_tween = create_tween()
	flash_tween.tween_property(body, "modulate", Color(1, 1, 1), 0.15)


func flash_grey():
	if flash_tween:
		flash_tween.kill()
	
	body.modulate = Color(0.5, 0.5, 0.5) # grey
	
	flash_tween = create_tween()
	flash_tween.tween_property(body, "modulate", Color(1, 1, 1), 0.15)


func flash_pickup_label(ammo_type: int):
	var amount = GameServer.collectibleManager.get_ammo_remaining(ammo_type)
	var ammo_name = GameServer.projectileManager.AmmoType.keys()[ammo_type]
	
	pickup_label.text = "x%d %s" % [amount, ammo_name]
	pickup_label.visible = true
	pickup_label.add_theme_constant_override("outline_size", 2)
	pickup_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pickup_label.modulate.a = 0.0
	
	# Kill any previous tween
	if pickup_label.has_meta("tween"):
		var old_tween = pickup_label.get_meta("tween")
		if is_instance_valid(old_tween):
			old_tween.kill()
	
	var tween = create_tween()
	pickup_label.set_meta("tween", tween)
	
	# Fade in
	tween.tween_property(pickup_label, "modulate:a", 1.0, 0.2)
	
	# Wait
	tween.tween_interval(1.4)
	
	# Fade out
	tween.tween_property(pickup_label, "modulate:a", 0.0, 0.2)
	
	# Hide
	tween.tween_callback(func():
		pickup_label.visible = false
	)


func set_visual_by_index(index: int):
	if index < 0 or index >= tank_textures.size():
		push_warning("Invalid tank index")
		return
	
	direction_arrow.color = colors[index]
	
	var data = tank_textures[index]
	body_sprite.texture = data["body"]
	turret_sprite.texture = data["turret"]


func setup_spawn_index(index: int):
	spawn_index = index
	set_visual_by_index(index)


func spawn_tracks(delta: float):
	# detect movement using distance (works for ALL tanks)
	var dist = global_position.distance_to(last_track_pos)
	
	if dist < track_distance:
		return
	
	track_timer -= delta
	if track_timer > 0:
		return
	
	track_timer = track_interval
	last_track_pos = global_position
	
	var track = track_scene.instantiate()
	
	# spawn behind tank
	var offset = Vector2.DOWN.rotated(body.rotation) * 10
	track.global_position = global_position + offset
	track.rotation = body.rotation
	
	get_parent().add_child(track)


func _on_tank_moved(peer_id: int, pos: Vector2, body_rot: float, turret_rot: float):
	if peer_id != get_multiplayer_authority():
		return
	position = pos
	body.rotation = body_rot
	turret.rotation = turret_rot


func _on_muzzle_timer_timeout() -> void:
	muzzle_flash.visible = false
