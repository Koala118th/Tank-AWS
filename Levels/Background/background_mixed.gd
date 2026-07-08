extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

@export var grass_source_1: int = 0
@export var grass_source_2: int = 1

@export var sand_source_1: int = 2
@export var sand_source_2: int = 3

@export var transition_source: int = 4

var tile_coords: Vector2i = Vector2i(0, 0)

func _ready():
	if tilemap == null:
		push_error("Background3: TileMapLayer is NULL!")
		return

	if tilemap.tile_set == null:
		push_error("Background3: TileSet is NULL!")
		return

	generate()

func generate():
	var tile_size = tilemap.tile_set.tile_size
	var half_w: int = int(1000 / tile_size.x)
	var half_h: int = int(500 / tile_size.y)

	for x in range(-half_w, half_w):
		for y in range(-half_h, half_h):
			var pos = Vector2i(x, y)

			if x < 0:
				var chosen_grass: int = grass_source_1 if randi() % 2 == 0 else grass_source_2
				tilemap.set_cell(pos, chosen_grass, tile_coords)

			elif x == 0:
				tilemap.set_cell(pos, transition_source, tile_coords)

			else:
				var chosen_sand: int = sand_source_1 if randi() % 2 == 0 else sand_source_2
				tilemap.set_cell(pos, chosen_sand, tile_coords)
