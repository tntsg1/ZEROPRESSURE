class_name GoodsArt
# The goods as clear pictures (50 号; player 2026-10-25: "make the icons for unsorted metal, ferrous
# feed and so on clear, not so blurry"): small isometric illustrations with lit, mid and shaded
# faces, crisp antialiased edges, a soft shadow under them — a skip of torn scrap, a pressed
# bale with its straps, a bulk bag showing copper and aluminium, a bundle of square billets with
# their cut ends. Drawn into any rect (keeps 16:10), so they stay sharp at any size.

const EDGE := Color(0.02, 0.025, 0.03, 0.9)
const STRAP := Color(0.55, 0.57, 0.6)
const STRAP_G1 := Color(1.0, 0.54, 0.31)


static func _p(r: Rect2, v: Vector2) -> Vector2:
	# 160 × 100 design units into the rect, centred
	var k := minf(r.size.x / 160.0, r.size.y / 100.0)
	return r.get_center() + (v - Vector2(80, 50)) * k


static func _k(r: Rect2) -> float:
	return minf(r.size.x / 160.0, r.size.y / 100.0)


static func _poly(ci, r: Rect2, pts: Array, col: Color, edge := true, width := 1.2) -> void:
	var pv := PackedVector2Array()
	for v in pts:
		pv.append(_p(r, v))
	ci.draw_colored_polygon(pv, col)
	if edge:
		var cl := pv.duplicate()
		cl.append(pv[0])
		ci.draw_polyline(cl, EDGE, width * _k(r), true)


