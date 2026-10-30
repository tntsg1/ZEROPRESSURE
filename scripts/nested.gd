extends Node2D
# A ship carried inside a ship (LC-140 "Shell Mountain", design/ships/02_新设计十艘_设计稿.md:
# "the contract wants the small ship out whole, priced as one, far above its parts:
# make it safe first (its battery, its fuel, its air), then the cradle locks from the
# stern forward, the bow door open, and out it slides along the cradle; cut any of its
# hull and it is only parts").
# A ship file's "nested":
#   {"pieces": [every piece of the small ship], "hull": [its hull pieces], "room": its
#    cabin, "battery": its battery switch (safe open), "fuel": its fuel volume, "locks":
#    [the cradle lock switches, the stern's first], "door": the hold's bow door piece,
#    "door_ctrl": its control, "winch": the winch switch, "winch_piece": the winch (it
#    needs power), "bonus": what the ship pays whole over its parts, "lurch_keep": the
#    bonus kept after it lurched into the door, "lurch_dent": what its equipment keeps,
#    "exit": [dx, dy] m it slides out by, "time": s}
#   A bow-side lock released while one aft of it still holds: the ship pivots on it
#   and lurches into the bow door (the bonus cut, its fittings knocked).
#   A hull piece cut or taken off: it is no longer whole (no bonus).
#   The winch thrown with the ship ready: it goes out whole, paid as one.
# Saved: whole, lurched, out.
#   98 号 (user 2026-10-28): the way out is real geometry: anything of the carrier's still in the
#   path the ship sweeps to the exit (bar the bow door, which is its own blocker) stops the winch,
#   and those pieces are outlined red. By the cradle: the four locks along the ship's keel, each
#   with its number in the order they come off and open or shut, the next one marked; the way out
#   as a dashed outline. Going out: the ship itself rolls out along the cradle on the winch's
#   cable (taking up, rolling steady, easing off), the rollers turning, then it is gone.

var game
var world
var cfg := {}
var whole := true
var lurched := false
var out := false
var _released := {}
var _winch_was := false
var _ghost: Array = []         # [world polygon] of the ship as it went
var _ghost_t := -1.0
var _hull := {}
var _mine := {}
const FastDraw = preload("res://scripts/fast_draw.gd")
var _block: Array = []          # 98 号: the carrier's pieces in the way out (ids)
var _block_t := 0.0
var _tag_t := 0.0
var _ghost_eq: Array = []       # per ghost polygon: is it equipment (drawn lighter)
var _rollers: Array = []        # world px under the keel, where the cradle's rollers are
var _winch_at := Vector2.ZERO
var _roll_d := 0.0              # px the ship has travelled (the rollers turn by it)


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("nested", {})
	z_index = 30
	for t in cfg.get("hull", []):
		_hull[str(t)] = true
	for t in cfg.get("pieces", []):
		_mine[str(t)] = true


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"whole": whole, "lurched": lurched, "out": out, "released": _released.keys()}


func load_state(d: Dictionary) -> void:
	whole = bool(d.get("whole", true))
	lurched = bool(d.get("lurched", false))
	out = bool(d.get("out", false))
	for k in d.get("released", []):
		_released[str(k)] = true


# 1 once the small ship is out (the special course's test)
func is_out() -> float:
	return 1.0 if out else 0.0


func _on(id: String) -> bool:
	return game.sys.on(id)


func locks_held() -> Array:
	return cfg.get("locks", []).filter(func(l): return _on(str(l)))


func hazards() -> Array:
	var out_h: Array = []
	if str(cfg.get("battery", "")) != "" and _on(str(cfg.battery)):
		out_h.append("battery")
	if game.sys.fluid(str(cfg.get("fuel", ""))) > 0.02:
		out_h.append("fuel")
	if game.sys.P(str(cfg.get("room", ""))) > 5.0:
		out_h.append("air")
	return out_h


func door_open() -> bool:
	var d = world.tag(str(cfg.get("door", "")))
	return d == null or d.gone or d.door_open


func _winch_live() -> bool:
	var p = world.tag(str(cfg.get("winch_piece", "")))
	return p != null and not p.gone and p.body == null and game.sys.piece_volts(p) > 1.0


