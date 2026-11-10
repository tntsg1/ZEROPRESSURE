extends Node
# CH-110's clamps and cracked beam seen working — drawing only, scripts/sandwich.gd keeps every
# number (图鉴 cx_m_sandwich: "上下两条船体通过 8 个液压夹钳夹住中间的居住舱"，"货舱没有放气就松开
# 夹钳，夹钳会弹开。如果一侧比另一侧多松开两个夹钳，货舱会发生扭转，已经开裂的横梁 2 也会断裂"，
# "横梁 2 已经开裂，载荷表读数为 192 kN").
#   Each clamp's two jaws bite on the habitat while its hold is on, its pressure lamp lit; let
#   go, the jaws swing back off it (a hiss of oil vapour); let go with the habitat still under
#   pressure, they fly open with sparks and the habitat jumps on its seats and rings. Let go
#   unevenly, the habitat is seen twisting between the hulls and settling. Beam 2's crack shows
#   on it, brighter the more load it carries (192 kN held, nothing once it is unloaded); torn
#   out with a clamp beside it still holding, it snaps: a flash along the crack, the halves
#   thrown apart.

const Kit = preload("res://scripts/mech_fx_kit.gd")

var sw
var game
var world
var node: Node2D
var glow: Node2D
var _open := {}               # clamp piece -> 0..1 jaws open
var _fast := {}               # clamp piece -> sprang open
var _was_sprung := false
var _was_twisted := false
var _was_torn := false
var _jump := -1.0             # s since the habitat sprang
var _twist := -1.0            # s since it twisted
var _snap := -1.0             # s since beam 2 tore
var _crack := PackedVector2Array()
var _t := 0.0


func setup(s) -> void:
	sw = s
	game = s.game
	world = s.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	_was_sprung = sw.sprung
	_was_twisted = sw.twisted
	_was_torn = sw.torn
	for c in sw.cfg.get("clamps", {}):
		_open[c] = 0.0 if game.sys.on(str(sw.cfg.clamps[c])) else 1.0


func _process(dt: float) -> void:
	if sw == null or not sw.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		node.queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	if sw.sprung and not _was_sprung:
		_jump = 0.0
	if sw.twisted and not _was_twisted:
		_twist = 0.0
	if sw.torn and not _was_torn:
		_snap = 0.0
		var c := _beam_mid()
		game.fx.sparks(c, Vector2.UP, 40, Pal.heat(1.0, 2.2), 520.0, 0.8, PI)
		game.fx.burst_shards(c, 10, 260.0, Pal.ink(0.7), 9.0)
	_was_sprung = sw.sprung
	_was_twisted = sw.twisted
	_was_torn = sw.torn
	if _jump >= 0.0:
		_jump += dt
	if _twist >= 0.0:
		_twist += dt
	if _snap >= 0.0:
		_snap += dt
	for c in sw.cfg.get("clamps", {}):
		var held: bool = game.sys.on(str(sw.cfg.clamps[c]))
		var was: float = _open.get(c, 0.0)
		if not held and was < 0.01:
			# just let go: under pressure it flies open
			_fast[c] = sw.cargo_kpa() > float(sw.cfg.get("spring_kpa", 20.0))
			var p = world.tag(c)
			if p != null and not p.gone:
				var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
				if _fast[c]:
					game.fx.sparks(at, _toward(p), 18, Pal.heat(1.0, 2.0), 420.0, 0.5, 1.0)
				else:
					game.fx.puff(at, Vector2.UP * 30.0, 1.0, 6.0, 22.0, Pal.ink(0.2))
		var rate := 9.0 if _fast.get(c, false) else 1.6
		_open[c] = move_toward(was, 0.0 if held else 1.0, rate * dt)
	node.queue_redraw()
	glow.queue_redraw()


# the way a clamp faces: toward the habitat between the hulls
func _toward(p) -> Vector2:
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var mid := Vector2.ZERO
	var n := 0
	for r in sw.cfg.get("rooms", []):
		var rp := Kit.room_poly(world, str(r))
		if rp.size() > 2:
			mid += Geom.centroid(rp)
			n += 1
	if n == 0:
		return Vector2.DOWN
	mid /= n
	return Vector2(0.0, signf(mid.y - c.y) if absf(mid.y - c.y) > 1.0 else 1.0)


func _beam_mid() -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for t in sw.cfg.get("cracked", {}).get("pieces", []):
		var p = world.tag(str(t))
		if p != null:
			s += world.frame(p) * Geom.centroid(p.poly)
			n += 1
	return s / maxf(1.0, n)


func _cargo_xf() -> Transform2D:
	# the habitat jumping on its seats (sprung) or twisting between the hulls (twisted): a
	# damped ring, drawn as its outline moving over it
	var c := Vector2.ZERO
	var n := 0
	for r in sw.cfg.get("rooms", []):
		var rp := Kit.room_poly(world, str(r))
		if rp.size() > 2:
			c += Geom.centroid(rp)
			n += 1
	c /= maxf(1.0, n)
	var off := Vector2.ZERO
	var ang := 0.0
	if _jump >= 0.0 and _jump < 1.6:
		off.y = -sin(_jump * 18.0) * exp(-_jump * 3.0) * 14.0
	if _twist >= 0.0 and _twist < 2.2:
		ang = sin(_twist * 9.0) * exp(-_twist * 2.0) * 0.045 + 0.012 * minf(1.0, _twist * 4.0) * exp(-_twist * 0.8)
	return Transform2D(ang, c + off) * Transform2D(0.0, -c)


