extends Node
# Recoil (反推, user 2026-11-10: "我觉得都有加反推机制，尽量和图鉴对标"): a container that
# opens under pressure is pushed back by what it throws out. The book says so of bottles
# (cx_gastank_b/x: a valve knocked off, the bottle flies like a rocket), of tanks under an
# ullage (cx_s_ullage_b), of accumulators (cx_hpu_b) and fire bottles (cx_extinguisher_b).
#
# Openings (each a "jet" on its piece, in the piece's own frame so it turns with it):
#   neck   the valve sheared off: a charged bottle yanked off its locks by the grapple, or
#          knocked hard (a crash, a bottle flying into it). 25 mm, a sheared neck's bore.
#   fit    a hose or fitting torn off a charged vessel with the piece (the grapple tearing
#          it loose). 16 mm. Not if the vessel's own valves are all shut (先关阀).
#   hole   a kerf into a vessel charged below its burst pressure (above it, it bursts as
#          before, game.gd _burst): the hole grows with the kerf.
# Liquid tanks that leak through a hole (systems.gd _hole_flow) are pushed back by the
# liquid's momentum, ρ·Q·v; a hose torn off a liquid tank whose valve is open opens such a
# hole at the fitting.
#
# Physics. A gas jet from a vessel at p into vacuum is choked: its thrust is F = C_F·Δp·A
# with C_F ≈ 1.27 (γ = 1.4, a sonic exit). The vessel empties as n·exp(−K·A·t/V) (K as in
# systems.gd, about √(γRT) of air): a 50 L bottle at 200 bar through 25 mm is down in a few
# seconds. Thrust follows the pressure down. A real bottle would reach tens of metres a
# second; nothing loose goes faster than FreeBody.MAX_SPEED (18.75 m/s) in the berth.
# Prevention is what the book says: vent it first (no pressure, no jet), shut the valve.

const CF := 1.27               # thrust coefficient of a choked jet into vacuum
const K_FLOW := 160.0          # 1/m: as systems.gd _hole_flow, n·exp(−K·A·dt/V)
const N_TO_GAME := 0.048       # N → t·px/s² (masses in tonnes, 48 px a metre)
const NECK_A := 4.9e-4         # m²: a sheared cylinder neck, 25 mm
const FIT_A := 2.0e-4          # m²: a torn hose or fitting, 16 mm
const KERF_W := 0.004          # m: a laser kerf through a wall (game.gd KERF_W)
const MIN_KPA := 25.0          # below this over what is outside, the jet is a hiss: done
const SHEAR_KPA := 300.0       # a yank or a knock shears the valve only of a charged bottle
const SHEAR_DV := 4.0 * Geom.M # px/s: the knock that takes a valve off
const KNOCK_R := 0.9 * Geom.M  # a body hitting this close to a charged bottle's neck
const FLY_T := 6.0             # s a launched body stays dangerous to what it hits
const HIT_V := 4.0 * Geom.M    # px/s: flying faster than this, it hurts the drone it meets

const DOOR_KPA := 20.0          # a door cut with less than this across it just comes apart
const DOOR_DEPTH := 1.0        # m: a door's height out of the drawing (2 m wide → 2 m²)
const DOOR_T := 0.08           # s the full difference pushes before the opening equalises it

var game
var _doors: Array = []         # doors cut free under pressure, waiting to be bodies: {parts, dir, dv, t}
var jets: Array = []           # {piece, vol, local, ldir, area, kind, t, acc, gas, f}
var flying := {}               # body instance id -> {body, t}
var _drone_cd := 0.0
var _prev_v := {}               # body instance id -> its velocity a step ago (_knocks)


func setup(g) -> void:
	game = g


func _sys():
	return game.sys


# ---------------------------------------------------------------- openings

# the valve end of a bottle, in its own frame: the end of its long axis its port is on
# (the top, or the right, when the port is in the middle)
func neck_of(p) -> Array:
	var bb := Geom.bbox(p.poly)
	var c := bb.get_center()
	var tall: bool = bb.size.y >= bb.size.x
	var axis := Vector2(0, -1) if tall else Vector2(1, 0)
	var port = null
	var vol: String = _sys().tank_vol(p)
	for id in game.world.ctrls:
		var ct = game.world.ctrls[id]
		if ct.kind == "port" and str(ct.target) == vol and game.world.pieces.get(ct.piece) == p:
			port = ct
			break
	if port != null:
		var off: Vector2 = port.pos - c
		var along: float = off.dot(axis)
		if absf(along) > 0.25 * maxf(bb.size.x, bb.size.y) * 0.5 and along < 0.0:
			axis = -axis
	var half: float = (bb.size.y if tall else bb.size.x) * 0.5
	return [c + axis * half, axis]


