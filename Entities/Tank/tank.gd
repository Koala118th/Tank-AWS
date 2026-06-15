extends CharacterBody2D
class_name Tank


@export var bullet_scene: PackedScene =preload("res://Objects/projectile/bullet/bullet.tscn")


@export var speed: float = 150.0
@export var turn_speed: float = 5.0
@export var acceleration: float = 2500.0
@export var deceleration: float = 1500.0


func _physics_process(delta: float):
	var turn = Input.get_axis("turn_left", "turn_right")
	rotation += turn * turn_speed * delta

	var forward = Input.get_axis("move_backward", "move_forward")
	velocity = Vector2.UP.rotated(rotation) * forward * speed
	
	if Input.is_action_just_pressed("shoot") == true:
		shoot()

	move_and_slide()


func shoot():
	print("shot")
	var bullet: Bullet = bullet_scene.instantiate()
	bullet.shooter = self
	var mouse_pos = get_global_mouse_position()
	var bullet_dir = (mouse_pos - global_position).normalized()

	bullet.global_position = global_position + bullet_dir * 25

	var dir = mouse_pos
	print(dir)
	bullet.set_direction(dir)

	get_parent().add_child(bullet)


func get_hit():
	print("got hit")
	queue_free()
