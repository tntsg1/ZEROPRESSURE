extends RefCounted
# 工业剖面 · Material Depth Pass (2026-11-10). Only read while Pal.solid is on.
# User (via review, 7/10 -> aim 8.5): "the big holds are empty slabs, the engines flat; materials
# look alike; no visual focus". Kept 2D, black-and-white, engineering-drawing precise; no overall
# brightening. Everything here is DRAWING ONLY: frames, hatches and gantries in a hold are not
# parts, nothing in the ship data or the play changes.
#
#  - holds: transverse web frames and longitudinal stringers on the wall of every big compartment;
#    a hold (cargo inside, or very big) also gets its deck hatch, an overhead gantry rail with
#    one trolley and hook, and lashing points along the floor. Sparse, not filled.
#  - engines: housing layers stepping in (shadow + lit lip), a bolted flange ring, cooling fins on
#    the shaded half, one metallic highlight on the lit edge
#  - tanks: domed end caps, two saddles, a pipe stub with its flange on top
#  - beams: the web's dark centre line between two lit flange lines
#  - bow: the forward hull plating doubled (an inner plate line and a rivet row)
# All of it built once per outline and replayed as one triangle list (Art.EQ.seg_tris).

const M := 48.0
const ENGINE_LAYERED := ["eng_core", "eng_front", "engine_s", "gen", "turbo", "turboexpander", "flywheel_rotor", "hpu", "screw_comp", "top_drive", "reactor"]

static var _EQ = null


static func _eq():
	if _EQ == null:
		_EQ = Art.EQ
	return _EQ


static func _segs(tp: PackedVector2Array, tc: PackedColorArray, segs: PackedVector2Array, col: Color, w: float) -> void:
	if segs.is_empty():
		return
	var t: Array = _eq().seg_tris(segs, PackedColorArray([col]), w)
	tp.append_array(t[0])
	tc.append_array(t[1])


static func _tris(tp: PackedVector2Array, tc: PackedColorArray, poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3:
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	for k in tri:
		tp.append(poly[k])
		tc.append(col)


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _clip_fill(tp: PackedVector2Array, tc: PackedColorArray, clip: PackedVector2Array, r: Rect2, col: Color) -> void:
	for q in Geometry2D.intersect_polygons(clip, _rect(r)):
		_tris(tp, tc, q, col)


static func _clip_line(segs: PackedVector2Array, clip: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	for q in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), clip):
		for i in q.size() - 1:
			segs.append(q[i])
			segs.append(q[i + 1])


# ---------------------------------------------------------------- holds

# r: a room of the world. cover: drawn over a closed compartment (dimmer) or on an open one's wall
static func room(w, r: Dictionary, cover: bool) -> Array:
	var key := "solid_struct_c" if cover else "solid_struct_o"
	if r.has(key):
		return r[key]
	var out := _room_build(w, r, cover)
	r[key] = out
	return out


static func _is_hold(w, r: Dictionary, area_m2: float) -> bool:
	if area_m2 > 120.0:
		return true
	for id in w.order:
		var p = w.pieces[id]
		if p.room == r.name and p.art in ["cargo", "crate", "locker", "vault", "safe_deposit"]:
			return true
	return false


