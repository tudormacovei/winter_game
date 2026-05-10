shader_type canvas_item;

uniform float alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}
