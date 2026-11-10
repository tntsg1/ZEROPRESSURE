extends Node
# What is in a room's air, seen — one layer for the three mechanisms that put something there,
# drawing only (each mechanism keeps its own numbers):
#   ST-40, composite fumes (图鉴 cx_m_composite: "在有气体的舱室附近用激光切割板件，会产生有毒烟雾，
#     使电子设备价值降低、玻璃起雾"，"将舱室抽成真空时，烟雾会随空气一同排出"): black smoke rolls
#     off the cut, the room fills with a grey haze and drifting soot and carbon-fibre specks as
#     thick as composite.gd's level for it; the glass it fogged goes milky. Vented, the haze
#     streams out with the air through the opening and thins.
#   MED-47, biological contamination (cx_m_bio: "污染物会进入舱内空气并随气流扩散"，"负压使空气
#     流向隔离舱"，"回收软管的过滤器可以过滤空气中的污染物"): a contaminated room's air is full of
#     motes, as many as its index; where two rooms are open to each other the air is seen moving
#     from the higher pressure to the lower, motes carried along it (into the isolation rooms
#     while they are under negative pressure; outward once that is lost); a recovery hose with
#     its filter draws motes into its port.
#   HB-86 / MY-48, oxygen-rich air (cx_m_o2_flash: "部分舱室的氧气浓度远高于普通空气中的 21%"，
#     "在附近使用激光会引发全舱闪燃，烧坏设备并损伤无人机"，"燃烧速度也会成倍提高"): a rich room's
#     air has a faint pale shimmer, stronger the richer; the flash fire runs out from where it
#     caught through the whole room in under a second, burns a few seconds, gutters out as the
#     oxygen is used up, and leaves the room scorched and smoky.
# One instance per game (made by whichever of the three comes first, cabin_fx.ensure).

const Kit = preload("res://scripts/mech_fx_kit.gd")

var game
var world
var node: Node2D
var glow: Node2D
var _t := 0.0
var _smoke_was := {}
var _fires: Array = []        # {room, from, t}
var _scorch := {}             # room -> [discs]
var _last := {}               # atmos _last copy
var _motes := {}              # room -> PackedVector2Array of mote seeds (0..1 in its bbox)


static func ensure(g):
	var w = g.world
	if w.has_meta("cabin_fx"):
		return w.get_meta("cabin_fx")
	var c = load("res://scripts/cabin_fx.gd").new()
	c.game = g
	c.world = w
	c.node = Kit.node(w, false, c._draw)
	c.glow = Kit.node(w, true, c._draw_glow)
	g.add_child(c)
	w.set_meta("cabin_fx", c)
	return c


func _comp():
	var c = game.get("composite")
	return c if c != null and c.active() else null


func _bio():
	var b = game.get("bio")
	return b if b != null and b.active() else null


func _atmos():
	var a = game.get("atmos")
	return a if a != null and a.active() else null


func _process(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		if node != null:
			node.queue_redraw()
			glow.queue_redraw()
		return
	_t += dt
	# fumes coming off a cut composite panel
	var co = _comp()
	if co != null:
		for r in co.smoke:
			var now: float = co.smoke[r]
			if now > float(_smoke_was.get(r, 0.0)) + 0.001 and game.tools != null:
				var at: Vector2 = game.tools.front
				for k in 3:
					game.fx.puff(at, Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0), 2.6, 6.0, 40.0, Color(0.35, 0.35, 0.37, 0.5))
			_smoke_was[r] = now
	# a flash fire caught: it runs through the room
	var at_ = _atmos()
	if at_ != null:
		for r in at_._last:
			if float(at_._last[r]) != float(_last.get(r, -1.0)):
				_last[r] = at_._last[r]
				var from: Vector2 = world.rooms[r].bbox.get_center() if world.rooms.has(r) else Vector2.ZERO
				if game.tools != null and world.rooms.has(r) and world.rooms[r].bbox.grow(60.0).has_point(game.tools.front):
					from = game.tools.front
				_fires.append({"room": r, "from": from, "t": 0.0})
				_scorch_room(r, from)
	for f in _fires:
		f.t = float(f.t) + dt
		if float(f.t) > 0.3 and float(f.t) < 3.5 and fmod(_t, 0.1) < dt:
			var rp := Kit.room_poly(world, str(f.room))
			if rp.size() > 2:
				var bb := Geom.bbox(rp)
				var p := bb.position + Vector2(randf() * bb.size.x, randf() * bb.size.y)
				if Geometry2D.is_point_in_polygon(p, rp):
					game.fx.puff(p, Vector2(randf_range(-20, 20), randf_range(-40, 0)), 2.5, 10.0, 50.0, Color(0.05, 0.05, 0.05, 0.4))
	_fires = _fires.filter(func(f): return float(f.t) < 5.0)
	node.queue_redraw()
	glow.queue_redraw()


