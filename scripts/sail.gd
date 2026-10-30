extends Node
# A light sail held flat by its stays (exotic batch, SA-200 "Kite": "the whole ship
# is a sail; the only thing of value is the gondola, the sail an obstacle to take
# down"). A ship file's "sail":
#   {"quads": {quadrant: its winch's brake control (on: holding the corner taut)},
#    "panels": {film panel: {"quad": quadrant, "next": [the panels either side]}},
#    "stays": {stay or brace: {"quad": quadrant, "panels": [the panels on it],
#      "hits": [what its spar whips into]}},
#    "torn": [panels already torn], "ground": the earthing clamp's control}
#   The film can't be cut clean: cut, a panel tears (worthless), and while its
#   quadrant is still taut the tear runs into the panels either side; a panel next
#   to one already torn tears through too. Freed while its quadrant is taut, a
#   panel is pulled apart; slack, it comes away whole (a roll).
#   A stay or brace cut or freed with its quadrant taut snaps: the panels on it
#   tear and the corner spar whips into the gondola.
#   The film holds a static charge until the earthing clamp is on: a panel freed or
#   cut before then discharges into the drone.
# Saved: which panels tore, which stays snapped.
#   87-2: a tear is not instant. It runs across the film from where it started at a speed set by
#   the pull on it; only when it has run right across does it carry on into the panels either
#   side, and only while that quadrant is still taut: put the winch brake off (slacken the
#   corner) and a running tear stops where it is. The film shows its pull: taut, it is drawn tight
#   with fine lines along the pull; slack, it ripples. Saved too: how far each tear has run.

const TEAR_RATE := 0.85        # of a panel's span a tear runs a second while its quadrant pulls
#   87-4: the sail is the ship's prize, not an obstacle (user 2026-10-26). "roll": {"value": all
#   four corners' film furled whole, "winch": {quadrant: its winch}, "furl": {quadrant: its
#   furling motor's switch}}. Each panel is worth its share of the value by area.
#   Furling is real work at each corner: earthed, the winch brake let off (the corner slack),
#   then the furling motor on. The winch reels the corner's panels in one by one, nearest first:
#   each one shortens towards the winch as it winds on (its real outline). Wound with the corner
#   still taut the film overloads: the panel on the drum tears and the motor trips. Wound unearthed
#   the film's charge arcs through it (pinholes). A panel already torn winds on as waste. Holes
#   knocked in by loose pieces and soot from cutting close by mark the film too.
#   When the corner's last panel is on the drum, the roll is there on the winch, bolted: a piece of
#   equipment of its own ("ROLL-NW"), worth its corner's share of the value times its grade
#   (good area x quality: A >= 0.9, B >= 0.7, C >= 0.45, D below), unbolted and carried to the
#   equipment mouth like any unit, onto the parts rack in a career (kept or sold there).
#   The quick way is still there: cut the film to waste, scrap by weight, almost nothing.
#   Saved: each corner's progress and marks, the panels' shortened outlines with the ship.
const FURL_RATE := 0.25        # panels a second the motor winds on
# the winding panel is cut back every physics step and drawn every frame on its own node (world.live),
# with the film running onto the drum and the drum filling (user 2026-10-27: the furl went in steps)
const OVERLOAD_DMG := 0.2      # quality off a roll wound taut (once a trip)
const STATIC_DMG := 0.08       # quality off for each panel wound unearthed
const PUNCT_DMG := 0.06        # each hole knocked into the film
const SOOT_DMG := 0.04         # each cut close by
const SOOT_NEAR := 2.0         # m

var game
var tearing := {}             # 87-2: panel tag -> {"p": 0..1 across, "at": world point it started}
var overlay: Node2D
var _tear_from := {}
var _lines := {}              # "panel|cut seq|taut" -> its pull lines (segment pairs, world)
var world
var cfg := {}
var torn := {}                # panel tag -> true
var snapped := {}             # stay tag -> true
var furl := {}                # 87-4: quadrant -> {"k": panels done, "f": 0..1 of the one winding, "ok": good area wound, "dmg": quality lost, "done": bool}
# 93 号 (the sample ship's readable chain): every loss to the sail as it happens — what, which
# corner, what it cost, where — for the status board, the marks on site and the review.
# {k: cause, q: corner, money, at: [x, y], n, t: play time}; causes: cut_taut cut spread
# freed_taut snap overload static holes soot
var events: Array = []
var _cause := ""
var marks := {}               # 87-4: panel tag -> {"punct": n, "soot": n}
var _area0 := {}              # panel tag -> its area as built (px²)
var _poly0 := {}              # panel tag -> its outline as built (world)
var _punct_t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("sail", {})
	for t in cfg.get("torn", []):
		torn[str(t)] = true
	# each panel's outline as built, from the ship file (a save may hold one half wound on)
	for pd in ship.get("pieces", []):
		var t := str(pd.get("tag", ""))
		if not cfg.get("panels", {}).has(t):
			continue
		var poly := PackedVector2Array()
		for q in pd.poly:
			poly.append(Vector2(q[0], q[1]) * Geom.M)
		_poly0[t] = poly
		_area0[t] = Geom.area(poly)
	if active():
		overlay = Node2D.new()
		overlay.z_index = 1
		overlay.z_as_relative = false
		overlay.draw.connect(_draw_film)
		world.add_child(overlay)
		wind_node = Node2D.new()
		wind_node.z_index = 1
		wind_node.z_as_relative = false
		wind_node.draw.connect(_draw_winding)
		world.add_child(wind_node)
		world.move_child(wind_node, world.piece_layer.get_index() + 1)


