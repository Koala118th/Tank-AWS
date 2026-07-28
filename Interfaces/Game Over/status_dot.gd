extends ColorRect
func _process(_delta):
	modulate.a = (sin(Time.get_ticks_msec() * 0.005) + 1) / 2
