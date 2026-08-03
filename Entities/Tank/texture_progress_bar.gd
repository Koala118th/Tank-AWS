extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	texture_progress = create_circle_texture(8, Color.WHITE)
	texture_under = create_circle_texture(8, Color(0.2, 0.2, 0.2))
	value = 100

func create_circle_texture(size: int, color: Color) -> Texture2D:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0)) # transparent

	var center = Vector2(size / 2, size / 2)
	var radius = size / 2

	for x in size:
		for y in size:
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)
