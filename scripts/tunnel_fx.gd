extends Node2D
# 2026-11-10 量子隧穿效应 (user: "穿墙的时候会有特效，就是那种很酷炫的特效"): what the player's grapple carries
# through a wall with the tunnelling upgrade on (FreeBody.tunneling) is drawn as a wave-function, not
# a solid: inside the wall its outline breaks into pixels (quantised to the screen grid), it leaves
# phase-split echoes of where it was a moment ago, the part inside the wall carries moving
# interference fringes and flickers in and out; where its outline crosses the wall's faces the wall
# ripples, and a halo rings out where it went in and where it came out. Black and white with the
# grapple's air-blue (and a hint of violet for the phase split). Sounds: the existing cues at other
# pitches (holo, reveal, static_arc, mirror_lock) — no synthesis.
# Driven by tools.gd (a child of it); tests read `stats`.

const ECHOES := 4             # past outlines kept
const ECHO_DT := 0.045        # s between them
const RIPPLE_DT := 0.09       # s between ripples where the outline crosses a wall face
const RING_LIFE := 0.55       # s a ripple lives
const HALO_LIFE := 0.9        # s the entry / exit halo lives
const MAX_RINGS := 48
const MAX_DOTS := 520         # dithered dots inside the wall, per frame

var tools
var t := 0.0
var rings: Array = []         # {p, r, life, age, halo}
var watch := {}               # body instance id -> {"b", "hist": [[polys...]], "ht", "rt", "in", "c", "st", "e"}
var stats := {"inside": 0, "rings": 0, "halos": 0, "entries": 0, "exits": 0}


func _init() -> void:
	z_index = 8
	z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _game():
	return tools.game if tools != null else null


# the bodies in the tunnel now, and those still easing out of a wall after it
func _candidates() -> Array:
	var out: Array = []
	if tools == null:
		return out
	var hb = tools.held_body
	if hb != null and is_instance_valid(hb) and hb.tunneling:
		out.append(hb)
	if tools.multi != null:
		for h in tools.multi.held:
			if is_instance_valid(h.body) and h.body.tunneling and not out.has(h.body):
				out.append(h.body)
	for id in watch:
		var b = watch[id].b
		if is_instance_valid(b) and not out.has(b) and b.clearing > 0.0:
			out.append(b)
	return out


func _process(dt: float) -> void:
	var game = _game()
	if game == null or game.world == null:
		return
	t += dt
	var live := {}
	var inside_n := 0
	for b in _candidates():
		var id: int = b.get_instance_id()
		live[id] = true
		if not watch.has(id):
			watch[id] = {"b": b, "hist": [], "ht": 0.0, "rt": 0.0, "in": false, "c": Vector2.ZERO, "st": 0.0, "e": 0.0, "parts": [], "polys": [], "cross": []}
		var w: Dictionary = watch[id]
		var polys: Array = []
		for p in b.pieces:
			if not p.gone:
				polys.append(game.world.world_poly(p))
		w.polys = polys
		var parts := _inside(game, polys)
		w.parts = parts
		var now_in := not parts.is_empty()
		w.e = move_toward(float(w.e), 1.0 if now_in else 0.0, dt * (6.0 if now_in else 2.5))
		if now_in:
			inside_n += 1
			var c := Vector2.ZERO
			var n := 0
			for it in parts:
				c += Geom.centroid(it.part)
				n += 1
			w.c = c / maxf(1.0, n)
		if now_in and not w.in:
			_halo(w.c)
			stats.entries += 1
			game.sfx.play("holo", w.c, 0.8, 0.5)
			game.sfx.play("reveal", w.c, 0.45, 1.9)
		elif w.in and not now_in:
			_halo(w.c)
			stats.exits += 1
			game.sfx.play("mirror_lock", w.c, 0.5, 1.6)
		w.in = now_in
		# echoes: where it was a moment ago
		w.ht = float(w.ht) - dt
		if w.ht <= 0.0:
			w.ht = ECHO_DT
			w.hist.push_back(polys.duplicate(true))
			while w.hist.size() > ECHOES:
				w.hist.pop_front()
		w.cross = _crossings(parts, polys) if now_in else []
		if now_in:
			# the wall ripples where the outline crosses its faces
			w.rt = float(w.rt) - dt
			if w.rt <= 0.0:
				w.rt = RIPPLE_DT
				for x in w.cross:
					_ring(x, 34.0, RING_LIFE, false)
			w.st = float(w.st) - dt
			if w.st <= 0.0:
				w.st = 0.22
				game.sfx.play("static_arc", w.c, 0.12, 2.4 + randf() * 0.4)
	for id in watch.keys():
		if not live.has(id):
			watch.erase(id)
	for r in rings:
		r.age += dt
	rings = rings.filter(func(r): return r.age < r.life)
	stats.inside = inside_n
	stats.rings = rings.size()
	if not watch.is_empty() or not rings.is_empty():
		queue_redraw()
	elif stats.inside == 0 and get_meta("drawn", false):
		set_meta("drawn", false)
		queue_redraw()


