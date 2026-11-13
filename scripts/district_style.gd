class_name DistrictStyle
extends RefCounted
# 六区内部质感 (user 2026-11-11: "周围几个区质感还是很拉"): the districts' insides by subtraction —
# the back wall flat dark paint, the structure solid plates with their thickness and shadow, the
# pipes a few heavy runs along the corners, the machines solid, warm-white local light. Two
# proposals to choose from (tests/interior_style_shot.gd): 0 as it was; 1 方案 A 平涂实体; 2 方案 B
# 厂房分跨 (the same, the hall framed in bays by solid portal frames with a lamp pool in each);
# 3 方案 C 同中央环 (user: "能不能做成和中央的那个环一样的" — scripts/hub_tidy.gd's picture: a dark floor,
# flat plates in a few greys, each solid piece its shadow off away from the light, its face, a lit
# edge on the side toward it; dim outlines, no bolts or hatching; hazards one quiet line; a few small
# slow lamps, no washes or beams).
static var style := 9   # 2026-11-11 用户: 线稿版太难看，回到 7 稍稍降亮 — 9 = 7 at ~87%; 8 (黑白线稿, scripts/line_pen.gd) kept unused. Earlier: 2026-11-11 用户: "都不要灰色，只有之前一样的黑白" — 8 黑白线稿; was 7 (亮工业, top held back) # 2026-11-11 用户定 方向 1 亮工业，上方不要那么亮 (7 = 4 with the ceiling strip and its wash held back); only the tug station reads it; F9 (Pal.solid) the old picture

const WALL := Color(0.036, 0.039, 0.045)
const WALL_LOW := Color(0.026, 0.028, 0.032)
const PLATE := Color(0.1, 0.104, 0.116)
const PLATE_DK := Color(0.062, 0.066, 0.074)
const EAVE := Color(0.22, 0.227, 0.245)
const WARM := Color(1.0, 0.9, 0.74)


static func on() -> bool:
	return style > 0 and Pal.solid


# the hall behind the machines (drawn first, under them): flat dark paint a shade darker toward the
# floor; 方案 A one warm-white strip light along the ceiling washing the wall's top; 方案 B the hall
# in bays between solid portal frames under a roof beam, a lamp in each bay and its pool of light.
# The floor slab with its lit top. r the box (world px), m px a metre, floor_y the floor (m from top).
static func back_wall(ci: CanvasItem, r: Rect2, m: float, on: bool, floor_y := 26.8) -> void:
	var lk := 1.0 if on else 0.3
	var fy := r.position.y + floor_y * m
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, fy), Vector2(r.position.x, fy)]),
		PackedColorArray([WALL, WALL, WALL_LOW, WALL_LOW]))
	var top := r.position.y
	if style == 8:
		# 黑白线稿: pure black (scripts/tug_station_art.gd draws the hall in white line art)
		ci.draw_rect(r, Color(0, 0, 0))
		return
	if style >= 3:
		_ring_hall(ci, r, m, on, fy)
		return
	if style == 1:
		# the ceiling's slab, its lit underside; strip fixtures and their wash down the wall's top
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 0.8 * m)), PLATE_DK)
		ci.draw_line(Vector2(r.position.x, top + 0.8 * m), Vector2(r.end.x, top + 0.8 * m), Color(EAVE, 0.5), 0.08 * m)
		var wash := Color(WARM, 0.05 * lk)
		ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, top + 0.8 * m), Vector2(r.end.x, top + 0.8 * m), Vector2(r.end.x, top + 9.0 * m), Vector2(r.position.x, top + 9.0 * m)]),
			PackedColorArray([wash, wash, Color(WARM, 0.0), Color(WARM, 0.0)]))
		for i in 5:
			var cx := r.position.x + r.size.x * (i + 0.5) / 5.0
			ci.draw_rect(Rect2(cx - 2.2 * m, top + 0.8 * m, 4.4 * m, 0.22 * m), Color(WARM, 0.85 * lk))
	else:
		var bays := 4
		var beam := 1.4 * m
		# the bays' lamp pools first (on the wall, behind the frames)
		for i in bays:
			var cx := r.position.x + r.size.x * (i + 0.5) / bays
			var ly := top + beam + 0.4 * m
			var hw := r.size.x / bays * 0.42
			var pool := Color(WARM, 0.045 * lk)
			ci.draw_polygon(PackedVector2Array([Vector2(cx - 0.6 * m, ly), Vector2(cx + 0.6 * m, ly), Vector2(cx + hw, fy), Vector2(cx - hw, fy)]),
				PackedColorArray([pool, pool, Color(WARM, 0.0), Color(WARM, 0.0)]))
			ci.draw_rect(Rect2(cx - 0.9 * m, top + beam, 1.8 * m, 0.4 * m), PLATE)
			ci.draw_rect(Rect2(cx - 0.7 * m, top + beam + 0.3 * m, 1.4 * m, 0.14 * m), Color(WARM, 0.9 * lk))
		# the portal frames: shadow, the column, its lit edge toward the light (up, left)
		for i in range(1, bays):
			var x := r.position.x + r.size.x * i / bays
			var w := 1.3 * m
			ci.draw_rect(Rect2(x - w * 0.5 + 0.35 * m, top + beam, w, fy - top - beam), Color(0, 0, 0, 0.35))
			ci.draw_rect(Rect2(x - w * 0.5, top, w, fy - top), PLATE_DK)
			ci.draw_line(Vector2(x - w * 0.5, top + beam), Vector2(x - w * 0.5, fy), Color(EAVE, 0.55), 0.08 * m)
			ci.draw_line(Vector2(x + w * 0.5, top + beam), Vector2(x + w * 0.5, fy), Color(0, 0, 0, 0.6), 0.08 * m)
		# the roof beam across, its shadow and lit underside
		ci.draw_rect(Rect2(r.position.x, top + beam, r.size.x, 0.35 * m), Color(0, 0, 0, 0.35))
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, beam)), PLATE_DK)
		ci.draw_line(Vector2(r.position.x, top + beam), Vector2(r.end.x, top + beam), Color(EAVE, 0.5), 0.08 * m)
	# the floor slab: lit along its top, a quiet line of warning paint at its edge
	ci.draw_rect(Rect2(r.position.x, fy, r.size.x, r.end.y - fy), PLATE_DK)
	ci.draw_line(Vector2(r.position.x, fy), Vector2(r.end.x, fy), Color(EAVE, 0.7), 0.1 * m)
	ci.draw_line(Vector2(r.position.x, fy + 0.35 * m), Vector2(r.end.x, fy + 0.35 * m), Pal.heat(0.3, 0.85), 0.07 * m)


