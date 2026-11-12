class_name Cutaway
extends RefCounted
# 工业剖面样片 (Industrial Cutaway × Minimalist Sci-Fi), 2026-11-10. Only used while Pal.solid is on;
# with it off nothing here runs and the old picture is unchanged. design/美术方向_工业剖面_样片.md
#
# Three tiers, one light (Look.LIGHT_DIR, up and a little left):
#   tier 1  the hull's outline and the main load beams: brightest, heaviest
#   tier 2  bulkheads, decks, equipment: mid
#   tier 3  ribs, rails, small fixtures, seams, rivets: darkest, hairline
# The hull is a solid grey plate with thickness (a dark rim round a lit inner face), its
# panels alternate a little in tone (armour plates), equipment throws a short shadow on the
# compartment wall behind it, and the machines that matter (engines, cargo, power, tanks)
# get the bright line and an inner rim; the rest step back.

const FastDraw = preload("res://scripts/fast_draw.gd")
const Depth3 = preload("res://scripts/cutaway_depth.gd")   # Material Depth Pass
static var skip := {}   # tests: parts of the picture left out to measure them (vol, extra, rooms)
# How quiet the background is (user 2026-11-10: the back walls' grid "很花", it drowned the machines
# and the drone). 0 the first cut; 1 no hold frames, no wall grid, the wall a near-flat dark face;
# 2 also the decks and bulkheads at a quarter of the foreground's line, ribs and struts fainter and
# thinner; 3 quieter still. The pick: CALM (tests/calm_shot.gd shoots them side by side).
const CALM := 2
static var calm := CALM


# the line strength a structure / frame member gets at the current calm level (1 = as designed)
static func _calm_k(m: String) -> float:
	if calm < 2:
		return 1.0
	match m:
		"structure":
			return 0.62 if calm == 2 else 0.45     # 0.38 -> 0.24 (a quarter of the hull's 0.96) / 0.17
		"frame":
			return 0.55 if calm == 2 else 0.38     # 0.30 -> 0.16 / 0.11
	return 1.0
const W1 := 2.4     # px: tier 1 line
const W2 := 1.3     # px: tier 2
const W3 := 1.0     # px: tier 3
const RIM := 5.0    # px: the plate's thickness (the dark band inside the hull's outline)
const SHADOW := 7.0 # px: how far equipment throws its shadow on the wall behind
const EDGE := 4.0   # px: how much of a tier-1 plate's side shows (its thickness)


static func _tier(p) -> int:
	match p.kind:
		"hull", "hatch", "keel", "beam":
			return 1
		"rib", "rail", "strut":
			return 3
	if p.cls == "fixture":
		return 3
	return 2


# ---------------------------------------------------------------- materials (v2)
# User 2026-11-10 (样片 7/10): each material its own set of greys — base, lit face, shaded face,
# edge — so engine, tank, pipe and armour read apart at a glance. Grey layering and thickness,
# not more lines; and the picture no brighter overall than the old one.
#   [base, lit, shade, edge alpha, warm]   (warm: a slight red lean, heat-stained metal)
const MATS := {
	"armor":     [Color(0.118, 0.123, 0.137), Color(0.2, 0.207, 0.226), Color(0.045, 0.047, 0.054), 0.9, 0.0],
	"engine":    [Color(0.07, 0.069, 0.074), Color(0.19, 0.186, 0.19), Color(0.022, 0.021, 0.022), 0.95, 0.014],
	"reactor":   [Color(0.072, 0.075, 0.082), Color(0.17, 0.176, 0.19), Color(0.026, 0.027, 0.031), 0.88, 0.0],
	"tank":      [Color(0.15, 0.153, 0.16), Color(0.36, 0.366, 0.38), Color(0.04, 0.041, 0.045), 0.7, 0.0],
	"pipe":      [Color(0.12, 0.124, 0.132), Color(0.33, 0.338, 0.355), Color(0.035, 0.036, 0.04), 0.48, 0.0],
	"cargo":     [Color(0.14, 0.142, 0.15), Color(0.25, 0.254, 0.264), Color(0.055, 0.056, 0.06), 0.72, 0.0],
	"machine":   [Color(0.078, 0.081, 0.09), Color(0.118, 0.122, 0.134), Color(0.04, 0.042, 0.047), 0.58, 0.0],
	"structure": [Color(0.066, 0.069, 0.077), Color(0.095, 0.099, 0.109), Color(0.04, 0.042, 0.047), 0.38, 0.0],
	"frame":     [Color(0.07, 0.072, 0.08), Color(0.098, 0.1, 0.11), Color(0.045, 0.046, 0.052), 0.3, 0.0],
	"legacy":    [Color(0.09, 0.094, 0.105), Color(0.13, 0.135, 0.15), Color(0.05, 0.052, 0.058), 0.55, 0.0],
	"rock":      [Color(0.085, 0.084, 0.082), Color(0.15, 0.148, 0.144), Color(0.035, 0.034, 0.033), 0.6, 0.004],
	"fixture":   [Color(0.058, 0.06, 0.067), Color(0.075, 0.078, 0.086), Color(0.04, 0.041, 0.046), 0.3, 0.0],
}
const ENGINE_ARTS := ["eng_core", "eng_front", "nozzle", "engine_s", "rcs_quad", "gen", "aux", "turbo",
	"turboexpander", "flywheel_rotor", "top_drive", "hpu", "screw_comp", "arc_furnace", "gyrotron", "nbi",
	"ech", "pellet", "actuator", "brake"]
const REACTOR_ARTS := ["reactor", "tf_coil", "divertor", "cs_stack", "port_plug", "vv_wall", "dump_res", "qpu"]
const TANK_ARTS := ["fueltank", "gastank", "sphere_tank", "cryotank", "o2cab", "water", "drum", "barrel",
	"coldbox", "cold_box_h2", "freezer", "fridge", "biobox"]
const PIPE_ARTS := ["pipe", "junction", "manifold", "standpipe", "hx", "relief", "filter", "pump", "bop",
	"bha", "reel", "insul", "radiator"]
const CARGO_ARTS := ["cargo", "crate", "locker", "vault", "safe_deposit", "shelf", "missile", "launcher",
	"toolwall", "drum_rack"]
