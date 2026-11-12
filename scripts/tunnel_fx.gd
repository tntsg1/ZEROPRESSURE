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
const MAX_DOTS := 520         # dithered dots inside the wall, per frame (all bodies together)
# 2026-11-11 (user: "干脆就把所有穿模装上那个量子的动画"): every body passing through the ship without touching
# it — a load in the grapple, a hauler's / the crane's / the arm's / a crew boat's, one easing out of a
# wall after a let-go (FreeBody: its mask without World.STATIC_LAYER) — gets the same wave-packet look,
# tunnelling upgrade or not. The player's own drone only when it tunnels (body_tunnel: it collides
# otherwise). Many at once: only those on screen, at most MAX_OTHER of them (nearest the view's middle),
# the walls looked up in a grid of the ship's outlines, one dot budget, crossing sounds spaced.
const MAX_OTHER := 6            # (two haulers, the crane, the arm, a crew boat: five at most in play)
const CELL := 192.0           # px: the grid the ship's outlines are filed in
const SND_GAP := 0.12         # s between two crossing sounds of bodies not the player's

var tools
var t := 0.0
var rings: Array = []         # {p, r, life, age, halo}
var watch := {}               # body instance id -> {"b", "hist": [[polys...]], "ht", "rt", "in", "c", "st", "e"}
var stats := {"inside": 0, "rings": 0, "halos": 0, "entries": 0, "exits": 0, "drone_in": 0, "drone_entries": 0, "drone_exits": 0, "flames": 0, "others": 0, "others_in": 0, "other_entries": 0, "dots": 0, "us_proc": 0, "us_draw": 0}
var _walls: Array = []        # [[bbox, world poly]] of the attached ship's pieces
var _grid := {}               # Vector2i -> [index into _walls]
var _walls_t := -9.0
var _walls_n := -1
var _snd_t := 0.0
var _last_in := {}            # body instance id -> when it was last inside a wall (no halo again for a re-show)
var all_phasing := true       # false: only the player's own, as before 2026-11-11 (tests' before shots)


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
		if is_instance_valid(b) and not (b is Drone) and not out.has(b) and b.clearing > 0.0:
			out.append(b)
	# 2026-11-11 量子隧穿·机体: the drone itself, tunnelling or easing out of a wall after
	var bt = tools.body_tunnel
	var d = tools.drone
	if bt != null and bt.showing() and d != null and is_instance_valid(d) and d.alive:
		out.append(d)
	# every other body that does not touch the ship now (carried, eased out, tunnelling), on screen
	var game = _game()
	if game != null and game.world != null and all_phasing:
		var view := _view().grow(240.0)
		var mid := view.get_center()
		var more: Array = []
		for b in game.world.bodies:
			if not is_instance_valid(b) or out.has(b) or b.capture != null or b.get_meta("arm_parked", false):
				continue
			if b.collision_mask & World.STATIC_LAYER:
				continue
			if not view.has_point(b.global_position):
				continue
			# those already drawn stay (no churn of who is shown: each change would ring a halo)
			more.append([b.global_position.distance_squared_to(mid) * (0.25 if watch.has(b.get_instance_id()) else 1.0), b])
		more.sort_custom(func(x, y): return x[0] < y[0])
		for i in mini(MAX_OTHER, more.size()):
			out.append(more[i][1])
		stats.others = mini(MAX_OTHER, more.size())
	return out


# the world rect on screen
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	return vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()


# the attached ship's outlines, filed in a grid (looked at again when pieces come off, or every 0.3 s:
# a towed hulk moves)
func _file_walls(game) -> void:
	var n: int = game.world.pieces.size()
	var gone := 0
	for q in game.world.pieces.values():
		if q.gone or q.body != null:
			gone += 1
	if t - _walls_t < 0.3 and n * 100000 + gone == _walls_n:
		return
	_walls_t = t
	_walls_n = n * 100000 + gone
	_walls.clear()
	_grid.clear()
	for q in game.world.pieces.values():
		if q.gone or q.body != null:
			continue
		var wq: PackedVector2Array = game.world.world_poly(q)
		if wq.size() < 3:
			continue
		var bb := Geom.bbox(wq)
		var k := _walls.size()
		_walls.append([bb, wq])
		for gx in range(int(floorf(bb.position.x / CELL)), int(floorf(bb.end.x / CELL)) + 1):
			for gy in range(int(floorf(bb.position.y / CELL)), int(floorf(bb.end.y / CELL)) + 1):
				var c := Vector2i(gx, gy)
				if not _grid.has(c):
					_grid[c] = []
				_grid[c].append(k)


