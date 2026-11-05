extends RefCounted
# Ways round the port that clear its real solids (user 2026-11-05: in the video the hull and its tug
# went up through the berth's floor and the tugs past the hulks parked in the yard; 87-6 had only
# kept the hull clear of the districts' boxes, and let it through the berth it was going into).
# The solids are the colliders scripts/port_structure.gd builds (district shells, corridors, the
# hub's ring, the machines inside), with the tug station's gate and mouth open as they are drawn,
# the berth's floor, tower and rail (scripts/dock.gd), and the hulks parked in the yard. They are
# rasterised on a 1 m grid; a body (a box round its origin: a hull and its tugs, or one tug) is free
# where a window of that box, grown by the margin, holds no solid (2D prefix sums); the way is found
# on that by the engine's AStarGrid2D and pulled straight into a few legs, each checked clear.
# Positions px; the grid is metres.

const W = preload("res://scripts/tug_works.gd")
const CELL := 1.0               # m
const REACH := 140.0            # m round the two ends that the grid covers


# the port's solids as world px outlines
static func solids(game) -> Array:
	var M := Geom.M
	var out: Array = []
	var ps = PortStructure.new()
	ps.game = game
	ps.walls = StaticBody2D.new()
	ps._build()
	var tb := PortStructure.box("tug")
	var holes := [Rect2(tb.position + Vector2(-1.0, W.GATE.x) * M, Vector2(2.0, W.GATE.y - W.GATE.x) * M),
		Rect2(tb.position + Vector2(-1.0, W.MOUTH.x) * M, Vector2(2.0, W.MOUTH.y - W.MOUTH.x) * M)]
	for cs in ps.walls.get_children():
		var sh = cs.shape
		if sh is RectangleShape2D:
			var h: Vector2 = sh.size * 0.5
			var xf := Transform2D(cs.rotation, cs.position)
			var poly := PackedVector2Array([xf * Vector2(-h.x, -h.y), xf * Vector2(h.x, -h.y), xf * Vector2(h.x, h.y), xf * Vector2(-h.x, h.y)])
			var parts: Array = [poly]
			for hole: Rect2 in holes:
				var hp := PackedVector2Array([hole.position, Vector2(hole.end.x, hole.position.y), hole.end, Vector2(hole.position.x, hole.end.y)])
				var nxt: Array = []
				for p in parts:
					for q in Geometry2D.clip_polygons(p, hp):
						if not Geometry2D.is_polygon_clockwise(q):
							nxt.append(q)
				parts = nxt
			out.append_array(parts)
		cs.free()
	ps.walls.free()
	ps.free()
	for s in [[Vector2(Dock.TOWER_X, Dock.FLOOR_Y), Vector2(Dock.FLOOR_X1, Dock.FLOOR_Y)], [Vector2(Dock.TOWER_X + 0.6, Dock.RAIL_Y - 2.6), Vector2(Dock.TOWER_X + 0.6, Dock.FLOOR_Y)], [Vector2(Dock.TOWER_X, Dock.RAIL_Y), Vector2(Dock.ARM_X1, Dock.RAIL_Y)]]:
		var a: Vector2 = s[0] * M
		var b: Vector2 = s[1] * M
		var n := (b - a).orthogonal().normalized() * 0.15 * M
		out.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	return out


# the hulks lying in the yard (but `except`), world px outlines (their boxes)
static func parked(except: String) -> Array:
	var out: Array = []
	if not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return out
	for a in Career.data.ship_market.get("assets", []):
		if str(a.get("id", "")) == except or not a.has("yard") or not str(a.get("state", "")) in ["arrived", "held", "stripping"]:
			continue
		var ship := TugYard.ship_of(a)
		var b := Ship.bounds(Ship.load_data(ship))
		var o := TugYard.slot_px(int(a.yard), ship) - Vector2(b.end.x, b.get_center().y) * Geom.M
		var r := Rect2(o + b.position * Geom.M, b.size * Geom.M)
		out.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	return out


# ---------------------------------------------------------------- the grid
var org := Vector2.ZERO         # m: the grid's corner
var n := Vector2i.ZERO
var occ := PackedByteArray()
var sat := PackedInt32Array()   # prefix sums, (n.x + 1) × (n.y + 1)
var free := PackedByteArray()   # per cell: the body's origin may be here
var body := Rect2()             # m, round the origin, grown by the margin


# more solids (another tug waiting): rasterised in, the sums again
func add(polys: Array) -> void:
	for p: PackedVector2Array in polys:
		_raster(p)
	_sums()


func _init(area_px: Rect2, polys: Array) -> void:
	var M := Geom.M
	var a := Rect2(area_px.position / M, area_px.size / M)
	org = a.position.floor()
	n = Vector2i(ceili(a.size.x / CELL) + 2, ceili(a.size.y / CELL) + 2)
	occ.resize(n.x * n.y)
	occ.fill(0)
	for p: PackedVector2Array in polys:
		_raster(p)
	_sums()


func _sums() -> void:
	sat.resize((n.x + 1) * (n.y + 1))
	sat.fill(0)
	var w := n.x + 1
	for y in n.y:
		var row := 0
		for x in n.x:
			row += occ[y * n.x + x]
			sat[(y + 1) * w + x + 1] = sat[y * w + x + 1] + row


