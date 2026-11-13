extends Node
# What every tank holds, seen through its shell — drawing only, the amounts are systems.gd's
# fluid volumes and nothing here changes them (user 2026-11-10 of HG-170's tanks: "这样就一条一条
# 线，感觉不好啊" — the liquid had been a level line and some hatching).
# Jev (layout A 0.75, shell A 0.65): no gravity in the berth, so the liquid wets the walls and
# lies round them; the pressurant / its own vapour is one rounded bubble inside it, a little off
# centre, trembling. The shell stays as drawn; the liquid shows through it, see-through in its
# own colour (liquid_colors.gd), darker against the wall where it is deep, the meniscus bright
# round the bubble, a glint on it.
#   The bubble's area is exactly the tank's empty share (a table solved per tank), so the liquid
#   seen is what the system holds: drawn off, the bubble grows steadily and the liquid thins on
#   the walls till it is gone; drawn while it runs out, the liquid gathers at the outlet (the
#   vanes hold it there) and streams round the wall toward it.
#   Cryogens: boiling (bubbles rising off the wall into the vapour, more as the tank warms),
#   white vapour in the bubble, frost on the shell. HG-170's tanks (scripts/boiloff.gd) boil
#   harder as their pressure climbs uncooled, and hard while venting.
# 60 FPS: the tanks' shapes, tables and frost are worked out once; each frame is one triangle
# array for all the liquid, the meniscus as thin lines, and the tanks off screen skipped.

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")
const EQ = preload("res://scripts/art_equip.gd")

const N := 48                 # points round a tank

const ARTS := ["fueltank", "water", "sphere_tank", "gastank", "cryotank"]

var game
var world
var node: Node2D
var glow: Node2D
var _tanks: Array = []        # see _tank()
var _found := false
var _t := 0.0
var _dirs := PackedVector2Array()


static func ensure(g, parent: Node):
	var f = load("res://scripts/tank_fill_fx.gd").new()
	f.game = g
	f.world = g.world
	parent.add_child(f)
	f.node = Kit.node(g.world, false, f._draw)
	f.glow = Kit.node(g.world, true, f._draw_glow)
	return f


func _exit_tree() -> void:
	for n in [node, glow]:
		if n != null and is_instance_valid(n):
			n.queue_free()


func _ready() -> void:
	for i in N:
		_dirs.append(Vector2.from_angle(TAU * i / N))


# ---------------------------------------------------------------- finding the tanks

func _art_of(p) -> String:
	var art: String = str(p.art)
	var alt := ""
	if EQ.ext != null and EQ.ext.BY_NAME.has(p.name_key):
		alt = str(EQ.ext.BY_NAME[p.name_key])
	elif EQ.BY_NAME.has(p.name_key):
		alt = str(EQ.BY_NAME[p.name_key])
	# 2026-11-13: the redrawn tanks (art_ships.gd) say which picture's liquid they take, and where its inside is
	if alt != "" and EQ.ext != null and EQ.ext.has_method("liquid_art"):
		var la: String = EQ.ext.liquid_art(alt, art)
		if la != "":
			return la
	if alt != "":
		art = alt
	return art if ARTS.has(art) else ""


