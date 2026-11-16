class_name DataFiles
extends RefCounted
## Small helper for loading JSON data files with clear errors.


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data file missing: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func to_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func to_vec2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback
