extends Projectile
class_name LaserProjectile

@onready var ray: RayCast2D = $RayCast2D

@export var max_bounces := 3
@export var max_length := 1000.0

var segments: Array[Sprite2D] = []
var direction: Vector2
var hit_targets := {}  # prevent multi-hit same frame
var last_points: PackedVector2Array = []


func set_direction(target_position: Vector2):
	direction = (target_position - global_position).normalized()


func _physics_process(_delta):
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return

	var points := PackedVector2Array()
	var current_pos = global_position
	var current_dir = direction
	points.append(current_pos)

	for i in range(max_bounces):
		ray.global_position = current_pos
		ray.target_position = current_dir * max_length
		ray.force_raycast_update()

		if ray.is_colliding():
			var collider = ray.get_collider()
			var end_point = ray.get_collision_point()
			points.append(end_point)

			if collider.has_method("get_hit"):
				if collider not in hit_targets:
					collider.get_hit(damage, shooter_id)
					hit_targets[collider] = true
				current_pos = end_point + current_dir * 1
				continue
			elif collider.is_in_group("wall"):
				var normal = ray.get_collision_normal()
				current_dir = current_dir.bounce(normal)
				current_pos = end_point + current_dir * 2
				continue
			else:
				break
		else:
			points.append(current_pos + current_dir * max_length)
			break

	last_points = points
	
	GameServer.projectileManager.sync_laser.rpc(projectile_id, get_laser_points())


func create_segment(start: Vector2, end: Vector2):
	var sprite = Sprite2D.new()
	sprite.texture = projectile_sprite.texture
	add_child(sprite)

	var dir = end - start
	var length = dir.length()

	sprite.global_position = start + dir / 2
	sprite.rotation = dir.angle() + deg_to_rad(90)

	sprite.scale.y = length / sprite.texture.get_height()
	sprite.scale.x = 1  # thickness

	segments.append(sprite)


func apply_laser_points(points: PackedVector2Array):
	draw_segments(points)


func draw_segments(points: PackedVector2Array):
	clear_segments()
	for i in range(points.size() - 1):
		create_segment(points[i], points[i + 1])


func clear_segments():
	for s in segments:
		s.queue_free()
	segments.clear()


func get_laser_points() -> PackedVector2Array:
	return last_points