# a vessel's inside as convex outlines in the art's own pixels (as art_equip.gd draws it)
func _shapes(art: String, w: float, h: float) -> Array:
	var out: Array = []
	match art:
		"fueltank":
			if h > w * 1.2:
				out.append(_capsule(Rect2(w * 0.08, h * 0.04, w * 0.84, h * 0.88), false))
			else:
				out.append(_capsule(Rect2(w * 0.02, h * 0.1, w * 0.96, h * 0.74), true))
		"water":
			out.append(_rect(Rect2(w * 0.06, h * 0.12, w * 0.84, h * 0.8), 0.06))
		_:
			if EQ.ext != null and EQ.ext.has_method("liquid_rect"):
				var lr: Array = EQ.ext.liquid_rect(art, w, h)
				if not lr.is_empty():
					out.append(_rect(lr[0], float(lr[1])))
		"sphere_tank":
			var rad: float = minf(w, h) * 0.44
			var pts := PackedVector2Array()
			for i in N:
				pts.append(Vector2(w * 0.5, h * 0.5) + Vector2.from_angle(TAU * i / N) * rad)
			out.append(pts)
		"cryotank":
			var rr: float = minf(h * 0.3, w * 0.12)
			out.append(_rect(Rect2(rr, h * 0.06, w - 2.0 * rr, h * 0.88), 0.3))
		"gastank":
			if w > h * 1.2 and h < 0.9 * Geom.M:
				var nl := clampi(roundi(h / maxf(w * 0.18, 10.0)), 1, 8)
				var lh: float = h / nl
				for i in nl:
					var r := Rect2(2.0, i * lh + 1.0, w - 4.0, lh - 2.0)
					var hd: float = minf(r.size.y * 0.9, r.size.x * 0.18)
					out.append(_rect(Rect2(r.position.x + 1.0, r.position.y + r.size.y * 0.06, r.size.x - hd - 1.0, r.size.y * 0.88), 0.45))
			else:
				var n := clampi(roundi(w / maxf(h * 0.3, 10.0)), 1, 16)
				var bw: float = w / n
				for i in n:
					var r := Rect2(i * bw + bw * 0.08, 1.0, bw * 0.84, h - 2.0)
					var hd: float = minf(r.size.x * 0.9, r.size.y * 0.18)
					out.append(_rect(Rect2(r.position.x + r.size.x * 0.06, r.position.y + hd, r.size.x * 0.88, r.size.y - hd - 1.0), 0.45))
	return out


