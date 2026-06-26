extends CharacterBody2D
class_name Projectile


@onready var _enemy_detection_area: Area2D = $EnemyDetectionArea
@onready var _delete_timer: Timer = $DeleteTimer


@export var speed: float
@export var damage: float
@export var fire_cooldown: float
var shooter


func set_direction(dir: Vector2):
	velocity = (dir - global_position).normalized() * speed
	rotation = velocity.angle()
	rotation += deg_to_rad(90)


func _ready():
	$EnemyDetectionArea/CollisionShape2D.disabled = true
	await get_tree().create_timer(0.08).timeout
	$EnemyDetectionArea/CollisionShape2D.disabled = false


func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)

	if collision:
		# Reflect velocity
		velocity = velocity.bounce(collision.get_normal())
		rotation = velocity.angle()
		rotation += deg_to_rad(90)


func _on_enemy_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("get_hit"):
		body.get_hit(damage)
		queue_free()


func _on_delete_timer_timeout() -> void:
	queue_free()
