extends Node2D

@export var tilemap: TileMapLayer
@export var cols: int = 12
@export var rows: int = 7
@export var source_id: int = 1
@export var wall_tile: Vector2i = Vector2i(0, 0)

var tile_cols: int = 0
var tile_rows: int = 0
@onready var nav_reg = $NavigationRegion2D

func _ready():
	print("=== Maze Generator: _ready() called ===")

	if tilemap == null:
		push_error("Maze Generator: 'tilemap' export is not assigned!")
		return
	print("Tilemap node found: ", tilemap.name)

	if tilemap.tile_set == null:
		push_error("Maze Generator: TileMapLayer has no TileSet assigned!")
		return

	if not tilemap.tile_set.has_source(source_id):
		push_error("Maze Generator: source_id " + str(source_id) + " not found!")
		return

	generate()
	print("=== Maze generation complete ===")
	nav_reg.bake_navigation_polygon()

func generate():
	tile_cols = 2 * cols + 1
	tile_rows = 2 * rows + 1
	print("Tile grid size: ", tile_cols, "x", tile_rows)

	tilemap.clear()

	# Build maze into a 2D array
	var maze_grid: Array = []
	for tr in range(tile_rows):
		maze_grid.append([])
		for tc in range(tile_cols):
			if tr % 2 == 0 or tc % 2 == 0:
				maze_grid[tr].append(1)  # wall
			else:
				maze_grid[tr].append(0)  # floor

	print("Starting recursive division...")
	divide_grid(maze_grid, 0, 0, tile_rows, tile_cols)
	print("Division complete.")

	print("Expanding corridors...")
	var expanded = expand_grid(maze_grid)
	print("Expanded grid size: ", expanded[0].size(), "x", expanded.size())

	print("Writing to tilemap...")
	tilemap.clear()
	for tr in range(expanded.size()):
		for tc in range(expanded[tr].size()):
			var pos = Vector2i(tc, tr)
			if expanded[tr][tc] == 1:
				tilemap.set_cell(pos, source_id, wall_tile)
			else:
				tilemap.erase_cell(pos)
	print("=== Maze generation complete ===")

func divide_grid(maze_grid: Array, y: int, x: int, height: int, width: int):
	print("  divide_grid() y=", y, " x=", x, " h=", height, " w=", width)

	var orientation: String
	if width < height:
		orientation = "horizontal"
	elif width > height:
		orientation = "vertical"
	else:
		orientation = "horizontal" if randi() % 2 == 0 else "vertical"

	if orientation == "horizontal":
		if height < 5:
			print("  -> Too small, stopping.")
			return

		var wall_count = (height - 1) / 2 - 1
		if wall_count < 1:
			print("  -> No valid wall positions, stopping.")
			return

		var hole_count = (width - 1) / 2
		if hole_count < 1:
			print("  -> No valid hole positions, stopping.")
			return

		var new_wall = y + (randi() % wall_count + 1) * 2
		var new_hole = x + (randi() % hole_count) * 2 + 1

		# Safety check before writing
		if new_wall >= maze_grid.size():
			push_error("new_wall row ", new_wall, " out of bounds (grid rows: ", maze_grid.size(), ")")
			return
		if new_hole >= maze_grid[new_wall].size():
			push_error("new_hole col ", new_hole, " out of bounds (grid cols: ", maze_grid[new_wall].size(), ")")
			return

		print("  -> H-wall at row=", new_wall, " hole at col=", new_hole)

		for i in range(x, x + width):
			maze_grid[new_wall][i] = 1
		maze_grid[new_wall][new_hole] = 0

		# Top region:    from y,        height = new_wall - y + 1
		# Bottom region: from new_wall, height = y + height - new_wall
		var top_height    = new_wall - y + 1
		var bottom_y      = new_wall
		var bottom_height = y + height - new_wall

		print("  -> Top:    y=", y, " h=", top_height)
		print("  -> Bottom: y=", bottom_y, " h=", bottom_height)

		divide_grid(maze_grid, y,         x, top_height,    width)
		divide_grid(maze_grid, bottom_y,  x, bottom_height, width)

	else:
		if width < 5:
			print("  -> Too small, stopping.")
			return

		var wall_count = (width - 1) / 2 - 1
		if wall_count < 1:
			print("  -> No valid wall positions, stopping.")
			return

		var hole_count = (height - 1) / 2
		if hole_count < 1:
			print("  -> No valid hole positions, stopping.")
			return

		var new_wall = x + (randi() % wall_count + 1) * 2
		var new_hole = y + (randi() % hole_count) * 2 + 1

		# Safety check before writing
		if new_hole >= maze_grid.size():
			push_error("new_hole row ", new_hole, " out of bounds (grid rows: ", maze_grid.size(), ")")
			return
		if new_wall >= maze_grid[new_hole].size():
			push_error("new_wall col ", new_wall, " out of bounds (grid cols: ", maze_grid[new_hole].size(), ")")
			return

		print("  -> V-wall at col=", new_wall, " hole at row=", new_hole)

		for i in range(y, y + height):
			maze_grid[i][new_wall] = 1
		maze_grid[new_hole][new_wall] = 0

		# Left region:  from x,        width = new_wall - x + 1
		# Right region: from new_wall, width = x + width - new_wall
		var left_width  = new_wall - x + 1
		var right_x     = new_wall
		var right_width = x + width - new_wall

		print("  -> Left:  x=", x, " w=", left_width)
		print("  -> Right: x=", right_x, " w=", right_width)

		divide_grid(maze_grid, y, x,       height, left_width)
		divide_grid(maze_grid, y, right_x, height, right_width)

func expand_grid(maze_grid: Array) -> Array:
	var orig_rows = maze_grid.size()
	var orig_cols = maze_grid[0].size()

	# Wall tiles (even index) stay 1 tile wide
	# Floor tiles (odd index) expand to 2 tiles wide
	var col_map: Array = []
	for tc in range(orig_cols):
		col_map.append(1 if tc % 2 == 0 else 2)

	var row_map: Array = []
	for tr in range(orig_rows):
		row_map.append(1 if tr % 2 == 0 else 2)

	# Total expanded size
	var new_cols = 0
	for v in col_map:
		new_cols += v
	var new_rows = 0
	for v in row_map:
		new_rows += v

	print("  expand_grid: ", orig_cols, "x", orig_rows, " → ", new_cols, "x", new_rows)

	# Build expanded grid filled with walls
	var expanded: Array = []
	for _tr in range(new_rows):
		expanded.append([])
		for _tc in range(new_cols):
			expanded[expanded.size() - 1].append(1)

	# Stamp each original tile into its expanded slots
	var exp_row = 0
	for orig_tr in range(orig_rows):
		var exp_col = 0
		for orig_tc in range(orig_cols):
			var value = maze_grid[orig_tr][orig_tc]
			for dr in range(row_map[orig_tr]):
				for dc in range(col_map[orig_tc]):
					expanded[exp_row + dr][exp_col + dc] = value
			exp_col += col_map[orig_tc]
		exp_row += row_map[orig_tr]

	return expanded