func _jet_of(p, kind: String):
	for j in jets:
		if j.piece == p and j.kind == kind:
			return j
	return null


# open a gas jet on piece p from its vessel vol (local: where, ldir: which way it blows)
func open(p, vol: String, local: Vector2, ldir: Vector2, area: float, kind: String) -> Dictionary:
	var s = _sys()
	var old = _jet_of(p, kind)
	if old != null:
		old.area = maxf(float(old.area), area)
		return old
	var gas: String = str(s.vessel_cfg.get(vol, {}).get("gas", ""))
	# a real jet is never quite on the axis: the bottle tumbles as it goes
	var d := ldir.normalized().rotated(randf_range(-0.06, 0.06))
	# a piece that comes loose is re-centred on its body: _local moves the point with it
	var j := {"piece": p, "vol": vol, "local": local, "cen0": Geom.centroid(p.poly), "body0": p.body, "ldir": d, "area": area, "kind": kind, "t": 0.0, "acc": 0.0, "gas": gas, "f": 0.0}
	jets.append(j)
	var at: Vector2 = game.world.frame(p) * local
	var wdir: Vector2 = game.world.frame(p).basis_xform(d).normalized()
	game.incident("recoil", "%s %s %.0f kPa" % [p.tag, kind, s.P(vol)])
	# the crack of it letting go, then the roar
	game.fx.flash(at, 120.0, 0.3, Pal.tint(Pal.AIR, 0.8, 1.8))
	for i in 18:
		game.fx.spark(at, wdir.rotated(randf_range(-0.25, 0.25)) * randf_range(500, 1000), randf_range(0.2, 0.45), Pal.tint(Pal.AIR, 0.8, 1.6), 1.2, 10.0, 1.4)
	game.fx.burst_shards(at, 6, 300.0, Pal.ink(0.8), 5.0)
	game.sfx.play("burst" if kind == "neck" else "hiss", at, 0.8 if kind == "neck" else 1.0)
	game.shake(0.3 if kind == "neck" else 0.12, wdir)
	if kind == "neck":
		game.hitstop(0.05)
	if p.body != null:
		_fly(p.body)
	return j


# the grapple tore p loose (game.gd on_tear): a charged bottle's valve or fitting goes with it
func on_tear(p, lines_held: Array, _at: Vector2) -> void:
	var s = _sys()
	var vol: String = s.tank_vol(p)
	if vol != "" and s.P(vol) > SHEAR_KPA:
		var pipe = null
		for l in lines_held:
			if l.kind == "pipe":
				pipe = l
				break
		if pipe != null:
			if not _valves_shut(vol):
				var at: Vector2 = game.world.line_end_world(pipe, 0 if pipe.a == p.id else 1)
				var loc: Vector2 = game.world.frame(p).affine_inverse() * at
				open(p, vol, loc, loc - Geom.centroid(p.poly), FIT_A, "fit")
		else:
			var nk: Array = neck_of(p)
			open(p, vol, nk[0], nk[1], NECK_A, "neck")
		# a magnetic grapple does not hold a kick of kilonewtons
		if game.tools.held_piece == p and _thrust_n(_jet_of(p, "neck") if _jet_of(p, "neck") != null else _jet_of(p, "fit")) > 2000.0:
			game.tools.release_grab(false)
	# a hose torn off a liquid tank whose valve is open: the tank empties through the fitting
	var fv: String = s.fluid_in_piece(p)
	if fv != "" and s.fluid(fv) > 0.02:
		for l in lines_held:
			if l.kind != "pipe" or not _line_open_to(l, fv):
				continue
			var at2: Vector2 = game.world.line_end_world(l, 0 if l.a == p.id else 1)
			game._leak(s.fvol[fv].fluid, fv, at2, p)
			var lk: Dictionary = s.leaks.back()
			lk.area = FIT_A
			lk.ullage = vol
			break


