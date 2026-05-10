shader_type canvas_item;

uniform float health_normalized : hint_range(0.0, 1.0) = 1.0;

uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
// magnitude in normalized space (height = 1.0 unit); ~0.02 ≈ 14px at 720p
uniform float wave_magnitude : hint_range(0.0, 0.1) = 0.02;
// must be integer for seamless ends (full sine cycles around 2*PI)
uniform float wave_frequency : hint_range(1.0, 16.0, 1.0) = 4.0;

uniform float wave2_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wave2_magnitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave2_frequency : hint_range(1.0, 16.0, 1.0) = 4.0;

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE.xy;

	// Y range: [-0.5, 0.5], X range: [-aspect/2, aspect/2] — coords stay centered no matter the res
	vec2 uv = (FRAGCOORD.xy - 0.5 * resolution) / resolution.y;

	float dist = length(uv);
	// wave2 distorts the angle before wave1 samples it, breaking circular symmetry
	float angle = atan(uv.y, uv.x);
	float distorted_angle = angle + wave2_magnitude * sin(wave2_frequency * angle + TIME * wave2_speed);

	float base_radius = health_normalized * 0.5 * (resolution.x / resolution.y);
	float radius = base_radius + wave_magnitude * sin(wave_frequency * distorted_angle + TIME * wave_speed);

	// 5px feather converted to normalized space
	float feather = 5.0 / resolution.y;
	float mask = smoothstep(radius - feather, radius + feather, dist);

	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * mask);
}