func _scorch_room(r: String, from: Vector2) -> void:
	var rp := Kit.room_poly(world, r)
	if rp.size() < 3:
		return
	var bb := Geom.bbox(rp)
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r) + int(_t * 10.0)
	for k in 14:
		var p := bb.position + Vector2(rng.randf() * bb.size.x, rng.randf() * bb.size.y)
		if Geometry2D.is_point_in_polygon(p, rp):
			out.append([p, rng.randf_range(0.6, 1.8) * Geom.M])
	_scorch[r] = out


func _seeds(r: String, n: int) -> PackedVector2Array:
	if not _motes.has(r) or (_motes[r] as PackedVector2Array).size() < n:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(r)
		var s := PackedVector2Array()
		for i in n:
			s.append(Vector2(rng.randf(), rng.randf()))
		_motes[r] = s
	return _motes[r]


# a room's haze: a fill and drifting puffs (only drawn once the room is seen into)
func _haze(r: String, a: float, col: Color, puff_col: Color) -> void:
	var rp := Kit.room_poly(world, r)
	if rp.size() < 3 or a <= 0.003 or not world.rooms[r].revealed:
		return
	Kit.fill(node, rp, Color(col.r, col.g, col.b, a))
	var bb := Geom.bbox(rp)
	var s := _seeds(r, 40)
	for i in 12:
		var u: Vector2 = s[i]
		var p := bb.position + Vector2(fposmod(u.x + _t * 0.012 * (1.0 + i % 3), 1.0) * bb.size.x, (u.y + 0.05 * sin(_t * 0.4 + i)) * bb.size.y)
		if Geometry2D.is_point_in_polygon(p, rp):
			Kit.disc(node, p, minf(bb.size.y, 3.0 * Geom.M) * (0.4 + 0.3 * u.x), Color(puff_col.r, puff_col.g, puff_col.b, puff_col.a * minf(1.0, a * 8.0)))


func _draw() -> void:
	if game == null:
		return
	var co = _comp()
	if co != null:
		for r in co.smoke:
			var lv: float = co.level(r)
			if lv <= 0.01:
				continue
			_haze(r, clampf(0.04 + 0.05 * lv, 0.0, 0.2), Color(0.42, 0.42, 0.44), Color(0.55, 0.55, 0.57, 0.22))
			# carbon-fibre specks glinting in it
			var rp := Kit.room_poly(world, r)
			var bb := Geom.bbox(rp)
			var s := _seeds(r, 40)
			for i in mini(40, int(10 + 20 * lv)):
				var u: Vector2 = s[i]
				var p := bb.position + Vector2(fposmod(u.x + _t * 0.02, 1.0) * bb.size.x, fposmod(u.y + _t * 0.01 * (i % 4), 1.0) * bb.size.y)
				if Geometry2D.is_point_in_polygon(p, rp):
					var d := Vector2.from_angle(u.x * 9.0 + _t) * 3.0
					node.draw_line(p - d, p + d, Pal.ink(0.35), 1.0)
		for t in co.fogged:
			var q = world.tag(str(t))
			if q != null and not q.gone:
				var poly: PackedVector2Array = world.world_poly(q)
				Kit.fill(node, poly, Pal.ink(0.22))
				Kit.outline(node, poly, Pal.ink(0.45), 1.0)
	var b = _bio()
	if b != null:
		for r in game.sys.bio:
			var idx: float = game.sys.bio_index(str(r))
			if idx < 0.01 or not world.rooms.has(r) or not world.rooms[r].revealed:
				continue
			var rp := Kit.room_poly(world, str(r))
			if rp.size() < 3:
				continue
			Kit.fill(node, rp, Color(0.6, 0.75, 0.25, clampf(0.02 + 0.05 * idx, 0.0, 0.1)))
			var bb := Geom.bbox(rp)
			var s := _seeds(str(r), 60)
			for i in mini(60, int(8 + 50 * clampf(idx, 0.0, 1.0))):
				var u: Vector2 = s[i]
				var p := bb.position + Vector2(fposmod(u.x + sin(_t * 0.3 + i) * 0.02, 1.0) * bb.size.x, fposmod(u.y + _t * 0.015 * (1 + i % 3), 1.0) * bb.size.y)
				if Geometry2D.is_point_in_polygon(p, rp):
					node.draw_circle(p, 1.6 + (i % 3) * 0.6, Color(0.75, 0.9, 0.35, 0.55))
	var a = _atmos()
	if a != null:
		for r in _scorch:
			for d in _scorch[r]:
				# soot burnt onto what was there: a brown-black blotch, its edge charred lighter
				Kit.disc(node, d[0], d[1], Color(0.16, 0.1, 0.06, 0.75))
				node.draw_arc(d[0], d[1] * 0.55, 0.0, TAU, 18, Color(0.35, 0.22, 0.12, 0.5), 1.0)


