extends RefCounted
# 黑白线稿 (user 2026-11-11: "都不要灰色，只有之前一样的黑白"): a pen that takes a drawing made in
# solid grey plates (scripts/tug_station_art.gd's hall and hoist bay) and lays it down as the game's
# line art on black — every grey face black, its outline white (brighter the lighter the face was:
# the near steel bold, the far wall panels a faint line), the grey lines white, the dark seams a hair
# of white; shadows and washes dropped; the theme's orange and the cyan kept as they are.
# Wraps a scripts/mesh_pen.gd.

var q   # the MeshPen drawn into
const BLACK := Color(0, 0, 0)


func _init(pen) -> void:
	q = pen


static func _sat(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _lum(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0


# a grey face's outline: its brightness from the face's (the far wall ~0.3, the near steel ~0.9)
static func _edge(c: Color) -> Color:
	var l := _lum(c)
	if l < 0.05:
		return Pal.ink(0.17)   # the far wall's panels: a faint line
	return Pal.ink(clampf(0.16 + l * 4.2, 0.18, 0.95))


# what a line's colour becomes; alpha 0 means drop it
static func _line_col(c: Color) -> Color:
	if _sat(c) > 0.12:
		return c
	var l := _lum(c)
	if l < 0.03:
		# a dark seam or a dark edge: a hair of white (heavy shadow edges stay a little brighter)
		return Pal.ink(0.08 + 0.12 * c.a) if c.a > 0.25 else Color(0, 0, 0, 0)
	if c.a < 0.12:
		return Color(0, 0, 0, 0)
	if l < 0.09:
		return Pal.ink(0.16)   # the wall's ribs, hangers, brackets: back, faint
	return Pal.ink(clampf(0.25 + l * 3.0, 0.25, 1.0) * clampf(c.a * 1.2, 0.3, 1.0))


func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var c := _line_col(col)
	if c.a > 0.0:
		q.line(a, b, c, minf(w, 0.08) if _sat(col) <= 0.12 else w)


func polyline(pts: PackedVector2Array, col: Color, w: float, closed := false) -> void:
	var c := _line_col(col)
	if c.a > 0.0:
		q.polyline(pts, c, minf(w, 0.08) if _sat(col) <= 0.12 else w, closed)


func rect(r: Rect2, col: Color, filled := true, w := 0.05) -> void:
	if not filled:
		line(r.position, Vector2(r.end.x, r.position.y), col, w)
		line(Vector2(r.end.x, r.position.y), r.end, col, w)
		line(r.end, Vector2(r.position.x, r.end.y), col, w)
		line(Vector2(r.position.x, r.end.y), r.position, col, w)
		return
	if _sat(col) > 0.12:
		q.rect(r, col)
		return
	if col.a < 0.6:
		return   # a shadow, a wash, the wear: not in line art
	var thin := minf(r.size.x, r.size.y)
	if thin < 0.16:
		# a strip (a rail, a flange, a lamp's bar): a white line along it
		q.rect(r, _edge(col))
		return
	q.rect(r, BLACK)
	q.rect(r, _edge(col), false, 0.06 if thin > 0.8 else 0.04)


func poly(pts: PackedVector2Array, col: Color) -> void:
	if _sat(col) > 0.12:
		q.poly(pts, col)
		return
	if col.a < 0.6:
		return
	q.poly(pts, BLACK)
	q.polyline(pts, _edge(col), 0.04, true)


func circle(c: Vector2, r: float, col: Color, n := 20) -> void:
	if _sat(col) > 0.12:
		q.circle(c, r, col, n)
		return
	if col.a < 0.6:
		return
	q.circle(c, r, BLACK, n)
	if r < 0.1:
		q.circle(c, r * 0.6, _edge(col), n)   # a rivet: a white dot
	else:
		q.ring(c, r, _edge(col), 0.05, n)


func arc(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float, n := 16) -> void:
	var cc := _line_col(col)
	if cc.a > 0.0:
		q.arc(c, r, a0, a1, cc, w, n)


func ring(c: Vector2, r: float, col: Color, w: float, n := 20) -> void:
	var cc := _line_col(col)
	if cc.a > 0.0:
		q.ring(c, r, cc, w, n)


func bolt(c: Vector2, r: float, col: Color) -> void:
	q.bolt(c, r, _line_col(col))


func hatch(r: Rect2, col: Color, w: float, step: float, flip := false) -> void:
	q.hatch(r, col, w, step, flip)