var wind_node: Node2D
var _winding := {}            # quadrant -> the panel winding on now (its tag)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	var run := {}
	for t in tearing:
		run[t] = float(tearing[t].p)
	return {"torn": torn.keys(), "snapped": snapped.keys(), "tearing": run, "furl": furl.duplicate(true), "marks": marks.duplicate(true), "events": events.duplicate(true)}


func load_state(d: Dictionary) -> void:
	for t in d.get("torn", []):
		torn[str(t)] = true
	for t in d.get("snapped", []):
		snapped[str(t)] = true
	furl = d.get("furl", {}).duplicate(true)
	marks = d.get("marks", {}).duplicate(true)
	events = d.get("events", []).duplicate(true)
	for t in d.get("tearing", {}):
		var p = world.tag(str(t))
		if p != null and not p.gone:
			tearing[str(t)] = {"p": float(d.tearing[t]), "at": world.frame(p) * Geom.centroid(p.poly)}


func taut(q: String) -> bool:
	return game.sys.on(str(cfg.get("quads", {}).get(q, "")))


func grounded() -> bool:
	return game.sys.on(str(cfg.get("ground", "")))


# a stay's pull (kN): what a tension gauge on it reads
func pull(stay: String) -> float:
	var e: Dictionary = cfg.get("stays", {}).get(stay, {})
	if e.is_empty() or snapped.has(stay):
		return 0.0
	var p = world.tag(stay)
	if p == null or p.gone or p.body != null:
		return 0.0
	return float(e.get("kn", 12.0)) if taut(str(e.quad)) else 0.0


# what still has to be made safe
func unsafe() -> Array:
	var out: Array = []
	for q in cfg.get("quads", {}):
		if taut(q):
			out.append("sail %s taut" % q)
	if not grounded():
		out.append("sail not earthed")
	return out


func _tear(tags: Array, why: String) -> void:
	var cause := _cause if _cause != "" else "spread"
	_cause = ""
	var lost := 0.0
	var at := Vector2.ZERO
	var n := 0
	for t in tags:
		if torn.has(t):
			continue
		var p = world.tag(t)
		if p == null or p.gone:
			continue
		torn[t] = true
		if not tearing.has(t):
			tearing[t] = {"p": 0.0, "at": _tear_from.get(t, world.frame(p) * Geom.centroid(p.poly))}
		lost += p.value * clampf(p.cond, 0.0, 1.0) + panel_value(t)
		p.value = 0.0
		p.intact = false
		p.cond = 0.0
		at += world.frame(p) * Geom.centroid(p.poly)
		n += 1
	if n == 0:
		return
	at /= float(n)
	game.incident("film_tear", why)
	game.say("film_tear", at, why)
	game.note_loss("loss_film", why, lost)
	_log(cause, _quad_of(str(tags[0])), lost, at, n)
	game.sfx.play("film_tear", at, 0.9)
	world.redraw_all()


# a panel torn: the tear runs on while its quadrant is taut, and through any
# panel beside one already torn
func _spread(t: String, from: Vector2 = Vector2.INF, cause: String = "spread") -> void:
	if from != Vector2.INF:
		_tear_from[t] = from
	_cause = cause
	_tear([t], t)


# 87-2: the tears run on; one that has crossed its panel goes into the panels either side while
# its quadrant still pulls (or into one already weakened by a torn neighbour)
func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	_furl_step(dt)
	_punct_step(dt)
	for t in tearing.keys():
		var r: Dictionary = tearing[t]
		if r.p >= 1.0:
			continue
		var e: Dictionary = cfg.panels.get(t, {})
		if e.is_empty() or not taut(str(e.quad)):
			continue
		r.p = minf(1.0, r.p + TEAR_RATE * dt)
		if r.p >= 1.0:
			game.sfx.play("snap", r.at, 0.6, 1.3)
			var p = world.tag(t)
			for nb in e.get("next", []):
				if torn.has(nb):
					continue
				var q = world.tag(str(nb))
				if q == null or q.gone:
					continue
				var weak := false
				for nn in cfg.panels.get(nb, {}).get("next", []):
					if nn != t and torn.has(nn):
						weak = true
				if taut(str(e.quad)) or weak:
					# it enters the neighbour where the two panels meet
					var pc: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null and not p.gone else r.at
					var qc: Vector2 = world.frame(q) * Geom.centroid(q.poly)
					_spread(str(nb), pc.lerp(qc, 0.5))


