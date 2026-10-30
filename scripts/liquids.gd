extends Node2D
# Liquid let loose in free fall: what comes out of a cut line or a broken tank is not
# a number going down but globules of liquid, drifting. Each globule keeps its momentum
# (no gravity in the berth; air drag only where a room still holds air), trembles
# under its surface tension (small ones round and still, big ones slow and wobbling),
# merges with any it touches, splashes apart or wets the surface it meets, and is lost
# the way its liquid is lost:
#   cryogenic (liquid hydrogen, helium, LNG, nitrogen): flash-boils as it comes out,
#     the rest shrinking fast in a trail of vapour, frosting what it touches (helium
#     fastest, then hydrogen, then LNG);
#   water: evaporates slowly in air; in vacuum it freezes over into a ball of ice and
#     slowly sublimes;
#   fuel: oily, slow to evaporate (its vapour still feeds the systems' fuel clouds);
#   MMH and N₂O₄ (a bipropellant's fuel and oxidiser): the hydrazine clear and slow to
#     boil, the tetroxide orange-brown and boiling hard in vacuum (its vapour pressure
#     is near an atmosphere) until it freezes over; the two light on contact;
#   what burns, and when, is combustion.gd's: the vapour a burnable globule boils off
#     is handed to it;
#   glycol coolant: like water, but never freezes and barely evaporates;
#   drilling mud: thick, never splashes, sticks wherever it lands.
# What a globule does to what it touches (none for the "quiet" ones a module spilt and
# already charged for): powered electrics short (a little), cryogens frost and crack,
# the drone gets wet or frosted.
# The globules are not saved: on a load the liquid that was adrift is gone.
#
# One body of liquid, not drops (user 2026-10-27: "一整团液体喷出来……是一整个"; Jev bulb 0.99,
# metaball 0.97). In free fall surface tension rules: what comes out of a hole swells into one
# ball sitting on it, fed by the flow, wobbling, until it is big enough for the flow behind it to
# push it off (fast jets let go sooner: a column of balls nose to tail); globules close to each
# other pull together and their relative motion dies away (cohesion, viscosity), and touching
# they run into one. Drawn as one surface (liquid_surface.gd): globules near each other read as
# one liquid.
#
# Where a liquid's look comes from: its volume's "look" in the ship file ("lh2", "lhe",
# "lng", "ln2", "water", "fuel", "glycol", "mud"), else its fluid kind.

const MAX_BLOBS := 320
const MAX_VOL := 0.035          # m³ in one globule from a leak
const RHO_GAP := 0.85           # how close two globules come before they merge (of r1 + r2)
const PULL_RANGE := 1.4         # globules within this many (r1 + r2) pull together (a liquid bridge)
const PULL := 1.6               # m/s² of that pull at contact, falling to nothing at its range
const DAMP := 1.5               # 1/s: how fast their relative motion dies within that range
const HOLD := 2.2               # s·(m/s): a bulb sits on its hole for about HOLD / jet speed

# per look: boil fraction/s in vacuum and in air, flash fraction lost on the way out,
# density (kg/m³, for the air drag), splash speed (m/s) above which it breaks up,
# whether it freezes (s in vacuum before it does), its vapour pressure at the berth's
# temperature (kPa: what pushes it out of a holed tank with no gas over it)
const LOOKS := {
	"lhe": {"boil_v": 0.30, "boil_a": 0.45, "flash": 0.45, "rho": 125.0, "splash": 1.5, "cryo": true, "pvap": 130.0},
	"lh2": {"boil_v": 0.12, "boil_a": 0.22, "flash": 0.25, "rho": 71.0, "splash": 1.8, "cryo": true, "pvap": 130.0},
	"lng": {"boil_v": 0.05, "boil_a": 0.09, "flash": 0.12, "rho": 430.0, "splash": 2.0, "cryo": true, "pvap": 120.0},
	"ln2": {"boil_v": 0.07, "boil_a": 0.12, "flash": 0.15, "rho": 810.0, "splash": 2.0, "cryo": true, "pvap": 120.0},
	"water": {"boil_v": 0.004, "boil_a": 0.0015, "flash": 0.0, "rho": 1000.0, "splash": 2.4, "freeze": 6.0, "pvap": 2.3},
	"fuel": {"boil_v": 0.006, "boil_a": 0.003, "flash": 0.0, "rho": 800.0, "splash": 2.8, "pvap": 0.7},
	"mmh": {"boil_v": 0.02, "boil_a": 0.004, "flash": 0.02, "rho": 880.0, "splash": 2.8, "freeze": 14.0, "pvap": 5.0},
	"nto": {"boil_v": 0.12, "boil_a": 0.03, "flash": 0.15, "rho": 1440.0, "splash": 2.6, "freeze": 4.0, "pvap": 96.0},
	"glycol": {"boil_v": 0.001, "boil_a": 0.0005, "flash": 0.0, "rho": 1110.0, "splash": 2.6, "pvap": 0.01},
	"oil": {"boil_v": 0.0002, "boil_a": 0.0, "flash": 0.0, "rho": 870.0, "splash": 3.2, "pvap": 0.01},
	"foam": {"boil_v": 0.004, "boil_a": 0.0015, "flash": 0.0, "rho": 1020.0, "splash": 2.2, "freeze": 8.0, "pvap": 2.3},
	"mud": {"boil_v": 0.0, "boil_a": 0.0, "flash": 0.0, "rho": 1800.0, "splash": 99.0, "sticky": true, "pvap": 0.0},
}
const CRYO := ["lhe", "lh2", "lng", "ln2"]

