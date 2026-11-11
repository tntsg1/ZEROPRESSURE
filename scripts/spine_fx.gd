extends Node
# ARK-01's spine seen carrying the tail — drawing only, scripts/spine.gd keeps every number and
# every part stays where the game has it (图鉴 cx_m_spine: "尾部的反应堆、发动机和推进剂安装在 440 m
# 长的主轴上，弦杆负责传递载荷"，"切断一根弦杆后，其余弦杆需要共同承担尾部的全部载荷。如果某一段的
# 载荷超过承受能力，该段结构会撕裂，尾部会下坠并扭转"，"应变探头显示各段的受力情况").
#   Each segment's chords lit with the load on them: nothing to see while they carry it easily,
#   amber past half their strength, red and throbbing near it (a chord cut puts its share on the
#   other: that one is seen to brighten). A segment torn: its chords flash and part, their ends
#   frayed; the whole tail behind it is seen to drop and twist on what is left (the pressure
#   tube), swing, and settle back where it hangs (the parts stay where they are: what is seen is
#   what is cut); the torn segment stays kinked, its chords drawn buckled.

const Kit = preload("res://scripts/mech_fx_kit.gd")

var sp
var game
var world
var node: Node2D
var glow: Node2D
var _torn_t := {}             # seg -> s since it tore
var _tail := {}               # seg -> [outline segments of what hangs aft of it, pivot]
var _t := 0.0


func setup(s) -> void:
	sp = s
	game = s.game
	world = s.world
	node = Kit.node(world, false, _draw)
	glow = Kit.node(world, true, _draw_glow)
	game.add_child(self)
	for seg in sp.torn:
		_torn_t[seg] = 99.0


func _process(dt: float) -> void:
	if sp == null or not sp.active() or game == null:
		return
	if game.paused_sim or game.state != "play":
		return
	_t += dt
	for seg in sp.torn:
		if not _torn_t.has(seg):
			_torn_t[seg] = 0.0
			_snapshot(str(seg))
			for c in _chords(str(seg)):
				var at: Vector2 = world.frame(c) * Geom.centroid(c.poly)
				game.fx.sparks(at, Vector2.UP, 30, Pal.heat(1.0, 2.2), 480.0, 0.7, PI)
				game.fx.burst_shards(at, 6, 220.0, Pal.ink(0.7), 8.0)
		_torn_t[seg] = float(_torn_t[seg]) + dt
	node.queue_redraw()
	glow.queue_redraw()