# how far a tear has run across its panel (0 = none)
func tear_run(t: String) -> float:
	return float(tearing.get(t, {}).get("p", 0.0))


# redraw only when what it shows changed: a corner pulled or let go, a tear running
var _sig := ""
var _taut_was := {}

func _process(_dt: float) -> void:
	if overlay == null or not active() or game == null:
		return
	var sig := ""
	for q in cfg.get("quads", {}):
		sig += "1" if taut(q) else "0"
		# 93 号: a winch brake let off or put on, heard at its winch
		var tq := taut(q)
		if _taut_was.has(q) and bool(_taut_was[q]) != tq:
			game.sfx.play("winch_brake", _winch_at(q), 0.8)
		_taut_was[q] = tq
	for t in tearing:
		sig += "%s%.2f" % [t, float(tearing[t].p)]
	for q in furl:
		sig += "%s%d%.2f" % [q, int(furl[q].k), float(furl[q].dmg)]
	sig += "%s|%d|%.3f" % [grounded(), events.size(), snappedf(game.cam_zoom(), 0.01)]
	if wind_node != null and (not _winding.is_empty() or furling()):
		wind_node.queue_redraw()
	if _roll_loose():
		sig += str(Time.get_ticks_msec())
	var moved: bool = world.bodies.size() != _sig_bodies
	if sig != _sig or moved:
		_sig = sig
		_sig_bodies = world.bodies.size()
		overlay.queue_redraw()


var _sig_bodies := -1


# 87-2: the film's pull drawn on it. Taut: fine lines along the panel's long axis; slack: a
# ripple across it. A tear: a ragged line from where it started, as far across as it has run,
# its lips pulled open while the film still pulls.
var draw_us := 0             # what the last redraw of the film took (µs)

func _draw_film() -> void:
	if world == null:
		return
	var t0 := Time.get_ticks_usec()
	for t in cfg.get("panels", {}):
		var p = world.tag(str(t))
		if p == null or p.gone or p.body != null:
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var bb := Geom.bbox(poly)
		var c := Geom.centroid(poly)
		var axis := Vector2.RIGHT if bb.size.x >= bb.size.y else Vector2.DOWN
		var span := maxf(bb.size.x, bb.size.y)
		var width := minf(bb.size.x, bb.size.y)
		# the one winding on is drawn on its own, moving (_draw_winding)
		if world.live.has(p.id):
			continue
		var tight := taut(str(cfg.panels[t].quad))
		# the pull lines are worked out once per panel and state (the film does not move)
		var key := "%s|%d|%d|%s" % [t, p.cut_seq, int(p.get_meta("wound", 0)), tight]
		if not _lines.has(key):
			var nrm := Vector2(-axis.y, axis.x)
			var segs := PackedVector2Array()
			for i in 4:
				var off := (float(i) + 0.5) / 4.0 - 0.5
				var pts := PackedVector2Array()
				for k in 13:
					var f := float(k) / 12.0 - 0.5
					var wob := 0.0 if tight else sin(f * 9.0 + i * 1.7) * width * 0.08
					pts.append(c + axis * f * span * 0.92 + nrm * (off * width * 0.8 + wob))
				for seg in Geometry2D.intersect_polyline_with_polygon(pts, poly):
					for k in range(1, seg.size()):
						segs.append(seg[k - 1])
						segs.append(seg[k])
			_lines[key] = segs
		var sg: PackedVector2Array = _lines[key]
		if sg.size() >= 2:
			overlay.draw_multiline(sg, Pal.ink(0.13 if tight else 0.07), 1.0)
		if tearing.has(t):
			_draw_tear(p, poly, tearing[t], axis, span, tight)
	_draw_rolls()
	draw_us = Time.get_ticks_usec() - t0


