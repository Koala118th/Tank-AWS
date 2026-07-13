extends CharacterBody2D
class_name Projectile


@export var speed: float
@export var damage: float
@export var fire_cooldown: float
var shooter
var shooter_id: int
var projectile_id


func set_direction(dir: Vector2):
	velocity = (dir - global_position).normalized() * speed
	rotation = velocity.angle()
	rotation += deg_to_rad(90)


func _ready():
	$EnemyDetectionArea/CollisionShape2D.disabled = true
	await get_tree().create_timer(0.08).timeout
	$EnemyDetectionArea/CollisionShape2D.disabled = false


func _physics_process(delta):
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		var collision = move_and_collide(velocity * delta)

		if collision:
			# Reflect velocity
			velocity = velocity.bounce(collision.get_normal())
			rotation = velocity.angle()
			rotation += deg_to_rad(90)
		
		GameServer.projectileManager.sync_transform.rpc(projectile_id, global_position, rotation, velocity)


func _on_enemy_detection_area_body_entered(body: Node2D) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if body.has_method("get_hit"):
		body.get_hit(damage)
		GameServer.projectileManager.sync_delete.rpc(projectile_id)
		queue_free()


func _on_delete_timer_timeout() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	GameServer.projectileManager.sync_delete.rpc(projectile_id)
	queue_free()