# the drone's outline (its hull, round)
func _drone_poly(d) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = d.global_position
	for k in 20:
		out.append(c + Vector2.from_angle(TAU * k / 20.0) * Drone.R)
	return out


func _process(dt: float) -> void:
	var us0 := Time.get_ticks_usec()
	_process_inner(dt)
	stats.us_proc = Time.get_ticks_usec() - us0


func _process_inner(dt: float) -> void:
	var game = _game()
	if game == null or game.world == null:
		return
	t += dt
	_snd_t -= dt
	var live := {}
	var inside_n := 0
	var others_in := 0
	var own = tools.held_body
	for b in _candidates():
		var id: int = b.get_instance_id()
		live[id] = true
		if not watch.has(id):
			watch[id] = {"b": b, "out_t": float(_last_in.get(id, -9.0)), "hist": [], "ht": 0.0, "rt": 0.0, "in": false, "c": Vector2.ZERO, "st": 0.0, "e": 0.0, "parts": [], "polys": [], "cross": []}
		var w: Dictionary = watch[id]
		var is_drone: bool = b is Drone
		var polys: Array = []
		if is_drone:
			polys.append(_drone_poly(b))
			# the jets' echoes: where it burned, and which way (drone.thrust), a moment ago
			if not w.has("fl"):
				w["fl"] = []
			w["ft"] = float(w.get("ft", 0.0)) - dt
			if w.ft <= 0.0:
				w.ft = 0.035
				if b.thrust.length() > 0.1:
					w.fl.push_back([b.global_position, b.thrust.normalized(), 0.0])
			for f in w.fl:
				f[2] += dt
			w.fl = w.fl.filter(func(f): return f[2] < 0.42)
			stats.flames = w.fl.size()
		else:
			for p in b.pieces:
				if not p.gone:
					polys.append(game.world.world_poly(p))
		w.polys = polys
		var parts := _inside(game, polys)
		w.parts = parts
		var now_in := not parts.is_empty()
		if now_in:
			_last_in[id] = t
		w.e = move_toward(float(w.e), 1.0 if now_in else 0.0, dt * (6.0 if now_in else 2.5))
		if now_in:
			inside_n += 1
			var c := Vector2.ZERO
			var n := 0
			for it in parts:
				c += Geom.centroid(it.part)
				n += 1
			w.c = c / maxf(1.0, n)
		if is_drone and now_in:
			stats.drone_in += 1
		# the player's own (the drone, what its grapple holds) always sound; the machines' loads spaced
		var mine: bool = is_drone or b == own or bool(b.tethered)
		if not mine and now_in:
			others_in += 1
		var loud: bool = mine or _snd_t <= 0.0
		# in again a moment after it was (a flicker at a face, or shown again after a turn off screen):
		# no new halo, no new sound — the crossing it is in the middle of
		var again: bool = now_in and not w.in and t - float(w.get("out_t", -9.0)) < 0.4
		if now_in and not w.in and again:
			pass
		elif now_in and not w.in:
			_halo(w.c, not mine)
			stats.entries += 1
			if is_drone:
				stats.drone_entries += 1
			if not mine:
				stats.other_entries += 1
			if loud:
				if not mine:
					_snd_t = SND_GAP
				var k := 1.0 if mine else 0.55
				# the drone's own crossing a little lower and fuller than a load's
				game.sfx.play("holo", w.c, (0.9 if is_drone else 0.8) * k, 0.42 if is_drone else 0.5)
				game.sfx.play("reveal", w.c, (0.5 if is_drone else 0.45) * k, 1.6 if is_drone else 1.9)
		elif w.in and not now_in:
			_halo(w.c, not mine)
			stats.exits += 1
			if is_drone:
				stats.drone_exits += 1
			if loud:
				if not mine:
					_snd_t = SND_GAP
				game.sfx.play("mirror_lock", w.c, (0.55 if is_drone else 0.5) * (1.0 if mine else 0.55), 1.35 if is_drone else 1.6)
		if w.in and not now_in:
			w["out_t"] = t
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
				# a machine's load: a third as often, two of its crossings (many at once stay cheap)
				w.rt = RIPPLE_DT * (1.0 if mine else 3.0)
				var nx: int = w.cross.size() if mine else (mini(2, w.cross.size()) if rings.size() < 20 else 0)
				for xi in nx:
					_ring(w.cross[xi], 34.0, RING_LIFE, false)
			w.st = float(w.st) - dt
			if w.st <= 0.0:
				w.st = 0.22 if mine else 0.45
				if mine or _snd_t <= 0.0:
					game.sfx.play("static_arc", w.c, 0.12 if mine else 0.07, 2.4 + randf() * 0.4)
	for id in watch.keys():
		if not live.has(id):
			watch.erase(id)
	if _last_in.size() > 64:
		for id in _last_in.keys():
			if t - float(_last_in[id]) > 1.0:
				_last_in.erase(id)
	for r in rings:
		r.age += dt
	rings = rings.filter(func(r): return r.age < r.life)
	stats.inside = inside_n
	stats.others_in = others_in
	stats.rings = rings.size()
	if not watch.is_empty() or not rings.is_empty():
		queue_redraw()
	elif stats.inside == 0 and get_meta("drawn", false):
		set_meta("drawn", false)
		queue_redraw()