func _draw_tear(p, poly: PackedVector2Array, r: Dictionary, axis: Vector2, span: float, tight: bool) -> void:
	var from: Vector2 = r.at
	# a tear runs across the pull (perpendicular to the long axis), both ways from where it began
	var dir := Vector2(-axis.y, axis.x)
	var reach := span * 1.2 * float(r.p) + 6.0
	var seed := float(p.id) * 1.37
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array([from])
		var at := from
		for k in 10:
			var j := sin(seed + k * 2.3 + sgn) * 0.45
			at += (dir * sgn).rotated(j) * reach / 10.0
			pts.append(at)
		for seg in Geometry2D.intersect_polyline_with_polygon(pts, poly):
			var gap := 2.5 if tight else 1.2
			var lip_a := PackedVector2Array()
			var lip_b := PackedVector2Array()
			for q in seg:
				lip_a.append(q + axis * gap)
				lip_b.append(q - axis * gap)
			overlay.draw_polyline(seg, Color(0, 0, 0, 0.85), 3.0 + gap, true)
			overlay.draw_polyline(lip_a, Pal.ink(0.7), 1.1, true)
			overlay.draw_polyline(lip_b, Pal.ink(0.7), 1.1, true)


func _zap(p) -> void:
	if grounded():
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.fx.arc(at, game.drone.global_position, 0.3, 0.8)
	game.hurt_drone(12.0, at, "static", "static", 1.0)
	game.incident("static_zap", p.tag)
	game.say("static_zap", at, p.tag)


func on_cut(p) -> void:
	if not active():
		return
	if not cfg.panels.has(p.tag) and not cfg.stays.has(p.tag):
		_soot(world.frame(p) * Geom.centroid(p.poly))
	if cfg.panels.has(p.tag):
		_zap(p)
		if not torn.has(p.tag):
			_spread(p.tag, game.tools.front if game.tools.cutting else Vector2.INF, "cut_taut" if taut(str(cfg.panels[p.tag].quad)) else "cut")
	elif cfg.stays.has(p.tag):
		_snap(p.tag)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if cfg.panels.has(q.tag):
			_zap(q)
			if not torn.has(q.tag) and taut(str(cfg.panels[q.tag].quad)):
				_spread(q.tag, Vector2.INF, "freed_taut")
		elif cfg.stays.has(q.tag):
			_snap(q.tag)


func _snap(t: String) -> void:
	var e: Dictionary = cfg.stays[t]
	if snapped.has(t) or not taut(str(e.quad)):
		return
	snapped[t] = true
	var p = world.tag(t)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	if world.rope_fx != null:
		world.rope_fx.snap_member(world.world_poly(p), at, 1.0)
	game.incident("stay_snap", t)
	game.say("stay_snap", at, t)
	var lost := 0.0
	for h in e.get("hits", []):
		var q = world.tag(str(h))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, 0.5), "dv_spar_whip")
		lost += (before - q.cond) * q.value
	if lost > 0.0:
		game.note_loss("loss_spar_whip", t, lost)
	game.shake(0.7)
	_cause = "snap"
	_tear(e.get("panels", []), t)


# ---------------------------------------------------------------- 87-4: the sail as the prize

# what the whole sail is worth furled whole, as the ship file has it (its torn panels left out):
# for the contract's total and the recovery's denominator
static func asset_full(d: Dictionary) -> float:
	var sc: Dictionary = d.get("sail", {})
	var v := float(sc.get("roll", {}).get("value", 0.0))
	if v <= 0.0:
		return 0.0
	var torn0: Array = sc.get("torn", [])
	var all := 0.0
	var good := 0.0
	for pd in d.get("pieces", []):
		var t := str(pd.get("tag", pd.get("key", "")))
		if not sc.get("panels", {}).has(t):
			continue
		var poly := PackedVector2Array()
		for q in pd.poly:
			poly.append(Vector2(q[0], q[1]))
		var a := Geom.area(poly)
		all += a
		if not torn0.has(t):
			good += a
	return v * good / maxf(all, 0.0001)


func _value() -> float:
	return float(cfg.get("roll", {}).get("value", 0.0))


func _area_all() -> float:
	var a := 0.0
	for t in _area0:
		a += float(_area0[t])
	return a


# a panel's share of the sail's worth (by area)
func panel_value(t: String) -> float:
	if _value() <= 0.0 or not _area0.has(t):
		return 0.0
	return _value() * float(_area0[t]) / maxf(_area_all(), 0.0001)


func _quad_panels(q: String) -> Array:
	var out: Array = []
	for t in cfg.get("panels", {}):
		if str(cfg.panels[t].quad) == q:
			out.append(str(t))
	var w := _winch_at(q)
	out.sort_custom(func(a, b): return _c0(a).distance_to(w) < _c0(b).distance_to(w))
	return out


func _c0(t: String) -> Vector2:
	return Geom.centroid(_poly0[t]) if _poly0.has(t) else Vector2.ZERO


func _winch_at(q: String) -> Vector2:
	var w = world.tag(str(cfg.get("roll", {}).get("winch", {}).get(q, "")))
	return world.frame(w) * Geom.centroid(w.poly) if w != null else Vector2.ZERO


