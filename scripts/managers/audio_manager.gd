#TODO: Set volume from settings.
# NOTE: This must be loaded in before GameManager!
# Does not decide when to play audio, just provides an interface for other scripts to do so.
class_name AudioManager
extends Node

const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"
const VALID_AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

var _ambient_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

#region Preloaded Streams

#NOTE: For now, we preload all audio streams. If this becomes a performance issue, we can add a kind of streaming system that loads/unloads as needed.
var ambient_audio_streams: Dictionary = {}
var sfx_audio_streams: Dictionary = {}

#endregion 

func _ready():
	ambient_audio_streams = _preload_streams(Config.AMBIENT_AUDIO_STREAMS_PATH)
	sfx_audio_streams = _preload_streams(Config.SFX_AUDIO_STREAMS_PATH)
	_create_players()

	DialogueFuncs.register_audio_manager(self )
	

func play_music(stream_name: String):
	if not ambient_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No music stream found with name '%s'!" % stream_name)
		return

	_ambient_player.stream = ambient_audio_streams[stream_name]
	_ambient_player.play()

func play_sfx(stream_name: String):
	if not sfx_audio_streams.has(stream_name):
		Utils.debug_error("AudioManager: No SFX stream found with name '%s'!" % stream_name)
		return
		
	var sfx = sfx_audio_streams[stream_name]
	var playback = _sfx_player.get_stream_playback()
	playback.play_stream(sfx, 0, 1.0, 1, 0, _sfx_player.bus)

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
	_ambient_player.bus = BUS_AMBIENT
	add_child(_ambient_player)
	
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = BUS_SFX
	_sfx_player.stream = AudioStreamPolyphonic.new()
	_sfx_player.stream.polyphony = 16
	add_child(_sfx_player)
	_sfx_player.play() # NOTE: Need to play the polyphonic player to initialize it, otherwise it gives an error on first play :(
