extends Node
# CL-104's cold holds seen cold — drawing only, scripts/coldchain.gd keeps every number
# (图鉴 cx_m_coldchain: "三个冷舱的温度保持在 −25 °C，由冷机和制冷主机提供冷却"，"切断电源或损坏
# 制冷系统，冷舱就会逐渐回温。温度超过 −5 °C 后，货物会解冻"，"先在外部面板接通‘船坞临时供冷’").
#   Each hold's walls are furred with frost, thick at −25 °C; as a hold warms the frost goes back
#   frond by frond until only the corners keep any, and near the thaw the walls bead with water.
#   While something keeps a hold cold its chiller (or the berth's temporary supply at its socket)
#   breathes cold air into it in pale wisps. The cargo thawed: the pallets lose their rime, sweat,
#   and shed drops into the hold.

const Kit = preload("res://scripts/mech_fx_kit.gd")
const LC = preload("res://scripts/liquid_colors.gd")   # real liquid colours

var cc
var game
var world
var node: Node2D
var _frost := {}              # room -> [segments, per-segment thresholds]
var _wisps := {}
var _thaw_t := {}             # room -> s since its cargo thawed
var _t := 0.0


func setup(c) -> void:
	cc = c
	game = c.game
	world = c.world
	node = Kit.node(world, false, _draw)
	game.add_child(self)
	for r in cc.thawed:
		_thaw_t[r] = 99.0


func _build(room: String) -> void:
	var rp := Kit.room_poly(world, room)
	var segs := PackedVector2Array()
	var th := PackedFloat32Array()
	if rp.size() < 3:
		_frost[room] = [segs, th]
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room)
	var c := Geom.centroid(rp)
	var n := rp.size()
	for i in n:
		var a := rp[i]
		var b := rp[(i + 1) % n]
		var L := a.distance_to(b)
		var inward := (b - a).orthogonal().normalized()
		if inward.dot(c - (a + b) * 0.5) < 0.0:
			inward = -inward
		var m := int(L / (0.45 * Geom.M))
		for k in m:
			var u := (k + rng.randf()) / maxf(1.0, m)
			var base := a.lerp(b, u)
			# frost holds on longest in the corners: a frond's threshold rises toward mid-wall
			var corner := minf(u, 1.0 - u) * 2.0
			var t0 := clampf(0.15 + 0.75 * corner + rng.randf_range(-0.12, 0.12), 0.02, 0.98)
			var dir := inward.rotated(rng.randf_range(-0.5, 0.5))
			var ln := rng.randf_range(0.25, 0.7) * Geom.M
			var tip := base + dir * ln
			segs.append_array(PackedVector2Array([base, tip]))
			th.append(t0)
			for j in 3:
				var at := base.lerp(tip, (j + 1) / 4.0)
				var side := 1.0 if j % 2 == 0 else -1.0
				segs.append_array(PackedVector2Array([at, at + dir.rotated(side * 0.8) * ln * 0.3]))
				th.append(t0 + 0.05)
	_frost[room] = [segs, th]


func _process(dt: float) -> void:
	if cc == null or not cc.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		node.queue_redraw()
		return
	_t += dt
	for r in cc.thawed:
		if not _thaw_t.has(r):
			_thaw_t[r] = 0.0
			for t in cc.cfg.get("cargo", {}).get(r, []):
				var p = world.tag(str(t))
				if p != null and not p.gone:
					var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
					for k in 4:
						game.fx.drop(at, Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0), 2.0, Pal.tint(LC.of("water"), 0.8, 1.2))
		_thaw_t[r] = float(_thaw_t[r]) + dt
	node.queue_redraw()


# where the cold comes in: the hold's chiller, or the temporary supply's socket
func _source(room: String) -> Vector2:
	if cc.supplied():
		var s: String = cc.cfg.get("supply", "")
		if world.ctrls.has(s):
			return world.ctrl_world(world.ctrls[s])
	for ch in cc.cfg.get("chillers", {}):
		if room in cc.cfg.chillers[ch]:
			var p = world.tag(ch)
			if p != null and not p.gone:
				return world.frame(p) * Geom.centroid(p.poly)
	return Vector2.INF


func _draw() -> void:
	if cc == null or not cc.active():
		return
	for r in cc.temp:
		if not _frost.has(r):
			_build(r)
		var T: float = cc.room_temp(r)
		var k := clampf((-T - 2.0) / 23.0, 0.0, 1.0)
		var rp := Kit.room_poly(world, r)
		if rp.size() < 3 or not world.rooms[r].revealed:
			continue
		# the cold itself: a faint blue in the hold's air
		Kit.fill(node, rp, Color(0.55, 0.75, 0.95, 0.035 * k))
		# frost on its walls, going back as it warms
		var e: Array = _frost[r]
		var segs: PackedVector2Array = e[0]
		var th: PackedFloat32Array = e[1]
		var out := PackedVector2Array()
		var cols := PackedColorArray()
		for i in th.size():
			var vis := clampf((k - (1.0 - th[i])) * 6.0, 0.0, 1.0)
			if vis <= 0.0:
				continue
			out.append(segs[i * 2])
			out.append(segs[i * 2].lerp(segs[i * 2 + 1], vis))
			cols.append(Color(0.8, 0.9, 1.0, 0.55 * vis))
		if not out.is_empty():
			node.draw_multiline_colors(out, cols, 1.0)
		# near the thaw: water beading on the walls
		var wet := clampf((T + 12.0) / 7.0, 0.0, 1.0)
		if wet > 0.0:
			for i in range(0, segs.size(), 8):
				var p := segs[i]
				var wob := sin(_t * 1.5 + i) * 1.0
				node.draw_circle(p + Vector2(wob, 0), 1.5 + 1.5 * wet, Pal.tint(LC.of("water"), 0.45 * wet, 1.2))
		# the cold coming in: wisps off the chiller or the supply
		if cc.held(r):
			var src := _source(r)
			if src != Vector2.INF:
				var c := Geom.centroid(rp)
				for w in 5:
					var u := fposmod(_t * 0.25 + w * 0.2, 1.0)
					var at := src.lerp(c, u * 0.8) + Vector2(sin(_t * 1.3 + w * 2.0), cos(_t * 1.1 + w)) * 18.0 * u
					if Geometry2D.is_point_in_polygon(at, rp):
						Kit.disc(node, at, 14.0 + 40.0 * u, Color(0.8, 0.9, 1.0, 0.12 * sin(u * PI)))
	# the cargo thawed: sweating pallets
	for r in _thaw_t:
		for t in cc.cfg.get("cargo", {}).get(r, []):
			var p = world.tag(str(t))
			if p == null or p.gone:
				continue
			var poly: PackedVector2Array = world.world_poly(p)
			Kit.fill(node, poly, Pal.tint(LC.of("water"), 0.07, 0.9))
			Kit.outline(node, poly, Pal.tint(LC.of("water"), 0.6 + 0.15 * sin(_t * 2.0), 1.2), 1.6)
			var bb := Geom.bbox(poly)
			for k in 5:
				var u := fposmod(_t * 0.3 + k * 0.21 + float(p.id % 7) * 0.13, 1.0)
				var at := Vector2(bb.position.x + bb.size.x * fposmod(k * 0.37 + 0.1, 1.0), bb.end.y + u * 20.0)
				node.draw_circle(at, 3.0 * (1.0 - u * 0.4), Pal.tint(LC.of("water"), 0.8 * (1.0 - u), 1.3))