const ARMOR_ARTS := ["armor", "shell", "grav_support", "dock", "turret", "gun_mount", "ciws"]


static func material(p) -> String:
	match p.kind:
		"hull", "hatch", "keel", "beam":
			if p.art == "" or not p.art in ENGINE_ARTS + TANK_ARTS + REACTOR_ARTS:
				return "armor"
		"bulkhead", "deck", "door", "plate":
			return "structure"
		"rib", "rail", "strut", "bracket":
			return "frame"
		"ice", "film":
			return "legacy"
		"ore":
			return "rock"
	if p.art in ENGINE_ARTS:
		return "engine"
	if p.art in REACTOR_ARTS:
		return "reactor"
	if p.art in TANK_ARTS:
		return "tank"
	if p.art in PIPE_ARTS:
		return "pipe"
	if p.art in CARGO_ARTS:
		return "cargo"
	if p.art in ARMOR_ARTS:
		return "armor"
	if p.cls == "equip":
		return "machine"
	return "fixture"


# [fill, line colour, line width, rim fill or null, material]
static func style(w, p) -> Array:
	var m := material(p)
	var mt: Array = MATS[m]
	var fill: Color = mt[0]
	var line := Pal.ink(mt[3] * _calm_k(m))
	var lw := W2
	var rim = null
	match m:
		"armor":
			rim = mt[2]
			lw = W1 if p.kind in ["hull", "hatch"] or p.cls != "equip" else W2 * 1.3
		"engine", "reactor":
			rim = mt[2]
			lw = 1.8
		"tank", "cargo":
			lw = 1.5
		"structure":
			rim = mt[2]
		"frame", "fixture":
			lw = W3
	if p.kind in ["keel", "beam"]:
		line = Pal.ink(mt[3] * 0.92)
		lw = W1 * 0.85
	if m == "legacy":
		# a sail film, an ice hull: their own pale tone stays (as the old picture has it)
		var base: Array = w._style(p)
		fill = base[0]
		line = base[1]
	if p.cls == "equip" and not p.intact:
		fill = Color(0.045, 0.045, 0.05)
		line = Pal.ink(0.32)
	if p.contam:
		line = line.lerp(Pal.tint(Pal.FLUID, line.a), 0.55)
	if p.mat != "":
		var dk := float(Mat.of(p).get("fill", 0.0)) * 0.6
		fill = Color(fill.r + dk, fill.g + dk, fill.b + dk * 1.1)
	return [fill, line, lw, rim, m]


# the inside of the plate, a rim's width in from its outline (cached with the outline)
static func _inner(p) -> Array:
	var sig: int = p.tri_sig
	if p.has_meta("solid_in") and p.get_meta("solid_in")[0] == sig:
		return p.get_meta("solid_in")[1]
	var out: Array = []
	# thin plates (a hull strip is ~14 px): the rim scales with how thick the plate is
	var thick := _thickness(p.poly)
	var inset := minf(RIM, thick * 0.24)
	if inset >= 1.5:
		for q in Geometry2D.offset_polygon(p.poly, -inset):
			if q.size() >= 3 and not Geometry2D.is_polygon_clockwise(q):
				var tri := Geometry2D.triangulate_polygon(q)
				if not tri.is_empty():
					out.append([q, tri])
	p.set_meta("solid_in", [sig, out])
	return out


# about how thick a plate is: twice its area over its perimeter (a strip's width)
static func _thickness(poly: PackedVector2Array) -> float:
	var per := 0.0
	for i in poly.size():
		per += poly[i].distance_to(poly[(i + 1) % poly.size()])
	return 2.0 * Geom.area(poly) / maxf(per, 1.0)


static func _add_poly(fp: PackedVector2Array, fc: PackedColorArray, fi: PackedInt32Array, poly: PackedVector2Array, tri: PackedInt32Array, col: Color, lit: bool, cc: Vector2, rr: float, lo := 0.78, hi := 1.24) -> void:
	var base := fp.size()
	fp.append_array(poly)
	for v in poly:
		var g := 1.0
		if lit:
			var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
			g = lerpf(lo, hi, lk * 0.5 + 0.5)
		fc.append(Color(col.r * g, col.g * g, col.b * g, col.a))
	for k in tri:
		fi.append(base + k)


# a face lit from LIGHT_DIR: shade -> base -> lit across it
static func _tone(mt: Array, lk: float) -> Color:
	var c: Color
	if lk < 0.0:
		c = (mt[0] as Color).lerp(mt[2], minf(-lk, 1.0))
	else:
		c = (mt[0] as Color).lerp(mt[1], minf(lk, 1.0))
	var wm: float = mt[4]
	return Color(c.r + wm, c.g, c.b - wm * 0.5, 1.0)


# a very big part (NR-95's 30 m hydrogen tank) would turn a whole stretch of the ship pale: past
# 8 m its material tone fades toward the plain drawing, to 55 % at 24 m and over
static func _big_k(bb: Rect2) -> float:
	return lerpf(1.0, 0.55, clampf((maxf(bb.size.x, bb.size.y) / Geom.M - 8.0) / 16.0, 0.0, 1.0))


static func _dim(mt: Array, k: float) -> Array:
	return [(mt[0] as Color) * Color(k, k, k, 1.0), (mt[1] as Color) * Color(k, k, k, 1.0), (mt[2] as Color) * Color(k, k, k, 1.0), mt[3], mt[4] * k]


static func _add_lit(fp: PackedVector2Array, fc: PackedColorArray, fi: PackedInt32Array, poly: PackedVector2Array, tri: PackedInt32Array, mt: Array, cc: Vector2, rr: float, k := 1.0) -> void:
	var base := fp.size()
	fp.append_array(poly)
	for v in poly:
		var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0) * k
		fc.append(_tone(mt, lk))
	for t in tri:
		fi.append(base + t)