# 方案 C: the hall as the central ring's floor and walls are drawn (hub_tidy.gd): the wall one dark
# flat plate (the ring's track bed), the ceiling slab and the floor slab as its plates — shadow, face,
# the edge toward the light lit, the other dark — the floor's edge one quiet warning line, a few
# small lamps under the ceiling (the ring's wall lamps: a dark housing, a short pale bar)
static func _ring_hall(ci: CanvasItem, r: Rect2, m: float, on: bool, fy: float) -> void:
	const HUB_WALL := Color(0.032, 0.034, 0.04)
	const HUB_TOP := Color(0.1, 0.104, 0.116)
	const HUB_LOW := Color(0.06, 0.063, 0.071)
	var top := r.position.y
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, fy - top)), HUB_WALL)
	# its plates' seams, few and faint (the ring's deck)
	var sx := r.position.x + 10.0 * m
	while sx < r.end.x - 1.0 * m:
		ci.draw_line(Vector2(sx, top), Vector2(sx, fy), Color(0.05, 0.053, 0.06), 0.06 * m)
		sx += 10.0 * m
	var sh := -Look.LIGHT_DIR * 0.5 * m
	# the ceiling slab: its shadow on the wall below it, its face, the underside away from the light
	ci.draw_rect(Rect2(r.position + Vector2(0, 0.9 * m) + Vector2(0, sh.y * 0.5), Vector2(r.size.x, 0.5 * m)), Color(0, 0, 0, 0.45))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 0.9 * m)), HUB_LOW)
	ci.draw_line(Vector2(r.position.x, top + 0.9 * m), Vector2(r.end.x, top + 0.9 * m), Color(0, 0, 0, 0.55), 0.06 * m)
	var lk := 1.0 if on else 0.25
	for i in 6:
		var cx := r.position.x + r.size.x * (i + 0.5) / 6.0
		ci.draw_rect(Rect2(cx - 0.55 * m, top + 0.9 * m, 1.1 * m, 0.4 * m), HUB_LOW)
		ci.draw_rect(Rect2(cx - 0.55 * m, top + 0.9 * m, 1.1 * m, 0.4 * m), Pal.ink(0.22), false, 0.04 * m)
		ci.draw_line(Vector2(cx - 0.4 * m, top + 1.18 * m), Vector2(cx + 0.4 * m, top + 1.18 * m), Color(0.85, 0.88, 0.9, 0.55 * lk), 0.07 * m)
	# the floor slab: its face, the top toward the light lit, one warning line at its edge
	ci.draw_rect(Rect2(r.position.x, fy, r.size.x, r.end.y - fy), HUB_TOP)
	ci.draw_line(Vector2(r.position.x, fy), Vector2(r.end.x, fy), Color(EAVE, 0.85), 0.08 * m)
	ci.draw_line(Vector2(r.position.x, fy + 0.3 * m), Vector2(r.end.x, fy + 0.3 * m), Pal.heat(0.3, 0.85), 0.08 * m)


