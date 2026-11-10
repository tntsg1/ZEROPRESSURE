extends Node2D
# Rotors coasting down (惰转) and a generator's remanence (剩磁). The codex:
#   cx_duct_fan_x       a fan off its power keeps turning a while; in vacuum, with no air to
#                       drag on it, for longer still
#   cx_axial_comp_b     the rotor may still be turning after the machine has stopped
#   cx_turbo_pump_x     a molecular pump's rotor takes minutes to stop
#   cx_reaction_wheel_b the wheel may keep turning after it is switched off
#   cx_steam_turbine_b  the heavy rotor may still be turning
#   cx_gen_x            with the excitation off, a generator whose rotor still turns puts out
#                       tens of volts from the field left in its poles
# User 2026-11-10 (用户定案 8, 13): as the book has it. Each rotor runs while it has power
# (a fan with no cable of its own is on the ship's main bus) and coasts down exponentially
# once it loses it; game time is shorter than the book's minutes (COAST, seconds, to all
# but stopped). While it still turns (over SAFE of its speed):
#   cut into: the rotor bursts, its blades and pieces thrown out (equipment round it
#     dented, the drone close in hurt), the machine wrecked;
#   taken off its mounts: its spin goes into the casing, which is flung round;
#   a generator reads REMANENCE volts at full speed (systems.gd piece_volts), enough to arc.
# Drawn: the blades turning over the machine, fast to a blur, slowing to a stop.

const COAST := {               # s from full speed to stopped (three time constants and a bit)
	"duct_fan": 20.0, "axial_comp": 40.0, "turbo_pump": 60.0, "turbo": 60.0,
	"turbopump": 15.0, "reaction_wheel": 90.0, "steam_turbine": 60.0, "gen": 30.0,
}
const VAC_SLOW := 2.0          # a fan in vacuum coasts this many times as long (no air drag on it)
const SAFE := 0.06             # under this share of its speed it is as good as stopped
const REMANENCE := 60.0        # V a generator puts out from its remanence at full speed
const SPIN_RATE := 30.0        # rad/s the drawn blades turn at full speed (a stroboscopic look)

var game
var world
var rotors: Array = []         # {p, art, w (0..1), ang, said}
var _skip := {}                # pieces another mechanism spins (flywheel.gd, rings.gd)


func setup(g) -> void:
	game = g
	world = g.world
	z_index = 33
	for t in g.ship.get("flywheel", {}).get("wheels", {}):
		_skip[str(t)] = true
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.cls != "equip" or _skip.has(p.tag):
			continue
		var art: String = Codex.art_of(p)
		if COAST.has(art):
			rotors.append({"p": p, "art": art, "w": 0.0, "ang": randf() * TAU, "said": false})
	for r in rotors:
		r.w = 1.0 if _powered(r) else 0.0


func _powered(r: Dictionary) -> bool:
	var s = game.sys
	var p = r.p
	if p.gone or p.body != null or not p.intact:
		return false
	if s.src.has(p.tag):
		return s.running(p.tag)
	# fed (not its own remanence, which piece_volts would count)
	if s.iso_powered.has(p.id) or (s.bus_live and (s.powered.has(p.id) or p.tag == s.bus_tag)):
		return true
	# a machine with no cable of its own in the ship file is fed off the main bus
	return s.bus_live and not s.electric_piece(p)


func rotor_of(p):
	for r in rotors:
		if r.p == p:
			return r
	return null


func turning(p) -> bool:
	var r = rotor_of(p)
	return r != null and float(r.w) > SAFE


# what a stopped generator's remanence puts out (systems.gd piece_volts)
func remanence(p) -> float:
	var r = rotor_of(p)
	if r == null or r.art != "gen" or float(r.w) <= SAFE:
		return 0.0
	return REMANENCE * float(r.w)


func _tau(r: Dictionary) -> float:
	var t: float = float(COAST[r.art]) / 3.5
	if r.art == "duct_fan":
		var room: String = world.room_at(world.frame(r.p) * Geom.centroid(r.p.poly))
		if room == "" or game.sys.P(room) < 5.0:
			t *= VAC_SLOW
	return t


func _physics_process(dt: float) -> void:
	if game == null or game.sys == null or game.state != "play" or game.paused_sim:
		return
	var any := false
	for r in rotors:
		var p = r.p
		if p.gone:
			continue
		var w: float = r.w
		if _powered(r):
			w = minf(1.0, w + dt / 3.0)
		else:
			w *= exp(-dt / _tau(r))
			if w < 0.01:
				w = 0.0
		r.w = w
		r.ang = fposmod(float(r.ang) + w * SPIN_RATE * dt, TAU)
		if w > 0.0:
			any = true
		# coasting near the drone: say it once
		if w > SAFE and not _powered(r) and not r.said and game.drone.alive:
			var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
			if game.drone.global_position.distance_to(c) < 3.0 * Geom.M:
				r.said = true
				game.say("rotor_coasting", c, p.tag)
	if any:
		queue_redraw()


