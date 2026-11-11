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
# Second round (design/图鉴对标_审计_第二轮_20261110.md):
#   pane     (cx_glass_b/c, cx_m_glass_b/x) a pane let go of its last fixing with GLASS_KPA or
#            more across it: the cabin pushes it out (the difference times its area for the
#            instant the gap takes to equalise) and it shatters. Vent the room first.
#   armour   (cx_armor_b) the heat a kerf leaves in an armour plate (mat.gd kerf_dt) over
#            ARMOUR_HOT reaches the equipment beside it: it heats and loses value, up to ARMOUR_MAX.
#   residual (cx_inverter_b/x, cx_xray_scanner_b/x, cx_gyrotron_b) a DC link's capacitors still
#            hold their volts after the supply goes: V0·e^(−t/τ) (systems.gd piece_volts reads it,
#            a cut or an unplugging over 30 V arcs). Wait, then prove it dead.
#   sorter   (cx_sorter_b) an eddy-current sorter's rotor is a drum of strong permanent magnets:
#            whole and in place it pulls the drone and loose steel within SORT_R toward it
#            (no switch kills it: a permanent magnet), and knocks a drone dragged onto it.
#   electrolyser (cx_electrolyser_b/x) its cells hold hydrogen and oxygen two to one: cut
#            into, the knallgas goes up with the beam's spark, in vacuum too (combustion.gd).
#   uv lamp  (cx_uv_steriliser_b/x) a mercury lamp broken by the beam lets its vapour into the
#            room: the equipment round it has to be cleaned (MERCURY_LOSS off its value).
#   hot      (cx_humidifier_b/x, cx_screw_comp_b) a humidifier's water and a screw compressor's
#            oil are hot while it runs and cool slowly once it stops: grabbed hot it burns
#            the drone (game.gd on_grab), the probe reads it.
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
const GLASS_KPA := 20.0        # kPa across a pane over which its frame's fixings were holding it in
const GLASS_T := 0.08          # s the gap takes to equalise (as a door blown out, recoil.gd)
const GLASS_KEEP := 0.05       # what a shattered pane is still worth
const GLASS_HURT_R := 2.0      # m: the drone this close is cut by the shards
const ARMOUR_HOT := 150.0      # °C of kerf heat in an armour plate over which it reaches its neighbours
const ARMOUR_NEAR := 0.6       # m from the plate's outline
const ARMOUR_RATE := 0.02      # of a neighbour's value a second while the plate is that hot
const ARMOUR_MAX := 0.2        # most a neighbour loses so
const ARMOUR_MATS := ["armor", "ceramic"]
# the DC link's volts with the supply on, and its bleed time constant (s; the book's minutes
# shortened to game time: about a minute to under 30 V)
const SORT_R := 1.8            # m an eddy-current sorter's magnet drum reaches out
const SORT_F := 1500.0         # its pull on the drone at the drum (game force, falling off to the edge)
const KNALL_H2 := 0.08         # kg of hydrogen in an electrolyser's cells and separators (oxygen 8 times that)
const MERCURY_R := 3.0         # m round a broken UV lamp the mercury settles on
const MERCURY_LOSS := 0.05     # of each machine's value to clean it off
const HOT := {"humidifier": 90.0, "screw_comp": 70.0}   # °C while running
const HOT_TAU := 45.0          # s its heat takes to fall by e once it stops
const RESIDUAL := {"inverter": [700.0, 15.0], "xray_scanner": [2000.0, 15.0], "gyrotron": [40000.0, 15.0]}

