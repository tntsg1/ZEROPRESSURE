extends Node2D
# What the codex says of ordinary equipment on every ship (user 2026-11-10, 用户定案 5/6/7/10/11,
# design/图鉴对标_审计_20261110.md). One node for the lot, under the world (drawn in its frame):
#
#   buckle   (cx_fueltank_x, cx_m_tanknet_b) a thin tank built for little pressure (marked
#            "thin" on its fluid volume: an atmospheric tank, not a pressure vessel; most
#            tanks hold several atmospheres and a vacuum inside is only one) drawn of its
#            liquid while the air outside presses on it and nothing lets gas in: the
#            inside pulls a vacuum and the shell buckles. Vent the room first, or keep its
#            ullage charged. (VT-80's own network, tanknet.gd, does its tanks itself.)
#   dry      (cx_pump_x, cx_s_hose_b) a pump still powered, its line drawn dry and the hose
#            still drawing on it ("抽取完成以后还继续运行"): it runs dry, its seal overheats
#            and it is damaged within DRY_S. Power it down or take the hose off.
#   gauge    (cx_coriolis_b, cx_level_radar_b) a level gauge or flowmeter on a tank still
#            under pressure, taken off: the open socket sprays (recoil.gd jets it, a leak for
#            a liquid). Which tank it sits on: "mounts" in the ship file, else the tank its
#            outline touches.
#   solenoid (cx_extinguisher_b) a charged fire bottle's solenoid release is wired to the
#            ship's bus: taken off with the bus live, it fires (its valve opens, recoil.gd).
#   rcs      (cx_rcs_quad_b) a thruster's valves are on the bus too: taken off live with
#            propellant aboard, it fires one short pulse.
# Each is drawn (a buckled shell's creases, a dry pump's heat and smoke) and booked.

const DRY_S := 30.0            # s a pump runs dry before its seal is gone (the book: tens of seconds)
const DRY_KEEP := 0.5
const DRY_LOW := 0.03          # share of its line's capacity under which a pump is drawing nothing
const BUCKLE_DP := 20.0        # kPa over the inside a thin shell gives under
const BUCKLE_KEEP := 0.45
const SPRAY_KPA := 60.0        # over what is outside: a gauge socket sprays
const FIRE_KPA := 300.0        # a fire bottle charged over this fires
const PULSE_S := 0.35          # s of a thruster's stray pulse
const PULSE_N := 4000.0        # N: an attitude thruster cluster (four 1 kN chambers)
const ARTS_GAUGE := ["coriolis", "level_radar"]
const KEYS_GAUGE := ["p_level", "p_level_radar", "p_hg_level_gauge", "p_flow_meter", "p_hg_flow_sensor", "p_coriolis"]
const KEYS_FIRE := ["p_ark_fire_bottle", "p_co2_bottle", "p_fire_bottle", "p_extinguisher", "p_foam"]
const KEYS_RCS := ["p_rcs", "p_rcs_q", "p_rcs_t", "p_rcs_quad"]

var game
var world
var pumps: Array = []          # {p, vol, t}
var thin: Array = []           # {vol, p, last}
var watch: Array = []          # {p, kind ("gauge"/"solenoid"/"rcs"), tank, attached}
var buckled := {}              # piece id -> true
var pulses: Array = []         # {p, t, local, ldir}
var _smoke := 0.0


func setup(g) -> void:
	game = g
	world = g.world
	z_index = 34
	var s = g.sys
	var mounts: Dictionary = g.ship.get("mounts", {}) if g.get("ship") is Dictionary else {}
	var skip_pump: String = str(g.tanknet.cfg.get("pump", "")) if g.tanknet != null and g.tanknet.active() else ""
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.cls != "equip":
			continue
		var nk: String = p.name_key
		if "pump" in nk and nk not in ["p_heat_pump", "p_pump_power"]:
			var fv: String = s.fluid_in_piece(p)
			if fv != "" and p.tag != skip_pump:
				pumps.append({"p": p, "vol": fv, "t": 0.0})
		if p.art in ARTS_GAUGE or nk in KEYS_GAUGE:
			var tank = world.tag(str(mounts[p.tag])) if mounts.has(p.tag) else _touching_tank(p)
			if tank != null:
				watch.append({"p": p, "kind": "gauge", "tank": tank, "attached": p.body == null})
		elif (p.art == "extinguisher" or nk in KEYS_FIRE) and s.tank_vol(p) != "":
			watch.append({"p": p, "kind": "solenoid", "tank": p, "attached": p.body == null})
		elif p.art == "rcs_quad" or nk in KEYS_RCS:
			watch.append({"p": p, "kind": "rcs", "tank": null, "attached": p.body == null})
	for k in s.fvol:
		var v: Dictionary = s.fvol[k]
		if v.get("thin", false):
			var tp = world.tag(str(v.get("piece", "")))
			if tp != null:
				thin.append({"vol": k, "p": tp, "last": float(v.amount)})


