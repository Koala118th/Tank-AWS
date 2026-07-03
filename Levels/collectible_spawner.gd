extends Node2D

@export var sniper_crate_scene: PackedScene
@export var small_crate_scene: PackedScene
@export var laser_crate_scene: PackedScene
@export var maze_generator: Node2D
@export var max_collectibles: int = 3
@export var spawn_interval: float = 5.0

var crate_scenes: Array[PackedScene] = []
var spawn_timer: Timer

func _ready() -> void:
	crate_scenes = [
		sniper_crate_scene,
		small_crate_scene,
		laser_crate_scene,
	]

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func _on_spawn_timer_timeout() -> void:
	if get_collectible_count() >= max_collectibles:
		return
	_spawn_collectible()

func _spawn_collectible() -> void:
	if maze_generator == null:
		push_error("CollectibleSpawner: maze_generator is not assigned!")
		return

	var floor_positions: Array = maze_generator.get_floor_positions()
	if floor_positions.is_empty():
		push_error("CollectibleSpawner: no floor positions found!")
		return

	# Filter out positions too close to existing collectibles
	var valid_positions: Array = floor_positions.filter(func(pos):
		for child in get_children():
			if child is Node2D and not child is Timer:
				if child.position.distance_to(pos) < 64.0:
					return false
		return true
	)

	if valid_positions.is_empty():
		return

	valid_positions.shuffle()

	var scene: PackedScene = crate_scenes[randi() % crate_scenes.size()]
	if scene == null:
		push_warning("CollectibleSpawner: one of the crate scenes is not assigned!")
		return

	var crate := scene.instantiate()
	crate.position = valid_positions[0]
	crate.tree_exited.connect(_on_collectible_picked_up)
	add_child(crate)

func _on_collectible_picked_up() -> void:
	if not is_inside_tree():
		return
	spawn_timer.stop()
	spawn_timer.start()

func get_collectible_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is Node2D and not child is Timer:
			count += 1
	return count