var game
var world
var pumps: Array = []          # {p, vol, t}
var thin: Array = []           # {vol, p, last}
var watch: Array = []          # {p, kind ("gauge"/"solenoid"/"rcs"), tank, attached}
var buckled := {}              # piece id -> true
var pulses: Array = []         # {p, t, local, ldir}
var _smoke := 0.0
var armour: Array = []         # armour plates (their kerf heat is watched)
var heated := {}               # piece id -> {"k": glow 0..1, "lost": value share lost to it}
var residuals := {}            # piece id -> {"p", "v0", "tau", "t" (s since its supply went)}
var _armour_t := 0.0
var sorters: Array = []        # eddy-current sorters (permanent magnet drums)
var hot: Array = []            # {p, T}: machines whose insides run hot
var _sort_cd := 0.0
var _pulled_last := false
var _pull: Array = []          # [drone pos, sorter centre, strength] drawn this frame


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
		# the book's entry this machine is drawn as (several drawings can share one entry)
		var art: String = Codex.device_entry(Codex.art_of(p))
		if art == "armor" or str(p.mat) in ARMOUR_MATS:
			armour.append(p)
		if art == "sorter":
			sorters.append(p)
		if HOT.has(art):
			hot.append({"p": p, "T": float(HOT[art])})
		if RESIDUAL.has(art) and p.tag != "":
			residuals[p.id] = {"p": p, "kind": art, "v0": float(RESIDUAL[art][0]), "tau": float(RESIDUAL[art][1]), "t": 0.0}
	for id in world.order:
		var q = world.pieces[id]
		if q.cls != "equip" and str(q.mat) in ARMOUR_MATS and not armour.has(q):
			armour.append(q)
	for id in residuals:
		residuals[id].t = 0.0 if _fed(residuals[id].p) else 999.0
	for e in hot:
		if _fed(e.p):
			e.p.temp = maxf(e.p.temp, float(e.T))
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
	_residuals(dt)
	_armour(dt)
	_sorters(dt)
	_hot(dt)
	if not buckled.is_empty() or not pumps.is_empty() or not heated.is_empty() or not _pull.is_empty() or _pulled_last:
		queue_redraw()


# ---------------------------------------------------------------- a pane pushed out

# game.gd on_body_freed: a body just made of what came loose
func on_freed(b) -> void:
	for q in b.pieces:
		if q.gone or q.cls != "equip" or not q.intact or q.has_meta("pane_out"):
			continue
		if q.art != "glass" and Codex.device_entry(Codex.art_of(q)) != "glass":
			continue
		# a hall's glazing in the ship file is liner.gd's (PS-12, ARK-01, BL-88, LC-140)
		if _liner_pane(q):
			continue
		var poly: PackedVector2Array = world.world_poly(q)
		var bb := Geom.bbox(poly)
		var c := bb.get_center()
		var tall: bool = bb.size.y >= bb.size.x
		var n := Vector2(1, 0) if tall else Vector2(0, 1)
		var half: float = (bb.size.x if tall else bb.size.y) * 0.5 + 0.5 * Geom.M
		var pa: float = _kpa_at(c + n * half)
		var pb: float = _kpa_at(c - n * half)
		var dp: float = absf(pa - pb)
		if dp < GLASS_KPA:
			continue
		q.set_meta("pane_out", true)
		var dir: Vector2 = -n if pa > pb else n
		var area: float = maxf(bb.size.x, bb.size.y) / Geom.M * 1.0
		var dv: float = dp * 1000.0 * area * GLASS_T / maxf(float(b.total_mass()) * 1000.0, 20.0)
		b.calm = 0.0
		b.settle = 0.0
		b.linear_velocity += dir * dv * Geom.M
		b.angular_velocity += randf_range(-3.0, 3.0)
		if game.recoil != null:
			game.recoil._fly(b)
		_shatter(q, c, dir, dp, bb)


func _liner_pane(q) -> bool:
	var ln = game.get("liner")
	if ln == null or not ln.active():
		return false
	if ln.blown.has(q.tag):
		return true
	var all: Array = ln.cfg.get("glazings", []).duplicate()
	if not ln.cfg.get("glazing", {}).is_empty():
		all.append(ln.cfg.glazing)
	for gz in all:
		if (gz.get("panes", []) as Array).has(q.tag):
			return true
	return false


func _kpa_at(pos: Vector2) -> float:
	var r: String = world.room_at(pos)
	return game.sys.P(r) if r != "" else 0.0