func _mark(m: Vector2) -> void:
	var c := Vector2i(floori((m.x - org.x) / CELL), floori((m.y - org.y) / CELL))
	if c.x >= 0 and c.y >= 0 and c.x < n.x and c.y < n.y:
		occ[c.y * n.x + c.x] = 1


func _raster(p: PackedVector2Array) -> void:
	var M := Geom.M
	var bb := Rect2(p[0] / M, Vector2.ZERO)
	for v in p:
		bb = bb.expand(v / M)
	# an upright box: filled; anything else: its edges, walked at a third of a cell (slabs are thin)
	var upright := p.size() == 4 and (absf(p[0].x - p[3].x) < 0.5 or absf(p[0].y - p[3].y) < 0.5) and (absf(p[0].x - p[1].x) < 0.5 or absf(p[0].y - p[1].y) < 0.5)
	if upright:
		var y := bb.position.y
		while y <= bb.end.y + 0.001:
			var x := bb.position.x
			while x <= bb.end.x + 0.001:
				_mark(Vector2(x, y))
				x += CELL * 0.5
			_mark(Vector2(bb.end.x, y))
			y += CELL * 0.5
		return
	for i in p.size():
		var a: Vector2 = p[i] / M
		var b: Vector2 = p[(i + 1) % p.size()] / M
		var steps := maxi(1, ceili(a.distance_to(b) / (CELL / 3.0)))
		for k in steps + 1:
			_mark(a.lerp(b, float(k) / steps))


func _sum(x0: int, y0: int, x1: int, y1: int) -> int:
	x0 = clampi(x0, 0, n.x); x1 = clampi(x1, 0, n.x); y0 = clampi(y0, 0, n.y); y1 = clampi(y1, 0, n.y)
	if x1 <= x0 or y1 <= y0:
		return 0
	var w := n.x + 1
	return sat[y1 * w + x1] - sat[y0 * w + x1] - sat[y1 * w + x0] + sat[y0 * w + x0]


# the body (m, round its origin) and the margin kept from every solid
var _astar: AStarGrid2D = null
func set_body(b: Rect2, margin: float) -> void:
	body = b.grow(margin)
	_astar = null
	free.resize(n.x * n.y)
	# the window's offsets from a cell are the same everywhere: worked out once
	var dx0 := floori(body.position.x / CELL)
	var dy0 := floori(body.position.y / CELL)
	var dx1 := ceili(body.end.x / CELL)
	var dy1 := ceili(body.end.y / CELL)
	var w := n.x + 1
	var i := 0
	for y in n.y:
		var y0 := clampi(y + dy0, 0, n.y)
		var y1 := clampi(y + dy1, 0, n.y)
		var r0 := y0 * w
		var r1 := y1 * w
		for x in n.x:
			var x0 := clampi(x + dx0, 0, n.x)
			var x1 := clampi(x + dx1, 0, n.x)
			free[i] = 1 if (y1 <= y0 or x1 <= x0 or sat[r1 + x1] - sat[r0 + x1] - sat[r1 + x0] + sat[r0 + x0] == 0) else 0
			i += 1


func cell(px: Vector2) -> Vector2i:
	var m := px / Geom.M
	return Vector2i(roundi((m.x - org.x) / CELL), roundi((m.y - org.y) / CELL))


func is_free(px: Vector2) -> bool:
	var c := cell(px)
	return c.x >= 0 and c.y >= 0 and c.x < n.x and c.y < n.y and free[c.y * n.x + c.x] == 1


func px_of(c: Vector2i) -> Vector2:
	return (org + Vector2(c) * CELL) * Geom.M


# a straight leg a → b (px) clear all the way
func clear(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / Geom.M / (CELL * 0.5)))
	for k in steps + 1:
		if not is_free(a.lerp(b, float(k) / steps)):
			return false
	return true


# the way from a to b (px): a few straight legs, every point of them free; [] if there is none
func way(a: Vector2, b: Vector2) -> Array:
	var ca := cell(a)
	var cb := cell(b)
	if _astar == null:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(0, 0, n.x, n.y)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.update()
		# runs of blocked cells along each row, filled a region at a time
		for y in n.y:
			var x := 0
			var row := y * n.x
			while x < n.x:
				if free[row + x] == 0:
					var x1 := x
					while x1 < n.x and free[row + x1] == 0:
						x1 += 1
					_astar.fill_solid_region(Rect2i(x, y, x1 - x, 1), true)
					x = x1
				else:
					x += 1
	var g := _astar
	if not g.is_in_boundsv(ca) or not g.is_in_boundsv(cb) or g.is_point_solid(ca) or g.is_point_solid(cb):
		return []
	var ids := g.get_id_path(ca, cb)
	if ids.is_empty():
		return []
	var pts: Array = [a]
	for c in ids:
		pts.append(px_of(c))
	pts.append(b)
	# pulled straight: from each corner on to the furthest point still in clear sight
	var out: Array = [a]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


# a body's box (m round its origin) from outlines (px) placed at origin o (px)
static func box_of(polys: Array, o: Vector2) -> Rect2:
	var r := Rect2()
	var first := true
	for p: PackedVector2Array in polys:
		for v in p:
			var m := (v - o) / Geom.M
			if first:
				r = Rect2(m, Vector2.ZERO)
				first = false
			else:
				r = r.expand(m)
	return r
