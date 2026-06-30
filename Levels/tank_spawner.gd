extends Node2D

var _tank_spawn_index: int = 0
@export var tank_scene: PackedScene
@export var game_over_screen: CanvasLayer

@onready var _tank_spawn_locations: Node2D = $"../TankSpawnLocations"

var match_number: int = 1

func _ready():
	spawn_tank()
	spawn_tank()
	spawn_tank()
	spawn_tank()

func spawn_tank():
	var tank: Tank = tank_scene.instantiate()
	var spawn_marker: Marker2D = _tank_spawn_locations.get_child(_tank_spawn_index)
	tank.position = spawn_marker.position
	_tank_spawn_index = (_tank_spawn_index + 1) % _tank_spawn_locations.get_child_count()
	
	tank.tree_exited.connect(_on_tank_died)
	
	add_child(tank)

func get_tanks_alive() -> int:
	var count = 0
	for child in get_children():
		if child is Tank:
			count += 1
	return count

func _on_tank_died():
	if not is_inside_tree():
		return

	await get_tree().process_frame

	if not is_inside_tree():
		return

	var tanks_alive = get_tanks_alive()
	print("Tanks remaining: ", tanks_alive)
	
	if tanks_alive == 1:
		_on_round_over()

func _on_round_over():
	for child in get_children():
		if child is Tank:
			print("Winner: ", child.name)
			break
	
	if game_over_screen != null:
		game_over_screen.show_screen(game_over_screen.placeholder_scores, match_number)
	else:
		print("ERROR: game_over_screen not assigned in Inspector!")

func start_next_match():
	match_number += 1
	_tank_spawn_index = 0

	for child in get_children():
		if child is Tank:
			child.queue_free()

	await get_tree().process_frame

	spawn_tank()
	spawn_tank()
	spawn_tank()
	spawn_tank()