static func draw_pieces(w, ci: CanvasItem, list: Array, part: String) -> void:
	if part == "shade" and skip.has("shade"):
		return
	if part == "block":
		if not skip.has("block"):
			_draw_block(w, ci, list)
		return
	# shadows first (under every fill), then rims, then faces
	var sp := PackedVector2Array()
	var scol := PackedColorArray()
	var si := PackedInt32Array()
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	var fi := PackedInt32Array()
	var segs := [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var cols := [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]
	var widths := [W1, 1.7, W2, W3]   # buckets: 0 tier 1, 1 heavy machines, 2 tier 2, 3 tier 3
	# equipment outlines go again over the material shading (which sits over the art)
	var eq_s := PackedVector2Array()
	var eq_c := PackedColorArray()
	var arts: Array = []
	var sh_off := -Look.LIGHT_DIR * SHADOW
	for p in list:
		if p.gone:
			continue
		var off: Vector2 = w.door_offset(p)
		var poly: PackedVector2Array = p.poly
		var xf := Transform2D(0.0, off)
		if off != Vector2.ZERO:
			poly = xf * poly
		var st := style(w, p)
		var m: String = st[4]
		var mt: Array = MATS[m]
		var tri: PackedInt32Array = w._tri_cached(p)
		var bb := Geom.bbox(poly)
		var cc := bb.get_center()
		var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
		var tier := _tier(p)
		var heavy: bool = m in ["engine", "reactor", "tank", "cargo"] or (m == "armor" and p.cls == "equip")
		if not tri.is_empty() and part in ["all", "fill", "shade"]:
			if not skip.has("extra") and (p.cls in ["equip", "fixture"] or p.kind in ["door", "fixture"]):
				_add_poly(sp, scol, si, Transform2D(0.0, sh_off) * poly, tri, Color(0, 0, 0, 0.6 if heavy else 0.4), false, cc, rr)
			if tier == 1 and not skip.has("extra"):
				# the plate's side, seen because the light is up and to the left: the same
				# outline pushed a few pixels away from the light, near black, under everything
				_add_poly(sp, scol, si, Transform2D(0.0, -Look.LIGHT_DIR * EDGE) * poly, tri, Color(0.022, 0.023, 0.026, 1.0), false, cc, rr)
			if st[3] != null and not skip.has("fillx"):
				_add_poly(fp, fc, fi, poly, tri, st[3], true, cc, rr, 0.85, 1.1)
				for q in _inner(p):
					_add_lit(fp, fc, fi, xf * (q[0] as PackedVector2Array), q[1], mt, cc, rr)
			elif m == "legacy":
				_add_poly(fp, fc, fi, poly, tri, st[0], true, cc, rr, 0.75, 2.25)   # as the old picture lights it
			elif p.art != "" and p.cls == "equip":
				# under a machine's drawing only a dim ground: its material tone comes in the
				# shading laid over the art (a big tank's pale fill would light a whole stretch)
				_add_lit(fp, fc, fi, poly, tri, _dim(mt, (0.85 if m in ["engine", "reactor", "tank"] else 0.6) * _big_k(bb)), cc, rr, 0.8)
			else:
				_add_lit(fp, fc, fi, poly, tri, mt, cc, rr, 0.8)
		var bucket := 3 if tier == 3 else (0 if tier == 1 and p.cls != "equip" else (1 if heavy else 2))
		var l0: Color = st[1]
		var n := poly.size()
		if part in ["all", "line", "line_far", "art"]:
			for i in n:
				var a := poly[i]
				var b := poly[(i + 1) % n]
				var e := (((a + b) * 0.5 - cc).dot(Look.LIGHT_DIR) / rr)
				# the edge toward the light catches it, the far one is in shade
				var lg := lerpf(0.45, 1.1, clampf(e * 0.5 + 0.5, 0.0, 1.0)) if (tier == 1 or heavy) else lerpf(0.7, 1.05, clampf(e * 0.5 + 0.5, 0.0, 1.0))
				var lc := Color(minf(l0.r * lg, 1.0), minf(l0.g * lg, 1.0), minf(l0.b * lg, 1.0), l0.a)
				if p.art != "" and p.cls == "equip":
					eq_s.append(a)
					eq_s.append(b)
					eq_c.append(lc)
				else:
					segs[bucket].append(a)
					segs[bucket].append(b)
					cols[bucket].append(lc)
			# a plate's lit inner edge: thickness, not a second outline
			if tier == 1 or m in ["engine", "reactor"]:
				for q in _inner(p):
					var ring: PackedVector2Array = xf * (q[0] as PackedVector2Array)
					for i in ring.size():
						var a2 := ring[i]
						var b2 := ring[(i + 1) % ring.size()]
						var e2 := (((a2 + b2) * 0.5 - cc).dot(Look.LIGHT_DIR) / rr)
						if e2 > 0.15:
							segs[3].append(a2)
							segs[3].append(b2)
							cols[3].append(Pal.ink(0.16))
		if p.art != "" or p.has_meta("cuts") or (p.mat != "" and str(Mat.of(p).get("pattern", "")) != "") or p.kind in ["hull", "hatch", "keel", "beam"]:
			arts.append([p, poly, off, m])
	if part in ["all", "shade"]:
		if not si.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), si, sp, scol)
	if part in ["all", "fill"]:
		if not fi.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), fi, fp, fc)
	if part in ["all", "line"]:
		for k in [3, 2, 1, 0]:
			if not segs[k].is_empty():
				ci.draw_multiline_colors(segs[k], cols[k], widths[k])
	elif part == "line_far":
		var all_s := PackedVector2Array()
		var all_c := PackedColorArray()
		# far out: no tier-3 hairlines, inner rims or machine outlines (all under a pixel, 60 FPS)
		for k in [2, 1, 0]:
			all_s.append_array(segs[k])
			all_c.append_array(cols[k])
		if skip.has("farfull"):
			all_s.append_array(segs[3])
			all_c.append_array(cols[3])
			all_s.append_array(eq_s)
			all_c.append_array(eq_c)
		if not all_s.is_empty():
			ci.draw_multiline_colors(all_s, all_c, -1.0)
	if not part in ["all", "art"] or arts.is_empty():
		return
	Art.EQ.batch_begin()
	for a in arts:
		var p = a[0]
		if p.art != "":
			Art.EQ.bxf = Transform2D(0.0, a[2]) * p.art_xf
			Art.draw(ci, p.art, p.art_size, p, w.font)
			if p.cls in ["equip", "fixture"] or p.kind == "fixture":
				if not skip.has("vol"):
					_volume(w, p, a[1], a[3])
		if not skip.has("vol") and a[3] in ["engine", "reactor", "tank"] or p.kind in ["keel", "beam", "hull", "hatch"]:
			var dd: Array = Depth3.detail(w, p, a[1], a[3])
			if not (dd[0] as PackedVector2Array).is_empty():
				Art.EQ.batch_tris(dd[0], dd[1])
		if p.kind in ["hull", "hatch"]:
			hull_dress(w, ci, p, a[1])
		if p.mat != "":
			w._mat_face(ci, p, a[2])
		if p.has_meta("cuts"):
			w._cut_edges(ci, p, a[2])
	Art.EQ.bxf = Transform2D.IDENTITY
	Art.EQ.batch_end(ci)
	if not eq_s.is_empty():
		ci.draw_multiline_colors(eq_s, eq_c, 1.5)


