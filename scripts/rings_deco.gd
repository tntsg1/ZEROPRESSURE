extends RefCounted
# ARK-01 侧挂转轮的舱内装饰（drawing only, nothing to cut or take off）: what fills the wheels' decks,
# corridors, spokes and housing drawn as silhouettes, so that seen whole (the art of the real
# equipment faded out that far) a wheel reads as lived in. Drawn once into a turning node
# (scripts/rings_fx.gd); faint when the camera is close and the real equipment shows.
#   A (habitat), its three decks outer to inner: cabins (bunks two high, lockers, desks, shelves),
#     the mess and wash rooms (shower and toilet stalls, tables and benches, the galley), life
#     support (cabinets with vents, tanks, a pipe run under the ceiling dropping to them)
#   B (farm): the hydroponic racks four tiers high with plants on each and grow lights over them,
#     nutrient tanks and their pipes, the cold store's shelving and its compressors
#   every deck: a light strip under its ceiling; the modules' plating: seams and a lit outer edge
#   the rim corridors: handrail, a pipe bundle, doors at the modules; the spokes: the lift shaft,
#     its car and cables; the housing (still): the bearing's races, the slip ring, the airlock doors
# Built as two lists (lines: segments and colours; fills: triangles and colours) in the ship
# file's metres for the wheel at 0°.

const LINE := Color(0.82, 0.84, 0.88)
const BLOCK := Color(0.165, 0.17, 0.19)
const BLOCK2 := Color(0.22, 0.225, 0.245)
const LAMP := Color(1.0, 0.86, 0.62)
const GAIN := 1.7               # the strokes are one screen pixel (hairlines): drawn stronger

var segs := PackedVector2Array()
var cols := PackedColorArray()
var tri := PackedVector2Array()
var tcol := PackedColorArray()
var M := 48.0
# the band being drawn: x0..x1 along it, its floor (y, metres) and which way is up from it
var _fl := 0.0
var _up := 1.0


func _p(x: float, h: float) -> Vector2:
	return Vector2(x, _fl + _up * h) * M


func ln(x0: float, h0: float, x1: float, h1: float, a: float, c: Color = LINE) -> void:
	segs.append(_p(x0, h0))
	segs.append(_p(x1, h1))
	cols.append(Color(c.r, c.g, c.b, minf(a * GAIN, 0.95)))


func box(x0: float, h0: float, x1: float, h1: float, a: float, fill: Color = BLOCK) -> void:
	var p0 := _p(x0, h0)
	var p1 := _p(x1, h0)
	var p2 := _p(x1, h1)
	var p3 := _p(x0, h1)
	tri.append_array(PackedVector2Array([p0, p1, p2, p0, p2, p3]))
	for i in 6:
		tcol.append(fill)
	ln(x0, h0, x1, h0, a)
	ln(x1, h0, x1, h1, a)
	ln(x1, h1, x0, h1, a)
	ln(x0, h1, x0, h0, a)


# world-space helpers (metres) for the round things
func wseg(a: Vector2, b: Vector2, al: float, c: Color = LINE) -> void:
	segs.append(a * M)
	segs.append(b * M)
	cols.append(Color(c.r, c.g, c.b, minf(al * GAIN, 0.95)))


func warc(c: Vector2, r: float, a0: float, a1: float, n: int, al: float, col: Color = LINE) -> void:
	for i in n:
		var t0 := lerpf(a0, a1, float(i) / n)
		var t1 := lerpf(a0, a1, float(i + 1) / n)
		wseg(c + Vector2.from_angle(t0) * r, c + Vector2.from_angle(t1) * r, al, col)


# ---------------------------------------------------------------- the decks

func band(ring: String, deck: int, x0: float, x1: float, fl: float, up: float, hh: float, room: String) -> void:
	_fl = fl
	_up = up
	# the light strip under the ceiling, in short lamps
	var x := x0 + 0.6
	while x < x1 - 1.0:
		ln(x, hh - 0.18, x + 0.9, hh - 0.18, 0.55, LAMP)
		x += 1.6
	ln(x0, hh - 0.32, x1, hh - 0.32, 0.12)
	if room == "CS":
		_cold_store(x0, x1, hh)
		return
	if ring == "A":
		match deck:
			0: _cabins(x0, x1, hh)
			1: _mess(x0, x1, hh)
			_: _life_support(x0, x1, hh)
	else:
		match deck:
			0: _hydroponics(x0, x1, hh)
			1: _nutrients(x0, x1, hh)
			_: _cold_store(x0, x1, hh)