func motor_on(q: String) -> bool:
	return game.sys.on(str(cfg.get("roll", {}).get("furl", {}).get(q, "")))


func _motor_off(q: String) -> void:
	var id := str(cfg.get("roll", {}).get("furl", {}).get(q, ""))
	game.sys.set_switch(id, false)
	var c = world.ctrls.get(id)
	if c != null:
		c.state = false


func furling() -> bool:
	for q in cfg.get("roll", {}).get("furl", {}):
		if motor_on(q) and not furled(q):
			return true
	return false


func furled(q: String) -> bool:
	return furl.get(q, {}).get("done", false)


func quad_area(q: String) -> float:
	var a := 0.0
	for t in _quad_panels(q):
		a += float(_area0.get(t, 0.0))
	return a


# a corner's roll: grade 0..1 = good area wound x quality (so far, while it winds)
func grade(q: String) -> float:
	var r: Dictionary = furl.get(q, {})
	if r.is_empty():
		return 0.0
	return clampf(float(r.ok) / maxf(quad_area(q), 0.0001), 0.0, 1.0) * clampf(1.0 - float(r.dmg), 0.0, 1.0)


static func grade_letter(g: float) -> String:
	if g >= 0.9:
		return "A"
	if g >= 0.7:
		return "B"
	if g >= 0.45:
		return "C"
	return "D"


func _furl_step(dt: float) -> void:
	var rc: Dictionary = cfg.get("roll", {})
	if rc.is_empty():
		return
	for q in rc.get("furl", {}):
		if furled(q) or not motor_on(q):
			continue
		if not furl.has(q):
			furl[q] = {"k": 0, "f": 0.0, "ok": 0.0, "dmg": 0.0, "done": false}
		var r: Dictionary = furl[q]
		var order := _quad_panels(q)
		while int(r.k) < order.size():
			var t0: String = order[int(r.k)]
			var p0 = world.tag(t0)
			if p0 != null and not p0.gone and p0.body == null:
				break
			# a panel already gone (cut away, carried off) adds nothing to the drum
			r.k = int(r.k) + 1
			r.f = 0.0
		if int(r.k) >= order.size():
			_finish(q)
			continue
		var t: String = order[int(r.k)]
		var p = world.tag(t)
		# the corner still taut: the film on the drum overloads and tears, the motor trips
		if taut(q):
			r.dmg = float(r.dmg) + OVERLOAD_DMG
			_log("overload", q, _quad_value(q) * OVERLOAD_DMG, _winch_at(q), 0, false)
			_spread(t, _winch_at(q).lerp(_c0(t), 0.3), "overload")
			_motor_off(q)
			game.incident("furl_overload", q)
			game.say("furl_overload", _winch_at(q), q)
			game.sfx.play("snap", _winch_at(q), 1.0, 0.8)
			game.shake(0.3)
			continue
		if not world.live.has(p.id):
			# out of the strips: from now on it is drawn every frame, cut back a little each step
			world.live[p.id] = true
			_winding[q] = t
			world.redraw_near([p])
		r.f = minf(1.0, float(r.f) + FURL_RATE * dt)
		_wind_shape(t, p, q, float(r.f))
		if float(r.f) >= 1.0:
			_panel_on(q, t, p)


# the panel as it winds on: what is left of it, from its far edge to the fold
func _wind_shape(t: String, p, q: String, f: float) -> void:
	if not _poly0.has(t):
		return
	var poly0: PackedVector2Array = _poly0[t]
	var w := _winch_at(q)
	var c0 := Geom.centroid(poly0)
	var dir := (c0 - w).normalized()
	var lo := INF
	var hi := -INF
	for v in poly0:
		var d := v.dot(dir)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var cut := lo + (hi - lo) * f
	var base := c0 + dir * (cut - c0.dot(dir))
	var n := Vector2(-dir.y, dir.x)
	var L := 100000.0
	var hp := PackedVector2Array([base + n * L, base - n * L, base - n * L + dir * L, base + n * L + dir * L])
	var parts: Array = Geometry2D.intersect_polygons(poly0, hp)
	if parts.is_empty():
		return
	var best: PackedVector2Array = parts[0]
	for pp in parts:
		if Geom.area(pp) > Geom.area(best):
			best = pp
	if Geom.area(best) < 4.0:
		return
	p.poly = best
	world.pick_touch(p)
	p.set_meta("wound", int(p.get_meta("wound", 0)) + 1)
	# drawn live while it winds; only a panel wound outside the motor's step (a save) goes back to its strip
	if not world.live.has(p.id):
		world.redraw_near([p])