# The material over a machine's own drawing: its greys laid over the art at about half, so the
# art's many fine lines sink into a tone and the material reads first. Each material its own
# profile: tanks and pipes a cylinder (a highlight a third of the way in from the lit side, dark
# at both edges), cargo corrugated, engines a heat-stained block, reactors a shielded drum.
# Built once per outline and replayed.
const PROFILE_BANDS := 5
const VOL_A := {"tank": 0.75, "pipe": 0.66, "engine": 0.38, "reactor": 0.5, "cargo": 0.55, "armor": 0.55, "machine": 0.52, "fixture": 0.7}


static func _vol_data(w, p, poly: PackedVector2Array, m: String) -> Array:
	var first := poly[0] if poly.size() > 0 else Vector2.ZERO
	var sig: int = hash([p.tri_sig, m, first, p.intact])
	var cache = p.get_meta("solid_vol") if p.has_meta("solid_vol") else null
	if cache == null or cache[0] != sig:
		cache = [sig, _volume_build(w, p, poly, m)]
		p.set_meta("solid_vol", cache)
	return cache[1]


static func _volume(w, p, poly: PackedVector2Array, m: String) -> void:
	var d: Array = _vol_data(w, p, poly, m)
	if not (d[0] as PackedVector2Array).is_empty():
		Art.EQ.batch_tris(d[0], d[1])


# ---------------------------------------------------------------- far out (v3, "全景可读")
# Zoomed out the machines' drawings fade away and outlines turn to hairlines, so the v2
# shading went with them. The "block" pass fades in instead (world.gd, 1 - the art's fade):
# the big machines as solid blocks of their material's greys, and the hull's plates with a
# thick lit edge on the side toward the light and a dark side face on the far side, wide
# enough in world pixels to read at a quarter zoom.
const FAR_BLOCK := ["engine", "reactor", "tank", "cargo"]
const FAR_LIT := 4.0     # px (world): the lit edge's width
const FAR_SIDE := 9.0    # px (world): the shaded side face's width


static func _draw_block(w, ci: CanvasItem, list: Array) -> void:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var lit_s := PackedVector2Array()
	var lit_c := PackedColorArray()
	var sh_s := PackedVector2Array()
	var sh_c := PackedColorArray()
	for p in list:
		if p.gone:
			continue
		var off: Vector2 = w.door_offset(p)
		var poly: PackedVector2Array = p.poly
		if off != Vector2.ZERO:
			poly = Transform2D(0.0, off) * poly
		var m := material(p)
		if p.cls == "equip" and p.art != "" and m in FAR_BLOCK:
			# 60 FPS (ARK-01 whole-ship view): one lit block of the material's tone per machine —
			# at this size the banded profiles and the layer detail are under a pixel anyway
			var tri: PackedInt32Array = w._tri_cached(p)
			if tri.is_empty():
				continue
			var mt: Array = MATS[m]
			var bb := Geom.bbox(poly)
			var cc := bb.get_center()
			var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
			var gk: float = {"engine": 1.25, "reactor": 1.2, "tank": 1.0, "cargo": 0.82}[m] * lerpf(1.0, 0.5, (1.0 - _big_k(bb)) / 0.45)
			for k in tri:
				var v := poly[k]
				var c := _tone(mt, clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0) * 0.8)
				tp.append(v)
				tc.append(Color(minf(c.r * gk, 1.0), minf(c.g * gk, 1.0), minf(c.b * gk, 1.0), 1.0))
		elif _tier(p) == 1 and p.cls != "equip":
			var n := poly.size()
			if n < 3:
				continue
			var a2 := 0.0
			for i in n:
				var a := poly[i]
				var b := poly[(i + 1) % n]
				a2 += a.x * b.y - b.x * a.y
			var sgn := 1.0 if a2 > 0.0 else -1.0
			for i in n:
				var a := poly[i]
				var b := poly[(i + 1) % n]
				var ln := a.distance_to(b)
				# 60 FPS: only the long edges read this far out (a plate's short ends are under a pixel)
				if ln < 1.5 * Geom.M:
					continue
				var nrm := (b - a).orthogonal() / ln * sgn    # outward
				var f := nrm.dot(Look.LIGHT_DIR)
				if f > 0.25:
					# the lit edge, inside the plate
					lit_s.append(a - nrm * FAR_LIT * 0.5)
					lit_s.append(b - nrm * FAR_LIT * 0.5)
					lit_c.append(Pal.ink(0.2 + 0.24 * f))
				elif f < -0.25:
					# the plate's side in shade, just outside it
					sh_s.append(a + nrm * FAR_SIDE * 0.5)
					sh_s.append(b + nrm * FAR_SIDE * 0.5)
					sh_c.append(Color(0.008, 0.008, 0.01, 0.6 + 0.35 * -f))
	if not sh_s.is_empty():
		ci.draw_multiline_colors(sh_s, sh_c, FAR_SIDE)
	if not tp.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), tp, tc)
	if not lit_s.is_empty():
		ci.draw_multiline_colors(lit_s, lit_c, FAR_LIT)