# the vessel (gas or liquid) whose outline the gauge's touches
func _touching_tank(p):
	var s = game.sys
	var bb := Geom.bbox(world.world_poly(p)).grow(0.25 * Geom.M)
	for id in world.order:
		var q = world.pieces[id]
		if q == p or q.gone or q.cls != "equip":
			continue
		if s.tank_vol(q) == "" and s.fluid_in_piece(q) == "":
			continue
		if bb.intersects(Geom.bbox(world.world_poly(q))):
			return q
	return null


func _outside(p) -> float:
	var r: String = world.room_at(world.frame(p) * Geom.centroid(p.poly))
	return game.sys.P(r) if r != "" else 0.0


func _bus_live() -> bool:
	return game.sys.bus_live


func _fuel_aboard() -> bool:
	var s = game.sys
	for k in s.fvol:
		if str(s.fvol[k].get("fluid", "")) == "fuel" and float(s.fvol[k].amount) > 0.05:
			return true
	return false


func _physics_process(dt: float) -> void:
	if game == null or game.sys == null or game.state != "play" or game.paused_sim:
		return
	_pumps(dt)
	_thin(dt)
	_removals()
	_pulses(dt)
	if not buckled.is_empty() or not pumps.is_empty():
		queue_redraw()


# ---------------------------------------------------------------- pumps run dry

func _pumps(dt: float) -> void:
	var s = game.sys
	_smoke -= dt
	for e in pumps:
		var p = e.p
		if p.gone or p.body != null or p.has_meta("ran_dry"):
			continue
		var full: float = maxf(float(s.fvol[e.vol].get("full", s.fvol[e.vol].amount)), 0.01)
		var dry: bool = s.fluid(e.vol) < full * DRY_LOW
		# it pumps only while its line is being drawn (a hose on one of the line's ports) and
		# only runs dry once it has had liquid to pump: a line empty from the start is not it
		if not dry:
			e["had"] = true
		var drawn := false
		for pid in s.hoses:
			var ct = world.ctrls.get(pid)
			if ct != null and str(ct.target) == str(e.vol):
				drawn = true
				break
		if dry and drawn and e.get("had", false) and s.piece_volts(p) > 0.0:
			e.t = float(e.t) + dt
			var k: float = clampf(float(e.t) / DRY_S, 0.0, 1.0)
			p.temp = maxf(p.temp, 20.0 + 160.0 * k)
			var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
			if k > 0.3 and _smoke <= 0.0:
				_smoke = 0.25
				game.fx.puff(c + Vector2(randf_range(-10, 10), -6), Vector2(randf_range(-20, 20), -50.0 - 60.0 * k), randf_range(0.8, 1.5), 4.0, 18.0 + 22.0 * k, Pal.ink(0.08 + 0.06 * k))
			if k > 0.2 and int(e.t) != int(e.t - dt):
				game.say("pump_running_dry", c, p.tag)
			if e.t >= DRY_S:
				p.set_meta("ran_dry", true)
				var before: float = p.cond
				game._dent(p, minf(p.cond, DRY_KEEP), "dv_pump_dry")
				game.incident("pump_dry", p.tag)
				game.say("pump_dry_any", c, p.tag)
				game.note_loss("loss_pump_dry", p.tag, (before - p.cond) * p.value)
				game.sfx.play("crack", c, 0.6, 0.7)
				game.fx.sparks(c, Vector2.UP, 16, Pal.heat(1.0, 2.0), 220.0, 0.4, PI)
				for i in 8:
					game.fx.puff(c, Vector2.from_angle(randf() * TAU) * randf_range(40, 120), randf_range(1.0, 2.0), 6.0, 40.0, Pal.ink(0.12))
		else:
			e.t = maxf(0.0, float(e.t) - dt * 2.0)


