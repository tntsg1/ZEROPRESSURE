class_name FarVista
extends RefCounted
# 118 号 层次纵深 Q2 A (user 2026-11-04 "按你的推荐"): what lies far beyond the berth — other
# yards' great structures, ships moored at them, their blinking navigation lights and now and
# then a ship's lights crossing slowly. Pure scenery, behind everything but the stars and the
# planet: one band of silhouettes in screen pixels (far things keep their size whatever the
# zoom), sliding at a fiftieth of the camera, repeating along its length. Built once.
# Drawn by the backdrop (the berth) and by the opening's cards, the same band.

const W := 7600.0                      # px: the band's length before it repeats
const PAR := 0.012                     # of the camera's travel (the belt's nearest rocks: 0.09)
const FILL := Color(0.024, 0.027, 0.034)
const FILL_HI := Color(0.036, 0.04, 0.05)
const RIM := Color(0.085, 0.093, 0.115)
const WIN := Color(0.15, 0.165, 0.2)
const WARM := Color(0.34, 0.21, 0.11)
const RED := Color(1.5, 0.22, 0.16)
const WHITE := Color(1.3, 1.35, 1.45)

static var on := true                  # tests: before / after
static var _tp := PackedVector2Array()
static var _tc := PackedColorArray()
static var _lp := PackedVector2Array()
static var _lc := PackedColorArray()
static var _blink: Array = []          # [pos, colour, period s, phase, size px]
static var _movers: Array = []         # [y, speed px/s, start x]
static var _built := false


static func _tri_poly(pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	for k in idx:
		var v := pts[k]
		_tp.append(v)
		_tc.append(top.lerp(bottom, clampf((v.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)))


static func _rect(r: Rect2, top: Color = FILL_HI, bottom: Color = FILL) -> void:
	_tri_poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), top, bottom)


static func _line(a: Vector2, b: Vector2, c: Color = RIM) -> void:
	_lp.append(a)
	_lp.append(b)
	_lc.append(c)


# the edges facing the light (up and to the left) catch it
static func _rim(pts: PackedVector2Array, c: Color = RIM) -> void:
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := (b - a).orthogonal().normalized()
		if -n.dot(Look.LIGHT_DIR) > 0.2:
			_line(a, b, c)


static func _windows(a: Vector2, b: Vector2, step: float, rng: RandomNumberGenerator, lit: float = 0.55) -> void:
	var n := int(a.distance_to(b) / step)
	for i in n:
		if rng.randf() > lit:
			continue
		var p := a.lerp(b, (i + 0.5) / maxf(n, 1))
		var c := WARM if rng.randf() < 0.18 else WIN
		_rect(Rect2(p - Vector2(1.5, 1.0), Vector2(3.0, 2.0)), c, c)


