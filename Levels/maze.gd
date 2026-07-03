extends Node2D

@export var tilemap: TileMapLayer
@export var cols: int = 12
@export var rows: int = 7
@export var source_id: int = 1
@export var wall_tile: Vector2i = Vector2i(0, 0)
@export var background_scenes: Array[PackedScene] = []
@onready var nav_reg = $NavigationRegion2D

var tile_cols: int = 0
var tile_rows: int = 0
var current_maze: Array = []

func _ready():
	GameServer.mapManager.maze_received.connect(_apply_maze)
	if not multiplayer.is_server():
		GameServer.mapManager.request_maze.rpc_id(1)
	else:
		GameServer.mapManager.request_maze()

	if tilemap == null:
		push_error("Maze Generator: 'tilemap' export is not assigned!")
		return

	if tilemap.tile_set == null:
		push_error("Maze Generator: TileMapLayer has no TileSet assigned!")
		return

	if not tilemap.tile_set.has_source(source_id):
		push_error("Maze Generator: source_id " + str(source_id) + " not found!")
		return

	spawn_background()
	nav_reg.bake_navigation_polygon()

func spawn_background():
	if background_scenes.is_empty():
		push_error("Maze Generator: no background scenes assigned!")
		return

	var picked: PackedScene = background_scenes[randi() % background_scenes.size()]

	if picked == null:
		push_error("Maze Generator: picked background scene is null!")
		return

	var background = picked.instantiate()

	# Defer the add_child call until the parent is done setting up
	get_parent().add_child.call_deferred(background)
	
	

	print("Background spawned: ", picked.resource_path)


func _apply_maze(grid: Array):
	tilemap.clear()
	for row in range(grid.size()):
		for col in range(grid[row].size()):
			var pos = Vector2i(col, row)
			if grid[row][col] == 1:
				tilemap.set_cell(pos, source_id, wall_tile)
			else:
				tilemap.erase_cell(pos)
	print("maze applied")
	
	await get_tree().process_frame
	await get_tree().process_frame
	nav_reg.bake_navigation_polygon()


func get_floor_positions() -> Array:
	var floor_positions: Array = []

	var used_rect: Rect2i = tilemap.get_used_rect()

	var scan_x_start = used_rect.position.x + 1
	var scan_y_start = used_rect.position.y + 1
	var scan_x_end   = used_rect.position.x + used_rect.size.x - 1
	var scan_y_end   = used_rect.position.y + used_rect.size.y - 1

	for scan_row in range(scan_y_start, scan_y_end):
		for scan_col in range(scan_x_start, scan_x_end):
			var pos = Vector2i(scan_col, scan_row)
			if tilemap.get_cell_source_id(pos) == -1:
				var local_pos = tilemap.map_to_local(pos)
				var world_pos = tilemap.to_global(local_pos)
				floor_positions.append(world_pos)
				print(world_pos)
	return floor_positions
	#Server nodes
	#var playerManager = GameServer.playerManager
	#playerManager.game_reloaded.connect(reload_self)


func reload_self() -> void:
	get_tree().reload_current_scene()