# what still stands between the ship and the winch
func blockers() -> Array:
	var b: Array = []
	b.append_array(hazards())
	if not locks_held().is_empty():
		b.append("locks")
	if not door_open():
		b.append("door")
	if not _winch_live():
		b.append("winch")
	if not exit_block().is_empty():
		b.append("exit")
	return b


# 98 号: the carrier's pieces still in the path the ship sweeps out to the exit (not the bow door,
# not the ship's own), by real overlap (a touch along an edge, the cradle under it, is no block);
# looked at twice a second
func exit_block() -> Array:
	if out or not active():
		return []
	if _block_t > 0.0:
		return _block
	_block_t = 0.5
	_block = []
	var e: Array = cfg.get("exit", [-60.0, 0.0])
	var ev := Vector2(float(e[0]), float(e[1])) * Geom.M
	var sweeps: Array = []
	var bb := Rect2()
	var first := true
	for t in cfg.get("hull", []):
		var p = world.tag(str(t))
		if p == null or p.gone:
			continue
		var wp: PackedVector2Array = world.world_poly(p)
		var pts := PackedVector2Array()
		for v in wp:
			pts.append(v)
			pts.append(v + ev)
		sweeps.append(Geometry2D.convex_hull(pts))
		var r := Geom.bbox(wp)
		bb = r if first else bb.merge(r)
		first = false
	if sweeps.is_empty():
		return _block
	var reach := bb.merge(Rect2(bb.position + ev, bb.size))
	var door := str(cfg.get("door", ""))
	var min_a := 0.05 * Geom.M * Geom.M
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or _mine.has(str(q.tag)) or str(q.tag) == door:
			continue
		var qp: PackedVector2Array = world.world_poly(q)
		if not Geom.bbox(qp).intersects(reach):
			continue
		for sw in sweeps:
			var a := 0.0
			for ip in Geometry2D.intersect_polygons(sw, qp):
				a += absf(Geom.area(ip))
			if a > min_a:
				_block.append(id)
				break
	return _block


func unsafe() -> Array:
	return [] if out else ["the small ship still aboard (%s)" % ", ".join(blockers())]


# for tests/salvage_bot.gd: its battery off, the locks from the stern, the bow door once
# the hold is empty of air, then the winch
func bot_prep() -> Array:
	if out:
		return []
	var bat: String = str(cfg.get("battery", ""))
	if bat != "" and _on(bat):
		return [[bat, "the small ship's battery off", 2.0]]
	for l in cfg.get("locks", []):
		if _on(str(l)):
			return [[str(l), "cradle lock %s released" % l, 2.0]]
	if not hazards().is_empty():
		return []
	var hold: String = str(cfg.get("hold", ""))
	if not door_open() and (hold == "" or game.sys.P(hold) < 5.0):
		return [[str(cfg.get("door_ctrl", "")), "the bow door open", 3.0]]
	if blockers().is_empty() and not _on(str(cfg.get("winch", ""))):
		return [[str(cfg.get("winch", "")), "winch the small ship out", 3.0]]
	return []


func hold_power() -> bool:
	return not out


func _physics_process(dt: float) -> void:
	if not active():
		return
	_block_t -= dt
	if _ghost_t >= 0.0:
		var before := travel()
		_ghost_t += dt
		_roll_d += absf(travel() - before)
		queue_redraw()
		if _ghost_t > float(cfg.get("time", 12.0)) + FADE_T:
			_ghost_t = -1.0
			_ghost = []
	if out:
		return
	# the tags by the cradle: four times a second
	_tag_t += dt
	if _tag_t > 0.25:
		_tag_t = 0.0
		queue_redraw()
	var locks: Array = cfg.get("locks", [])
	for i in locks.size():
		var l: String = str(locks[i])
		if _released.has(l) or _on(l):
			continue
		_released[l] = true
		# a lock let go while one aft of it still holds: the ship pivots on that one
		for j in i:
			if _on(str(locks[j])):
				_lurch(l)
				break
	var wn: String = str(cfg.get("winch", ""))
	var won: bool = _on(wn)
	if won and not _winch_was:
		var why := blockers()
		if why.is_empty():
			_extract()
		else:
			var c = world.ctrls.get(wn)
			game.say("nested_not_ready", world.ctrl_world(c) if c != null else Vector2.ZERO, ", ".join(why.map(func(k): return game.txt("nb_" + k))))
			game.sfx.play("deny")
	_winch_was = won


