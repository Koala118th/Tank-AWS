extends CharacterBody2D
class_name Projectile


@export var speed: float
@export var damage: float
@export var fire_cooldown: float
@export var projectile_textures := []

var shooter
var shooter_id: int
var projectile_id
var explosion_scene: PackedScene =preload("res://Assets/Scenes/ExplosionSmall/explosion_small.tscn")

var target_pos: Vector2
var target_rot: float
var interp_speed := 45.0

@onready var projectile_sprite: Sprite2D = $Sprite2D

func set_direction(dir: Vector2):
	velocity = (dir - global_position).normalized() * speed
	rotation = velocity.angle()
	rotation += deg_to_rad(90)


func _ready():
	target_pos = global_position
	target_rot = rotation
	
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
	else:
		# interpolation
		var t = clamp(delta * interp_speed, 0.0, 1.0)

		var predicted_pos = target_pos + velocity * delta

		global_position = global_position.lerp(predicted_pos, t)
		rotation = lerp_angle(rotation, target_rot, t)


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


func explode():
	set_physics_process(false)

	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)


func set_visual_by_index(index: int):
	if index < 0 or index >= projectile_textures.size():
		push_warning("Invalid index")
		return
	
	var data = projectile_textures[index]
	projectile_sprite.texture = data