# ------------------------------------------------------------------ each district's own hall
# 2026-11-12 (user: "我之前要的那个画风，推广到其他区域了吗"): the tug station's finished interior
# language (recessed wall panels, portal columns and girders, pipe bundles, cable trays, catwalks, a lit
# edge toward the light and a shadow away from it, outlines opaque dark grey) carried to the other
# districts, each with its own working details. Background only: drawn after back_wall and under the
# district's own machines (their art is theirs); no words. Drawn once into the still layer.
static var halls := true          # tests: false draws the districts as before (the tug station aside)
static var hall_us := 0.0         # tests: what the last hall took to draw (µs, recorded once per redraw)
# 2026-11-12 (user, on the first trade hall: "我能走的地方怎么还有柱子呢？我能走的地方应该没有柱子才对，
# 是空的"): where the drone can fly nothing may look solid — no column, girder, pipe, walkway or ladder
# in the open. Structure only on the district's shell (FRAME m in from its edge), above the ceiling
# (CEIL), below the floor (FLOOR_Y), or on what really collides (scripts/port_solids.gd and the rest:
# laid over it, inside its rect). In the open at most the wall's own faint texture, plainly behind.
# Every structure helper notes its rect (box-local m) while `noting`: tests/hall_walkable_check.gd.
const FRAME := 0.8
const CEIL := 0.9
const FLOOR_Y := 26.8
static var noting := false
static var noted: Array = []


static func _note(a: Vector2, b: Vector2) -> void:
	if noting:
		noted.append(Rect2(a, b - a).abs())

const COL := Color(0.235, 0.244, 0.264)      # column / girder face (the tug station's style 9 FACE)
const COL_LIT := Color(0.42, 0.436, 0.462)   # the edge toward the light (its eave)
const COL_DK := Color(0.11, 0.115, 0.126)   # the edge away from it
const RECESS := Color(0.085, 0.089, 0.098)   # a recessed panel (a shade under the wall)
const SHADOW := Color(0.04, 0.042, 0.047)    # a cast shadow (opaque: hdr_2d mixes half-tones too bright)
const PIPE := Color(0.218, 0.226, 0.244)
const PIPE_LIT := Color(0.36, 0.373, 0.396)
const LINE := Color(0.12, 0.124, 0.137)      # quiet outlines and seams
const LAMP := Color(0.72, 0.68, 0.6)
const FAINT := Color(0.082, 0.085, 0.094)
const MESH := Color(0.13, 0.135, 0.148)       # a rack's wire mesh: clear, under the goods    # the far wall's seams: a breath above the plating
const HALL_WALL := Color(0.072, 0.075, 0.083)  # the hall's wall plating (the tug station's C_PANEL at style 9)


static func _q(ci, r: Rect2, m: float, a: Vector2, b: Vector2, col: Color) -> void:
	ci.draw_rect(Rect2(r.position + a * m, (b - a) * m), col)


static func _l(ci, r: Rect2, m: float, a: Vector2, b: Vector2, col: Color, wm: float) -> void:
	ci.draw_line(r.position + a * m, r.position + b * m, col, wm * m)


