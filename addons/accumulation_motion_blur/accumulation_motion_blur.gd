# Slightly modified implementation of https://git.gay/lamb/accumulation-motion-blur
extends TextureRect

@export_range(0.0, 1.0) var alpha := 0.2 # Controls motion blur intensity
@export var use_frame_post_draw := true # Different style if this is enabled / disabled

func _process(delta: float) -> void:
	accumulation_motion_blur(self, alpha, use_frame_post_draw, get_viewport())

func accumulation_motion_blur(
		texture_rect: TextureRect,
		alpha: float = 0.5,
		use_frame_post_draw: bool = true,
		viewport: Viewport = null
	) -> void:

	alpha = clamp(alpha, 0.0, 1.0)
	if viewport == null:
		viewport = get_viewport()

	# Get image from viewport texture (Godot 4 method)
	var viewport_tex: Texture2D = viewport.get_texture()
	var image: Image = viewport_tex.get_image()

	if use_frame_post_draw:
		await RenderingServer.frame_post_draw

	# Create texture from image
	var texture := ImageTexture.create_from_image(image)

	texture_rect.modulate.a = alpha
	texture_rect.texture = texture