var game
var world
var blobs: Array = []           # {pos, vel, vol, look, t, ph, stuck, loc, nrm, ice, quiet, frozen_t}
var frost: Array = []           # [world pos, t, size]
var _new: Array = []            # globules made this step, joined at its end
var jets: Array = []            # [from, dir, flow, look] of the leaks running this step
var _t := 0.0
var _space = null
var surface                     # liquid_surface.gd: the globules drawn as one liquid
var spilt_total := 0.0          # m³ that ever came out as globules (for the tests)


func setup(g) -> void:
	game = g
	world = g.world
	z_index = 35


static func look_of(v: Dictionary) -> String:
	if v.has("look"):
		return str(v.look)
	match str(v.get("fluid", "")):
		"fuel": return "fuel"
		"lng": return "lng"
		"n2": return "ln2"
		"coolant": return "glycol"
		_: return "water"


static func radius_m(vol: float) -> float:
	return pow(maxf(vol, 1e-7) * 0.75 / PI, 1.0 / 3.0)


# a module's spill (a burst ball, a mud blowout, a tank failing): `n` globules
# sharing `vol` m³, flung out from `at` round `dir` within `spread` radians at
# `speed` m/s (±40 %)
func spill(at: Vector2, dir: Vector2, vol: float, look: String, n: int = 12, spread: float = PI, speed: float = 1.0, quiet: bool = true) -> void:
	if vol <= 0.0 or n <= 0:
		return
	# a mass bursting all round (a ball's skin giving way): most of it stays one body, barely
	# moving, wobbling; the rest is flung off it (user 2026-10-27: one whole mass, not drops)
	if n >= 6 and spread >= PI:
		_add(at, dir.normalized() * speed * 0.12 * Geom.M if dir != Vector2.ZERO else Vector2.ZERO, vol * 0.55, look, quiet)
		vol *= 0.45
		n -= 1
	var weights: Array = []
	var tot := 0.0
	for i in n:
		# a few big ones and many small: the way a broken mass of liquid comes apart
		var wgt: float = pow(randf_range(0.15, 1.0), 2.2)
		weights.append(wgt)
		tot += wgt
	for i in n:
		var v: float = vol * float(weights[i]) / tot
		var d: Vector2 = dir.normalized().rotated(randf_range(-spread * 0.5, spread * 0.5)) if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
		var off: Vector2 = Vector2.ZERO if n == 1 else d * randf_range(0.2, 1.0) * maxf(0.3, radius_m(vol) * 1.2) * Geom.M
		_add(at + off, d * speed * randf_range(0.6, 1.4) * Geom.M, v, look, quiet)
	_flush()


func _flush() -> void:
	for nb in _new:
		if blobs.size() >= MAX_BLOBS:
			# the smallest goes (it would have boiled off or merged by now)
			var k := 0
			for i in blobs.size():
				if float(blobs[i].vol) < float(blobs[k].vol):
					k = i
			blobs.remove_at(k)
		blobs.append(nb)
	_new.clear()


func _add(pos: Vector2, vel: Vector2, vol: float, look: String, quiet: bool) -> void:
	var lk: Dictionary = LOOKS.get(look, LOOKS.water)
	var v := vol
	if float(lk.get("flash", 0.0)) > 0.0:
		# part of a cryogen flashes to vapour the moment it is out
		v *= 1.0 - float(lk.flash)
		game.fx.puff(pos, vel * 0.6, randf_range(0.8, 1.6), 6.0, 26.0 + 300.0 * vol, Pal.ink(0.07))
	_new.append({"pos": pos, "vel": vel, "vol": v, "look": look, "t": 0.0, "ph": randf() * TAU, "stuck": -1, "loc": Vector2.ZERO,
		"nrm": Vector2.ZERO, "ice": false, "quiet": quiet, "vac_t": 0.0, "wet": {}})
	spilt_total += v


func total_volume(look: String = "") -> float:
	var s := 0.0
	for b in blobs:
		if look == "" or b.look == look:
			s += float(b.vol)
	return s