# a hole cut into a vessel charged below its burst pressure (game.gd on_cut_into)
func on_cut(p, at: Vector2) -> void:
	var s = _sys()
	var vol: String = s.tank_vol(p)
	if vol == "" or s.bursts(p):
		return
	if s.P(vol) - _outside(at) < MIN_KPA:
		return
	var loc: Vector2 = game.world.frame(p).affine_inverse() * at
	open(p, vol, loc, loc - Geom.centroid(p.poly), KERF_W * 0.25, "hole")


# the kerf grows across it: so does the hole (game.gd _kerf_breach)
func on_kerf(p, pl: PackedVector2Array, res: Dictionary) -> void:
	var j = _jet_of(p, "hole")
	if j == null:
		return
	var ln := 0.0
	for i in pl.size() - 1:
		ln += pl[i].distance_to(pl[i + 1])
	j.area = float(j.area) + ln / Geom.M * KERF_W
	if int(res.get("split", 1)) > 1:
		var bb := Geom.bbox(p.poly)
		j.area = maxf(float(j.area), minf(bb.size.x, bb.size.y) / Geom.M * 0.5)


# a body took a hard knock (game.gd _impact): a charged bottle in it, or one fixed in the
# ship right where it hit, loses its valve; a launched body breaks what it hits
func on_impact(b, dv: float, at = null) -> void:
	# one knock is one knock, whichever of the two saw it (game.gd _impact, or _knocks here)
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(b.get_meta("rc_knock", -9.0)) < 0.15:
		return
	b.set_meta("rc_knock", now)
	var hit: Vector2 = at if at != null else b.hit_pos
	var s = _sys()
	if dv >= SHEAR_DV:
		for p in b.pieces:
			var vol: String = s.tank_vol(p)
			if vol != "" and s.P(vol) > SHEAR_KPA and _jet_of(p, "neck") == null:
				var nk: Array = neck_of(p)
				open(p, vol, nk[0], nk[1], NECK_A, "neck")
		for id in game.world.order:
			var q = game.world.pieces[id]
			if q.gone or q.body != null or q.cls != "equip":
				continue
			var vq: String = s.tank_vol(q)
			if vq == "" or s.P(vq) <= SHEAR_KPA or _jet_of(q, "neck") != null:
				continue
			var nq: Array = neck_of(q)
			if (game.world.frame(q) * nq[0]).distance_to(hit) < KNOCK_R:
				open(q, vq, nq[0], nq[1], NECK_A, "neck")
	var f = flying.get(b.get_instance_id())
	if f == null:
		return
	# what it flew into takes the blow: the equipment it struck, by how hard
	var k := clampf((dv - 55.0) / 260.0, 0.0, 1.0)
	var lost := 0.0
	for q in game._equip_near(hit, 1.2 * Geom.M):
		if q.body == b:
			continue
		var before: float = q.cond
		game._dent(q, maxf(0.0, q.cond - q.fragile * k * 0.6), "dv_impact")
		lost += (before - q.cond) * q.value
	if lost > 50.0:
		game.incident("impact", "%d" % int(lost))
		game.fx.number(hit + Vector2(0, -24), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)


# a loose body brought up hard (a sudden stop of SHEAR_DV or more, not a push): what a
# collision does. The contact impulses alone miss some of them (a body stopped dead on the
# hull in one step).
func _knocks() -> void:
	var seen := {}
	for b in game.world.bodies:
		if not is_instance_valid(b):
			continue
		var id: int = b.get_instance_id()
		seen[id] = true
		var v: Vector2 = b.linear_velocity
		var pv = _prev_v.get(id)
		_prev_v[id] = v
		if pv == null or b.capture != null:
			continue
		var lost: float = (pv as Vector2).length() - v.length()
		if lost < SHEAR_DV * 0.75 or (v - pv).length() < SHEAR_DV:
			continue
		if not (flying.has(id) or _charged(b)):
			continue
		var r := 0.0
		for q in b.pieces:
			r = maxf(r, Geom.bbox(q.poly).size.length() * 0.5)
		var hit: Vector2 = b.hit_pos if b.hit_imp > 0.0 else b.global_position + (pv as Vector2).normalized() * r
		on_impact(b, (v - pv).length(), hit)
	for id in _prev_v.keys():
		if not seen.has(id):
			_prev_v.erase(id)