static func _room_build(w, r: Dictionary, cover: bool) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var poly: PackedVector2Array = r.poly
	var bb: Rect2 = r.bbox
	var area := Geom.area(poly) / (M * M)
	if area < 50.0 or bb.size.x < 6.0 * M or bb.size.y < 3.0 * M:
		return [tp, tc]
	var inner := Geometry2D.offset_polygon(poly, -0.25 * M)
	if inner.is_empty():
		return [tp, tc]
	var clip: PackedVector2Array = inner[0]
	var k := 0.7 if cover else 1.0
	var web := Color(0.036, 0.038, 0.044, 1.0) if cover else Color(0.062, 0.065, 0.074, 1.0)
	var lit := Pal.ink(0.36 * k)
	var shade := Color(0, 0, 0, 0.88 * k)
	var hairs := PackedVector2Array()
	var lits := PackedVector2Array()
	var shades := PackedVector2Array()
	# transverse web frames, every ~3.6 m, 0.4 m deep
	var n := int(bb.size.x / (3.6 * M))
	var fw := 0.62 * M
	for i in range(1, n + 1):
		var x := bb.position.x + bb.size.x * i / (n + 1)
		_clip_fill(tp, tc, clip, Rect2(x - fw * 0.5, bb.position.y, fw, bb.size.y), web)
		_clip_line(lits, clip, Vector2(x - fw * 0.5, bb.position.y), Vector2(x - fw * 0.5, bb.end.y))
		_clip_line(shades, clip, Vector2(x + fw * 0.5 + 2.0, bb.position.y), Vector2(x + fw * 0.5 + 2.0, bb.end.y))
		# lightening holes down the web: a dark slot every metre and a half
		var y := bb.position.y + 0.9 * M
		while y < bb.end.y - 0.9 * M:
			var hole := Rect2(x - fw * 0.22, y, fw * 0.44, 0.55 * M)
			if Geometry2D.is_point_in_polygon(hole.get_center(), clip):
				_tris(tp, tc, _rect(hole), Color(0.02, 0.021, 0.024, 1.0))
			y += 1.5 * M
	# longitudinal stringers at a third and two thirds of the height
	for f in [0.34, 0.67]:
		var y: float = bb.position.y + bb.size.y * f
		_clip_fill(tp, tc, clip, Rect2(bb.position.x, y - 0.17 * M, bb.size.x, 0.34 * M), web)
		_clip_line(lits, clip, Vector2(bb.position.x, y - 0.17 * M), Vector2(bb.end.x, y - 0.17 * M))
		_clip_line(shades, clip, Vector2(bb.position.x, y + 0.17 * M + 2.0), Vector2(bb.end.x, y + 0.17 * M + 2.0))
	if _is_hold(w, r, area):
		# the deck hatch: a coaming across the top, two hinge knuckles, the cover's seam
		var hw := minf(bb.size.x * 0.42, 14.0 * M)
		var hx := bb.get_center().x - hw * 0.5
		var hy := bb.position.y + 0.3 * M
		var hr := Rect2(hx, hy, hw, 0.8 * M)
		_clip_fill(tp, tc, clip, hr, Color(0.06, 0.062, 0.07, 1.0) if not cover else Color(0.042, 0.044, 0.05, 1.0))
		_clip_line(lits, clip, hr.position, Vector2(hr.end.x, hr.position.y))
		_clip_line(shades, clip, Vector2(hr.position.x, hr.end.y + 1.5), Vector2(hr.end.x, hr.end.y + 1.5))
		_clip_line(hairs, clip, Vector2(hr.get_center().x, hr.position.y), Vector2(hr.get_center().x, hr.end.y))
		for s in [0.2, 0.8]:
			var kx: float = hx + hw * s
			_tris(tp, tc, _rect(Rect2(kx - 0.18 * M, hy - 0.12 * M, 0.36 * M, 0.2 * M)), Color(0.08, 0.083, 0.092, k))
		# the overhead gantry: a rail under the deckhead, one trolley, its hook let down a little
		var gy := bb.position.y + 1.2 * M
		var g0 := bb.position.x + 0.8 * M
		var g1 := bb.end.x - 0.8 * M
		_clip_fill(tp, tc, clip, Rect2(g0, gy, g1 - g0, 0.26 * M), Color(0.06, 0.063, 0.071, 1.0))
		_clip_line(lits, clip, Vector2(g0, gy), Vector2(g1, gy))
		var tx := bb.position.x + bb.size.x * 0.62
		var tr := Rect2(tx - 0.55 * M, gy + 0.16 * M, 1.1 * M, 0.42 * M)
		if Geometry2D.is_point_in_polygon(tr.get_center(), clip):
			_tris(tp, tc, _rect(Rect2(tr.position + Vector2(3, 4), tr.size)), Color(0, 0, 0, 0.45 * k))
			_tris(tp, tc, _rect(tr), Color(0.085, 0.088, 0.098, 1.0))
			lits.append(tr.position)
			lits.append(Vector2(tr.end.x, tr.position.y))
			var hook_top := Vector2(tx, tr.end.y)
			var hook_end := hook_top + Vector2(0, minf(1.6 * M, bb.size.y * 0.3))
			hairs.append(hook_top)
			hairs.append(hook_end)
			_tris(tp, tc, _rect(Rect2(hook_end - Vector2(0.14 * M, 0), Vector2(0.28 * M, 0.2 * M))), Color(0.13, 0.134, 0.146, 1.0))
		# lashing points along the deck
		var ly := bb.end.y - 0.45 * M
		var lx := bb.position.x + 1.0 * M
		while lx < bb.end.x - 1.0 * M:
			var c := Vector2(lx, ly)
			if Geometry2D.is_point_in_polygon(c, clip):
				_tris(tp, tc, _rect(Rect2(c - Vector2(2.5, 2.5), Vector2(5, 5))), Pal.ink(0.16 * k))
			lx += 1.8 * M
	_segs(tp, tc, shades, shade, 6.0)
	_segs(tp, tc, lits, lit, 3.2)
	_segs(tp, tc, hairs, Pal.ink(0.28 * k), 2.0)
	return [tp, tc]


