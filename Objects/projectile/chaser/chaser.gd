extends Projectile
class_name Chaser


@onready var agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D


func _ready():
	$EnemyDetectionArea/CollisionShape2D.disabled = true
	await get_tree().create_timer(0.1).timeout
	$EnemyDetectionArea/CollisionShape2D.disabled = false
	target = get_closest_tank()
	agent.target_position = target.global_position


func get_closest_tank():
	var tanks = get_tree().get_nodes_in_group("tank")
	var closest = null
	var closest_dist = INF
	
	for tank in tanks:
		if tank == shooter:
			continue
		
		var dist = global_position.distance_squared_to(tank.global_position)
		
		if dist < closest_dist:
			closest_dist = dist
			closest = tank
	
	return closest


func _physics_process(delta):
	if !is_instance_valid(target):
		target = get_closest_tank()
		
		if !target:
			queue_free()
	if agent.is_navigation_finished():
		return

	var next_point = agent.get_next_path_position()
	var direction = (next_point - global_position).normalized()

	velocity = direction * speed
	move_and_collide(velocity * delta)	
	if target:
		agent.target_position = target.global_position
	rotation = direction.angle() + deg_to_rad(90)
