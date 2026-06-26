extends Node2D

@export var tilemap: TileMapLayer
@export var cols: int = 12
@export var rows: int = 7
@export var source_id: int = 1
@export var wall_tile: Vector2i = Vector2i(0, 0)

var tile_cols: int = 0
var tile_rows: int = 0

func _ready():
	if tilemap == null:
		push_error("Maze Generator: 'tilemap' export is not assigned!")
		return

	if tilemap.tile_set == null:
		push_error("Maze Generator: TileMapLayer has no TileSet assigned!")
		return

	if not tilemap.tile_set.has_source(source_id):
		push_error("Maze Generator: source_id " + str(source_id) + " not found!")
		return

	generate()

func generate():
	tile_cols = 2 * cols + 1
	tile_rows = 2 * rows + 1

	tilemap.clear()

	var maze_grid: Array = []
	for row in range(tile_rows):
		maze_grid.append([])
		for col in range(tile_cols):
			if row % 2 == 0 or col % 2 == 0:
				maze_grid[row].append(1)
			else:
				maze_grid[row].append(0)

	divide_grid(maze_grid, 0, 0, tile_rows, tile_cols)

	var expanded = expand_grid(maze_grid)

	tilemap.clear()
	for row in range(expanded.size()):
		for col in range(expanded[row].size()):
			var pos = Vector2i(col, row)
			if expanded[row][col] == 1:
				tilemap.set_cell(pos, source_id, wall_tile)
			else:
				tilemap.erase_cell(pos)

func divide_grid(maze_grid: Array, y: int, x: int, height: int, width: int):

	var orientation: String
	if width < height:
		orientation = "horizontal"
	elif width > height:
		orientation = "vertical"
	else:
		orientation = "horizontal" if randi() % 2 == 0 else "vertical"

	if orientation == "horizontal":
		if height < 5:
			return

		var wall_count = (height - 1) / 2 - 1
		if wall_count < 1:
			return

		var hole_count = (width - 1) / 2
		if hole_count < 1:
			return

		var new_wall = y + (randi() % wall_count + 1) * 2
		var new_hole = x + (randi() % hole_count) * 2 + 1

		if new_wall >= maze_grid.size():
			push_error("new_wall row ", new_wall, " out of bounds!")
			return
		if new_hole >= maze_grid[new_wall].size():
			push_error("new_hole col ", new_hole, " out of bounds!")
			return

		for i in range(x, x + width):
			maze_grid[new_wall][i] = 1
		maze_grid[new_wall][new_hole] = 0

		var top_height    = new_wall - y + 1
		var bottom_y      = new_wall
		var bottom_height = y + height - new_wall

		divide_grid(maze_grid, y,         x, top_height,    width)
		divide_grid(maze_grid, bottom_y,  x, bottom_height, width)

	else:
		if width < 5:
			return

		var wall_count = (width - 1) / 2 - 1
		if wall_count < 1:
			return

		var hole_count = (height - 1) / 2
		if hole_count < 1:
			return

		var new_wall = x + (randi() % wall_count + 1) * 2
		var new_hole = y + (randi() % hole_count) * 2 + 1

		if new_hole >= maze_grid.size():
			push_error("new_hole row ", new_hole, " out of bounds!")
			return
		if new_wall >= maze_grid[new_hole].size():
			push_error("new_wall col ", new_wall, " out of bounds!")
			return

		for i in range(y, y + height):
			maze_grid[i][new_wall] = 1
		maze_grid[new_hole][new_wall] = 0

		var left_width  = new_wall - x + 1
		var right_x     = new_wall
		var right_width = x + width - new_wall

		divide_grid(maze_grid, y, x,       height, left_width)
		divide_grid(maze_grid, y, right_x, height, right_width)

func expand_grid(maze_grid: Array) -> Array:
	var orig_rows = maze_grid.size()
	var orig_cols = maze_grid[0].size()

	var col_map: Array = []
	for col in range(orig_cols):
		col_map.append(1 if col % 2 == 0 else 2)

	var row_map: Array = []
	for row in range(orig_rows):
		row_map.append(1 if row % 2 == 0 else 2)

	var new_cols = 0
	for v in col_map:
		new_cols += v
	var new_rows = 0
	for v in row_map:
		new_rows += v


	var expanded: Array = []
	for _row in range(new_rows):
		expanded.append([])
		for _col in range(new_cols):
			expanded[expanded.size() - 1].append(1)

	var exp_row = 0
	for orig_row in range(orig_rows):
		var exp_col = 0
		for orig_col in range(orig_cols):
			var value = maze_grid[orig_row][orig_col]
			for dr in range(row_map[orig_row]):
				for dc in range(col_map[orig_col]):
					expanded[exp_row + dr][exp_col + dc] = value
			exp_col += col_map[orig_col]
		exp_row += row_map[orig_row]

	return expanded

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
	return floor_positions
