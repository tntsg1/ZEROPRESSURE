extends Node
# A container wall that is the ship's beam (exotic batch, CF-90 "Hive": "there is
# no hold: the containers in their slots are the hull; unload a column in the
# wrong order and the whole wall bends, then falls"). A ship file's "boxbeam":
#   {"bays": [[the bay's containers, top tier first], ...], "support": the bay the
#    berth holds it by, "stiff": what a container adds to a bay's stiffness (the
#    chords alone 1), "limit": the bending a bay takes, "gauges": {probe: bay},
#    "rods": {rod tag: {"turnbuckle": its switch, "bays": [the bays it holds],
#    "hits": [what it whips into], "kn": its pull}}}
#   Each bay bends under the containers outboard of it (towards the ship's ends,
#   from the bay the berth holds it by), each the further out the more; it is as
#   stiff as the chords and the containers still in it. Empty a bay while the
#   bays beyond it are still full and it bends past what it takes: the wall
#   kinks there, and everything still on beyond it is damaged. So the wall comes
#   down from the ends inwards. A strain gauge reads its bay's bending (% of what
#   it takes).
#   Within a bay the containers come off from the top: one taken from under
#   others still on lets the stack above sag onto it (damaged).
#   A pretension rod cut or freed with its turnbuckle still tight whips loose,
#   into what it hits, and knocks the containers in its bays.
# Saved: which sides kinked, which rods snapped.
#   (97 号's temporary props under a bay were removed 2026-11-12, user "从来没有用到过": the wall comes down
#   from the ends inwards.)
#   87-2: the wall really bends. Each bay outboard of the support turns about its inboard post by
#   an angle that follows its bending (elastic: back when the load comes off), the bays beyond
#   carried round with it, so the free end droops visibly as a column is emptied in the wrong
#   order; a kinked bay keeps a plastic angle for good. The containers, chords and posts move
#   with their bay (world.displace), so what you see is where they are. Saved: each bay's angle.

const KINK_KEEP := 0.5
const SAG_KEEP := 0.6
const SNAP_KEEP := 0.6

var game
var world
var cfg := {}
var kinked := {}              # "fwd"/"aft" -> true
var snapped := {}             # rod tag -> true
var _t := 0.0
const ELASTIC := 0.022         # rad a bay turns at its bending limit (1.0)
const PLASTIC := 0.11          # rad a kinked bay keeps
const FOLLOW := 2.5            # 1/s: how fast the wall settles to its load
var ang := {}                  # 87-2: bay -> the angle it has turned (rad, drooping)
var kink_bay := {}             # side -> the bay that kinked
var _applied := {}             # piece id -> the transform already put on it
var _pivots := {}              # bay -> its hinge (world px, as built)
var _members := {}             # bay -> [piece tags that move with it]
var _ready_ang := false
var bars: Node2D
const BAR_W := 4.0             # m


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("boxbeam", {})
	# 97 号 Q3 B: over each bay, its bending as a bar (red and flashing near the limit)
	if active():
		bars = Node2D.new()
		bars.z_index = 40
		bars.z_as_relative = false
		bars.draw.connect(_draw_bars)
		world.add_child(bars)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	var a := {}
	for b in ang:
		a[str(b)] = float(ang[b])
	return {"kinked": kinked.keys(), "snapped": snapped.keys(), "ang": a, "kink_bay": kink_bay.duplicate()}


func load_state(d: Dictionary) -> void:
	for k in d.get("kinked", []):
		kinked[str(k)] = true
	for k in d.get("snapped", []):
		snapped[str(k)] = true
	for k in d.get("kink_bay", {}):
		kink_bay[str(k)] = int(d.kink_bay[k])
	# the saved geometry already carries these angles: remember them as applied
	_build()
	for k in d.get("ang", {}):
		ang[int(k)] = float(d.ang[k])
	var xfs := _targets()
	for id in xfs:
		_applied[id] = xfs[id]
	_ready_ang = not ang.is_empty()


