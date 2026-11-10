extends Node2D
# IC-120's ice as it goes — drawing only, scripts/ice.gd keeps every number (user 2026-11-10:
# "冰融化的动画做好了呀，怎么突然消失，突然消失，这我玩个蛋呢").
#   A block being melted leaves the strips (world.live) and is drawn here every frame: a pit
#   eaten into it from the side its heater warms, its corners rounding off, the new surface wet
#   and glinting; what is seen of it is always the ice left in it (area = 1 - melt), down to a
#   small core that runs off as the last of its water. The meltwater beads on the wet face, runs
#   together into a ball sitting in the pit (free fall: surface tension holds it there) and,
#   big enough, goes off to the nearest intake on the water main; pulses run along the main
#   to its pump. A heater working glows, its coil lit, heat rippling toward the face it melts.
#   The crack across the saddle shows as the strain gauge reads it, and opens when it runs.
# The water is drawn as the game's liquid is (liquid_surface.gd, an instance of its own: one
# surface, globules close together reading as one body).

const F_CORE := 0.94          # past this the last of a block shrinks to its core
const TAB_N := 32             # pit radius solved at this many steps of the melt
const MAX_BLOBS := 160        # liquid_surface.gd reads it
const BEAD_RATE := 3.2        # beads a second on a face being melted
const POOL_GO := 0.045        # m³: a pit's ball this big goes off to the main
const RUN_SPEED := 3.0        # m/s a ball runs to the intake at
const PULSE_SPEED := 4.5      # m/s the water runs along the main

const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours
var ice
var game
var world
var glow: Node2D              # additive: heat, glints, the water in the main
var surface
var drops: Array = []         # the meltwater (drawing only): liquid_surface's globule fields + st, tag, vel, age, ph
var _poly0 := {}              # tag -> the block's outline when it started going (px, its own frame)
var _sig0 := {}               # tag -> hash of the piece's outline it was taken from
var _f0 := {}                 # tag -> melt when that outline was taken (a cut mid-melt starts it over)
var _a0 := {}
var _bite := {}               # tag -> {c, dir, s, rmax, minside}
var _rtab := {}               # tag -> pit radius at i / TAB_N * F_CORE of the melt
var _shape := {}              # tag -> {f, polys, area, fill, cols, idx, dry, dryc, wet, wetc, film, front}
var _heat := {}               # heater switch -> 0..1 warmth shown
var _work := {}               # heater switch -> the block it is on (while it works)
var _pool := {}               # tag -> its pit's ball
var _emit := {}
var _idle := {}               # tag -> s since it was last melted
var _pulses: Array = []       # {path index, s}
var _rings: Array = []        # [pos, t]
var _main: Array = []         # [path toward the pump (px), cumulative lengths]
var _crack: Array = []        # [a, b, s, branch]
var _crack_len := 0.0
var _crack_tags: Array = []
var _shards: Array = []
var _split_t := -1.0
var _was_split := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _area_log := {}           # tag -> area drawn this frame (tests)
var _ids := {}                # tag -> the piece id put in world.live


func setup(ic) -> void:
	ice = ic
	game = ic.game
	world = ic.world
	_rng.seed = 120
	z_index = 1
	z_as_relative = false
	world.add_child(self)
	world.move_child(self, world.piece_layer.get_index() + 1)
	glow = Node2D.new()
	glow.z_index = 4
	glow.z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(_draw_glow)
	world.add_child(glow)
	for h in ice.cfg.get("heaters", {}):
		_heat[h] = 0.0
	_crack_tags = ice.cfg.get("crack", {}).get("blocks", [])


# ---------------------------------------------------------------- liquid_surface.gd's host

static func radius_m(vol: float) -> float:
	return pow(maxf(vol, 1e-7) * 0.75 / PI, 1.0 / 3.0)


func _rad(b: Dictionary) -> float:
	return radius_m(float(b.vol)) * Geom.M


# ---------------------------------------------------------------- the shape of a block going

func _piece(tag: String):
	var p = world.tag(tag)
	return p if p != null and not p.gone and p.body == null else null


func _start(tag: String, p, f: float) -> void:
	var poly: PackedVector2Array = p.poly
	_poly0[tag] = poly
	_sig0[tag] = hash(poly)
	_f0[tag] = f
	_a0[tag] = Geom.area(poly)
	var bb := Geom.bbox(poly)
	var cen := Geom.centroid(poly)
	# heated from the side nearest its heater: the pit opens at the point of it nearest the pad
	var hc := cen + Vector2.UP * Geom.M * 20.0
	for h in ice.cfg.get("heaters", {}):
		if (ice.cfg.heaters[h].get("blocks", []) as Array).has(tag):
			var hp = world.tag(str(ice.cfg.heaters[h].get("piece", "")))
			if hp != null:
				hc = Geom.centroid(hp.poly)
	var c := _nearest_on(poly, hc)
	var dir := (cen - c).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	c -= dir * 0.35 * Geom.M
	var rmax := 0.0
	for v in poly:
		rmax = maxf(rmax, v.distance_to(c))
	_bite[tag] = {"c": c, "dir": dir, "s": float(hash(tag) % 997) * 0.013, "rmax": rmax * 1.25 + Geom.M, "minside": minf(bb.size.x, bb.size.y)}
	_rtab[tag] = [0.0]
	_shape.erase(tag)