# ---------------------------------------------------------------- machines and plates

static func detail(w, p, poly: PackedVector2Array, m: String) -> Array:
	var first := poly[0] if poly.size() > 0 else Vector2.ZERO
	var sig: int = hash([p.tri_sig, m, first, p.kind])
	if p.has_meta("solid_detail") and p.get_meta("solid_detail")[0] == sig:
		return p.get_meta("solid_detail")[1]
	var out: Array
	match m:
		"engine", "reactor":
			out = _engine(poly) if p.art in ENGINE_LAYERED else [PackedVector2Array(), PackedColorArray()]
		"tank":
			out = _tank(poly)
		_:
			if p.kind in ["keel", "beam"]:
				out = _beam(poly)
			elif p.kind in ["hull", "hatch"] and _is_bow(w, poly):
				out = _bow(poly)
			else:
				out = [PackedVector2Array(), PackedColorArray()]
	p.set_meta("solid_detail", [sig, out])
	return out


static func _rings(poly: PackedVector2Array, d: float) -> Array:
	var out: Array = []
	for q in Geometry2D.offset_polygon(poly, -d):
		if q.size() >= 3:
			out.append(q)
	return out


static func _ring_segs(segs: PackedVector2Array, ring: PackedVector2Array, off: Vector2 = Vector2.ZERO) -> void:
	for i in ring.size():
		segs.append(ring[i] + off)
		segs.append(ring[(i + 1) % ring.size()] + off)


# an engine: the housing stepping in twice (each step a shadow under a lit lip), a bolted
# flange on the first step, cooling fins across the shaded half, one highlight on the lit edge
static func _engine(poly: PackedVector2Array) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var bb := Geom.bbox(poly)
	var s := minf(bb.size.x, bb.size.y)
	if s < 14.0:
		return [tp, tc]
	var shades := PackedVector2Array()
	var lips := PackedVector2Array()
	var bolts := PackedVector2Array()
	var steps := [0.12, 0.27] if s > 40.0 else [0.16]
	var li := 0
	for f in steps:
		for ring in _rings(poly, s * f):
			# a darker tone inside each step (the housing goes in)
			_tris(tp, tc, ring, Color(0, 0, 0, 0.38))
			_ring_segs(shades, ring, -Look.LIGHT_DIR * 2.2)
			_ring_segs(lips, ring)
			if li == 0:
				for i in ring.size():
					var a: Vector2 = ring[i]
					var b: Vector2 = ring[(i + 1) % ring.size()]
					var nb := int(a.distance_to(b) / 9.0)
					for k in nb:
						var c := a.lerp(b, (k + 0.5) / maxf(nb, 1.0))
						bolts.append(c - Vector2(0.9, 0))
						bolts.append(c + Vector2(0.9, 0))
		li += 1
	# fins on the half away from the light, across the long axis
	var long_x := bb.size.x >= bb.size.y
	var fins := PackedVector2Array()
	var span := bb.size.x if long_x else bb.size.y
	var depth := (bb.size.y if long_x else bb.size.x) * 0.16
	var t := 0.12
	while t < 0.88:
		var a: Vector2
		var b: Vector2
		if long_x:
			a = Vector2(bb.position.x + span * t, bb.end.y - s * 0.04)
			b = a - Vector2(0, depth)
		else:
			a = Vector2(bb.end.x - s * 0.04, bb.position.y + span * t)
			b = a - Vector2(depth, 0)
		for q in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
			for i in q.size() - 1:
				fins.append(q[i])
				fins.append(q[i + 1])
		t += 6.0 / maxf(span, 1.0)
	# one metallic highlight along the lit long edge, a third of its length
	var hl := PackedVector2Array()
	if long_x:
		var y := bb.position.y + s * 0.06
		hl.append(Vector2(bb.position.x + span * 0.18, y))
		hl.append(Vector2(bb.position.x + span * 0.52, y))
	else:
		var x := bb.position.x + s * 0.06
		hl.append(Vector2(x, bb.position.y + span * 0.18))
		hl.append(Vector2(x, bb.position.y + span * 0.52))
	_segs(tp, tc, shades, Color(0, 0, 0, 0.9), 4.4)
	_segs(tp, tc, lips, Pal.ink(0.62), 2.0)
	_segs(tp, tc, fins, Pal.ink(0.3), 1.8)
	_segs(tp, tc, bolts, Pal.ink(0.58), 2.4)
	_segs(tp, tc, hl, Pal.ink(0.9), 2.6)
	return [tp, tc]