static func _prof(m: String, mt: Array, v: Vector2, bb: Rect2, long_x: bool, a: float) -> Color:
	var cc := bb.get_center()
	var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
	var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
	var span := bb.size.y if long_x else bb.size.x
	var along := bb.size.x if long_x else bb.size.y
	var u := clampf(((v.y - bb.position.y) if long_x else (v.x - bb.position.x)) / maxf(span, 1.0), 0.0, 1.0)
	var t := ((v.x - bb.position.x) if long_x else (v.y - bb.position.y))
	var c: Color
	match m:
		"tank", "pipe":
			# the light is up-left: the highlight a third of the way across, dark at both edges
			var x := (u - 0.3) / (0.7 if u > 0.3 else 0.3)
			var h := 1.0 - clampf(absf(x), 0.0, 1.0)
			c = _tone(mt, h * 1.6 - 0.75)
		"cargo":
			# the light sloping across (its ribs are drawn as lines over it)
			c = _tone(mt, lk * 0.8)
		"reactor":
			# a shielded drum: dark rim, lit band, darker core
			var q := absf(u - 0.5) * 2.0
			c = _tone(mt, (0.6 - absf(q - 0.55) * 2.2) + lk * 0.3)
		"engine":
			c = _tone(mt, lk * 0.9)
			# heat stain on the side away from the light
			var hs := clampf(-lk, 0.0, 1.0) * 0.03
			c = Color(c.r + hs, c.g + hs * 0.35, c.b, 1.0)
		_:
			c = _tone(mt, lk * 0.85)
	return Color(c.r, c.g, c.b, a)


static func _volume_build(w, p, poly: PackedVector2Array, m: String) -> Array:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var tri: PackedInt32Array = w._tri_cached(p)
	if tri.is_empty():
		return [pts, cols]
	var mt: Array = MATS[m]
	var bb := Geom.bbox(poly)
	var a: float = 0.6 if not p.intact else float(VOL_A.get(m, 0.5))
	# a very big part (NR-95's 30 m hydrogen tank) would turn a whole stretch of the ship pale:
	# the bigger it is, the more of the drawing under it shows through
	a *= _big_k(bb)
	var long_x := bb.size.x >= bb.size.y
	var span := bb.size.y if long_x else bb.size.x
	var along := bb.size.x if long_x else bb.size.y
	if m == "cargo":
		# 60 FPS (ARK-01 has ~140 of these): the light's slope on the whole face, then one dark
		# rib line every 12 px for the corrugation — not a band of triangles per rib
		for k in tri:
			pts.append(poly[k])
			cols.append(_prof(m, mt, poly[k], bb, long_x, a))
		var ribs := PackedVector2Array()
		var t := 8.0
		while t < along - 4.0:
			var ra: Vector2
			var rb: Vector2
			if long_x:
				ra = Vector2(bb.position.x + t, bb.position.y + 2.0)
				rb = Vector2(bb.position.x + t, bb.end.y - 2.0)
			else:
				ra = Vector2(bb.position.x + 2.0, bb.position.y + t)
				rb = Vector2(bb.end.x - 2.0, bb.position.y + t)
			for q in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([ra, rb]), poly):
				for i in q.size() - 1:
					ribs.append(q[i])
					ribs.append(q[i + 1])
			t += 12.0
		if not ribs.is_empty():
			var rt: Array = Art.EQ.seg_tris(ribs, PackedColorArray([Color(0, 0, 0, 0.32 * a / 0.55)]), 3.0)
			pts.append_array(rt[0])
			cols.append_array(rt[1])
	elif m in ["tank", "pipe", "reactor"] and span >= 20.0:
		# bands across so the cylinder's profile is smooth, clipped to the outline
		var n := PROFILE_BANDS
		for b in n:
			var r: Rect2
			var len_ := span
			var f0 := float(b) / n * len_
			var f1 := float(b + 1) / n * len_
			var across_bands := true
			if long_x != across_bands:
				r = Rect2(bb.position.x + f0, bb.position.y, f1 - f0, bb.size.y)
			else:
				r = Rect2(bb.position.x, bb.position.y + f0, bb.size.x, f1 - f0)
			var rp := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			for q in Geometry2D.intersect_polygons(poly, rp):
				var qt := Geometry2D.triangulate_polygon(q)
				for k in qt:
					pts.append(q[k])
					cols.append(_prof(m, mt, q[k], bb, long_x, a))
	else:
		for k in tri:
			pts.append(poly[k])
			cols.append(_prof(m, mt, poly[k], bb, long_x, a))
	return [pts, cols]


