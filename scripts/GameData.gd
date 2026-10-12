class_name GameData
extends RefCounted

## Manages local player records, offline telemetry, and sync queue
const SAVE_PATH = "user://orchard_history.json"
const SETTINGS_PATH = "user://orchard_settings.json"

static func save_level_record(record: Dictionary):
	var history = get_history()
	history.append(record)
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history, "\t"))

static func get_history() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return []
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Array:
		return json.data
	return []

static func get_opt_in_telemetry() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false # Default opt-in is FALSE (privacy first)
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data.get("opt_in_telemetry", false)
	return false

static func set_opt_in_telemetry(opt_in: bool):
	var data = _load_settings_dict()
	data["opt_in_telemetry"] = opt_in
	_save_settings_dict(data)

static func get_high_score() -> int:
	var data = _load_settings_dict()
	return int(data.get("high_score", 0))

static func update_high_score(new_score: int) -> int:
	var data = _load_settings_dict()
	var current_best = int(data.get("high_score", 0))
	if new_score > current_best:
		data["high_score"] = new_score
		_save_settings_dict(data)
		return new_score
	return current_best

static func _load_settings_dict() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	return {}

static func _save_settings_dict(data: Dictionary):
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