func _cabins(x0: float, x1: float, hh: float) -> void:
	var x := x0 + 0.4
	while x + 6.2 < x1:
		ln(x, 0.0, x, hh - 0.35, 0.32)                     # the partition
		ln(x + 0.05, 2.25, x + 0.05, 2.25 + 0.1, 0.3)
		# bunks two high, posts and a ladder
		box(x + 0.35, 0.45, x + 2.45, 0.75, 0.45, BLOCK2)
		box(x + 0.35, 1.75, x + 2.45, 2.05, 0.45, BLOCK2)
		ln(x + 0.5, 0.75, x + 1.1, 0.95, 0.3)               # pillows
		ln(x + 0.5, 2.05, x + 1.1, 2.25, 0.3)
		ln(x + 0.35, 0.0, x + 0.35, 2.6, 0.35)
		ln(x + 2.45, 0.0, x + 2.45, 2.6, 0.35)
		for k in 6:
			ln(x + 2.55, 0.3 + k * 0.38, x + 2.85, 0.3 + k * 0.38, 0.28)
		ln(x + 2.55, 0.0, x + 2.55, 2.4, 0.3)
		ln(x + 2.85, 0.0, x + 2.85, 2.4, 0.3)
		# a locker, a desk with its lamp and chair, shelves over it
		box(x + 3.1, 0.0, x + 3.95, 2.0, 0.42)
		ln(x + 3.52, 0.1, x + 3.52, 1.9, 0.3)
		box(x + 4.2, 0.72, x + 5.7, 0.82, 0.4, BLOCK2)
		ln(x + 4.3, 0.0, x + 4.3, 0.72, 0.3)
		ln(x + 5.6, 0.0, x + 5.6, 0.72, 0.3)
		box(x + 4.5, 0.0, x + 4.95, 0.5, 0.3)
		ln(x + 5.3, 0.82, x + 5.45, 1.25, 0.35)
		for k in 3:
			ln(x + 4.2, 1.5 + k * 0.45, x + 5.7, 1.5 + k * 0.45, 0.3)
			box(x + 4.3 + k * 0.4, 1.5 + k * 0.45, x + 4.6 + k * 0.4, 1.85 + k * 0.45, 0.25)
		x += 6.5


func _mess(x0: float, x1: float, hh: float) -> void:
	var w := x1 - x0
	# wash rooms: shower and toilet stalls
	var x := x0 + 0.4
	var end_wash := x0 + w * 0.3
	var k := 0
	while x + 1.1 < end_wash:
		box(x, 0.0, x + 1.1, 2.2, 0.4)
		ln(x + 0.15, 0.1, x + 0.15, 2.0, 0.25)
		if k % 2 == 0:
			ln(x + 0.55, 2.0, x + 0.55, 1.8, 0.4)          # the shower head
			for j in 4:
				ln(x + 0.4 + j * 0.1, 1.7, x + 0.38 + j * 0.1, 1.2, 0.15)
		else:
			box(x + 0.35, 0.0, x + 0.8, 0.45, 0.35, BLOCK2)  # the pan
		x += 1.25
		k += 1
	# tables and benches
	x = end_wash + 0.8
	var end_mess := x0 + w * 0.72
	while x + 2.8 < end_mess:
		box(x + 0.4, 0.75, x + 2.4, 0.85, 0.45, BLOCK2)
		ln(x + 0.6, 0.0, x + 0.6, 0.75, 0.3)
		ln(x + 2.2, 0.0, x + 2.2, 0.75, 0.3)
		box(x, 0.4, x + 0.3, 0.48, 0.3)
		box(x + 2.5, 0.4, x + 2.8, 0.48, 0.3)
		for j in 3:
			box(x + 0.7 + j * 0.55, 0.85, x + 0.95 + j * 0.55, 0.95, 0.3)  # trays
		x += 3.4
	# the galley: counter, cabinets over it, hood
	box(end_mess + 0.4, 0.0, x1 - 0.4, 0.95, 0.42, BLOCK2)
	x = end_mess + 0.5
	while x + 0.9 < x1 - 0.4:
		ln(x, 0.1, x, 0.85, 0.25)
		box(x, 1.6, x + 0.85, 2.3, 0.35)
		x += 0.95
	ln(end_mess + 0.4, 1.05, x1 - 0.4, 1.05, 0.3)