func count(look: String = "") -> int:
	return blobs.filter(func(b): return look == "" or b.look == look).size()


func _physics_process(dt: float) -> void:
	if game == null or game.sys == null:
		return
	_t += dt
	if _space == null:
		_space = get_world_2d().direct_space_state
	_flush()
	_leaks(dt)
	var _pa := Time.get_ticks_usec()
	_move(dt)
	World._ps("liq_move", _pa)
	_flush()
	# globules meeting and pulling on each other: every third step (a 40th of a second)
	if Engine.get_physics_frames() % 3 == 0:
		_pa = Time.get_ticks_usec()
		_merge(dt * 3.0)
		World._ps("liq_merge", _pa)
	for f in frost:
		f[1] = float(f[1]) + dt
	frost = frost.filter(func(f): return float(f[1]) < 24.0)
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees_zone(game, "salvage", 80.0):
		queue_redraw()


# the systems' open leaks: what they drain comes out here as globules along the jet
func _leaks(dt: float) -> void:
	var s = game.sys
	jets.clear()
	for lk in s.leaks:
		var v = s.fvol.get(lk.src)
		if v == null:
			continue
		var flow: float = float(lk.get("rate", 0.0))
		if flow <= 0.0:
			continue
		var acc: float = float(lk.get("_liq", 0.0)) + flow * dt
		var look := look_of(v)
		var at: Vector2 = game.leak_pos(lk)
		var dir: Vector2 = lk.dir if lk.dir != Vector2.ZERO else Vector2.UP
		var severed: bool = lk.get("severed", false)
		if not severed:
			jets.append([at, dir, flow, look])
		# the jet's speed: from the pressure behind the hole (systems.gd), or a seep
		var sp: float = clampf(float(lk.v), 1.0, 18.0) if lk.has("v") else clampf(1.5 + flow * 30.0, 1.5, 6.0)
		# a long cut lets it out all along its length: one sheet of liquid, pulled by its surface
		# tension into one mass on the middle of the cut, stretched along it at first
		var spot := _slit_spot(lk, at, dir)
		_bulb(lk, 0, spot[0], spot[1], flow, sp, look, acc, severed, spot[2], spot[3])
		lk["_liq"] = 0.0


# where a kerf lets the liquid out: [the middle of the cut, outward (away from the tank's
# middle), along the cut, half its length px]; a short cut or a hole: the hole itself
func _slit_spot(lk: Dictionary, at: Vector2, dir: Vector2) -> Array:
	var slit: Array = lk.get("slit", [])
	var p = lk.get("piece")
	if slit.size() < 2 or p == null or p.gone:
		return [at, dir, Vector2.ZERO, 0.0]
	var xf: Transform2D = world.frame(p)
	var pts := PackedVector2Array()
	for q in slit:
		pts.append(xf * (q as Vector2))
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	if total < 1.0 * Geom.M:
		return [at, dir, Vector2.ZERO, 0.0]
	var mid: Vector2 = xf * Geom.centroid(p.poly)
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if acc + seg >= total * 0.5 or i == pts.size() - 1:
			var f := clampf((total * 0.5 - acc) / maxf(seg, 0.001), 0.0, 1.0)
			var c := pts[i - 1].lerp(pts[i], f)
			var tan := (pts[i] - pts[i - 1]).normalized()
			var nrm := tan.orthogonal()
			var side := (c - mid).dot(nrm)
			if absf(side) < 0.2 * Geom.M:
				side = 1.0
			var out := nrm * signf(side)
			# the liquid wells up on whichever side of the cut is open (a cut through the tank's
			# middle: over the outside face that has room, not into the deck it stands on).
			# Found once per cut (it walks the pieces), kept in the tank's frame.
			var key := "%d|%d" % [slit.size(), p.id]
			if lk.get("_spot_key", "") != key:
				lk["_spot_key"] = key
				var best := INF
				var best_c := c
				var best_d := out
				for dd in [out, -out]:
					var d := 0.15 * Geom.M
					while d < 6.0 * Geom.M:
						if world.pieces_at(c + dd * d).is_empty():
							break
						d += 0.1 * Geom.M
					if d < best:
						best = d
						best_c = c + dd * d
						best_d = dd
				var inv := xf.affine_inverse()
				lk["_spot"] = [inv * best_c, inv.basis_xform(best_d), inv.basis_xform(tan)]
			var sp_l: Array = lk["_spot"]
			c = xf * (sp_l[0] as Vector2)
			out = xf.basis_xform(sp_l[1]).normalized()
			tan = xf.basis_xform(sp_l[2]).normalized()
			return [c, out, tan, total * 0.5]
		acc += seg
	return [at, dir, Vector2.ZERO, 0.0]