func _lurch(by: String) -> void:
	if lurched:
		return
	lurched = true
	var lost := 0.0
	var keep: float = float(cfg.get("lurch_dent", 0.5))
	var at := Vector2.ZERO
	for t in _mine:
		var p = world.tag(t)
		if p == null or p.gone or p.body != null or p.cls != "equip" or not p.intact:
			continue
		var before: float = p.cond
		game._dent(p, maxf(0.0, p.cond - p.fragile * (1.0 - keep)), "dv_nested_lurch")
		lost += (before - p.cond) * p.value
		at = world.frame(p) * Geom.centroid(p.poly)
	if whole:
		lost += float(cfg.get("bonus", 0.0)) * (1.0 - float(cfg.get("lurch_keep", 0.5)))
	game.shake(0.4)
	game.sfx.play("boom", at, 0.6)
	game.incident("nested_lurch", by)
	game.say("nested_lurch", at, by)
	game.note_loss("loss_nested_lurch", by, lost)


func on_cut(p) -> void:
	if active() and p != null and not out and whole and _hull.has(p.tag):
		_broken(p.tag)


func on_freed(b) -> void:
	if not active() or out or not whole:
		return
	for q in b.pieces:
		if _hull.has(q.tag):
			_broken(q.tag)
			return


func _broken(by: String) -> void:
	whole = false
	var p = world.tag(by)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else Vector2.ZERO
	game.incident("nested_cut", by)
	game.say("nested_cut", at, by)
	game.note_loss("loss_nested_whole", by, float(cfg.get("bonus", 0.0)) * (float(cfg.get("lurch_keep", 0.5)) if lurched else 1.0))


func bonus_now() -> float:
	if not whole:
		return 0.0
	return float(cfg.get("bonus", 0.0)) * (float(cfg.get("lurch_keep", 0.5)) if lurched else 1.0)


# out it goes, paid as one: its parts as they are, and the bonus if it is whole
func _extract() -> void:
	out = true
	var v := 0.0
	var names: Array = []
	var at := Vector2.ZERO
	var n := 0
	_ghost = []
	for t in cfg.get("pieces", []):
		var p = world.tag(str(t))
		if p == null or p.gone or p.body != null:
			continue
		v += game.piece_value(p, "equip" if p.cls == "equip" else "metal")
		if p.cls == "equip" and p.tag != "":
			names.append(p.tag)
		var wp: PackedVector2Array = world.world_poly(p)
		_ghost.append(wp)
		_ghost_eq.append(p.cls == "equip")
		at += Geom.centroid(wp)
		n += 1
		world.remove_piece(p)
	v += bonus_now()
	at = at / maxf(1, n)
	_ghost_t = 0.0
	_roll_d = 0.0
	_rollers = _roller_spots()
	var wch = world.tag(str(cfg.get("winch_piece", "")))
	_winch_at = world.frame(wch) * Geom.centroid(wch.poly) if wch != null else at
	game.sfx.play("tow_start", at, 1.0)
	game.ledger.append([game.txt("nested_whole") if whole else game.txt("nested_parts"), "equip", v])
	game.log_op("deliver_equip")
	game.gain("equip", v, at, game.txt("nested_whole") if whole else game.txt("nested_parts"))
	game.sfx.play("release", at, 0.8)
	game.say("nested_out", at, Pal.money(v))
	world.dirty_links = true
	queue_redraw()


# ---------------------------------------------------------------- drawing

const FADE_T := 1.2             # s the ship takes to fade once it is clear
const TAKE_UP := 0.22            # of the run: the winch taking up, the ship gathering way
const EASE_OFF := 0.15           # of the run: easing off at the end