func _charged(b) -> bool:
	var s = _sys()
	for p in b.pieces:
		var vol: String = s.tank_vol(p)
		if vol != "" and s.P(vol) > SHEAR_KPA:
			return true
	return false


func _fly(b) -> void:
	flying[b.get_instance_id()] = {"body": b, "t": 0.0}


# ---------------------------------------------------------------- doors

# the codex (cx_door_b/x), user 2026-11-10 (用户定案 1): the doors slide, so their motors open
# them whatever the difference; but a door cut through with air on one side and less on the
# other is blown out of its frame, the difference times its area for the instant before the
# opening equalises it: a heavy plate flying at whatever is on the low side
func on_door_cut(p, res: Dictionary) -> void:
	if p == null or p.gone or not p.door or p.door_open or p.body != null:
		return
	var w = game.world
	var poly: PackedVector2Array = w.world_poly(p)
	var bb := Geom.bbox(poly)
	var c := bb.get_center()
	var tall: bool = bb.size.y >= bb.size.x
	var n := Vector2(1, 0) if tall else Vector2(0, 1)
	var half: float = (bb.size.x if tall else bb.size.y) * 0.5 + 0.5 * Geom.M
	var pa := _kpa_at(c + n * half)
	var pb := _kpa_at(c - n * half)
	var dp: float = absf(pa - pb)
	if dp < DOOR_KPA:
		return
	var dir: Vector2 = -n if pa > pb else n
	var area: float = maxf(bb.size.x, bb.size.y) / Geom.M * DOOR_DEPTH
	var parts: Array = [p]
	for q in res.get("new", []):
		var qq = q if typeof(q) == TYPE_OBJECT else w.pieces.get(q)
		if qq != null and not qq.gone and not parts.has(qq):
			parts.append(qq)
	for q in parts:
		for j in w.joints_of(q).duplicate():
			w.kill_joint(j)
	var mass_kg := 0.0
	for q in parts:
		mass_kg += float(q.mass) * 1000.0
	# m/s: the impulse over the plate's mass (the berth caps what anything loose can reach)
	var dv: float = dp * 1000.0 * area * DOOR_T / maxf(mass_kg, 20.0)
	_doors.append({"parts": parts, "dir": dir, "dv": dv, "t": 0.0, "at": c, "kpa": dp})
	game.sys.topology_dirty = true
	game.incident("door_blown", p.tag)
	game.say("door_blown", c)
	# the bang of the frame letting go, the air that comes with it
	game.shake(clampf(dp / 150.0, 0.2, 0.6), dir)
	game.hitstop(0.05)
	game.sfx.play("blowout", c, clampf(dp / 100.0, 0.5, 1.0))
	game.fx.flash(c, 200.0, 0.4, Pal.tint(Pal.AIR, 0.5, 1.6))
	game.fx.ring(c, 8.0, 3.0 * Geom.M, 0.45, Pal.tint(Pal.AIR, 0.7, 1.4), 2.5)
	for i in 30:
		var d := dir.rotated(randf_range(-0.6, 0.6))
		var o := (n.orthogonal() * randf_range(-0.5, 0.5) * maxf(bb.size.x, bb.size.y))
		game.fx.puff(c + o, d * randf_range(300, 900), randf_range(0.4, 0.9), 4.0, 26.0, Pal.tint(Pal.AIR, 0.12))
	game.fx.sparks(c, dir, 18, Pal.heat(1.0, 2.0), 420.0, 0.35, 1.2)


func _kpa_at(pos: Vector2) -> float:
	var r: String = game.world.room_at(pos)
	return game.sys.P(r) if r != "" else 0.0


func _step_doors(dt: float) -> void:
	var keep: Array = []
	for d in _doors:
		d.t = float(d.t) + dt
		var ready := true
		for q in d.parts:
			if not q.gone and q.body == null:
				ready = false
		if not ready and d.t < 0.6:
			keep.append(d)
			continue
		var seen := {}
		for q in d.parts:
			var b = q.body
			if b == null or q.gone or seen.has(b.get_instance_id()):
				continue
			seen[b.get_instance_id()] = true
			b.linear_velocity += (d.dir as Vector2) * float(d.dv) * Geom.M
			b.angular_velocity += randf_range(-2.5, 2.5)
			b.calm = 0.0
			_fly(b)
	_doors = keep


# ---------------------------------------------------------------- the step

