extends Node

### NOTE: For small save files, the normal JSON option should work out of the box for both PC and Web.
### Limitations for Web - the save file will not persist between sessions when: 
	### - Using Incognito mode
	### - Not allowing cookies
### https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence

const SAVE_PATH := "user://savegame.save"

var data: Dictionary = {}

# TODO - polish: Use OS.is_userfs_persistent() to check if the save file is persistent and inform player if it's not. 
# Above is suggested in the docs even though not 100% reliable

## Caller is responsible for calling the function at the right time
## NOTE: Function doesn't have a dictionary parameter by design. Most variables should be saved through Variables autoload instead.
func save_game(day_index: int, interaction_index: int) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		Utils.debug_error("SaveManager: Save failed: %s" % FileAccess.get_open_error())
		return

	data = Variables.get_all_globals()
	data["day_index"] = day_index
	data["interaction_index"] = interaction_index

	file.store_string(JSON.stringify(data))
	print("SaveManager: Saving game at day %d, interaction %d" % [day_index, interaction_index])

	file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: Save file does not exist. No data to load.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		Utils.debug_error("SaveManager: Load failed: %s" % FileAccess.get_open_error())
		return

	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)
	data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	Variables.load_all_globals(data)
	
	file.close()


#region Debug

func debug_get_day_index() -> int:
	if not data.has("day_index"):
		return -1
	return data["day_index"]

func debug_get_interaction_index() -> int:
	if not data.has("interaction_index"):
		return -1
	return data["interaction_index"]

#endregion