# a tank: domed ends (a shaded crescent at each end, a lit arc on the near side), two
# saddles under it, a pipe stub with its flange on top
static func _tank(poly: PackedVector2Array) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var bb := Geom.bbox(poly)
	var long_x := bb.size.x >= bb.size.y
	var L := bb.size.x if long_x else bb.size.y
	var D := bb.size.y if long_x else bb.size.x
	if D < 12.0 or L < D * 1.1:
		return [tp, tc]
	var r := D * 0.5
	var arcs := PackedVector2Array()
	var darcs := PackedVector2Array()
	for end in [0, 1]:
		# the dome's seam: an arc a radius in from the end
		var cx := (bb.position.x + r * 0.55) if end == 0 else (bb.end.x - r * 0.55)
		var cy := bb.get_center().y
		if not long_x:
			cx = bb.get_center().x
			cy = (bb.position.y + r * 0.55) if end == 0 else (bb.end.y - r * 0.55)
		var prev := Vector2.INF
		for i in 13:
			var ang := lerpf(-PI * 0.5, PI * 0.5, i / 12.0)
			var v := Vector2(cos(ang) * r * 0.35 * (1.0 if end == 1 else -1.0), sin(ang) * r * 0.92)
			if not long_x:
				v = Vector2(v.y, v.x)
			var q := Vector2(cx, cy) + v
			if prev != Vector2.INF:
				(arcs if end == 0 else darcs).append(prev)
				(arcs if end == 0 else darcs).append(q)
			prev = q
	# saddles: two dark blocks under the shell with a lit top
	var sad := PackedVector2Array()
	for f in [0.25, 0.75]:
		var sr: Rect2
		if long_x:
			sr = Rect2(bb.position.x + L * f - D * 0.18, bb.end.y - D * 0.16, D * 0.36, D * 0.16)
		else:
			sr = Rect2(bb.end.x - D * 0.16, bb.position.y + L * f - D * 0.18, D * 0.16, D * 0.36)
		_clip_fill(tp, tc, poly, sr, Color(0.035, 0.036, 0.04, 0.9))
		sad.append(sr.position)
		sad.append(Vector2(sr.end.x, sr.position.y) if long_x else Vector2(sr.position.x, sr.end.y))
	# the pipe stub: a short round bar off the top with a flange
	var top := Vector2(bb.position.x + L * 0.5, bb.position.y) if long_x else Vector2(bb.position.x, bb.position.y + L * 0.5)
	var dir := Vector2(0, 1) if long_x else Vector2(1, 0)
	var p0 := top + dir * D * 0.04
	var p1 := top + dir * D * 0.22
	_segs(tp, tc, PackedVector2Array([p0, p1]), Color(0.02, 0.021, 0.024, 1.0), 5.0)
	_segs(tp, tc, PackedVector2Array([p0, p1]), Color(0.2, 0.205, 0.22, 1.0), 3.0)
	var fl := dir.orthogonal()
	_segs(tp, tc, PackedVector2Array([p1 - fl * 4.0, p1 + fl * 4.0]), Pal.ink(0.4), 1.6)
	_segs(tp, tc, darcs, Color(0, 0, 0, 0.5), 2.2)
	_segs(tp, tc, arcs, Pal.ink(0.32), 1.2)
	_segs(tp, tc, sad, Pal.ink(0.3), 1.0)
	return [tp, tc]


