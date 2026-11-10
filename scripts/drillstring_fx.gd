extends Node
# DR-150's drill string seen holding its torque and its mud — drawing only, scripts/drillstring.gd
# keeps every number (图鉴 cx_m_drill_torque: "八节立根仍然带有残余扭矩，钻杆内部也有受压的泥浆"，
# "关闭转盘刹车释放扭矩……再打开泄压阀排出可回收的泥浆"，"扭矩按照时间常数呈指数下降"；
# cx_m_drill_slips: "每节立根下方都有一副卡瓦"，"卡瓦由楔形牙块组成"，"上面的钻杆会因失去支撑而
# 掉落……下方整串钻杆会掉进井内").
#   The twist in each stand drawn on it as a helix of marks, steep with the torque in it; with
#   the rotary brake on they turn as it unwinds and lie down flat as it bleeds away, the brake at
#   the rotary table glowing with the work. The mud shows in the bore, dark and throbbing with
#   its pressure, falling as it is drawn off, pulses of it running along the mud line to the
#   port. Each joint's slips: toothed wedges either side of the pipe, set and gripping or drawn
#   back. A stand broken out loaded: the string seen whipping across the floor; stands dropping:
#   the string seen slipping down the hole.

const Kit = preload("res://scripts/mech_fx_kit.gd")

var ds
var game
var world
var node: Node2D
var glow: Node2D
var _spin := 0.0              # the helix's phase (turns as the torque comes off)
var _was_tq := 1.0
var _unwind := 0.0
var _was_mud := -1.0
var _drain := 0.0
var _slip := {}               # slip switch -> 0..1 set
var _drops: Array = []        # [polys, t]
var _was_dropped := 0
var _was_whip := false
var _whip_t := -1.0
var _whip_at := Vector2.ZERO
var _mudlines: Array = []
var _t := 0.0


func setup(d) -> void:
	ds = d
	game = d.game
	world = d.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	_was_tq = ds.torque
	_was_whip = ds.whipped
	_was_dropped = ds.dropped.size()
	for s in ds.cfg.get("slips", []):
		_slip[s] = 1.0 if game.sys.on(str(s)) else 0.0


