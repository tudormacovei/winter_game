# NOTE: This must be loaded in before GameManager!
# Does not decide when to play audio, just provides an interface for other scripts to do so.
extends Node

const VALID_AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

const SFX_POLYPHONY := 16
const SFX_DIALOGUE_LETTER_POLYPHONY := 32

var _ambient_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_dialogue_letter_player: AudioStreamPlayer

#region Preloaded Streams

#NOTE: For now, we preload all audio streams. If this becomes a performance issue, we can add a kind of streaming system that loads/unloads as needed.
var ambient_audio_streams: Dictionary = {}
var sfx_audio_streams: Dictionary = {}

#endregion 

func _ready():
	ambient_audio_streams = _preload_streams(Config.AMBIENT_AUDIO_STREAMS_PATH)
	sfx_audio_streams = _preload_streams(Config.SFX_AUDIO_STREAMS_PATH)
	_create_players()


func play_music(stream_name: String):
	if not ambient_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No music stream found with name '%s'!" % stream_name)
		return

	_ambient_player.stream = ambient_audio_streams[stream_name]
	_ambient_player.play()

func play_sfx(stream_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	_play_sfx(_sfx_player, stream_name, volume_db, pitch_scale)

func play_sfx_on_letter_spoke():
	var random_pitch = randf_range(Config.LETTER_SPOKE_MIN_PITCH_SCALE, Config.LETTER_SPOKE_MAX_PITCH_SCALE)
	_play_sfx(_sfx_dialogue_letter_player, Config.LETTER_SPOKE_SFX_NAME, Config.LETTER_SPOKE_SFX_VOLUME_DB, random_pitch)
	
func set_bus_volume(bus_name: String, volume_db: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), volume_db)
	
func _play_sfx(stream_player: AudioStreamPlayer, stream_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not sfx_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No SFX stream found with name '%s'!" % stream_name)
		return
		
	var sfx = sfx_audio_streams[stream_name]
	var playback = stream_player.get_stream_playback()
	playback.play_stream(sfx, 0, volume_db, pitch_scale, 0, stream_player.bus)

func _preload_streams(path: String) -> Dictionary:
	var streams: Dictionary = {}
	var dir = DirAccess.open(path)
	if not dir:
		Utils.debug_error("AudioManager: Could not open path '%s'" % path)
		return streams

	for file_name in dir.get_files():
		var ext = file_name.get_extension().to_lower()
		if not ext in VALID_AUDIO_EXTENSIONS:
			continue

		var key = file_name.get_basename()
		var full_path = path.path_join(file_name)
		var stream = ResourceLoader.load(full_path)
		if not stream:
			Utils.debug_error("AudioManager: Failed to load audio stream at '%s'" % full_path)
			continue
		streams[key] = stream

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