# a portal column from y0 to y1 (m), w wide: its shadow off to the right, face, lit left edge, dark right
static func _column(ci, r: Rect2, m: float, x: float, y0: float, y1: float, w := 1.1) -> void:
	_note(Vector2(x - w * 0.5, y0), Vector2(x + w * 0.5 + 0.45, y1))
	_q(ci, r, m, Vector2(x + w * 0.5, y0 + 0.3), Vector2(x + w * 0.5 + 0.45, y1), SHADOW)
	_q(ci, r, m, Vector2(x - w * 0.5, y0), Vector2(x + w * 0.5, y1), COL)
	_l(ci, r, m, Vector2(x - w * 0.5 + 0.05, y0), Vector2(x - w * 0.5 + 0.05, y1), COL_LIT, 0.09)
	_l(ci, r, m, Vector2(x + w * 0.5 - 0.04, y0), Vector2(x + w * 0.5 - 0.04, y1), COL_DK, 0.08)
	# its stiffener plates, a few
	var y := y0 + 2.0
	while y < y1 - 1.0:
		_l(ci, r, m, Vector2(x - w * 0.5 + 0.12, y), Vector2(x + w * 0.5 - 0.12, y), LINE, 0.05)
		y += 3.2


# a girder across from x0 to x1 at y (its depth d): shadow below, face, lit top, dark underside
static func _girder(ci, r: Rect2, m: float, x0: float, x1: float, y: float, d: float) -> void:
	_note(Vector2(x0, y), Vector2(x1, y + d + 0.4))
	_q(ci, r, m, Vector2(x0, y + d), Vector2(x1, y + d + 0.4), SHADOW)
	_q(ci, r, m, Vector2(x0, y), Vector2(x1, y + d), COL)
	_l(ci, r, m, Vector2(x0, y + 0.04), Vector2(x1, y + 0.04), COL_LIT, 0.08)
	_l(ci, r, m, Vector2(x0, y + d - 0.04), Vector2(x1, y + d - 0.04), COL_DK, 0.08)
	var x := x0 + 1.5
	while x < x1 - 0.5:
		_l(ci, r, m, Vector2(x, y + 0.15), Vector2(x, y + d - 0.15), LINE, 0.05)
		x += 3.0


# a recessed panel: the reveal's dark top and left (in shadow), lit bottom and right lips
static func _recess(ci, r: Rect2, m: float, a: Vector2, b: Vector2) -> void:
	_note(a, b)
	_q(ci, r, m, a, b, RECESS)
	_l(ci, r, m, a, Vector2(b.x, a.y), SHADOW, 0.14)
	_l(ci, r, m, a, Vector2(a.x, b.y), SHADOW, 0.1)
	_l(ci, r, m, Vector2(a.x, b.y), b, COL_LIT, 0.05)
	_l(ci, r, m, Vector2(b.x, a.y), b, LINE, 0.05)


# a run of n pipes along y from x0 to x1, d apart, on brackets every 4 m
static func _pipes(ci, r: Rect2, m: float, x0: float, x1: float, y: float, n: int, d := 0.36, wm := 0.24) -> void:
	_note(Vector2(x0, y - 0.3), Vector2(x1, y + (n - 1) * d + 0.3))
	var x := x0 + 1.0
	while x < x1:
		_q(ci, r, m, Vector2(x - 0.08, y - 0.3), Vector2(x + 0.08, y + (n - 1) * d + 0.3), COL_DK)
		x += 4.0
	for k in n:
		var py := y + k * d
		_l(ci, r, m, Vector2(x0, py + 0.12), Vector2(x1, py + 0.12), SHADOW, wm)
		_l(ci, r, m, Vector2(x0, py), Vector2(x1, py), PIPE, wm)
		_l(ci, r, m, Vector2(x0, py - wm * 0.28), Vector2(x1, py - wm * 0.28), PIPE_LIT, wm * 0.22)
	# flanges
	x = x0 + 3.0
	while x < x1:
		for k in n:
			_q(ci, r, m, Vector2(x - 0.06, y + k * d - wm * 0.75), Vector2(x + 0.06, y + k * d + wm * 0.75), PIPE_LIT)
		x += 6.0


# a cable tray along y: its side rail, rungs, the cables in it
static func _tray(ci, r: Rect2, m: float, x0: float, x1: float, y: float) -> void:
	_note(Vector2(x0, y - 0.3), Vector2(x1, y + 0.3))
	_l(ci, r, m, Vector2(x0, y + 0.2), Vector2(x1, y + 0.2), SHADOW, 0.16)
	_l(ci, r, m, Vector2(x0, y), Vector2(x1, y), COL, 0.2)
	_l(ci, r, m, Vector2(x0, y - 0.08), Vector2(x1, y - 0.08), COL_LIT, 0.04)
	_l(ci, r, m, Vector2(x0, y - 0.22), Vector2(x1, y - 0.22), Color(0.09, 0.07, 0.06), 0.1)
	var x := x0 + 0.5
	while x < x1:
		_l(ci, r, m, Vector2(x, y - 0.12), Vector2(x, y + 0.1), LINE, 0.04)
		x += 1.0


