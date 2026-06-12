extends Node2D

var _tank_spawn_index: int = 0
@export var tank_scene: PackedScene
@onready var _tank_spawn_locations: Node2D = $"../TankSpawnLocations"


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
	add_child(tank)