func _life_support(x0: float, x1: float, hh: float) -> void:
	var x := x0 + 0.5
	var k := 0
	var drops: Array = []
	while x + 1.4 < x1:
		if k % 3 == 2:
			# a tank: round ends, a band and a gauge
			box(x, 0.2, x + 1.2, 2.3, 0.42, BLOCK2)
			ln(x, 0.6, x + 1.2, 0.6, 0.3)
			ln(x, 1.9, x + 1.2, 1.9, 0.3)
			box(x + 0.45, 1.2, x + 0.75, 1.5, 0.35)
			x += 1.5
		else:
			box(x, 0.0, x + 1.0, 2.4, 0.42)
			for j in 6:
				ln(x + 0.15, 1.5 + j * 0.13, x + 0.85, 1.5 + j * 0.13, 0.25)
			box(x + 0.2, 0.4, x + 0.5, 0.7, 0.3, BLOCK2)
			x += 1.25
		drops.append(x - 0.6)
		k += 1
	# the pipe run under the ceiling, dropping to every second one
	for j in 3:
		ln(x0 + 0.3, hh - 0.75 - j * 0.2, x1 - 0.3, hh - 0.75 - j * 0.2, 0.35)
	for i in drops.size():
		if i % 2 == 0:
			ln(drops[i], hh - 1.15, drops[i], 2.4, 0.28)


func _hydroponics(x0: float, x1: float, hh: float) -> void:
	var x := x0 + 0.4
	var tiers := 4
	var top: float = minf(hh - 0.6, 4.6)
	while x + 3.0 < x1:
		ln(x, 0.0, x, top, 0.35)
		ln(x + 3.0, 0.0, x + 3.0, top, 0.35)
		for t in tiers:
			var h: float = 0.35 + t * (top - 0.35) / tiers
			box(x, h, x + 3.0, h + 0.12, 0.38, BLOCK2)
			# the plants on the tier
			var px := x + 0.15
			while px < x + 2.85:
				var ph := 0.25 + 0.12 * float(int(px * 7.0) % 3)
				ln(px, h + 0.12, px - 0.08, h + 0.12 + ph, 0.45)
				ln(px, h + 0.12, px + 0.09, h + 0.12 + ph * 0.8, 0.4)
				px += 0.32
			# its grow light
			var lh: float = h + (top - 0.35) / tiers - 0.12
			ln(x + 0.2, lh, x + 2.8, lh, 0.6, LAMP)
		x += 3.4


func _nutrients(x0: float, x1: float, hh: float) -> void:
	var x := x0 + 0.5
	var k := 0
	var tops: Array = []
	while x + 1.8 < x1:
		if k % 4 == 3:
			# a processing bench with its crates
			box(x, 0.8, x + 2.2, 0.9, 0.4, BLOCK2)
			ln(x + 0.1, 0.0, x + 0.1, 0.8, 0.3)
			ln(x + 2.1, 0.0, x + 2.1, 0.8, 0.3)
			box(x + 0.3, 0.0, x + 0.9, 0.5, 0.3)
			box(x + 1.2, 0.9, x + 1.8, 1.3, 0.3)
			x += 2.6
		else:
			box(x, 0.0, x + 1.6, 2.6, 0.42, BLOCK2)
			ln(x, 1.1 + 0.2 * (k % 3), x + 1.6, 1.1 + 0.2 * (k % 3), 0.45)   # the level
			box(x + 0.6, 2.6, x + 1.0, 2.9, 0.35)
			tops.append(x + 0.8)
			x += 2.0
		k += 1
	ln(x0 + 0.3, 3.2, x1 - 0.3, 3.2, 0.38)
	ln(x0 + 0.3, 3.4, x1 - 0.3, 3.4, 0.3)
	for t in tops:
		ln(t, 2.9, t, 3.2, 0.35)


func _cold_store(x0: float, x1: float, hh: float) -> void:
	var x := x0 + 0.4
	var k := 0
	while x + 2.4 < x1:
		if k % 4 == 3:
			# a compressor: casing and its fan
			box(x, 0.0, x + 1.8, 1.4, 0.42, BLOCK2)
			var c := Vector2(x + 0.9, 0.7)
			for j in 8:
				var a := TAU * j / 8.0
				ln(c.x + cos(a) * 0.5, c.y + sin(a) * 0.5, c.x + cos(a + TAU / 8.0) * 0.5, c.y + sin(a + TAU / 8.0) * 0.5, 0.35)
			ln(c.x - 0.4, c.y, c.x + 0.4, c.y, 0.3)
			x += 2.2
		else:
			# shelving: three shelves, crates on them
			ln(x, 0.0, x, 2.6, 0.35)
			ln(x + 2.0, 0.0, x + 2.0, 2.6, 0.35)
			for s in 3:
				var h := 0.1 + s * 0.85
				ln(x, h, x + 2.0, h, 0.35)
				box(x + 0.1, h, x + 0.7, h + 0.5, 0.3)
				box(x + 0.8, h, x + 1.3, h + 0.6, 0.3)
				if (k + s) % 2 == 0:
					box(x + 1.4, h, x + 1.9, h + 0.45, 0.3)
			x += 2.4
		k += 1