func _physics_process(dt: float) -> void:
	if game == null or game.sys == null or game.state != "play" or game.paused_sim:
		return
	_drone_cd = maxf(0.0, _drone_cd - dt)
	var s = _sys()
	var keep: Array = []
	for j in jets:
		if _step_jet(j, dt):
			keep.append(j)
		else:
			_flush(j, true)
	jets = keep
	_step_doors(dt)
	_knocks()
	# a tank leaking liquid through a hole: the liquid's momentum, ρ·Q·v, pushes it back
	for lk in s.leaks:
		var p = lk.piece
		if p == null or p.gone or p.body == null or not lk.has("v"):
			continue
		var look: String = LIQ.look_of(s.fvol.get(lk.src, {}))
		var rho: float = float(LIQ.LOOKS.get(look, LIQ.LOOKS.water).get("rho", 1000.0))
		var fn: float = rho * float(lk.rate) * float(lk.v)
		if fn < 1.0:
			continue
		var at: Vector2 = game.leak_pos(lk)
		var out: Vector2 = (at - game.world.frame(p) * Geom.centroid(p.poly)).normalized()
		lk.recoil = fn
		p.body.apply_force(-out * fn * N_TO_GAME, at - p.body.global_position)
		if fn > 200.0:
			_fly(p.body)
	# what has been launched: it hurts the drone it runs into
	for id in flying.keys():
		var f: Dictionary = flying[id]
		f.t += dt
		var b = f.body
		if not is_instance_valid(b) or f.t > FLY_T or b.capture != null:
			flying.erase(id)
			continue
		var v: Vector2 = b.linear_velocity - game.drone.linear_velocity
		if v.length() < HIT_V or _drone_cd > 0.0 or not game.drone.alive:
			continue
		var r := 0.0
		for q in b.pieces:
			var qb := Geom.bbox(game.world.world_poly(q))
			r = maxf(r, qb.size.length() * 0.5)
		var rel: Vector2 = game.drone.global_position - b.global_position
		if rel.length() < r + 0.7 * Geom.M and rel.dot(v) > 0.0:
			_drone_cd = 1.0
			var dmg := clampf(v.length() / Geom.M * 2.5, 10.0, 45.0) * clampf(b.total_mass() / 0.2, 0.5, 1.5)
			game.hurt_drone(dmg, b.global_position, "jet_hit", "recoil", 0.8)
			game.drone.external += v.normalized() * game.drone.mass * 1400.0


# one jet, one step; false when it is spent
func _step_jet(j: Dictionary, dt: float) -> bool:
	var s = _sys()
	var p = j.piece
	if p == null or p.gone or not s.vols.has(j.vol):
		return false
	j.t += dt
	var xf: Transform2D = game.world.frame(p)
	var at: Vector2 = xf * _local(j)
	var dir: Vector2 = xf.basis_xform(j.ldir).normalized()
	j.at = at
	var pin: float = s.P(j.vol)
	var dp: float = pin - _outside(at)
	if dp < MIN_KPA:
		return false
	var v: Dictionary = s.vols[j.vol]
	var vv: float = maxf(float(v.V), 0.002)
	var n0: float = v.n
	# choked while the vessel is at nearly twice what is outside or more; below that the
	# flow goes with √Δp (subsonic), so the last of it hisses out quickly
	var r: float = dp / maxf(pin, 1e-3)
	var choke: float = 1.0 if r > 0.47 else sqrt(maxf(r, 0.0) / 0.47)
	var n1: float = n0 * exp(-K_FLOW * float(j.area) * dt / vv * choke)
	v.n = n1
	s.gas_lost += n0 - n1
	j.acc = float(j.acc) + (n0 - n1)
	if float(j.acc) > 0.0 and fmod(float(j.t), 0.25) < dt:
		_flush(j, false)
	var fn: float = CF * dp * 1000.0 * float(j.area)
	j.f = fn
	if p.body != null:
		var b = p.body
		b.apply_force(-dir * fn * N_TO_GAME, at - b.global_position)
		if fn > 300.0:
			_fly(b)
	_jet_fx(at, dir, fn, j)
	_stream(at, dir, fn, p)
	return true


