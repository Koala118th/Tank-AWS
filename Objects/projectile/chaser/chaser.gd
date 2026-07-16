extends Projectile
class_name Chaser

@export var turn_speed = 10.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D


func _ready():
	target = get_closest_tank()
	if target != null:
		agent.target_position = target.global_position
	$EnemyDetectionArea/CollisionShape2D.disabled = true
	await get_tree().create_timer(0.15).timeout
	$EnemyDetectionArea/CollisionShape2D.disabled = false


func get_closest_tank():
	var tanks = get_tree().get_nodes_in_group("tank")
	var closest = null
	var closest_dist = INF
	
	for tank in tanks:
		if tank.owner_id == shooter_id:
			continue
		
		var dist = global_position.distance_squared_to(tank.global_position)
		
		if dist < closest_dist:
			closest_dist = dist
			closest = tank
	
	return closest


func _physics_process(delta):
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		if !is_instance_valid(target):
			target = get_closest_tank()
		
		if target:
			agent.target_position = target.global_position
			
			if !agent.is_navigation_finished():

				var next_point = agent.get_next_path_position()
				var desired_dir = (next_point - global_position).normalized()

				# If velocity is zero, initialize it
				if velocity.length() == 0:
					velocity = desired_dir * speed
				else:
					var current_dir = velocity.normalized()
					var new_dir = current_dir.lerp(desired_dir, turn_speed * delta).normalized()
					velocity = new_dir * speed
		
		move_and_collide(velocity * delta)
		rotation = velocity.angle() + deg_to_rad(90)
		
		GameServer.projectileManager.sync_transform.rpc(projectile_id, global_position, rotation, velocity)
	else:
		var t = clamp(delta * interp_speed, 0.0, 1.0)

		var predicted_pos = target_pos + velocity * delta

		global_position = global_position.lerp(predicted_pos, t)
		rotation = lerp_angle(rotation, target_rot, t)