# the parts of the load inside the attached ship's pieces
func _inside(game, polys: Array) -> Array:
	var out: Array = []
	_file_walls(game)
	for wp in polys:
		var bb := Geom.bbox(wp)
		var seen := {}
		for gx in range(int(floorf(bb.position.x / CELL)), int(floorf(bb.end.x / CELL)) + 1):
			for gy in range(int(floorf(bb.position.y / CELL)), int(floorf(bb.end.y / CELL)) + 1):
				for k in _grid.get(Vector2i(gx, gy), []):
					seen[k] = true
		for k in seen:
			var wq: PackedVector2Array = _walls[k][1]
			if not bb.intersects(_walls[k][0]):
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


func _halo(p: Vector2, lite := false) -> void:
	_ring(p, 130.0, HALO_LIFE, true)
	rings[rings.size() - 1]["lite"] = lite
	stats.halos += 1


# a plain ring: one cached unit circle, placed by the canvas transform (no points made per ring)
var _unit := PackedVector2Array()
func _circ(c: Vector2, r: float, col: Color, w: float) -> void:
	if _unit.is_empty():
		for k in 25:
			_unit.append(Vector2.from_angle(TAU * k / 24.0))
	draw_set_transform(c, 0.0, Vector2(r, r))
	draw_polyline(_unit, col, w / maxf(r, 0.01))


