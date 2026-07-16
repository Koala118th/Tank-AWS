extends Projectile
class_name Sniper


var wall_hits :float= 0
var max_skips :float= 8

var wall_pen_scene: PackedScene =preload("res://Assets/Scenes/WallPen/wall_pen.tscn")
var was_in_wall := false

func _physics_process(delta):
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		var motion = velocity * delta
		
		var collision = move_and_collide(motion)
		
		if collision:
			if collision.get_collider().is_in_group("wall"):
				wall_hits += 1
			
			if wall_hits > max_skips:
				GameServer.projectileManager.sync_delete.rpc(projectile_id)
				queue_free()
				return
			
			var remaining = motion - collision.get_travel()
			global_position += remaining
		GameServer.projectileManager.sync_transform.rpc(projectile_id, global_position, rotation, velocity)
	else:
		var t = clamp(delta * interp_speed, 0.0, 1.0)

		var predicted_pos = target_pos + velocity * delta

		global_position = global_position.lerp(predicted_pos, t)
		rotation = lerp_angle(rotation, target_rot, t)
		
		var motion = target_pos - global_position
		var is_in_wall := false

		if test_move(global_transform, motion):
			var collision = move_and_collide(motion, true) # test_only = true
			if collision and collision.get_collider().is_in_group("wall"):
				is_in_wall = true

		if is_in_wall and not was_in_wall:
			show_sprite()

		was_in_wall = is_in_wall


func show_sprite():
	var explosion = wall_pen_scene.instantiate()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