static func _nearest_on(poly: PackedVector2Array, at: Vector2) -> Vector2:
	var best := at
	var bd := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])
		var d := q.distance_squared_to(at)
		if d < bd:
			bd = d
			best = q
	return best


# the pit's edge: a circle with a little waver in it (melt fronts are not drawn with compasses)
func _wavy(c: Vector2, r: float, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 44
	for k in n:
		var a := TAU * k / n
		var rr := r * (1.0 + 0.045 * sin(a * 5.0 + s) + 0.022 * sin(a * 11.0 + s * 2.3))
		pts.append(c + Vector2.from_angle(a) * rr)
	return pts


# corners round off as it goes (melt is fastest where the ice is warmed from two sides)
func _e(tag: String, f: float) -> float:
	return minf(float(_bite[tag].minside) * 0.2, 1.1 * Geom.M) * smoothstep(0.0, 0.55, f)


static func _outer(list: Array) -> Array:
	if list.size() <= 1:
		return list
	var big: PackedVector2Array = list[0]
	for q in list:
		if Geom.area(q) > Geom.area(big):
			big = q
	var cw := Geometry2D.is_polygon_clockwise(big)
	return list.filter(func(q): return Geometry2D.is_polygon_clockwise(q) == cw and q.size() >= 3)


func _cut(tag: String, r: float, e: float) -> Array:
	var b: Dictionary = _bite[tag]
	var parts: Array = [_poly0[tag]]
	if r > 0.5:
		parts = _outer(Geometry2D.clip_polygons(_poly0[tag], _wavy(b.c, r, b.s)))
	if e < 0.5:
		return parts
	var out: Array = []
	for pp in parts:
		for q in _outer(Geometry2D.offset_polygon(pp, -e, Geometry2D.JOIN_ROUND)):
			out.append_array(_outer(Geometry2D.offset_polygon(q, e, Geometry2D.JOIN_ROUND)))
	return out


static func _area(list: Array) -> float:
	var s := 0.0
	for q in list:
		s += Geom.area(q)
	return s


# the pit's radius at table step i: the one that leaves the ice that is left (bisection, once)
func _solve(tag: String, i: int) -> float:
	var f := float(i) / TAB_N * F_CORE
	var target: float = float(_a0[tag]) * (1.0 - f)
	var lo: float = _rtab[tag][i - 1]
	var hi: float = _bite[tag].rmax
	var e := _e(tag, f)
	for k in 15:
		var mid := (lo + hi) * 0.5
		if _area(_cut(tag, mid, e)) > target:
			lo = mid
		else:
			hi = mid
	return hi


func _polys_at(tag: String, f: float) -> Array:
	var fc := minf(f, F_CORE)
	var x := fc / F_CORE * TAB_N
	var i := mini(int(x), TAB_N - 1)
	var tab: Array = _rtab[tag]
	while tab.size() <= i + 1:
		tab.append(_solve(tag, tab.size()))
	var r := lerpf(tab[i], tab[i + 1], x - i)
	var polys := _cut(tag, r, _e(tag, fc))
	if polys.is_empty():
		# nothing of it left at that radius: the core, where its middle was
		var c: Vector2 = _bite[tag].c + _bite[tag].dir * r
		polys = [_wavy(c, sqrt(maxf(1.0, float(_a0[tag]) * (1.0 - fc)) / PI), 1.0)]
	if f > F_CORE:
		# the last of it: the core shrinking to nothing, where it was
		var k := sqrt(maxf(0.0, (1.0 - f) / (1.0 - F_CORE)))
		var cen := Vector2.ZERO
		var aw := 0.0
		for q in polys:
			var a := Geom.area(q)
			cen += Geom.centroid(q) * a
			aw += a
		cen /= maxf(aw, 0.001)
		var out: Array = []
		for q in polys:
			var s := PackedVector2Array()
			for v in q:
				s.append(cen + (v - cen) * k)
			out.append(s)
		polys = out
	return polys


# the block as drawn now: fill triangles, its old (dry) edges and the new wet ones
func _build(tag: String, f: float) -> void:
	var polys := _polys_at(tag, f)
	var poly0: PackedVector2Array = _poly0[tag]
	var b: Dictionary = _bite[tag]
	var d := {"f": f, "polys": polys, "area": _area(polys), "fill": PackedVector2Array(), "cols": PackedColorArray(),
		"idx": PackedInt32Array(), "dry": PackedVector2Array(), "dryc": PackedColorArray(), "wet": PackedVector2Array(),
		"film": PackedVector2Array(), "front": []}
	var fill0 := Color(0.085, 0.108, 0.13)
	var wetfill := Color(0.11, 0.16, 0.17)
	var line0: Color = Pal.ink(0.5).lerp(Pal.tint(LC.of("water"), 0.7), 0.5)
	var bb := Geom.bbox(poly0)
	var cc := bb.get_center()
	var rr := maxf(maxf(bb.size.x, bb.size.y) * 0.5, 1.0)
	for q0 in polys:
		var q: PackedVector2Array = q0
		var tri := Geometry2D.triangulate_polygon(q)
		if tri.is_empty():
			continue
		var n := q.size()
		var wet := PackedByteArray()
		wet.resize(n)
		for i in n:
			wet[i] = 1 if Geom.dist_to_boundary(q[i], poly0) > 1.5 else 0
		var base: int = d.fill.size()
		for i in n:
			var v := q[i]
			var lk := clampf((v - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
			var g := 1.5 + 0.75 * lk if Look.on else 1.0
			var c0 := fill0.lerp(wetfill, 0.85) if wet[i] == 1 else fill0
			d.fill.append(v)
			d.cols.append(Color(c0.r * g, c0.g * g, c0.b * g))
		for k in tri:
			d.idx.append(base + k)
		var inside_cw := Geometry2D.is_polygon_clockwise(q)
		for i in n:
			var a := q[i]
			var c := q[(i + 1) % n]
			if wet[i] == 1 and wet[(i + 1) % n] == 1:
				d.wet.append(a)
				d.wet.append(c)
				# the film of water on it: a second edge just inside
				var nrm := (c - a).orthogonal().normalized()
				if inside_cw:
					nrm = -nrm
				d.film.append(a - nrm * 2.6)
				d.film.append(c - nrm * 2.6)
				d.front.append([(a + c) * 0.5, nrm, a.distance_to(c)])
			else:
				d.dry.append(a)
				d.dry.append(c)
				var ek := clampf(((a + c) * 0.5 - cc).dot(Look.LIGHT_DIR) / rr, -1.0, 1.0)
				var lg := 0.84 + 0.3 * ek if Look.on else 1.0
				d.dryc.append(Color(line0.r * lg, line0.g * lg, line0.b * lg, line0.a))
	_shape[tag] = d
	_area_log[tag] = float(d.area)


# what is drawn of a block (tests): its area in px², -1 when it is not drawn here
func visible_area(tag: String) -> float:
	return float(_area_log.get(tag, -1.0))


# ---------------------------------------------------------------- each frame

func _process(dt: float) -> void:
	if ice == null or not ice.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	var s = game.sys
	if _main.is_empty():
		_find_main()
	# which heaters work, and on what
	_work.clear()
	for h in ice.cfg.get("heaters", {}):
		var e: Dictionary = ice.cfg.heaters[h]
		var hp = world.tag(str(e.get("piece", "")))
		var on: bool = s.on(str(h)) and hp != null and not hp.gone and s.piece_volts(hp) >= 1.0
		if on:
			for b in e.get("blocks", []):
				if ice._ice_piece(b) != null:
					_work[h] = b
					break
		_heat[h] = Pal.damp(float(_heat[h]), 1.0 if on else 0.0, 1.1 if on else 0.6, dt)
	var working := {}
	for h in _work:
		working[_work[h]] = true
	# the blocks going: out of the strips, drawn here
	for tag in ice.melt:
		var f: float = float(ice.melt[tag])
		var p = _piece(tag)
		if p == null:
			if _shape.has(tag) or _ids.has(tag):
				_gone(tag)
			continue
		if f <= 0.0:
			continue
		if not _poly0.has(tag) or hash(p.poly) != int(_sig0[tag]):
			_start(tag, p, 0.0 if not _poly0.has(tag) else f)
		var fl := clampf((f - float(_f0[tag])) / maxf(0.001, 1.0 - float(_f0[tag])), 0.0, 1.0)
		if not _shape.has(tag) or absf(float(_shape[tag].f) - fl) > 0.00001:
			_build(tag, fl)
		if not world.live.has(p.id):
			world.live[p.id] = true
			_ids[tag] = p.id
			world.redraw_near([p])
		_idle[tag] = 0.0 if working.has(tag) else float(_idle.get(tag, 0.0)) + dt
		if working.has(tag):
			_beads(tag, dt)
	_water(dt)
	_crack_fx(dt)
	queue_redraw()
	glow.queue_redraw()


# melted through: the last of its water goes off to the main
func _gone(tag: String) -> void:
	var melted := true
	if _ids.has(tag):
		world.live.erase(_ids[tag])
		var q = world.pieces.get(_ids[tag])
		_ids.erase(tag)
		# freed with the ice still on it (not melted): back to being drawn as any piece is
		if q != null and not q.gone:
			melted = false
			world.redraw_near([q])
	if _shape.has(tag) and melted:
		var d: Dictionary = _shape[tag]
		var c := Vector2.ZERO
		for q in d.polys:
			c += Geom.centroid(q)
		c /= maxf(1.0, d.polys.size())
		_drop(c, 0.006, "run", tag)
		_rings.append([c, 0.0, 0])
	if _pool.has(tag):
		_pool[tag].st = "run"
		_pool[tag].stuck = -1
		_pool.erase(tag)
	for b in drops:
		if b.tag == tag and b.st == "bead":
			b.st = "run"
			b.stuck = -1
	_shape.erase(tag)
	_area_log[tag] = 0.0


func _drop(pos: Vector2, vol: float, st: String, tag: String, nrm := Vector2.ZERO) -> Dictionary:
	var b := {"pos": pos, "vol": vol, "look": "water", "stuck": 0 if nrm != Vector2.ZERO else -1, "nrm": nrm,
		"ice": false, "st": st, "tag": tag, "vel": Vector2.ZERO, "age": 0.0, "ph": _rng.randf() * TAU, "s": 0.0, "acc": 0.0}
	if drops.size() < MAX_BLOBS:
		drops.append(b)
	return b


# meltwater beading on the wet face, running together into the pit's ball
func _beads(tag: String, dt: float) -> void:
	var d: Dictionary = _shape[tag]
	if (d.front as Array).is_empty():
		return
	_emit[tag] = float(_emit.get(tag, 0.0)) + dt * BEAD_RATE
	while float(_emit[tag]) >= 1.0:
		_emit[tag] = float(_emit[tag]) - 1.0
		var fr: Array = d.front[_rng.randi() % d.front.size()]
		var nrm: Vector2 = fr[1]
		_drop(fr[0] + nrm * 1.5, 0.0006, "bead", tag, nrm)


# the pit's ball: where the front's middle is, sitting on it
func _pool_at(tag: String) -> Array:
	var d: Dictionary = _shape[tag]
	var c := Vector2.ZERO
	var n := Vector2.ZERO
	var w := 0.0
	for fr in d.front:
		c += fr[0] * float(fr[2])
		n += fr[1] * float(fr[2])
		w += float(fr[2])
	if w <= 0.0:
		return []
	return [c / w, n.normalized()]


func _water(dt: float) -> void:
	var s = game.sys
	# each pit's ball, fed by its beads
	for tag in _shape:
		var at := _pool_at(tag)
		if at.is_empty():
			continue
		if not _pool.has(tag) and _idle.get(tag, 99.0) < 0.5:
			_pool[tag] = _drop(at[0], 0.0008, "pool", tag, at[1])
		if _pool.has(tag):
			var pb: Dictionary = _pool[tag]
			var r := _rad(pb)
			var want: Vector2 = at[0] + at[1] * r * 0.55
			pb.pos = Pal.damp2(pb.pos, want + Vector2(sin(_t * 2.1 + pb.ph), cos(_t * 1.7 + pb.ph)) * 0.6, 3.0, dt)
			pb.nrm = at[1]
			# big enough, or no longer fed: it goes off to the main
			if float(pb.vol) > POOL_GO or (_idle.get(tag, 0.0) > 2.5 and float(pb.vol) > 0.0012):
				pb.st = "run"
				pb.stuck = -1
				pb.vel = at[1] * 0.4 * Geom.M
				_pool.erase(tag)
	var gone: Array = []
	for b in drops:
		b.age = float(b.age) + dt
		match str(b.st):
			"bead":
				# swelling on the face (staying on it as it melts back), then drawn along it into the ball
				b.vol = float(b.vol) + dt * 0.0018
				var pb = _pool.get(b.tag)
				if _shape.has(b.tag) and (pb == null or float(b.age) <= 0.9):
					var best: Array = []
					var bd := INF
					for fr in _shape[b.tag].front:
						var dd: float = (fr[0] as Vector2).distance_squared_to(b.pos)
						if dd < bd:
							bd = dd
							best = fr
					if not best.is_empty():
						b.nrm = best[1]
						b.pos = Pal.damp2(b.pos, best[0] + (best[1] as Vector2) * _rad(b) * 0.5, 8.0, dt)
				if pb != null and float(b.age) > 0.9:
					var to: Vector2 = pb.pos - b.pos
					var dist := to.length()
					b.pos += to.normalized() * minf(dist, (0.6 + float(b.age)) * Geom.M * dt)
					if dist < (_rad(pb) + _rad(b)) * 0.85:
						pb.vol = float(pb.vol) + float(b.vol)
						gone.append(b)
				elif pb == null and float(b.age) > 1.6:
					b.st = "run"
					b.stuck = -1
			"pool":
				pass
			"run":
				var tgt := _intake(b.pos)
				if tgt.is_empty():
					b.vol = float(b.vol) - dt * 0.004
					if float(b.vol) <= 0.0:
						gone.append(b)
					continue
				var to: Vector2 = tgt[0] - b.pos
				var want := to.normalized() * RUN_SPEED * Geom.M * clampf(to.length() / (1.5 * Geom.M), 0.25, 1.0)
				b.vel = Pal.damp2(b.vel, want, 1.6, dt)
				b.pos += b.vel * dt
				if to.length() < _rad(b) + 4.0:
					b.st = "drain"
					b.s = tgt[1]
					b.stuck = 0
					b.nrm = -to.normalized() if to.length() > 0.1 else Vector2.UP
					b.acc = 0.0
			"drain":
				# into the main: the ball drawn in, a pulse of water off down the pipe for each bit
				var v := minf(float(b.vol), dt * 0.018)
				b.vol = float(b.vol) - v
				b.acc = float(b.acc) + v
				if float(b.acc) > 0.003:
					b.acc = 0.0
					_pulses.append({"s": float(b.s)})
				if float(b.vol) < 0.0003:
					_pulses.append({"s": float(b.s)})
					gone.append(b)
	for b in gone:
		drops.erase(b)
	# the balls near each other run together (not the beads on the face: they are its film)
	for i in drops.size():
		var a: Dictionary = drops[i]
		if a.st != "run":
			continue
		for j in range(i + 1, drops.size()):
			var c: Dictionary = drops[j]
			if c.st != "run" or a.vol <= 0.0 or c.vol <= 0.0:
				continue
			if a.pos.distance_to(c.pos) < (_rad(a) + _rad(c)) * 0.8:
				var tv: float = a.vol + c.vol
				a.pos = (a.pos * a.vol + c.pos * c.vol) / tv
				a.vel = (a.vel * a.vol + c.vel * c.vol) / tv
				a.vol = tv
				c.vol = 0.0
	drops = drops.filter(func(b): return float(b.vol) > 0.0)
	# the water along the main to its pump
	if not _main.is_empty():
		var L: float = (_main[1] as PackedFloat32Array)[(_main[1] as PackedFloat32Array).size() - 1]
		var arrived := 0
		for pu in _pulses:
			pu.s = float(pu.s) + PULSE_SPEED * Geom.M * dt
			if float(pu.s) >= L:
				arrived += 1
		_pulses = _pulses.filter(func(pu): return float(pu.s) < L)
		if arrived > 0:
			_rings.append([_at(L), 0.0, 1])
	# drawn off at the port: rings at the pump while the main empties
	var vol: String = str(ice.cfg.get("volume", ""))
	if s.fvol.has(vol):
		var amt: float = s.fvol[vol].amount
		var was: float = float(get_meta("amt", amt))
		set_meta("amt", amt)
		if amt < was - 0.00001 and not _main.is_empty() and fmod(_t, 0.7) < dt:
			_rings.append([_at((_main[1] as PackedFloat32Array)[(_main[1] as PackedFloat32Array).size() - 1]), 0.0, 1])
	for r in _rings:
		r[1] = float(r[1]) + dt
	_rings = _rings.filter(func(r): return float(r[1]) < 1.1)
	# (no picture without a display: a headless run keeps the globules, not their surface)
	if surface == null and not drops.is_empty() and DisplayServer.get_name() != "headless":
		surface = preload("res://scripts/liquid_surface.gd").new()
		add_child(surface)
		surface.setup(self)
	if surface != null:
		surface.update(drops)


# the water main, as one path running to the pump
func _find_main() -> void:
	var vol: Dictionary = game.sys.fvol.get(str(ice.cfg.get("volume", "")), {})
	var pump = world.tag(str(vol.get("piece", "")))
	var nets: Array = vol.get("nets", [])
	for id in world.lines:
		var l = world.lines[id]
		if not l.alive or not nets.has(l.net) or l.path.size() < 2:
			continue
		var path: PackedVector2Array = l.path
		if pump != null and l.a == pump.id:
			path = path.duplicate()
			path.reverse()
		var cum := PackedFloat32Array([0.0])
		for i in range(1, path.size()):
			cum.append(cum[i - 1] + path[i - 1].distance_to(path[i]))
		if _main.is_empty() or cum[cum.size() - 1] > (_main[1] as PackedFloat32Array)[(_main[1] as PackedFloat32Array).size() - 1]:
			_main = [path, cum]


func _at(s: float) -> Vector2:
	var path: PackedVector2Array = _main[0]
	var cum: PackedFloat32Array = _main[1]
	for i in range(1, path.size()):
		if s <= cum[i]:
			var seg := maxf(0.001, cum[i] - cum[i - 1])
			return path[i - 1].lerp(path[i], (s - cum[i - 1]) / seg)
	return path[path.size() - 1]


# the main's nearest point to a ball, and how far along the main it is
func _intake(pos: Vector2) -> Array:
	if _main.is_empty():
		return []
	var path: PackedVector2Array = _main[0]
	var cum: PackedFloat32Array = _main[1]
	var best := []
	var bd := INF
	for i in range(1, path.size()):
		var q := Geometry2D.get_closest_point_to_segment(pos, path[i - 1], path[i])
		var dd := q.distance_squared_to(pos)
		if dd < bd:
			bd = dd
			best = [q, cum[i - 1] + path[i - 1].distance_to(q)]
	return best


# ---------------------------------------------------------------- the crack

func _build_crack() -> void:
	var pts: Array = []
	for t in _crack_tags:
		var p = world.tag(str(t))
		if p != null:
			pts.append(Geom.centroid(p.poly))
	if pts.size() < 2:
		return
	# one run across the saddle, first block to last, through the middle of the ones between
	if pts.size() > 2:
		var mid := Vector2.ZERO
		for i in range(1, pts.size() - 1):
			mid += pts[i]
		pts = [pts[0], mid / (pts.size() - 2), pts[pts.size() - 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# from beyond the first block to beyond the last, jagged
	var a0: Vector2 = pts[0] + (pts[0] - pts[1]).normalized() * 6.0 * Geom.M
	var a1: Vector2 = pts[pts.size() - 1] + (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * 6.0 * Geom.M
	pts.insert(0, a0)
	pts.append(a1)
	var line := PackedVector2Array()
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var n := maxi(2, int(a.distance_to(b) / (0.7 * Geom.M)))
		var nrm := (b - a).orthogonal().normalized()
		for k in n:
			var u := float(k) / n
			line.append(a.lerp(b, u) + nrm * rng.randf_range(-0.28, 0.28) * Geom.M * sin(u * PI + 0.3))
	line.append(pts[pts.size() - 1])
	var s := 0.0
	for i in range(1, line.size()):
		var l := line[i - 1].distance_to(line[i])
		_crack.append([line[i - 1], line[i], s, false])
		s += l
	_crack_len = s
	# branches off it
	for k in 9:
		var i := rng.randi_range(2, line.size() - 3)
		var at := line[i]
		var dir := (line[i + 1] - line[i - 1]).normalized().rotated(rng.randf_range(0.5, 1.1) * (1.0 if k % 2 == 0 else -1.0))
		var bs: float = _crack[i][2]
		var cur := at
		for m in rng.randi_range(2, 5):
			var nx := cur + dir.rotated(rng.randf_range(-0.4, 0.4)) * rng.randf_range(0.4, 0.8) * Geom.M
			_crack.append([cur, nx, bs + m * 0.6 * Geom.M, true])
			cur = nx


func _crack_fx(dt: float) -> void:
	if _crack.is_empty() and not _crack_tags.is_empty():
		_build_crack()
	if ice.split and not _was_split:
		_split_t = 0.0
		for k in 22:
			var seg: Array = _crack[_rng.randi() % maxi(1, _crack.size())] if not _crack.is_empty() else [Vector2.ZERO, Vector2.ZERO]
			var at: Vector2 = (seg[0] as Vector2).lerp(seg[1], _rng.randf())
			_shards.append([at, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.6, 2.4) * Geom.M, _rng.randf() * TAU, 0.0])
	_was_split = ice.split
	if _split_t >= 0.0:
		_split_t += dt
	for sh in _shards:
		sh[0] = (sh[0] as Vector2) + (sh[1] as Vector2) * dt
		sh[2] = float(sh[2]) + dt * 3.0
		sh[3] = float(sh[3]) + dt
	_shards = _shards.filter(func(sh): return float(sh[3]) < 1.8)


# is this point of the crack in ice that is still there (as drawn)?
func _in_ice(at: Vector2) -> bool:
	for t in _crack_tags:
		var p = _piece(str(t))
		if p == null:
			continue
		if _shape.has(t):
			for q in _shape[t].polys:
				if Geometry2D.is_point_in_polygon(at, q):
					return true
		elif Geometry2D.is_point_in_polygon(at, p.poly):
			return true
	return false


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if ice == null or not ice.active():
		return
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	var fi := PackedInt32Array()
	var dry := PackedVector2Array()
	var dryc := PackedColorArray()
	var wet := PackedVector2Array()
	var film := PackedVector2Array()
	for tag in _shape:
		var d: Dictionary = _shape[tag]
		var base := fp.size()
		fp.append_array(d.fill)
		fc.append_array(d.cols)
		for k in d.idx:
			fi.append(base + k)
		dry.append_array(d.dry)
		dryc.append_array(d.dryc)
		wet.append_array(d.wet)
		film.append_array(d.film)
	if not fi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), fi, fp, fc)
	if not dry.is_empty():
		draw_multiline_colors(dry, dryc, 1.1 if Look.on else 1.3)
	if not film.is_empty():
		draw_multiline(film, Pal.tint(LC.of("water"), 0.22, 1.1), 1.0)
	if not wet.is_empty():
		draw_multiline(wet, Pal.tint(LC.of("water"), 0.62 + 0.12 * sin(_t * 3.1), 1.25), 1.4)
	_draw_crack()


func _draw_crack() -> void:
	if _crack.is_empty():
		return
	var st: float = ice.strain()
	var k := clampf((st - 20.0) / 70.0, 0.0, 1.0)
	var show := _crack_len * (0.3 + 0.7 * k)
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	var gap := PackedVector2Array()
	for c in _crack:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		if not ice.split and (float(c[2]) > show or (c[3] and k < 0.5)):
			continue
		if not _in_ice((a + b) * 0.5):
			continue
		if ice.split and not c[3]:
			# run: open, its two faces apart
			var n := (b - a).orthogonal().normalized() * 1.8
			gap.append_array(PackedVector2Array([a + n, b + n, a - n, b - n]))
			continue
		var al := (0.16 + 0.34 * k) * (0.6 if c[3] else 1.0)
		segs.append(a)
		segs.append(b)
		cols.append(Pal.ink(al).lerp(Pal.tint(Pal.AIR, al), 0.35))
	if not segs.is_empty():
		draw_multiline_colors(segs, cols, 1.0)
	if not gap.is_empty():
		for i in range(0, gap.size(), 4):
			draw_colored_polygon(PackedVector2Array([gap[i], gap[i + 1], gap[i + 3], gap[i + 2]]), Color(0.02, 0.025, 0.03))
		draw_multiline(gap, Pal.ink(0.62), 1.0)


func _draw_glow() -> void:
	if ice == null or not ice.active():
		return
	var tv := PackedVector2Array()
	var tc := PackedColorArray()
	var ti := PackedInt32Array()
	var lines := PackedVector2Array()
	var lcols := PackedColorArray()
	# heaters working: the pad's glow, its coil lit, heat rippling over to the face it melts
	for h in _heat:
		var k: float = _heat[h]
		if k < 0.01:
			continue
		var hp = world.tag(str(ice.cfg.heaters[h].get("piece", "")))
		if hp == null or hp.gone:
			continue
		var poly: PackedVector2Array = world.world_poly(hp)
		var hc := Geom.centroid(poly)
		var flick := 0.88 + 0.12 * sin(_t * 9.0 + hc.x) * sin(_t * 5.3)
		_fan(tv, tc, ti, hc, (1.2 + 0.5 * k) * Geom.M, Pal.heat(0.30 * k * flick, 1.0))
		_fan(tv, tc, ti, hc, 0.45 * Geom.M, Pal.heat(0.42 * k * flick, 1.3))
		var bb := Geom.bbox(poly)
		var zz := PackedVector2Array()
		for i in 9:
			var u := float(i) / 8.0
			zz.append(Vector2(lerpf(bb.position.x + 2.0, bb.end.x - 2.0, u), bb.position.y + bb.size.y * (0.3 if i % 2 == 0 else 0.7)))
		for i in range(1, zz.size()):
			lines.append(zz[i - 1])
			lines.append(zz[i])
			lcols.append(Pal.heat(0.9 * k * flick, 1.4))
		# the heat going out of it: ripples off the pad
		for w in 2:
			var u := fposmod(_t * 0.7 + w * 0.5, 1.0)
			_ring_lines(lines, lcols, hc, (0.35 + 1.1 * u) * Geom.M, Pal.heat(0.28 * k * (1.0 - u) * smoothstep(0.0, 0.15, u), 1.1))
		# and over to the face it is melting: warmth running along its lead to it
		var tag: String = _work.get(h, "")
		if tag != "" and _shape.has(tag):
			var at := _pool_at(tag)
			if not at.is_empty():
				var to: Vector2 = at[0] - hc
				var dist := to.length()
				var dir := to / maxf(dist, 1.0)
				var off := fposmod(_t * 70.0, 26.0)
				var x := off
				while x < dist:
					var e := minf(x + 11.0, dist)
					var fade := smoothstep(0.0, 40.0, x) * smoothstep(0.0, 40.0, dist - x)
					lines.append(hc + dir * x)
					lines.append(hc + dir * e)
					lcols.append(Pal.heat(0.3 * k * fade, 1.1))
					x += 26.0
	# the wet faces warmed and glinting
	for tag in _shape:
		var d: Dictionary = _shape[tag]
		var warm := 0.0
		for h in _work:
			if _work[h] == tag:
				warm = float(_heat[h])
		var fr: Array = d.front
		if fr.is_empty():
			continue
		if warm > 0.01:
			var w := d.wet as PackedVector2Array
			for i in range(0, w.size(), 2):
				lines.append(w[i])
				lines.append(w[i + 1])
				lcols.append(Pal.heat(0.16 * warm, 1.0))
		for g in 4:
			var u := fposmod(_t * 0.07 + g * 0.27 + float(hash(tag) % 100) * 0.01, 1.0)
			var it: Array = fr[int(u * fr.size()) % fr.size()]
			var a := 0.5 + 0.5 * sin(_t * 4.0 + g * 1.9)
			var c: Vector2 = it[0] + (it[1] as Vector2) * 1.0
			var sz := 2.0 + 2.5 * a
			var col := Pal.ink(0.55 * a * a)
			lines.append_array(PackedVector2Array([c - Vector2(sz, 0), c + Vector2(sz, 0), c - Vector2(0, sz), c + Vector2(0, sz)]))
			lcols.append_array(PackedColorArray([col, col]))
	# the water in the main, and the pulses of it running to the pump
	var vol: String = str(ice.cfg.get("volume", ""))
	if not _main.is_empty() and game.sys.fvol.has(vol):
		var fv: Dictionary = game.sys.fvol[vol]
		var fill := clampf(float(fv.amount) / maxf(0.1, float(fv.get("full", 20.0))) * 8.0, 0.0, 1.0)
		var path: PackedVector2Array = _main[0]
		if fill > 0.002:
			for i in range(1, path.size()):
				lines.append(path[i - 1])
				lines.append(path[i])
				lcols.append(Pal.tint(LC.of("water"), 0.14 + 0.3 * fill, 1.0))
		for pu in _pulses:
			var s: float = pu.s
			for m in 8:
				var a := _at(maxf(0.0, s - m * 7.0))
				var b := _at(maxf(0.0, s - (m + 1) * 7.0))
				lines.append(a)
				lines.append(b)
				lcols.append(Pal.tint(LC.of("water"), 1.0 * (1.0 - m / 8.0), 1.5))
			_fan(tv, tc, ti, _at(s), 9.0, Pal.tint(LC.of("water"), 0.5, 1.3))
	for r in _rings:
		var u: float = float(r[1]) / 1.1
		var rad := (0.3 + (1.2 if int(r[2]) == 1 else 0.8) * Pal.ease_out(u)) * Geom.M
		var prev: Vector2 = r[0] + Vector2(rad, 0)
		for m in range(1, 21):
			var q: Vector2 = r[0] + Vector2.from_angle(TAU * m / 20.0) * rad
			lines.append(prev)
			lines.append(q)
			lcols.append(Pal.tint(LC.of("water"), 0.5 * (1.0 - u), 1.2))
			prev = q
	# the crack under strain: now and then a creak runs along it
	if not _crack.is_empty() and not ice.split:
		var k := clampf((ice.strain() - 20.0) / 70.0, 0.0, 1.0)
		var u := fposmod(_t / 3.6, 1.0)
		if k > 0.55 and u < 0.3:
			var at := _crack_len * u / 0.3
			for c in _crack:
				if c[3] or absf(float(c[2]) - at) > 1.2 * Geom.M or not _in_ice((c[0] + c[1]) * 0.5):
					continue
				lines.append(c[0])
				lines.append(c[1])
				lcols.append(Pal.tint(Pal.AIR, 0.5 * k * (1.0 - absf(float(c[2]) - at) / (1.2 * Geom.M)), 1.2))
	# the crack running: a flash along it, chips of ice thrown off
	if _split_t >= 0.0 and _split_t < 1.2:
		var a := 1.0 - _split_t / 1.2
		for c in _crack:
			if not c[3] and _in_ice((c[0] + c[1]) * 0.5):
				lines.append(c[0])
				lines.append(c[1])
				lcols.append(Pal.tint(Pal.AIR, 0.9 * a, 1.5))
	for sh in _shards:
		var a := 1.0 - float(sh[3]) / 1.8
		var c: Vector2 = sh[0]
		var d := Vector2.from_angle(float(sh[2])) * 5.0
		var e := d.orthogonal() * 0.5
		lines.append_array(PackedVector2Array([c - d, c + e, c + e, c + d, c + d, c - e, c - e, c - d]))
		for m in 4:
			lcols.append(Pal.ink(0.7 * a))
	if not ti.is_empty():
		RenderingServer.canvas_item_add_triangle_array(glow.get_canvas_item(), ti, tv, tc)
	if not lines.is_empty():
		glow.draw_multiline_colors(lines, lcols, 1.2)


static func _ring_lines(lines: PackedVector2Array, cols: PackedColorArray, c: Vector2, r: float, col: Color) -> void:
	var n := 28
	var prev := c + Vector2(r, 0)
	for m in range(1, n + 1):
		var q := c + Vector2.from_angle(TAU * m / n) * r
		lines.append(prev)
		lines.append(q)
		cols.append(col)
		prev = q


# a soft disc of light: bright at the middle, nothing at its edge
static func _fan(tv: PackedVector2Array, tc: PackedColorArray, ti: PackedInt32Array, c: Vector2, r: float, col: Color) -> void:
	var base := tv.size()
	tv.append(c)
	tc.append(col)
	var n := 20
	for k in n:
		tv.append(c + Vector2.from_angle(TAU * k / n) * r)
		tc.append(Color(col.r, col.g, col.b, 0.0))
	for k in n:
		ti.append_array([base, base + 1 + k, base + 1 + (k + 1) % n])
