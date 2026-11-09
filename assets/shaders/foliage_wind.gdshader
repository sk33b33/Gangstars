shader_type spatial;
// Tree crowns sway gently; the trunk (below sway_start) stays put. Works in every renderer.
uniform vec4 albedo : source_color = vec4(0.31, 0.54, 0.24, 1.0);
uniform float sway = 0.05;
uniform float sway_start = 1.2;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y - sway_start, 0.0);
	VERTEX.x += sin(TIME * 1.6 + w.x * 0.35 + w.z * 0.21) * sway * h;
	VERTEX.z += cos(TIME * 1.25 + w.z * 0.3 + w.x * 0.13) * sway * 0.6 * h;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.9;
}