func _shatter(q, c: Vector2, dir: Vector2, dp: float, bb: Rect2) -> void:
	game._dent(q, minf(q.cond, GLASS_KEEP), "dv_pane_out")
	game.incident("pane_out", q.tag)
	game.say("pane_blown", c, q.tag)
	game.shake(clampf(dp / 200.0, 0.15, 0.45), dir)
	game.hitstop(0.04)
	game.sfx.play("blowout", c, clampf(dp / 120.0, 0.4, 0.9))
	game.sfx.play("crack", c, 1.0, 1.5)
	var glass: Color = Pal.tint(Pal.AIR, 0.85, 1.6)
	# the frame lets go with a bang, the pane bursts into a fan of glittering shards that
	# ride out on the air, a thin ring of the pressure wave, a breath of fog as the cabin's
	# moisture freezes in the jet
	game.fx.flash(c, 150.0, 0.25, Pal.tint(Pal.AIR, 0.5, 1.8))
	game.fx.ring(c, 6.0, 2.5 * Geom.M, 0.4, Pal.tint(Pal.AIR, 0.6, 1.4), 2.0)
	game.fx.burst_shards(c, 22, 520.0, glass, 4.0)
	var span: float = maxf(bb.size.x, bb.size.y)
	var side: Vector2 = dir.orthogonal()
	for i in 34:
		var o: Vector2 = side * randf_range(-0.5, 0.5) * span
		game.fx.spark(c + o, dir.rotated(randf_range(-0.55, 0.55)) * randf_range(260, 760), randf_range(0.35, 0.8), glass, 1.2, 6.0, 0.6)
	for i in 18:
		var o2: Vector2 = side * randf_range(-0.5, 0.5) * span
		game.fx.puff(c + o2, dir.rotated(randf_range(-0.5, 0.5)) * randf_range(200, 700), randf_range(0.4, 0.9), 4.0, 24.0, Pal.tint(Pal.AIR, 0.14))
	var dr = game.drone
	if dr.alive and dr.global_position.distance_to(c) < GLASS_HURT_R * Geom.M:
		game.hurt_drone(8.0 + clampf(dp / 10.0, 0.0, 12.0), c, "glass_hit", "pane_out", 0.5)


# ---------------------------------------------------------------- armour kerf heat

func _armour(dt: float) -> void:
	_armour_t -= dt
	# glows fade as the plates cool
	for id in heated.keys():
		var h: Dictionary = heated[id]
		h.k = maxf(0.0, float(h.k) - dt * 0.4)
		if h.k <= 0.0:
			heated.erase(id)
	if _armour_t > 0.0:
		return
	var step := 0.25
	_armour_t = step
	for a in armour:
		if a.gone or float(a.kerf_dt) < ARMOUR_HOT:
			continue
		var ap: PackedVector2Array = world.world_poly(a)
		var reach: float = ARMOUR_NEAR * Geom.M
		var bb := Geom.bbox(ap).grow(reach)
		var heat: float = float(a.kerf_dt)
		for id in world.order:
			var q = world.pieces[id]
			if q == a or q.gone or q.cls != "equip" or not q.intact or q.art == "armor" or str(q.mat) in ARMOUR_MATS:
				continue
			var qp: PackedVector2Array = world.world_poly(q)
			if not bb.intersects(Geom.bbox(qp)):
				continue
			var qc: Vector2 = Geom.centroid(qp)
			if Geom.dist_to_boundary(qc, ap) > reach + Geom.bbox(qp).size.length() * 0.5:
				continue
			var h: Dictionary = heated.get(q.id, {"k": 0.0, "lost": 0.0})
			var k: float = clampf((heat - ARMOUR_HOT) / 200.0 + 0.3, 0.3, 1.0)
			q.temp = maxf(q.temp, 20.0 + heat * 0.55)
			if float(h.lost) < ARMOUR_MAX:
				var take: float = minf(ARMOUR_RATE * k * step, ARMOUR_MAX - float(h.lost))
				h.lost = float(h.lost) + take
				game._dent(q, maxf(0.0, q.cond - take), "dv_armour_heat")
			if float(h.k) <= 0.0:
				game.say("armour_heat", qc, q.tag)
				game.incident("armour_heat", q.tag)
			h.k = minf(1.0, float(h.k) + 0.5 * k)
			heated[q.id] = h
			if randf() < 0.35:
				game.fx.puff(qc + Vector2(randf_range(-12, 12), -4), Vector2(randf_range(-15, 15), -40.0), randf_range(0.6, 1.1), 3.0, 14.0, Pal.ink(0.07))


# ---------------------------------------------------------------- inside, when cut

