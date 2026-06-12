extends CharacterBody2D
class_name Tank


@export var speed: float = 150.0
@export var turn_speed: float = 5.0
@export var acceleration: float = 2500.0
@export var deceleration: float = 1500.0


func _physics_process(delta: float):
	var turn = Input.get_axis("turn_left", "turn_right")
	rotation += turn * turn_speed * delta

	var forward = Input.get_axis("move_backward", "move_forward")
	velocity = Vector2.UP.rotated(rotation) * forward * speed

	move_and_slide()