# a catwalk along y from x0 to x1: deck, kick plate, handrail on posts
static func _walk(ci, r: Rect2, m: float, x0: float, x1: float, y: float) -> void:
	_note(Vector2(x0, y - 1.1), Vector2(x1, y + 0.32))
	_q(ci, r, m, Vector2(x0, y), Vector2(x1, y + 0.32), SHADOW)
	_q(ci, r, m, Vector2(x0, y - 0.06), Vector2(x1, y + 0.18), COL)
	_l(ci, r, m, Vector2(x0, y - 0.04), Vector2(x1, y - 0.04), COL_LIT, 0.05)
	_l(ci, r, m, Vector2(x0, y - 1.1), Vector2(x1, y - 1.1), COL_LIT, 0.06)
	_l(ci, r, m, Vector2(x0, y - 0.55), Vector2(x1, y - 0.55), LINE, 0.04)
	var x := x0
	while x <= x1 + 0.01:
		_l(ci, r, m, Vector2(x, y - 1.1), Vector2(x, y), COL_LIT, 0.05)
		x += 1.5


# a ladder from y0 down to y1 at x
static func _ladder(ci, r: Rect2, m: float, x: float, y0: float, y1: float) -> void:
	_note(Vector2(x - 0.25, y0), Vector2(x + 0.25, y1))
	_l(ci, r, m, Vector2(x - 0.25, y0), Vector2(x - 0.25, y1), COL_LIT, 0.05)
	_l(ci, r, m, Vector2(x + 0.25, y0), Vector2(x + 0.25, y1), COL_LIT, 0.05)
	var y := y0 + 0.3
	while y < y1:
		_l(ci, r, m, Vector2(x - 0.25, y), Vector2(x + 0.25, y), LINE, 0.04)
		y += 0.35


# a small lamp under a girder at x, y: its housing and a short pale bar, a soft pool on the wall
static func _lamp(ci, r: Rect2, m: float, x: float, y: float, on: bool, reach := 5.0) -> void:
	_note(Vector2(x - 0.6, y), Vector2(x + 0.6, y + 0.35))
	if on:
		var top := r.position + Vector2(x, y + 0.4) * m
		var pool := Color(0.15, 0.145, 0.135)
		ci.draw_polygon(PackedVector2Array([top + Vector2(-0.5, 0) * m, top + Vector2(0.5, 0) * m, top + Vector2(2.6, reach) * m, top + Vector2(-2.6, reach) * m]),
			PackedColorArray([pool, pool, HALL_WALL, HALL_WALL]))
	_q(ci, r, m, Vector2(x - 0.6, y), Vector2(x + 0.6, y + 0.35), COL_DK)
	_l(ci, r, m, Vector2(x - 0.45, y + 0.3), Vector2(x + 0.45, y + 0.3), LAMP if on else LINE, 0.07)


# a roll-up goods door in the back wall: its frame, the curtain's slats, the hood, a quiet warning
# line at its foot
static func _door(ci, r: Rect2, m: float, x0: float, x1: float, y0: float, y1: float, open: float) -> void:
	_note(Vector2(x0 - 0.5, y0 - 0.9), Vector2(x1 + 0.5, y1))
	_q(ci, r, m, Vector2(x0 - 0.5, y0 - 0.9), Vector2(x1 + 0.5, y1), COL)
	_l(ci, r, m, Vector2(x0 - 0.5, y0 - 0.9), Vector2(x1 + 0.5, y0 - 0.9), COL_LIT, 0.07)
	_l(ci, r, m, Vector2(x0 - 0.45, y0 - 0.9), Vector2(x0 - 0.45, y1), COL_LIT, 0.06)
	_q(ci, r, m, Vector2(x0, y0), Vector2(x1, y1), RECESS)
	var cy := lerpf(y0, y1 - 0.4, open)
	_q(ci, r, m, Vector2(x0, cy), Vector2(x1, y1), Color(0.085, 0.089, 0.1))
	var y := cy + 0.3
	while y < y1:
		_l(ci, r, m, Vector2(x0 + 0.05, y), Vector2(x1 - 0.05, y), LINE, 0.04)
		y += 0.42
	_l(ci, r, m, Vector2(x0, cy), Vector2(x1, cy), COL_LIT, 0.06)
	# the hood the curtain rolls into
	_q(ci, r, m, Vector2(x0 - 0.2, y0 - 0.75), Vector2(x1 + 0.2, y0), Color(0.09, 0.094, 0.104))
	_l(ci, r, m, Vector2(x0 - 0.2, y0), Vector2(x1 + 0.2, y0), COL_DK, 0.06)
	_l(ci, r, m, Vector2(x0, y1 - 0.08), Vector2(x1, y1 - 0.08), Pal.heat(0.3, 0.85), 0.07)



