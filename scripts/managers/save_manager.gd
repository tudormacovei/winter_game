extends Node

### NOTE: For small save files, the normal JSON option should work out of the box for both PC and Web.
### Limitations for Web - the save file will not persist between sessions when: 
	### - Using Incognito mode
	### - Not allowing cookies
### https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence

const SAVE_DIR := "user://"
const SAVE_FILE_NAME := "savegame.save"
var SAVE_PATH := "%s%s" % [SAVE_DIR, SAVE_FILE_NAME]

var data: Dictionary = {}
const DAY_INDEX_KEY := "day_index"
const INTERACTION_INDEX_KEY := "interaction_index"

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
	data[DAY_INDEX_KEY] = day_index
	data[INTERACTION_INDEX_KEY] = interaction_index

	file.store_string(var_to_str(data))
	print("SaveManager: Saving game at day %d, interaction %d" % [day_index, interaction_index])

	file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: Save file does not exist. No data to load.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		Utils.debug_error("SaveManager: Load failed: %s" % FileAccess.get_open_error())
		return false

	var content := file.get_as_text()
	var parsed = str_to_var(content)
	data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	var vars_to_load: Dictionary = data.duplicate()
	vars_to_load.erase(DAY_INDEX_KEY)
	vars_to_load.erase(INTERACTION_INDEX_KEY)
	Variables.load_all_globals(vars_to_load)
	
	file.close()
	return true

func reset_save() -> void:
	data.clear()
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open(SAVE_DIR)
		if dir == null:
			Utils.debug_error("SaveManager: Failed to open directory to reset save.")
			return

		var error := dir.remove(SAVE_FILE_NAME)
		if error != OK:
			Utils.debug_error("SaveManager: Failed to reset save: %s" % error)

func does_save_exist() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func get_saved_day_index() -> int:
	if not data.has(DAY_INDEX_KEY):
		return -1
	return data[DAY_INDEX_KEY]

func get_saved_interaction_index() -> int:
	if not data.has(INTERACTION_INDEX_KEY):
		return -1
	return data[INTERACTION_INDEX_KEY]
