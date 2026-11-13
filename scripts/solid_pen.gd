extends "res://scripts/mesh_pen.gd"
# 2026-11-12 (user, on the processing district: "这些贴图还是纯2D、纯扁平啊，没有一点质感啊！"): the tug
# station's finished solid look (its style 9) given to a district drawn in flat dark fills and white
# line art, without redrawing each machine. A MeshPen whose plain dark fills come out as steel: the
# face lifted into the tug station's greys with a top-to-bottom shade (lit from above, Look.LIGHT_DIR),
# a shadow cast down and right onto what is behind, the edges toward the light lit and the others dark,
# big plates with a seam and corner rivets. Polygons the same without the shade. Themed colours (heat,
# glass, the lit lamps), light washes and anything small pass through as they were. Drawn once into a
# mesh (built with the still parts): no cost a frame.

const SH := Vector2(0.28, 0.34)          # m: where a shadow falls (away from the light)
const SH_COL := Color(0, 0, 0, 0.58)
const EAVE := Color(0.6, 0.62, 0.65)     # the lit edge
const DARK_EDGE := Color(0.04, 0.042, 0.047)
const SEAM := Color(0.075, 0.078, 0.086)
const RIVET := Color(0.3, 0.31, 0.33)
var detail := true                       # seams and rivets (off for the far level of detail)
var tinted := false                      # painted parts too (a forklift's yellow, a rack's orange beams): shaded in their own colour


# a painted part big enough to shade (tinted pens only): opaque, not a glow (nothing over 1)
func _paint(col: Color, size: Vector2) -> bool:
	return tinted and col.a >= 0.85 and maxf(col.r, maxf(col.g, col.b)) <= 1.0 and minf(size.x, size.y) >= 0.2


# a plain dark fill, the kind a casing is drawn in
static func solidish(col: Color) -> bool:
	if col.a < 0.85:
		return false
	var hi := maxf(col.r, maxf(col.g, col.b))
	var lo := minf(col.r, minf(col.g, col.b))
	return hi < 0.21 and hi - lo < 0.05


# the face in the tug station's greys (a dark fill lifted, its slight blue kept)
static func lift(col: Color) -> Color:
	var v := (col.r + col.g + col.b) / 3.0
	var g := 0.09 + v * 1.35
	return Color(g, g * 1.03, g * 1.1, 1.0)


func _quad4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var n := _v.size()
	_v.append_array([xf * a, xf * b, xf * c, xf * d])
	_c.append_array([ca, cb, cc, cd])
	_ix.append_array([n, n + 1, n + 2, n, n + 2, n + 3])


func rect(r: Rect2, col: Color, filled := true, w := 0.05) -> void:
	r = r.abs()
	var paint := filled and not solidish(col) and _paint(col, r.size)
	if not filled or (not solidish(col) and not paint) or minf(r.size.x, r.size.y) < 0.15:
		super.rect(r, col, filled, w)
		return
	var face := Color(col, 1.0) if paint else lift(col)
	var big := minf(r.size.x, r.size.y) >= 0.4 and r.size.x * r.size.y >= 0.3
	if big:
		super.rect(Rect2(r.position + SH, r.size), SH_COL)
	# the face: lit at the top, a shade darker toward the bottom
	var top := Color(face.r * 1.3, face.g * 1.3, face.b * 1.3, 1.0)
	var low := Color(face.r * 0.66, face.g * 0.66, face.b * 0.66, 1.0)
	_quad4(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), top, top, low, low)
	var lw := minf(0.08, minf(r.size.x, r.size.y) * 0.25)
	super.line(r.position, Vector2(r.end.x, r.position.y), EAVE, lw)
	super.line(r.position, Vector2(r.position.x, r.end.y), Color(EAVE.r * 0.75, EAVE.g * 0.75, EAVE.b * 0.75), lw)
	super.line(Vector2(r.position.x, r.end.y), r.end, DARK_EDGE, lw)
	super.line(Vector2(r.end.x, r.position.y), r.end, DARK_EDGE, lw)
	if detail and r.size.x >= 1.2 and r.size.y >= 1.2:
		# a plate seam across, the corner rivets
		var sy := r.position.y + r.size.y * 0.5
		super.line(Vector2(r.position.x + 0.12, sy), Vector2(r.end.x - 0.12, sy), SEAM, 0.035)
		super.line(Vector2(r.position.x + 0.12, sy + 0.04), Vector2(r.end.x - 0.12, sy + 0.04), Color(EAVE.r * 0.55, EAVE.g * 0.55, EAVE.b * 0.55), 0.02)
		for cx: float in [r.position.x + 0.22, r.end.x - 0.22]:
			for cy: float in [r.position.y + 0.22, r.end.y - 0.22]:
				circle(Vector2(cx, cy), 0.055, RIVET, 6)


func poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		super.poly(pts, col)
		return
	var bb := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		bb = bb.expand(q)
	var paint := not solidish(col) and _paint(col, bb.size)
	if (not solidish(col) and not paint) or minf(bb.size.x, bb.size.y) < 0.15:
		super.poly(pts, col)
		return
	var face := Color(col, 1.0) if paint else lift(col)
	if minf(bb.size.x, bb.size.y) >= 0.4:
		var sp := PackedVector2Array()
		for q in pts:
			sp.append(q + SH)
		super.poly(sp, SH_COL)
	super.poly(pts, face)
	# each edge lit if it faces the light, dark if it faces away
	var cw := Geometry2D.is_polygon_clockwise(pts)
	var lw := minf(0.06, minf(bb.size.x, bb.size.y) * 0.25)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var d := b - a
		if d.length_squared() < 1e-6:
			continue
		var nrm := d.normalized().orthogonal()
		if cw:
			nrm = -nrm
		var k := -nrm.dot(Vector2(-0.45, -0.89))
		if k < -0.2:
			super.line(a, b, EAVE, lw)
		elif k > 0.2:
			super.line(a, b, DARK_EDGE, lw)
