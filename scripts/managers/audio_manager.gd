# NOTE: This must be loaded in before GameManager!
# Does not decide when to play audio, just provides an interface for other scripts to do so.
extends Node

const SFX_POLYPHONY := 16
const SFX_DIALOGUE_LETTER_POLYPHONY := 32

var _ambient_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_dialogue_letter_player: AudioStreamPlayer

var audio_file_to_volume: Dictionary[String, int] = {
	"amb_main_menu_faded": 40,
	"amb_main_game": 25,
	"amb_night_sounds": 25,
}

# NOTE: SFX volume config, editable in the Inspector at res://data/audio/sfx_config.tres.
# Should only be read by the AudioManager.
var sfx_config: SfxConfig

#region Preloaded Streams

# NOTE: For now, we preload all audio streams. If this becomes a performance issue, we can add a kind of streaming system that loads/unloads as needed.
var ambient_audio_streams: Dictionary = {}
var sfx_audio_streams: Dictionary = {}

#endregion 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # We don't want audio to pause when the game is paused
	ambient_audio_streams = _preload_streams(Config.AMBIENT_AUDIO_STREAMS_PATH)
	sfx_audio_streams = _preload_streams(Config.SFX_AUDIO_STREAMS_PATH)
	sfx_config = ResourceLoader.load(Config.SFX_CONFIG_PATH)
	_create_players()


func play_ambient_stream(stream_name: String):
	if not ambient_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No music stream found with name '%s'!" % stream_name)
		return

	var volume: int = audio_file_to_volume.get(stream_name, 0)
	_ambient_player.stream = ambient_audio_streams[stream_name]
	_ambient_player.volume_db = volume
	_ambient_player.play()

func stop_ambient():
	_ambient_player.stop()

func play_sfx(stream_name: String, volume_offset_db: float = 0.0):
	if not sfx_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No SFX stream found with name '%s'!" % stream_name)
		return

	var volume_db := _get_sfx_volume(stream_name)
	_play_sfx(_sfx_player, stream_name, volume_db + volume_offset_db)

## Play a single SFX and await its completion
func play_sfx_and_wait(stream_name: String, volume_offset_db: float = 0.0) -> void:
	if not sfx_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No SFX stream found with name '%s'!" % stream_name)
		return

	var volume_db := _get_sfx_volume(stream_name)

	# Use a plain AudioStreamPlayer to reliably await completion
	var temp_player := AudioStreamPlayer.new()
	temp_player.bus = Config.AUDIO_BUS_SFX
	temp_player.stream = sfx_audio_streams[stream_name]
	temp_player.volume_db = volume_db + volume_offset_db
	add_child(temp_player)
	temp_player.play()

	await temp_player.finished

	temp_player.queue_free()
	
func play_sfx_on_letter_spoke():
	var random_pitch = randf_range(Config.LETTER_SPOKE_MIN_PITCH_SCALE, Config.LETTER_SPOKE_MAX_PITCH_SCALE)
	_play_sfx(_sfx_dialogue_letter_player, Config.LETTER_SPOKE_SFX_NAME, sfx_config.volumes_db.get(Config.LETTER_SPOKE_SFX_NAME, 0.0), random_pitch)
	
func set_bus_volume(bus_name: String, volume_db: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), volume_db)

func _get_sfx_volume(stream_name: String) -> float:
	var base_volume_db: float = 0.0
	if sfx_config and sfx_config.volumes_db.has(stream_name):
		base_volume_db = sfx_config.volumes_db[stream_name]
	else:
		Utils.debug_error("AudioManager: No volume configured for SFX '%s' in %s, volume set to 0dB." % [stream_name, Config.SFX_CONFIG_PATH])

	return base_volume_db

func _play_sfx(stream_player: AudioStreamPlayer, stream_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var sfx = sfx_audio_streams[stream_name]
	var playback = stream_player.get_stream_playback()
	playback.play_stream(sfx, 0, volume_db, pitch_scale, 0, stream_player.bus)

func _preload_streams(path: String) -> Dictionary:
	var streams: Dictionary = {}

	for file_name in ResourceLoader.list_directory(path):
		var full_path = path.path_join(file_name)
		var stream = ResourceLoader.load(full_path)
		if not stream is AudioStream:
			continue
		streams[file_name.get_basename()] = stream

	return streams

func _create_players():
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = Config.AUDIO_BUS_AMBIENT
	add_child(_ambient_player)
	
	_sfx_player = _create_polyphonic_stream_player(Config.AUDIO_BUS_SFX, SFX_POLYPHONY)
	_sfx_dialogue_letter_player = _create_polyphonic_stream_player(Config.AUDIO_BUS_SFX, SFX_DIALOGUE_LETTER_POLYPHONY)

func _create_polyphonic_stream_player(bus_name: String, polyphony: int) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = AudioStreamPolyphonic.new()
	player.stream.polyphony = polyphony
	add_child(player)
	player.play() # NOTE: Need to play the polyphonic player to initialize it, otherwise it gives an error on first play :(
	return player