# what comes out of a hole: one ball swelling on it, fed by the flow, until it is big enough
# to be pushed off (it keeps a little of the jet's speed; the next one starts on the hole)
func _bulb(lk: Dictionary, k: int, at: Vector2, dir: Vector2, flow: float, sp: float, look: String, vol: float, severed: bool, along := Vector2.ZERO, half := 0.0) -> void:
	if vol <= 0.0:
		return
	var bulbs: Dictionary = lk.get("_bulbs", {})
	lk["_bulbs"] = bulbs
	var b = bulbs.get(k)
	if b != null and (float(b.vol) <= 0.0 or int(b.stuck) >= 0 or b.ice or not (blobs.has(b) or _new.has(b))):
		b = null
	var lkd: Dictionary = LOOKS.get(look, LOOKS.water)
	var add := vol * (1.0 - float(lkd.get("flash", 0.0)))
	if b == null:
		_add(at, dir * sp * 0.15 * Geom.M, vol, look, false)
		b = _new[_new.size() - 1]
		bulbs[k] = b
		b["bulb_t"] = 0.0
	else:
		b.vol = float(b.vol) + add
		spilt_total += add
		if float(lkd.get("flash", 0.0)) > 0.0 and randf() < 0.3:
			game.fx.puff(at, dir * sp * 10.0, randf_range(0.8, 1.6), 6.0, 26.0 + 300.0 * vol, Pal.ink(0.07))
	b.bulb_t = float(b.get("bulb_t", 0.0)) + vol / maxf(flow, 1e-6)
	b["held_t"] = _t
	# it sits on the hole, its far side growing outward with the jet's push; wobbling. Out of a
	# long cut it is a sheet along the cut, drawn together as it grows (liquid_surface.gd)
	var r: float = radius_m(float(b.vol)) * Geom.M
	if half > 0.0:
		b["along"] = along
		b["half"] = half
		b["sheet"] = 1.0
		r = r * clampf(r / maxf(half, 1.0), 0.25, 1.0)
	b.pos = at + dir.rotated(0.12 * sin(float(b.t) * 5.0 + float(b.ph))) * r * 0.85
	b.vel = dir * sp * 0.15 * Geom.M
	# let go: a slow seep holds on longer (a big ball), a fast jet sooner (a chain of them);
	# a tank cut in two lets its whole mass go
	var hold: float = clampf(HOLD / sp, 0.12, 1.6) * (2.0 if severed else 1.0)
	if float(b.bulb_t) >= hold:
		b.vel = dir * sp * (0.55 if severed else 0.7) * Geom.M
		b.t = 0.0
		b["held_t"] = -1.0
		bulbs.erase(k)


var _bounds := Rect2()
var _bounds_t := -99.0


# the ship's extent (and the berth floor's), grown a little: no surface to meet outside it
func _near_ship(pos: Vector2) -> bool:
	if _t - _bounds_t > 2.0:
		_bounds_t = _t
		var r := Rect2()
		var first := true
		for id in world.order:
			var p = world.pieces[id]
			if p.gone or p.body != null:
				continue
			var bb := Geom.bbox(world.world_poly(p))
			r = bb if first else r.merge(bb)
			first = false
		r = r.merge(Rect2(Vector2(-10.0, 8.0) * Geom.M, Vector2(Dock.FLOOR_X1 + 20.0, 4.0) * Geom.M))
		_bounds = r.grow(2.0 * Geom.M)
		_build_solid()
	return _bounds.has_point(pos)


# 60 FPS (user 2026-10-27: "液滴一多就变得贼卡"): which coarse cells hold any of the attached
# structure (or the berth floor), rebuilt with the bounds; a globule whose way this step runs only
# through empty cells cannot meet a surface, so it needs no ray
const SOLID_CELL := 1.5            # m
var _solid := {}


func _build_solid() -> void:
	_solid = {}
	var c := SOLID_CELL * Geom.M
	var rects: Array = [Rect2(Vector2(-10.0, 8.0) * Geom.M, Vector2(Dock.FLOOR_X1 + 20.0, 4.0) * Geom.M)]
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.body != null:
			continue
		rects.append(Geom.bbox(world.world_poly(p)))
	for r in rects:
		var x0 := int(floor(r.position.x / c)) - 1
		var x1 := int(floor(r.end.x / c)) + 1
		var y0 := int(floor(r.position.y / c)) - 1
		var y1 := int(floor(r.end.y / c)) + 1
		if (x1 - x0) * (y1 - y0) > 40000:
			continue
		for x in range(x0, x1 + 1):
			for y in range(y0, y1 + 1):
				_solid[Vector2i(x, y)] = true


func _clear_way(a: Vector2, b: Vector2) -> bool:
	var c := SOLID_CELL * Geom.M
	return not _solid.has(Vector2i(int(floor(a.x / c)), int(floor(a.y / c)))) and not _solid.has(Vector2i(int(floor(b.x / c)), int(floor(b.y / c))))