func _chords(seg: String) -> Array:
	var out: Array = []
	for t in sp.cfg.segments[seg].get("chords", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.body == null:
			out.append(p)
	return out


# what hangs aft of a torn segment, as outline segments, and where it pivots (the tear)
func _snapshot(seg: String) -> void:
	var x1: float = float(sp.cfg.segments[seg].get("x1", 0.0)) * Geom.M
	var segs := PackedVector2Array()
	var n := 0
	for h in sp.hung:
		var p = h[1]
		if p.gone or p.body != null or float(h[0]) * Geom.M <= x1:
			continue
		var poly: PackedVector2Array = p.poly
		# the big parts only: the tail's silhouette, not every bolt
		var bb := Geom.bbox(poly)
		if bb.size.x < 1.5 * Geom.M and bb.size.y < 1.5 * Geom.M:
			continue
		for i in poly.size():
			segs.append(poly[i])
			segs.append(poly[(i + 1) % poly.size()])
		n += 1
		if n > 400:
			break
	var piv := Vector2(x1, 0.0)
	var cs := _chords(seg)
	if not cs.is_empty():
		var c := Vector2.ZERO
		for q in cs:
			c += Geom.centroid(q.poly)
		piv = c / cs.size()
	_tail[seg] = [segs, piv]


func _draw() -> void:
	if sp == null or not sp.active():
		return
	for seg in _torn_t:
		var t: float = _torn_t[seg]
		# the tail dropping and twisting on the tube, swinging, settling back
		if t < 2.4 and _tail.has(seg):
			var e: Array = _tail[seg]
			var piv: Vector2 = e[1]
			var swing := exp(-t * 2.2)
			var drop := sin(minf(t * 5.0, PI * 0.5)) * swing * 7.0 * Geom.M * (1.0 + 0.25 * sin(t * 9.0))
			var twist := sin(t * 6.5) * swing * 0.06
			var xf := Transform2D(twist, piv + Vector2(0.0, drop)) * Transform2D(0.0, -piv)
			node.draw_multiline(xf * (e[0] as PackedVector2Array), Pal.ink(0.85 * minf(1.0, swing * 1.6)), 1.6)
		# the torn segment's chords: parted, frayed, buckled
		for c in _chords(str(seg)):
			var bb := Geom.bbox(world.world_poly(c))
			var mid := bb.get_center()
			var along := bb.size.x >= bb.size.y
			var half := (bb.size.x if along else bb.size.y) * 0.5
			var dir := Vector2.RIGHT if along else Vector2.DOWN
			var nrm := dir.orthogonal()
			# the gap where it parted
			var g := PackedVector2Array([mid - dir * 16.0 + nrm * 12.0, mid + dir * 16.0 + nrm * 12.0, mid + dir * 16.0 - nrm * 12.0, mid - dir * 16.0 - nrm * 12.0])
			Kit.fill(node, g, Color(0.02, 0.02, 0.025))
			# frayed ends
			for k in 5:
				var s := 1.0 if k % 2 == 0 else -1.0
				for side in [-1.0, 1.0]:
					var base: Vector2 = mid + dir * 16.0 * side + nrm * (k - 2) * 4.0
					node.draw_line(base, base - dir * side * (8.0 + 4.0 * k) + nrm * s * 7.0, Pal.ink(0.85), 1.2)
			# buckled: a kink drawn either side of the gap
			for side in [-1.0, 1.0]:
				var a: Vector2 = mid + dir * side * 16.0
				var b: Vector2 = mid + dir * side * minf(half, 60.0)
				node.draw_polyline(PackedVector2Array([a, a.lerp(b, 0.5) + nrm * 9.0 * side, b]), Pal.ink(0.6), 1.2)


func _draw_glow() -> void:
	if sp == null or not sp.active():
		return
	# ARK-01 帧率: redrawn every frame, so only what is in the camera's view (0.5 ms a frame)
	var view := ViewCull.view(game) if not (ViewCull.off or World.ark_old) else Rect2()
	if view.size != Vector2.ZERO:
		view = view.grow(ViewCull.MARGIN_PX / maxf(0.02, game.cam_zoom()) + 40.0)
	for seg in sp.cfg.get("order", []):
		if sp.torn.has(seg):
			var t: float = float(_torn_t.get(seg, 99.0))
			if t < 0.8:
				for c in _chords(str(seg)):
					Kit.outline(glow, world.world_poly(c), Color(1.0, 0.9, 0.7, 1.0 - t / 0.8), 3.0)
			for c in _chords(str(seg)):
				var mid := Geom.bbox(world.world_poly(c)).get_center()
				var ea := clampf(1.0 - (t - 0.3) / 6.0, 0.25, 1.0)
				for side in [-1.0, 1.0]:
					Kit.disc(glow, mid + Vector2(16.0 * side, 0.0), 14.0, Pal.heat(0.45 * ea * (0.8 + 0.2 * sin(_t * 7.0 + side)), 1.6))
			continue
		var st: float = sp.stress(str(seg))
		if st < 0.5:
			continue
		var k := clampf((st - 0.5) / 0.5, 0.0, 1.0)
		var pulse := 0.75 + 0.25 * sin(_t * (3.0 + 9.0 * k))
		for c in _chords(str(seg)):
			if sp.cut.has(c.tag):
				continue
			var poly: PackedVector2Array = world.world_poly(c)
			if view.size != Vector2.ZERO and not view.intersects(Geom.bbox(poly)):
				continue
			var col := Color(1.0, 0.7, 0.25).lerp(Pal.heat(1.0, 1.4), k)
			var fc := Color(col.r, col.g, col.b, (0.15 + 0.35 * k) * pulse)
			if World.ark_old:
				Kit.fill(glow, poly, fc)
			else:
				# ARK-01 帧率: the chord's triangles as the world keeps them (an attached chord's
				# world outline is its own), not worked out again every frame
				var tri: PackedInt32Array = world._tri_cached(c)
				if not tri.is_empty():
					var fcs := PackedColorArray()
					fcs.resize(poly.size())
					fcs.fill(fc)
					RenderingServer.canvas_item_add_triangle_array(glow.get_canvas_item(), tri, poly, fcs)
			Kit.outline(glow, poly, Color(col.r, col.g, col.b, (0.4 + 0.5 * k) * pulse), 1.6)
