extends VBoxContainer

@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SFXVolumeSlider

# NOTE: This is populated on _ready so that the nodes can be used as keys
var slider_to_bus_mapping: Dictionary = {}

func _ready() -> void:
	slider_to_bus_mapping = {
		music_volume_slider: Config.AUDIO_BUS_AMBIENT,
		sfx_volume_slider: Config.AUDIO_BUS_SFX
	}

	connect("visibility_changed", Callable(self , "_on_visibility_changed"))
	_update_component()

	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

func _on_visibility_changed() -> void:
	if not visible:
		return

	_update_component()
	
func _update_component() -> void:
	_update_slider(music_volume_slider)
	_update_slider(sfx_volume_slider)

func _update_slider(slider: HSlider) -> void:
	var bus: String = slider_to_bus_mapping[slider]
	slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume(slider_to_bus_mapping[music_volume_slider], value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume(slider_to_bus_mapping[sfx_volume_slider], value)