# the plating's seams and the lit outer edge of a module (its outer wall at y0, inward up)
func plating(x0: float, x1: float, y_out: float, up: float) -> void:
	_fl = y_out
	_up = up
	var x := x0
	while x < x1:
		ln(x, -0.6, x, 0.0, 0.3)
		x += 2.0
	ln(x0, -0.62, x1, -0.62, 0.55)


# a rim corridor: the truss's arc about the hub (radius rt, from a0 to a1, metres)
func corridor(hub: Vector2, rt: float, a0: float, a1: float) -> void:
	var n := 18
	warc(hub, rt - 1.7, a0, a1, n, 0.35)        # handrail
	for k in n:
		var a := lerpf(a0, a1, (k + 0.5) / n)
		wseg(hub + Vector2.from_angle(a) * (rt - 1.7), hub + Vector2.from_angle(a) * (rt - 1.35), 0.25)
	for j in 3:
		warc(hub, rt + 1.35 + j * 0.22, a0, a1, n, 0.32)   # the pipe bundle
	for a in [a0, a1]:
		var u := Vector2.from_angle(a)
		var t := u.orthogonal()
		var c: Vector2 = hub + u * rt
		# a door at the module
		for s in [-1.0, 1.0]:
			wseg(c + t * 0.15 * s - u * 1.1, c + t * 0.15 * s + u * 1.1, 0.5)
		wseg(c - u * 1.1 - t * 0.15, c - u * 1.1 + t * 0.15, 0.5)
		wseg(c + u * 1.1 - t * 0.15, c + u * 1.1 + t * 0.15, 0.5)


# a spoke (its room's box, metres): the lift shaft, its car, cables, ladder rungs
func spoke(r: Rect2, vertical: bool) -> void:
	if vertical:
		var cx := r.get_center().x
		for s in [-0.45, 0.45]:
			wseg(Vector2(cx + s, r.position.y), Vector2(cx + s, r.end.y), 0.4)
		wseg(Vector2(cx - 0.1, r.position.y), Vector2(cx - 0.1, r.end.y), 0.22)
		wseg(Vector2(cx + 0.1, r.position.y), Vector2(cx + 0.1, r.end.y), 0.22)
		var cy := r.get_center().y
		for s in [-0.6, 0.6]:
			wseg(Vector2(cx - 0.4, cy + s), Vector2(cx + 0.4, cy + s), 0.5)
		wseg(Vector2(cx - 0.4, cy - 0.6), Vector2(cx - 0.4, cy + 0.6), 0.5)
		wseg(Vector2(cx + 0.4, cy - 0.6), Vector2(cx + 0.4, cy + 0.6), 0.5)
		var y := r.position.y + 0.3
		while y < r.end.y:
			wseg(Vector2(r.position.x + 0.1, y), Vector2(r.position.x + 0.35, y), 0.28)
			y += 0.4


# the still housing: the bearing's races, the slip ring's bands, the airlock doors on its faces
func housing(c: Vector2, rad: float, faces: Array) -> void:
	for k in 4:
		warc(c, rad * (0.55 + 0.15 * k), 0.0, TAU, 40, 0.3 + 0.08 * (k % 2))
	for k in 12:
		var a := TAU * k / 12.0
		wseg(c + Vector2.from_angle(a) * rad * 0.55, c + Vector2.from_angle(a) * rad * 0.7, 0.25)
	for k in 3:
		warc(c, rad * (1.12 + 0.07 * k), 0.0, TAU, 48, 0.4, LAMP if k == 1 else LINE)
	for f in faces:
		var p: Vector2 = f[0]
		var n: Vector2 = f[1]
		var t := n.orthogonal()
		var q := p + n * 0.2
		wseg(q - t * 0.9, q + t * 0.9, 0.55)
		wseg(q - t * 0.9 + n * 1.9, q + t * 0.9 + n * 1.9, 0.55)
		wseg(q - t * 0.9, q - t * 0.9 + n * 1.9, 0.55)
		wseg(q + t * 0.9, q + t * 0.9 + n * 1.9, 0.55)
		wseg(q + n * 0.95 - t * 0.3, q + n * 0.95 + t * 0.3, 0.4, LAMP)


func draw_into(ci: CanvasItem) -> void:
	if not tri.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), tri, tcol)
	if not segs.is_empty():
		# hairlines: one screen pixel at every zoom (a 1 px world line is a dotted ghost seen whole)
		ci.draw_multiline_colors(segs, cols, -1.0)