func _room_kpa(pos: Vector2) -> float:
	var r: String = world.room_at(pos)
	return game.sys.P(r) if r != "" else 0.0


func _move(dt: float) -> void:
	var dead := false
	var reacts := {}
	var dr = game.drone
	var dr_on: bool = dr != null and dr.alive
	var dr_at: Vector2 = dr.global_position if dr_on else Vector2.INF
	for b in blobs:
		b.t = float(b.t) + dt
		# a sheet let go rounds up into a ball within a second or so
		if b.has("sheet") and not _is_bulb(b):
			b.sheet = maxf(0.0, float(b.sheet) - dt * 0.9)
		var lk: Dictionary = LOOKS.get(b.look, LOOKS.water)
		var near: bool = _near_ship(b.pos)
		# the room's pressure, looked up again only once the globule has moved half a metre or a
		# quarter second has gone (point-in-room over every room, for every globule, every step)
		var kpa := 0.0
		if near:
			if b.get("kpa_t", -1.0) < 0.0 or _t - float(b.get("kpa_t", -1.0)) > 0.25 or (b.pos as Vector2).distance_to(b.get("kpa_at", Vector2.INF)) > 0.5 * Geom.M:
				b["kpa"] = _room_kpa(b.pos)
				b["kpa_t"] = _t
				b["kpa_at"] = b.pos
			kpa = float(b.kpa)
		var air: bool = kpa > 5.0
		var v0: float = float(b.vol)
		# evaporation / boiling, freezing
		if bool(lk.get("cryo", false)):
			var boil: float = float(lk.boil_a if air else lk.boil_v)
			var lost: float = float(b.vol) * boil * dt
			b.vol = float(b.vol) - lost
			if randf() < dt * 6.0:
				game.fx.puff(b.pos, -b.vel * 0.2 + Vector2.from_angle(randf() * TAU) * 20.0, 0.9, 3.0, 8.0 + radius_m(b.vol) * 120.0, Pal.ink(0.06))
		elif b.ice:
			b.vol = float(b.vol) * (1.0 - 0.002 * dt)
		else:
			b.vol = float(b.vol) * (1.0 - float(lk.boil_a if air else lk.boil_v) * dt)
			if lk.has("freeze") and not air:
				b.vac_t = float(b.vac_t) + dt
				if float(b.vac_t) > float(lk.freeze):
					b.ice = true
		if float(b.vol) < 0.00008:
			b.vol = 0.0
			dead = true
			continue
		# what a burnable one boiled off is vapour, handed on in lumps
		if not reacts.has(b.look):
			reacts[b.look] = game.combustion != null and game.combustion.reacts(b.look)
		if reacts[b.look]:
			var vap: float = float(b.get("vap", 0.0)) + (v0 - float(b.vol)) * float(lk.get("rho", 1000.0))
			if vap > 0.05 or (vap > 0.0 and fmod(float(b.t), 0.3) < dt):
				game.combustion.add_vapour(b.pos, b.vel * 0.2, vap, b.look)
				vap = 0.0
			b["vap"] = vap
		if int(b.stuck) >= 0:
			var sp = world.pieces.get(int(b.stuck))
			if sp == null or sp.gone:
				b.stuck = -1
			else:
				b.pos = world.frame(sp) * b.loc
				_touch(b, sp)
				continue
		# air drag, quadratic: a = 3/8 · Cd · (ρ air / ρ liquid) · v² / r. Water barely
		# feels it; a small drop of liquid hydrogen (14 times lighter) is slowed; none in vacuum
		if air:
			var r: float = radius_m(b.vol)
			var v_ms: float = b.vel.length() / Geom.M
			var dec: float = 0.375 * 0.47 * (1.2 * kpa / 101.0) / float(lk.get("rho", 1000.0)) * v_ms * v_ms / maxf(r, 0.005)
			b.vel = b.vel.move_toward(Vector2.ZERO, dec * Geom.M * dt)
		var step: Vector2 = b.vel * dt
		# a bulb is held on its hole (_bulb places it): nothing to run into
		if _is_bulb(b):
			continue
		var rad: float = _rad(b)
		if near and step.length() > 0.01 and not _clear_way(b.pos, b.pos + step + step.normalized() * rad):
			var q := PhysicsRayQueryParameters2D.create(b.pos, b.pos + step + step.normalized() * rad, World.STATIC_LAYER)
			var hit: Dictionary = _space.intersect_ray(q)
			if not hit.is_empty():
				_hit(b, hit, lk)
				continue
		b.pos = b.pos + step
		# the drone flying through it
		if dr_on and not b.quiet and dr_at.distance_to(b.pos) < rad + 18.0:
			_drone_wet(b, lk)
	if dead or blobs.any(func(b): return float(b.vol) <= 0.0):
		blobs = blobs.filter(func(b): return float(b.vol) > 0.0)