# the parts of the load inside the attached ship's pieces
func _inside(game, polys: Array) -> Array:
	var out: Array = []
	for wp in polys:
		var bb := Geom.bbox(wp)
		for q in game.world.pieces.values():
			if q.gone or q.body != null:
				continue
			var wq: PackedVector2Array = game.world.world_poly(q)
			if not bb.intersects(Geom.bbox(wq)):
				continue
			for part in Geometry2D.intersect_polygons(wp, wq):
				if absf(Geom.area(part)) > 8.0:
					out.append({"part": part, "wall": wq})
	return out


# where the load's outline crosses a wall's outline (the two faces it is passing)
func _crossings(parts: Array, polys: Array) -> Array:
	var out: Array = []
	var seen := {}
	for it in parts:
		var wq: PackedVector2Array = it.wall
		if seen.has(wq):
			continue
		seen[wq] = true
		for wp in polys:
			for i in wp.size():
				var a: Vector2 = wp[i]
				var b: Vector2 = wp[(i + 1) % wp.size()]
				for j in wq.size():
					var x = Geometry2D.segment_intersects_segment(a, b, wq[j], wq[(j + 1) % wq.size()])
					if x != null:
						out.append(x)
						if out.size() >= 6:
							return out
	return out


func _ring(p: Vector2, r: float, life: float, halo: bool) -> void:
	if rings.size() >= MAX_RINGS:
		rings.pop_front()
	rings.append({"p": p, "r": r, "life": life, "age": 0.0, "halo": halo})


func _halo(p: Vector2) -> void:
	_ring(p, 130.0, HALO_LIFE, true)
	stats.halos += 1


