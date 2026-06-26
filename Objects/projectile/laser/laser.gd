extends Projectile
class_name LaserProjectile

@onready var ray: RayCast2D = $RayCast2D

@export var max_bounces := 3
@export var max_length := 1000.0
@onready var laser_texture: Texture2D = $Sprite2D.texture


var segments: Array[Sprite2D] = []
var direction: Vector2
var hit_targets := {}  # prevent multi-hit same frame


func set_direction(target_pos: Vector2):
	direction = (target_pos - global_position).normalized()


func _physics_process(delta):
	clear_segments()

	var current_pos = global_position
	var current_dir = direction

	for i in range(max_bounces):
		ray.global_position = current_pos
		ray.target_position = current_dir * max_length
		ray.force_raycast_update()

		var end_point: Vector2

		if ray.is_colliding():
			var collider = ray.get_collider()
			end_point = ray.get_collision_point()

			create_segment(current_pos, end_point)

			# DAMAGE
			if collider.has_method("get_hit"):
				if collider not in hit_targets:
					collider.get_hit(damage)
					hit_targets[collider] = true

				current_pos = end_point + current_dir * 1

			# BOUNCE on walls
			elif collider.is_in_group("wall"):
				var normal = ray.get_collision_normal()
				current_dir = current_dir.bounce(normal)
				current_pos = end_point + current_dir * 2

			else:
				break

		else:
			end_point = current_pos + current_dir * max_length
			create_segment(current_pos, end_point)
			break


func create_segment(start: Vector2, end: Vector2):
	var sprite = Sprite2D.new()
	sprite.texture = laser_texture
	add_child(sprite)

	var dir = end - start
	var length = dir.length()

	sprite.global_position = start + dir / 2
	sprite.rotation = dir.angle() + deg_to_rad(90)

	sprite.scale.y = length / sprite.texture.get_height()
	sprite.scale.x = 1  # thickness

	segments.append(sprite)


func clear_segments():
	for s in segments:
		s.queue_free()
	segments.clear()
