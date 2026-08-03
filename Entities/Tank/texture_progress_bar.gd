extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	texture_progress = create_circle_texture(8, Color.WHITE)
	texture_under = create_circle_texture(8, Color(0.2, 0.2, 0.2))
	value = 100

func create_circle_texture(tsize: int, color: Color) -> Texture2D:
	var image = Image.create(tsize, tsize, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0)) # transparent

	var center = Vector2(tsize / 2.0, tsize / 2.0)
	var radius = tsize / 2.0

	for x in tsize:
		for y in tsize:
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)
