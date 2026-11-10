extends Node
# VT-80's cross-connected tanks seen holding and sharing their propellant — drawing only,
# scripts/tanknet.gd keeps every number (图鉴 cx_m_tanknet: "三个储罐通过交叉阀连接到同一根总管，
# 大型泵通过泵房回收口抽取总管里的液体"，"液体抽干后继续运行水泵，会因空转而损坏水泵；如果先排掉
# 罐顶气体再抽液，储罐可能被吸瘪"，"交叉阀打开后，各储罐的液位会通过总管逐渐趋于一致"，"增压阀
# 打开时，氮气球罐会维持储罐压力").
#   Each tank shows its propellant (held at its outlet by the tank's vanes: a level, its surface
#   trembling), the oxidiser warmer in tone than the fuel. A cross valve open: the levels run
#   toward each other, pulses along the branches into the manifold; the pump drawing: pulses on
#   to the recovery port. Its ullage losing pressure as liquid is drawn with no gas let in, the
#   tank's walls are seen drawn in, creaking, and buckled for good once it gives. The pump run on
#   with nothing to pump: it shudders and heats, then smokes when it is damaged.

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours

var tn
var game
var world
var node: Node2D
var glow: Node2D
var _was := {}
var _flow := {}               # vol -> how hard it is moving
var _p0 := {}
var _lines := {}              # vol -> [lines]
var _t := 0.0


func setup(t) -> void:
	tn = t
	game = t.game
	world = t.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)


func _process(dt: float) -> void:
	if tn == null or not tn.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		node.queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	var s = game.sys
	var vols: Array = [str(tn.cfg.get("manifold", ""))]
	for t in tn.cfg.tanks:
		vols.append(str(tn.cfg.tanks[t].vol))
		vols.append(str(tn.cfg.tanks[t].get("branch", "")))
		var uk: String = tn.cfg.tanks[t].get("ullage", "")
		if s.vols.has(uk) and not _p0.has(t):
			_p0[t] = maxf(1.0, s.P(uk))
	for v in vols:
		if v == "":
			continue
		var now: float = s.fluid(v)
		var d := absf(float(_was.get(v, now)) - now)
		_was[v] = now
		_flow[v] = Pal.damp(float(_flow.get(v, 0.0)), 1.0 if d > 0.000005 else 0.0, 3.0, dt)
	if tn._dry_t > 0.0 and fmod(_t, 0.12) < dt:
		var p = world.tag(str(tn.cfg.get("pump", "")))
		if p != null and not p.gone:
			var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
			game.fx.sparks(at, Vector2.UP, 2, Pal.heat(1.0, 2.0), 160.0, 0.3, PI)
	if tn.ran_dry and fmod(_t, 0.3) < dt:
		var p2 = world.tag(str(tn.cfg.get("pump", "")))
		if p2 != null and not p2.gone:
			game.fx.puff(world.frame(p2) * Geom.centroid(p2.poly), Vector2(10.0, -30.0), 2.0, 8.0, 34.0, Pal.ink(0.14))
	node.queue_redraw()
	glow.queue_redraw()


# how far a tank's walls are drawn in: by the vacuum in its ullage, for good once it buckled
func _suck(t: String) -> float:
	if tn.buckled.has(t):
		return 1.0
	var uk: String = tn.cfg.tanks[t].get("ullage", "")
	if not game.sys.vols.has(uk) or not _p0.has(t):
		return 0.0
	return clampf(1.0 - game.sys.P(uk) / (float(_p0[t]) * 0.6), 0.0, 1.0) * 0.6