# the hall wall in the open: flat plating, its seams faint (plainly the far wall, nothing to hit)
static func _far_wall(ci, r: Rect2, m: float, step := 4.8, x0 := 0.0, x1 := 60.0, k := 1.0) -> void:
	_q(ci, r, m, Vector2(x0, CEIL), Vector2(x1, FLOOR_Y), HALL_WALL * Color(k, k, k, 1.0))
	var seam := FAINT * Color(k, k, k, 1.0)
	var sy := CEIL + step
	while sy < FLOOR_Y - 0.5:
		_l(ci, r, m, Vector2(x0, sy), Vector2(x1, sy), seam, 0.035)
		sy += step
	var sx := x0 + 7.5
	while sx < x1 - 1.0:
		_l(ci, r, m, Vector2(sx, CEIL), Vector2(sx, FLOOR_Y), seam, 0.03)
		sx += 7.5


# the shell: a pilaster strip down each end wall inside FRAME, its lit inner edge
static func _shell(ci, r: Rect2, m: float) -> void:
	for x: Vector2 in [Vector2(0.0, FRAME), Vector2(60.0 - FRAME, 60.0)]:
		_note(Vector2(x.x, CEIL), Vector2(x.y, FLOOR_Y))
		_q(ci, r, m, Vector2(x.x, CEIL), Vector2(x.y, FLOOR_Y), COL)
		var inner: float = x.y if x.x < 1.0 else x.x
		_l(ci, r, m, Vector2(inner, CEIL), Vector2(inner, FLOOR_Y), COL_LIT if x.x < 1.0 else COL_DK, 0.06)
		var y := CEIL + 3.0
		while y < FLOOR_Y - 1.0:
			_l(ci, r, m, Vector2(x.x + 0.1, y), Vector2(x.y - 0.1, y), LINE, 0.04)
			y += 3.2


# below the floor's top: the slab's trench and its grating, the warning line stays back_wall's
static func _under_floor(ci, r: Rect2, m: float, x0: float, x1: float) -> void:
	_note(Vector2(x0, FLOOR_Y + 0.45), Vector2(x1, FLOOR_Y + 0.95))
	_q(ci, r, m, Vector2(x0, FLOOR_Y + 0.45), Vector2(x1, FLOOR_Y + 0.95), SHADOW)
	var x := x0 + 0.2
	while x < x1:
		_l(ci, r, m, Vector2(x, FLOOR_Y + 0.5), Vector2(x, FLOOR_Y + 0.9), LINE, 0.04)
		x += 0.3


# a lamp set into the underside of a solid (a slab, a girder) whose bottom edge is at y: no housing
# hanging into the air, a pale bar flush with it and a soft pool on the wall below
static func _flush_lamp(ci, r: Rect2, m: float, x: float, y: float, on: bool, reach := 4.6, glow := 1.0) -> void:
	_note(Vector2(x - 0.5, y - 0.2), Vector2(x + 0.5, y))
	if on:
		var top := r.position + Vector2(x, y) * m
		var pool := Color(0.15 * glow, 0.145 * glow, 0.135 * glow)
		ci.draw_polygon(PackedVector2Array([top + Vector2(-0.5, 0) * m, top + Vector2(0.5, 0) * m, top + Vector2(2.6, reach) * m, top + Vector2(-2.6, reach) * m]),
			PackedColorArray([pool, pool, HALL_WALL, HALL_WALL]))
	_l(ci, r, m, Vector2(x - 0.45, y - 0.06), Vector2(x + 0.45, y - 0.06), LAMP if on else LINE, 0.07)


