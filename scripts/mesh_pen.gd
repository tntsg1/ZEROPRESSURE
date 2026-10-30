extends RefCounted
# 96 号: a drawing kept as one mesh in its own metres, drawn again anywhere with one draw_mesh
# (about 0.2 µs, scripts/fast_draw.gd). The tug station's moving machines — the gantry's trolley
# and hook block, the pods, the tugs — have hundreds of parts each; drawn line by line every frame
# they would cost the frame, built once they cost nothing. Lines are quads of their own width in
# metres (square ends, so a polyline's joints close), fills are triangulated; later shapes cover
# earlier ones. Text can't go in a mesh: the caller draws it.
#   var pen = MeshPen.new(); pen.line(...); ...; var mesh: ArrayMesh = pen.mesh()
#   ci.draw_mesh(mesh, null, Transform2D(angle, Vector2(px_per_m, px_per_m), 0.0, at_px))

var _v := PackedVector2Array()
var _c := PackedColorArray()
var _ix := PackedInt32Array()
var xf := Transform2D.IDENTITY     # applied to every point given (a sub-assembly placed in the whole)


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var n := _v.size()
	_v.append_array([xf * a, xf * b, xf * c])
	_c.append_array([col, col, col])
	_ix.append_array([n, n + 1, n + 2])


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var n := _v.size()
	_v.append_array([xf * a, xf * b, xf * c, xf * d])
	_c.append_array([col, col, col, col])
	_ix.append_array([n, n + 1, n + 2, n, n + 2, n + 3])


func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if d.length_squared() < 1e-10:
		return
	var u := d.normalized() * w * 0.5
	var nn := u.orthogonal()
	_quad(a - u + nn, b + u + nn, b + u - nn, a - u - nn, col)


func polyline(pts: PackedVector2Array, col: Color, w: float, closed := false) -> void:
	for i in range(1, pts.size()):
		line(pts[i - 1], pts[i], col, w)
	if closed and pts.size() > 2:
		line(pts[pts.size() - 1], pts[0], col, w)


func rect(r: Rect2, col: Color, filled := true, w := 0.05) -> void:
	if filled:
		_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)
		return
	var h := w * 0.5
	line(r.position + Vector2(-h, 0), Vector2(r.end.x + h, r.position.y), col, w)
	line(Vector2(r.position.x - h, r.end.y), r.end + Vector2(h, 0), col, w)
	line(r.position, Vector2(r.position.x, r.end.y), col, w)
	line(Vector2(r.end.x, r.position.y), r.end, col, w)


# a filled outline, any shape
func poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() == 3:
		_tri(pts[0], pts[1], pts[2], col)
		return
	if pts.size() == 4 and Geometry2D.is_polygon_clockwise(pts) == Geometry2D.is_polygon_clockwise(PackedVector2Array([pts[0], pts[1], pts[2]])):
		_quad(pts[0], pts[1], pts[2], pts[3], col)
		return
	var ix := Geometry2D.triangulate_polygon(pts)
	for i in range(0, ix.size(), 3):
		_tri(pts[ix[i]], pts[ix[i + 1]], pts[ix[i + 2]], col)


func circle(c: Vector2, r: float, col: Color, n := 20) -> void:
	for i in n:
		_tri(c, c + Vector2.from_angle(TAU * i / n) * r, c + Vector2.from_angle(TAU * (i + 1) / n) * r, col)


func arc(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, n := 16) -> void:
	var ri := r - w * 0.5
	var ro := r + w * 0.5
	for i in n:
		var p := Vector2.from_angle(lerpf(a0, a1, float(i) / n))
		var q := Vector2.from_angle(lerpf(a0, a1, float(i + 1) / n))
		_quad(c + p * ri, c + p * ro, c + q * ro, c + q * ri, col)


func ring(c: Vector2, r: float, col: Color, w: float, n := 20) -> void:
	arc(c, r, 0.0, TAU, col, w, n)


# a bolt head: a small disc with a darker centre
func bolt(c: Vector2, r: float, col: Color) -> void:
	circle(c, r, col, 6)
	circle(c, r * 0.45, Color(0.03, 0.03, 0.035), 6)


# diagonal hatching inside a rect (warning stripes, grating)
func hatch(r: Rect2, col: Color, w: float, step: float, flip := false) -> void:
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(x, r.end.y) if not flip else Vector2(x, r.position.y)
		var b := Vector2(x + r.size.y, r.position.y) if not flip else Vector2(x + r.size.y, r.end.y)
		var seg := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		for s in seg:
			if s.size() >= 2:
				line(s[0], s[1], col, w)
		x += step


func empty() -> bool:
	return _v.is_empty()


func mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	if _v.is_empty():
		# nothing drawn: one invisible triangle, so a draw_mesh of it is harmless (an ArrayMesh
		# with no surface has no RID and the renderer complains every frame)
		_tri(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0, 0, 0, 0))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = _v
	a[Mesh.ARRAY_COLOR] = _c
	a[Mesh.ARRAY_INDEX] = _ix
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m