# ---------------------------------------------------------------- thin tanks buckle

func _thin(_dt: float) -> void:
	var s = game.sys
	for e in thin:
		var p = e.p
		var a: float = s.fluid(e.vol)
		var drawn: bool = a < float(e.last) - 1e-6
		e.last = a
		if not drawn or p.gone or p.body != null or buckled.has(p.id) or not p.intact:
			continue
		# a hole lets air in: nothing to pull a vacuum against
		var holed := false
		for lk in s.leaks:
			if lk.get("src", "") == e.vol or lk.get("piece") == p:
				holed = true
		if holed:
			continue
		var uk: String = s.tank_vol(p)
		var inside: float = s.P(uk) if uk != "" else 0.0
		if _outside(p) - inside > BUCKLE_DP:
			_buckle(p)


func _buckle(p) -> void:
	buckled[p.id] = true
	var before: float = p.cond
	game._dent(p, minf(p.cond, BUCKLE_KEEP), "dv_buckle")
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.incident("tank_buckled", p.tag)
	game.say("tank_buckled_thin", c, p.tag)
	game.note_loss("loss_buckle", p.tag, (before - p.cond) * p.value)
	# the shell folds in with a bang: a jolt, a groan, dust off the creases
	game.sfx.play("clank", c, 1.0, 0.55)
	game.sfx.play("crack", c, 0.8, 0.6)
	game.shake(0.25)
	var bb := Geom.bbox(world.world_poly(p))
	for i in 14:
		var q: Vector2 = bb.position + Vector2(randf(), randf()) * bb.size
		game.fx.puff(q, (c - q).normalized() * randf_range(20, 60), randf_range(0.6, 1.2), 3.0, 16.0, Pal.ink(0.07))
	game.fx.ring(c, maxf(bb.size.x, bb.size.y) * 0.6, 6.0, 0.35, Pal.ink(0.6), 2.0)
	game.world.redraw_all()


# ---------------------------------------------------------------- taken off live / charged

func _removals() -> void:
	for e in watch:
		var p = e.p
		if p.gone:
			continue
		var now: bool = p.body == null
		if e.attached and not now:
			_removed(e)
		e.attached = now


func _removed(e: Dictionary) -> void:
	var s = game.sys
	var p = e.p
	var rc = game.recoil
	match str(e.kind):
		"gauge":
			var t = e.tank
			if t == null or t.gone:
				return
			var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
			var tc: Vector2 = world.frame(t) * Geom.centroid(t.poly)
			var out_kpa: float = _outside(t)
			var uk: String = s.tank_vol(t)
			var fv: String = s.fluid_in_piece(t)
			if fv != "" and s.fluid(fv) > 0.02 and ((uk != "" and s.P(uk) > out_kpa + 5.0) or float(s.fvol[fv].get("bellows", 0.0)) > out_kpa + 5.0):
				# liquid behind the socket: it sprays out of it
				game._leak(str(s.fvol[fv].fluid), fv, at, t)
				s.leaks.back().area = rc.FIT_A
				game.incident("gauge_spray", p.tag)
				game.say("gauge_spray", at, p.tag)
			elif uk != "" and s.P(uk) > out_kpa + SPRAY_KPA:
				var loc: Vector2 = world.frame(t).affine_inverse() * at
				rc.open(t, uk, loc, loc - Geom.centroid(t.poly), rc.FIT_A, "fit")
				game.incident("gauge_spray", p.tag)
				game.say("gauge_spray", at, p.tag)
			# the gauge itself is thrown off its socket
			if p.body != null:
				p.body.linear_velocity += (at - tc).normalized() * 3.0 * Geom.M
		"solenoid":
			var vol: String = s.tank_vol(p)
			if _bus_live() and vol != "" and s.P(vol) > FIRE_KPA:
				var nk: Array = rc.neck_of(p)
				rc.open(p, vol, nk[0], nk[1], rc.NECK_A, "neck")
				if p.body != null:
					p.body.calm = 0.0
					p.body.settle = 0.0
				var at2: Vector2 = world.frame(p) * (nk[0] as Vector2)
				game.incident("solenoid_fired", p.tag)
				game.say("solenoid_fired", at2, p.tag)
				game.fx.arc(at2, at2 + Vector2.from_angle(randf() * TAU) * 30.0, 0.2, 0.5)
		"rcs":
			if _bus_live() and _fuel_aboard() and p.body != null:
				var nk2: Array = rc.neck_of(p)
				pulses.append({"p": p, "t": 0.0, "local": nk2[0], "ldir": nk2[1]})
				# a body just let go is held calm a moment (free_body.gd): not against a thruster
				p.body.calm = 0.0
				p.body.settle = 0.0
				var at3: Vector2 = world.frame(p) * (nk2[0] as Vector2)
				game.incident("rcs_fired", p.tag)
				game.say("rcs_fired", at3, p.tag)
				game.sfx.play("burst", at3, 0.7, 1.2)


