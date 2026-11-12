extends SceneTree
# 零件图鉴 (2026-11-11): collects every drawn part in ships/*.json, de-duplicates by
# (resolved art, name_key), renders each one the way the game draws it onto a dark
# section-plate cell, and writes raw cell PNGs plus a manifest for tests/art_atlas_build.py.
# Draws nothing new and changes no art. Reads ships/*.json only; touches no save.
# tools/run_test.sh tests/art_atlas.gd -- <out_dir>

const CW := 480
const CH := 360
const COLS := 4
const ROWS := 3
const M := 48.0
const STRUCT := ["hull", "hatch", "bulkhead", "deck", "keel", "rib", "rail", "beam", "strut", "plate", "door", "film", "ice", "ore", "bracket"]

var out := "E:/godot/zeropower/proofs/零件图鉴_20261111"
var node: Node2D
var font: Font
var batch: Array = []
var entries: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	root.add_child(preload("res://tests/test_window.gd").new())
	font = Fonts.get_font("Regular")
	Art.EQ.ext = Art.SH
	Art.EQ.detail = Art.DT
	_collect()
	node = Node2D.new()
	node.draw.connect(_paint)
	root.add_child(node)
	_run()


func _route(nk: String, art: String) -> Array:
	# mirrors Art.EQ.draw: detail (Pal.solid) > ships > equip > the piece's own art
	var EQ = Art.EQ
	var alt := ""
	var via := "own"
	if Pal.solid and EQ.detail != null and EQ.detail.BY_NAME.has(nk):
		alt = EQ.detail.BY_NAME[nk]
		via = "detail"
	elif EQ.ext != null and EQ.ext.BY_NAME.has(nk):
		alt = EQ.ext.BY_NAME[nk]
		via = "ships"
	elif EQ.BY_NAME.has(nk):
		alt = EQ.BY_NAME[nk]
		via = "equip"
	if alt != "" and alt != art and EQ._has(alt):
		return [alt, via]
	return [art, "own"]


func _file_of(art: String) -> String:
	var EQ = Art.EQ
	if art in EQ.DRAWN:
		return "art_equip.gd"
	if art in Art.SH.DRAWN:
		return "art_ships.gd"
	if art in Art.DT.DRAWN:
		return "art_detail.gd"
	if art == "" or art == "window":
		return "不画"
	return "art.gd"


func _collect() -> void:
	var groups := {}
	var dir := DirAccess.open("res://ships")
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.open("res://ships/" + f, FileAccess.READ).get_as_text())
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var sid: String = f.get_basename()
		for pd in d.get("pieces", []):
			var art: String = str(pd.get("art", ""))
			if art == "":
				continue
			var nk: String = str(pd.get("name_key", ""))
			var r := _route(nk, art)
			var key: String = str(r[0]) + "|" + nk
			if not groups.has(key):
				groups[key] = {"art": r[0], "raw_arts": {}, "via": r[1], "name_key": nk, "ships": {}, "sizes": {}, "kinds": {}, "n": 0, "pds": []}
			var g: Dictionary = groups[key]
			g.n += 1
			g.ships[sid] = int(g.ships.get(sid, 0)) + 1
			g.raw_arts[art] = int(g.raw_arts.get(art, 0)) + 1
			g.kinds[str(pd.get("kind", ""))] = int(g.kinds.get(str(pd.get("kind", "")), 0)) + 1
			var sz: Array = pd.get("art_size", [1, 1])
			var sk := "%.1fx%.1f" % [float(sz[0]), float(sz[1])]
			if not g.sizes.has(sk):
				g.sizes[sk] = 0
			g.sizes[sk] += 1
			g.pds.append([sk, pd, sid])
	for key in groups:
		var g: Dictionary = groups[key]
		var best := ""
		var bn := -1
		for sk in g.sizes:
			if g.sizes[sk] > bn:
				bn = g.sizes[sk]
				best = sk
		# the representative: most common size, unrotated if there is one
		var pick = null
		for e in g.pds:
			if e[0] != best:
				continue
			var xf: Array = e[1].get("art_xf", [1, 0, 0, 1, 0, 0])
			if pick == null:
				pick = e
			if absf(float(xf[1])) < 0.001 and float(xf[0]) > 0.99:
				pick = e
				break
		g.best = best
		g.pick = pick[1]
		g.pick_ship = pick[2]
		g.erase("pds")
		entries.append(g)
	entries.sort_custom(func(x, y): return str(x.art) + "|" + str(x.name_key) < str(y.art) + "|" + str(y.name_key))


