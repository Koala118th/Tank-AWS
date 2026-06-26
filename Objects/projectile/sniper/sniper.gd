extends Projectile
class_name Sniper


var wall_hits :float= 0
var max_skips :float= 4.4


func _physics_process(delta):
	var motion = velocity * delta
	
	var collision = move_and_collide(motion)
	if collision: 
		if wall_hits <= max_skips: 
			print(wall_hits) 
			wall_hits += 1.1
			global_position += collision.get_remainder() # manual move 
		else:
			queue_free()
