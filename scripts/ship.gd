class_name Ship
# A ship type is data: ships/<id>.json (written by tools/ship_export.gd from
# an authoring script). This builds it into a World and answers questions
# about its systems setup, so no game code has to know any ship by name.

const DIR := "res://ships/"
const CONTENTS = preload("res://scripts/contents.gd")

static var _cache := {}


static func load_data(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var f := FileAccess.open(DIR + id + ".json", FileAccess.READ)
	if f == null:
		push_error("no ship file for %s" % id)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("ship file %s is not valid JSON" % id)
		return {}
	# the containers the file left empty get what they really hold (scripts/contents.gd)
	CONTENTS.add(d)
	# 108 号 第 5 件 (user 2026-10-29 "C 折中"): the structure's scrap is priced by the tonne, the
	# same for every ship (material-weighted), not each file's own figure
	if not d.has("value"):
		d.value = {}
	d.value.metal = scrap_value(id, d)
	# and the ship's whole worth with it (the recovery's denominator, the market's prices)
	Variant.revalue(d)
	# the author's edits in data/台词.txt: course radio lines and the story (scripts/lines.gd)
	Lines.apply_ship(id, d)
	_cache[id] = d
	return d


# what the structure fetches as scrap: its metal pieces' tonnes, weighted by their material's price
# (titanium more a tonne, composite less), at one price a tonne for every ship. A hopper's ore is
# priced as ore, not here (scripts/world.gd finalize does the same sum).
const SCRAP_PER_T := 150.0


static func scrap_value(id: String, d: Dictionary) -> float:
	var ore := float(d.get("ore", {}).get("price", 0.0)) > 0.0
	var t := 0.0
	for pd in d.get("pieces", []):
		if str(pd.get("cls", "metal")) != "metal" or (ore and str(pd.get("kind", "")) == "ore"):
			continue
		var m := float(pd.mass) if pd.has("mass") else _area(pd) * float(pd.get("density", 1.0))
		t += m * float(Mat.def(str(Mat.resolve(id, pd)[0])).get("price", 1.0))
	return snappedf(t * SCRAP_PER_T, 1.0)


static func _area(pd: Dictionary) -> float:
	var pts := PackedVector2Array()
	for q in pd.get("poly", []):
		pts.append(Vector2(q[0], q[1]))
	return absf(Geom.area(pts))


# for tests that break a ship on purpose: the next load_data reads this instead
static func override(id: String, d: Dictionary) -> void:
	_cache[id] = d


static func clear_cache() -> void:
	_cache = {}


static func _v(a) -> Vector2:
	return Vector2(a[0], a[1]) * Geom.M


static func _poly(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(q[0], q[1]) * Geom.M)
	return out


# how far a ship reaches above and below its keel line: Vector2(top, bottom) in m, y down
# (the berth lifts its top and drops its floor for a tall one: Dock.configure)
# the ship's outline box in metres, as it lies in the berth
static func bounds(d: Dictionary) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pd in d.get("pieces", []):
		for q in pd.get("poly", []):
			lo = Vector2(minf(lo.x, float(q[0])), minf(lo.y, float(q[1])))
			hi = Vector2(maxf(hi.x, float(q[0])), maxf(hi.y, float(q[1])))
	return Rect2(lo, hi - lo) if lo.x < INF else Rect2()


static func extent(d: Dictionary) -> Vector2:
	var top := 0.0
	var bottom := 0.0
	for pd in d.get("pieces", []):
		for q in pd.get("poly", []):
			top = minf(top, float(q[1]))
			bottom = maxf(bottom, float(q[1]))
	return Vector2(top, bottom)


# Everything: pieces, joints, lines, controls and rooms. Returns key -> piece.
static func build(w, d: Dictionary) -> Dictionary:
	var by_key := {}
	var hidden := []
	for pd in d.get("pieces", []):
		var opts := {}
		for k in ["density", "cut_speed", "tag", "name_key", "cls", "value", "cond", "art", "fragile", "room", "barrier", "door", "door_open", "hazard", "temp", "mandatory", "dest", "mass", "scope"]:
			if pd.has(k):
				opts[k] = pd[k]
		# 87-1: what the part is made of, and the beam's speed through it (data/materials.json)
		var mr: Array = Mat.resolve(str(d.get("id", "")), pd)
		opts.mat = mr[0]
		opts.cut_speed = mr[1]
		if pd.has("art_xf"):
			var a: Array = pd.art_xf
			opts.art_xf = Transform2D(Vector2(a[0], a[1]), Vector2(a[2], a[3]), Vector2(a[4], a[5]) * Geom.M)
		if pd.has("art_size"):
			opts.art_size = _v(pd.art_size)
		if pd.has("open_dir"):
			opts.open_dir = _v(pd.open_dir)
		var p = w.add_piece(pd.kind, _poly(pd.poly), opts)
		p.key = str(pd.get("key", ""))
		if p.door:
			p.open_t = 1.0 if p.door_open else 0.0
		if pd.get("rig", false):
			p.set_meta("rig", true)
		if pd.has("segments"):
			p.set_meta("segments", pd.segments)
		p.label = d.get("labels", {}).get(p.tag, "")
		by_key[pd.key] = p
		if pd.has("hidden_by"):
			hidden.append([p, pd.hidden_by])
	for h in hidden:
		var cov = by_key.get(h[1])
		if cov != null:
			h[0].hidden_by = cov.id
	for jd in d.get("joints", []):
		var a = by_key.get(jd.a)
		var b = by_key.get(jd.b) if jd.b != null else null
		if a == null or (jd.b != null and b == null):
			push_warning("ship %s: joint between missing pieces %s / %s" % [d.get("id", "?"), jd.a, jd.b])
			continue
		var j = w.add_joint(a, b, jd.type, _v(jd.at))
		if jd.has("tag"):
			j.set_meta("tag", jd.tag)
	for ld in d.get("lines", []):
		var a = by_key.get(ld.a)
		var b = by_key.get(ld.b)
		if a == null or b == null:
			push_warning("ship %s: line %s has a missing end" % [d.get("id", "?"), ld.id])
			continue
		w.add_line(ld.id, ld.kind, ld.net, a, _v(ld.pa), b, _v(ld.pb), _poly(ld.path))
		# a line that came in already severed (ARK-01's trunk at L6): where it was cut
		if ld.has("cut"):
			var l = w.lines[ld.id]
			l.alive = false
			l.cut_at = _v(ld.cut)
	for cd in d.get("ctrls", []):
		var opts := {}
		for k in ["state", "medium", "target", "hidden_room"]:
			if cd.has(k):
				opts[k] = cd[k]
		w.add_ctrl(cd.id, cd.kind, by_key.get(cd.piece) if cd.piece != null else null, _v(cd.at), opts)
	rooms(w, d)
	return by_key


# rooms only (a saved contract brings its own pieces)
static func rooms(w, d: Dictionary) -> void:
	for rd in d.get("rooms", []):
		w.add_room(rd.name, _poly(rd.poly))


# ---------------------------------------------------------------- lookups

static func ctrl_cfg(d: Dictionary, id: String) -> Dictionary:
	return d.get("ctrls_cfg", {}).get(id, {})


static func label(d: Dictionary, tag: String) -> String:
	return d.get("labels", {}).get(tag, "")


static func room_name_key(d: Dictionary, room: String) -> String:
	return d.get("room_names", {}).get(room, "room_" + room)
