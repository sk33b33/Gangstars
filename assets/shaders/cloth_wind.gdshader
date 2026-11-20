shader_type spatial;
render_mode cull_disabled;
// Washing on a line: pegged along the top edge (line_y), free below it. The cloth leans downwind and flaps; both grow with `wind` (0..1).
// Each line (each instance) has its own phase from where it stands, so a row of lines does not move as one.
uniform vec4 albedo : source_color = vec4(1.0);
uniform float wind = 0.0;
uniform float line_y = 1.86;
uniform vec2 wind_dir = vec2(-0.8, -0.6);   // the south-easter blows towards the north-west (x, z)

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;   // the instance's origin
	float hang = max(line_y - VERTEX.y, 0.0);
	float phase = w.x * 0.9 + w.z * 0.7 + VERTEX.x * 2.3;
	float rate = 1.3 + wind * 3.2;
	float amp = 0.05 + wind * 0.5;
	float flap = sin(TIME * rate + phase) * amp + sin(TIME * rate * 2.3 + phase * 1.7) * amp * 0.3;
	float lean = wind * 0.35;
	vec3 push = vec3(wind_dir.x, 0.0, wind_dir.y) * (lean + flap) * hang;
	vec3 local = (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
	VERTEX += local;
	VERTEX.y -= length(local) * 0.25;   // swinging out lifts the hem less than it sways: keep the cloth from stretching
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.9;
}