# 87-2: each bay's members (its containers, its chords, the post on its outboard side) and the
# hinge it turns about (its inboard post, at the wall's middle)
func _build() -> void:
	if not _pivots.is_empty() or not active():
		return
	var sup := int(cfg.get("support", 0))
	for b in cfg.bays.size():
		var lo := INF
		var hi := -INF
		var ys := 0.0
		var n := 0
		for t in cfg.bays[b]:
			var p = world.tag(str(t))
			if p == null:
				continue
			var bb := Geom.bbox(world.world_poly(p))
			lo = minf(lo, bb.position.x)
			hi = maxf(hi, bb.end.x)
			ys += bb.get_center().y
			n += 1
		if n == 0:
			continue
		var y := ys / n
		var m: Array = cfg.bays[b].duplicate()
		for t in ["TC-%d" % (b + 1), "BC-%d" % (b + 1)]:
			m.append(t)
		m.append("P%d" % (b + 1) if b > sup else "P%d" % b)
		_members[b] = m
		_pivots[b] = Vector2(lo - 0.4 * Geom.M, y) if b > sup else Vector2(hi + 0.4 * Geom.M, y)


# the angle each bay should have now: elastic with its bending, plus the kink's set
func _want(b: int) -> float:
	var sup := int(cfg.get("support", 0))
	var side := "fwd" if b < sup else "aft"
	var a := ELASTIC * minf(bend(b), 1.6)
	if kinked.has(side) and int(kink_bay.get(side, -1)) == b:
		a += PLASTIC
	return a


# each moving piece's transform for the bays' current angles: a bay turns about its hinge, and
# carries every bay beyond it round with it
func _targets() -> Dictionary:
	var out := {}
	var sup := int(cfg.get("support", 0))
	for b in _members:
		var xf := Transform2D.IDENTITY
		var chain: Array = range(sup + 1, b + 1) if b > sup else range(b, sup)
		for k in chain:
			if not _pivots.has(k):
				continue
			var sgn := 1.0 if b > sup else -1.0
			var pv: Vector2 = _pivots[k]
			var r := Transform2D(sgn * float(ang.get(k, 0.0)), Vector2.ZERO)
			xf = xf * (Transform2D(0.0, pv) * r * Transform2D(0.0, -pv))
		for t in _members[b]:
			var p = world.tag(str(t))
			if p != null:
				out[p.id] = xf
	return out


# the wall follows its load: the angles ease towards what the bending asks, and the members
# are moved by the difference (only while something actually moves)
func _settle(dt: float) -> void:
	_build()
	if not _ready_ang:
		# the wall as built already carries its full load: that shape is the starting point,
		# only changes from here move it
		_ready_ang = true
		for b in _members:
			ang[b] = _want(b)
		_applied = _targets()
		return
	var moving := false
	for b in _members:
		var want := _want(b)
		var now := float(ang.get(b, 0.0))
		var nxt := want + (now - want) * exp(-FOLLOW * dt)
		if absf(nxt - now) > 0.00002:
			moving = true
		ang[b] = nxt
	if not moving:
		return
	var xfs := _targets()
	for id in xfs:
		var p = world.pieces.get(id)
		if p == null or p.gone or p.body != null:
			continue
		var old: Transform2D = _applied.get(id, Transform2D.IDENTITY)
		var delta: Transform2D = xfs[id] * old.affine_inverse()
		if delta.origin.length() < 0.15 and absf(delta.get_rotation()) < 0.0003:
			continue
		world.displace(p, delta)
		_applied[id] = xfs[id]


# how far the wall's free ends hang off straight (m), for the gauges and the tests
func droop(side: String) -> float:
	var sup := int(cfg.get("support", 0))
	var end_bay: int = cfg.bays.size() - 1 if side == "aft" else 0
	if not _members.has(end_bay) or not _pivots.has(end_bay):
		return 0.0
	var xfs := _targets()
	var p = world.tag(str(cfg.bays[end_bay][0]))
	if p == null or not xfs.has(p.id):
		return 0.0
	var tip: Vector2 = _pivots[end_bay] + Vector2((12.0 if side == "aft" else -12.0) * Geom.M, 0)
	return (xfs[p.id] * tip - tip).y / Geom.M


