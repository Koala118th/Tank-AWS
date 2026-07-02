shader_type canvas_item;

void fragment() {
	vec2 grid = fract(UV * vec2(20.0, 15.0));
	float line = step(0.97, grid.x) + step(0.97, grid.y);
	COLOR = vec4(vec3(1.0), line * 0.04);
}