# a panel wound right on: its area counts if it was whole, its marks take off the quality
func _panel_on(q: String, t: String, p) -> void:
	var r: Dictionary = furl[q]
	var m: Dictionary = marks.get(t, {})
	if not torn.has(t):
		r.ok = float(r.ok) + float(_area0.get(t, 0.0))
	var pc: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var holes := PUNCT_DMG * int(m.get("punct", 0))
	var sooty := SOOT_DMG * mini(3, int(m.get("soot", 0)))
	r.dmg = float(r.dmg) + holes + sooty
	if holes > 0.0:
		_log("holes", q, _quad_value(q) * holes, pc, int(m.get("punct", 0)))
	if sooty > 0.0:
		_log("soot", q, _quad_value(q) * sooty, pc, mini(3, int(m.get("soot", 0))))
	if not grounded():
		r.dmg = float(r.dmg) + STATIC_DMG
		_log("static", q, _quad_value(q) * STATIC_DMG, pc)
		game.sfx.play("static_arc", pc, 0.8)
		if game.drone.global_position.distance_to(pc) < 8.0 * Geom.M:
			_zap(p)
		else:
			game.incident("static_pinhole", t)
	tearing.erase(t)
	world.live.erase(p.id)
	_winding.erase(q)
	world.remove_piece(p)
	world.redraw_near([p])
	game.sfx.play("clank", _winch_at(q), 0.5, 1.2)
	game.sfx.play("sail_flap", _winch_at(q), 0.7)
	# the drum takes the weight of another panel: felt
	game.shake(0.08)
	r.k = int(r.k) + 1
	r.f = 0.0


# the corner done: the roll on its winch, bolted
func _finish(q: String) -> void:
	var r: Dictionary = furl[q]
	r.done = true
	_motor_off(q)
	var rc: Dictionary = cfg.get("roll", {})
	var winch = world.tag(str(rc.get("winch", {}).get(q, "")))
	if winch == null or winch.gone:
		return
	var at := _winch_at(q)
	var hx := 1.3 * Geom.M
	var hy := 0.55 * Geom.M
	var poly := PackedVector2Array([at + Vector2(-hx, -hy), at + Vector2(hx, -hy), at + Vector2(hx, hy), at + Vector2(-hx, hy)])
	var g := grade(q)
	var mass := 0.3
	for t in _quad_panels(q):
		mass += 0.03
	var roll = world.add_piece("equip", poly, {"cls": "equip", "value": snappedf(_value() * quad_area(q) / maxf(_area_all(), 0.0001), 1.0),
		# the grade rounded down, so the four rolls never pay more than the sail is worth
		"cond": floorf(g * 100.0) / 100.0, "tag": "ROLL-" + q, "name_key": "p_sail_roll", "dest": "equip", "mass": mass,
		"fragile": 0.4, "room": winch.room, "mat": "film", "cut_speed": 90.0, "barrier": false})
	roll.label = "%s %d%%" % [grade_letter(g), int(round(g * 100.0))]
	world.add_joint(roll, winch, "bolt", at)
	world.dirty_links = true
	world.redraw_near([roll, winch])
	game.sfx.play("roll_lock", at, 1.0)
	game.shake(0.25)
	game.say("furl_done", at, "%s %s %d%%" % [q, grade_letter(g), int(round(g * 100.0))])
	# the climax, kept short (93 号 Q4): the last corner on its drum, the film gone, the gondola alone
	var all := true
	for qq in cfg.get("quads", {}):
		if not furled(qq):
			all = false
	if all and game.hud != null:
		var sum := 0.0
		var letters: Array = []
		for qq in cfg.get("quads", {}):
			sum += _quad_value(qq) * grade(qq)
			letters.append(grade_letter(grade(qq)))
		game.hud.show_hint(("整帆收回：四卷 %s，约 %s" if Txt.zh else "THE WHOLE SAIL IN: FOUR ROLLS %s, ABOUT %s") % [" ".join(letters), Pal.money(sum)])


# soot: a cut close to the film blackens it
func _soot(at: Vector2) -> void:
	for t in cfg.get("panels", {}):
		var p = world.tag(str(t))
		if p == null or p.gone or p.body != null or torn.has(t):
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		if Geometry2D.is_point_in_polygon(at, poly) or Geom.dist_to_boundary(at, poly) < SOOT_NEAR * Geom.M:
			var m: Dictionary = marks.get(t, {})
			m["soot"] = int(m.get("soot", 0)) + 1
			marks[t] = m