func _stands() -> Array:
	var out: Array = []
	for t in ds.cfg.get("stands", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.body == null:
			out.append(p)
	return out


func _process(dt: float) -> void:
	if ds == null or not ds.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		node.queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	var d_tq: float = _was_tq - ds.torque
	_was_tq = ds.torque
	_unwind = Pal.damp(_unwind, clampf(d_tq / maxf(dt, 0.001) * 25.0, 0.0, 1.0), 4.0, dt)
	_spin += d_tq * 40.0
	var lvl: float = ds.mud_level()
	if _was_mud < 0.0:
		_was_mud = lvl
	_drain = Pal.damp(_drain, 1.0 if _was_mud - lvl > 0.000005 else 0.0, 3.0, dt)
	_was_mud = lvl
	for s in _slip:
		_slip[s] = move_toward(float(_slip[s]), 1.0 if game.sys.on(str(s)) else 0.0, 2.5 * dt)
	# the string slipping: what dropped seen going down the hole
	if ds.dropped.size() > _was_dropped:
		var polys: Array = []
		for t in ds.dropped:
			var p = world.tag(str(t))
			if p != null and not p.gone:
				polys.append(world.world_poly(p))
		_drops.append([polys, 0.0])
		for q in polys:
			game.fx.puff(Geom.centroid(q), Vector2.ZERO, 1.2, 8.0, 30.0, Pal.ink(0.18))
	_was_dropped = ds.dropped.size()
	for e in _drops:
		e[1] = float(e[1]) + dt
	_drops = _drops.filter(func(e): return float(e[1]) < 1.4)
	if ds.whipped and not _was_whip:
		_whip_t = 0.0
		var f: Array = ds.cfg.get("floor", [0, 0, 0, 0])
		_whip_at = Vector2((float(f[0]) + float(f[2])) * 0.5, float(f[3])) * Geom.M
	_was_whip = ds.whipped
	if _whip_t >= 0.0:
		_whip_t += dt
	node.queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	if ds == null or not ds.active():
		return
	var tq: float = ds.torque
	var lvl: float = ds.mud_level()
	var stands := _stands()
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	for p in stands:
		var bb := Geom.bbox(world.world_poly(p))
		var w := bb.size.x
		# the mud in the bore: a dark core, throbbing with the pressure on it
		if lvl > 0.01:
			var core := Rect2(bb.position.x + w * 0.32, bb.position.y + 2.0, w * 0.36, bb.size.y - 4.0)
			var th := 0.85 + 0.15 * sin(_t * 7.0 + bb.position.y * 0.05) * lvl
			node.draw_rect(core, Color(0.22, 0.15, 0.08, (0.35 + 0.45 * lvl) * th))
		# the twist: marks across the pipe, slanted with the torque, turning as it unwinds
		var slant := tq * 0.9
		var pitch := 14.0
		var off := fposmod(_spin * pitch, pitch)
		var y := bb.position.y + off
		while y < bb.end.y - 2.0:
			var y2 := y + w * slant
			if y2 > bb.end.y:
				break
			segs.append(Vector2(bb.position.x + 1.0, y))
			segs.append(Vector2(bb.end.x - 1.0, y2))
			cols.append(Pal.ink(0.18 + 0.4 * tq))
			y += pitch
	if not segs.is_empty():
		node.draw_multiline_colors(segs, cols, 1.0)
	# the slips at each joint: toothed wedges either side of the pipe
	var names: Array = ds.cfg.get("stands", [])
	var slips: Array = ds.cfg.get("slips", [])
	for k in slips.size():
		if k + 1 >= names.size():
			break
		var lo = world.tag(str(names[k + 1]))
		if lo == null or lo.gone or lo.body != null:
			continue
		var bb := Geom.bbox(world.world_poly(lo))
		var y := bb.position.y
		var s: float = _slip.get(slips[k], 0.0)
		var gap := lerpf(16.0, 0.0, s)
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var edge := bb.position.x if side < 0.0 else bb.end.x
			var x0 := edge + side * gap
			var wedge := PackedVector2Array([Vector2(x0, y - 6.0), Vector2(x0 + side * 10.0, y - 9.0), Vector2(x0 + side * 10.0, y + 9.0), Vector2(x0, y + 6.0)])
			Kit.fill(node, wedge, Color(0.1, 0.105, 0.12))
			Kit.outline(node, wedge, Pal.ink(0.5 + 0.35 * s), 1.1)
			for m in 3:
				var ty := y - 4.0 + m * 4.0
				node.draw_line(Vector2(x0, ty), Vector2(x0 - side * 2.0 * s, ty + 1.5), Pal.ink(0.6 * s), 1.0)
	# the string slipping down the hole
	for e in _drops:
		var u: float = float(e[1]) / 1.4
		var dy := Pal.ease_in(minf(1.0, u * 1.4)) * 3.0 * Geom.M
		for q in e[0]:
			Kit.outline(node, Transform2D(0.0, Vector2(0.0, dy)) * (q as PackedVector2Array), Pal.ink(0.6 * (1.0 - u)), 1.3)


func _draw_glow() -> void:
	if ds == null or not ds.active():
		return
	# the rotary brake doing the work
	if _unwind > 0.02:
		var rt := _rotary()
		if rt != Vector2.INF:
			Kit.disc(glow, rt, 26.0 + 14.0 * _unwind, Pal.heat(0.35 * _unwind, 1.5), 1.6, 0.5)
	# the mud going to the port along its line
	if _drain > 0.02:
		if _mudlines.is_empty():
			for id in world.lines:
				var l = world.lines[id]
				if str(l.net) == "mud" and l.path.size() > 1:
					_mudlines.append(l)
		var segs := PackedVector2Array()
		for l in _mudlines:
			if not l.alive:
				continue
			var path: PackedVector2Array = l.path
			for i in range(1, path.size()):
				var a := path[i - 1]
				var b := path[i]
				var L := a.distance_to(b)
				var x := fposmod(_t * 2.5 * Geom.M, 30.0)
				while x < L:
					segs.append(a.lerp(b, x / L))
					segs.append(a.lerp(b, minf(1.0, (x + 12.0) / L)))
					x += 30.0
		if not segs.is_empty():
			glow.draw_multiline(segs, Color(0.75, 0.55, 0.3, 0.6 * _drain), 2.0)
		# and down the bore
		for p in _stands():
			var bb := Geom.bbox(world.world_poly(p))
			for k in 3:
				var u := fposmod(_t * 1.4 + k / 3.0, 1.0)
				Kit.disc(glow, Vector2(bb.get_center().x, lerpf(bb.position.y, bb.end.y, u)), 5.0, Color(0.7, 0.5, 0.28, 0.45 * _drain))
	# a stand whipping across the floor
	if _whip_t >= 0.0 and _whip_t < 0.8:
		var u := _whip_t / 0.8
		var r := 6.0 * Geom.M
		var a0 := -PI * 0.95 + u * PI * 0.9
		glow.draw_arc(_whip_at, r, a0 - 0.6, a0, 16, Color(1.0, 0.85, 0.6, 0.8 * (1.0 - u)), 3.0)
		glow.draw_arc(_whip_at, r * 0.8, a0 - 0.4, a0, 12, Color(1.0, 0.85, 0.6, 0.5 * (1.0 - u)), 2.0)


func _rotary() -> Vector2:
	for t in ["RT", "ROTARY"]:
		var p = world.tag(t)
		if p != null and not p.gone:
			return world.frame(p) * Geom.centroid(p.poly)
	return Vector2.INF
