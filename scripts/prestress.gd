extends Node2D
# Beams that carry a load (the codex, cx_frame_b: "cut them straight through and the
# equipment and structure they held may suddenly move, even spring apart, twist or
# break"). User 2026-11-10 (用户定案 9): on a few ships with a real preload or load, done
# with the best animation we can make. DR-150's derrick legs (they carry the crown block and
# the string: compression), IC-120's saddle beams (they carry the ice: bending), OB-90's
# preloaded struts (they hold the telescope tube in tension).
# A ship file's "prestress": {"beams": {tag: {"kn": load, "mode": "compression"|"bend"|
#   "tension"}}, "reach": m round the beam its whip can hit}.
#
# A loaded beam cut through lets its strain energy go at once, U = F·L·ε/2 (ε 0.2 %, steel
# near its working stress). What happens to each part:
#   still fixed at one end: it whips round that end and stays bent there (world.displace:
#     a permanent kink of a few degrees, its joints and lines moved with it); a bending
#     member droops, a compression member kicks sideways and kinks, a tension member snaps
#     back toward its anchor;
#   free: it is thrown, away from the cut, spinning (recoil.gd keeps it dangerous).
# What its whip sweeps is hit: equipment within reach dented (capped), the drone hurt.
# Drawn: the snap at the cut (a white flash, sparks off both faces, a shock ring, flakes of
# scale), then each part ringing like a struck bar, its first bending mode decaying over a
# second and a half (motion trails at the fast part), the kink at the root glowing with the
# heat of yielding steel and cooling; dust shaken off along the whole beam.

const EPS := 0.002             # strain at the beam's working load
const KINK_MAX := 0.14         # rad: the most a part stays bent
const RING_T := 1.6            # s the ringing lasts
const RING_HZ := 7.5
const RING_A := 0.45           # m: the ringing's first swing at the free end, at full energy
const HURT := 30.0
const DENT_MAX := 0.25

var game
var world
var cfg := {}
var rings: Array = []          # {p, root (local), tip (local), side (local unit), a, t, kink_t}
var snaps: Array = []          # {at, n, t}
var _done := {}                # beam tag -> true once released


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("prestress", {})
	z_index = 35


func active() -> bool:
	return not cfg.is_empty()


func beam_cfg(p) -> Dictionary:
	if p == null:
		return {}
	var tag: String = p.tag if p.tag != "" else str(p.get_meta("origin", ""))
	return cfg.get("beams", {}).get(tag, {})