# holes: a loose piece going through the film fast enough punches one
func _punct_step(dt: float) -> void:
	_punct_t += dt
	if _punct_t < 0.2:
		return
	_punct_t = 0.0
	for b in world.bodies:
		if not is_instance_valid(b) or b.linear_velocity.length() < 40.0:
			continue
		var com: Vector2 = b.global_transform * b.center_of_mass
		if b.has_meta("punched") and float(b.get_meta("punched")) > Time.get_ticks_msec() / 1000.0:
			continue
		for t in cfg.get("panels", {}):
			var p = world.tag(str(t))
			if p == null or p.gone or p.body != null or torn.has(t):
				continue
			if Geometry2D.is_point_in_polygon(com, world.world_poly(p)):
				var m: Dictionary = marks.get(t, {})
				m["punct"] = int(m.get("punct", 0)) + 1
				marks[t] = m
				b.set_meta("punched", Time.get_ticks_msec() / 1000.0 + 1.5)
				game.sfx.play("snap", com, 0.4, 1.6)
				break


func _roll_loose() -> bool:
	for q in furl:
		var p = world.tag("ROLL-" + str(q))
		if p != null and not p.gone and p.body != null:
			return true
	return false


# the rolls: a drum with the film wound on it, its grade on it
func _draw_rolls() -> void:
	var font: Font = game.hud.font if game != null and game.hud != null else ThemeDB.fallback_font
	for q in furl:
		var p = world.tag("ROLL-" + str(q))
		if p == null or p.gone:
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var c := Geom.centroid(poly)
		var xf: Transform2D = world.frame(p)
		var ax: Vector2 = xf.basis_xform(Vector2.RIGHT).normalized()
		var r := 0.5 * Geom.M
		for k in 4:
			var rr := r * (0.35 + 0.18 * k)
			overlay.draw_arc(c - ax * 0.9 * Geom.M, rr, 0.0, TAU, 20, Pal.ink(0.5 - 0.08 * k), 1.2, true)
			overlay.draw_arc(c + ax * 0.9 * Geom.M, rr, 0.0, TAU, 20, Pal.ink(0.5 - 0.08 * k), 1.2, true)
		overlay.draw_string(font, c + Vector2(-1.0 * Geom.M, -0.7 * Geom.M), str(p.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.9))
	_draw_corner_tags(font)


# 93 号 (Q2, the board on site as well): by each corner's winch, its pull, how far it has wound
# and what it is worth now; a fixed size on the screen whatever the zoom
func _draw_corner_tags(font: Font) -> void:
	if game == null:
		return
	var z: float = maxf(game.cam_zoom(), 0.05)
	var k := 1.0 / z
	for q in cfg.get("quads", {}):
		var w := _winch_at(q)
		if w == Vector2.ZERO:
			continue
		var st := corner_state(q)
		var line1 := "%s · %s" % [quad_name(q), (("已成卷" if Txt.zh else "ROLLED") if st.done else (("绷紧" if Txt.zh else "TAUT") if st.taut else ("已松" if Txt.zh else "SLACK")))]
		var line2 := "%s %s" % [grade_letter(float(st.grade)), Pal.money(float(st.worth))]
		if st.winding:
			line2 += ("  收卷 %d/%d" if Txt.zh else "  WINDING %d/%d") % [st.k, st.n]
		var at := w + Vector2(1.9 * Geom.M, -1.6 * Geom.M)
		overlay.draw_set_transform(at, 0.0, Vector2(k, k))
		var col: Color = Pal.heat(0.9, 1.2) if st.taut and not st.done else Pal.ink(0.88)
		overlay.draw_line(Vector2(-6, -14), Vector2(-6, 22), col, 2.0)
		overlay.draw_string_outline(font, Vector2(0, 0), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.02, 0.022, 0.028, 0.85))
		overlay.draw_string(font, Vector2(0, 0), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		overlay.draw_string_outline(font, Vector2(0, 19), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.022, 0.028, 0.85))
		overlay.draw_string(font, Vector2(0, 19), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.7))
		overlay.draw_set_transform(Vector2.ZERO)