# a shell with dished heads (vessel_h / vessel_v)
func _capsule(r: Rect2, lying: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if lying:
		var dh: float = minf(r.size.y * 0.25, r.size.x * 0.2)
		var cy: float = r.get_center().y
		var ry: float = r.size.y * 0.5
		for k in 13:
			var a: float = -PI * 0.5 + PI * k / 12.0
			pts.append(Vector2(r.end.x - dh + cos(a) * dh, cy + sin(a) * ry))
		for k in 13:
			var a: float = PI * 0.5 + PI * k / 12.0
			pts.append(Vector2(r.position.x + dh + cos(a) * dh, cy + sin(a) * ry))
	else:
		var dh: float = minf(r.size.x * 0.25, r.size.y * 0.2)
		var cx: float = r.get_center().x
		var rx: float = r.size.x * 0.5
		for k in 13:
			var a: float = PI + PI * k / 12.0
			pts.append(Vector2(cx + cos(a) * rx, r.position.y + dh + sin(a) * dh))
		for k in 13:
			var a: float = PI * k / 12.0
			pts.append(Vector2(cx + cos(a) * rx, r.end.y - dh + sin(a) * dh))
	return pts


# a box with its corners rounded (k: the corner radius as a share of the short side)
func _rect(r: Rect2, k: float) -> PackedVector2Array:
	var cr: float = minf(r.size.x, r.size.y) * k
	var pts := PackedVector2Array()
	var cs := [Vector2(r.end.x - cr, r.position.y + cr), Vector2(r.end.x - cr, r.end.y - cr), Vector2(r.position.x + cr, r.end.y - cr), Vector2(r.position.x + cr, r.position.y + cr)]
	for q in 4:
		var cc: Vector2 = cs[q]
		for j in 5:
			var a: float = -PI * 0.5 + q * PI * 0.5 + PI * 0.5 * j / 4.0
			pts.append(cc + Vector2.from_angle(a) * cr)
	return pts


# a tank's record: its outline as radii round its centre, its bubble table, its frost
func _tank(vk: String, p, poly: PackedVector2Array, xf_art: Transform2D, look: String, share: float, outer: PackedVector2Array, boil_t: String) -> Dictionary:
	var shrunk: Array = Geometry2D.offset_polygon(poly, -1.5)
	if not shrunk.is_empty():
		poly = shrunk[0]
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= poly.size()
	var R := PackedFloat32Array()
	for i in N:
		R.append(_ray(poly, c, _dirs[i]))
	# the bubble's shape: the outline smoothed round (a bubble has no corners)
	var rho := PackedFloat32Array()
	var win := N / 8
	for i in N:
		var s := 0.0
		for j in range(-win, win + 1):
			s += R[(i + j + N) % N]
		rho.append(minf(s / (2 * win + 1), R[i]))
	var area_v := 0.0
	var rin := 1e9
	for i in N:
		area_v += R[i] * R[i]
		rin = minf(rin, rho[i])
	var tab := []                  # the bubble's radii at each film thickness (_levels, built later)
	# frost: short ticks and specks round the outside of the shell (cryogens only)
	var frost := PackedVector2Array()
	if LC.misty(look):
		var Ro := PackedFloat32Array()
		for i in N:
			Ro.append(_ray(outer, c, _dirs[i]) if outer.size() > 2 else R[i] + 3.0)
		for i in N * 3:
			var f: float = float(i) / 3.0
			var i0 := int(f) % N
			var d := _dirs[i0].lerp(_dirs[(i0 + 1) % N], f - int(f)).normalized()
			var ro: float = lerpf(Ro[i0], Ro[(i0 + 1) % N], f - int(f))
			var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
			var base: Vector2 = c + d * (ro + 0.5)
			var tip: Vector2 = base + d.rotated((h1 - 0.5) * 1.6) * (3.0 + 8.0 * h2)
			frost.append(base)
			frost.append(tip)
	var e := {"vol": vk, "p": p, "xf": xf_art, "c": c, "R": R, "rho": rho, "lv": tab, "la": PackedFloat32Array(), "area": area_v, "rin": rin, "look": look,
		"share": share, "frost": frost, "boil": boil_t, "flow": 0.0, "was": -1.0,
		"seed": float(hash(vk) % 997) * 0.37, "bb": Geom.bbox(poly)}
	var v: Dictionary = game.sys.fvol.get(vk, {}) if game != null and game.get("sys") != null else {}
	e["full"] = float(v.get("full", 0.0))
	if e.full <= 0.0:
		e.full = maxf(0.001, float(v.get("amount", 0.0)))
	return e


# the bubble for a film t px thick, at LEVELS thicknesses from none to the tank's narrowest half:
# the wall moved t in all round (exactly: the tank is convex, so its inside is where every wall's
# half-plane moved in by t overlaps), but never further from the middle than a few times what is
# left of that narrowest half (a small bubble is round, a big one leaves an even film on the
# wall). Its radii one way round each and its area; worked out a couple of tanks a frame.
const LEVELS := 16
const EDGES := 24

func _levels(e: Dictionary) -> void:
	var R: PackedFloat32Array = e.R
	var ns := PackedVector2Array()
	var hs := PackedFloat32Array()
	var step := N / EDGES
	var rin := 1e9
	for j in EDGES:
		var a: Vector2 = _dirs[j * step] * R[j * step]
		var b: Vector2 = _dirs[((j + 1) * step) % N] * R[((j + 1) * step) % N]
		if a.distance_to(b) < 0.01:
			continue
		var n: Vector2 = (b - a).orthogonal().normalized()
		if n.dot(a) < 0.0:
			n = -n
		ns.append(n)
		hs.append(n.dot(a))
		rin = minf(rin, n.dot(a))
	rin = maxf(rin, 1.0)
	var lv: Array = []
	var la := PackedFloat32Array()
	for k in LEVELS + 1:
		var t: float = rin * float(k) / LEVELS
		var u: float = float(k) / LEVELS
		var cap: float = 2.6 * (rin - t) * (1.0 + 6.0 * pow(1.0 - u, 3.0))
		var rs := PackedFloat32Array()
		rs.resize(N)
		var ar := 0.0
		for i in N:
			var d: Vector2 = _dirs[i]
			var r: float = minf(cap, R[i] * 0.995)
			for j in ns.size():
				var dn: float = d.dot(ns[j])
				if dn > 0.0001:
					r = minf(r, (hs[j] - t) / dn)
			r = maxf(r, 0.0)
			rs[i] = r
			ar += r * r
		lv.append(rs)
		la.append(ar)
	e["lv"] = lv
	e["la"] = la
	e["rin"] = rin


func _ray(poly: PackedVector2Array, c: Vector2, d: Vector2) -> float:
	var far: Vector2 = c + d * 100000.0
	var best := 0.0
	for i in poly.size():
		var hit = Geometry2D.segment_intersects_segment(c, far, poly[i], poly[(i + 1) % poly.size()])
		if hit != null:
			best = maxf(best, c.distance_to(hit))
	return best


func _find() -> void:
	_found = true
	var bo = game.get("boiloff")
	var mine := {}
	# HG-170's cryogenic tanks: no art, an octagon of shell plates
	if bo != null and bo.active():
		for t in bo.cfg.get("tanks", {}):
			var e: Dictionary = bo.cfg.tanks[t]
			var pts := PackedVector2Array()
			var thick := 99999.0
			var first = null
			for st in e.get("shell", []):
				var sp = world.tag(str(st))
				if sp == null:
					continue
				if first == null:
					first = sp
				pts.append_array(sp.poly)
				var pp: PackedVector2Array = sp.poly
				var longest := 0.0
				var ar := 0.0
				for i in pp.size():
					var a0: Vector2 = pp[i]
					var a1: Vector2 = pp[(i + 1) % pp.size()]
					longest = maxf(longest, a0.distance_to(a1))
					ar += a0.cross(a1)
				thick = minf(thick, absf(ar) * 0.5 / maxf(1.0, longest))
			if pts.size() < 3:
				continue
			var hull := Geometry2D.convex_hull(pts)
			hull.remove_at(hull.size() - 1)
			var inner: Array = Geometry2D.offset_polygon(hull, -minf(thick, 0.8 * Geom.M) - 1.0)
			if inner.is_empty():
				continue
			var vk: String = str(e.get("vol", ""))
			mine[vk] = true
			_tanks.append(_tank(vk, null, inner[0], Transform2D.IDENTITY, str(e.get("look", "lh2")), 1.0, hull, str(t)))
	for vk in game.sys.fvol:
		if mine.has(vk):
			continue
		var v: Dictionary = game.sys.fvol[vk]
		if not v.has("piece"):
			continue
		var p = world.tag(str(v.piece))
		if p == null or p.gone or p.art_size == Vector2.ZERO:
			continue
		var art := _art_of(p)
		if art == "":
			continue
		var look := LC.of_volume(v)
		if art == "cryotank" and not v.has("look"):
			look = "ln2"
		var shapes := _shapes(art, p.art_size.x, p.art_size.y)
		for sh in shapes:
			_tanks.append(_tank(str(vk), p, sh, p.art_xf, look, 1.0 / shapes.size(), PackedVector2Array(), ""))
		if art == "water" or (EQ.ext != null and EQ.ext.has_method("liquid_rect") and not EQ.ext.liquid_rect(art, p.art_size.x, p.art_size.y).is_empty()):
			p.set_meta("liquid_live", true)
			world.redraw_near([p])


# ---------------------------------------------------------------- each frame

func _process(dt: float) -> void:
	if game == null or world == null:
		return
	if not _found:
		if game.sys == null or game.sys.fvol.is_empty() or game.state != "play":
			return
		_find()
	if _tanks.is_empty():
		return
	var built := 0
	for e in _tanks:
		if (e.lv as Array).is_empty():
			_levels(e)
			built += 1
			if built >= 2:
				break
	if not (game.paused_sim or game.state != "play"):
		_t += dt
		for e in _tanks:
			var now: float = game.sys.fluid(e.vol)
			var was: float = e.was
			e.was = now
			if was >= 0.0:
				e.flow = Pal.damp(float(e.flow), 1.0 if was - now > 0.00001 else 0.0, 3.0 if was - now > 0.00001 else 1.2, dt)
	node.queue_redraw()
	glow.queue_redraw()


func _view() -> Rect2:
	var vp: Viewport = world.get_viewport()
	var inv: Transform2D = world.get_global_transform_with_canvas().affine_inverse()
	var r := Rect2(inv * Vector2.ZERO, Vector2.ZERO)
	var s: Vector2 = vp.get_visible_rect().size
	for q in [Vector2(s.x, 0), Vector2(0, s.y), s]:
		r = r.expand(inv * q)
	return r.grow(r.size.x * 0.05)


func _xf(e: Dictionary) -> Transform2D:
	if e.p == null:
		return Transform2D.IDENTITY
	return world.frame(e.p) * e.xf


func _live(e: Dictionary) -> bool:
	if e.p != null and e.p.gone:
		return false
	if e.boil != "":
		var bo = game.get("boiloff")
		if bo != null and bo.burst.has(e.boil):
			return false
	return true


func _boil(e: Dictionary) -> float:
	if e.has("boil_k"):
		return float(e.boil_k)
	if not LC.misty(e.look):
		return 0.0
	if e.boil == "":
		return 0.45
	var bo = game.get("boiloff")
	if bo == null:
		return 0.45
	if bo._venting.has(e.boil):
		return 1.0
	var fl: float = float(bo.cfg.get("floor", 300.0))
	var rl: float = float(bo.cfg.get("relief", 600.0))
	var k := clampf((bo.tank_kpa(e.boil) - fl) / maxf(1.0, rl - fl), 0.0, 1.0)
	return (0.2 if bo._cooled(e.boil) else 0.45) + 0.55 * k


# where a tank's outlet is, in its own frame (its port)
func _port_dir(e: Dictionary, xf: Transform2D) -> Vector2:
	if e.has("pd"):
		return e.pd
	var pd := Vector2.DOWN
	var port: String = str(game.sys.fvol.get(e.vol, {}).get("port", ""))
	if world.ctrls.has(port):
		var pw: Vector2 = world.ctrl_world(world.ctrls[port])
		var pl: Vector2 = xf.affine_inverse() * pw
		if pl.distance_to(e.c) > 0.5:
			pd = (pl - e.c).normalized()
	e["pd"] = pd
	return pd


# the wall and bubble points of a tank this frame (its own frame), or [] when it holds nothing
func _shape(e: Dictionary, xf: Transform2D) -> Array:
	# (a tank that asks for it keeps its shape two frames: the bubble moves slowly)
	var fr := Engine.get_process_frames() / (2 if e.has("slow") else 1)
	if int(e.get("_f", -1)) == fr:
		return e._sh
	var out := _shape_now(e, xf)
	e["_f"] = fr
	e["_sh"] = out
	return out


func _shape_now(e: Dictionary, xf: Transform2D) -> Array:
	# (a tank not of a ship's volumes — the gas plant's — says how full it is itself)
	var k := clampf(float(e.k_now) if e.has("k_now") else game.sys.fluid(e.vol) / float(e.full), 0.0, 1.0)
	if k <= 0.003:
		return []
	var lv: Array = e.lv
	if lv.is_empty():
		return []
	# the film thickness level whose bubble has the empty share's area
	var want: float = (1.0 - k) * float(e.area)
	var la: PackedFloat32Array = e.la
	var lk := 0
	while lk < LEVELS - 1 and la[lk + 1] >= want:
		lk += 1
	var lf: float = clampf((la[lk] - want) / maxf(0.0001, la[lk] - la[lk + 1]), 0.0, 1.0)
	var r0: PackedFloat32Array = lv[lk]
	var r1: PackedFloat32Array = lv[lk + 1]
	var th: float = (lk + lf) / LEVELS
	var R: PackedFloat32Array = e.R
	var rho: PackedFloat32Array = e.rho
	var c: Vector2 = e.c
	var t: float = _t + float(e.seed)
	var fl: float = float(e.flow)
	var wob: float = 0.035 * (1.0 + 0.6 * _boil(e) + 0.8 * fl)
	var ph2 := t * 0.9
	var ph3 := t * 1.37 + 1.0
	var r := PackedFloat32Array()
	r.resize(N)
	var gap := 1e9
	for i in N:
		var a: float = TAU * i / N
		var ri: float = minf(lerpf(r0[i], r1[i], lf) * (1.0 + wob * cos(2.0 * a + ph2) + wob * 0.6 * cos(3.0 * a - ph3)), R[i] * 0.995)
		r[i] = ri
		gap = minf(gap, R[i] - ri)
	# the bubble drifting about; drawn off, pushed from the outlet (the liquid gathers there)
	var drift := Vector2(sin(t * 0.31), cos(t * 0.23 + 0.7)) * 0.55
	var pd := _port_dir(e, xf)
	var d: Vector2 = (drift * (1.0 - fl) - pd * 0.9 * fl) * maxf(0.0, gap)
	var W := PackedVector2Array()
	var B := PackedVector2Array()
	W.resize(N)
	B.resize(N)
	for i in N:
		W[i] = c + _dirs[i] * R[i]
		B[i] = c + d + _dirs[i] * r[i]
	return [W, B, k, 1.0 - th, d]


# ARK-01 帧率: zoomed this far out a boiling bubble (1-4 px) is under a fifth of a pixel and the
# outlet rings under one: they are left out (the whole ship in view drew hundreds of arcs a frame)
const FAR_ZOOM := 0.14
var _far := false


func _draw() -> void:
	if _tanks.is_empty() or node == null:
		return
	_far = game != null and game.has_method("cam_zoom") and game.cam_zoom() < FAR_ZOOM and not World.ark_old
	var view := _view()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for e in _tanks:
		if not _live(e):
			continue
		var xf := _xf(e)
		var bb: Rect2 = xf * (e.bb as Rect2)
		if not view.intersects(bb):
			continue
		emit_liquid(e, xf, node, verts, cols, idx)
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), idx, verts, cols)