# what the jet let out goes where the gas would (the room's air, a fuel cloud, adrift)
func _flush(j: Dictionary, last: bool) -> void:
	var p = j.piece
	var n: float = float(j.acc)
	if last and p != null and not p.gone and _sys().vols.has(j.vol):
		# the hiss at the end: what is left over the air round it goes too (an open bottle
		# reads what is outside it)
		var vv: Dictionary = _sys().vols[j.vol]
		var keep: float = minf(vv.n, _outside(j.get("at", Vector2.ZERO)) * float(vv.V))
		n += vv.n - keep
		_sys().gas_lost += vv.n - keep
		vv.n = keep
	j.acc = 0.0
	if n <= 0.0 or p == null:
		return
	var at: Vector2 = game.world.frame(p) * _local(j) if not p.gone else j.get("at", Vector2.ZERO)
	game.combustion.gas_released(str(j.gas), n, at)


func _local(j: Dictionary) -> Vector2:
	var p = j.piece
	if p.body != j.body0:
		var cen: Vector2 = Geom.centroid(p.poly)
		j.local = j.local + cen - j.cen0
		j.cen0 = cen
		j.body0 = p.body
	return j.local


func _thrust_n(j) -> float:
	if j == null:
		return 0.0
	var dp: float = _sys().P(j.vol) - _outside(game.world.frame(j.piece) * _local(j))
	return CF * maxf(dp, 0.0) * 1000.0 * float(j.area)


func _outside(at: Vector2) -> float:
	var room: String = game.world.room_at(at)
	return _sys().P(room) if room != "" else 0.0


# the vessel's own valves (systems.gd gas_valves): any of them, and all shut
func _valves_shut(vol: String) -> bool:
	var any := false
	for gv in _sys().gas_valves:
		if gv.a == vol or gv.b == vol:
			any = true
			if _sys().on(gv.ctrl):
				return false
	return any


# a pipe off this piece carries the piece's own liquid: its net is the tank's, or its line
# volume joins the tank through a valve that is open
func _line_open_to(l, fv: String) -> bool:
	var s = _sys()
	var lv: String = s.fluid_of_net(l.net)
	if lv == "":
		return false
	if lv == fv:
		return true
	for jn in s.cfg.get("fluids", {}).get("joins", []):
		if (jn.a == fv and jn.b == lv) or (jn.b == fv and jn.a == lv):
			return s.join_open(jn)
	return false


const LIQ = preload("res://scripts/liquids.gd")


func _jet_fx(at: Vector2, dir: Vector2, fn: float, _j: Dictionary) -> void:
	# strength: about a kilonewton is a roar (on_jet's scale for a room venting)
	var k := clampf(fn / 2500.0, 0.0, 1.0)
	if k < 0.01:
		return
	var n := int(k * 5.0) + (1 if randf() < k * 5.0 - int(k * 5.0) else 0) + 1
	for i in n:
		var d := dir.rotated(randf_range(-0.22, 0.22))
		game.fx.puff(at + d * 6.0, d * randf_range(320, 760) * (0.5 + k), randf_range(0.3, 0.7), 3.0, 14.0 + 30.0 * k, Pal.tint(Pal.AIR, 0.1 + 0.08 * k))
	if randf() < 0.3 + k:
		game.fx.spark(at, dir.rotated(randf_range(-0.15, 0.15)) * (500.0 + 500.0 * k), 0.2, Pal.tint(Pal.AIR, 0.7, 1.4), 1.0, 8.0, 2.0)
	game.sfx.jet(maxf(k, 0.25))


# the stream shoves what is in it and knocks the drone about (game.gd on_jet, for a vessel)
func _stream(at: Vector2, dir: Vector2, fn: float, src) -> void:
	var k := clampf(fn / 2500.0, 0.0, 1.5)
	if k < 0.02:
		return
	for b in game.world.bodies:
		if src != null and src.body == b:
			continue
		var rel: Vector2 = b.global_position - at
		if rel.length() < 3.0 * Geom.M and rel.normalized().dot(dir) > 0.6:
			b.apply_central_force(dir * b.mass * 500.0 * k)
	if game.drone.alive:
		var rd: Vector2 = game.drone.global_position - at
		if rd.length() < 2.5 * Geom.M and rd.normalized().dot(dir) > 0.5:
			game.drone.external += dir * game.drone.mass * 900.0 * k
			if k > 0.4 and rd.length() < 1.4 * Geom.M:
				game.hurt_drone(20.0, at, "jet_hit", "jet", 1.0)