# the beam cut into a machine whose rotor still turns: it bursts
func on_cut(p, pos: Vector2) -> void:
	var r = rotor_of(p)
	if r == null or float(r.w) <= SAFE:
		return
	var w: float = r.w
	r.w = 0.0
	game.incident("rotor_burst", p.tag)
	game.say("rotor_burst", pos, p.tag)
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var rad: float = maxf(Geom.bbox(p.poly).size.length() * 0.5, 0.5 * Geom.M)
	# the blades go tangentially, off the rim, all round
	for i in 26:
		var a := randf() * TAU
		var at := c + Vector2.from_angle(a) * rad * 0.6
		var d := Vector2.from_angle(a + PI * 0.5)
		game.fx.spark(at, d * randf_range(500, 1100) * (0.5 + 0.5 * w), randf_range(0.25, 0.6), Pal.heat(1.0, 2.2), 1.6, 14.0, 0.8)
	game.fx.burst_shards(c, int(10 + 16 * w), 520.0 * (0.5 + 0.5 * w), Pal.ink(0.85), 7.0)
	game.fx.ring(c, rad * 0.5, rad + 2.5 * Geom.M * w, 0.4, Pal.heat(0.8, 1.8), 2.5)
	game.fx.flash(c, 160.0, 0.3, Pal.heat(1.0, 2.2))
	game.sfx.play("crack", c, 1.0, 0.8)
	game.sfx.play("clank", c, 1.0, 1.3)
	game.shake(0.3 + 0.3 * w)
	game.hitstop(0.05)
	game._dent(p, 0.0, "dv_rotor")
	for q in game._equip_near(c, 2.2 * Geom.M):
		if q != p:
			game._dent(q, maxf(0.0, q.cond - minf(0.2, q.fragile * 0.5 * w)), "dv_rotor")
	if game.drone.alive and game.drone.global_position.distance_to(c) < 3.0 * Geom.M:
		game.hurt_drone(10.0 + 25.0 * w, c, "rotor_hit", "rotor", 0.5)


# taken off its mounts still turning: the bearings drag the casing round with the rotor
func on_freed(b) -> void:
	for q in b.pieces:
		var r = rotor_of(q)
		if r == null or float(r.w) <= SAFE:
			continue
		var w: float = r.w
		var k: float = 1.0 if r.art in ["reaction_wheel", "steam_turbine", "gen"] else 0.6
		b.calm = 0.0
		b.settle = 0.0
		b.angular_velocity += (1.0 if randf() < 0.5 else -1.0) * 5.0 * w * k
		var c: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		b.linear_velocity += Vector2.from_angle(randf() * TAU) * 2.0 * w * k * Geom.M
		game.incident("rotor_kick", q.tag)
		game.say("rotor_kick", c, q.tag)
		game.sfx.play("clank", c, 0.9, 0.7)
		game.fx.sparks(c, Vector2.from_angle(randf() * TAU), 14, Pal.heat(1.0, 2.0), 300.0, 0.35, PI)


func _draw() -> void:
	for r in rotors:
		var w: float = r.w
		var p = r.p
		if w <= 0.0 or p.gone:
			continue
		var xf: Transform2D = world.frame(p)
		var bb := Geom.bbox(p.poly)
		var c: Vector2 = xf * bb.get_center()
		var rad: float = minf(bb.size.x, bb.size.y) * 0.36
		if rad < 4.0:
			continue
		var a0: float = float(r.ang) + xf.get_rotation()
		var blades := 6
		var al: float = 0.25 + 0.45 * w
		# fast: a blurred disc with streaks; slower: each blade stands out
		if w > 0.35:
			draw_arc(c, rad, 0.0, TAU, 40, Pal.ink(0.12 * w), rad * 0.9, true)
		for i in blades:
			var a: float = a0 + TAU * i / blades
			draw_line(c + Vector2.from_angle(a) * rad * 0.18, c + Vector2.from_angle(a) * rad, Pal.ink(al), 1.4, true)
			if w > 0.2:
				draw_arc(c, rad * 0.85, a - 0.5 * w, a, 8, Pal.ink(al * 0.35), 1.0, true)
		draw_circle(c, rad * 0.16, Pal.ink(0.5 * al))
