shader_type canvas_item;

uniform float arc_fill: hint_range(0.0, 1.0) = 0.75;
uniform vec4 ring_color: source_color = vec4(0.298, 0.686, 0.314, 1.0);
uniform float ring_width: hint_range(0.01, 0.5) = 0.12;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float inner = 1.0 - ring_width;
    float ring = step(inner, dist) * step(dist, 1.0);

    float angle = atan(uv.y, uv.x);
    float normalized = (angle / (2.0 * PI)) + 0.5;
    float arc = step(normalized, arc_fill);

    COLOR = vec4(ring_color.rgb, ring * arc * ring_color.a);
}