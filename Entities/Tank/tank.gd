extends CharacterBody2D
class_name Tank

const MAX_HEALTH: int = 100
@export var bullet_scene: PackedScene =preload("res://Objects/projectile/bullet/bullet.tscn")
@export var explosion_scene: PackedScene =preload("res://Entities/Explosion/explosion.tscn")

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

@onready var body: Node2D =$Body
@onready var health_bar: ProgressBar = $ProgressBar

func _process(delta):
	health_bar.value = lerp(health_bar.value, _health, 10 * delta)


func _physics_process(delta: float):
	if not is_multiplayer_authority():
		return

	var turn = Input.get_axis("turn_left", "turn_right")
	body.rotation += turn * turn_speed * delta

	var forward = Input.get_axis("move_backward", "move_forward")
	velocity = Vector2.UP.rotated(body.rotation) * forward * speed

	if Input.is_action_just_pressed("shoot") == true:
		shoot()

	move_and_slide()


func shoot():
	print("shot")
	var bullet: Bullet = bullet_scene.instantiate()
	var mouse_pos = get_global_mouse_position()
	var bullet_dir = (mouse_pos - global_position).normalized()

	bullet.global_position = global_position + bullet_dir * 25

	var dir = mouse_pos
	print(dir)
	bullet.set_direction(dir)

	get_parent().add_child(bullet)


func get_hit(damage: float):
	print(health)
	print("got hit")
	health -= damage
	print(health)


func die():
	set_physics_process(false)

	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	queue_free()
