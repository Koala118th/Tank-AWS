shader_type canvas_item;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float vignette = smoothstep(0.4, 1.2, length(uv));
	COLOR = vec4(0.055, 0.067, 0.09, vignette * 0.95);
}