func _draw() -> void:
	if tn == null or not tn.active():
		return
	for t in tn.cfg.tanks:
		var p = world.tag(t)
		if p == null or p.gone or p.body != null:
			continue
		var e: Dictionary = tn.cfg.tanks[t]
		var poly: PackedVector2Array = world.world_poly(p)
		var bb := Geom.bbox(poly)
		var c := bb.get_center()
		var suck := _suck(t)
		if suck > 0.01:
			# the walls drawn in at the middle of each long side (a buckle there once it gives)
			var dent := PackedVector2Array()
			for v in poly:
				var fx := 1.0 - absf(v.x - c.x) / maxf(1.0, bb.size.x * 0.5)
				var dy := (c.y - v.y) * 0.32 * suck * fx * (1.0 + 0.1 * sin(_t * 9.0) * (0.0 if tn.buckled.has(t) else 1.0))
				dent.append(Vector2(v.x, v.y + dy))
			Kit.outline(node, dent, Pal.ink(0.85), 2.0)
			for k in 3:
				var x := lerpf(bb.position.x, bb.end.x, (k + 1) / 4.0)
				node.draw_line(Vector2(x, bb.position.y + bb.size.y * 0.18 * suck), Vector2(x + 8.0, bb.position.y + bb.size.y * 0.3 * suck), Pal.ink(0.5 * suck), 1.0)
		var full := clampf(game.sys.fluid(e.vol) / maxf(0.001, float(e.cap)), 0.0, 1.0)
		if full <= 0.005:
			continue
		var top := bb.end.y - bb.size.y * full
		var surf := PackedVector2Array()
		var n := 16
		for i in n + 1:
			var x := lerpf(bb.position.x - 2.0, bb.end.x + 2.0, float(i) / n)
			surf.append(Vector2(x, top + sin(i * 1.3 + _t * 2.2) * 1.6 * (0.3 + _flow.get(e.vol, 0.0))))
		var body := surf.duplicate()
		body.append(Vector2(bb.end.x + 2.0, bb.end.y + 2.0))
		body.append(Vector2(bb.position.x - 2.0, bb.end.y + 2.0))
		var look: String = str(game.sys.fvol.get(e.vol, {}).get("look", "mmh"))
		var col := LC.of(look, 0.16 + 0.2 * LC.opacity(look))
		for q in Geometry2D.intersect_polygons(poly, body):
			Kit.fill(node, q, col)
		var line := PackedVector2Array()
		for v in surf:
			if Geometry2D.is_point_in_polygon(v, poly):
				line.append(v)
		if line.size() > 1:
			node.draw_polyline(line, Color(col.r, col.g, col.b, 0.7), 1.2)


func _vol_lines(v: String) -> Array:
	if _lines.has(v):
		return _lines[v]
	var nets: Array = game.sys.fvol.get(v, {}).get("nets", [])
	var out: Array = []
	for id in world.lines:
		var l = world.lines[id]
		if nets.has(l.net) and l.path.size() > 1:
			out.append(l)
	_lines[v] = out
	return out


func _draw_glow() -> void:
	if tn == null or not tn.active():
		return
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	var vols: Array = [str(tn.cfg.get("manifold", ""))]
	for t in tn.cfg.tanks:
		vols.append(str(tn.cfg.tanks[t].get("branch", "")))
	for v in vols:
		var f: float = float(_flow.get(v, 0.0))
		# a branch moves when its tank does
		for t in tn.cfg.tanks:
			if str(tn.cfg.tanks[t].get("branch", "")) == v:
				f = maxf(f, float(_flow.get(str(tn.cfg.tanks[t].vol), 0.0)))
		if f < 0.03:
			continue
		var look: String = str(game.sys.fvol.get(v, {}).get("look", "mmh"))
		var col := LC.of(look, 0.7 * f)
		for l in _vol_lines(v):
			if not l.alive:
				continue
			var path: PackedVector2Array = l.path
			for i in range(1, path.size()):
				var a := path[i - 1]
				var b := path[i]
				var L := a.distance_to(b)
				var x := fposmod(_t * 2.6 * Geom.M, 32.0)
				while x < L:
					segs.append(a.lerp(b, x / L))
					segs.append(a.lerp(b, minf(1.0, (x + 12.0) / L)))
					cols.append(col)
					x += 32.0
	if not segs.is_empty():
		glow.draw_multiline_colors(segs, cols, 1.8)
	# the pump running dry: heating
	if tn._dry_t > 0.0 or tn.ran_dry:
		var p = world.tag(str(tn.cfg.get("pump", "")))
		if p != null and not p.gone:
			var k := clampf(tn._dry_t / 3.0, 0.0, 1.0) if not tn.ran_dry else 0.5
			var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) + Vector2(sin(_t * 60.0), cos(_t * 53.0)) * 2.0 * k
			Kit.disc(glow, at, 50.0, Pal.heat(0.4 * k, 1.5), 1.3, 0.8)
