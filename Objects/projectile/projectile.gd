extends Node2D
class_name Projectile


@onready var _enemy_detection_area: Area2D = $EnemyDetectionArea


@export var speed: float
var velocity: Vector2


func set_direction(dir: Vector2):
	velocity = (dir - global_position).normalized() * speed
	rotation = velocity.angle()
	rotation += deg_to_rad(90)

func _physics_process(delta):
	global_position += velocity * delta


func _on_enemy_detection_area_body_entered(body: Node2D) -> void:
	body.get_hit()
