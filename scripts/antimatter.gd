extends Node2D
# AX-40 逆火 · the antimatter trap (design/新船点子_10艘_详细版_20261111.md §4; user 2026-11-11: "反物质
# 要设计成核弹一样，只要一断电，正反物质马上爆炸"). A ship file's "antimatter":
#   {"trap": piece, "switch": the main switch, "supply": the magnet supply, "bus": the switchboard,
#    "source": the battery, "lines": [the chain's cables], "panel": the readout, "probe": its test
#    point, "near": m}
# The trap's confinement runs on the main bus only: no backup battery, no count. Whatever takes its
# power away — the main switch thrown, the beam through a cable of the chain or into the switchboard
# or the supply, the supply's connector pulled, the battery taken out or blown — and the trap
# annihilates there and then (scripts/annihilation.gd). The one way round it: the portable
# confinement supply (scripts/gear.gd "confine", lent with the ship) put on the trap; once it has
# taken up the load (CONNECT_T) the trap reads "dual supply" and the bus may go. The beam into the
# trap itself annihilates it whatever feeds it.
# The chain carries its warning all the time ("断电即湮灭"), on the trap, the switch, the supply and
# the battery; the beam, or the wrench's pointer, this close to any of it (near, as the reactor's
# 1.5 m) and the whole chain flares, a line said once, a warning sound every time.
# The trap breathes: a ring of blue-white segments round its sphere, slow while it is confined.
# Saved: whether it has gone (annihilated or delivered).

const Anni = preload("res://scripts/annihilation.gd")
const RING_R := 1.9           # m: the trap's indicator ring (the annihilation's starts from the same)
const CONNECT_T := 2.0        # s: the portable supply taking up the coils' load

var game
var world
var cfg := {}
var trap = null
var armed := false            # the trap has been seen confined (no verdicts before the ship is live)
var done := ""                # "", "annihilated", "delivered"
var _warn_k := 0.0
var _near_t := -99.0
var _told := false
var _t := 0.0
var _chain_lines: Array = []
var _key := []
var mark: Node2D              # the chain and its tags: drawn again only when they change (60 FPS)
var _watch_t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("antimatter", {})
	if cfg.is_empty():
		return
	trap = world.tag(str(cfg.get("trap", "")))
	z_index = 9
	z_as_relative = false
	mark = Node2D.new()
	mark.z_index = 9
	mark.z_as_relative = false
	mark.draw.connect(_draw_mark)
	add_child(mark)
	for id in cfg.get("lines", []):
		_chain_lines.append(str(id))
	preload("res://scripts/guide_cards.gd").note("antimatter_trap")
	# the spectrum is baked off the main thread while the ship is looked over, its material warmed
	Anni.prebake()
	if not (game.bot != null and game.bot.get("no_warm", false)):
		Anni.warm.call_deferred(game)


static func _w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func active() -> bool:
	return not cfg.is_empty()


func _exit_tree() -> void:
	if not cfg.is_empty():
		Anni.release()


func is_trap(p) -> bool:
	return trap != null and p == trap


# ---------------------------------------------------------------- what feeds it

func main_volts() -> float:
	if trap == null or trap.gone or not trap.intact:
		return 0.0
	# the grid carries power through any piece a live cable reaches; the chain is stricter: the beam
	# through the magnet supply, the switchboard or the battery takes the trap's power with it
	for k in ["supply", "bus", "source"]:
		var q = world.tag(str(cfg.get(k, "")))
		if q == null or q.gone or not q.intact:
			return 0.0
	return float(game.sys.piece_volts(trap))


func _unit() -> Dictionary:
	if game.gear == null or trap == null:
		return {}
	for u in game.gear.units:
		if u.type == "confine" and int(u.piece) == trap.id:
			return u
	return {}


# the portable supply on the trap and carrying it (0..1 while it takes up the load)
func portable_k() -> float:
	var u := _unit()
	if u.is_empty():
		return 0.0
	return clampf(float(u.get("t", 0.0)) / CONNECT_T, 0.0, 1.0)


func portable() -> bool:
	return portable_k() >= 1.0


# for wait conditions ({"mod": ["anti", "dual", ">", 0.5]}): the portable supply carrying it
func dual() -> float:
	return 1.0 if portable() else 0.0


func fed() -> bool:
	return main_volts() > 1.0 or portable()


# what the readout says: [value, text]
func reading() -> Array:
	if done == "delivered":
		return [0.0, _w("已送走", "DELIVERED")]
	var m := main_volts() > 1.0
	var p := portable()
	if m and p:
		return [2.0, _w("约束正常 · 双路供电 · 可以断主电", "CONFINED · DUAL SUPPLY · MAIN MAY GO")]
	if p:
		return [1.0, _w("约束正常 · 便携电源供电", "CONFINED · PORTABLE SUPPLY")]
	if m:
		return [1.0, _w("约束正常 · 主电单路 · 断电即湮灭", "CONFINED · MAIN ONLY · LOSE IT AND IT ANNIHILATES")]
	return [0.0, _w("无约束", "UNCONFINED")]