# every frame while a corner winds: the panel being wound (its outline cut back every step), the
# film running from its fold onto the drum with marks travelling along it, the drum filling and turning
func _draw_winding() -> void:
	if world == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for q in furl:
		if furled(q):
			continue
		var r: Dictionary = furl[q]
		var w := _winch_at(q)
		var n: int = _quad_panels(q).size()
		var k := (float(r.k) + float(r.f)) / maxf(1.0, n)
		var dr := (0.25 + 0.5 * sqrt(k)) * Geom.M
		var on := motor_on(q)
		var t: String = _winding.get(q, "")
		var p = world.tag(t) if t != "" else null
		if p != null and not p.gone and world.live.has(p.id):
			world.draw_pieces(wind_node, [p])
			# the fold: the panel's edge nearest the drum, and the film from it onto the drum
			var poly: PackedVector2Array = world.world_poly(p)
			var c := Geom.centroid(poly)
			var dir := (c - w).normalized()
			var lo := INF
			for v in poly:
				lo = minf(lo, (v - w).dot(dir))
			var nrm := Vector2(-dir.y, dir.x)
			var hw := 0.0
			for v in poly:
				if absf((v - w).dot(dir) - lo) < 0.6 * Geom.M:
					hw = maxf(hw, absf((v - w).dot(nrm)))
			hw = minf(hw, dr * 0.9)
			var fold := w + dir * lo
			var strip := PackedVector2Array([fold + nrm * hw, w + nrm * dr * 0.9, w - nrm * dr * 0.9, fold - nrm * hw])
			wind_node.draw_colored_polygon(strip, Pal.ink(0.08))
			wind_node.draw_line(fold + nrm * hw, w + nrm * dr * 0.9, Pal.ink(0.45), 1.2)
			wind_node.draw_line(fold - nrm * hw, w - nrm * dr * 0.9, Pal.ink(0.45), 1.2)
			# marks on the film, carried along at the furl's speed
			if on:
				var L := maxf(1.0, lo)
				var spd := FURL_RATE * 2.0 * Geom.M
				for i in 6:
					var u := fposmod(i / 6.0 - now * spd / L, 1.0)
					var a := fold.lerp(w, u)
					var hh := lerpf(hw, dr * 0.9, u)
					wind_node.draw_line(a + nrm * hh, a - nrm * hh, Pal.ink(0.22), 1.0)
		wind_node.draw_arc(w, dr, 0.0, TAU, 32, Pal.ink(0.7), 1.6, true)
		wind_node.draw_arc(w, dr, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Pal.tint(Pal.AIR, 0.9, 1.3), 2.6, true)
		# the drum turning: spokes going round while the motor runs
		var spin := now * 2.4 if on else 0.0
		for i in 3:
			var a := spin + TAU * i / 3.0
			wind_node.draw_line(w, w + Vector2.from_angle(a) * dr * 0.8, Pal.ink(0.55), 1.2)


# ---------------------------------------------------------------- 93 号: what the sail lost, and why

const CoreAsset = preload("res://scripts/core_asset.gd")
const QUAD_NAMES := {"NW": ["西北", "NW"], "NE": ["东北", "NE"], "SW": ["西南", "SW"], "SE": ["东南", "SE"]}


static func quad_name(q: String) -> String:
	return QUAD_NAMES.get(q, [q, q])[0 if Txt.zh else 1]


func _quad_of(t: String) -> String:
	return str(cfg.get("panels", {}).get(t, {}).get("quad", ""))


# a corner's share of the sail's worth
func _quad_value(q: String) -> float:
	return _value() * quad_area(q) / maxf(_area_all(), 0.0001)


# a loss: kept, shown where it happened (the money off, a word on why)
func _log(cause: String, q: String, money: float, at: Vector2, n: int = 1, popup: bool = true) -> void:
	if money < 1.0:
		return
	events.append({"k": cause, "q": q, "money": snappedf(money, 1.0), "at": [at.x, at.y], "n": n, "t": snappedf(float(game.playtime), 0.1)})
	if cause in ["overload", "static", "holes", "soot"]:
		game.note_loss("loss_film_" + cause, q, money)
	if popup and game.fx != null:
		game.fx.number(at + Vector2(0, -30), "−%s %s" % [Pal.money(money).trim_prefix("$"), CoreAsset.cause_short(cause)], Pal.heat(0.95, 1.4), 18)


# if each corner were furled now from where it stands: what the sail would fetch
func worth_now() -> float:
	var sum := 0.0
	for q in cfg.get("quads", {}):
		sum += corner_worth(q)
	return sum


func corner_worth(q: String) -> float:
	var qv := _quad_value(q)
	if furled(q):
		return qv * grade(q)
	var r: Dictionary = furl.get(q, {})
	var good := float(r.get("ok", 0.0))
	for t in _quad_panels(q):
		var p = world.tag(t)
		if p != null and not p.gone and not torn.has(t):
			good += float(_area0.get(t, 0.0)) * ((1.0 - float(r.get("f", 0.0))) if str(_winding.get(q, "")) == t else 1.0)
	return qv * clampf(good / maxf(quad_area(q), 0.0001), 0.0, 1.0) * clampf(1.0 - float(r.get("dmg", 0.0)), 0.0, 1.0)


# a corner's state in a few words: pull, progress, grade
func corner_state(q: String) -> Dictionary:
	var order := _quad_panels(q)
	var r: Dictionary = furl.get(q, {})
	var torn_n := 0
	for t in order:
		if torn.has(t):
			torn_n += 1
	var full := _quad_value(q)
	return {"taut": taut(q), "done": furled(q), "k": int(r.get("k", 0)), "n": order.size(), "winding": motor_on(q) and not furled(q),
		"grade": grade(q) if furled(q) else clampf(corner_worth(q) / maxf(full, 0.0001), 0.0, 1.0), "worth": corner_worth(q), "full": full, "torn": torn_n}

