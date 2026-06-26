extends Node2D

@export var tank_scene: PackedScene
@export var tank_count: int = 4
@export var maze_generator: Node2D

func _ready():
	await get_tree().process_frame
	spawn_tanks()

func spawn_tanks():
	if maze_generator == null:
		push_error("TankSpawner: maze_generator is not assigned!")
		return

	var floor_positions: Array = maze_generator.get_floor_positions()

	if floor_positions.is_empty():
		push_error("TankSpawner: no floor positions found!")
		return

	if floor_positions.size() < tank_count:
		push_error("TankSpawner: not enough floor positions (", floor_positions.size(), ") for ", tank_count, " tanks!")
		return

	floor_positions.shuffle()

	for i in range(tank_count):
		var tank: Tank = tank_scene.instantiate()
		tank.position = floor_positions[i]
		add_child(tank)
