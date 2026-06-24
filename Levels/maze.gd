extends Node2D

@export var tilemap: TileMapLayer
@export var cols: int = 10
@export var rows: int = 5
@export var source_id: int = 1
@export var wall_tile: Vector2i = Vector2i(0, 0)

# Tile grid dimensions (set during generate)
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
	print("TileSet found: ", tilemap.tile_set)

	if not tilemap.tile_set.has_source(source_id):
		push_error("Maze Generator: source_id " + str(source_id) + " not found!")
		return
	print("Source ID ", source_id, " is valid.")

	print("Starting maze generation: ", cols, "x", rows, " cells")
	generate()
	print("=== Maze generation complete ===")
	nav_reg.bake_navigation_polygon()

func generate():
	# Tile grid is (2*cols+1) wide and (2*rows+1) tall
	# e.g. 10 cols → 21 tile cols, same as the C++ area size
	tile_cols = 2 * cols + 1
	tile_rows = 2 * rows + 1
	print("Tile grid size: ", tile_cols, "x", tile_rows)

	# Step 1: Fill the entire grid with walls
	print("Filling with walls...")
	for tr in tile_rows:
		for tc in tile_cols:
			tilemap.set_cell(Vector2i(tc, tr), source_id, wall_tile)

	# Step 2: Carve out the interior as floors (leave border as walls)
	# Matches the C++ loop: y from 1..(height-2), x from 1..(width-2)
	print("Carving interior floors...")
	for tr in range(1, tile_rows - 1):
		for tc in range(1, tile_cols - 1):
			tilemap.erase_cell(Vector2i(tc, tr))

	# Step 3: Recursively divide
	# Pass full tile dimensions just like C++: divide(0, 0, height, width)
	print("Starting recursive division...")
	divide(0, 0, tile_rows, tile_cols)
	print("=== Maze generation complete ===")

func divide(y: int, x: int, height: int, width: int):
	print("  divide() y=", y, " x=", x, " h=", height, " w=", width)

	var orientation: String

	# Match C++ logic: longer axis gets the perpendicular wall
	if width < height:
		orientation = "horizontal"
	elif width > height:
		orientation = "vertical"
	else:
		orientation = "horizontal" if randi() % 2 == 0 else "vertical"

	print("  -> orientation: ", orientation)

	if orientation == "horizontal":
		# Need at least 5 tiles tall to place a wall with room either side
		if height < 5:
			print("  -> Too small (height ", height, " < 5), stopping.")
			return

		# Wall must land on an even row, hole on an odd row
		# random_wall range: 2..(height-3), then force even: /2*2
		var wall_range = height - 3 - 2 + 1  # = height - 4
		var raw_wall = randi() % wall_range + 2
		var new_wall = y + (raw_wall / 2 * 2)        # force even tile row

		# Hole must land on an odd col
		# random_hole range: 1..(width-2), then force odd: /2*2+1
		var hole_range = width - 2 - 1 + 1           # = width - 2
		var raw_hole = randi() % hole_range + 1
		var new_hole = x + (raw_hole / 2 * 2 + 1)    # force odd tile col

		print("  -> H-wall at row=", new_wall, " hole at col=", new_hole)

		# Draw the wall across the full width (x to x+width-2, matches C++ i < x+width-1)
		for i in range(x, x + width - 1):
			tilemap.set_cell(Vector2i(i, new_wall), source_id, wall_tile)

		# Carve the hole
		tilemap.erase_cell(Vector2i(new_hole, new_wall))

		# Recurse into top and bottom sub-regions
		divide(y,        x, new_wall - y + 1,       width)   # top
		divide(new_wall, x, y + height - new_wall,  width)   # bottom

	else:  # vertical
		# Need at least 5 tiles wide
		if width < 5:
			print("  -> Too small (width ", width, " < 5), stopping.")
			return

		# Wall must land on an even col, hole on an odd row
		var wall_range = width - 3 - 2 + 1           # = width - 4
		var raw_wall = randi() % wall_range + 2
		var new_wall = x + (raw_wall / 2 * 2)        # force even tile col

		var hole_range = height - 2 - 1 + 1          # = height - 2
		var raw_hole = randi() % hole_range + 1
		var new_hole = y + (raw_hole / 2 * 2 + 1)    # force odd tile row

		print("  -> V-wall at col=", new_wall, " hole at row=", new_hole)

		# Draw the wall across the full height (y to y+height-2)
		for i in range(y, y + height - 1):
			tilemap.set_cell(Vector2i(new_wall, i), source_id, wall_tile)

		# Carve the hole
		tilemap.erase_cell(Vector2i(new_wall, new_hole))

		# Recurse into left and right sub-regions
		divide(y, x,        height, new_wall - x + 1)      # left
		divide(y, new_wall, height, x + width - new_wall)  # right