# a ship lying at rest: blunt bow to the left, a bridge block, engine bells at the stern
static func _ship(c: Vector2, l: float, h: float, rng: RandomNumberGenerator) -> void:
	var hull := PackedVector2Array([c + Vector2(-l * 0.5, 0), c + Vector2(-l * 0.5 + h * 0.9, -h * 0.5), c + Vector2(l * 0.5 - h * 0.3, -h * 0.5),
		c + Vector2(l * 0.5, -h * 0.25), c + Vector2(l * 0.5, h * 0.25), c + Vector2(l * 0.5 - h * 0.3, h * 0.5), c + Vector2(-l * 0.5 + h * 0.9, h * 0.5)])
	_tri_poly(hull, FILL_HI, FILL)
	_rim(hull)
	var br := Rect2(c + Vector2(l * 0.12, -h * 0.5 - h * 0.42), Vector2(l * 0.16, h * 0.42))
	_rect(br)
	_line(br.position, Vector2(br.end.x, br.position.y))
	_line(br.position, Vector2(br.position.x, br.end.y))
	_windows(br.position + Vector2(4, h * 0.14), Vector2(br.end.x - 4, br.position.y + h * 0.14), 7.0, rng, 0.8)
	for k in 3:
		var ey := c.y + (k - 1) * h * 0.28
		var bell := PackedVector2Array([c + Vector2(l * 0.5, ey - c.y - h * 0.1), c + Vector2(l * 0.5 + h * 0.4, ey - c.y - h * 0.16),
			c + Vector2(l * 0.5 + h * 0.4, ey - c.y + h * 0.16), c + Vector2(l * 0.5, ey - c.y + h * 0.1)])
		_tri_poly(bell, FILL, FILL)
	# plating seams
	var sx := -l * 0.5 + h * 1.4
	while sx < l * 0.5 - h * 0.6:
		_line(c + Vector2(sx, -h * 0.5), c + Vector2(sx, h * 0.5), Color(RIM, 0.45))
		sx += l * rng.randf_range(0.08, 0.14)
	_windows(c + Vector2(-l * 0.5 + h * 1.2, -h * 0.12), c + Vector2(l * 0.5 - h * 0.6, -h * 0.12), 9.0, rng, 0.35)
	_blink.append([c + Vector2(-l * 0.5, 0), RED, rng.randf_range(1.8, 2.6), rng.randf(), 2.2])
	_blink.append([c + Vector2(l * 0.5 - h * 0.3, -h * 0.5), WHITE, rng.randf_range(2.4, 3.2), rng.randf(), 1.8])


# a lattice mast with its arms, its warning light on top
static func _tower(x: float, top: float, bottom: float, rng: RandomNumberGenerator) -> void:
	var w := 30.0
	_rect(Rect2(x - w * 0.5, top, w, bottom - top))
	_line(Vector2(x - w * 0.5, top), Vector2(x - w * 0.5, bottom))
	_line(Vector2(x - w * 0.5, top), Vector2(x + w * 0.5, top))
	var y := top + 6.0
	var flip := false
	while y < bottom - 24.0:
		_line(Vector2(x - w * 0.5 if flip else x + w * 0.5, y), Vector2(x + w * 0.5 if flip else x - w * 0.5, y + 24.0), Color(RIM, 0.55))
		y += 24.0
		flip = not flip
	for arm in [[top + 70.0, 300.0], [top + 210.0, 190.0]]:
		var ay: float = arm[0]
		var al: float = arm[1]
		_rect(Rect2(x - al * 0.5, ay, al, 10.0))
		_line(Vector2(x - al * 0.5, ay), Vector2(x + al * 0.5, ay))
		_line(Vector2(x, ay - 40.0), Vector2(x - al * 0.5, ay), Color(RIM, 0.5))
		_line(Vector2(x, ay - 40.0), Vector2(x + al * 0.5, ay), Color(RIM, 0.5))
		_blink.append([Vector2(x - al * 0.5, ay + 5.0), RED, rng.randf_range(1.6, 2.4), rng.randf(), 1.8])
		_blink.append([Vector2(x + al * 0.5, ay + 5.0), RED, rng.randf_range(1.6, 2.4), rng.randf(), 1.8])
	var pod := Rect2(x - 70.0, bottom - 150.0, 140.0, 64.0)
	_rect(pod)
	_line(pod.position, Vector2(pod.end.x, pod.position.y))
	_windows(pod.position + Vector2(8, 18), Vector2(pod.end.x - 8, pod.position.y + 18), 8.0, rng)
	_windows(pod.position + Vector2(8, 38), Vector2(pod.end.x - 8, pod.position.y + 38), 8.0, rng, 0.3)
	_blink.append([Vector2(x, top - 4.0), RED, 2.0, rng.randf(), 2.6])


