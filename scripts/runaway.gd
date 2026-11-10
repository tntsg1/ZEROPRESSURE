extends Node
# Thermal runaway (热失控). The codex (cx_battery_b/x): a cell pierced while it still holds
# its charge shorts inside; the heat breaks the electrolyte down, the cell climbs past
# 600 °C within seconds, vents a cloud of flammable electrolyte vapour, and the heat of it
# sets off the cells beside it. User 2026-11-10 (用户定案 3): cutting into a charged battery
# pack does that.
#
# A pack in runaway: VENT seconds of venting (its temperature climbing to PEAK, a jet of
# smoke and sparks off the kerf, electrolyte vapour into the air: combustion.gd lights it
# where there is oxygen, between its flammability limits), then it burns out (condition
# gone, the pack scrap) and cools. Any other charged battery within SPREAD of it for
# CATCH seconds of that goes the same way. The drone close in is burnt.
# Prevention: drain it (the arc empties a source; a source run flat is safe), or take it
# off whole with the wrench.

const PEAK := 650.0            # °C a cell in runaway reaches
const VENT := 5.0              # s of venting
const CATCH := 2.5             # s next to a pack in runaway before the next one goes
const SPREAD := 1.2            # m: cells this close (outline to outline) catch it
const VAPOUR := 6.0            # kg of electrolyte vapour a tonne of pack vents over VENT: a small pack burns as a jet flame, a big one (over about a tonne) fast enough to go up as a deflagration
const MIN_CHARGE := 0.05       # a pack under this holds too little to run away
const HURT_R := 1.6            # m

var game
var packs: Array = []          # {piece, t, at (piece-local point), exposed {id: s}}
var _drone_cd := 0.0


func setup(g) -> void:
	game = g


# what a piece holds: its charge if it is a battery (a power source, an isolated store, or a
# piece the ship file calls a battery hazard), else -1
func charge_of(p) -> float:
	var s = game.sys
	if p == null or p.tag == "":
		return 1.0 if p != null and p.hazard == "battery" else -1.0
	if s.src.has(p.tag) and str(s.src[p.tag].get("kind", "")) == "battery":
		return float(s.src[p.tag].charge)
	if s.iso.has(p.tag) and str(s.iso[p.tag].get("kind", "")) == "battery":
		return float(s.iso[p.tag].charge)
	if p.hazard == "battery":
		return 0.0 if p.has_meta("runaway_done") else 1.0
	return -1.0


func running(p) -> bool:
	for r in packs:
		if r.piece == p:
			return true
	return false


# the beam cut into p at pos (game.gd on_cut_into, before the arc empties it)
func on_cut(p, pos: Vector2) -> void:
	if p.cls != "equip" or running(p) or p.has_meta("runaway_done"):
		return
	if charge_of(p) < MIN_CHARGE:
		return
	start(p, game.world.frame(p).affine_inverse() * pos)


func start(p, local: Vector2) -> void:
	packs.append({"piece": p, "t": 0.0, "at": local, "cen0": Geom.centroid(p.poly), "body0": p.body})
	var at: Vector2 = game.world.frame(p) * local
	game.incident("runaway", p.tag)
	game.say("battery_runaway", at)
	game.sfx.play("burst", at, 0.6, 1.3)
	game.fx.flash(at, 160.0, 0.4, Pal.heat(1.0, 2.4))
	game.fx.sparks(at, Vector2.UP, 26, Pal.heat(1.0, 2.2), 380.0, 0.5, PI)


func _at(r: Dictionary) -> Vector2:
	var p = r.piece
	# a pack re-centred as it came off the ship (world.gd): its kerf point moves with it
	if p.body != r.body0:
		var cen: Vector2 = Geom.centroid(p.poly)
		r.at = (r.at as Vector2) + cen - (r.cen0 as Vector2)
		r.body0 = p.body
	r.cen0 = Geom.centroid(p.poly)
	return game.world.frame(p) * (r.at as Vector2)


func _physics_process(dt: float) -> void:
	if game == null or game.sys == null or game.state != "play" or game.paused_sim:
		return
	_drone_cd = maxf(0.0, _drone_cd - dt)
	var keep: Array = []
	var hot: Array = []
	for r in packs:
		var p = r.piece
		if p == null or p.gone:
			continue
		r.t = float(r.t) + dt
		var t: float = r.t
		var at := _at(r)
		var c: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
		var out: Vector2 = (at - c).normalized() if at.distance_to(c) > 2.0 else Vector2.UP.rotated(randf_range(-0.4, 0.4))
		if t < VENT:
			# climbing to its peak, venting all the while
			p.temp = maxf(p.temp, lerpf(80.0, PEAK, clampf(t / (VENT * 0.5), 0.0, 1.0)))
			var k: float = clampf(t / 1.0, 0.3, 1.0)
			var kg: float = VAPOUR * maxf(float(p.mass), 0.05) * dt / VENT
			# the vent gas comes out hot over sparks: a jet flame at the kerf where there is air
			# (it is lit as it leaves, little by little, not piled into one cloud to go up at once)
			game.combustion.add_vapour(at + out * 0.2 * Geom.M, out * 0.8 * Geom.M, kg, "electrolyte")
			game.combustion.spark(at + out * 0.3 * Geom.M, 1.1)
			if randf() < 0.8:
				game.fx.puff(at, out.rotated(randf_range(-0.35, 0.35)) * randf_range(140, 360) * k, randf_range(0.6, 1.4), 5.0, 30.0 + 30.0 * k, Pal.ink(0.11))
			if randf() < 0.5:
				game.fx.spark(at, out.rotated(randf_range(-0.6, 0.6)) * randf_range(200, 520), randf_range(0.2, 0.45), Pal.heat(1.0, 2.2), 1.3, 8.0, 2.0)
			game.sfx.jet(0.35 * k)
			game._dent(p, maxf(0.0, p.cond - dt * 0.25), "dv_runaway")
			hot.append(p)
			if game.drone.alive and _drone_cd <= 0.0 and game.drone.global_position.distance_to(at) < HURT_R * Geom.M:
				_drone_cd = 0.8
				game.hurt_drone(8.0, at, "heat_hit", "runaway", 0.6)
			keep.append(r)
		else:
			# burnt out
			game._dent(p, 0.0, "dv_runaway")
			p.set_meta("runaway_done", true)
			if p.tag != "":
				game.sys.drain_source(p.tag)
	packs = keep
	# the cells beside a pack in runaway catch it
	for h in hot:
		var hp: PackedVector2Array = game.world.world_poly(h)
		var hb := Geom.bbox(hp).grow(SPREAD * Geom.M)
		for id in game.world.order:
			var q = game.world.pieces[id]
			if q == h or q.gone or q.cls != "equip" or running(q) or q.has_meta("runaway_done"):
				continue
			if charge_of(q) < MIN_CHARGE:
				continue
			var qp: PackedVector2Array = game.world.world_poly(q)
			if not hb.intersects(Geom.bbox(qp)):
				continue
			var key := "rw_exposed"
			var e: float = float(q.get_meta(key, 0.0)) + dt
			q.set_meta(key, e)
			q.temp = maxf(q.temp, 20.0 + 200.0 * e / CATCH)
			if e >= CATCH:
				start(q, Geom.centroid(q.poly))