func _draw() -> void:
	if sw == null or not sw.active():
		return
	# the clamps' jaws
	for c in sw.cfg.get("clamps", {}):
		var p = world.tag(c)
		if p == null or p.gone or p.body != null:
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var bb := Geom.bbox(poly)
		var n := _toward(p)
		var edge_y := bb.end.y if n.y > 0.0 else bb.position.y
		var o: float = _open.get(c, 0.0)
		var ang := o * 0.95
		var L := bb.size.x * 0.48
		var th := 8.0
		for side in [-1.0, 1.0]:
			var pivot := Vector2(bb.get_center().x + side * bb.size.x * 0.48, edge_y + n.y * th * 0.5)
			# each jaw lies along the face, closed; swings back about its outer end, open
			var dir := Vector2(-side, 0.0).rotated(side * ang * n.y)
			var tip := pivot + dir * L
			var nrm := dir.orthogonal() * th * 0.5
			var jaw := PackedVector2Array([pivot + nrm, tip + nrm, tip - nrm, pivot - nrm])
			Kit.fill(node, jaw, Color(0.11, 0.115, 0.13))
			Kit.outline(node, jaw, Pal.ink(0.85), 1.2)
			# the teeth biting
			for k in 4:
				var q := pivot.lerp(tip, (k + 0.5) / 4.0) + n * th * 0.5
				node.draw_line(q, q + n * 3.0, Pal.ink(0.6), 1.0)
	# the habitat's outline when it jumps or twists
	var xf := _cargo_xf()
	if xf != Transform2D.IDENTITY and ((_jump >= 0.0 and _jump < 1.6) or (_twist >= 0.0 and _twist < 2.2)):
		for r in sw.cfg.get("rooms", []):
			var rp := Kit.room_poly(world, str(r))
			if rp.size() > 2:
				Kit.outline(node, xf * rp, Pal.ink(0.75), 1.6)
	# beam 2's crack
	if _crack.is_empty():
		_build_crack()
	if not _crack.is_empty():
		var torn: bool = sw.torn
		if torn:
			for i in range(0, _crack.size(), 2):
				var a := _crack[i]
				var b := _crack[i + 1]
				var nn := (b - a).orthogonal().normalized() * 3.0
				Kit.fill(node, PackedVector2Array([a + nn, b + nn, b - nn, a - nn]), Color(0.015, 0.016, 0.02))
		node.draw_multiline(_crack, Pal.ink(0.55 if not torn else 0.8), 1.2)


func _build_crack() -> void:
	var pts: Array = []
	for t in sw.cfg.get("cracked", {}).get("pieces", []):
		var p = world.tag(str(t))
		if p != null and not p.gone:
			pts.append(p)
	if pts.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 110
	# a crack running across the beam's middle piece, with a few branches
	var p = pts[mini(2, pts.size() - 1)]
	var bb := Geom.bbox(p.poly)
	var cur := Vector2(bb.position.x, bb.get_center().y + bb.size.y * 0.1)
	var n := 8
	for i in n:
		var nx := Vector2(bb.position.x + bb.size.x * (i + 1) / n, cur.y + rng.randf_range(-0.35, 0.35) * bb.size.x * 0.4)
		_crack.append(cur)
		_crack.append(nx)
		if i % 3 == 1:
			_crack.append(nx)
			_crack.append(nx + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(0.4, 0.9) * (1.0 if i % 2 == 0 else -1.0)) * bb.size.x * 0.4)
		cur = nx


func _draw_glow() -> void:
	if sw == null or not sw.active():
		return
	# the clamps holding: their pressure lamp lit
	for c in sw.cfg.get("clamps", {}):
		var p = world.tag(c)
		if p == null or p.gone or p.body != null:
			continue
		var held: bool = game.sys.on(str(sw.cfg.clamps[c]))
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
		if held:
			Kit.disc(glow, at, 10.0, Pal.heat(0.55 + 0.1 * sin(_t * 3.0 + at.x), 1.4))
	# beam 2 under its load: the crack lit with the stress (192 kN of 120 it was built for)
	if not _crack.is_empty() and not sw.torn:
		var kn := 0.0
		for lc in sw.cfg.get("loads", {}):
			if sw.cfg.loads[lc].has("k"):
				kn = sw.load(lc)
		var k := clampf((kn - 60.0) / 140.0, 0.0, 1.0)
		if k > 0.01:
			glow.draw_multiline(_crack, Pal.heat((0.25 + 0.5 * k) * (0.8 + 0.2 * sin(_t * 4.0)), 1.6), 1.6)
	if _snap >= 0.0 and _snap < 1.0:
		var a := pow(1.0 - _snap, 2.0)
		glow.draw_multiline(_crack, Color(1.0, 0.92, 0.75, a), 3.0)
		Kit.disc(glow, _beam_mid(), 26.0 + 30.0 * _snap, Color(1.0, 0.85, 0.6, 0.7 * a))
		Kit.disc(glow, _beam_mid(), 60.0 + 40.0 * _snap, Pal.heat(0.25 * a, 1.6))