static func _shade(ci, r: Rect2, pts: Array, top: Color, bottom: Color) -> void:
	# a face lit from above: its upper points light, its lower ones dark
	var pv := PackedVector2Array()
	var cols := PackedColorArray()
	var y0 := INF
	var y1 := -INF
	for v in pts:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	for v in pts:
		pv.append(_p(r, v))
		cols.append(top.lerp(bottom, clampf((v.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)))
	ci.draw_polygon(pv, cols)
	var cl := pv.duplicate()
	cl.append(pv[0])
	ci.draw_polyline(cl, EDGE, 1.2 * _k(r), true)


static func _line(ci, r: Rect2, a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	ci.draw_line(_p(r, a), _p(r, b), col, w * _k(r), true)


static func _shadow(ci, r: Rect2, cx: float, y: float, rx: float) -> void:
	var pv := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pv.append(_p(r, Vector2(cx + cos(a) * rx, y + sin(a) * rx * 0.18)))
	ci.draw_colored_polygon(pv, Color(0, 0, 0, 0.35))


# an isometric box: front, side and top faces
static func _box(ci, r: Rect2, o: Vector2, w: float, h: float, d: float, base: Color) -> void:
	var dx := Vector2(d * 0.7, -d * 0.45)
	_shade(ci, r, [o + Vector2(0, -h) + dx, o + Vector2(w, -h) + dx, o + Vector2(w, -h), o + Vector2(0, -h)], base.lightened(0.35), base.lightened(0.2))
	_shade(ci, r, [o + Vector2(w, -h), o + Vector2(w, -h) + dx, o + Vector2(w, 0) + dx, o + Vector2(w, 0)], base.darkened(0.25), base.darkened(0.45))
	_shade(ci, r, [o + Vector2(0, -h), o + Vector2(w, -h), o + Vector2(w, 0), o], base.lightened(0.08), base.darkened(0.15))


static func draw(ci, r: Rect2, item: String, grade: int) -> void:
	match item:
		"mixed_metal": _skip(ci, r)
		"ferrous_scrap":
			# 64 号: grade 1 is the berth furnace's cast ingot
			if grade >= 1:
				_ingots(ci, r)
			else:
				_bale(ci, r, grade)
		"nonferrous_mix": _bag(ci, r)
		"steel_billet": _billets(ci, r, grade)
		"steel_plate": _plates(ci, r)
		"steel_section": _sections(ci, r)


# 74 号: a stack of rolled plate, strapped, on dunnage
static func _plates(ci, r: Rect2) -> void:
	_shadow(ci, r, 80, 86, 62)
	for i in 6:
		var y := 72.0 - i * 6.0
		_poly(ci, r, [Vector2(22, y), Vector2(130, y), Vector2(138, y - 5), Vector2(30, y - 5)], Color(0.42, 0.44, 0.47).lerp(Color(0.6, 0.62, 0.65), i / 6.0))
	for x in [50.0, 104.0]:
		_line(ci, r, Vector2(x, 76), Vector2(x + 8, 40), Color(0.75, 0.55, 0.25), 1.6)
	for x in [36.0, 118.0]:
		_poly(ci, r, [Vector2(x - 8, 82), Vector2(x + 8, 82), Vector2(x + 8, 76), Vector2(x - 8, 76)], Color(0.38, 0.27, 0.17))


# 74 号: a bundle of rolled sections, I-beam ends to the front
static func _sections(ci, r: Rect2) -> void:
	_shadow(ci, r, 80, 86, 62)
	for row in 3:
		for col in 4 - row:
			var cx := 40.0 + col * 24.0 + row * 12.0
			var cy := 74.0 - row * 16.0
			_poly(ci, r, [Vector2(cx - 10, cy), Vector2(cx + 10, cy), Vector2(cx + 10, cy - 3), Vector2(cx + 2, cy - 3), Vector2(cx + 2, cy - 11), Vector2(cx + 10, cy - 11), Vector2(cx + 10, cy - 14), Vector2(cx - 10, cy - 14), Vector2(cx - 10, cy - 11), Vector2(cx - 2, cy - 11), Vector2(cx - 2, cy - 3), Vector2(cx - 10, cy - 3)], Color(0.5, 0.52, 0.55))
	_line(ci, r, Vector2(30, 44), Vector2(132, 44), Color(0.75, 0.55, 0.25), 1.6)


# a skip of mixed scrap: ribbed sides, wheels, torn plate, an I-beam end, a bolt, rust
static func _skip(ci, r: Rect2) -> void:
	_shadow(ci, r, 80, 88, 58)
	# the heap above the rim, behind the front wall
	_poly(ci, r, [Vector2(34, 46), Vector2(48, 22), Vector2(60, 34), Vector2(70, 18), Vector2(84, 30), Vector2(96, 14), Vector2(110, 32), Vector2(124, 46)], Color(0.32, 0.33, 0.35))
	_poly(ci, r, [Vector2(52, 44), Vector2(62, 28), Vector2(78, 36), Vector2(72, 46)], Color(0.48, 0.31, 0.2))
	_poly(ci, r, [Vector2(88, 46), Vector2(92, 26), Vector2(108, 30), Vector2(116, 46)], Color(0.55, 0.57, 0.6))
	_line(ci, r, Vector2(92, 26), Vector2(108, 30), Color(0.85, 0.87, 0.9), 1.4)
	# an I-beam end
	_poly(ci, r, [Vector2(72, 30), Vector2(82, 30), Vector2(82, 32), Vector2(78, 32), Vector2(78, 40), Vector2(82, 40), Vector2(82, 42), Vector2(72, 42), Vector2(72, 40), Vector2(76, 40), Vector2(76, 32), Vector2(72, 32)], Color(0.62, 0.64, 0.67))
	# a bolt
	_poly(ci, r, [Vector2(42, 36), Vector2(47, 33), Vector2(52, 36), Vector2(52, 41), Vector2(47, 44), Vector2(42, 41)], Color(0.7, 0.72, 0.75))
	# the skip: tapered walls, ribs, a rim
	_shade(ci, r, [Vector2(26, 44), Vector2(134, 44), Vector2(124, 82), Vector2(36, 82)], Color(0.42, 0.45, 0.48), Color(0.2, 0.22, 0.24))
	_poly(ci, r, [Vector2(24, 41), Vector2(136, 41), Vector2(136, 46), Vector2(24, 46)], Color(0.55, 0.58, 0.61))
	for x in [46.0, 66.0, 94.0, 114.0]:
		_line(ci, r, Vector2(x, 47), Vector2(x - (x - 80.0) * 0.09, 81), Color(0.15, 0.16, 0.18), 2.2)
		_line(ci, r, Vector2(x + 1.5, 47), Vector2(x + 1.5 - (x - 80.0) * 0.09, 81), Color(0.55, 0.58, 0.6, 0.6), 1.0)
	# rust streaks and a stencil plate
	_poly(ci, r, [Vector2(52, 60), Vector2(56, 60), Vector2(54, 76)], Color(0.45, 0.25, 0.14, 0.8), false)
	_poly(ci, r, [Vector2(70, 56), Vector2(90, 56), Vector2(90, 64), Vector2(70, 64)], Color(0.85, 0.55, 0.2))
	# wheels
	for x in [46.0, 114.0]:
		ci.draw_circle(_p(r, Vector2(x, 85)), 6.0 * _k(r), Color(0.08, 0.09, 0.1))
		ci.draw_circle(_p(r, Vector2(x, 85)), 2.4 * _k(r), Color(0.5, 0.52, 0.55))


# a pressed bale of ferrous scrap: crushed strip texture, two straps; grade 1 orange straps and tag
static func _bale(ci, r: Rect2, grade: int) -> void:
	_shadow(ci, r, 84, 88, 56)
	var o := Vector2(38, 86)
	_box(ci, r, o, 70, 56, 30, Color(0.36, 0.37, 0.38))
	# the crushed strip on the front face
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 26:
		var y := 34.0 + rng.randf() * 50.0
		var x := 40.0 + rng.randf() * 60.0
		var len := 6.0 + rng.randf() * 12.0
		var tilt := rng.randf_range(-3.0, 3.0)
		var col := Color(0.24, 0.25, 0.27) if i % 3 else Color(0.5, 0.32, 0.2)
		_line(ci, r, Vector2(x, y), Vector2(minf(106.0, x + len), y + tilt), col, 1.6)
	for i in 10:
		var y2 := 34.0 + rng.randf() * 50.0
		var x2 := 42.0 + rng.randf() * 58.0
		_line(ci, r, Vector2(x2, y2), Vector2(x2 + 8, y2 - 1), Color(0.7, 0.72, 0.75, 0.7), 0.9)
	# two straps over top and front
	var sc := STRAP_G1 if grade >= 1 else STRAP
	for sx in [56.0, 90.0]:
		_line(ci, r, Vector2(sx, 30), Vector2(sx, 86), sc, 3.2)
		_line(ci, r, Vector2(sx, 30), Vector2(sx + 21, 16.5), sc, 3.2)
		_line(ci, r, Vector2(sx + 1, 30), Vector2(sx + 1, 86), sc.lightened(0.4), 0.8)
	if grade >= 1:
		# the passed tag on its wire
		_line(ci, r, Vector2(90, 40), Vector2(96, 50), Color(0.8, 0.8, 0.8), 0.8)
		_poly(ci, r, [Vector2(93, 50), Vector2(108, 50), Vector2(108, 62), Vector2(93, 62)], Color(0.96, 0.95, 0.9))
		_line(ci, r, Vector2(96, 54), Vector2(105, 54), Color(0.2, 0.6, 0.3), 1.6)
		_line(ci, r, Vector2(96, 58), Vector2(102, 58), Color(0.2, 0.2, 0.2), 1.0)


# a bulk bag of mixed non-ferrous: white woven body, cinched top, four loops, copper and aluminium
# showing at the open top
static func _bag(ci, r: Rect2) -> void:
	_shadow(ci, r, 80, 90, 46)
	# the copper wire and aluminium pieces in the opening
	_poly(ci, r, [Vector2(56, 26), Vector2(104, 26), Vector2(100, 34), Vector2(60, 34)], Color(0.2, 0.17, 0.14))
	for i in 5:
		ci.draw_arc(_p(r, Vector2(66 + i * 6, 29)), 4.0 * _k(r), PI, TAU, 10, Color(0.85, 0.48, 0.22), 1.6 * _k(r), true)
	_poly(ci, r, [Vector2(88, 24), Vector2(98, 22), Vector2(100, 30), Vector2(90, 31)], Color(0.82, 0.84, 0.87))
	# the body
	_shade(ci, r, [Vector2(52, 32), Vector2(108, 32), Vector2(116, 50), Vector2(114, 86), Vector2(46, 86), Vector2(44, 50)], Color(0.92, 0.93, 0.92), Color(0.62, 0.64, 0.64))
	# the weave and the seams
	for i in 6:
		_line(ci, r, Vector2(50, 44 + i * 7), Vector2(110, 44 + i * 7), Color(0.55, 0.57, 0.57, 0.45), 0.7)
	_line(ci, r, Vector2(80, 34), Vector2(80, 86), Color(0.5, 0.52, 0.52, 0.7), 1.0)
	# the four lifting loops
	for x in [52.0, 66.0, 94.0, 108.0]:
		ci.draw_arc(_p(r, Vector2(x, 32)), 5.0 * _k(r), PI, TAU, 12, Color(0.3, 0.45, 0.75), 2.6 * _k(r), true)
	# the label pocket
	_poly(ci, r, [Vector2(70, 56), Vector2(90, 56), Vector2(90, 70), Vector2(70, 70)], Color(0.98, 0.98, 0.96))
	_line(ci, r, Vector2(73, 61), Vector2(87, 61), Color(0.2, 0.2, 0.2), 1.2)
	_line(ci, r, Vector2(73, 65), Vector2(83, 65), Color(0.4, 0.4, 0.4), 1.0)


# a bundle of square billets: end faces with flame-cut texture, three layers, two straps; the
# grade sprayed on the ends
# a stack of cast ingots from the berth furnace: tapered (wider at the base), crossed in layers,
# the mould's dimpled top, a dark skin with a blued sheen
static func _ingots(ci, r: Rect2) -> void:
	_shadow(ci, r, 80, 88, 62)
	var dx := Vector2(40, -24)
	for layer in 3:
		var n := 3 if layer < 2 else 2
		for col in n:
			var w := 18.0
			var h := 11.0
			var o := Vector2(34 + col * (w + 3.0) + (10.0 if layer == 2 else 0.0) + (5.0 if layer == 1 else 0.0), 87 - layer * (h + 1.0))
			var taper := 2.5
			# the long top (narrower than the base: a mould's draft), the right side, the front end
			_shade(ci, r, [o + Vector2(taper, -h), o + Vector2(taper, -h) + dx, o + Vector2(w - taper, -h) + dx, o + Vector2(w - taper, -h)], Color(0.46, 0.48, 0.54), Color(0.36, 0.38, 0.44))
			_shade(ci, r, [o + Vector2(w - taper, -h), o + Vector2(w - taper, -h) + dx, o + Vector2(w, 0) + dx, o + Vector2(w, 0)], Color(0.24, 0.25, 0.29), Color(0.15, 0.16, 0.19))
			_shade(ci, r, [o + Vector2(taper, -h), o + Vector2(w - taper, -h), o + Vector2(w, 0), o], Color(0.4, 0.37, 0.36), Color(0.27, 0.25, 0.25))
			# the dimple the shrinking metal leaves on top, and a pour lip
			_line(ci, r, o + Vector2(w * 0.5, -h) + dx * 0.35, o + Vector2(w * 0.5, -h) + dx * 0.65, Color(0.25, 0.26, 0.3, 0.9), 1.4)
			_line(ci, r, o + Vector2(taper + 1.0, -h + 1.0), o + Vector2(w - taper - 1.0, -h + 1.0), Color(0.62, 0.64, 0.7, 0.8), 0.8)
	# the cast heat number on the front ingot
	ci.draw_string(Fonts.get_font("Medium"), _p(r, Vector2(38, 84)), "BERTH 07", HORIZONTAL_ALIGNMENT_LEFT, -1, int(6.0 * _k(r)), Color(0.85, 0.85, 0.88, 0.8))


static func _billets(ci, r: Rect2, grade: int) -> void:
	_shadow(ci, r, 84, 88, 60)
	var s := 16.0
	var dx := Vector2(48, -30)
	for layer in 3:
		for col in 3 - (1 if layer == 2 else 0):
			var o := Vector2(30 + col * s + (s * 0.5 if layer == 2 else 0.0), 86 - layer * s)
			# the long side (top and right), then the cut end in front
			_shade(ci, r, [o + Vector2(0, -s), o + Vector2(0, -s) + dx, o + Vector2(s, -s) + dx, o + Vector2(s, -s)], Color(0.62, 0.64, 0.67), Color(0.48, 0.5, 0.53))
			_shade(ci, r, [o + Vector2(s, -s), o + Vector2(s, -s) + dx, o + Vector2(s, 0) + dx, o + Vector2(s, 0)], Color(0.32, 0.33, 0.35), Color(0.2, 0.21, 0.22))
			_shade(ci, r, [o + Vector2(0, -s), o + Vector2(s, -s), o + Vector2(s, 0), o], Color(0.55, 0.5, 0.46), Color(0.38, 0.33, 0.3))
			# flame-cut drag lines on the end
			for k in 3:
				_line(ci, r, o + Vector2(3, -s + 4 + k * 4), o + Vector2(s - 3, -s + 5 + k * 4), Color(0.3, 0.24, 0.2, 0.8), 0.7)
	# the sprayed grade on the front ends
	var mark := Color(1.0, 0.54, 0.31) if grade >= 1 else Color(0.9, 0.9, 0.9)
	ci.draw_string(Fonts.get_font("Medium"), _p(r, Vector2(34, 82)), "G%d" % grade, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 * _k(r)), mark)
	# two straps around the bundle: across the top of the lower layers and down the side
	var sc := STRAP_G1 if grade >= 1 else STRAP
	for t in [0.3, 0.75]:
		var off: Vector2 = dx * float(t)
		_line(ci, r, Vector2(30, 54) + off, Vector2(78, 54) + off, sc, 3.0)
		_line(ci, r, Vector2(78, 54) + off, Vector2(78, 86) + off, sc, 3.0)
		_line(ci, r, Vector2(30, 54) + off, Vector2(30, 56) + off, sc, 3.0)
