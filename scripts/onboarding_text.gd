extends RefCounted
# Shared source for the in-game pages and the editable TXT export.
const SOURCE := "res://data/onboarding_copy.json"
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(SOURCE,FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary: _data = parsed
	return _data
static func localized(value: Array) -> String:
	return str(value[0 if Txt.zh else 1]) if value.size() >= 2 else ""
static func text(id: String) -> String:
	return localized(data().get("labels",{}).get(id,[id,id]))
static func pages() -> Array:
	return data().get("pages",[])
