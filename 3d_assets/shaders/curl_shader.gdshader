shader_type spatial;

// Optional: Ensure we can see the back of the mesh as it curls
render_mode cull_disabled;

// We define a varying variable to pass data from Vertex -> Fragment
varying float curl_ratio;

void vertex() {
	// CUSTOM0 contains the data we packed in SurfaceTool.
	// We put the ratio in the Red channel (.r)
	curl_ratio = CUSTOM0.r;
}

void fragment() {
	// Base color (White)
	ALBEDO = vec3(1.0, 1.0, 1.0);

	// ALPHA Logic
	// As curl_ratio goes from 0.0 (start) to 1.0 (end)
	// We want Alpha to go from 1.0 (opaque) to 0.0 (transparent)
	//ALPHA = 1.0 - curl_ratio;

	// Optional: Clamp it just in case ratio goes slightly below 0 or above 1
	ALPHA = clamp(ALPHA, 0.0, 1.0);

	//	FOR DEBUGGING
	ALBEDO = vec3(curl_ratio, 0.0, 1.0 - curl_ratio);
}