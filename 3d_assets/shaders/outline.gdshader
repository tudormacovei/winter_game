shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 outline_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float thickness : hint_range(0.0, 0.01);

void vertex() {
    // Assumes your mesh uses smooth normals across seams (see steps below)
    VERTEX += NORMAL * thickness;
}

void fragment() {
    ALBEDO = outline_color;
    ALPHA = 1.0;
}