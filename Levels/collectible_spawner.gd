extends Node2D

@export var sniper_crate_scene: PackedScene
@export var small_crate_scene: PackedScene
@export var laser_crate_scene: PackedScene
@export var chaser_crate_scene: PackedScene
@export var maze_generator: Node2D

var _crates: Dictionary = {}

@onready var collectible_manager = GameServer.collectibleManager

func _ready() -> void:
	collectible_manager.maze_generator = maze_generator
	collectible_manager.init_collectibles(self)
	if not multiplayer.is_server():
		collectible_manager.request_crates.rpc_id(1)

func get_crate_scene(crate_type: int) -> PackedScene:
	match crate_type:
		0: return sniper_crate_scene
		1: return small_crate_scene
		2: return laser_crate_scene
		3: return chaser_crate_scene
	return null

func spawn_crate(crate_id: int, crate_type: int, pos: Vector2) -> void:
	var scene: PackedScene = get_crate_scene(crate_type)
	if scene == null:
		push_warning("[CollectibleSpawner] no scene for crate_type %d" % crate_type)
		return
	var crate := scene.instantiate()
	crate.position = pos
	crate.crate_id = crate_id
	add_child(crate)
	_crates[crate_id] = crate

func remove_crate(crate_id: int) -> void:
	if _crates.has(crate_id):
		_crates[crate_id].queue_free()
		_crates.erase(crate_id)