# armour plates: the hull's panels between the weld seams alternate a little in tone, seams
# and rivets are tier 3; the ship's name painted on its biggest plate stays
static func hull_dress(w, ci: CanvasItem, p, poly: PackedVector2Array) -> void:
	var bb := Geom.bbox(poly)
	if bb.size.x < 1.2 * Geom.M and bb.size.y < 1.2 * Geom.M:
		return
	var sig: int = hash([poly, "armour"])
	var cache = p.get_meta("solid_dress") if p.has_meta("solid_dress") else null
	if cache == null or cache[0] != sig:
		cache = [sig, _dress_build(poly, bb)]
		p.set_meta("solid_dress", cache)
	var d: Array = cache[1]
	if not (d[0] as PackedVector2Array).is_empty():
		Art.EQ.batch_tris(d[0], d[1])
	# the ship's name on its biggest hull plate (as the old dressing paints it)
	if w._reg_id == -2:
		w._reg_id = -1
		var best := 0.0
		for id in w.order:
			var q = w.pieces[id]
			if q.kind == "hull" and not q.gone and q.body == null:
				var ar := Geom.area(q.poly)
				if ar > best:
					best = ar
					w._reg_id = q.id
	if p.id == w._reg_id and w.game != null:
		var nm := str(w.game.ship.get("name", ""))
		if nm != "":
			var sz := int(clampf(minf(bb.size.y * 0.42, bb.size.x / maxf(nm.length(), 1) * 1.3), 12.0, 72.0))
			var tw: float = w.font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			ci.draw_string(w.font, Vector2(bb.get_center().x - tw * 0.5, bb.get_center().y + sz * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.ink(0.2))


static func _dress_build(poly: PackedVector2Array, bb: Rect2) -> Array:
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var along_x := bb.size.x >= bb.size.y
	var step := 1.8 * Geom.M
	var n := int((bb.size.x if along_x else bb.size.y) / step)
	var inner := Geometry2D.offset_polygon(poly, -RIM)
	var seams := PackedVector2Array()
	var rivets := PackedVector2Array()
	var len_ := bb.size.x if along_x else bb.size.y
	for i in n + 1:
		var f0 := float(i) / (n + 1)
		var f1 := float(i + 1) / (n + 1)
		var r: Rect2
		if along_x:
			r = Rect2(bb.position.x + f0 * len_ + 1.5, bb.position.y - 2, (f1 - f0) * len_ - 3.0, bb.size.y + 4)
		else:
			r = Rect2(bb.position.x - 2, bb.position.y + f0 * len_ + 1.5, bb.size.x + 4, (f1 - f0) * len_ - 3.0)
		var rp := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		# alternate panels: one a touch paler (a different plate, laid later)
		var tone := 0.03 if i % 2 == 0 else 0.0
		var h := fposmod(sin(float(i) * 12.9898 + bb.position.x * 0.013) * 43758.5453, 1.0)
		tone += h * 0.012
		if tone > 0.002:
			for ring in inner:
				for q in Geometry2D.intersect_polygons(ring, rp):
					var tri := Geometry2D.triangulate_polygon(q)
					for k in tri:
						tp.append(q[k])
						tc.append(Color(1, 1, 1, tone))
		if i > 0:
			var a: Vector2
			var b: Vector2
			if along_x:
				var x := bb.position.x + f0 * len_
				a = Vector2(x, bb.position.y - 1.0)
				b = Vector2(x, bb.end.y + 1.0)
			else:
				var y := bb.position.y + f0 * len_
				a = Vector2(bb.position.x - 1.0, y)
				b = Vector2(bb.end.x + 1.0, y)
			for seg in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), poly):
				if seg.size() < 2:
					continue
				var s0: Vector2 = seg[0]
				var s1: Vector2 = seg[seg.size() - 1]
				seams.append(s0)
				seams.append(s1)
				# rivets in from each end, inside the rim
				var dir := (s1 - s0).normalized()
				for c in [s0 + dir * (RIM + 2.0), s1 - dir * (RIM + 2.0)]:
					rivets.append(c - Vector2(0.9, 0))
					rivets.append(c + Vector2(0.9, 0))
	var t1: Array = Art.EQ.seg_tris(seams, PackedColorArray([Color(0, 0, 0, 0.55)]), 2.0)
	var t2: Array = Art.EQ.seg_tris(seams, PackedColorArray([Pal.ink(Pal.T3 * 0.7)]), 1.0)
	var t3: Array = Art.EQ.seg_tris(rivets, PackedColorArray([Pal.ink(Pal.T3 + 0.08)]), 1.8)
	for t in [t1, t2, t3]:
		tp.append_array(t[0])
		tc.append_array(t[1])
	return [tp, tc]


