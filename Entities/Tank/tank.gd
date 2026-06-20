extends CharacterBody2D
class_name Tank

const MAX_HEALTH: int = 100
var bullet_scene: PackedScene =preload("res://Objects/projectile/bullet/bullet.tscn")
var sniper_scene: PackedScene =preload("res://Objects/projectile/sniper/sniper.tscn")
var chaser_scene: PackedScene =preload("res://Objects/projectile/chaser/chaser.tscn")
var small_scene: PackedScene =preload("res://Objects/projectile/small/small.tscn")
var laser_scene: PackedScene = preload("res://Objects/projectile/laser/laser.tscn")
var explosion_scene: PackedScene =preload("res://Entities/Explosion/explosion.tscn")

@export var current_ammo: PackedScene = laser_scene

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


func _process(delta):
	health_bar.value = lerp(health_bar.value, _health, 10 * delta)


func _physics_process(delta: float):
	turret.look_at(get_global_mouse_position())
	turret.rotation += deg_to_rad(90)
	var turn = Input.get_axis("turn_left", "turn_right")
	body.rotation += turn * turn_speed * delta

	var forward = Input.get_axis("move_backward", "move_forward")
	velocity = Vector2.UP.rotated(body.rotation) * forward * speed
	
	if Input.is_action_pressed("shoot") == true:
		shoot(current_ammo)

	move_and_slide()


func shoot(projectile_scene: PackedScene):
	if not fire_timer.is_stopped():
		return
	var projectile = projectile_scene.instantiate()
	projectile.shooter = self
	var mouse_pos = get_global_mouse_position()
	var bullet_dir = (mouse_pos - global_position).normalized()

	projectile.global_position = global_position + bullet_dir * 25

	var dir = mouse_pos
	projectile.set_direction(dir)

	get_parent().add_child(projectile)
	
	fire_timer.start(projectile.fire_cooldown)


func get_hit(damage: float):
	health -= damage


func die():
	set_physics_process(false)

	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	queue_free()
