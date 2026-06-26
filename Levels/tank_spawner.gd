extends Node2D

@export var tank_scene: PackedScene
@onready var _tank_spawn_locations: Node2D = $"../TankSpawnLocations"

var tank: Dictionary = {} 

func _ready():
	#Server nodes
	var playerManager = GameServer.playerManager
	var tankManager = GameServer.tankManager
	
	if GameServer.is_server_mode():
		var slots: Dictionary = playerManager.slots
		
		for slot in slots.keys():
			if slots[slot] != null:
				spawn_tank(slots[slot], slot)
				tankManager.relay_spawn_tank.rpc(slots[slot], slot)
	else:
		tankManager.tank_spawned.connect(spawn_tank)

func spawn_tank(owner_peer_id: int, spawn_index: int):
	var tank: Tank = tank_scene.instantiate()
	tank.set_multiplayer_authority(owner_peer_id)

	var spawn_marker: Marker2D = _tank_spawn_locations.get_child(spawn_index)
	tank.position = spawn_marker.position
	add_child(tank)
	