# 0..1 of the way out: the winch takes up slowly, the ship rolls out steady, eases at the end
# (a trapezoid of speed, its integral)
func travel() -> float:
	if _ghost_t < 0.0:
		return 1.0 if out else 0.0
	var tt: float = float(cfg.get("time", 12.0))
	var k: float = clampf(_ghost_t / tt, 0.0, 1.0)
	var a := TAKE_UP
	var c := EASE_OFF
	var vmax := 1.0 / (1.0 - 0.5 * a - 0.5 * c)
	if k < a:
		return 0.5 * vmax * k * k / a
	if k < 1.0 - c:
		return 0.5 * vmax * a + vmax * (k - a)
	var r := 1.0 - k
	return 1.0 - 0.5 * vmax * r * r / c


# how fast it is rolling, 0..1 (for the sounds)
func rolling() -> float:
	if _ghost_t < 0.0:
		return 0.0
	var tt: float = float(cfg.get("time", 12.0))
	var k: float = _ghost_t / tt
	if k >= 1.0:
		return 0.0
	return clampf(minf(k / TAKE_UP, (1.0 - k) / EASE_OFF), 0.0, 1.0)


# the cradle's rollers: under the keel, every 2.4 m along the ship's length
func _roller_spots() -> Array:
	var bb := Rect2()
	var first := true
	for wp in _ghost:
		var r := Geom.bbox(wp)
		bb = r if first else bb.merge(r)
		first = false
	var out_r: Array = []
	var x := bb.position.x + 1.2 * Geom.M
	while x < bb.end.x - 0.6 * Geom.M:
		out_r.append(Vector2(x, bb.end.y + 0.35 * Geom.M))
		x += 2.4 * Geom.M
	return out_r


func _draw() -> void:
	if not out:
		_draw_cradle()
		return
	if _ghost_t < 0.0 or _ghost.is_empty():
		return
	var tt: float = float(cfg.get("time", 12.0))
	var e: Array = cfg.get("exit", [-60.0, 0.0])
	var off := Vector2(float(e[0]), float(e[1])) * Geom.M * travel()
	var al: float = 1.0 - clampf((_ghost_t - tt) / FADE_T, 0.0, 1.0)
	var z: float = maxf(game.cam_zoom(), 0.05)
	var lw := 1.3 / z
	# the cradle's rollers, turning as it passes over them (still once it is off them)
	for rp in _rollers:
		var rr := 0.3 * Geom.M
		var ang := _roll_d / rr
		FastDraw.circle(self, rp, rr, Pal.ink(0.55 * al), false, lw)
		for i in 3:
			var aa := ang + TAU * i / 3.0
			draw_line(rp, rp + Vector2.from_angle(aa) * rr * 0.85, Pal.ink(0.45 * al), lw)
	# the ship itself: dark plate, its outline, its equipment lighter
	var bow := Vector2(INF, 0.0)
	for i in _ghost.size():
		var q := PackedVector2Array()
		for v in _ghost[i]:
			var w: Vector2 = v + off
			q.append(w)
			if w.x < bow.x:
				bow = w
		FastDraw.poly(self, q, Color(0.075, 0.08, 0.09, 0.96 * al) if not _ghost_eq[i] else Color(0.12, 0.125, 0.14, 0.96 * al))
		q.append(q[0])
		draw_polyline(q, Pal.ink((0.9 if not _ghost_eq[i] else 0.6) * al), lw)
	# the winch's cable, taut from the winch to the ship's bow eye
	if al > 0.0 and _ghost_t < tt:
		draw_line(_winch_at, bow, Pal.ink(0.85 * al, 1.15), lw * 1.6)
		draw_line(_winch_at, bow, Pal.ink(0.35 * al), lw * 4.0)