func _hash(x: int, y: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (k * 83492791)
	return float(absi(h) % 1000) / 1000.0


# the outline broken into screen pixels (snapped to a q grid), each flickering in phase
# (one draw call for all its pixels: each a short thick segment — 2026-11-11, many bodies at once)
func _quant(poly: PackedVector2Array, q: float, col: Color, off: Vector2, flick: float) -> void:
	var last := Vector2.INF
	var frame := int(t * 30.0)
	var segs := PackedVector2Array()
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
			var y := s.y * q + q * 0.5
			segs.append(Vector2(s.x * q + q * 0.1, y))
			segs.append(Vector2(s.x * q + q * 0.9, y))
	if segs.size() >= 2:
		draw_multiline(segs, col, q * 0.8)


func _draw() -> void:
	var us0 := Time.get_ticks_usec()
	_draw_inner()
	stats.us_draw = Time.get_ticks_usec() - us0


func _draw_inner() -> void:
	var game = _game()
	if game == null:
		return
	set_meta("drawn", true)
	var z: float = maxf(0.05, game.cam_zoom())
	var q := 4.0 / z
	var air := Pal.AIR
	var violet := Pal.VOLT
	var dots := 0
	for id in watch:
		var w: Dictionary = watch[id]
		var e: float = w.e
		if e <= 0.01:
			continue
		var b = w.b
		# the machines' loads (not the player's drone or what its grapple holds): the same look, lighter —
		# one echo, half the fringes, no dots, plainer rings
		var lite: bool = is_instance_valid(b) and not (b is Drone) and not bool(b.tethered)
		# the drone: the whole time it tunnels, its hull is the two-layer wave packet, and its jets
		# leave pixel echoes behind (only the load's parts inside a wall get the rest)
		if is_instance_valid(b) and b is Drone:
			e = maxf(e, 0.55)
			for f in w.get("fl", []):
				var age: float = f[2] / 0.42
				var at: Vector2 = f[0]
				var back: Vector2 = -f[1]
				var fa := (1.0 - age) * 0.5
				var tip := at + back * (Drone.R + (14.0 + 18.0 * age) / z)
				_quant(PackedVector2Array([at + back * Drone.R, tip]), q, Pal.tint(air if int(f[2] * 60.0) % 2 == 0 else violet, fa, 1.4), Vector2.ZERO, 0.2 + 0.5 * age)
		var v: Vector2 = b.linear_velocity if is_instance_valid(b) else Vector2.ZERO
		var u := v.normalized() if v.length() > 5.0 else Vector2.RIGHT
		var perp := Vector2(-u.y, u.x)
		# phase-split echoes of where it was, oldest faintest, broken into pixels
		var hist: Array = w.hist
		for k in range(maxi(0, hist.size() - 1) if lite else 0, hist.size()):
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
				s0 += lam * (1.0 if lite else 0.5)
			# |ψ|²: pixels lit at random inside, more of them towards the middle
			var gstep := q * 2.0
			var frame := int(t * 24.0)
			var gx := floorf(bb.position.x / gstep)
			if lite:
				gx = INF
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
			# a machine's load: the standing wave coarser (a few points, not one every 3 px)
			var n := mini(8, maxi(2, int(along.length() / (6.0 / z)))) if lite else maxi(2, int(along.length() / (3.0 / z)))
			var nrm := Vector2(-along.y, along.x).normalized()
			var pts := PackedVector2Array()
			for k in n + 1:
				var f := float(k) / float(n)
				pts.append(a0 + along * f + nrm * sin(f * TAU * 3.0 + t * 18.0) * (3.0 / z) * sin(f * PI))
			draw_polyline(pts, Pal.tint(air, 0.8 * e, 1.6), 2.0 / z, not lite)
			if not lite:
				draw_polyline(pts, Pal.ink(0.55 * e, 1.6), 1.0 / z, true)
		for x in cr:
			if lite:
				draw_rect(Rect2(x - Vector2.ONE * 2.0 / z, Vector2.ONE * 4.0 / z), Pal.ink(0.8 * e, 1.3))
				continue
			draw_circle(x, 2.2 / z, Pal.ink(0.8 * e, 1.3))
			draw_arc(x, (7.0 + 2.5 * sin(t * 20.0)) / z, 0.0, TAU, 12 if lite else 20, Pal.tint(air, 0.6 * e, 1.3), 1.2 / z, not lite)
	stats.dots = dots
	# ripples on the wall faces, and the entry / exit halos
	for r in rings:
		var k: float = r.age / r.life
		var rad: float = (r.r * Pal.ease_out(k) + 3.0) / z
		var a: float = (1.0 - k) * (1.0 - k)
		if r.halo and r.get("lite", false):
			# a machine's load: the halo's two rings, plainer (many at once)
			_circ(r.p, rad, Pal.tint(air, 0.7 * a, 1.5), 2.0 / z)
		elif r.halo:
			draw_set_transform(Vector2.ZERO)
			draw_arc(r.p, rad, 0.0, TAU, 72, Pal.tint(air, 0.8 * a, 1.5), 2.6 / z, true)
			draw_arc(r.p, rad * 0.9, 0.0, TAU, 72, Pal.ink(0.4 * a, 1.6), 1.2 / z, true)
			draw_arc(r.p, rad * 0.72, 0.0, TAU, 48, Pal.tint(violet, 0.4 * a, 1.4), 1.4 / z, true)
			# dashed outer shell, turning
			var n := 18
			for i in n:
				var a0 := TAU * float(i) / float(n) + t * 1.6
				draw_arc(r.p, rad * 1.18, a0, a0 + TAU / float(n) * 0.45, 4, Pal.ink(0.5 * a, 1.3), 1.0 / z)
		else:
			_circ(r.p, rad, Pal.tint(air, 0.5 * a, 1.2), 1.2 / z)
			_circ(r.p, rad * 0.55, Pal.ink(0.35 * a, 1.2), 1.0 / z)
	draw_set_transform(Vector2.ZERO)