func _hash(x: int, y: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (k * 83492791)
	return float(absi(h) % 1000) / 1000.0


# the outline broken into screen pixels (snapped to a q grid), each flickering in phase
func _quant(poly: PackedVector2Array, q: float, col: Color, off: Vector2, flick: float) -> void:
	var last := Vector2.INF
	var frame := int(t * 30.0)
	for i in poly.size():
		var a: Vector2 = poly[i] + off
		var b: Vector2 = poly[(i + 1) % poly.size()] + off
		var n := maxi(1, int(a.distance_to(b) / q))
		for k in n:
			var p := a.lerp(b, float(k) / float(n))
			var s := Vector2(floorf(p.x / q), floorf(p.y / q))
			if s == last:
				continue
			last = s
			if flick > 0.0 and _hash(int(s.x), int(s.y), frame) < flick:
				continue
			draw_rect(Rect2(s * q + Vector2(q * 0.1, q * 0.1), Vector2(q * 0.8, q * 0.8)), col)


func _draw() -> void:
	var game = _game()
	if game == null:
		return
	set_meta("drawn", true)
	var z: float = maxf(0.05, game.cam_zoom())
	var q := 4.0 / z
	var air := Pal.AIR
	var violet := Pal.VOLT
	for id in watch:
		var w: Dictionary = watch[id]
		var e: float = w.e
		if e <= 0.01:
			continue
		var b = w.b
		var v: Vector2 = b.linear_velocity if is_instance_valid(b) else Vector2.ZERO
		var u := v.normalized() if v.length() > 5.0 else Vector2.RIGHT
		var perp := Vector2(-u.y, u.x)
		# phase-split echoes of where it was, oldest faintest, broken into pixels
		var hist: Array = w.hist
		for k in hist.size():
			var age := float(hist.size() - k) / float(hist.size() + 1)
			var a := (1.0 - age) * 0.32 * e
			for poly in hist[k]:
				_quant(poly, q * (1.0 + age), Pal.tint(air if k % 2 == 0 else violet, a, 1.3), Vector2.ZERO, 0.35 + 0.4 * age)
		# the load itself: a wave packet — two phase-split pixel outlines that flicker
		var split := (1.5 + 1.2 * sin(t * 23.0)) / z
		for poly in w.polys:
			_quant(poly, q, Pal.tint(air, 0.7 * e, 1.2), perp * split, 0.18)
			_quant(poly, q, Pal.tint(violet, 0.45 * e, 1.3), -perp * split, 0.3)
		# inside the wall: interference fringes travelling with it, and dithered probability
		var lam := 7.0 / z
		var lam2 := 7.9 / z
		var dots := 0
		for it in w.parts:
			var part: PackedVector2Array = it.part
			var bb := Geom.bbox(part)
			var c := bb.get_center()
			var half := bb.size.length() * 0.5 + lam
			var s0 := -half
			while s0 <= half:
				var mid := c + u * s0
				var beat := (0.5 + 0.5 * cos(TAU * s0 / lam - t * 14.0)) * (0.5 + 0.5 * cos(TAU * s0 / lam2 + t * 9.0))
				if beat > 0.08:
					for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([mid - perp * half, mid + perp * half]), part):
						if seg.size() >= 2:
							draw_line(seg[0], seg[seg.size() - 1], Pal.tint(air if beat > 0.45 else Pal.INK, (0.06 + 0.32 * beat) * e, 0.9), 1.6 / z)
				s0 += lam * 0.5
			# |ψ|²: pixels lit at random inside, more of them towards the middle
			var gstep := q * 2.0
			var frame := int(t * 24.0)
			var gx := floorf(bb.position.x / gstep)
			while gx * gstep <= bb.end.x and dots < MAX_DOTS:
				var gy := floorf(bb.position.y / gstep)
				while gy * gstep <= bb.end.y and dots < MAX_DOTS:
					var p := Vector2(gx, gy) * gstep + Vector2.ONE * gstep * 0.5
					if Geometry2D.is_point_in_polygon(p, part) and _hash(int(gx), int(gy), frame) < 0.38:
						draw_rect(Rect2(p - Vector2.ONE * q * 0.4, Vector2.ONE * q * 0.8), Pal.ink(0.28 * e, 0.9))
						dots += 1
					gy += 1.0
				gx += 1.0
			# the edge of the part inside the wall, bright
			_quant(part, q, Pal.ink(0.6 * e, 1.1), Vector2.ZERO, 0.1)
		# the wall's faces where it passes them: a lit gate across the opening, standing waves on it
		var cr: Array = w.cross
		for i in range(0, cr.size() - 1, 2):
			var a0: Vector2 = cr[i]
			var a1: Vector2 = cr[i + 1]
			var along := (a1 - a0)
			var n := maxi(2, int(along.length() / (3.0 / z)))
			var nrm := Vector2(-along.y, along.x).normalized()
			var pts := PackedVector2Array()
			for k in n + 1:
				var f := float(k) / float(n)
				pts.append(a0 + along * f + nrm * sin(f * TAU * 3.0 + t * 18.0) * (3.0 / z) * sin(f * PI))
			draw_polyline(pts, Pal.tint(air, 0.8 * e, 1.6), 2.0 / z, true)
			draw_polyline(pts, Pal.ink(0.55 * e, 1.6), 1.0 / z, true)
		for x in cr:
			draw_circle(x, 2.2 / z, Pal.ink(0.8 * e, 1.3))
			draw_arc(x, (7.0 + 2.5 * sin(t * 20.0)) / z, 0.0, TAU, 20, Pal.tint(air, 0.6 * e, 1.3), 1.2 / z, true)
	# ripples on the wall faces, and the entry / exit halos
	for r in rings:
		var k: float = r.age / r.life
		var rad: float = (r.r * Pal.ease_out(k) + 3.0) / z
		var a: float = (1.0 - k) * (1.0 - k)
		if r.halo:
			draw_arc(r.p, rad, 0.0, TAU, 72, Pal.tint(air, 0.8 * a, 1.5), 2.6 / z, true)
			draw_arc(r.p, rad * 0.9, 0.0, TAU, 72, Pal.ink(0.4 * a, 1.6), 1.2 / z, true)
			draw_arc(r.p, rad * 0.72, 0.0, TAU, 48, Pal.tint(violet, 0.4 * a, 1.4), 1.4 / z, true)
			# dashed outer shell, turning
			var n := 18
			for i in n:
				var a0 := TAU * float(i) / float(n) + t * 1.6
				draw_arc(r.p, rad * 1.18, a0, a0 + TAU / float(n) * 0.45, 4, Pal.ink(0.5 * a, 1.3), 1.0 / z)
		else:
			draw_arc(r.p, rad, 0.0, TAU, 32, Pal.tint(air, 0.5 * a, 1.2), 1.2 / z, true)
			draw_arc(r.p, rad * 0.55, 0.0, TAU, 24, Pal.ink(0.35 * a, 1.2), 1.0 / z, true)