# a load-carrying beam: the web's dark centre line between two lit flange lines
static func _beam(poly: PackedVector2Array) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var bb := Geom.bbox(poly)
	var long_x := bb.size.x >= bb.size.y
	var D := bb.size.y if long_x else bb.size.x
	if D < 7.0:
		return [tp, tc]
	var webs := PackedVector2Array()
	var flg := PackedVector2Array()
	var c := bb.get_center()
	if long_x:
		_clip_line(webs, poly, Vector2(bb.position.x, c.y), Vector2(bb.end.x, c.y))
		_clip_line(flg, poly, Vector2(bb.position.x, bb.position.y + D * 0.22), Vector2(bb.end.x, bb.position.y + D * 0.22))
	else:
		_clip_line(webs, poly, Vector2(c.x, bb.position.y), Vector2(c.x, bb.end.y))
		_clip_line(flg, poly, Vector2(bb.position.x + D * 0.22, bb.position.y), Vector2(bb.position.x + D * 0.22, bb.end.y))
	_segs(tp, tc, webs, Color(0, 0, 0, 0.5), maxf(1.5, D * 0.16))
	_segs(tp, tc, flg, Pal.ink(0.22), 1.0)
	return [tp, tc]


# the bow: the forward fifth of the hull, its plating doubled — an inner plate line and a row
# of rivets along it (the most detail goes where the eye goes first)
static func _is_bow(w, poly: PackedVector2Array) -> bool:
	var span: Vector2 = _span(w)
	if span.y <= span.x:
		return false
	return Geom.bbox(poly).get_center().x < span.x + (span.y - span.x) * 0.2


static func _span(w) -> Vector2:
	var key: int = w.order.size()
	if w.has_meta("solid_span") and w.get_meta("solid_span")[0] == key:
		return w.get_meta("solid_span")[1]
	var lo := INF
	var hi := -INF
	for id in w.order:
		var p = w.pieces[id]
		if p.kind == "hull" and not p.gone and p.body == null:
			var bb := Geom.bbox(p.poly)
			lo = minf(lo, bb.position.x)
			hi = maxf(hi, bb.end.x)
	var out := Vector2(lo, hi)
	w.set_meta("solid_span", [key, out])
	return out


static func _bow(poly: PackedVector2Array) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var bb := Geom.bbox(poly)
	if minf(bb.size.x, bb.size.y) < 9.0 and maxf(bb.size.x, bb.size.y) < 30.0:
		return [tp, tc]
	var inset := minf(6.0, Geom.area(poly) * 2.0 / maxf(_perimeter(poly), 1.0) * 0.42)
	var lines := PackedVector2Array()
	var rivets := PackedVector2Array()
	for ring in _rings(poly, inset):
		_ring_segs(lines, ring)
		for i in ring.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % ring.size()]
			var nb := int(a.distance_to(b) / 8.0)
			for k in nb:
				var c := a.lerp(b, (k + 0.5) / maxf(nb, 1.0))
				rivets.append(c - Vector2(0.8, 0))
				rivets.append(c + Vector2(0.8, 0))
	_segs(tp, tc, lines, Pal.ink(0.24), 1.0)
	_segs(tp, tc, rivets, Pal.ink(0.3), 1.6)
	return [tp, tc]


static func _perimeter(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].distance_to(poly[(i + 1) % poly.size()])
	return s
