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
static var style := 3   # 2026-11-11 成品: 方案 C on by default (only the tug station reads it); F9 (Pal.solid) the old picture

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
	if style == 3:
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
