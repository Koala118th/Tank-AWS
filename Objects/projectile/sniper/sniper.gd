extends Projectile
class_name Sniper


var wall_hits :float= 0
var max_skips :float= 8

func _physics_process(delta):
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		var motion = velocity * delta
		
		var collision = move_and_collide(motion)
		
		if collision:
			if collision.get_collider().is_in_group("wall"):
				wall_hits += 1
				print(wall_hits)
			
			if wall_hits > max_skips:
				GameServer.projectileManager.sync_delete.rpc(projectile_id)
				queue_free()
				return
			
			var remaining = motion - collision.get_travel()
			global_position += remaining
		GameServer.projectileManager.sync_transform.rpc(projectile_id, global_position, rotation, velocity)
