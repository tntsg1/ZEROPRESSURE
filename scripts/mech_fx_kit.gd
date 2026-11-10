extends RefCounted
# Shared pieces for the mechanisms' own drawing nodes (*_fx.gd, design/机制动画缺口_20261110.md):
# a node on the world over the strips (plain or additive), soft discs, rings, hot-metal colours,
# a room filling. Drawing only: nothing here reads back into a mechanism.

const ThermalFx = preload("res://scripts/thermal_fx.gd")


# a drawing node on the world: z 1 just over the strips, or z 4 additive (light)
static func node(world: Node2D, additive: bool, fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	if additive:
		n.z_index = 4
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	else:
		n.z_index = 1
	n.draw.connect(fn)
	world.add_child(n)
	if not additive:
		world.move_child(n, world.piece_layer.get_index() + 1)
	return n


# a soft disc (or ellipse, sx/sy) bright at its middle, nothing at its edge
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color, sx: float = 1.0, sy: float = 1.0, n: int = 20) -> void:
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	var idx := PackedInt32Array()
	for k in n:
		var d := Vector2.from_angle(TAU * k / n)
		pts.append(c + Vector2(d.x * r * sx, d.y * r * sy))
		cols.append(Color(col.r, col.g, col.b, 0.0))
	for k in n:
		idx.append_array([0, 1 + k, 1 + (k + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float = 1.2, n: int = 28) -> void:
	ci.draw_arc(c, r, 0.0, TAU, n, col, w)


# a polygon filled one colour (triangulated each call: keep it for small or changing shapes)
static func fill(ci: CanvasItem, poly: PackedVector2Array, col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(poly.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tri, poly, cols)


static func hot(k: float) -> Color:
	return ThermalFx.glow_col(clampf(k, 0.0, 1.0))


# a closed outline
static func outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, w: float = 1.2) -> void:
	if poly.size() < 2:
		return
	var p := poly.duplicate()
	p.append(poly[0])
	ci.draw_polyline(p, col, w)


# a room's outline (px, ship frame), or empty
static func room_poly(world, room: String) -> PackedVector2Array:
	if room == "" or not world.rooms.has(room):
		return PackedVector2Array()
	return world.rooms[room].poly


# a wavy circle (a front spreading through a room, a growing globule)
static func blob(c: Vector2, r: float, t: float, wav: float = 0.06, n: int = 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + wav * sin(a * 5.0 + t * 2.3) + wav * 0.5 * sin(a * 9.0 - t * 3.1)))
	return pts


# a room filling from a point: the part of it the front has reached (fill 0..1 of its size)
static func room_fill(room: PackedVector2Array, from: Vector2, f: float, t: float) -> Array:
	if room.size() < 3 or f <= 0.0:
		return []
	var bb := Geom.bbox(room)
	var far := 0.0
	for v in room:
		far = maxf(far, v.distance_to(from))
	if f >= 1.0:
		return [room]
	return Geometry2D.intersect_polygons(room, blob(from, far * 1.05 * f, t, 0.05))