func _on(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.body == null


# 97 号: the bay a piece of the wall belongs to (-1: none)
func bay_of(p) -> int:
	_build()
	for b in _members:
		if (_members[b] as Array).has(str(p.tag)):
			return b
	return -1


func fill(b: int) -> int:
	var n := 0
	for t in cfg.bays[b]:
		if _on(str(t)):
			n += 1
	return n


# a bay's bending as a share of what it takes (1 = at the limit)
func bend(b: int) -> float:
	var sup := int(cfg.get("support", 0))
	if b == sup:
		return 0.0
	var m := 0.0
	var nb: int = cfg.bays.size()
	if b < sup:
		for i in range(0, b):
			m += fill(i) * float(b - i)
	else:
		for i in range(b + 1, nb):
			m += fill(i) * float(i - b)
	var k: float = 1.0 + float(cfg.get("stiff", 0.75)) * fill(b)
	return m / k / float(cfg.get("limit", 6.0))


# what a strain gauge reads (%)
func strain(probe: String) -> float:
	var b := int(cfg.get("gauges", {}).get(probe, -1))
	if b < 0:
		return 0.0
	return 100.0 * bend(b)


func rod_tight(rod: String) -> bool:
	var e: Dictionary = cfg.get("rods", {}).get(rod, {})
	return not snapped.has(rod) and _on(rod) and game.sys.on(str(e.get("turnbuckle", "")))


func rod_pull(rod: String) -> float:
	return float(cfg.rods[rod].get("kn", 80.0)) if rod_tight(rod) else 0.0


# what still has to be made safe (the rods' turnbuckles)
func unsafe() -> Array:
	var out: Array = []
	for r in cfg.get("rods", {}):
		if rod_tight(r):
			out.append("rod %s tight" % r)
	return out


# the order a careful hand takes the containers off: the bays from the ends
# inwards to the one the berth holds, each from the top
func unload_order() -> Array:
	var sup := int(cfg.get("support", 0))
	var nb: int = cfg.bays.size()
	var bays: Array = range(nb)
	bays.sort_custom(func(a, c): return absi(a - sup) > absi(c - sup) if absi(a - sup) != absi(c - sup) else a < c)
	var seq: Array = []
	for b in bays:
		for t in cfg.bays[b]:
			seq.append(str(t))
	return seq


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	_settle(dt)
	_t += dt
	if _t < 0.2:
		return
	_t = 0.0
	if bars != null:
		bars.queue_redraw()
	var sup := int(cfg.get("support", 0))
	for b in cfg.bays.size():
		var side := "fwd" if b < sup else "aft"
		if b == sup or kinked.has(side):
			continue
		if bend(b) > 1.0:
			_kink(b, side)


func _kink(b: int, side: String) -> void:
	kinked[side] = true
	kink_bay[side] = b
	var lost := 0.0
	var at := Vector2.ZERO
	var n := 0
	for i in cfg.bays.size():
		if (side == "fwd" and i >= b) or (side == "aft" and i <= b):
			continue
		for t in cfg.bays[i]:
			var p = world.tag(str(t))
			if p == null or p.gone or p.body != null or not p.intact:
				continue
			var before: float = p.cond
			game._dent(p, minf(p.cond, KINK_KEEP), "dv_kink")
			lost += (before - p.cond) * p.value
			at += world.frame(p) * Geom.centroid(p.poly)
			n += 1
	if n > 0:
		at /= float(n)
	game.incident("beam_kink", "%s %d" % [side, b])
	game.say("beam_kink", at, "")
	game.note_loss("loss_kink", "", lost)
	game.shake(0.8)
	game.sfx.play("snap")


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		# a container taken from under others still on
		for bay in cfg.bays:
			var i: int = bay.find(q.tag)
			if i <= 0:
				continue
			var lost := 0.0
			for k in range(0, i):
				var p = world.tag(str(bay[k]))
				if p == null or p.gone or p.body != null or not p.intact:
					continue
				var before: float = p.cond
				game._dent(p, minf(p.cond, SAG_KEEP), "dv_sag")
				lost += (before - p.cond) * p.value
			if lost > 0.0:
				game.incident("stack_sag", q.tag)
				game.say("stack_sag", world.frame(q) * Geom.centroid(q.poly), q.tag)
				game.note_loss("loss_sag", q.tag, lost)
		_rod(q)


func on_cut(p) -> void:
	if active():
		_rod(p)


func _rod(p) -> void:
	var rods: Dictionary = cfg.get("rods", {})
	if not rods.has(p.tag) or snapped.has(p.tag):
		return
	var e: Dictionary = rods[p.tag]
	if not game.sys.on(str(e.get("turnbuckle", ""))):
		return
	snapped[p.tag] = true
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	if world.rope_fx != null:
		world.rope_fx.snap_member(world.world_poly(p), at, 1.0)
	var lost := 0.0
	var hit: Array = e.get("hits", []).duplicate()
	for bi in e.get("bays", []):
		hit.append_array(cfg.bays[int(bi)])
	for t in hit:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, SNAP_KEEP), "dv_rod_snap")
		lost += (before - q.cond) * q.value
	game.incident("rod_snap", p.tag)
	game.say("rod_snap", at, p.tag)
	game.note_loss("loss_rod_snap", p.tag, lost)
	game.shake(0.6)
	game.sfx.play("snap")