# a globule's radius (px), worked out again only when its volume has changed by 2 %
func _rad(b: Dictionary) -> float:
	var v := float(b.vol)
	var rv := float(b.get("r_vol", -1.0))
	if rv < 0.0 or absf(v - rv) > rv * 0.02:
		b["r_vol"] = v
		b["r_px"] = radius_m(v) * Geom.M
	return float(b.r_px)


# meeting a surface: fast enough, it splashes apart; else it wets the surface and stays
func _hit(b: Dictionary, hit: Dictionary, lk: Dictionary) -> void:
	var nrm: Vector2 = hit.normal
	var vn: float = absf(b.vel.dot(nrm)) / Geom.M
	# a big mass does not shatter on a wall the way a drop does: its surface tension holds it
	var r_m: float = radius_m(float(b.vol))
	if vn > float(lk.get("splash", 2.4)) * (1.0 + r_m * 2.0) and float(b.vol) > 0.0006 and not b.ice:
		var parts := mini(4, 2 + int(vn))
		var refl: Vector2 = b.vel.bounce(nrm) * 0.45
		var v0: float = float(b.vol)
		b.vol = 0.0
		for i in parts:
			_add(hit.position + nrm * 3.0, refl.rotated(randf_range(-0.9, 0.9)) * randf_range(0.5, 1.1), v0 / parts, b.look, b.quiet)
		return
	if b.ice:
		b.vel = b.vel.bounce(nrm) * 0.5
		return
	var p = world.piece_at(hit.position - nrm * 2.0)
	if p == null:
		b.vel = b.vel.bounce(nrm) * 0.3
		return
	b.stuck = p.id
	b.nrm = nrm
	b.loc = world.frame(p).affine_inverse() * (hit.position + nrm * radius_m(b.vol) * Geom.M * 0.4)
	b.pos = world.frame(p) * b.loc
	b.vel = Vector2.ZERO
	_touch(b, p)


# what a globule does to what it lies on (once per piece)
func _touch(b: Dictionary, p) -> void:
	if b.quiet or b.wet.has(p.id) or p.cls != "equip" or not p.intact:
		return
	b.wet[p.id] = true
	var lk: Dictionary = LOOKS.get(b.look, LOOKS.water)
	var size_k: float = clampf(float(b.vol) / 0.01, 0.2, 1.0)
	if bool(lk.get("cryo", false)):
		frost.append([b.pos, 0.0, radius_m(b.vol) * Geom.M * 2.2])
		var before: float = p.cond
		game._dent(p, maxf(0.0, p.cond - p.fragile * 0.25 * size_k), "dv_frost")
		game.note_loss("dv_frost", p.tag, (before - p.cond) * p.value)
	elif b.look != "mud" and game.sys.electric_piece(p) and game.sys.piece_volts(p) > 1.0:
		var before2: float = p.cond
		game._dent(p, maxf(0.0, p.cond - 0.08 * size_k), "dv_wet_short")
		game.note_loss("dv_wet_short", p.tag, (before2 - p.cond) * p.value)
		game.fx.sparks(b.pos, b.nrm if b.nrm != Vector2.ZERO else Vector2.UP, 6, Pal.ink(0.9, 1.6), 140.0, 0.25, 1.2)
		if game.combustion != null:
			game.combustion.spark(b.pos, 0.6)


func _drone_wet(b: Dictionary, lk: Dictionary) -> void:
	if b.wet.has(-1):
		return
	b.wet[-1] = true
	if bool(lk.get("cryo", false)):
		game.hurt_drone(4.0 * clampf(float(b.vol) / 0.01, 0.3, 1.0), b.pos, "frost_hit", "frost", 1.5)
	# it splatters off the drone's shell
	b.vel = (b.pos - game.drone.global_position).normalized() * b.vel.length() * 0.4