# 98 号 Q4 B: by the cradle before it goes: each lock along the keel, numbered in the order they
# come off (the stern's first), shut or open, the next marked; the way out as a dashed outline;
# what blocks it outlined red; a fixed size on the screen
func _draw_cradle() -> void:
	var bb := Rect2()
	var first := true
	for t in cfg.get("hull", []):
		var p = world.tag(str(t))
		if p == null or p.gone:
			continue
		var r := Geom.bbox(world.world_poly(p))
		bb = r if first else bb.merge(r)
		first = false
	if first:
		return
	var z: float = maxf(game.cam_zoom(), 0.05)
	var k := 1.0 / z
	var lw := 1.3 * k
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5
	# the way out
	var e: Array = cfg.get("exit", [-60.0, 0.0])
	var ev := Vector2(float(e[0]), float(e[1])) * Geom.M
	var dest := Rect2(bb.position + ev, bb.size)
	_dashed_rect(dest, Pal.ink(0.4), lw)
	_dashed(Vector2(bb.position.x, bb.position.y), Vector2(dest.position.x, dest.position.y), Pal.ink(0.3), lw)
	_dashed(Vector2(bb.position.x, bb.end.y), Vector2(dest.position.x, dest.end.y), Pal.ink(0.3), lw)
	var blocked := exit_block()
	for id in blocked:
		var q = world.pieces.get(id)
		if q == null or q.gone:
			continue
		var wp: PackedVector2Array = world.world_poly(q)
		wp.append(wp[0])
		draw_polyline(wp, Pal.heat(0.95 if flash else 0.5, 1.5), lw * 2.0)
	_label(dest.position + Vector2(0.6 * Geom.M, -0.5 * Geom.M), [[("出口 · 净空" if Txt.zh else "WAY OUT · CLEAR") if blocked.is_empty() else ("出口 · %d 件挡路" if Txt.zh else "WAY OUT · %d IN THE WAY") % blocked.size(), Pal.ink(0.75) if blocked.is_empty() else Pal.heat(0.95, 1.4)]], k, font)
	# the locks along the keel, the stern's first
	var locks: Array = cfg.get("locks", [])
	var next := -1
	for i in locks.size():
		if _on(str(locks[i])):
			next = i
			break
	for i in locks.size():
		var f := (i + 0.5) / float(locks.size())
		var at := Vector2(lerpf(bb.end.x - 2.0 * Geom.M, bb.position.x + 2.0 * Geom.M, f), bb.end.y + 0.15 * Geom.M)
		var shut := _on(str(locks[i]))
		var col := Pal.ink(0.55)
		if shut:
			col = Pal.heat(0.95, 1.4) if i == next and flash else Pal.ink(0.9)
		# the clamp: a jaw closed round the keel, or swung open
		var jw := 0.5 * Geom.M
		if shut:
			draw_polyline(PackedVector2Array([at + Vector2(-jw, -0.35 * Geom.M), at + Vector2(-jw, 0.25 * Geom.M), at + Vector2(jw, 0.25 * Geom.M), at + Vector2(jw, -0.35 * Geom.M)]), col, lw * 1.6)
		else:
			draw_polyline(PackedVector2Array([at + Vector2(-jw * 1.6, 0.0), at + Vector2(-jw, 0.25 * Geom.M), at + Vector2(jw, 0.25 * Geom.M), at + Vector2(jw * 1.6, 0.0)]), col, lw * 1.2)
		var word := (("锁" if Txt.zh else "SHUT") if shut else ("开" if Txt.zh else "OPEN"))
		if shut and i == next:
			word = ("下一个" if Txt.zh else "NEXT")
		_label(at + Vector2(-jw, 1.1 * Geom.M), [["%d %s · %s" % [i + 1, str(locks[i]), word], col]], k, font)


func _label(at: Vector2, lines: Array, k: float, font: Font) -> void:
	draw_set_transform(at, 0.0, Vector2(k, k))
	for i in lines.size():
		var y := i * 18.0
		draw_string_outline(font, Vector2(0, y), str(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.022, 0.028, 0.85))
		draw_string(font, Vector2(0, y), str(lines[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lines[i][1])
	draw_set_transform(Vector2.ZERO)


func _dashed(a: Vector2, b: Vector2, col: Color, lw: float) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var dir := (b - a) / d
	var step := 0.9 * Geom.M
	var x := 0.0
	while x < d:
		draw_line(a + dir * x, a + dir * minf(x + step * 0.55, d), col, lw)
		x += step


func _dashed_rect(r: Rect2, col: Color, lw: float) -> void:
	_dashed(r.position, Vector2(r.end.x, r.position.y), col, lw)
	_dashed(Vector2(r.end.x, r.position.y), r.end, col, lw)
	_dashed(r.end, Vector2(r.position.x, r.end.y), col, lw)
	_dashed(Vector2(r.position.x, r.end.y), r.position, col, lw)