# game.gd on_cut_into: the beam has gone into p at pos
func on_cut(p, pos: Vector2) -> void:
	if p.cls != "equip" or not p.intact or p.has_meta("insides_out"):
		return
	match Codex.device_entry(Codex.art_of(p)):
		"electrolyser":
			p.set_meta("insides_out", true)
			var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
			var out: Vector2 = (pos - c).normalized() if pos.distance_to(c) > 2.0 else Vector2.UP
			game.combustion.add_vapour(pos + out * 0.2 * Geom.M, out * 0.6 * Geom.M, KNALL_H2, "lh2")
			game.combustion.add_vapour(pos + out * 0.3 * Geom.M, out * 0.5 * Geom.M, KNALL_H2 * 8.0, "o2")
			game.combustion.spark(pos + out * 0.3 * Geom.M, 1.2)
			game.incident("knallgas", p.tag)
			game.say("knallgas", pos, p.tag)
			game.fx.puff(pos, out * 120.0, 0.6, 6.0, 40.0, Pal.tint(Pal.AIR, 0.14))
		"uv_steriliser":
			p.set_meta("insides_out", true)
			_mercury(p, pos)


func _mercury(p, pos: Vector2) -> void:
	var room: String = world.room_at(pos)
	var names: Array = []
	for q in game._equip_near(pos, MERCURY_R * Geom.M):
		if q == p or q.gone or not q.intact or q.has_meta("mercury"):
			continue
		if room != "" and world.room_at(world.frame(q) * Geom.centroid(q.poly)) != room:
			continue
		q.set_meta("mercury", true)
		game._dent(q, maxf(0.0, q.cond - MERCURY_LOSS), "dv_mercury")
		if q.tag != "":
			names.append(q.tag)
	game.incident("mercury", p.tag)
	game.say("uv_mercury", pos, p.tag)
	game.sfx.play("crack", pos, 0.6, 1.8)
	# the quartz sleeve's tinkle, a pale grey-green haze creeping out low and slow
	game.fx.burst_shards(pos, 8, 120.0, Pal.tint(Pal.AIR, 0.7, 1.4), 2.5)
	for i in 16:
		game.fx.puff(pos + Vector2(randf_range(-10, 10), randf_range(-6, 6)), Vector2.from_angle(randf() * TAU) * randf_range(15, 60), randf_range(1.6, 3.0), 6.0, 40.0 + randf() * 30.0, Color(0.62, 0.78, 0.66, 0.10))


# ---------------------------------------------------------------- machines that run hot

func _hot(dt: float) -> void:
	for e in hot:
		var p = e.p
		if p.gone:
			continue
		if _fed(p):
			p.temp = maxf(p.temp, float(e.T))
		elif p.temp > 20.5:
			p.temp = 20.0 + (p.temp - 20.0) * exp(-dt / HOT_TAU)


# ---------------------------------------------------------------- a sorter's magnet drum

func _sorters(dt: float) -> void:
	_sort_cd = maxf(0.0, _sort_cd - dt)
	_pull.clear()
	var r: float = SORT_R * Geom.M
	for p in sorters:
		if p.gone or not p.intact:
			continue
		var wp: PackedVector2Array = world.world_poly(p)
		var c: Vector2 = Geom.centroid(wp)
		var box := Geom.bbox(wp).grow(r)
		var dr = game.drone
		if dr != null and dr.alive and dr.spawn_t > 2.5 and box.has_point(dr.global_position):
			# measured from the machine's casing (a sorter can be a dozen metres long)
			var gap: float = 0.0 if Geometry2D.is_point_in_polygon(dr.global_position, wp) else Geom.dist_to_boundary(dr.global_position, wp)
			if gap < r:
				var d: Vector2 = (c - dr.global_position).normalized()
				dr.apply_central_force(d * SORT_F * (1.0 - gap / r))
				_pull.append([dr.global_position, c, 1.0 - gap / r])
				if gap < 0.6 * Geom.M and _sort_cd <= 0.0:
					_sort_cd = 3.0
					game.incident("sorter_pull", p.tag)
					game.hurt_drone(6.0, dr.global_position, "hurt_magnet", "sorter", 2.0)
					game.say("sorter_pull", dr.global_position, p.tag)
					game.fx.sparks(dr.global_position, d, 10, Pal.ink(0.9, 1.4), 160.0, 0.25, 1.0)
		for b in world.bodies:
			if not is_instance_valid(b) or b.pieces.has(p) or b.mass > 600.0 or not box.has_point(b.global_position):
				continue
			var steel := false
			for q in b.pieces:
				if Mat.id_of(q) in [Mat.STEEL, "armor"]:
					steel = true
					break
			if not steel:
				continue
			var gap2: float = Geom.dist_to_boundary(b.global_position, wp)
			if gap2 < r:
				b.apply_central_force((c - b.global_position).normalized() * 700.0 * (1.0 - gap2 / r))


