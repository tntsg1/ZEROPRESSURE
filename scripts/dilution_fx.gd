extends Node
# QC-30's dilution fridge seen cold, warming and failing — drawing only, scripts/dilution.gd keeps
# every number (图鉴 cx_m_dilution: "量子芯片放在混合室里，温度接近绝对零度。外面有好几层冷板，靠
# 制冷机一直降温"，"混合气还没回收就停冷头，气体受热沸腾，可能损坏冷板。芯片温度太低时直接加热，
# 也可能裂开"，"混合室最冷、回温最慢"，"隔振台没锁，附近的切割会通过台面震到芯片").
#   Each plate of the stack frosted and cold-blue for how cold it is (the mixing chamber the
#   bluest); with the pulse tube off the frost goes plate by plate, the top ones first, the
#   mixing chamber last. The pulse tube running: its compressor pulses and cold travels down
#   the stack. The heaters on: the plates glow faintly warm. The mixture boiling: the still and
#   cold plate seethe and spit vapour. The chip cracked: a bright fracture across it. The table
#   unlocked: the stack trembles with any cut close by.

const Kit = preload("res://scripts/mech_fx_kit.gd")

var dl
var game
var world
var node: Node2D
var glow: Node2D
var _boil_t := -1.0
var _was_boiled := false
var _shake_t := -99.0
var _was_shake := -99.0
var _t := 0.0


func setup(d) -> void:
	dl = d
	game = d.game
	world = d.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	_was_boiled = dl.boiled
	_was_shake = dl._shake_t


func _process(dt: float) -> void:
	if dl == null or not dl.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		node.queue_redraw()
		glow.queue_redraw()
		return
	_t += dt
	if dl.boiled and not _was_boiled:
		_boil_t = 0.0
	_was_boiled = dl.boiled
	if _boil_t >= 0.0:
		_boil_t += dt
		if _boil_t < 3.0 and fmod(_t, 0.06) < dt:
			for t in ["STG-STILL", "STG-CP"]:
				var q = world.tag(t)
				if q != null and not q.gone:
					var c: Vector2 = world.frame(q) * Geom.centroid(q.poly)
					game.fx.puff(c + Vector2(randf_range(-40.0, 40.0), 0.0), Vector2(randf_range(-80.0, 80.0), randf_range(-60.0, 60.0)), 1.0, 4.0, 24.0, Pal.ink(0.3))
	if dl._shake_t != _was_shake:
		_shake_t = _t
		_was_shake = dl._shake_t
	node.queue_redraw()
	glow.queue_redraw()


# how cold a plate is shown: 1 at the mixing chamber's base, 0 at room temperature
func _cold(st: String) -> float:
	var T: float = dl.stage_temp(st)
	return clampf(1.0 - log(maxf(T, 0.01) / 0.01) / log(dl.ROOM / 0.01), 0.0, 1.0)


func _draw() -> void:
	if dl == null or not dl.active():
		return
	var jit := Vector2.ZERO
	if _t - _shake_t < 0.8:
		var a := 1.0 - (_t - _shake_t) / 0.8
		jit = Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 3.0 * a
	for st in dl.cfg.get("order", []):
		var p = world.tag(str(st))
		if p == null or p.gone or p.body != null:
			continue
		var poly: PackedVector2Array = Transform2D(0.0, jit) * world.world_poly(p)
		var k := _cold(str(st))
		Kit.fill(node, poly, Color(0.5, 0.75, 1.0, 0.06 + 0.22 * k * k))
		# frost along the plate's underside, longer the colder
		var bb := Geom.bbox(poly)
		if k > 0.25:
			var n := int(bb.size.x / 9.0)
			for i in n:
				var x := bb.position.x + (i + 0.5) * bb.size.x / n
				var L := (2.0 + 6.0 * (k - 0.25) / 0.75) * (0.6 + 0.4 * sin(i * 2.3))
				node.draw_line(Vector2(x, bb.end.y), Vector2(x + 1.5, bb.end.y + L), Color(0.85, 0.93, 1.0, 0.5 * k), 1.0)
	# the chip
	var c = world.tag(str(dl.cfg.get("chip", "")))
	if c != null and not c.gone and dl.cracked != "":
		var bb := Geom.bbox(world.world_poly(c))
		var a := bb.position + Vector2(0, bb.size.y * 0.3)
		var pts := PackedVector2Array([a, a + Vector2(bb.size.x * 0.35, bb.size.y * 0.25), a + Vector2(bb.size.x * 0.55, -bb.size.y * 0.1), bb.end - Vector2(0, bb.size.y * 0.35)])
		node.draw_polyline(pts, Pal.ink(0.95), 1.4)
		node.draw_line(pts[1], pts[1] + Vector2(0, bb.size.y * 0.5), Pal.ink(0.7), 1.0)


func _draw_glow() -> void:
	if dl == null or not dl.active():
		return
	var run: bool = dl.running()
	var heat: bool = game.sys.on(str(dl.cfg.get("heater", "")))
	var order: Array = dl.cfg.get("order", [])
	var cen := Vector2.INF
	for i in order.size():
		var p = world.tag(str(order[i]))
		if p == null or p.gone or p.body != null:
			continue
		var poly: PackedVector2Array = world.world_poly(p)
		var bb := Geom.bbox(poly)
		if i == 0:
			cen = Vector2(bb.get_center().x, bb.position.y)
		# the cold running down the stack while the pulse tube runs
		if run:
			var u := fposmod(_t * 0.8 - i * 0.18, 1.0)
			glow.draw_line(Vector2(bb.position.x, bb.get_center().y), Vector2(bb.end.x, bb.get_center().y), Color(0.55, 0.8, 1.0, 0.35 * pow(1.0 - u, 3.0)), 2.0)
		if heat:
			Kit.disc(glow, bb.get_center(), bb.size.x * 0.6, Pal.heat(0.18 + 0.05 * sin(_t * 4.0 + i), 1.2), 1.0, 0.25)
		if _boil_t >= 0.0 and _boil_t < 3.0 and str(order[i]) in ["STG-STILL", "STG-CP"]:
			var a := 1.0 - _boil_t / 3.0
			for b in 6:
				var bp := bb.position + Vector2(bb.size.x * fposmod(b * 0.37 + _t * 0.9, 1.0), bb.size.y * 0.5 + sin(_t * 20.0 + b) * 4.0)
				glow.draw_arc(bp, 3.0 + 2.0 * sin(_t * 15.0 + b), 0.0, TAU, 10, Pal.ink(0.7 * a), 1.0)
	# the compressor pulsing
	if run:
		var pc = world.tag(str(dl.cfg.get("compressor", "")))
		if pc != null and not pc.gone:
			var at: Vector2 = world.frame(pc) * Geom.centroid(pc.poly)
			var u := fposmod(_t * 1.4, 1.0)
			Kit.ring(glow, at, 20.0 + 40.0 * u, Color(0.55, 0.8, 1.0, 0.45 * (1.0 - u)), 1.4)