# one tank's liquid: its triangles added to verts / cols / idx (drawn together by the caller), the
# meniscus, frost and boiling drawn on ci (scripts/gas_plant.gd uses it for its own tanks)
func emit_liquid(e: Dictionary, xf: Transform2D, ci: CanvasItem, verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array) -> void:
	var sh := _shape(e, xf)
	if sh.is_empty():
		if (e.frost as PackedVector2Array).size() > 0:
			ci.draw_multiline(xf * (e.frost as PackedVector2Array), Color(0.9, 0.95, 1.0, 0.22), -1.0)
		return
	var W: PackedVector2Array = xf * (sh[0] as PackedVector2Array)
	var B: PackedVector2Array = xf * (sh[1] as PackedVector2Array)
	var look: String = e.look
	var op := LC.opacity(look)
	var col := LC.of(look)
	# (the 2D canvas blends in linear light: a tenth is already a clear grey on screen)
	var aw := lerpf(0.13, 0.75, op)     # against the wall, where it is deepest
	var ab := lerpf(0.035, 0.5, op)     # at the meniscus, thin
	var cw := Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, aw)
	var cb := Color(col.r, col.g, col.b, ab)
	# the bubble's centre (the gas fan's middle)
	var bc := Vector2.ZERO
	for v in B:
		bc += v
	bc /= N
	# 60 FPS: the colours and the triangles' order never change for a tank — kept once, offset
	# only when other tanks are already in the list
	if not e.has("_cl"):
		var gas: float = 0.03 if LC.misty(look) else 0.008
		var cl := PackedColorArray()
		var ix := PackedInt32Array()
		for i in N:
			cl.append(cw)
		for i in N:
			cl.append(cb)
		cl.append(Color(0.92, 0.96, 1.0, gas * 0.15))
		for i in N:
			cl.append(Color(0.92, 0.96, 1.0, gas))
		for i in N:
			var j := (i + 1) % N
			ix.append_array(PackedInt32Array([i, j, N + i, j, N + j, N + i]))
		var gb := 2 * N
		for i in N:
			ix.append_array(PackedInt32Array([gb, gb + 1 + i, gb + 1 + (i + 1) % N]))
		e["_cl"] = cl
		e["_ix"] = ix
	var base := verts.size()
	verts.append_array(W)
	verts.append_array(B)
	verts.append(bc)
	verts.append_array(B)
	cols.append_array(e._cl)
	if base == 0:
		idx.append_array(e._ix)
	else:
		var ix2: PackedInt32Array = (e._ix as PackedInt32Array).duplicate()
		for i in ix2.size():
			ix2[i] += base
		idx.append_array(ix2)
	# the meniscus round the bubble
	if (sh[3] as float) > 0.04:
		var ring := B.duplicate()
		ring.append(B[0])
		ci.draw_polyline(ring, Color(lerpf(col.r, 1.0, 0.5), lerpf(col.g, 1.0, 0.5), lerpf(col.b, 1.0, 0.5), 0.55), -1.0)
	# frost on the shell
	if (e.frost as PackedVector2Array).size() > 0:
		ci.draw_multiline(xf * (e.frost as PackedVector2Array), Color(0.9, 0.95, 1.0, 0.5), -1.0)
	# boiling: bubbles off the wall into the vapour
	var boil := _boil(e) if not _far else 0.0
	if boil > 0.0:
		var nb := int(4 + 14 * boil)
		for m in nb:
			var h := fposmod(sin((m + 1) * 91.7 + float(e.seed)) * 4375.85, 1.0)
			var i0 := int(h * N) % N
			var u := fposmod(_t * (0.5 + 0.9 * boil) * (0.7 + 0.6 * h) + h * 7.0, 1.0)
			var pp: Vector2 = W[i0].lerp(B[i0], u * 0.92 + 0.04)
			pp += (B[i0] - W[i0]).orthogonal().normalized() * sin(_t * 7.0 + m) * 1.5
			ci.draw_arc(pp, 1.2 + 2.4 * u, 0.0, TAU, 8, Color(0.95, 0.97, 1.0, 0.7 * (1.0 - u * 0.4)), -1.0)


