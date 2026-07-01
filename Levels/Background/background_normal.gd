extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

@export var tile_a_coords: Vector2i = Vector2i(0, 0)
@export var tile_a_source: int = 0

@export var tile_b_coords: Vector2i = Vector2i(0, 0)
@export var tile_b_source: int = 1


func _ready():

	if tilemap == null:
		push_error("TileMapLayer is NULL!")
		return
	
	if tilemap.tile_set == null:
		push_error("TileSet is NULL!")
		return

	generate_random_tiles()


func generate_random_tiles():
	var tile_size = tilemap.tile_set.tile_size

	var half_w = int(1000 / tile_size.x)
	var half_h = int(500 / tile_size.y)

	for x in range(-half_w, half_w):
		for y in range(-half_h, half_h):

			var use_a = randi() % 2 == 0
			
			var source = tile_a_source if use_a else tile_b_source
			var coords = tile_a_coords if use_a else tile_b_coords

			tilemap.set_cell(Vector2i(x, y), source, coords)