func _draw_glow() -> void:
	if game == null:
		return
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	# the air moving between rooms open to each other (bio: the motes it carries)
	var b = _bio()
	var co = _comp()
	if b != null or co != null:
		for l in game.sys.links:
			var ra: String = str(l[0])
			var rb: String = str(l[1])
			var pa: float = game.sys.P(ra)
			var pb: float = 0.0 if rb == "space" else game.sys.P(rb)
			var dp := pa - pb
			if absf(dp) < 0.5 or float(l[2]) < 0.5:
				continue
			var src := ra if dp > 0.0 else rb
			var dirty := 0.0
			if b != null and src != "space":
				dirty = game.sys.bio_index(src)
			var sm := 0.0
			if co != null and src != "space":
				sm = co.level(src)
			if dirty < 0.01 and sm < 0.05:
				continue
			var at: Vector2 = l[3]
			var dir: Vector2 = l[4] if rb == "space" else Vector2.ZERO
			if dir == Vector2.ZERO:
				var ca: Vector2 = world.rooms[ra].bbox.get_center() if world.rooms.has(ra) else at
				var cb: Vector2 = world.rooms[rb].bbox.get_center() if world.rooms.has(rb) else at + Vector2.RIGHT
				dir = (cb - ca).normalized()
			if dp < 0.0:
				dir = -dir
			var k := clampf(absf(dp) / 20.0, 0.25, 1.0)
			var col := Color(0.75, 0.9, 0.35, 0.6 * k) if dirty >= 0.01 else Pal.ink(0.35 * k)
			for m in 6:
				var u := fposmod(_t * 0.8 * k + m / 6.0, 1.0)
				var p := at - dir * 40.0 + dir * 120.0 * u + dir.orthogonal() * (float(m) - 2.5) * 6.0
				segs.append(p)
				segs.append(p + dir * 10.0)
				cols.append(Color(col.r, col.g, col.b, col.a * sin(u * PI)))
	# a filter hose drawing the motes in
	if b != null:
		for pid in game.sys.hoses:
			var c = world.ctrls.get(pid)
			if c == null or c.medium != "gas":
				continue
			var r: String = c.target
			if game.sys.bio_index(r) < 0.01:
				continue
			var at: Vector2 = world.ctrl_world(c)
			for m in 8:
				var u := fposmod(_t * 0.7 + m / 8.0, 1.0)
				var p: Vector2 = at + Vector2.from_angle(m * 0.785 + _t * 0.3) * 70.0 * (1.0 - u)
				glow.draw_circle(p, 2.0, Color(0.75, 0.9, 0.35, 0.8 * u))
	if not segs.is_empty():
		glow.draw_multiline_colors(segs, cols, 1.2)
	# oxygen-rich air: a pale shimmer
	var a = _atmos()
	if a != null:
		for r in game.sys.o2:
			if not world.rooms.has(r) or not world.rooms[r].revealed:
				continue
			var f: float = game.sys.o2_frac(str(r))
			var rich := clampf((f - 0.22) / 0.4, 0.0, 1.0)
			if rich <= 0.0 or game.sys.P(str(r)) < 5.0:
				continue
			var rp := Kit.room_poly(world, str(r))
			Kit.fill(glow, rp, Color(0.55, 0.75, 1.0, 0.015 + 0.03 * rich))
			var bb := Geom.bbox(rp)
			var s := _seeds(str(r), 40)
			for i in int(10 + 30 * rich):
				var u: Vector2 = s[i]
				var p := bb.position + Vector2(u.x * bb.size.x, u.y * bb.size.y)
				if Geometry2D.is_point_in_polygon(p, rp):
					var tw := 0.5 + 0.5 * sin(_t * 2.0 + i * 1.7)
					var sz := 3.0 + 3.0 * tw
					glow.draw_line(p - Vector2(sz, 0), p + Vector2(sz, 0), Color(0.75, 0.88, 1.0, 0.7 * tw), 1.0)
					glow.draw_line(p - Vector2(0, sz), p + Vector2(0, sz), Color(0.75, 0.88, 1.0, 0.7 * tw), 1.0)
	# embers still glowing in the soot for a while after
	for f in _fires:
		if float(f.t) > 2.0 and _scorch.has(f.room):
			var ea := clampf(1.0 - (float(f.t) - 2.0) / 3.0, 0.0, 1.0)
			for d in _scorch[f.room]:
				Kit.disc(glow, d[0], d[1] * 0.3, Pal.heat(0.4 * ea * (0.7 + 0.3 * sin(_t * 5.0 + d[1])), 1.3))
	# the flash fire running through the room, burning, guttering out
	for f in _fires:
		var rp := Kit.room_poly(world, str(f.room))
		if rp.size() < 3:
			continue
		var t: float = f.t
		var spread := clampf(t / 0.7, 0.0, 1.0)
		var life := 1.0 if t < 1.2 else clampf(1.0 - (t - 1.2) / 2.6, 0.0, 1.0)
		if life <= 0.0:
			continue
		var reach := Kit.room_fill(rp, f.from, Pal.ease_out(spread), _t * 3.0)
		for q in reach:
			Kit.fill(glow, q, Pal.heat(0.04 * life, 1.4))
			# the front: bright while it is still running through the room
			Kit.outline(glow, q, Color(1.0, 0.85, 0.5, (0.9 if spread < 1.0 else 0.25) * life), 2.4 if spread < 1.0 else 1.2)
		# the burning: flickering pockets of flame through what it has reached
		var bb0 := Geom.bbox(rp)
		var sd := _seeds(str(f.room) + "_f", 40)
		for i in 40:
			var u: Vector2 = sd[i]
			var p := bb0.position + Vector2(u.x * bb0.size.x, u.y * bb0.size.y)
			if p.distance_to(f.from) > spread * bb0.size.length() or not Geometry2D.is_point_in_polygon(p, rp):
				continue
			var fl := absf(sin(_t * (7.0 + i % 5) + i * 1.9))
			Kit.disc(glow, p, (18.0 + 30.0 * fl) * (0.6 + 0.4 * life), Pal.heat(0.35 * fl * life, 1.8))
		# tongues of flame along the floor of the reached part
		var bb := Geom.bbox(rp)
		var n := int(bb.size.x / 18.0)
		for i in n:
			var x := bb.position.x + (i + 0.5) * bb.size.x / n
			var base := Vector2(x, bb.end.y - 4.0)
			if base.distance_to(f.from) > spread * bb.size.length() or not Geometry2D.is_point_in_polygon(base, rp):
				continue
			var h := (14.0 + 26.0 * absf(sin(_t * 9.0 + i * 1.3))) * life
			glow.draw_line(base, base + Vector2(sin(_t * 7.0 + i) * 4.0, -h), Pal.heat(0.7 * life, 2.0), 3.0)