func _draw_glow() -> void:
	if _tanks.is_empty() or glow == null:
		return
	var view := _view()
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	for e in _tanks:
		if not _live(e):
			continue
		var xf := _xf(e)
		var bb: Rect2 = xf * (e.bb as Rect2)
		if not view.intersects(bb):
			continue
		emit_glow(e, xf, glow, segs, sc)
	if not segs.is_empty():
		glow.draw_multiline_colors(segs, sc, 1.4)


# one tank's glint and outflow on an additive layer (segs / sc drawn together by the caller)
func emit_glow(e: Dictionary, xf: Transform2D, ci: CanvasItem, segs: PackedVector2Array, sc: PackedColorArray) -> void:
	var sh := _shape(e, xf)
	if sh.is_empty():
		return
	var W: PackedVector2Array = sh[0]
	var B: PackedVector2Array = sh[1]
	var col := LC.of(e.look)
	# a glint on the bubble, up and to the left, as on a ball of gas in liquid
	if (sh[3] as float) > 0.12:
		var g := PackedVector2Array()
		var bc := Vector2.ZERO
		for v in B:
			bc += v
		bc /= N
		for i in range(int(N * 0.56), int(N * 0.7)):
			g.append(xf * bc.lerp(B[i], 0.8))
		ci.draw_polyline(g, Color(1.0, 1.0, 1.0, 0.22), 1.6)
	# drawn off: the liquid streaming round the wall to the outlet
	var fl: float = float(e.flow)
	if fl > 0.03:
		var pd := _port_dir(e, xf)
		var ip := int(round(fposmod(pd.angle(), TAU) / TAU * N)) % N
		for m in 10:
			var side := 1 if m % 2 == 0 else -1
			var u := fposmod(_t * 0.8 + m * 0.21, 1.0)
			var off := int((1.0 - u) * N * 0.45)
			var i0 := (ip + side * off + N * 4) % N
			var i1 := (i0 - side * 2 + N * 4) % N
			var a0: Vector2 = xf * W[i0].lerp(B[i0], 0.5)
			var a1: Vector2 = xf * W[i1].lerp(B[i1], 0.5)
			segs.append(a0)
			segs.append(a1)
			sc.append(Color(lerpf(col.r, 1.0, 0.3), lerpf(col.g, 1.0, 0.3), lerpf(col.b, 1.0, 0.3), 0.5 * fl * sin(u * PI)))
		var outlet: Vector2 = xf * W[ip]
		for k in (0 if _far else 2):
			var u2 := fposmod(_t * 1.5 + k * 0.5, 1.0)
			ci.draw_arc(outlet, 3.0 + 9.0 * u2, 0.0, TAU, 12, Color(col.r, col.g, col.b, 0.45 * fl * (1.0 - u2)), 1.2)
