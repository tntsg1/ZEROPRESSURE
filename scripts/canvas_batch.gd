extends RefCounted
# A stand-in for a CanvasItem's draw_* calls that gathers the shapes and draws them
# in as few commands as possible (performance request 2026-10-20: the berth was the
# biggest cost of the whole-ship view). Wide lines become triangles, thin ones (1.2 px
# or less) hairlines; fills are triangulated; every run of geometry goes out as one
# triangle array and one hairline batch. Text, textures and transforms go straight
# to the canvas item, after flushing what came before, so the drawing order holds.
# A fill that comes after lines flushes first, so later fills still cover earlier
# lines; 60 FPS (2026-10-27): only when it reaches those lines (pad round them): one that
# does not cover them looks the same drawn before them, and the furnace was flushing 86
# times a draw, two dear commands each. Usage: var ci = CanvasBatch.new(node);
# ...ci.draw_*...; ci.flush()

const THIN := 1.2

var node: CanvasItem
var no_text := false     # a layer of shapes only (its text is drawn on another, less often)
var no_shapes := false   # a layer of text only
var _tp := PackedVector2Array()     # triangles
var _tc := PackedColorArray()
var _lp := PackedVector2Array()     # hairline segments
var _lc := PackedColorArray()
var _lb := Rect2()                  # where the hairlines waiting in _lp lie
var width_k := 1.0                  # 118 号: every line this much finer (the berth as the middle ground)
var pad := 2.0                      # how near a fill may come to them and still go before them
                                    # (a pixel or two: callers far out set it in their units)


func _init(n: CanvasItem) -> void:
	node = n
	# 91 号: this item's notes are drawn again with it
	Look.clear_notes(n)


func flush() -> void:
	if not _tp.is_empty():
		RenderingServer.canvas_item_add_triangle_array(node.get_canvas_item(), PackedInt32Array(), _tp, _tc)
		_tp = PackedVector2Array()
		_tc = PackedColorArray()
	if not _lp.is_empty():
		node.draw_multiline_colors(_lp, _lc, -1.0)
		_lp = PackedVector2Array()
		_lc = PackedColorArray()


# a fill after lines: draw the lines first so the fill can cover them (only if it reaches them)
func _fill_mode(r: Rect2) -> void:
	if not _lp.is_empty() and _lb.grow(pad).intersects(r, true):
		flush()


func _fill_pts(pts: PackedVector2Array) -> void:
	if _lp.is_empty() or pts.is_empty():
		return
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	_fill_mode(Rect2(lo, hi - lo))


func get_canvas_item() -> RID:
	flush()
	return node.get_canvas_item()


func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	if no_shapes:
		return
	if w > 0.0:
		w *= width_k
	if w <= THIN:
		var r := Rect2(a, Vector2.ZERO).expand(b)
		_lb = r if _lp.is_empty() else _lb.merge(r)
		_lp.append(a)
		_lp.append(b)
		_lc.append(col)
		return
	if not _lp.is_empty() and _lb.grow(pad + w).intersects(Rect2(a, Vector2.ZERO).expand(b), true):
		flush()
	var d := b - a
	var ln := d.length()
	var hw := w * 0.5
	d = d / ln * hw if ln > 0.0001 else Vector2(hw, 0.0)
	var n := Vector2(-d.y, d.x)
	var a0 := a - d * 0.5
	var b0 := b + d * 0.5
	_tp.append_array([a0 - n, a0 + n, b0 + n, a0 - n, b0 + n, b0 - n])
	for k in 6:
		_tc.append(col)


func draw_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	_seg(a, b, col, w)


func draw_multiline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	for i in range(0, pts.size() - 1, 2):
		_seg(pts[i], pts[i + 1], col, w)


func draw_multiline_colors(pts: PackedVector2Array, cols: PackedColorArray, w: float = -1.0, _aa: bool = false) -> void:
	for i in range(0, pts.size() - 1, 2):
		_seg(pts[i], pts[i + 1], cols[mini(i / 2, cols.size() - 1)], w)


func draw_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	for i in pts.size() - 1:
		_seg(pts[i], pts[i + 1], col, w)


func draw_polyline_colors(pts: PackedVector2Array, cols: PackedColorArray, w: float = -1.0, _aa: bool = false) -> void:
	for i in pts.size() - 1:
		_seg(pts[i], pts[i + 1], cols[mini(i, cols.size() - 1)], w)


func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	var prev := c + Vector2.from_angle(a0) * r
	for i in range(1, maxi(n, 2)):
		var p := c + Vector2.from_angle(lerpf(a0, a1, float(i) / (maxi(n, 2) - 1))) * r
		_seg(prev, p, col, w)
		prev = p


func draw_rect(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if no_shapes:
		return
	if filled:
		_fill_mode(r)
		var a := r.position
		var b := Vector2(r.end.x, r.position.y)
		var c := r.end
		var d := Vector2(r.position.x, r.end.y)
		_tp.append_array([a, b, c, a, c, d])
		for k in 6:
			_tc.append(col)
		return
	var p0 := r.position
	var p1 := Vector2(r.end.x, r.position.y)
	var p2 := r.end
	var p3 := Vector2(r.position.x, r.end.y)
	_seg(p0, p1, col, w)
	_seg(p1, p2, col, w)
	_seg(p2, p3, col, w)
	_seg(p3, p0, col, w)


func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	if no_shapes:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	_fill_pts(pts)
	for i in idx:
		_tp.append(pts[i])
		_tc.append(col)


func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	if no_shapes:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	_fill_pts(pts)
	for i in idx:
		_tp.append(pts[i])
		_tc.append(cols[mini(i, cols.size() - 1)])


func draw_circle(c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if no_shapes:
		return
	var n := 12 if r > 4.0 else 6
	if not filled:
		draw_arc(c, r, 0.0, TAU, n + 1, col, w)
		return
	_fill_mode(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
	var prev := c + Vector2(r, 0.0)
	for i in range(1, n + 1):
		var p := c + Vector2.from_angle(TAU * i / n) * r
		_tp.append_array([c, prev, p])
		_tc.append_array([col, col, col])
		prev = p


# these go straight to the canvas item, in order
func draw_string(font: Font, pos: Vector2, text: String, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, size: int = 16, col: Color = Color.WHITE) -> void:
	if no_text:
		return
	flush()
	node.draw_string(font, pos, text, align, width, size, col)


# 91 号 Q4: a small note in the scene (what a part is): shown only near the cursor or with the
# measuring tool out (scripts/look.gd draws it)
func note(font: Font, pos: Vector2, text: String, align: int = HORIZONTAL_ALIGNMENT_LEFT, _width: float = -1.0, size: int = 12, col: Color = Color.WHITE) -> void:
	if no_text:
		return
	Look.note(node, font, pos, text, align, size, col)


func draw_texture_rect(tex: Texture2D, r: Rect2, tile: bool, modulate: Color = Color.WHITE, transpose: bool = false) -> void:
	if no_shapes:
		return
	flush()
	node.draw_texture_rect(tex, r, tile, modulate, transpose)


func draw_texture_rect_region(tex: Texture2D, r: Rect2, src: Rect2, modulate: Color = Color.WHITE) -> void:
	if no_shapes:
		return
	flush()
	node.draw_texture_rect_region(tex, r, src, modulate)


func draw_set_transform(pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	flush()
	node.draw_set_transform(pos, rot, scale)
