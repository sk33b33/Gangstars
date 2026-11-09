class_name SaveSystem
extends RefCounted
## Versioned JSON saves. Writes go to a temp file first and are then renamed, so a crash
## mid-write never leaves a half-written save. Loading validates the envelope; callers
## validate each section before applying anything.

const VERSION := 1


static func write(path: String, sections: Dictionary) -> Error:
	var data := sections.duplicate()
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return ERR_CANT_OPEN
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file())


## Returns {ok: bool, error: String, data: Dictionary}.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no save file", "data": {}}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {"ok": false, "error": "save file is damaged (not valid JSON)", "data": {}}
	var data: Dictionary = json.data
	if int(data.get("version", -1)) != VERSION:
		return {"ok": false, "error": "save version %s is not supported" % str(data.get("version", "?")), "data": {}}
	return {"ok": true, "error": "", "data": data}


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
