extends Node
# Superconducting magnets (FX-70 "Fusion Core", design/ships/02_新设计十艘_设计稿.md:
# "eight coil packs hold stored energy, run down slowly through the dump resistor with
# the dump switch closed and the cooling kept on; lose the cooling and the coils warm
# past their critical temperature and quench: the energy comes out at once, wrecking
# the coil and what is near it, and spreads to the coils beside it; cutting or freeing
# a coil's supports while it is energised quenches it too; the liquid helium is dear").
# A ship file's "supercon" (not "magnets": that is scripts/mech.gd's):
#   {"coils": {piece: {"next": [the coils beside it], "fix": [its supports], "line":
#    its helium line}}, "dump": the dump switch, "tau": seconds the dump takes to bring
#    the energy down by e, "plant": the cryoplant's cold box (it needs power), "he": the
#    liquid helium's volume, "he_min": what still cools, "T0": K, "Tc": K, "warm": K/s
#    without cooling, "cool": K/s back down with it, "safe": the energy fraction below
#    which a coil warms up harmlessly, "reach": metres a quench damages around it,
#    "boil": the helium fraction a quench boils off}
#   A coil quenches when it is above its critical temperature, or its supports are cut
#   or freed, or it is freed itself, while it holds more than "safe" of its energy.
#   A quench: the coil wrecked, equipment within reach damaged by how much energy it
#   held, helium boiled off, and the coils beside it quench a moment later if they
#   are still energised.
# Saved: each coil's energy and temperature, which quenched.
#   87-2: the field is drawn as it is. Round each energised coil its flux loops, as wide and as
#   bright as the energy still in it, creeping round the slower the less is left; with the dump
#   switch closed the dump resistor glows with the power going into it (the energy's fall per
#   second), cooling as the coils run down. A quench: the coil's loops collapse into it in a
#   moment, a flash of arcs, the field gone.

const WRECK_KEEP := 0.25
const SPREAD_T := 0.6            # s from one coil's quench to its neighbours'

var game
var world
var cfg := {}
var energy := {}                 # coil -> fraction of its stored energy left
var temp := {}                   # coil -> K
var quenched := {}
var _pending := {}               # coil -> time left before it quenches (spreading)
var _support_of := {}            # support piece tag -> its coil
var overlay: Node2D
var _collapse := {}              # coil -> seconds since it quenched (its field falling in)
var dump_power := 0.0            # 87-2: fraction of the full stored energy going into the dump a second
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("supercon", {})
	for c in cfg.get("coils", {}):
		energy[c] = 1.0
		temp[c] = float(cfg.get("T0", 4.5))
		for f in cfg.coils[c].get("fix", []):
			_support_of[str(f)] = str(c)
	if active():
		overlay = Node2D.new()
		overlay.z_index = 3
		overlay.z_as_relative = false
		overlay.draw.connect(_draw_field)
		world.add_child(overlay)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"energy": energy, "temp": temp, "quenched": quenched.keys(), "res_lost": _res_lost}


func load_state(d: Dictionary) -> void:
	for c in d.get("energy", {}):
		energy[str(c)] = float(d.energy[c])
	for c in d.get("temp", {}):
		temp[str(c)] = float(d.temp[c])
	for c in d.get("quenched", []):
		quenched[str(c)] = true
	_res_lost = bool(d.get("res_lost", false))


func field() -> float:
	var s := 0.0
	for c in energy:
		s += float(energy[c])
	return s / maxf(1, energy.size()) * 100.0


func max_temp() -> float:
	var t := 0.0
	for c in temp:
		t = maxf(t, float(temp[c]))
	return t


func energised(c: String) -> bool:
	return float(energy.get(c, 0.0)) > float(cfg.get("safe", 0.05)) and not quenched.has(c)


func any_energised() -> bool:
	return energy.keys().any(func(c): return energised(str(c)))


func cooled(c: String) -> bool:
	var plant = world.tag(str(cfg.get("plant", "")))
	if plant == null or plant.gone or plant.body != null or not plant.intact or game.sys.piece_volts(plant) < 1.0:
		return false
	if game.sys.fluid(str(cfg.get("he", ""))) < float(cfg.get("he_min", 0.03)):
		return false
	var ln: String = str(cfg.coils[c].get("line", ""))
	if ln != "" and world.lines.has(ln) and not world.lines[ln].alive:
		return false
	return true


func unsafe() -> Array:
	var out: Array = []
	for c in energy:
		if energised(str(c)):
			out.append("coil %s energised (%.0f %%)" % [c, float(energy[c]) * 100.0])
	return out


# for tests/salvage_bot.gd: the dump switch closed first, with the cooling still on
func bot_prep() -> Array:
	var d: String = str(cfg.get("dump", ""))
	if any_energised() and d != "" and not game.sys.on(d):
		return [[d, "magnet dump closed", 2.0]]
	return []