func _pulses(dt: float) -> void:
	var keep: Array = []
	for e in pulses:
		var p = e.p
		e.t = float(e.t) + dt
		if p.gone or p.body == null or e.t > PULSE_S:
			continue
		keep.append(e)
		var xf: Transform2D = world.frame(p)
		var at: Vector2 = xf * (e.local as Vector2)
		var d: Vector2 = xf.basis_xform(e.ldir as Vector2).normalized()
		# the plume goes out of the nozzle, the thruster the other way
		p.body.apply_force(-d * PULSE_N * game.recoil.N_TO_GAME, at - p.body.global_position)
		for i in 3:
			game.fx.puff(at, d.rotated(randf_range(-0.2, 0.2)) * randf_range(400, 800), randf_range(0.2, 0.4), 4.0, 22.0, Pal.heat(0.5, 2.0))
		game.fx.spark(at, d.rotated(randf_range(-0.15, 0.15)) * 700.0, 0.2, Pal.heat(1.0, 2.4), 1.6, 12.0, 1.0)
		game.combustion.spark(at + d * 0.5 * Geom.M, 0.6)
		var dr = game.drone
		if dr.alive:
			var rel: Vector2 = dr.global_position - at
			if rel.length() < 2.5 * Geom.M and rel.normalized().dot(d) > 0.6:
				game.hurt_drone(12.0, at, "fire_hit", "rcs_pulse", 0.5)
	pulses = keep


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	# a buckled shell: creases across it, folded in
	for id in buckled:
		var p = world.pieces.get(id)
		if p == null or p.gone:
			continue
		var xf: Transform2D = world.frame(p)
		var bb := Geom.bbox(p.poly)
		var n := 5
		for i in n:
			var y: float = bb.position.y + bb.size.y * (0.15 + 0.7 * i / float(n - 1))
			var pts := PackedVector2Array()
			for k in 9:
				var x: float = bb.position.x + bb.size.x * (0.06 + 0.88 * k / 8.0)
				var dy: float = (0.12 if k % 2 == 0 else -0.12) * minf(bb.size.y, bb.size.x) * (0.5 + 0.5 * sin(i * 1.7 + k))
				pts.append(xf * Vector2(x, y + dy))
			draw_polyline(pts, Pal.ink(0.55), 1.2, true)
		# the walls drawn in, at the middle of each long side
		var c: Vector2 = bb.get_center()
		draw_line(xf * Vector2(bb.position.x, c.y), xf * Vector2(bb.position.x + bb.size.x * 0.12, c.y), Pal.ink(0.7), 1.6, true)
		draw_line(xf * Vector2(bb.end.x, c.y), xf * Vector2(bb.end.x - bb.size.x * 0.12, c.y), Pal.ink(0.7), 1.6, true)
	# a pump running dry: its casing glows with the heat
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	for e in pumps:
		var p = e.p
		if p.gone or float(e.t) <= 0.0 or tex == null:
			continue
		var k: float = clampf(float(e.t) / DRY_S, 0.0, 1.0)
		var c2: Vector2 = world.frame(p) * Geom.centroid(p.poly)
		var r: float = maxf(Geom.bbox(p.poly).size.length() * 0.5, 20.0)
		draw_texture_rect(tex, Rect2(c2 - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.heat(0.12 + 0.4 * k, 1.6))
