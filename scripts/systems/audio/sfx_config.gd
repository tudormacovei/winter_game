## Central, Inspector-editable volume config for all SFX.
##
## Meant to be instantiated as the single resource at res://data/audio/sfx_config.tres,
## which AudioManager loads and uses as the only source of truth for SFX volume.
## Keys are SFX names (matching the audio file names in res://audio_assets/sfx/,
## the same strings passed to AudioManager.play_sfx() / DialogueFuncs.play_sfx());
## values are each sound's base volume in dB.
class_name SfxConfig
extends Resource

@export var volumes_db: Dictionary[String, float] = {}