# a kerf went through p (game.gd cut_kerf, after the cut is made)
func on_cut(p, pl: PackedVector2Array, res: Dictionary) -> void:
	if not active() or int(res.get("split", 1)) < 2:
		return
	var bc := beam_cfg(p)
	var tag: String = p.tag
	if bc.is_empty() or _done.has(tag):
		return
	_done[tag] = true
	var parts: Array = [p]
	for q in res.get("new", []):
		if q != null and not q.gone and not parts.has(q):
			parts.append(q)
	var cut_at: Vector2 = (pl[0] + pl[pl.size() - 1]) * 0.5
	var mode: String = str(bc.get("mode", "bend"))
	var kn: float = float(bc.get("kn", 300.0))
	# the beam's length, along its long axis, from all its parts
	var bb := Rect2()
	for q in parts:
		var qb := Geom.bbox(world.world_poly(q))
		bb = qb if bb.size == Vector2.ZERO else bb.merge(qb)
	var axis := Vector2(1, 0) if bb.size.x >= bb.size.y else Vector2(0, 1)
	var length: float = maxf(bb.size.x, bb.size.y) / Geom.M
	var energy: float = kn * 1000.0 * length * EPS * 0.5
	var k: float = clampf(energy / 6000.0, 0.35, 1.0)
	game.incident("beam_snap", tag)
	game.say("beam_snap_" + mode, cut_at, tag)
	_snap(cut_at, axis, k)
	for q in parts:
		_release(q, cut_at, axis, mode, energy / parts.size(), k)
	# what the whip sweeps
	var reach: float = float(cfg.get("reach", 3.0)) * Geom.M * (0.6 + 0.4 * k)
	var lost := 0.0
	for e in game._equip_near(cut_at, reach):
		if parts.has(e):
			continue
		var before: float = e.cond
		game._dent(e, maxf(0.0, e.cond - minf(DENT_MAX, e.fragile * 0.6 * k)), "dv_beam_snap")
		lost += (before - e.cond) * e.value
	if lost > 100.0:
		game.fx.number(cut_at + Vector2(0, -40), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
	var dr = game.drone
	if dr.alive and dr.global_position.distance_to(cut_at) < reach:
		game.hurt_drone(HURT * k, cut_at, "beam_hit", "beam_snap", 0.5)
		dr.linear_velocity += (dr.global_position - cut_at).normalized() * 300.0 * k


func _release(q, cut_at: Vector2, axis: Vector2, mode: String, energy: float, k: float) -> void:
	var anchors: Array = []
	for j in world.joints_of(q):
		if j.alive:
			anchors.append(world.joint_world(j))
	var qc: Vector2 = world.frame(q) * Geom.centroid(q.poly)
	# along the beam, from the cut out to this part
	var out: Vector2 = axis * signf((qc - cut_at).dot(axis))
	if out == Vector2.ZERO:
		out = axis
	var side: Vector2 = axis.orthogonal()
	if anchors.is_empty():
		# free: thrown off the cut, spinning
		var m_kg: float = maxf(float(q.mass) * 1000.0, 50.0)
		var v: float = minf(sqrt(2.0 * energy / m_kg) * 2.0, 15.0)
		var dir: Vector2 = (out + side * randf_range(-0.4, 0.4)).normalized()
		_after_body(q, dir * v * Geom.M, randf_range(-3.0, 3.0) * k)
		return
	# fixed at its far end: the root is the anchor furthest from the cut
	var root: Vector2 = anchors[0]
	for a in anchors:
		if (a - cut_at).dot(out) > (root - cut_at).dot(out):
			root = a
	var sgn: float = 1.0 if randf() < 0.5 else -1.0
	var ang: float
	match mode:
		"bend":
			# the load it carried pulls the free end down (toward +y in the ship's frame)
			ang = KINK_MAX * k * signf(out.cross(Vector2.DOWN))
			if absf(ang) < 0.01:
				ang = KINK_MAX * k * sgn
		"compression":
			ang = KINK_MAX * 0.8 * k * sgn
		_:
			ang = KINK_MAX * 0.4 * k * sgn
	var xf := Transform2D(ang, Vector2.ZERO)
	xf = Transform2D(0.0, root) * xf * Transform2D(0.0, -root)
	world.displace(q, xf)
	var inv: Transform2D = world.frame(q).affine_inverse()
	var tip_w: Vector2 = root
	for v in world.world_poly(q):
		if (v - root).length() > (tip_w - root).length():
			tip_w = v
	rings.append({"p": q, "root": inv * root, "tip": inv * tip_w, "a": RING_A * k * (1.4 if mode == "bend" else 1.0), "t": 0.0, "mode": mode, "sgn": signf(ang) if ang != 0.0 else 1.0})


# a part about to come loose: its kick once it is a body
func _after_body(q, v: Vector2, w: float) -> void:
	snaps.append({"body_of": q, "v": v, "w": w, "t": 0.0})


func _snap(at: Vector2, axis: Vector2, k: float) -> void:
	snaps.append({"at": at, "axis": axis, "k": k, "t": 0.0})
	game.fx.flash(at, 50.0 + 40.0 * k, 0.2, Pal.ink(0.8, 1.8))
	game.fx.ring(at, 6.0, (1.5 + 2.5 * k) * Geom.M, 0.5, Pal.ink(0.8, 1.6), 3.0)
	for i in int(24 + 30 * k):
		var d: Vector2 = (axis * (1.0 if i % 2 == 0 else -1.0)).rotated(randf_range(-1.1, 1.1))
		game.fx.spark(at, d * randf_range(300, 900) * (0.6 + 0.4 * k), randf_range(0.25, 0.6), Pal.heat(1.0, 2.4), 1.5, 12.0, 1.0)
	game.fx.burst_shards(at, int(8 + 12 * k), 380.0 * (0.6 + 0.4 * k), Pal.ink(0.8), 6.0)
	game.sfx.play("crack", at, 1.0, 0.65)
	game.sfx.play("clank", at, 1.0, 0.5)
	game.shake(0.35 + 0.45 * k, axis.orthogonal())
	game.hitstop(0.04 + 0.04 * k)


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.state != "play" or game.paused_sim:
		return
	var keep: Array = []
	for s in snaps:
		s.t = float(s.t) + dt
		if s.has("body_of"):
			var q = s.body_of
			if q.gone:
				continue
			if q.body == null:
				if s.t < 0.6:
					keep.append(s)
				continue
			q.body.calm = 0.0
			q.body.settle = 0.0
			q.body.linear_velocity += s.v
			q.body.angular_velocity += float(s.w)
			if game.recoil != null:
				game.recoil._fly(q.body)
			continue
		if s.t < 0.6:
			keep.append(s)
	snaps = keep
	var keep_r: Array = []
	for r in rings:
		r.t = float(r.t) + dt
		var q = r.p
		if q.gone or r.t > RING_T:
			continue
		keep_r.append(r)
		# dust shaken off along it while it rings hard
		if r.t < 0.5 and randf() < 0.35:
			var root: Vector2 = world.frame(q) * (r.root as Vector2)
			var tip: Vector2 = world.frame(q) * (r.tip as Vector2)
			var at: Vector2 = root.lerp(tip, randf())
			game.fx.puff(at, Vector2(randf_range(-30, 30), randf_range(-30, 30)), randf_range(0.6, 1.2), 3.0, 14.0, Pal.ink(0.06))
	rings = keep_r
	if not rings.is_empty() or not snaps.is_empty():
		queue_redraw()
	elif _drawn:
		_drawn = false
		queue_redraw()


var _drawn := false


# the part's centreline swung by its first bending mode (a cantilever's, about (x/L)²)
func _line(q, r: Dictionary, phase: float) -> PackedVector2Array:
	var xf: Transform2D = world.frame(q)
	var root: Vector2 = xf * (r.root as Vector2)
	var tip: Vector2 = xf * (r.tip as Vector2)
	var n: Vector2 = (tip - root).orthogonal().normalized()
	var amp: float = float(r.a) * Geom.M * exp(-float(r.t) / 0.45) * cos(TAU * RING_HZ * float(r.t) + phase)
	var pts := PackedVector2Array()
	for i in 13:
		var x: float = i / 12.0
		pts.append(root.lerp(tip, x) + n * amp * x * x * float(r.sgn))
	return pts


func _draw() -> void:
	_drawn = true
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	for r in rings:
		var q = r.p
		if q.gone:
			continue
		var t: float = r.t
		var fade: float = clampf(1.0 - t / RING_T, 0.0, 1.0)
		# trails: where it was a moment ago, fainter
		for k in [3, 2, 1]:
			var pts := _line(q, r, -k * 0.55)
			draw_polyline(pts, Pal.ink(0.12 * fade / k), 5.0, true)
		var now := _line(q, r, 0.0)
		draw_polyline(now, Pal.heat(0.35 + 0.5 * fade, 1.0 + 1.2 * fade), 2.4, true)
		draw_polyline(now, Pal.ink(0.9 * fade, 1.5), 1.0, true)
		# the kink at the root: steel that has just yielded, glowing and cooling
		var root: Vector2 = world.frame(q) * (r.root as Vector2)
		var heat: float = clampf(1.0 - t / 1.2, 0.0, 1.0)
		if tex != null and heat > 0.0:
			var rr: float = 26.0 + 10.0 * heat
			draw_texture_rect(tex, Rect2(root - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Pal.heat(0.55 * heat, 2.0))
		for i in 3:
			var a: float = float(i) * 0.9 + float(r.sgn)
			draw_line(root + Vector2.from_angle(a) * 4.0, root + Vector2.from_angle(a) * (12.0 + 6.0 * heat), Pal.heat(0.6 * heat, 2.0), 1.2, true)
	for s in snaps:
		if not s.has("at"):
			continue
		var t2: float = s.t
		var at: Vector2 = s.at
		var axis: Vector2 = s.axis
		var a2: float = clampf(1.0 - t2 / 0.6, 0.0, 1.0)
		# the two faces of the break, white-hot, pulling apart
		var gap: float = (6.0 + 30.0 * float(s.k)) * (1.0 - a2 * a2)
		var side: Vector2 = axis.orthogonal() * 14.0
		for sg in [-1.0, 1.0]:
			var c: Vector2 = at + axis * gap * sg
			draw_line(c - side, c + side, Pal.heat(a2, 2.6), 3.0, true)
		if tex != null:
			draw_texture_rect(tex, Rect2(at - Vector2(22, 22), Vector2(44, 44)), false, Pal.heat(0.5 * a2, 2.0))