# the compartments: a lit back wall, darker into the corners (the light falls off away from
# the lamp side), and a band of shadow along the walls where the hull's thickness hides it
# how much of a room's back wall shows, from the fraction of its shell still there (and whether
# its panel grid is drawn): the rule tests/strip_back_check.gd holds the picture to
# User 2026-11-10 (PS-12, its lower half taken off): "这个背景看起来很突兀，出戏". A room's wall
# goes with the plating round it: whole down to 95 % of its shell, gone below 35 % (only the real
# structure still there is drawn — keel, the neighbouring bulkheads' stubs, the cut edges); its
# panel grid only while the room is still near whole.
static func back_k(f: float) -> float:
	if skip.has("backfix"):    # tests: the rule before this fix, for the before / after pictures
		return pow(clampf(f, 0.0, 1.0), 0.6)
	var t := clampf((f - 0.35) / 0.6, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func back_grid(f: float) -> bool:
	if calm >= 1 and not skip.has("backfix"):
		return false
	return f > 0.85 or skip.has("backfix")


static func back_rooms(w) -> void:
	if skip.has("back"):
		return
	var shells: Dictionary = w._room_shells()
	var bl: Node2D = w.back_layer
	for n in w.rooms:
		if not w.hide_rooms.has(n):
			back_room(w, bl, n, shells)


# one compartment's back wall (also drawn turned with a wheel: scripts/rings_fx.gd)
static func back_room(w, bl: CanvasItem, n: String, shells: Dictionary) -> void:
	var r = w.rooms[n]
	var poly: PackedVector2Array = r.poly
	var k := 1.0
	var f := 1.0
	if r.has("shell0") and r.shell0 > 0.0:
		f = clampf(shells[n] / r.shell0, 0.0, 1.0)
		k = back_k(f)
	if k < 0.02:
		return
	if not r.revealed:
		bl.draw_colored_polygon(poly, Color(0.03, 0.031, 0.035, k))
		return
	var bb: Rect2 = r.bbox
	var cc := bb.get_center()
	var rr := maxf(bb.size.x, bb.size.y) * 0.5
	var cs := PackedColorArray()
	for v in poly:
		var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
		var g := lerpf(0.7, 1.25, lk * 0.5 + 0.5) if calm < 1 else lerpf(0.9, 1.08, lk * 0.5 + 0.5)
		var wl: Color = Color(0.075, 0.078, 0.088) if skip.has("backfix") else Pal.ROOM_LIT
		cs.append(Color(wl.r * g, wl.g * g, wl.b * g, k))
	bl.draw_polygon(poly, cs)
	var ring := PackedVector2Array(poly)
	ring.append(poly[0])
	bl.draw_polyline(ring, Color(0, 0, 0, 0.16 * k), 34.0)
	bl.draw_polyline(ring, Color(0, 0, 0, 0.28 * k), 14.0)
	var rs: Array = Depth3.room(w, r, false) if not skip.has("rooms") and calm < 1 else [PackedVector2Array(), PackedColorArray()]
	if not (rs[0] as PackedVector2Array).is_empty():
		var rc: PackedColorArray = rs[1]
		if k < 0.99 and not skip.has("backfix"):
			# the hold's frames fade with its wall
			rc = PackedColorArray()
			for c in (rs[1] as PackedColorArray):
				rc.append(Color(c.r, c.g, c.b, c.a * k))
		RenderingServer.canvas_item_add_triangle_array(bl.get_canvas_item(), PackedInt32Array(), rs[0], rc)
	if not back_grid(f):
		return
	if not r.has("grid"):
		r.grid = w._room_grid(r)
	if r.grid[0].size() >= 2:
		bl.draw_multiline(r.grid[0], Pal.ink(0.02 * k), 1.0)
	if r.grid[1].size() >= 2:
		bl.draw_multiline(r.grid[1], Pal.ink(0.012 * k), 1.0)


# a closed compartment seen from outside: the side plating, lit like the hull, with a few
# sparse diagonal strokes (not a hatch of hundreds) to say "closed"
static func cover(w) -> void:
	if skip.has("cover"):
		return
	var cl: Node2D = w.cover_layer
	var hatch := PackedVector2Array()
	for n in w.rooms:
		var r = w.rooms[n]
		if r.revealed:
			continue
		var poly: PackedVector2Array = r.poly
		var bb: Rect2 = r.bbox
		var cc := bb.get_center()
		var rr := maxf(bb.size.x, bb.size.y) * 0.5
		var cs := PackedColorArray()
		for v in poly:
			var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
			var g := lerpf(0.35, 1.7, lk * 0.5 + 0.5)
			cs.append(Color(0.007 * g, 0.0075 * g, 0.0085 * g, 1.0))
		cl.draw_polygon(poly, cs)
		# v3 全景可读: the plating's edges — a pale band inside the edges toward the light, a deep
		# shadow inside the far ones (the hull's thickness hides the light there)
		var rs: Array = Depth3.room(w, r, true) if not skip.has("rooms") and calm < 1 else [PackedVector2Array(), PackedColorArray()]
		if not (rs[0] as PackedVector2Array).is_empty():
			RenderingServer.canvas_item_add_triangle_array(cl.get_canvas_item(), PackedInt32Array(), rs[0], rs[1])
		var s := maxf(Geom.M * 2.4, (bb.size.x + bb.size.y) / 14.0)
		var x := bb.position.x - bb.size.y
		while x < bb.end.x:
			var seg := PackedVector2Array([Vector2(x, bb.end.y), Vector2(x + bb.size.y, bb.position.y)])
			for q in Geometry2D.intersect_polyline_with_polygon(seg, poly):
				for k in q.size() - 1:
					hatch.append(q[k])
					hatch.append(q[k + 1])
			x += s
	if not hatch.is_empty():
		cl.draw_multiline(hatch, Pal.ink(0.035), 1.0)
	# the plating's light and shade bands on a child node world.gd hides far out (60 FPS)
	var bn: Node2D = w.get_meta("cover_bands") if w.has_meta("cover_bands") else null
	if bn == null:
		bn = Node2D.new()
		bn.draw.connect(func() -> void: cover_bands(w, bn))
		cl.add_child(bn)
		w.set_meta("cover_bands", bn)
	bn.queue_redraw()
	return


# light and shade bands inside a polygon's edges, by which way each edge faces (world px wide,
# so they still read zoomed out)
static func _edge_bands(ci: CanvasItem, poly: PackedVector2Array, k: float) -> void:
	var n := poly.size()
	if n < 3:
		return
	var a2 := 0.0
	for i in n:
		a2 += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	var sgn := 1.0 if a2 > 0.0 else -1.0
	var lit := PackedVector2Array()
	var lc := PackedColorArray()
	var sh := PackedVector2Array()
	var shc := PackedColorArray()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var ln := a.distance_to(b)
		if ln < 4.0:
			continue
		var nrm := (b - a).orthogonal() / ln * sgn
		var f := nrm.dot(Look.LIGHT_DIR)
		var t := (b - a) / ln
		if f > 0.2:
			lit.append(a - nrm * 7.0 + t * 7.0)
			lit.append(b - nrm * 7.0 - t * 7.0)
			lc.append(Pal.ink(0.04 * k * f))
		elif f < -0.2:
			sh.append(a - nrm * 16.0)
			sh.append(b - nrm * 16.0)
			shc.append(Color(0, 0, 0, 0.6 * k * -f))
	if not sh.is_empty():
		ci.draw_multiline_colors(sh, shc, 32.0)
	if not lit.is_empty():
		ci.draw_multiline_colors(lit, lc, 14.0)


static func cover_bands(w, bn: Node2D) -> void:
	if not Pal.solid:
		return
	for n in w.rooms:
		var r = w.rooms[n]
		if not r.revealed:
			_edge_bands(bn, r.poly, 0.75 if calm < 3 else 0.4)


# a pipe run: a round bar, not two lines — dark edges, a mid body, a thin highlight on the
# side toward the light
static func pipe(ci: CanvasItem, path: PackedVector2Array, a: float) -> void:
	var mt: Array = MATS["pipe"]
	ci.draw_polyline(path, Color(0.02, 0.021, 0.024, a), 5.6, true)
	var body: Color = mt[0]
	ci.draw_polyline(path, Color(body.r, body.g, body.b, a), 3.8, true)
	var lit: Color = mt[1]
	ci.draw_polyline(Transform2D(0.0, Look.LIGHT_DIR * 0.9) * path, Color(lit.r, lit.g, lit.b, 0.8 * a), 1.0, true)


# ---------------------------------------------------------------- the berth crane

# the rail as a rolled I-beam: top flange lit, web in shade, bottom flange, stiffeners and
# rivets as tier 3, a shadow under it
static func crane_rail(ci: CanvasItem, x0: float, x1: float, ry: float) -> void:
	if skip.has("crane"):
		return
	var w := x1 - x0
	# a heavy rolled I-beam, 24 px deep: lit top flange, web in shade, bottom flange, its
	# shadow on what is behind; stiffener plates every 1.25 m, rivet pairs on the flange
	ci.draw_rect(Rect2(x0 + 4.0, ry + 20.0, w, 9.0), Color(0, 0, 0, 0.4))
	var top := Rect2(x0, ry - 4.0, w, 6.0)
	var web := Rect2(x0 + 0.0, ry + 2.0, w, 12.0)
	var bot := Rect2(x0, ry + 14.0, w, 5.0)
	var hi := Color(0.46, 0.47, 0.5)
	var mid := Color(0.24, 0.247, 0.265)
	ci.draw_polygon(PackedVector2Array([top.position, Vector2(top.end.x, top.position.y), top.end, Vector2(top.position.x, top.end.y)]), PackedColorArray([hi, hi, mid, mid]))
	var wt := Color(0.1, 0.104, 0.115)
	var wb := Color(0.15, 0.155, 0.17)
	ci.draw_polygon(PackedVector2Array([web.position, Vector2(web.end.x, web.position.y), web.end, Vector2(web.position.x, web.end.y)]), PackedColorArray([wt, wt, wb, wb]))
	ci.draw_rect(bot, Color(0.27, 0.278, 0.298))
	ci.draw_line(Vector2(x0, ry - 4.0), Vector2(x1, ry - 4.0), Pal.ink(Pal.T1), W1)
	ci.draw_line(Vector2(x0, ry + 2.0), Vector2(x1, ry + 2.0), Color(0, 0, 0, 0.6), 1.5)
	ci.draw_line(Vector2(x0, ry + 14.0), Vector2(x1, ry + 14.0), Pal.ink(Pal.T2 * 0.8), W3)
	ci.draw_line(Vector2(x0, ry + 19.0), Vector2(x1, ry + 19.0), Pal.ink(Pal.T2 * 0.6), W3)
	var st := PackedVector2Array()
	var sh := PackedVector2Array()
	var rv := PackedVector2Array()
	var x := x0 + 30.0
	while x < x1:
		st.append(Vector2(x, ry + 2.0))
		st.append(Vector2(x, ry + 14.0))
		sh.append(Vector2(x + 2.0, ry + 2.0))
		sh.append(Vector2(x + 2.0, ry + 14.0))
		for dx in [-9.0, -5.0, 5.0, 9.0]:
			rv.append(Vector2(x + dx - 0.9, ry - 1.0))
			rv.append(Vector2(x + dx + 0.9, ry - 1.0))
		x += 60.0
	ci.draw_multiline(sh, Color(0, 0, 0, 0.5), 2.0)
	ci.draw_multiline(st, Pal.ink(Pal.T3 + 0.12), 1.4)
	ci.draw_multiline(rv, Pal.ink(Pal.T3 + 0.1), 1.8)


# the trolley as a block of machinery: a shaded body with a lit top, the motor housing, the
# drum, a shadow on the rail web; the beacon's light falls on the body while it works
static func trolley(ci: CanvasItem, c: Vector2, w: float, busy: bool, t: float, wheel: float) -> void:
	var h := 18.0
	var body := Rect2(c.x - w * 0.5, c.y + 20.0, w, h)
	ci.draw_rect(Rect2(body.position + Vector2(3, 5), body.size), Color(0, 0, 0, 0.45))
	# body: dark below, lit band on top
	var p := PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)])
	var top := Color(0.34, 0.35, 0.375)
	var bot := Color(0.11, 0.114, 0.126)
	ci.draw_polygon(p, PackedColorArray([top, top, bot, bot]))
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, 2.5)), Color(0.55, 0.56, 0.59))
	# the hangers from the wheel axles down past the beam to the body
	for s2 in [-1.0, 1.0]:
		var hx: float = c.x + s2 * (w * 0.5 - 8.0)
		ci.draw_rect(Rect2(hx - 2.5, c.y - 3.0, 5.0, 23.0), Color(0.2, 0.207, 0.224))
		ci.draw_rect(Rect2(hx - 2.5, c.y - 3.0, 5.0, 23.0), Pal.ink(Pal.T2), false, W3)
	ci.draw_rect(body, Pal.ink(Pal.T2 * 1.25), false, W2 * 1.3)
	# the motor housing (a heavier block on one end) with cooling fins
	var mr := Rect2(c.x + w * 0.5 - 20.0, body.position.y + 3.0, 15.0, 11.0)
	ci.draw_rect(mr, Color(0.22, 0.228, 0.245))
	ci.draw_rect(mr, Pal.ink(Pal.T2), false, W3)
	for k in 4:
		ci.draw_line(Vector2(mr.position.x + 2.5 + k * 3.3, mr.position.y + 2.0), Vector2(mr.position.x + 2.5 + k * 3.3, mr.end.y - 2.0), Pal.ink(Pal.T3), W3)
	# the drum: a cylinder (lit stripe on its upper side), turning
	var drum := Vector2(c.x - 6.0, body.position.y + 9.0)
	FastDraw.circle(ci, drum, 6.0, Color(0.11, 0.115, 0.128))
	FastDraw.arc(ci, drum, 6.0, PI * 1.05, PI * 1.95, 10, Pal.ink(0.6), 1.4, true)
	FastDraw.arc(ci, drum, 6.0, 0.0, TAU, 14, Pal.ink(Pal.T3 + 0.1), W3, true)
	ci.draw_line(drum + Vector2.from_angle(wheel * 2.0) * 5.0, drum - Vector2.from_angle(wheel * 2.0) * 5.0, Pal.ink(0.3), 1.0)
	for s in [-1.0, 1.0]:
		var wc := Vector2(c.x + s * (w * 0.5 - 8.0), c.y - 3.0)
		FastDraw.circle(ci, wc, 5.5, Color(0.26, 0.268, 0.288))
		FastDraw.arc(ci, wc, 5.5, 0.0, TAU, 12, Pal.ink(Pal.T2), W2, true)
		FastDraw.circle(ci, wc, 1.6, Pal.ink(0.5))
		ci.draw_line(wc, wc + Vector2.from_angle(wheel) * 4.5, Pal.ink(0.35), 1.0)
	# beacon: orange, and while it turns its light sweeps the trolley's top
	var bc := Vector2(c.x - w * 0.5 + 9.0, body.position.y - 1.0)
	FastDraw.arc(ci, bc, 3.2, PI, TAU, 8, Pal.ink(0.5), 1.0, true)
	if busy:
		var ph := fposmod(t * 2.2, 1.0)
		var on := 0.35 + 0.65 * pow(maxf(0.0, sin(ph * TAU)), 4.0)
		FastDraw.circle(ci, bc, 2.6, Color(1.0, 0.62, 0.2, on))
		FastDraw.circle(ci, bc, 12.0, Color(1.0, 0.55, 0.15, 0.14 * on))
		ci.draw_rect(Rect2(body.position.x, body.position.y, w * 0.55, 2.5), Color(1.0, 0.55, 0.2, 0.35 * on))