# a dry dock: a frame of beams with a ship inside it and a gantry over it
static func _drydock(x: float, y: float, rng: RandomNumberGenerator) -> void:
	var r := Rect2(x - 420.0, y - 120.0, 840.0, 250.0)
	_rect(Rect2(r.position, Vector2(r.size.x, 18.0)))
	_rect(Rect2(Vector2(r.position.x, r.end.y - 18.0), Vector2(r.size.x, 18.0)))
	_line(r.position, Vector2(r.end.x, r.position.y))
	_line(Vector2(r.position.x, r.end.y - 18.0), Vector2(r.end.x, r.end.y - 18.0))
	for k in 6:
		var bx := r.position.x + k * r.size.x / 5.0 - (14.0 if k == 5 else 0.0)
		_rect(Rect2(bx, r.position.y, 14.0, r.size.y), FILL, FILL)
		_line(Vector2(bx, r.position.y), Vector2(bx, r.end.y))
	_ship(Vector2(x - 10.0, y + 8.0), 640.0, 84.0, rng)
	var g := Rect2(x + 120.0, r.position.y - 70.0, 16.0, 70.0)
	_rect(g)
	_rect(Rect2(x - 60.0, r.position.y - 76.0, 260.0, 10.0))
	_line(Vector2(x - 60.0, r.position.y - 76.0), Vector2(x + 200.0, r.position.y - 76.0))
	_blink.append([Vector2(x + 200.0, r.position.y - 71.0), RED, 2.2, rng.randf(), 2.0])
	_blink.append([Vector2(r.position.x, r.position.y), WHITE, 3.0, rng.randf(), 1.6])
	_blink.append([Vector2(r.end.x, r.position.y), WHITE, 3.0, rng.randf(), 1.6])


# a great wheel of a station, only its upper arc above the band, spokes to a hub below
static func _ring(x: float, y: float, rng: RandomNumberGenerator) -> void:
	var c := Vector2(x, y + 560.0)
	var r := 600.0
	var th := 40.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var a0 := deg_to_rad(-158.0)
	var a1 := deg_to_rad(-22.0)
	for i in 49:
		var a := lerpf(a0, a1, i / 48.0)
		outer.append(c + Vector2.from_angle(a) * r)
		inner.append(c + Vector2.from_angle(a) * (r - th))
	for i in 48:
		_tri_poly(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), FILL_HI, FILL)
		if outer[i + 1].x < c.x + r * 0.3:
			_line(outer[i], outer[i + 1])
		if i % 3 == 0:
			_line(outer[i], inner[i], Color(RIM, 0.45))
		if i % 2 == 0 and rng.randf() < 0.7:
			var wp := c + Vector2.from_angle(lerpf(a0, a1, (i + 0.5) / 48.0)) * (r - th * 0.5)
			var wc := WARM if rng.randf() < 0.15 else WIN
			_rect(Rect2(wp - Vector2(1.5, 1.5), Vector2(3, 3)), wc, wc)
	for k in 5:
		var a := lerpf(a0, a1, (k + 0.5) / 5.0)
		_line(c + Vector2.from_angle(a) * (r - th), c + Vector2.from_angle(a) * 120.0, Color(RIM, 0.5))
	_blink.append([outer[0], RED, 2.4, rng.randf(), 2.2])
	_blink.append([outer[48], RED, 2.4, rng.randf(), 2.2])
	_blink.append([outer[24], WHITE, 3.4, rng.randf(), 2.0])