# 贸易港: the visitors' hall upstairs, the dock under its slab (scripts/trade_hall_art.gd draws the
# board, the booths, the slab and its columns, the belt, the locks). Open air everywhere else, so here
# only the far wall's plating, the shell's end pilasters, the trench under the floor, and lamps set
# flush into the underside of the slab (port_solids: 14–60 m, 15.8–16.4 m) over the dock.
static func trade_hall(ci, r: Rect2, m: float, on: bool) -> void:
	# (2026-11-12 review: the trade hall read darker and emptier than the others beside it — mostly open
	# air by the rule — so its far wall a step lighter and more light on it: lamps flush in the ceiling
	# of the upper hall either side of the board, the dock's under the slab brighter)
	_far_wall(ci, r, m, 4.8, 0.0, 60.0, 1.85)
	_shell(ci, r, m)
	_under_floor(ci, r, m, 2.0, 58.0)
	for x in [24.5, 39.5, 52.0]:
		_flush_lamp(ci, r, m, x, 16.4, on, 7.5, 1.6)
	for x in [5.0, 11.5, 56.8]:
		_flush_lamp(ci, r, m, x, CEIL, on, 11.0, 1.5)


# 加工区: scripts/process_art.gd draws the hall's truss, its columns, the lamps, the floor and the
# machines; the open air between them stays open. Here only the far wall's plating, the shell, the
# trench under the floor, and lamps flush under the crane's runway girder (port_solids: 0.3–36.6 m,
# 9.42–10.3 m) over the furnace bay.
static func process_hall(ci, r: Rect2, m: float, on: bool) -> void:
	_far_wall(ci, r, m)
	_shell(ci, r, m)
	_under_floor(ci, r, m, 2.0, 58.0)
	for x in [6.0, 24.0, 33.0]:
		_flush_lamp(ci, r, m, x, 10.3, on, 3.4)


# 仓库 (货运区): scripts/cargo_art.gd draws the hall's truss, the high-bay lamps, the two banks of racking,
# the stacker crane's runway, the board, the roller line, the forklifts; the open floor between the
# racks stays open (the forklifts' lane, the stacker's aisle). Here the far wall's plating, the shell,
# and the trench under the floor either side of the yard hatch (27.5–32.5 m).
static func cargo_hall(ci, r: Rect2, m: float, on: bool) -> void:
	_far_wall(ci, r, m)
	_shell(ci, r, m)
	_under_floor(ci, r, m, 2.0, 27.2)
	_under_floor(ci, r, m, 32.8, 58.0)
	# the racks' wire-mesh backs, inside the banks (they collide: port_solids): darker than the wall,
	# the mesh's grid, so the bays read deep behind the beams and the loads
	for rb: Rect2 in [Rect2(5.87, 8.8, 10.26, 3.6), Rect2(5.87, 16.0, 10.26, 5.26), Rect2(41.87, 8.8, 10.26, 12.46)]:
		_note(rb.position, rb.end)
		_q(ci, r, m, rb.position, rb.end, Color(0.05, 0.052, 0.058))
		var gx := rb.position.x + 0.3
		while gx < rb.end.x:
			_l(ci, r, m, Vector2(gx, rb.position.y), Vector2(gx, rb.end.y), MESH, 0.03)
			gx += 0.5
		var gy := rb.position.y + 0.3
		while gy < rb.end.y:
			_l(ci, r, m, Vector2(rb.position.x, gy), Vector2(rb.end.x, gy), MESH, 0.03)
			gy += 0.5


# 动力区: scripts/power_station_art.gd draws the plant (the three reactor bays, the control screen, the
# turbine on its deck, the condenser, the switchgear, the pumps, the fuel cells) and its pipe runs; the
# air between them stays open. Here the far wall's plating, the shell, and the trench under the floor
# either side of the arrival door in it.
static func power_hall(ci, r: Rect2, m: float, on: bool) -> void:
	_far_wall(ci, r, m)
	_shell(ci, r, m)
	for fr: Rect2 in preload("res://scripts/port_solids.gd").floor_rects("power"):
		if fr.size.x > 3.0:
			_under_floor(ci, r, m, maxf(fr.position.x, 1.5) + 0.5, minf(fr.end.x, 58.5) - 0.5)


# the colliding rects of a district, box-local m: what its art draws solid, its floor, its machines
static func solids(zone: String) -> Array:
	var out: Array = []
	out.append_array(preload("res://scripts/port_solids.gd").rects(zone))
	out.append_array(preload("res://scripts/port_solids.gd").floor_rects(zone))
	for mc in PortStructure.MACHINES.get(zone, []):
		out.append(Rect2(mc[1], mc[2]))
	for s in preload("res://scripts/district_interiors.gd").SOLIDS.get(zone, []):
		out.append(Rect2(s[1], s[2]))
	return out


