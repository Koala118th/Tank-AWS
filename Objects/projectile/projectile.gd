extends CharacterBody2D
class_name Projectile


@onready var _enemy_detection_area: Area2D = $EnemyDetectionArea
@onready var _delete_timer: Timer = $DeleteTimer


@export var speed: float


var shooter


func set_direction(dir: Vector2):
	velocity = (dir - global_position).normalized() * speed
	rotation = velocity.angle()
	rotation += deg_to_rad(90)

func _physics_process(delta):
	global_position += velocity * delta


func _on_enemy_detection_area_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.has_method("get_hit"):
		body.get_hit()


func _on_delete_timer_timeout() -> void:
	queue_free()