# for tests/salvage_bot.gd: the helium stays in while a coil still holds its energy
func hold_port(id: String) -> bool:
	if not any_energised():
		return false
	return game.sys.fluid_at_port(id) == str(cfg.get("he", ""))


# for tests/salvage_bot.gd: the cryoplant keeps its power while a coil does
func hold_power() -> bool:
	return any_energised()


# the dump resistor (cx_dump_res_b; second codex round): the piece the dump switch sends the
# coils' current into. "resistor" in the ship file, else the piece drawn as one
var _res = null
var _res_lost := false


func _resistor():
	if _res == null:
		var t: String = str(cfg.get("resistor", ""))
		if t != "":
			_res = world.tag(t)
		if _res == null:
			for id in world.order:
				var p = world.pieces[id]
				if p.cls == "equip" and Codex.art_of(p) == "dump_res":
					_res = p
					break
	return _res


# is there still a path for the dump: the resistor whole and in its place
func dump_path() -> bool:
	var r = _resistor()
	return r == null or (not r.gone and r.intact and r.body == null)


func _physics_process(dt: float) -> void:
	if not active():
		return
	var dumping: bool = game.sys.on(str(cfg.get("dump", "")))
	# the book: the resistor taken out while the coils still hold their field leaves them no
	# way to shed it; opened under a running dump the current has nowhere to go and every
	# coil still energised quenches
	if not _res_lost and not dump_path():
		_res_lost = true
		if any_energised():
			var r = _resistor()
			game.incident("dump_res_lost", r.tag if r != null else "")
			if dumping:
				for c in energy:
					if energised(c):
						_quench(c, "magnet_quench_dump")
			else:
				var at: Vector2 = world.frame(r) * Geom.centroid(r.poly) if r != null else Vector2.ZERO
				game.say("dump_res_gone", at)
	if _res_lost:
		dumping = false
	var tau: float = maxf(1.0, float(cfg.get("tau", 35.0)))
	var tc: float = float(cfg.get("Tc", 9.0))
	var t0: float = float(cfg.get("T0", 4.5))
	var before := 0.0
	var after := 0.0
	for c in energy:
		if quenched.has(c):
			continue
		before += float(energy[c])
		if dumping:
			energy[c] = float(energy[c]) * exp(-dt / tau)
		after += float(energy[c])
		if cooled(c):
			temp[c] = maxf(t0, float(temp[c]) - float(cfg.get("cool", 0.2)) * dt)
		else:
			temp[c] = float(temp[c]) + float(cfg.get("warm", 0.04)) * dt
		if float(temp[c]) > tc and energised(c):
			_quench(c, "magnet_quench_warm")
	dump_power = (before - after) / maxf(dt, 0.0001) / maxf(1.0, float(energy.size()))
	for c in _collapse.keys():
		_collapse[c] = float(_collapse[c]) + dt
		if float(_collapse[c]) > 0.8:
			_collapse.erase(c)
	for c in _pending.keys():
		_pending[c] = float(_pending[c]) - dt
		if float(_pending[c]) <= 0.0:
			_pending.erase(c)
			if energised(c):
				_quench(c, "magnet_quench_spread")


func on_cut(p) -> void:
	if not active() or p == null:
		return
	var c: String = _support_of.get(p.tag, p.tag if cfg.get("coils", {}).has(p.tag) else "")
	if c != "" and energised(c):
		_quench(c, "magnet_quench_cut")


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		var c: String = _support_of.get(q.tag, q.tag if cfg.get("coils", {}).has(q.tag) else "")
		if c != "" and energised(c):
			_quench(c, "magnet_quench_cut")