# 97 号: a bar over each bay, as long as its bending (the tick at the limit), its number and
# reading beside it; a kinked one says so; a fixed size on the screen
func _draw_bars() -> void:
	_build()
	var z: float = maxf(game.cam_zoom(), 0.05)
	var k := 1.0 / z
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	var sup := int(cfg.get("support", 0))
	var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.35
	for b in _members:
		var tc = world.tag("TC-%d" % (b + 1))
		if tc == null or tc.gone or tc.body != null:
			continue
		var bb := Geom.bbox(world.world_poly(tc))
		var mid := Vector2(bb.get_center().x, bb.position.y - 1.4 * Geom.M)
		var side := "fwd" if b < sup else "aft"
		var bent: bool = kinked.has(side) and int(kink_bay.get(side, -1)) == b
		var v := bend(b)
		var w := BAR_W * Geom.M
		var col := Pal.ink(0.75)
		if bent or v > 1.0:
			col = Pal.heat(0.95, 1.5)
		elif v > 0.85:
			col = Pal.heat(0.9, 1.3) if flash else Pal.heat(0.5, 1.1)
		elif v > 0.6:
			col = Pal.heat(0.7, 1.05)
		var x0 := mid.x - w * 0.5
		bars.draw_rect(Rect2(Vector2(x0, mid.y), Vector2(w, 0.35 * Geom.M)), Color(0.05, 0.055, 0.065, 0.85), true)
		bars.draw_rect(Rect2(Vector2(x0, mid.y), Vector2(w * clampf(v / 1.2, 0.0, 1.0), 0.35 * Geom.M)), col, true)
		var lim := x0 + w / 1.2
		bars.draw_line(Vector2(lim, mid.y - 0.15 * Geom.M), Vector2(lim, mid.y + 0.5 * Geom.M), Pal.ink(0.8), 1.5 * k)
		bars.draw_rect(Rect2(Vector2(x0, mid.y), Vector2(w, 0.35 * Geom.M)), Pal.ink(0.45), false, 1.0 * k)
		var txt := ""
		if b == sup:
			txt = "%d · %s" % [b + 1, "船坞夹持" if Txt.zh else "HELD"]
		elif bent:
			txt = "%d · %s" % [b + 1, "已折弯" if Txt.zh else "KINKED"]
		else:
			txt = "%d · %d%%" % [b + 1, int(round(v * 100.0))]
		bars.draw_set_transform(Vector2(x0, mid.y - 0.25 * Geom.M), 0.0, Vector2(k, k))
		bars.draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.02, 0.022, 0.028, 0.85))
		bars.draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col if b != sup else Pal.ink(0.6))
		bars.draw_set_transform(Vector2.ZERO)