# globules close to each other pull together and stop moving apart (cohesion, viscosity);
# touching, they become one: volumes add, momentum is kept
func _merge(step: float = 1.0 / 60.0) -> void:
	var cell := 1.2 * Geom.M
	var grid := {}
	var radii := PackedFloat64Array()
	radii.resize(blobs.size())
	for i in blobs.size():
		var b = blobs[i]
		var key := Vector2i(int(floor(b.pos.x / cell)), int(floor(b.pos.y / cell)))
		if not grid.has(key):
			grid[key] = []
		if b.ice or float(b.t) < 0.5:
			continue
		radii[i] = radius_m(b.vol) * Geom.M
		grid[key].append(i)
	var gone := {}
	for key in grid:
		var neighbours: Array = []
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				neighbours.append_array(grid.get(key + Vector2i(dx, dy), []))
		for i in grid[key]:
			if gone.has(i):
				continue
			var a = blobs[i]
			for j in neighbours:
				if j <= i or gone.has(j):
					continue
				var c = blobs[j]
				if c.look != a.look or a.ice or c.ice:
					continue
				var rsum: float = radii[i] + radii[j]
				var d: Vector2 = c.pos - a.pos
				var dl2 := d.length_squared()
				var reach := rsum * PULL_RANGE
				if dl2 > reach * reach:
					continue
				var rel: Vector2 = c.vel - a.vel
				var free_a: bool = int(a.stuck) < 0 and not _is_bulb(a)
				var free_c: bool = int(c.stuck) < 0 and not _is_bulb(c)
				if not free_a and not free_c and dl2 > (RHO_GAP * rsum) * (RHO_GAP * rsum):
					continue
				var gap := RHO_GAP * rsum
				# flying apart (the pieces of a burst, a splash), or a fast pass: neither pull nor merge
				if int(a.stuck) < 0 and int(c.stuck) < 0 and ((rel.dot(d) > 0.0 and rel.length() > 0.15 * Geom.M) or rel.length() > 1.2 * Geom.M):
					continue
				if dl2 > gap * gap:
					# near but apart: they pull together (surface tension) and their relative
					# motion dies away (viscosity), each as its mass allows
					var dl: float = sqrt(dl2)
					var nd: Vector2 = d / maxf(dl, 0.001)
					var k: float = 1.0 - dl / reach
					var pull: Vector2 = nd * PULL * Geom.M * k * step
					var drag: Vector2 = rel * clampf(DAMP * k * step, 0.0, 0.5)
					var m: float = float(a.vol) + float(c.vol)
					if free_a:
						a.vel += (pull + drag) * float(c.vol) / m * 2.0
					if free_c:
						c.vel -= (pull + drag) * float(a.vol) / m * 2.0
					continue
				# touching (and not parting): they run into one
				var m: float = float(a.vol) + float(c.vol)
				if int(a.stuck) < 0 and int(c.stuck) < 0:
					a.vel = (a.vel * float(a.vol) + c.vel * float(c.vol)) / m
				a.pos = (a.pos * float(a.vol) + c.pos * float(c.vol)) / m
				if int(c.stuck) >= 0 and int(a.stuck) < 0:
					a.stuck = c.stuck
					a.loc = c.loc
					a.nrm = c.nrm
				a.vol = m
				radii[i] = radius_m(m) * Geom.M
				# a bulb swallowing another stays the bulb (it is the one on the hole)
				if _is_bulb(c) and not _is_bulb(a):
					a["bulb_t"] = c.bulb_t
					a["held_t"] = c.held_t
					for lk in game.sys.leaks:
						var bs: Dictionary = lk.get("_bulbs", {})
						for bk in bs:
							if bs[bk] == c:
								bs[bk] = a
				a.t = minf(float(a.t), float(c.t))
				a.quiet = a.quiet and c.quiet
				a.ph = float(a.ph) + 1.3
				gone[j] = true
	if gone.is_empty():
		return
	var keep: Array = []
	for i in blobs.size():
		if not gone.has(i):
			keep.append(blobs[i])
	blobs = keep


func _bulb_of(b):
	return b if _is_bulb(b) else null


# held on its hole: fed by a leak this step or the last (a leak that stops lets it go)
func _is_bulb(b) -> bool:
	return _t - float(b.get("held_t", -1.0)) < 0.05


# ---------------------------------------------------------------- drawing

var _ink

func _draw() -> void:
	var _pd := Time.get_ticks_usec()
	_draw_inner()
	World._ps("liq_draw", _pd)


func _draw_inner() -> void:
	_ink = preload("res://scripts/liquid_draw.gd").new()
	for f in frost:
		var a: float = 0.45 * (1.0 - float(f[1]) / 24.0)
		var c: Vector2 = f[0]
		var sz: float = float(f[2])
		for k in 6:
			var d := Vector2.from_angle(k * TAU / 6.0 + float(c.x) * 0.1)
			_ink.draw_line(c + d * sz * 0.2, c + d * sz, Pal.ink(a), 1.0, false)
			_ink.draw_line(c + d * sz * 0.6, c + d * sz * 0.6 + d.rotated(0.8) * sz * 0.25, Pal.ink(a * 0.7), 1.0, false)
	for j in jets:
		_draw_jet(j)
	# the liquid itself as one surface; ice and what goes on inside a globule drawn here
	if surface == null:
		surface = preload("res://scripts/liquid_surface.gd").new()
		add_child(surface)
		surface.setup(self)
	surface.update(blobs)
	# ice, and what goes on inside a globule big enough on screen to be seen
	var min_r: float = 6.0 / maxf(0.05, game.cam_zoom())
	for b in blobs:
		if b.ice or _rad(b) >= min_r:
			_draw_blob(b)
	_ink.flush(self)


