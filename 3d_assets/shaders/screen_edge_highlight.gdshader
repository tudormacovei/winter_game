shader_type canvas_item;

group_uniforms EdgeBehaviour;
/** Bitmask configuring which edges have glow. Top = bit 0, Bottom = bit 1, Left = bit 2, Right = bit 3 */
uniform int edges_enabled_mask = 0;

group_uniforms Glow;
uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float glow_height : hint_range(0.0, 1.0) = 0.1; // Screen percentage
uniform float glow_multiplier : hint_range(0.0, 1.5) = 0.5;
uniform float glow_softness : hint_range(0.0, 5.0) = 2.0;

uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5; // 0.0 - Disabled
const float pulse_intensity = 0.5;

group_uniforms CodeDrivenValues;
/** This is set in GDScript not in editor! */
uniform float _fade_progress = 0.0;

float edge_glow(float uv_value, bool enabled) {
    if (!enabled)
		return 0.0;

    float g = (uv_value - (1.0 - glow_height)) / glow_height; // Remap UV: 0.0 - inner glow boundary, 1.0 - screen edge
	g = clamp(g, 0.0, 1.0); // Remove negative values (outside glow boundary)
    return pow(g, glow_softness); // Reshape glow curve
}

void fragment() {
    float glow = 0.0;
    glow = max(glow, edge_glow(1.0 - UV.y, bool(edges_enabled_mask & 1)));
    glow = max(glow, edge_glow(UV.y, bool(edges_enabled_mask & 2)));
    glow = max(glow, edge_glow(1.0 - UV.x, bool(edges_enabled_mask & 4)));
    glow = max(glow, edge_glow(UV.x, bool(edges_enabled_mask & 8)));

    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	float fade = clamp(_fade_progress, 0.0, 1.0);

	vec4 color = glow_color;
    color.a *= glow * glow_multiplier * pulse * fade;
    COLOR = color;
}