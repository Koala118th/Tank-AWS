extends Projectile
class_name Sniper


var wall_hits :float= 0
var max_skips :float= 8


func _physics_process(delta):
	var motion = velocity * delta
	
	var collision = move_and_collide(motion)
	
	if collision:
		if collision.get_collider().is_in_group("wall"):
			wall_hits += 1
			print(wall_hits)
		
		if wall_hits > max_skips:
			queue_free()
			return
		
		var remaining = motion - collision.get_travel()
		global_position += remaining