# ---------------------------------------------------------------- the verdict, every step

func _physics_process(dt: float) -> void:
	if cfg.is_empty() or trap == null or done != "":
		return
	if game.state != "play" or game.ended:
		return
	if trap.gone:
		done = "delivered"
		return
	if not armed:
		armed = fed()
		return
	if not fed():
		annihilate("power")


func annihilate(why: String) -> void:
	if done != "" or trap == null:
		return
	done = "annihilated"
	game.incident("annihilation", why)
	game.start_annihilation(world.frame(trap) * Geom.centroid(trap.poly))


func on_cut(p) -> void:
	if done == "" and is_trap(p):
		annihilate("cut")


func on_freed(_b) -> void:
	pass


func save_state() -> Dictionary:
	return {"done": done, "armed": armed}


func load_state(d: Dictionary) -> void:
	done = str(d.get("done", ""))
	armed = bool(d.get("armed", false))


# ---------------------------------------------------------------- the chain and its warning

# the pieces whose loss takes the trap's power (only the trap itself once the portable supply carries it)
func chain_pieces() -> Array:
	var out: Array = []
	if trap == null:
		return out
	out.append(trap)
	if portable():
		return out
	for k in ["supply", "bus", "source"]:
		var p = world.tag(str(cfg.get(k, "")))
		if p != null and not p.gone:
			out.append(p)
	return out


func chain_lines() -> Array:
	if portable():
		return []
	var out: Array = []
	for l in world.lines.values():
		if l.alive and str(l.id) in _chain_lines:
			out.append(l)
	return out


func _near_chain(at: Vector2, r: float) -> bool:
	for q in chain_pieces():
		var lp: Vector2 = world.frame(q).affine_inverse() * at
		if Geometry2D.is_point_in_polygon(lp, q.poly) or Geom.dist_to_boundary(lp, q.poly) < r:
			return true
	for l in chain_lines():
		var path: PackedVector2Array = world.line_path_world(l)
		for i in path.size() - 1:
			if Geometry2D.get_closest_point_to_segment(at, path[i], path[i + 1]).distance_to(at) < r:
				return true
	if not portable():
		var sw = world.ctrls.get(str(cfg.get("switch", "")))
		if sw != null and world.ctrl_world(sw).distance_to(at) < r:
			return true
	return false


func _process(dt: float) -> void:
	if cfg.is_empty() or trap == null:
		return
	_t += dt
	_warn_k = maxf(0.0, _warn_k - dt / 1.6)
	_watch_t += dt
	if _watch_t >= 0.1 and done == "" and game.state == "play" and not game.paused_sim and not game.menu_open:
		_watch_t = 0.0
		_watch()
	queue_redraw()
	# the chain and its tags (text, every cable's path) only when something about them changed
	var key: Array = [snappedf(game.cam_zoom(), 0.0001), snappedf(_warn_k, 0.05), portable(), done, str(reading()[1]), trap.gone]
	if not trap.gone:
		key.append((world.frame(trap) * Geom.centroid(trap.poly)).snapped(Vector2(0.5, 0.5)))
	if key != _key:
		_key = key
		mark.queue_redraw()


# the beam, or the wrench's pointer, close to the chain: the chain flares, a warning
func _watch() -> void:
	var tl = game.tools
	if tl == null:
		return
	var at := Vector2.INF
	if tl.cutting:
		at = tl.front
	elif tl.tool == 2:
		at = tl.aim
	if at == Vector2.INF:
		return
	if not _near_chain(at, float(cfg.get("near", 1.5)) * Geom.M):
		return
	_warn_k = 1.0
	var now := Time.get_ticks_msec() / 1000.0
	if now - _near_t < 2.5:
		return
	_near_t = now
	if not _told:
		_told = true
		game.say("anti_near", at)
	game.sfx.play("warn")


# ---------------------------------------------------------------- drawing (world space, over the ship)

