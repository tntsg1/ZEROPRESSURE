extends RefCounted
# The port's and the berth's solid geometry and the tugs' and hulks' outlines, world px, for the
# no-clipping checks of the tugs at work (user 2026-11-05: two tugs went through each other, a hulk
# through the tug station, the push through the berth's truss). The solids are the real colliders:
# the district shells, corridors, the hub's ring and the machines inside (scripts/port_structure.gd's
# walls, built here again so the job scene has them too), the berth's floor, tower and rail
# (scripts/dock.gd), with the tug station's two openings in its left wall cut out: the tug gate and
# the mouth (drawn there, closed only in the drone's collider). Distances in metres.

const TugRig = preload("res://scripts/tug_rig.gd")
const W = preload("res://scripts/tug_works.gd")

# a tug's outline, local m, nose +x, skids at y 0: hull, push plate and fenders, winch and its boom,
# the aft pod and its bell
const TUG := [Vector2(-7.9, -3.05), Vector2(-5.6, -3.75), Vector2(-3.0, -4.55), Vector2(-2.4, -5.55), Vector2(1.6, -5.7),
	Vector2(4.6, -4.55), Vector2(6.6, -3.9), Vector2(6.6, -0.85), Vector2(5.0, -0.6), Vector2(3.9, 0.0), Vector2(-4.1, 0.0),
	Vector2(-5.6, -0.6), Vector2(-7.9, -1.55)]


static func tug_poly(at: Vector2, face: float, cut_pad := false) -> PackedVector2Array:
	var M := Geom.M
	var f := signf(face) if absf(face) > 0.01 else 1.0
	var out := PackedVector2Array()
	for v: Vector2 in TUG:
		var x := minf(v.x, TugRig.PLATE) if cut_pad else v.x
		out.append(at + Vector2(x * f * absf(face) if absf(face) > 0.01 else 0.0, v.y) * M)
	return out


# the solids (world px polygons)
static func solids(g) -> Array:
	var M := Geom.M
	var out: Array = []
	var ps = PortStructure.new()
	ps.game = g
	ps.walls = StaticBody2D.new()
	ps._build()
	var tb := PortStructure.box("tug")
	# the openings in the tug station's left wall: the gate (deck) and the mouth
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
	# the berth: floor, tower, rail (0.3 m slabs)
	for s in [[Vector2(Dock.TOWER_X, Dock.FLOOR_Y), Vector2(Dock.FLOOR_X1, Dock.FLOOR_Y)], [Vector2(Dock.TOWER_X + 0.6, Dock.RAIL_Y - 2.6), Vector2(Dock.TOWER_X + 0.6, Dock.FLOOR_Y)], [Vector2(Dock.TOWER_X, Dock.RAIL_Y), Vector2(Dock.ARM_X1, Dock.RAIL_Y)]]:
		var a: Vector2 = s[0] * M
		var b: Vector2 = s[1] * M
		var n := (b - a).orthogonal().normalized() * 0.15 * M
		out.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	return out


# a ship's outside (its pieces merged), local m
static func hull_outline(ship: String) -> Array:
	var polys: Array = []
	for pd in Ship.load_data(ship).get("pieces", []):
		var pts := PackedVector2Array()
		for q in pd.get("poly", []):
			pts.append(Vector2(float(q[0]), float(q[1])))
		if pts.size() >= 3:
			polys.append(pts)
	return preload("res://scripts/tow_traffic.gd")._silhouette(polys)


static func placed(polys: Array, at: Vector2) -> Array:
	var out: Array = []
	for p: PackedVector2Array in polys:
		var w := PackedVector2Array()
		for v in p:
			w.append(at + v * Geom.M)
		out.append(w)
	return out


static func _bbox(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r


# the least distance between two outlines (m; 0 when they overlap)
static func dist(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return 0.0
	var best := INF
	for pass_ in 2:
		var p := a if pass_ == 0 else b
		var q := b if pass_ == 0 else a
		for v in p:
			for i in q.size():
				var c := Geometry2D.get_closest_point_to_segment(v, q[i], q[(i + 1) % q.size()])
				best = minf(best, v.distance_squared_to(c))
	return sqrt(best) / Geom.M


# the least distance between two sets of outlines, skipping pairs whose boxes are further than `far` m
static func dist_sets(a: Array, b: Array, far := 6.0) -> float:
	var best := INF
	var pad := far * Geom.M
	for p: PackedVector2Array in a:
		var bp := _bbox(p).grow(pad)
		for q: PackedVector2Array in b:
			if not bp.intersects(_bbox(q)):
				continue
			best = minf(best, dist(p, q))
	return best
