class_name PortMesh
extends RefCounted
# The still part of Zero Pressure Port as one retained mesh (2026-10-24, design/…/24_港站绘制性能):
# a stand-in for the CanvasItem draw_* calls PortArt makes, with every shape in world px and
# every line's width kept as a screen-pixel offset in the vertex's UV. The node that holds it
# carries scripts/port_lines.gdshader, which pushes each vertex out by UV / zoom: lines stay
# their width on screen at any zoom, so the mesh is built once and never redrawn while the
# camera zooms. PortArt is built at zoom 1, where its widths (k / z) are already screen px.
# Text goes straight to the node between the geometry, so the drawing order holds.

const CIRCLE_SEGS := 64
const MARK := Vector2(1000.0, 1000.0)   # our vertices' UVs sit here; a glyph's (0..1) do not move
const MAX_VERTS := 60000

var node: CanvasItem
var _p := PackedVector2Array()
var _c := PackedColorArray()
var _u := PackedVector2Array()


func _init(n: CanvasItem) -> void:
	node = n


func flush() -> void:
	if _p.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), PackedInt32Array(), _p, _c, _u)
	_p = PackedVector2Array()
	_c = PackedColorArray()
	_u = PackedVector2Array()


func _v(p: Vector2, u: Vector2, col: Color) -> void:
	_p.append(p)
	_u.append(u + MARK)
	_c.append(col)


func _quad(a: Vector2, ua: Vector2, b: Vector2, ub: Vector2, c: Vector2, uc: Vector2, d: Vector2, ud: Vector2, col: Color) -> void:
	if _p.size() > MAX_VERTS:
		flush()
	_v(a, ua, col)
	_v(b, ub, col)
	_v(c, uc, col)
	_v(a, ua, col)
	_v(c, uc, col)
	_v(d, ud, col)


# a straight stroke w screen px wide (-1: one pixel), butt ends like CanvasItem.draw_line
func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	if d.length_squared() < 1e-12:
		return
	var h := (w if w > 0.0 else 1.0) * 0.5
	var n := d.normalized().orthogonal() * h
	_quad(a, n, b, n, b, -n, a, -n, col)


func draw_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	_seg(a, b, col, w)


func draw_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	for i in pts.size() - 1:
		_seg(pts[i], pts[i + 1], col, w)


func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	var prev := c + Vector2.from_angle(a0) * r
	for i in range(1, n):
		var q := c + Vector2.from_angle(a0 + (a1 - a0) * float(i) / float(n - 1)) * r
		_seg(prev, q, col, w)
		prev = q


func draw_rect(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	var p0 := r.position
	var p1 := Vector2(r.end.x, r.position.y)
	var p2 := r.end
	var p3 := Vector2(r.position.x, r.end.y)
	if filled:
		_quad(p0, Vector2.ZERO, p1, Vector2.ZERO, p2, Vector2.ZERO, p3, Vector2.ZERO, col)
		return
	# the outline straddles the edges, half its width either side, corners filled
	var h := (w if w > 0.0 else 1.0) * 0.5
	_quad(p0, Vector2(-h, -h), p1, Vector2(h, -h), p1, Vector2(h, h), p0, Vector2(-h, h), col)
	_quad(p3, Vector2(-h, -h), p2, Vector2(h, -h), p2, Vector2(h, h), p3, Vector2(-h, h), col)
	_quad(p0, Vector2(-h, h), p0, Vector2(h, h), p3, Vector2(h, -h), p3, Vector2(-h, -h), col)
	_quad(p1, Vector2(-h, h), p1, Vector2(h, h), p2, Vector2(h, -h), p2, Vector2(-h, -h), col)


func draw_circle(c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, aa: bool = false) -> void:
	if not filled:
		draw_arc(c, r, 0.0, TAU, CIRCLE_SEGS + 1, col, w, aa)
		return
	if _p.size() > MAX_VERTS:
		flush()
	var prev := c + Vector2(r, 0.0)
	for i in range(1, CIRCLE_SEGS + 1):
		var q := c + Vector2.from_angle(TAU * float(i) / CIRCLE_SEGS) * r
		_v(c, Vector2.ZERO, col)
		_v(prev, Vector2.ZERO, col)
		_v(q, Vector2.ZERO, col)
		prev = q


func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if _p.size() > MAX_VERTS:
		flush()
	for i in idx:
		_v(pts[i], Vector2.ZERO, col)


func draw_string(font: Font, pos: Vector2, text: String, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, size: int = 16, col: Color = Color.WHITE) -> void:
	flush()
	node.draw_string(font, pos, text, align, width, size, col)