# a long spindle: a cylinder with radiator wings and docking arms, a ship moored under it
static func _spindle(x: float, y: float, rng: RandomNumberGenerator) -> void:
	var body := Rect2(x - 470.0, y - 30.0, 940.0, 60.0)
	_rect(body)
	_line(body.position, Vector2(body.end.x, body.position.y))
	_line(body.position, Vector2(body.position.x, body.end.y))
	var sx := body.position.x + 60.0
	while sx < body.end.x - 40.0:
		_line(Vector2(sx, body.position.y), Vector2(sx, body.end.y), Color(RIM, 0.4))
		sx += 70.0
	_windows(body.position + Vector2(20, 22), Vector2(body.end.x - 20, body.position.y + 22), 10.0, rng, 0.4)
	for k in 3:
		var wx := x - 300.0 + k * 300.0
		for s in [-1.0, 1.0]:
			var wing := Rect2(wx - 60.0, y - 30.0 - 190.0 if s < 0.0 else y + 30.0, 120.0, 190.0)
			_rect(wing, FILL, FILL)
			_line(wing.position, Vector2(wing.end.x, wing.position.y), Color(RIM, 0.7))
			var gy := wing.position.y + 24.0
			while gy < wing.end.y:
				_line(Vector2(wing.position.x, gy), Vector2(wing.end.x, gy), Color(RIM, 0.3))
				gy += 24.0
		_blink.append([Vector2(wx, y - 220.0), RED, rng.randf_range(1.8, 2.6), rng.randf(), 1.8])
	for e in [body.position.x, body.end.x]:
		_blink.append([Vector2(e, y), WHITE, 2.8, rng.randf(), 2.0])
	_line(Vector2(x + 180.0, y + 30.0), Vector2(x + 180.0, y + 250.0))
	_ship(Vector2(x + 140.0, y + 290.0), 420.0, 62.0, rng)


static func _build() -> void:
	_built = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 118
	_tower(500.0, -560.0, 220.0, rng)
	_ship(Vector2(1180.0, 150.0), 360.0, 54.0, rng)
	_drydock(2150.0, -40.0, rng)
	_ring(3800.0, -120.0, rng)
	_ship(Vector2(4700.0, -300.0), 470.0, 66.0, rng)
	_spindle(5750.0, -120.0, rng)
	_tower(6950.0, -420.0, 160.0, rng)
	_ship(Vector2(7300.0, 260.0), 300.0, 46.0, rng)
	_movers = [[-430.0, 21.0, 0.0], [70.0, -14.0, 2600.0], [330.0, 28.0, 5200.0]]


# The band drawn across a view w px wide: `base` takes its pixels to the canvas item's own (the
# backdrop's world; identity for a screen-space Control), xoff slides it, y is its middle.
static func draw(ci: CanvasItem, base: Transform2D, xoff: float, y: float, w: float, t: float) -> void:
	if not on or not Look.on:
		return
	if not _built:
		_build()
	var rid := ci.get_canvas_item()
	var x0 := fposmod(xoff, W) - W
	while x0 < w:
		if x0 + W > 0.0:
			ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(x0, y)))
			RenderingServer.canvas_item_add_triangle_array(rid, PackedInt32Array(), _tp, _tc)
			ci.draw_multiline_colors(_lp, _lc, -1.0)
			# the navigation lights: a short flash each period
			for b in _blink:
				var p: Vector2 = b[0]
				if x0 + p.x < -20.0 or x0 + p.x > w + 20.0:
					continue
				var ph := fposmod(t / float(b[2]) + float(b[3]), 1.0)
				var k := 1.0 if ph < 0.09 else 0.0
				var c: Color = b[1]
				var s: float = b[4]
				ci.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(c.r, c.g, c.b, 0.18 + 0.82 * k))
				if k > 0.0:
					ci.draw_rect(Rect2(p - Vector2(s, s) * 1.6, Vector2(s, s) * 3.2), Color(c.r, c.g, c.b, 0.16))
			# ships under way, far off: a white light leading, a red one behind, a faint wake
			for m in _movers:
				var mx := fposmod(float(m[2]) + t * float(m[1]), W)
				if x0 + mx < -60.0 or x0 + mx > w + 60.0:
					continue
				var dirx := signf(float(m[1]))
				var p := Vector2(mx, float(m[0]))
				ci.draw_line(p - Vector2(dirx * 70.0, 0.0), p - Vector2(dirx * 8.0, 0.0), Color(0.5, 0.55, 0.65, 0.12), 1.0)
				ci.draw_rect(Rect2(p - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), WHITE)
				ci.draw_rect(Rect2(p - Vector2(dirx * 7.0 + 1.0, 1.0), Vector2(2.0, 2.0)), Color(RED, 0.4 + 0.6 * float(fposmod(t * 0.7 + float(m[2]), 1.0) < 0.12)))
		x0 += W
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
