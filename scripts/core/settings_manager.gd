# scripts/core/settings_manager.gd
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH: String = "user://settings.json"

var settings: Dictionary = {
	"audio_master": 1.0,
	"audio_music": 0.8,
	"audio_sfx": 0.9,
	"audio_engine": 0.85,
	"audio_voice": 1.0,
	"screen_shake": 1.0,
	"high_contrast_hud": false,
	"colorblind_filter": "none",
	"drs_enabled": true,
	"graphics_preset": "high",
	"bloom_enabled": true,
	"ssao_enabled": true
}

func _init() -> void:
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			for k in json.data.keys():
				settings[k] = json.data[k]
		file.close()

func save_settings() -> bool:
	var tmp_path := SETTINGS_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(settings, "\t"))
	file.flush()
	file.close()
	
	var dir := DirAccess.open("user://")
	if dir:
		if FileAccess.file_exists(SETTINGS_PATH):
			dir.remove(SETTINGS_PATH)
		var err := dir.rename(tmp_path, SETTINGS_PATH)
		return err == OK
	return false

func set_volume(bus_name: String, normalized_vol: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db := linear_to_db(clamp(normalized_vol, 0.0001, 1.0))
		if normalized_vol <= 0.0001:
			db = -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)