func _quench(c: String, why: String) -> void:
	if quenched.has(c):
		return
	quenched[c] = true
	_collapse[c] = 0.0
	var e: float = float(energy[c])
	energy[c] = 0.0
	temp[c] = maxf(float(temp[c]), 80.0)
	var coil = world.tag(c)
	if coil == null:
		return
	var at: Vector2 = world.frame(coil) * Geom.centroid(coil.poly)
	var lost := 0.0
	if coil.intact:
		var b0: float = coil.cond
		game._dent(coil, minf(coil.cond, WRECK_KEEP), "dv_magnet_quench")
		lost += (b0 - coil.cond) * coil.value
	var reach: float = float(cfg.get("reach", 6.0)) * Geom.M
	for p in game._equip_near(at, reach):
		if p == coil or p.gone or not p.intact or cfg.coils.has(p.tag):
			continue
		var before: float = p.cond
		var k: float = 1.0 - clampf(at.distance_to(world.frame(p) * Geom.centroid(p.poly)) / reach, 0.0, 1.0)
		game._dent(p, maxf(0.0, p.cond - p.fragile * 0.8 * e * k), "dv_magnet_quench")
		lost += (before - p.cond) * p.value
	# the coil's helium flashes off through the relief
	var hv: String = str(cfg.get("he", ""))
	if game.sys.fvol.has(hv):
		game.sys.fvol[hv].amount = maxf(0.0, float(game.sys.fvol[hv].amount) * (1.0 - float(cfg.get("boil", 0.25))))
	for n in cfg.coils[c].get("next", []):
		if energised(str(n)) and not _pending.has(str(n)):
			_pending[str(n)] = SPREAD_T
	# the helium in the coil's channels flashes out as boiling liquid
	if game.liquids != null:
		game.liquids.spill(at, Vector2.ZERO, 0.05, "lhe", 10, TAU, 2.5, true)
	game.fx.flash(at, 5.0 * Geom.M, 0.5, Pal.heat(1.0, 2.0))
	game.fx.sparks(at, Vector2.UP, 30, Pal.heat(1.0, 2.0), 360.0, 0.5, PI)
	game.shake(0.35)
	game.sfx.play("boom", at, 0.7)
	game.incident("magnet_quench", c)
	game.say(why, at, c)
	game.note_loss("loss_magnet_quench", c, lost)


func _process(dt: float) -> void:
	if overlay == null:
		return
	_t += dt
	if any_energised() or not _collapse.is_empty() or dump_power > 0.0001:
		overlay.queue_redraw()


func _coil_at(c: String) -> Array:
	var p = world.tag(c)
	if p == null or p.gone:
		return []
	var poly: PackedVector2Array = world.world_poly(p)
	var bb := Geom.bbox(poly)
	return [Geom.centroid(poly), bb.size]


# 87-2: flux loops round each coil (an ellipse along the coil, a few nested), dashed, the dashes
# creeping round at a speed set by the energy left; the dump resistor's glow; a quench's collapse
var draw_us := 0               # what the last redraw of the field took (µs)

func _draw_field() -> void:
	var t0 := Time.get_ticks_usec()
	for c in energy:
		var at := _coil_at(str(c))
		if at.is_empty():
			continue
		var centre: Vector2 = at[0]
		var size: Vector2 = at[1]
		var e := float(energy[c])
		if not quenched.has(c) and e > 0.01:
			var grow := sqrt(e)
			for k in 3:
				var rx := (size.x * 0.5 + (0.9 + 0.9 * k) * Geom.M * grow)
				var ry := (size.y * 0.5 + (0.9 + 0.9 * k) * Geom.M * grow)
				var phase := _t * (0.4 + 1.6 * e) * (1.0 if k % 2 == 0 else -1.0)
				_dashed_ellipse(centre, Vector2(rx, ry), phase, Pal.ink((0.07 + 0.2 * e) * (1.0 - 0.25 * k)), 1.2)
		if _collapse.has(c):
			var t := float(_collapse[c]) / 0.8
			var r := (1.0 - t) * 3.0 * Geom.M
			_dashed_ellipse(centre, Vector2(size.x * 0.5 + r, size.y * 0.5 + r), 0.0, Pal.heat(0.8 * (1.0 - t), 2.0), 2.4)
			for i in 5:
				var a0 := float(i) * 1.26 + t * 9.0
				var p0 := centre + Vector2.from_angle(a0) * (size.length() * 0.3 + r)
				var p1 := centre + Vector2.from_angle(a0 + 0.4) * (size.length() * 0.2)
				overlay.draw_line(p0, p1, Color(2.0, 2.0, 2.4, 0.7 * (1.0 - t)), 1.4, true)
	# the dump resistor glows with what is going into it
	var dc = world.ctrls.get(str(cfg.get("dump", "")))
	if dc != null and dump_power > 0.0001:
		var host = world.pieces.get(dc.piece)
		var pos: Vector2 = (world.frame(host) * dc.pos) if host != null else dc.pos
		var k := clampf(dump_power * float(cfg.get("tau", 35.0)), 0.0, 1.0)
		var tex: Texture2D = game.fx.glow_tex
		var r := (0.6 + 1.6 * k) * Geom.M
		overlay.draw_texture_rect(tex, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.heat(0.55 * k, 1.0 + 1.6 * k))
	draw_us = Time.get_ticks_usec() - t0


func _dashed_ellipse(c: Vector2, r: Vector2, phase: float, col: Color, w: float) -> void:
	var n := 40
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * float(i) / n + phase
		var a1 := TAU * float(i + 1) / n + phase
		overlay.draw_line(c + Vector2(cos(a0) * r.x, sin(a0) * r.y), c + Vector2(cos(a1) * r.x, sin(a1) * r.y), col, w, true)