func _piece(pd: Dictionary, fallback_art: String):
	var p := Model.Piece.new()
	for k in ["density", "cut_speed", "tag", "name_key", "cls", "value", "cond", "art", "fragile", "room", "barrier", "kind", "label"]:
		if pd.has(k) and k in p:
			p.set(k, pd[k])
	var poly := PackedVector2Array()
	for q in pd.get("poly", []):
		poly.append(Vector2(float(q[0]), float(q[1])) * M)
	p.poly = poly
	p.art = fallback_art
	var sz: Array = pd.get("art_size", [1, 1])
	p.art_size = Vector2(float(sz[0]), float(sz[1]))
	if pd.has("art_xf"):
		var x: Array = pd.art_xf
		p.art_xf = Transform2D(Vector2(x[0], x[1]), Vector2(x[2], x[3]), Vector2(x[4], x[5]) * M)
	return p


# fit (scale, offset) so the art box and the part's polygon sit inside a cell
func _fit(p) -> Array:
	var r := Rect2(Vector2.ZERO, p.art_size * M)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in pts:
		var v: Vector2 = p.art_xf * q
		lo = lo.min(v)
		hi = hi.max(v)
	for q in p.poly:
		lo = lo.min(q)
		hi = hi.max(q)
	var ext := hi - lo
	var s := clampf(minf((CW - 56.0) / maxf(ext.x, 1.0), (CH - 56.0) / maxf(ext.y, 1.0)), 0.35, 3.0)
	var off := Vector2(CW, CH) * 0.5 - (lo + ext * 0.5) * s
	return [s, off]


func _paint() -> void:
	for i in batch.size():
		var e: Dictionary = batch[i]
		var org := Vector2((i % COLS) * CW, (i / COLS) * CH)
		node.draw_rect(Rect2(org, Vector2(CW, CH)), Color(0.052, 0.055, 0.063))
		var p = e.p
		var fit: Array = e.fit
		var s: float = fit[0]
		var at: Vector2 = org + fit[1]
		var struct: bool = e.struct
		# the part's outline as the game sets it
		node.draw_set_transform(at, 0.0, Vector2(s, s))
		var pl := PackedVector2Array(p.poly)
		if pl.size() >= 3:
			pl.append(pl[0])
			node.draw_polyline(pl, Pal.ink(0.35 if struct else 0.5), 1.0 / s)
		# the art
		var xf: Transform2D = p.art_xf
		node.draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, at) * xf)
		Art.draw(node, p.art, p.art_size * M, p, font)
		node.draw_set_transform(Vector2.ZERO)
		e.scale_used = s


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(out + "/raw")
	var per := COLS * ROWS
	var idx := 0
	while idx < entries.size():
		batch = []
		for i in per:
			if idx + i >= entries.size():
				break
			var g: Dictionary = entries[idx + i]
			var p = _piece(g.pick, g.art)
			g["p"] = p
			g["fit"] = _fit(p)
			g["struct"] = g.kinds.keys().all(func(k): return k in STRUCT)
			batch.append(g)
		node.queue_redraw()
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = load("res://tests/cap.gd").to_srgb8(root.get_texture().get_image())
		for i in batch.size():
			var cell := img.get_region(Rect2i((i % COLS) * CW, (i / COLS) * CH, CW, CH))
			cell.save_png("%s/raw/%04d.png" % [out, idx + i])
		idx += batch.size()
	var man := []
	for i in entries.size():
		var g: Dictionary = entries[i]
		var p = g.p
		var ships_list := []
		for s in g.ships:
			ships_list.append([s, g.ships[s]])
		man.append({
			"idx": i, "art": g.art, "via": g.via, "name_key": g.name_key,
			"name_zh": Txt.t(g.name_key) if g.name_key != "" else "",
			"file": _file_of(g.art), "raw_arts": g.raw_arts, "kinds": g.kinds, "struct": g.struct,
			"size": g.best, "sizes": g.sizes, "ships": ships_list, "n": g.n,
			"scale": snappedf(float(g.scale_used), 0.01), "tag": p.tag, "label": p.label,
			"pick_ship": g.pick_ship, "cls": p.cls,
		})
	var f := FileAccess.open(out + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(man, "\t"))
	f.close()
	print("atlas entries ", entries.size())
	quit()