# ---------------------------------------------------------------- a DC link still charged

func _fed(p) -> bool:
	var s = game.sys
	if p.gone or not p.intact:
		return false
	if s.iso_powered.has(p.id) or (s.bus_live and (s.powered.has(p.id) or p.tag == s.bus_tag)):
		return true
	return s.bus_live and not s.electric_piece(p)


func _residuals(dt: float) -> void:
	for id in residuals:
		var e: Dictionary = residuals[id]
		if _fed(e.p):
			e.t = 0.0
			# an inverter's link is the bus rectified: about 1.35 times its AC volts
			if str(e.kind) == "inverter" and game.sys.bus_volts() > 0.0:
				e.v0 = game.sys.bus_volts() * 1.35
		else:
			e.t = float(e.t) + dt


# what the link still holds (systems.gd piece_volts, when nothing feeds it)
func residual(p) -> float:
	var e = residuals.get(p.id)
	if e == null or p.gone or not p.intact:
		return 0.0
	var v: float = float(e.v0) * exp(-float(e.t) / float(e.tau))
	return v if v >= 1.0 else 0.0


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


# a pump running dry right now and the port whose hose is drawing on it: [pump, port id], or []
# (next_step.gd puts "take the hose off" up first, so following the guide never burns a pump)
func dry_running() -> Array:
	for e in pumps:
		var p = e.p
		if p.gone or p.has_meta("ran_dry") or float(e.t) <= 0.0:
			continue
		for pid in game.sys.hoses:
			var ct = world.ctrls.get(pid)
			if ct != null and str(ct.target) == str(e.vol):
				return [p, str(pid)]
	return []


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
	# the drum's field reaching for the drone: faint flux lines bowing from the drone into the
	# machine, crawling inward, brighter the closer it is dragged
	_pulled_last = not _pull.is_empty()
	var tms: float = Time.get_ticks_msec() * 0.001
	for e in _pull:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var k: float = float(e[2])
		var ab: Vector2 = b - a
		var len: float = minf(ab.length(), 3.0 * Geom.M)
		var dir: Vector2 = ab.normalized()
		var side: Vector2 = dir.orthogonal()
		for i in 5:
			var bow: float = (float(i) - 2.0) * 0.22 * len
			var pts := PackedVector2Array()
			for j in 13:
				var u: float = j / 12.0
				pts.append(a + dir * len * u + side * bow * sin(u * PI))
			draw_polyline(pts, Pal.tint(Pal.VOLT, 0.10 + 0.25 * k, 1.2), 1.0, true)
			# a bead running down each line toward the drum
			var u2: float = fposmod(tms * (0.8 + 0.6 * k) + i * 0.21, 1.0)
			draw_circle(a + dir * len * u2 + side * bow * sin(u2 * PI), 1.6 + 1.4 * k, Pal.tint(Pal.VOLT, 0.35 + 0.5 * k, 1.6))
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
	# equipment the armour's kerf heat is reaching: a dull red soak over it, and its outline
	# picked out hot on the side the heat comes from
	for id in heated:
		var q = world.pieces.get(id)
		if q == null or q.gone or tex == null:
			continue
		var hk: float = float(heated[id].k)
		var qc: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		var qr: float = maxf(Geom.bbox(q.poly).size.length() * 0.55, 16.0)
		var flick: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.011 + float(id))
		draw_texture_rect(tex, Rect2(qc - Vector2(qr, qr), Vector2(qr, qr) * 2.0), false, Pal.heat((0.05 + 0.16 * hk) * flick, 1.3))
		var ol: PackedVector2Array = world.world_poly(q)
		if ol.size() > 2:
			ol.append(ol[0])
			draw_polyline(ol, Pal.heat(0.25 + 0.5 * hk, 1.8), 1.3, true)