# where a column at x from y0 down to y1 stands in something solid: the spans [top, bottom] (merged)
static func column_spans(zone: String, x: float, y0: float, y1: float) -> Array:
	var segs: Array = []
	for s: Rect2 in solids(zone):
		if x > s.position.x and x < s.end.x:
			var a := maxf(y0, s.position.y)
			var b := minf(y1, s.end.y)
			if b > a + 0.05:
				segs.append(Vector2(a, b))
	segs.sort_custom(func(u, v): return u.x < v.x)
	var out: Array = []
	for sg: Vector2 in segs:
		if not out.is_empty() and sg.x <= (out[-1] as Vector2).y + 0.01:
			out[-1] = Vector2((out[-1] as Vector2).x, maxf((out[-1] as Vector2).y, sg.y))
		else:
			out.append(sg)
	return out


# ------------------------------------------------------------------ the solid look for machines drawn
# straight onto a canvas (in px), the same as scripts/solid_pen.gd gives the baked ones (2026-11-12,
# user: "纯2D、纯扁平啊，没有一点质感"): for a district's modules' own fill and edge helpers
static func solid() -> bool:
	return on() and halls


# line art in the solid look: faint detail lines dark (cut into the faces), outlines light (round them)
static func ink(a: float) -> Color:
	if not solid():
		return Pal.ink(a)
	var g := (0.04 + a * 0.28) if a < 0.3 else (0.3 + a * 0.5)
	return Color(g, g * 1.03, g * 1.1)


# a casing's rect (px) as lit steel: shadow, a top-to-bottom shade, the lit and the dark edges.
# False (nothing drawn) when the solid look is off or the fill is no casing's: the caller draws its own
static func solid_rect(ci, r: Rect2, fill: Color, m: float, paint := false) -> bool:
	const SP = preload("res://scripts/solid_pen.gd")
	r = r.abs()
	# (paint: a painted or lighter steel part shaded in its own colour, as a tinted pen does)
	var painted := paint and not SP.solidish(fill) and fill.a >= 0.85 and maxf(fill.r, maxf(fill.g, fill.b)) <= 1.0
	if not solid() or (not SP.solidish(fill) and not painted) or minf(r.size.x, r.size.y) < 0.15 * m:
		return false
	var face := Color(fill, 1.0) if painted else SP.lift(fill)
	if minf(r.size.x, r.size.y) >= 0.4 * m:
		ci.draw_rect(Rect2(r.position + SP.SH * m, r.size), SP.SH_COL)
	var top := Color(face.r * 1.3, face.g * 1.3, face.b * 1.3, 1.0)
	var low := Color(face.r * 0.66, face.g * 0.66, face.b * 0.66, 1.0)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, low, low]))
	var lw := maxf(1.0, minf(0.08 * m, minf(r.size.x, r.size.y) * 0.25))
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), SP.EAVE, lw)
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(SP.EAVE.r * 0.75, SP.EAVE.g * 0.75, SP.EAVE.b * 0.75), lw)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, SP.DARK_EDGE, lw)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, SP.DARK_EDGE, lw)
	return true


# a casing's outline (px) as lit steel: shadow, face, each edge lit or dark by where it faces
static func solid_poly(ci, pts: PackedVector2Array, fill: Color, m: float) -> bool:
	const SP = preload("res://scripts/solid_pen.gd")
	if not solid() or not SP.solidish(fill) or pts.size() < 3:
		return false
	var bb := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		bb = bb.expand(q)
	if minf(bb.size.x, bb.size.y) < 0.15 * m:
		return false
	var face := SP.lift(fill)
	if minf(bb.size.x, bb.size.y) >= 0.4 * m:
		var sp := PackedVector2Array()
		for q in pts:
			sp.append(q + SP.SH * m)
		ci.draw_colored_polygon(sp, SP.SH_COL)
	var top := Color(face.r * 1.25, face.g * 1.25, face.b * 1.25, 1.0)
	var low := Color(face.r * 0.7, face.g * 0.7, face.b * 0.7, 1.0)
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(low, clampf((q.y - bb.position.y) / maxf(bb.size.y, 0.001), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	var cw := Geometry2D.is_polygon_clockwise(pts)
	var lw := maxf(1.0, minf(0.07 * m, minf(bb.size.x, bb.size.y) * 0.25))
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
			ci.draw_line(a, b, SP.EAVE, lw)
		elif k > 0.2:
			ci.draw_line(a, b, SP.DARK_EDGE, lw)
	return true