func _draw() -> void:
	if cfg.is_empty() or trap == null or trap.gone or done == "annihilated":
		return
	var z: float = maxf(0.02, game.cam_zoom())
	var s := 1.0 / z
	var c: Vector2 = world.frame(trap) * Geom.centroid(trap.poly)
	var tex: Texture2D = game.fx.glow_tex if game.fx != null else null
	var k := 0.5 + 0.5 * sin(_t * 1.6)
	# the breathing ring: 18 blue-white segments round the sphere
	var col := Color(0.45 + 0.25 * k, 0.9 + 0.3 * k, 1.35 + 0.35 * k, 1.0)
	for i in 18:
		var a0 := TAU * i / 18.0 - PI * 0.5
		draw_arc(c, RING_R * Geom.M, a0, a0 + TAU / 18.0 * 0.78, 6, col, maxf(2.0, 3.0 * s * 0.6))
	if tex != null:
		var gr := RING_R * Geom.M * (1.25 + 0.08 * k)
		draw_texture_rect(tex, Rect2(c - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(0.35, 0.7, 1.2, 0.10 + 0.06 * k))


func _draw_mark() -> void:
	if cfg.is_empty() or trap == null or trap.gone or done == "annihilated":
		return
	var z: float = maxf(0.02, game.cam_zoom())
	var s := 1.0 / z
	var c: Vector2 = world.frame(trap) * Geom.centroid(trap.poly)
	# the chain: its cables traced, brighter as the warning flares
	var warn := _warn_k
	var hot := Color(1.6, 0.42, 0.25, 0.35 + 0.6 * warn)
	for l in chain_lines():
		var path: PackedVector2Array = world.line_path_world(l)
		if path.size() >= 2:
			mark.draw_polyline(path, Color(hot.r, hot.g, hot.b, hot.a * 0.8), (1.5 + 2.0 * warn) * s, true)
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var tag_t := _w("断电即湮灭", "NO POWER = ANNIHILATION")
	for q in chain_pieces():
		var qc: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		var bb := Geom.bbox(world.world_poly(q))
		var at := Vector2(qc.x, bb.position.y) + Vector2(0, -6.0 * s)
		if q == trap:
			at = c + Vector2(0, -(RING_R + 0.9) * Geom.M)
			var r: Array = reading()
			var head := _w("储存阱 · %s", "TRAP · %s") % str(r[1])
			_tag(font, at + Vector2(0, -20.0 * s), head, s, Pal.ink(0.95), 15)
		elif warn <= 0.0 and z < 0.35:
			continue
		_tag(font, at, tag_t, s, Color(1.6, 0.42, 0.25, 0.95).lerp(Color(2.4, 2.2, 2.0, 1.0), 0.6 * warn), 14)
	if not portable():
		var sw = world.ctrls.get(str(cfg.get("switch", "")))
		if sw != null:
			var sp: Vector2 = world.ctrl_world(sw)
			mark.draw_arc(sp, (10.0 + 6.0 * warn) * s, 0.0, TAU, 24, hot, (1.4 + warn) * s, true)


func _tag(font: Font, at: Vector2, text: String, s: float, col: Color, size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	mark.draw_set_transform(at, 0.0, Vector2(s, s))
	mark.draw_rect(Rect2(Vector2(-w * 0.5 - 6, -size - 2), Vector2(w + 12, size + 8)), Color(0.03, 0.032, 0.036, 0.85))
	mark.draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the salvage bot (tests/salvage_bot.gd)

func bot_prep() -> Array:
	return []


func unsafe() -> Array:
	return []


# a plate taken off to get in (a part-ship job's roof plates) carries whatever is bolted under it —
# a lamp, a cold head, the comms box — and that one's cable, still plugged in at the other end,
# tears the plug out of the rack there (contract runs 007-AX-68/-95/-32): those come off first,
# their cables unplugged, and anything wired comes off before the plates
func bot_order(order: Array) -> Array:
	# the bus is dead and the trap on its portable supply by now: every cable on the ship is unplugged
	# first, as a careful hand would — the bridge's rack has six of them, and whichever plate or box
	# goes first, one of them would otherwise tear its plug out
	if portable() and game.sys != null and not game.sys.bus_live:
		for l in world.lines.values():
			if l.alive and l.kind == "cable":
				world.kill_line(l)
	var out: Array = []
	var seen := {}
	for id in order:
		var p = world.pieces.get(id)
		if p == null:
			continue
		if p.cls != "equip":
			for j in world.joints_of(p):
				var other: int = j.b if j.a == p.id else j.a
				var q = world.pieces.get(other)
				if q != null and not q.gone and q.body == null and q.id != p.id and not seen.has(q.id) and not world.lines_of(q).is_empty() and not order.has(q.id):
					seen[q.id] = true
					out.append(q.id)
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	# the wired fixtures (lamps) first of all: the bot leaves structure under loose equipment alone
	# for a while, and a lamp left on its roof plate goes with it
	var lamps: Array = out.filter(func(i): return world.pieces[i].cls != "equip" and not world.lines_of(world.pieces[i]).is_empty())
	var wired: Array = out.filter(func(i): return world.pieces[i].cls == "equip" and not world.lines_of(world.pieces[i]).is_empty())
	return lamps + wired + out.filter(func(i): return world.lines_of(world.pieces[i]).is_empty())


# the main bus is kept until the portable supply carries the trap
func hold_power() -> bool:
	return done == "" and trap != null and not trap.gone and not portable()