# a leak's jet: a ligament of liquid leaving the hole, necking (Plateau-Rayleigh) and
# pinching off into the drops the globules are; a cryogen's half-flashed to a plume
func _draw_jet(j: Array) -> void:
	var at: Vector2 = j[0]
	var dir: Vector2 = j[1]
	var flow: float = float(j[2])
	var look: String = j[3]
	var cryo: bool = look in CRYO
	var len_px: float = clampf(0.3 + flow * 12.0, 0.3, 1.4) * Geom.M
	var w0: float = clampf(1.5 + flow * 40.0, 1.5, 5.0)
	var nrm := Vector2(-dir.y, dir.x)
	var col := Pal.tint(Pal.FLUID, 0.85, 1.4 if cryo else 1.1)
	var n := 10
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n + 1:
		var f: float = float(k) / n
		# the neck: waves along it growing until it breaks
		var wv: float = w0 * (1.0 - f * 0.55) * (1.0 + 0.35 * f * sin(f * 18.0 - _t * 22.0))
		var c: Vector2 = at + dir * len_px * f
		left.append(c + nrm * wv * 0.5)
		right.append(c - nrm * wv * 0.5)
	# the liquid leaving the hole is the bulb on it (liquid_surface.gd); a cryogen's flash plume
	if cryo:
		for k in 3:
			var f3: float = fposmod(_t * 1.5 + k * 0.33, 1.0)
			_ink.draw_arc(at + dir * len_px * f3 * 1.4 + nrm * sin(f3 * 9.0 + k) * 6.0, 3.0 + f3 * 10.0, 0.0, TAU, 10, Pal.ink(0.12 * (1.0 - f3)), 1.0, false)


func _draw_blob(b: Dictionary) -> void:
	var r: float = maxf(1.6, radius_m(b.vol) * Geom.M)
	var c: Vector2 = b.pos
	var look: String = b.look
	var col := Pal.tint(Pal.FLUID, 0.75, 1.2)
	var w := 1.2
	match look:
		"lhe", "lh2", "lng", "ln2":
			col = Pal.tint(Pal.FLUID, 0.95, 1.6)
			w = 0.9
		"fuel", "mmh":
			col = Pal.tint(Pal.FLUID, 0.8, 1.0)
			w = 1.8
		"nto":
			# nitrogen tetroxide: yellow-orange liquid
			col = Color(0.95, 0.6, 0.28, 0.9)
			w = 1.6
		"mud":
			col = Pal.ink(0.35)
			w = 1.4
	if b.ice:
		# a ball of ice: faceted, still
		var pts := PackedVector2Array()
		for k in 7:
			var a: float = k * TAU / 7.0 + float(b.ph)
			pts.append(c + Vector2.from_angle(a) * r * (0.9 + 0.12 * sin(a * 3.0 + float(b.ph))))
		pts.append(pts[0])
		_ink.draw_polyline(pts, Pal.ink(0.7), 1.1, false)
		_ink.draw_line(pts[0], pts[3], Pal.ink(0.25), 1.0, false)
		_ink.draw_line(pts[1], pts[5], Pal.ink(0.2), 1.0, false)
		return
	# the body and its edge are the liquid surface's (liquid_surface.gd); what moves inside it here
	_details(b, c, r, look, col)


func _details(b: Dictionary, c: Vector2, r: float, look: String, col: Color) -> void:
	var n := 16
	match look:
		"glycol":
			_ink.draw_arc(c, r * 0.78, 0.0, TAU, n, Color(col.r, col.g, col.b, 0.3), 1.0, false)
		"fuel", "mmh", "nto":
			# the oily film swirling inside
			var sw: float = _t * 0.8 + float(b.ph)
			_ink.draw_arc(c, r * 0.55, sw, sw + 2.2, 8, Color(col.r, col.g, col.b, 0.5), 1.0, false)
			_ink.draw_arc(c, r * 0.3, -sw * 1.3, -sw * 1.3 + 1.8, 6, Color(col.r, col.g, col.b, 0.35), 1.0, false)
		"lhe", "lh2", "lng", "ln2":
			# boiling: vapour bubbles nucleating inside and rising out of it
			for k in 3:
				var bp: Vector2 = c + Vector2.from_angle(float(b.ph) * 3.0 + k * 2.1 + _t * 2.0) * r * fposmod(_t * 0.9 + k * 0.33, 1.0) * 0.8
				_ink.draw_arc(bp, maxf(0.8, r * 0.12), 0.0, TAU, 6, Pal.ink(0.5), 1.0, false)
		"mud":
			for k in mini(8, int(r * 0.6)):
				var gp: Vector2 = c + Vector2.from_angle(k * 2.4 + float(b.ph)) * r * fposmod(k * 0.37, 0.8)
				_ink.draw_rect(Rect2(gp, Vector2(1.4, 1.4)), Pal.ink(0.5))
