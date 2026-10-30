class_name Lines
# Every spoken line of the game in one text file the author edits at once (player 2026-10-25:
# "put the lines in a TXT, I'll change them all in one go"): data/台词.txt. Read at start and
# laid over the built-in copy — the growth lines (scripts/copy.gd, ids as they are), the
# training courses' radio lines ("course.<file>.<id>"), the GR-7 story ("story.<ship>.<path>"),
# and Liang's exam and reminder lines in txt.gd ("txt.<key>"). tools/export_lines.py writes
# the file from the built-in copy; after that the file is what the game says.
#
#   [id]
#   谁：梁工            (notes only; the game knows who speaks)
#   中：the Chinese     (empty: not written yet — not spoken, a card shows 【待写】)
#   英：the English     (empty: the Chinese is shown)
#   # a comment line

const FILE := "res://data/台词.txt"
static var path := FILE          # tests point this at their own copy
static var _t: Dictionary = {}   # id -> [zh, en]
static var _loaded := false


# read the file again (tests): the caller clears Copy's, Ship's and Txt's copies first —
# (not named reload: that is the script resource's own, and re-runs its static setup)
static func read_again() -> void:
	_loaded = false
	_t = {}
	_load()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(path):
		return
	var id := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var ln := raw.strip_edges(false, true).trim_suffix("\r")
		var s := ln.strip_edges()
		if s.begins_with("#") or s.begins_with("="):
			continue
		if s.begins_with("[") and s.ends_with("]") and s.length() > 2:
			id = s.substr(1, s.length() - 2).strip_edges()
			_t[id] = ["", ""]
			continue
		if id == "":
			continue
		for pre in [["中：", 0], ["中:", 0], ["英：", 1], ["英:", 1]]:
			if s.begins_with(pre[0]):
				_t[id][pre[1]] = s.substr(str(pre[0]).length()).strip_edges().replace("\\n", "\n")
	# Liang's lines kept in txt.gd
	for k in _t:
		if str(k).begins_with("txt.") and str(_t[k][0]) != "":
			Txt.ov[str(k).substr(4)] = [_t[k][0], _t[k][1] if str(_t[k][1]) != "" else _t[k][0]]


static func has(id: String) -> bool:
	_load()
	return _t.has(id)


static func get_pair(id: String) -> Array:
	_load()
	return _t.get(id, [])


static func ids() -> Array:
	_load()
	return _t.keys()


# a ship or course file as loaded: its radio lines and its story, as the file has them
static func apply_ship(ship_id: String, d: Dictionary) -> void:
	_load()
	if _t.is_empty():
		return
	var course_pre := "course.%s." % ship_id
	var story_pre := "story.%s." % ship_id
	for k in _t:
		var key := str(k)
		var p: Array = _t[k]
		if key.begins_with(course_pre) and d.get("lines") is Dictionary:
			var lid := key.substr(course_pre.length())
			if d.lines.has(lid) and d.lines[lid] is Dictionary:
				d.lines[lid].zh = p[0] if str(p[0]) != "" else Copy.TODO[0]
				d.lines[lid].en = p[1] if str(p[1]) != "" else (p[0] if str(p[0]) != "" else Copy.TODO[1])
		elif key.begins_with(story_pre) and d.has("story"):
			_set_path(d.story, key.substr(story_pre.length()).split("."), p)


# walk a story path (keys and list indices) and lay the pair on what is there:
# [zh, en], a recorder fragment [time, who, zh, en], or {zh, en}
static func _set_path(node, parts: PackedStringArray, p: Array) -> void:
	var at = node
	for part in parts:
		if at is Dictionary and at.has(part):
			at = at[part]
		elif at is Array and part.is_valid_int() and int(part) < at.size():
			at = at[int(part)]
		else:
			return
	if str(p[0]) == "":
		return
	var en: String = p[1] if str(p[1]) != "" else p[0]
	if at is Dictionary:
		at.zh = p[0]
		at.en = en
	elif at is Array and at.size() == 2:
		at[0] = p[0]
		at[1] = en
	elif at is Array and at.size() == 4:
		at[2] = p[0]
		at[3] = en
