extends RefCounted
# 98 号: the trade port drawn as the place it is (user 2026-10-28: as fine as the tug station,
# "超级详细的精细化，硬核"). Still parts: one mesh per stage and level of detail; machines that
# move: meshes built once and placed each frame (scripts/mesh_pen.gd); the board's and the
# counters' words: the hall's slow layer, once a second. What moves and why: scripts/trade_works.gd.
# Box-local metres (60 × 28, floor at 26.8; the drone's door and the consoles in the west wall).

const MeshPen = preload("res://scripts/mesh_pen.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")
const TW = preload("res://scripts/trade_works.gd")
const TH = preload("res://scripts/trade_hall.gd")

const FLOOR := 26.8
const BOARD := Rect2(18.0, 0.5, 36.0, 5.9)
const DUCT_Y := 6.75
const FACE := Color(0.118, 0.124, 0.136)
const FACE2 := Color(0.15, 0.158, 0.172)
const DARK := Color(0.06, 0.064, 0.072)
const VOID := Color(0.025, 0.027, 0.031)

var font: Font
var font_b: Font
var r := Rect2()
var m := 1.0
var _meshes := {}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ink(a: float) -> Color:
	return Pal.ink(a)


func _p(v: Vector2) -> Vector2:
	return r.position + v * m


func _lw(wm: float) -> float:
	return maxf(1.0, wm * m)


func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


func _put(ci: CanvasItem, mesh: ArrayMesh, at: Vector2, rot := 0.0, mod := Color.WHITE, flip := false) -> void:
	ci.draw_mesh(mesh, null, Transform2D(rot, Vector2(m * (-1.0 if flip else 1.0), m), 0.0, _p(at)), mod)


func _text(ci, at: Vector2, s: String, size_m: float, col: Color, b := false, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	ci.draw_string(font_b if b else font, _p(at), s, align, width_m * m if width_m > 0.0 else -1.0, int(size_m * m), col)


static func lamp_col(state: String, t: float) -> Color:
	match state:
		"ok": return Pal.tint(Pal.FLUID, 0.95, 1.3)
		"work": return Pal.heat(0.65 + 0.35 * absf(sin(t * 4.0)), 1.3)
		"warn": return Color(1.0, 0.3, 0.22, 0.6 + 0.4 * absf(sin(t * 2.5)))
	return Pal.ink(0.22)


func plate(ci: CanvasItem, at: Vector2, width: float, name: String, st: Array, t: float) -> void:
	var rr := Rect2(_p(at), Vector2(width, 0.9) * m)
	var lc := lamp_col(str(st[1]), t)
	if not Pal.labels:
		FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)
		return
	ci.draw_rect(rr, Color(0.02, 0.022, 0.026, 0.9))
	ci.draw_rect(Rect2(rr.position, Vector2(0.12 * m, rr.size.y)), lc)
	FastDraw.circle(ci, _p(at + Vector2(0.42, 0.45)), 0.15 * m, lc)
	_text(ci, at + Vector2(0.75, 0.64), name, 0.44, _ink(0.92))
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.44 * m)).x / m
	_text(ci, at + Vector2(1.1 + nw, 0.64), str(st[0]), 0.4, _ink(0.66), false, HORIZONTAL_ALIGNMENT_LEFT, width - nw - 1.3)


static func counter_x(i: int) -> float:
	return 20.0 + i * 12.0


# ================================================================== the still parts
func still(ci: CanvasItem, on: bool, lod: int) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0), false, 1.0)   # the layer's bounds (a mesh alone is culled near the origin)
	_put(ci, _mesh("still/%s/%d" % [on, lod], func(p): _still(p, on, lod)), Vector2.ZERO)


func _still(p, on: bool, lod: int) -> void:
	_board_frame(p, lod)
	for i in 3:
		_booth(p, i, on, lod)
	_duct(p, lod)
	_slab(p, lod)
	_locks(p, lod)
	_dock_frame(p, on, lod)


func _board_frame(p, lod: int) -> void:
	var b := BOARD
	p.rect(b.grow(0.25), FACE)
	p.rect(b, Color(0.03, 0.036, 0.042))
	p.rect(b.grow(0.25), _ink(0.6), false, 0.08)
	for hx in [b.position.x + 3.0, b.end.x - 3.0]:
		p.line(Vector2(hx, 0.0), Vector2(hx, b.position.y - 0.25), _ink(0.45), 0.1)
	if lod >= 1:
		# the bezel's screws, the panel seams of the LED wall
		for k in range(1, 6):
			p.line(Vector2(b.position.x + k * b.size.x / 6.0, b.position.y), Vector2(b.position.x + k * b.size.x / 6.0, b.end.y), Color(1, 1, 1, 0.025), 0.03)
		for c in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
			p.bolt(c + (b.get_center() - c).normalized() * 0.35, 0.06, _ink(0.5))


# a company's booth: its sign over the glass, the glass, the desk with its card reader, receipt
# printer and the tube terminal; the tube up to the duct
func _booth(p, i: int, on: bool, lod: int) -> void:
	var x0 := counter_x(i)
	var edge := _ink(0.65)
	p.rect(Rect2(x0 - 0.3, 6.9, 9.6, 0.7), FACE2)                       # the sign's frame
	p.rect(Rect2(x0 - 0.3, 6.9, 9.6, 0.7), edge, false, 0.05)
	p.rect(Rect2(x0, 7.6, 9.0, 1.2), Pal.tint(Pal.AIR, 0.07, 1.0))      # the glass
	for gx in [x0, x0 + 3.0, x0 + 6.0, x0 + 9.0]:
		p.line(Vector2(gx, 7.6), Vector2(gx, 8.8), _ink(0.5), 0.07)
	p.line(Vector2(x0 + 0.3, 7.8), Vector2(x0 + 1.4, 8.6), Color(1, 1, 1, 0.08), 0.05)   # a glint
	p.rect(Rect2(x0 - 0.2, 8.8, 9.4, 1.2), FACE)                        # the desk
	p.line(Vector2(x0 - 0.2, 8.8), Vector2(x0 + 9.2, 8.8), _ink(0.8), 0.1)
	if lod >= 1:
		var fx := x0 + 0.4
		while fx < x0 + 9.0:
			p.line(Vector2(fx, 9.0), Vector2(fx, 9.9), _ink(0.16), 0.03)
			fx += 0.5
	# the card reader, the receipt printer (its slot), the tube terminal
	p.rect(Rect2(x0 + 1.0, 8.45, 0.7, 0.35), FACE2)
	p.rect(Rect2(x0 + 1.05, 8.5, 0.25, 0.1), Pal.tint(Pal.FLUID, 0.7, 1.2) if on else _ink(0.2))
	p.rect(Rect2(x0 + 2.4, 8.35, 1.2, 0.45), FACE2)
	p.line(Vector2(x0 + 2.55, 8.42), Vector2(x0 + 3.45, 8.42), VOID, 0.06)
	p.rect(Rect2(x0 + 7.9, 8.1, 0.9, 0.7), FACE2)
	p.ring(Vector2(x0 + 8.35, 8.45), 0.24, edge, 0.05, 12)
	p.line(Vector2(x0 + 8.35, 8.1), Vector2(x0 + 8.35, DUCT_Y), _ink(0.5), 0.16)
	p.line(Vector2(x0 + 8.35, 8.1), Vector2(x0 + 8.35, DUCT_Y), Pal.tint(Pal.AIR, 0.12, 1.0), 0.08)


# the tube duct under the board, west to the port office over the door
func _duct(p, lod: int) -> void:
	p.line(Vector2(14.6, DUCT_Y), Vector2(counter_x(2) + 8.6, DUCT_Y), _ink(0.5), 0.18)
	p.line(Vector2(14.6, DUCT_Y), Vector2(counter_x(2) + 8.6, DUCT_Y), Pal.tint(Pal.AIR, 0.12, 1.0), 0.09)
	p.line(Vector2(14.6, DUCT_Y), Vector2(14.6, 0.0), _ink(0.5), 0.18)
	if lod >= 1:
		var x := 15.5
		while x < counter_x(2) + 8.6:
			p.rect(Rect2(x, DUCT_Y - 0.14, 0.08, 0.28), _ink(0.4))
			x += 2.4


# the hall floor: a slab over the dock, its grating, the visitors' cart rail, the handrail
func _slab(p, lod: int) -> void:
	var s := TW.SLAB
	p.rect(Rect2(TW.SLAB_X, s.x, 60.0 - TW.SLAB_X, s.y - s.x), FACE2)
	p.line(Vector2(TW.SLAB_X, s.x), Vector2(60.0, s.x), _ink(0.8), 0.09)
	p.line(Vector2(TW.SLAB_X, s.y), Vector2(60.0, s.y), _ink(0.5), 0.05)
	if lod >= 1:
		var x := TW.SLAB_X + 0.3
		while x < 60.0:
			p.line(Vector2(x, s.x + 0.1), Vector2(x, s.y - 0.1), _ink(0.18), 0.03)
			x += 0.45
	# the cart's rail and its stop by the business console
	p.line(Vector2(TW.SLAB_X + 0.6, s.x - 0.12), Vector2(57.6, s.x - 0.12), _ink(0.45), 0.08)
	p.rect(Rect2(TW.WAIT_X - 1.6, s.x - 0.35, 0.3, 0.35), Pal.heat(0.6, 1.0))
	# the slab's columns down through the dock (clear of the belt's stations)
	for cx in [22.0, 34.5, 45.0]:
		p.rect(Rect2(cx - 0.3, s.y, 0.6, FLOOR - s.y), FACE)
		p.line(Vector2(cx - 0.3, s.y), Vector2(cx - 0.3, FLOOR), _ink(0.4), 0.04)
	# the open west end's handrail
	p.line(Vector2(TW.SLAB_X, s.x - 1.0), Vector2(TW.SLAB_X + 0.6, s.x - 1.0), _ink(0.4), 0.05)
	p.line(Vector2(TW.SLAB_X + 0.1, s.x), Vector2(TW.SLAB_X + 0.1, s.x - 1.0), _ink(0.4), 0.05)


# the east wall: two airlocks for the visitors' ships, the cart lift down to the floor, the
# lighter's port below the slab
func _locks(p, lod: int) -> void:
	var edge := _ink(0.62)
	for lk: Vector2 in TW.LOCKS:
		p.rect(Rect2(58.8, lk.x - 0.3, 1.4, lk.y - lk.x + 0.6), FACE2)
		p.rect(Rect2(59.1, lk.x, 0.9, lk.y - lk.x), VOID)
		p.rect(Rect2(58.8, lk.x - 0.3, 1.4, lk.y - lk.x + 0.6), edge, false, 0.06)
		p.hatch(Rect2(58.85, lk.y, 1.3, 0.28), Pal.heat(0.55, 1.0), 0.08, 0.3)
		p.rect(Rect2(56.6, lk.y, 2.2, 0.25), FACE2)                       # its landing
		p.circle(Vector2(58.4, lk.x - 0.75), 0.18, _ink(0.3), 10)          # its lamp's housing
	# the cart lift's guides from the landings down to the floor
	for gx in [56.9, 58.1]:
		p.line(Vector2(gx, TW.LOCKS[0].x), Vector2(gx, TW.SLAB.x), _ink(0.4), 0.07)
	# the lighter's port
	var pt := TW.PORT
	p.rect(Rect2(58.6, pt.x - 0.5, 1.6, 0.5), FACE2)
	p.hatch(Rect2(58.7, pt.x - 0.42, 1.4, 0.34), Pal.heat(0.6, 1.0), 0.1, 0.36)
	p.line(Vector2(59.1, pt.x), Vector2(59.1, pt.y), Color(0.03, 0.03, 0.035), 0.16)
	if lod >= 1:
		var y := pt.x + 0.5
		while y < pt.y:
			p.bolt(Vector2(59.6, y), 0.06, _ink(0.45))
			y += 1.1


# the hand-over dock: the warehouse intake, the belt on its legs with its rollers, the
# weighbridge and its display post, the sealer's frame, the dock crane's girder and the bumpers
func _dock_frame(p, on: bool, lod: int) -> void:
	var edge := _ink(0.62)
	var by := TW.BELT_Y
	# the intake: a frame in the dock's west end with its roller door (drawn moving)
	p.rect(Rect2(TW.INTAKE_X - 1.4, by - 2.4, 1.4, 2.4 + (FLOOR - by)), FACE)
	p.rect(Rect2(TW.INTAKE_X - 1.1, by - 2.1, 1.1, 2.1), VOID)
	p.rect(Rect2(TW.INTAKE_X - 1.4, by - 2.4, 1.4, 2.4 + (FLOOR - by)), edge, false, 0.06)
	p.hatch(Rect2(TW.INTAKE_X - 1.35, by - 2.75, 1.3, 0.3), Pal.heat(0.55, 1.0), 0.08, 0.3)
	# the chute from the warehouse
	p.polyline(PackedVector2Array([Vector2(TW.INTAKE_X - 0.7, by - 2.4), Vector2(TW.INTAKE_X - 0.7, TW.SLAB.y + 0.6), Vector2(1.2, TW.SLAB.y + 0.6)]), Color(0.09, 0.095, 0.105), 0.34)
	p.polyline(PackedVector2Array([Vector2(TW.INTAKE_X - 0.7, by - 2.4), Vector2(TW.INTAKE_X - 0.7, TW.SLAB.y + 0.6), Vector2(1.2, TW.SLAB.y + 0.6)]), _ink(0.3), 0.06)
	# the belt: its frame, legs, the return strand
	p.rect(Rect2(TW.INTAKE_X, by, TW.BELT_END + 0.9 - TW.INTAKE_X, 0.42), FACE2)
	p.line(Vector2(TW.INTAKE_X, by), Vector2(TW.BELT_END + 0.9, by), _ink(0.75), 0.07)
	p.line(Vector2(TW.INTAKE_X + 0.2, by + 0.95), Vector2(TW.BELT_END + 0.7, by + 0.95), _ink(0.3), 0.05)
	var lx := TW.INTAKE_X + 1.2
	while lx < TW.BELT_END:
		p.line(Vector2(lx, by + 0.42), Vector2(lx - 0.25, FLOOR), _ink(0.4), 0.08)
		p.line(Vector2(lx, by + 0.42), Vector2(lx + 0.25, FLOOR), _ink(0.4), 0.08)
		lx += 4.0
	# the weighbridge: its plate on four load cells, the display post
	var wg := TW.WEIGH
	p.rect(Rect2(wg.x, by - 0.1, wg.y - wg.x, 0.18), Pal.tint(Pal.FLUID, 0.35, 1.0))
	for k in 4:
		p.rect(Rect2(wg.x + 0.3 + k * (wg.y - wg.x - 0.6) / 3.0 - 0.15, by + 0.42, 0.3, 0.3), _ink(0.55))
	p.rect(Rect2(wg.y + 0.4, by - 4.2, 0.25, 4.6), FACE)
	p.rect(Rect2(wg.y + 0.0, by - 5.4, 2.4, 1.3), FACE2)
	p.rect(Rect2(wg.y + 0.12, by - 5.28, 2.16, 1.06), Color(0.01, 0.025, 0.02))
	p.rect(Rect2(wg.y + 0.0, by - 5.4, 2.4, 1.3), edge, false, 0.04)
	# the sealer: a frame over the belt, the stamp's guide (its head drawn moving)
	var sx := TW.SEAL_X
	for s in [-1.0, 1.0]:
		p.line(Vector2(sx + s * 1.0, by), Vector2(sx + s * 1.0, by - 3.4), _ink(0.55), 0.12)
	p.rect(Rect2(sx - 1.2, by - 3.7, 2.4, 0.5), FACE2)
	p.rect(Rect2(sx - 1.2, by - 3.7, 2.4, 0.5), edge, false, 0.04)
	p.rect(Rect2(sx - 0.18, by - 3.2, 0.36, 0.9), _ink(0.45))
	p.rect(Rect2(sx + 0.3, by - 3.6, 0.6, 0.3), Pal.heat(0.6, 1.0))
	# the dock crane: its girder under the slab, the rail stops
	p.rect(Rect2(46.0, TW.CRANE_Y - 0.4, 13.0, 0.5), FACE2)
	p.line(Vector2(46.0, TW.CRANE_Y - 0.4), Vector2(59.0, TW.CRANE_Y - 0.4), _ink(0.7), 0.08)
	p.line(Vector2(46.0, TW.CRANE_Y + 0.1), Vector2(59.0, TW.CRANE_Y + 0.1), _ink(0.6), 0.08)
	if lod >= 1:
		var gx := 46.5
		while gx < 59.0:
			p.line(Vector2(gx, TW.CRANE_Y - 0.35), Vector2(gx + 0.5, TW.CRANE_Y + 0.05), _ink(0.2), 0.03)
			gx += 1.0
	for sx2 in [46.2, 58.8]:
		p.rect(Rect2(sx2 - 0.2, TW.CRANE_Y + 0.1, 0.4, 0.35), Pal.heat(0.6, 1.0))
	# the floor's lane marks in the dock
	var mx := TW.INTAKE_X
	while mx < 58.0:
		p.line(Vector2(mx, FLOOR - 0.05), Vector2(mx + 0.9, FLOOR - 0.05), Pal.heat(0.35, 1.0), 0.06)
		mx += 2.0


# ================================================================== the meshes that move
func _crate(p) -> void:
	# origin: its bottom middle. A steel crate with its corner castings, ribs, the seal tag
	var s := TW.CRATE
	var b := Rect2(-s.x * 0.5, -s.y, s.x, s.y)
	p.rect(b, Color(0.17, 0.18, 0.19))
	for k in range(1, 4):
		p.line(Vector2(b.position.x + k * s.x / 4.0, -s.y + 0.08), Vector2(b.position.x + k * s.x / 4.0, -0.08), _ink(0.25), 0.04)
	for c in [b.position, Vector2(b.end.x - 0.18, b.position.y), Vector2(b.position.x, b.end.y - 0.18), b.end - Vector2(0.18, 0.18)]:
		p.rect(Rect2(c, Vector2(0.18, 0.18)), _ink(0.6))
	p.rect(b, _ink(0.75), false, 0.05)


func _seal_tag(p) -> void:
	p.rect(Rect2(-0.2, -0.8, 0.4, 0.3), Pal.heat(0.9, 1.1))


func _lighter(p) -> void:
	# a client lighter, bow (−x) in: a hull with a hold well, the wheelhouse aft, fenders; origin
	# its deck line at the bow
	var edge := _ink(0.8)
	var hull := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.2, 2.8), Vector2(15.0, 2.8), Vector2(16.5, 1.0), Vector2(16.5, -0.2), Vector2(0.0, -0.2)])
	p.poly(hull, Color(0.1, 0.106, 0.118))
	p.rect(Rect2(2.5, -0.2, 7.0, 0.35), VOID)                 # the hold's coaming (open)
	p.rect(Rect2(11.5, -2.8, 3.6, 2.6), FACE2)                # the wheelhouse
	p.rect(Rect2(11.8, -2.5, 3.0, 0.8), Pal.tint(Pal.AIR, 0.35, 1.1))
	p.rect(Rect2(11.5, -2.8, 3.6, 2.6), _ink(0.6), false, 0.05)
	p.line(Vector2(13.3, -2.8), Vector2(13.3, -4.0), _ink(0.6), 0.06)
	for k in 4:
		p.rect(Rect2(1.8 + k * 3.4, 2.75, 1.2, 0.3), Color(0.03, 0.03, 0.035))
	p.hatch(Rect2(0.6, 0.35, 9.0, 0.5), Pal.heat(0.4, 1.0), 0.08, 0.6)
	p.polyline(hull, edge, 0.08, true)


func _ship(p) -> void:
	# a visitor's small ship, bow (−x) to the airlock: hull, cockpit, engine bells aft, its hatch
	var edge := _ink(0.75)
	var hull := PackedVector2Array([Vector2(0.0, 0.0), Vector2(2.2, -2.0), Vector2(11.0, -2.0), Vector2(12.5, -1.0), Vector2(12.5, 1.0), Vector2(11.0, 2.0), Vector2(2.2, 2.0)])
	p.poly(hull, Color(0.085, 0.09, 0.1))
	p.poly(PackedVector2Array([Vector2(1.0, -0.9), Vector2(2.6, -1.6), Vector2(4.2, -1.6), Vector2(4.2, 0.0), Vector2(1.0, 0.0)]), Pal.tint(Pal.AIR, 0.35, 1.1))
	for k in [-0.9, 0.9]:
		p.poly(PackedVector2Array([Vector2(12.5, k - 0.5), Vector2(14.0, k - 0.8), Vector2(14.0, k + 0.8), Vector2(12.5, k + 0.5)]), Color(0.1, 0.098, 0.096))
	p.rect(Rect2(0.2, -0.6, 0.5, 1.2), FACE2)                # its hatch
	for sx in [5.5, 8.5]:
		p.line(Vector2(sx, -2.0), Vector2(sx, 2.0), _ink(0.22), 0.04)
	p.polyline(hull, edge, 0.08, true)


func _cart(p) -> void:
	# the visitors' shuttle cart: a glass-topped car on its bogie; origin its bottom middle
	p.rect(Rect2(-1.3, -0.5, 2.6, 0.4), FACE2)
	p.poly(PackedVector2Array([Vector2(-1.2, -0.5), Vector2(-0.9, -1.7), Vector2(1.0, -1.7), Vector2(1.3, -0.5)]), Pal.tint(Pal.AIR, 0.22, 1.0))
	p.polyline(PackedVector2Array([Vector2(-1.2, -0.5), Vector2(-0.9, -1.7), Vector2(1.0, -1.7), Vector2(1.3, -0.5)]), _ink(0.7), 0.05)
	for wx in [-0.8, 0.8]:
		p.circle(Vector2(wx, -0.1), 0.14, _ink(0.6), 8)
	# the passenger, a figure seated
	p.circle(Vector2(0.0, -1.35), 0.17, Pal.ink(0.75), 10)
	p.poly(PackedVector2Array([Vector2(-0.3, -0.55), Vector2(-0.22, -1.12), Vector2(0.22, -1.12), Vector2(0.3, -0.55)]), Pal.ink(0.6))


func _rep(p) -> void:
	# the company's representative on the video link: head and shoulders, back-lit
	p.circle(Vector2(0.0, -0.75), 0.24, Pal.ink(0.16), 14)
	p.poly(PackedVector2Array([Vector2(-0.75, 0.0), Vector2(-0.55, -0.4), Vector2(-0.2, -0.5), Vector2(0.2, -0.5), Vector2(0.55, -0.4), Vector2(0.75, 0.0)]), Pal.ink(0.16))
	p.ring(Vector2(0.0, -0.75), 0.25, Pal.tint(Pal.AIR, 0.5, 1.2), 0.03, 14)


func _trolley(p) -> void:
	# the dock crane's trolley; origin under it where the rope leaves
	p.rect(Rect2(-0.9, -0.55, 1.8, 0.55), FACE2)
	p.rect(Rect2(-0.9, -0.55, 1.8, 0.55), _ink(0.7), false, 0.05)
	p.circle(Vector2(0.0, -0.28), 0.2, Color(0.1, 0.105, 0.115), 12)
	p.rect(Rect2(0.45, -0.45, 0.35, 0.35), Pal.heat(0.5, 1.0))


func _spreader(p) -> void:
	# the crate spreader on the hook: a beam, two twist-lock legs; origin its feet
	p.rect(Rect2(-1.0, -0.5, 2.0, 0.22), _ink(0.6))
	for s in [-0.75, 0.75]:
		p.line(Vector2(s, -0.28), Vector2(s, 0.0), _ink(0.7), 0.08)
	p.hatch(Rect2(-0.95, -0.48, 1.9, 0.18), Pal.heat(0.6, 1.0), 0.06, 0.25)


# ================================================================== the moving parts
func moving(ci: CanvasItem, t: float, on: bool, inside: bool, names: Dictionary) -> void:
	if inside:
		_booths_moving(ci, t, on, names)
		_tubes(ci)
		_dock_moving(ci, t, on, names)
		_carts(ci, t)
	_outside(ci, t, names)


func _booths_moving(ci: CanvasItem, t: float, on: bool, names: Dictionary) -> void:
	for i in 3:
		var x0 := counter_x(i)
		var k := float(TW.near_k[i])
		if k <= 0.01:
			continue
		# Q5 C: the video link on the glass, the representative and the company's line
		var gr := Rect2(_p(Vector2(x0 + 0.15, 7.65)), Vector2(8.7, 1.1) * m)
		ci.draw_rect(gr, Color(0.02, 0.05, 0.06, 0.85 * k))
		_put(ci, _mesh("rep", _rep), Vector2(x0 + 1.2, 8.75), 0.0, Color(1, 1, 1, k))
		var sl := PackedVector2Array()
		var yy := 7.7 + fmod(t * 0.4, 0.15)
		while yy < 8.75:
			sl.append_array([_p(Vector2(x0 + 0.15, yy)), _p(Vector2(x0 + 8.85, yy))])
			yy += 0.15
		ci.draw_multiline(sl, Color(0.6, 0.9, 1.0, 0.05 * k), 1.0)
		var who := str(TH.COMPANIES[i])
		var nm := str(names.get(who, {}).get("name", who))
		var deal := TH.main_deal(who)
		var line := w("代表 · %s", "%s'S DESK") % nm
		var say := w("你好，需要什么？", "Good day, what do you need?")
		if not deal.is_empty():
			say = (w("我们在收 %s，%s/t，还要 %.1f t。", "We're buying %s at %s/t, %.1f t more.") if str(deal.side) == "buy" else w("我们有 %s，%s/t，%.1f t 现货。", "We have %s at %s/t, %.1f t in stock.")) % [Ops.item_name(str(deal.key)), Pal.money(float(deal.price)), float(deal.t)]
		_text(ci, Vector2(x0 + 2.2, 8.05), line, 0.34, Pal.tint(Pal.AIR, 0.9 * k, 1.2), true)
		_text(ci, Vector2(x0 + 2.2, 8.55), say, 0.32, Pal.ink(0.88 * k), false, HORIZONTAL_ALIGNMENT_LEFT, 6.5)
		FastDraw.circle(ci, _p(Vector2(x0 + 8.55, 7.85)), 0.07 * m, Color(1.0, 0.3, 0.25, k * (0.5 + 0.5 * sin(t * 4.0))))


# the capsules: up the counter's tube, along the duct west, up to the office
func _tubes(ci: CanvasItem) -> void:
	for c in TW.tubes:
		var i := int(c.i)
		var up := Vector2(counter_x(i) + 8.35, 8.1)
		var knee := Vector2(counter_x(i) + 8.35, DUCT_Y)
		var west := Vector2(14.6, DUCT_Y)
		var top := Vector2(14.6, 0.2)
		var legs := [up.distance_to(knee), knee.distance_to(west), west.distance_to(top)]
		var total: float = legs[0] + legs[1] + legs[2]
		var s := Pal.ease_io(float(c.u)) * total
		var at := up
		if s < float(legs[0]):
			at = up.lerp(knee, s / float(legs[0]))
		elif s < float(legs[0]) + float(legs[1]):
			at = knee.lerp(west, (s - float(legs[0])) / float(legs[1]))
		else:
			at = west.lerp(top, (s - float(legs[0]) - float(legs[1])) / float(legs[2]))
		ci.draw_rect(Rect2(_p(at - Vector2(0.1, 0.1)), Vector2(0.2, 0.2) * m), Pal.tint(Pal.AIR, 0.95, 1.6))


func _dock_moving(ci: CanvasItem, t: float, on: bool, names: Dictionary) -> void:
	var by := TW.BELT_Y
	# the intake's roller door
	var shut := (2.1) * (1.0 - smoothstep(0.0, 1.0, TW.intake))
	if shut > 0.02:
		ci.draw_rect(Rect2(_p(Vector2(TW.INTAKE_X - 1.1, by - 2.1)), Vector2(1.1, shut) * m), Color(0.13, 0.135, 0.145))
		ci.draw_line(_p(Vector2(TW.INTAKE_X - 1.1, by - 2.1 + shut)), _p(Vector2(TW.INTAKE_X, by - 2.1 + shut)), Pal.heat(0.75, 1.0), _lw(0.08))
	# the belt's rollers turning with it
	var rl := PackedVector2Array()
	var off := fmod(TW.belt_run, 0.6)
	var x := TW.INTAKE_X + 0.3 + off
	while x < TW.BELT_END + 0.8:
		rl.append_array([_p(Vector2(x, by + 0.08)), _p(Vector2(x, by + 0.34))])
		x += 0.6
	ci.draw_multiline(rl, _ink(0.42), _lw(0.04))
	# the crates on the belt and on the hook, their seals
	for c in TW.crates:
		var at: Vector2 = Vector2(float(c.x), by) if str(c.at) == "belt" else TW.hook_at() + Vector2(0.0, TW.CRATE.y)
		_put(ci, _mesh("crate", _crate), at)
		if bool(c.sealed):
			_put(ci, _mesh("seal", _seal_tag), at)
	# the weighbridge's reading; the sealer's head
	var wg := TW.WEIGH
	_text(ci, Vector2(wg.y + 0.25, by - 4.45), "%.2f t" % TW.weigh_show, 0.62, Pal.tint(Pal.FLUID, 0.95 if on else 0.3, 1.3), true)
	var head := lerpf(by - 2.3, by - TW.CRATE.y - 0.15, TW.seal_t)
	ci.draw_line(_p(Vector2(TW.SEAL_X, by - 3.2)), _p(Vector2(TW.SEAL_X, head)), _ink(0.65), _lw(0.12))
	ci.draw_rect(Rect2(_p(Vector2(TW.SEAL_X - 0.4, head)), Vector2(0.8, 0.25) * m), Pal.heat(0.75, 1.1))
	# the dock crane: trolley, ropes, the spreader
	_put(ci, _mesh("dtrolley", _trolley), Vector2(TW.cx, TW.CRANE_Y + 0.65))
	var hk := TW.hook_at()
	for s in [-0.4, 0.4]:
		ci.draw_line(_p(Vector2(TW.cx + s, TW.CRANE_Y + 0.65)), _p(hk + Vector2(s * 1.5, -0.5)), _ink(0.6), _lw(0.04))
	_put(ci, _mesh("spreader", _spreader), hk)
	var moving_crane := absf(TW.cvx) > 0.01 or absf(TW.cvh) > 0.01
	FastDraw.circle(ci, _p(Vector2(TW.cx + 0.62, TW.CRANE_Y + 0.38)), 0.11 * m, Pal.heat(0.4 + 0.6 * absf(sin(t * 8.0)), 1.6) if moving_crane else _ink(0.3))
	# the plates
	plate(ci, Vector2(15.0, 17.0), 13.5, w("交货码头", "HAND-OVER DOCK"), TW.dock_state(), t)
	var nm := str(names.get(TW.lighter_for, {}).get("name", ""))
	plate(ci, Vector2(41.0, 26.95), 18.0, w("驳船口", "LIGHTER PORT"), TW.lighter_state(nm), t)


# the visitors' carts on the hall floor and their lift; a label over each
func _carts(ci: CanvasItem, t: float) -> void:
	for id in TW.visitors:
		var e: Dictionary = TW.visitors[id]
		if float(e.g) <= 0.0 and float(e.c) <= 0.0:
			continue
		var lk: Vector2 = TW.LOCKS[int(e.lock)]
		var c := float(e.c)
		var pos := Vector2.ZERO
		if c < 0.2:
			pos = Vector2(57.5, lk.y).lerp(Vector2(57.5, TW.SLAB.x - 0.12), Pal.ease_io(c / 0.2))
		else:
			pos = Vector2(57.5, TW.SLAB.x - 0.12).lerp(Vector2(TW.WAIT_X, TW.SLAB.x - 0.12), Pal.ease_io((c - 0.2) / 0.8))
		_put(ci, _mesh("cart", _cart), pos, 0.0, Color.WHITE, c > 0.2 and (e.leaving as bool))
		if float(e.g) >= 1.0 and not bool(e.leaving):
			var v: Dictionary = e.v
			var st := TW.visitor_state(e)
			var lab := "%s · %s" % [TradePeople.card_name(v), TradePeople.temper_name(str(v.temper))]
			plate(ci, pos + Vector2(-0.5, -3.3), 14.0, lab, st, t)


# outside: the visitors' ships at the airlocks with their gangways; the client lighter
func _outside(ci: CanvasItem, t: float, names: Dictionary) -> void:
	for id in TW.visitors:
		var e: Dictionary = TW.visitors[id]
		var lk: Vector2 = TW.LOCKS[int(e.lock)]
		var k := Pal.ease_out(float(e.k))
		var cy := (lk.x + lk.y) * 0.5
		var at := Vector2(60.0 + 3.0 + (1.0 - k) * 60.0, cy)
		if float(e.k) < 1.0 and float(e.k) > 0.0:
			# braking in: the retros forward
			ci.draw_line(_p(at + Vector2(-0.4, -1.4)), _p(at + Vector2(-1.6 - sin(t * 30.0) * 0.4, -1.4)), Pal.tint(Pal.AIR, 0.8, 1.6), _lw(0.12))
			ci.draw_line(_p(at + Vector2(-0.4, 1.4)), _p(at + Vector2(-1.6 - sin(t * 30.0) * 0.4, 1.4)), Pal.tint(Pal.AIR, 0.8, 1.6), _lw(0.12))
		_put(ci, _mesh("ship", _ship), at, 0.0, Color(1, 1, 1, clampf(float(e.k) * 3.0, 0.0, 1.0)))
		var g := smoothstep(0.0, 1.0, float(e.g))
		if g > 0.0:
			ci.draw_rect(Rect2(_p(Vector2(60.0, cy - 0.7)), Vector2(3.2 * g, 1.4) * m), FACE2)
			ci.draw_rect(Rect2(_p(Vector2(60.0, cy - 0.7)), Vector2(3.2 * g, 1.4) * m), _ink(0.6), false, _lw(0.05))
			var ribs := PackedVector2Array()
			var gx := 60.4
			while gx < 60.0 + 3.2 * g:
				ribs.append_array([_p(Vector2(gx, cy - 0.7)), _p(Vector2(gx, cy + 0.7))])
				gx += 0.5
			if not ribs.is_empty():
				ci.draw_multiline(ribs, _ink(0.3), 1.0)
		FastDraw.circle(ci, _p(Vector2(58.4, lk.x - 0.75)), 0.16 * m, Pal.tint(Pal.FLUID, 0.9, 1.3) if g >= 1.0 else Pal.heat(0.4 + 0.6 * absf(sin(t * 6.0)), 1.5))
	# the client lighter in the east port
	if TW.lighter_k > 0.0:
		var k := Pal.ease_out(TW.lighter_k)
		var at := Vector2(52.0 + (1.0 - k) * 45.0, TW.LIGHTER_Y)
		_put(ci, _mesh("lighter", _lighter), at)
		# what is in its hold
		for i in TW.hold:
			_put(ci, _mesh("crate", _crate), at + Vector2(3.0 + (i % 4) * 1.75, 0.0 - (i / 4) * TW.CRATE.y))
		var nm := str(names.get(TW.lighter_for, {}).get("name", ""))
		if Pal.labels:
			_text(ci, at + Vector2(11.0, -4.4), nm, 0.5, Pal.ink(0.8), true)


# ================================================================== the board and the counters' words (slow layer)
# the quote board: each goods' best bid and ask, the last price, its history (Q9), the depth on each side
func board(ci: CanvasItem, rows: Array) -> void:
	var b := BOARD
	_text(ci, b.position + Vector2(0.7, 0.85), w("报价大屏 · 港内三家与小行星带商人", "QUOTES · THE PORT'S THREE AND THE BELT'S MERCHANTS"), 0.55, Pal.ink(0.95), true)
	var cols := [0.7, 10.5, 15.0, 19.5, 24.0, 31.0]
	var heads := [w("商品", "GOODS"), w("最高收价", "BEST BID"), w("最低卖价", "BEST ASK"), w("上次成交", "LAST"), w("走势（每格 1 分钟）", "TREND (1 MIN / STEP)"), w("买 / 卖 深度", "BID / ASK DEPTH")]
	for k in heads.size():
		_text(ci, b.position + Vector2(cols[k], 1.6), str(heads[k]), 0.34, Pal.ink(0.5))
	var yy := 2.3
	for row in rows.slice(0, 6):
		var y := b.position.y + yy
		_text(ci, Vector2(b.position.x + cols[0], y), (w("加急 ", "RUSH ") if row.rush else "") + str(row.name), 0.42, Pal.ink(0.9))
		_text(ci, Vector2(b.position.x + cols[1], y), Pal.money(float(row.bid)) if float(row.bid) > 0.0 else "—", 0.44, UiSkin.DATA, true)
		_text(ci, Vector2(b.position.x + cols[2], y), Pal.money(float(row.ask)) if float(row.ask) < INF else "—", 0.44, UiSkin.ACCENT, true)
		_text(ci, Vector2(b.position.x + cols[3], y), Pal.money(float(row.last)) if float(row.last) > 0.0 else "—", 0.4, Pal.ink(0.75))
		_spark(ci, Rect2(b.position.x + cols[4], y - 0.45, 6.3, 0.5), TW.history(str(row.key)))
		_depth(ci, Rect2(b.position.x + cols[5], y - 0.42, 4.6, 0.42), float(row.bid_t), float(row.ask_t))
		yy += 0.62


# a goods' history: its bid (blue) and ask (orange) over the last hour, one line each
func _spark(ci: CanvasItem, rr: Rect2, h: Array) -> void:
	ci.draw_line(_p(Vector2(rr.position.x, rr.end.y)), _p(rr.end), Color(1, 1, 1, 0.08), 1.0)
	if h.size() < 2:
		_text(ci, Vector2(rr.position.x, rr.end.y - 0.05), w("记录中…", "RECORDING…"), 0.28, Pal.ink(0.35))
		return
	var lo := INF
	var hi := -INF
	for p in h:
		for v in [float(p[0]), float(p[1])]:
			if v > 0.0:
				lo = minf(lo, v)
				hi = maxf(hi, v)
	if lo == INF:
		return
	var span := maxf(1.0, hi - lo)
	for side in 2:
		var pts := PackedVector2Array()
		for k in h.size():
			var v := float(h[k][side])
			if v <= 0.0:
				continue
			pts.append(_p(Vector2(rr.position.x + rr.size.x * k / float(TW.HIST_N - 1), rr.end.y - (v - lo) / span * rr.size.y)))
		if pts.size() >= 2:
			FastDraw.polyline(ci, pts, UiSkin.DATA if side == 0 else UiSkin.ACCENT, 1.4)


# how many tonnes are bid and offered: a bar each way from the middle
func _depth(ci: CanvasItem, rr: Rect2, bid_t: float, ask_t: float) -> void:
	var mid := rr.position.x + rr.size.x * 0.5
	var k := rr.size.x * 0.5 / maxf(5.0, maxf(bid_t, ask_t))
	ci.draw_rect(Rect2(_p(Vector2(mid - bid_t * k, rr.position.y)), Vector2(bid_t * k, rr.size.y) * m), Color(UiSkin.DATA, 0.7))
	ci.draw_rect(Rect2(_p(Vector2(mid, rr.position.y)), Vector2(ask_t * k, rr.size.y) * m), Color(UiSkin.ACCENT, 0.7))
	ci.draw_line(_p(Vector2(mid, rr.position.y - 0.05)), _p(Vector2(mid, rr.end.y + 0.05)), _ink(0.5), 1.0)
	_text(ci, Vector2(mid - 2.3, rr.end.y + 0.0), "%.1f" % bid_t, 0.26, Pal.ink(0.6))
	_text(ci, Vector2(mid + 1.6, rr.end.y + 0.0), "%.1f" % ask_t, 0.26, Pal.ink(0.6))


# the counters' signs: the company and its main business in one line, a rush tag; and the
# ticker under the board: the port's last deals
func signs(ci: CanvasItem, names: Dictionary, near: String) -> void:
	for i in 3:
		var who := str(TH.COMPANIES[i])
		var x0 := counter_x(i)
		var nm := str(names.get(who, {}).get("name", who))
		var deal := TH.main_deal(who)
		var sc := TH.scene_of(who)
		var lit: bool = not deal.is_empty()
		var rush: bool = not sc.rush.is_empty()
		if rush:
			ci.draw_rect(Rect2(_p(Vector2(x0 - 0.25, 6.95)), Vector2(9.5, 0.6) * m), Color(UiSkin.ACCENT, 0.35))
		_text(ci, Vector2(x0, 7.43), nm, 0.42, Pal.ink(0.95 if lit else 0.45), true)
		var line := w("暂无生意", "NO BUSINESS")
		if lit:
			line = "%s %s %s/t" % [w("收", "BUYS") if str(deal.side) == "buy" else w("卖", "SELLS"), Ops.item_name(str(deal.key)), Pal.money(float(deal.price))]
		if rush:
			line = w("加急 · ", "RUSH · ") + line
		_text(ci, Vector2(x0 + 3.6, 7.43), line, 0.34, (UiSkin.ACCENT if rush else (UiSkin.DATA if lit and str(deal.side) == "buy" else Pal.ink(0.7))) if lit else Pal.ink(0.4), false, HORIZONTAL_ALIGNMENT_LEFT, 5.6)
		# under the desk: what it is doing with the company now (its stand, 49 号, in one line)
		var stand := ""
		match who:
			"merchant_00":
				if not sc.ledger.is_empty():
					var e: Dictionary = sc.ledger[sc.ledger.size() - 1]
					stand = w("台账 · 上一笔 %s %.2f t %s/t", "LEDGER · LAST %s %.2f t %s/t") % [Ops.item_name(str(e.key)), float(e.t), Pal.money(float(e.price))]
			"merchant_01":
				stand = w("货单 %d 张在途 · 上一批过磅 %.2f t", "%d DOCKETS OPEN · LAST WEIGHED %.2f t") % [sc.dockets.size(), float(sc.weighed)]
			"merchant_02":
				for bb in sc.buys:
					stand = w("修复件 · 收 %s 还要 %.1f t", "REPAIR PARTS · BUYS %s, %.1f t MORE") % [Ops.item_name(str(bb.key)), float(bb.t)]
					break
		if stand != "":
			_text(ci, Vector2(x0 + 0.2, 9.65), stand, 0.3, Pal.ink(0.55), false, HORIZONTAL_ALIGNMENT_LEFT, 8.8)
		if who == near:
			_text(ci, Vector2(x0 + 1.5, 11.0), w("按 %s 到柜台办理", "%s AT THE COUNTER") % Keys.label("use"), 0.48, Pal.ink(0.95), true)


# the ticker under the board: the port's last deals, one at a time, each sliding in (moving layer)
func ticker(ci: CanvasItem, t: float) -> void:
	var trades: Array = Career.data.get("exchange", {}).get("trades", [])
	var y := BOARD.end.y - 0.25
	ci.draw_rect(Rect2(_p(Vector2(BOARD.position.x + 0.2, y - 0.5)), Vector2(BOARD.size.x - 0.4, 0.6) * m), Color(0.01, 0.02, 0.025, 0.9))
	if trades.is_empty():
		_text(ci, Vector2(BOARD.position.x + 0.5, y - 0.05), w("成交 · 今天还没有成交", "DEALS · NONE YET TODAY"), 0.32, Pal.ink(0.45))
		return
	var last: Array = trades.slice(maxi(0, trades.size() - 6))
	var idx := int(t / 3.5) % last.size()
	var tr: Dictionary = last[last.size() - 1 - idx]
	var u := clampf(fmod(t, 3.5) / 0.4, 0.0, 1.0)
	var who := "%s → %s" % [str(tr.get("seller", "")), str(tr.get("buyer", ""))]
	var s := w("成交 · ", "DEAL · ") + "%s %.2f t @ %s/t" % [Ops.item_name(preload("res://scripts/industrial_exchange.gd").lot_key(str(tr.item), int(tr.grade))), float(tr.quantity), Pal.money(float(tr.unit_price))]
	_text(ci, Vector2(BOARD.position.x + 0.5 + (1.0 - Pal.ease_out(u)) * 3.0, y - 0.05), s, 0.32, Pal.tint(Pal.AIR, 0.85 * u, 1.1))
	_text(ci, Vector2(BOARD.end.x - 0.5, y - 0.05), "%d / %d" % [idx + 1, last.size()], 0.28, Pal.ink(0.4), false, HORIZONTAL_ALIGNMENT_RIGHT, 3.0)


# ================================================================== the hover cards
func hover_items(names: Dictionary) -> Array:
	var out: Array = []
	var add := func(rects: Array, title: String, use: String, now: Array, can: String) -> void:
		for rr in rects:
			out.append({"rect": Rect2(_p((rr as Rect2).position), (rr as Rect2).size * m), "title": title, "use": use, "now": str(now[0]), "can": can, "lamp": str(now[1])})
	add.call([BOARD], w("报价大屏", "QUOTE BOARD"),
		w("整个港口每样货的最高收价、最低卖价、上次成交价，每分钟记一点的走势，以及买卖两边各挂了多少吨。", "Every goods' best bid, best ask and last price at the port, its trend one point a minute, and how many tonnes are bid and offered."),
		[w("%d 种货在报价" % TH.board().size(), "%d GOODS QUOTED" % TH.board().size()), "ok"],
		w("看准价差再去柜台或终端（F8）买卖。蓝线高过平时就是卖的好时候。", "Mind the spread, then deal at a counter or the exchange (F8). Blue above its usual is the time to sell."))
	for i in 3:
		var who := str(TH.COMPANIES[i])
		var nm := str(names.get(who, {}).get("name", who))
		var deal := TH.main_deal(who)
		var now := [w("暂无生意", "NO BUSINESS"), "off"]
		if not deal.is_empty():
			now = ["%s %s %s/t · %.1f t" % [w("收", "BUYS") if str(deal.side) == "buy" else w("卖", "SELLS"), Ops.item_name(str(deal.key)), Pal.money(float(deal.price)), float(deal.t)], "ok"]
		var use: String = [w("炉料商：卖废钢、混合金属等炉料，收钢锭。", "Furnace feed: sells scrap and mixed metal, buys billets."),
			w("物流商：收成品，开货单、过磅、发运。", "Logistics: buys products, writes dockets, weighs, ships."),
			w("修理工场：收钢锭做法兰、轴套、支架等修复件。", "Repair shop: buys billets for flanges, bushes, brackets.")][i]
		add.call([Rect2(counter_x(i) - 0.3, 6.9, 9.6, 3.1)], nm, use, now, w("飞到柜台前按 %s：挂单、按它的报价成交。和它成交的货在下层交货码头交接。", "Fly to the desk, %s: post, or take its quote. What you deal with it is handed over at the dock below.") % Keys.label("use"))
	add.call([Rect2(TW.INTAKE_X - 1.4, TW.BELT_Y - 2.8, 2.0, 5.2)], w("仓库进货口", "WAREHOUSE INTAKE"), w("交货码头和仓库之间的口：卖出的货从这里出来，买进的货从这里进仓。", "Between the dock and the warehouse: what you sell comes out here, what you buy goes in."), TW.dock_state(), w("不用操作；仓库里要有货，卖单才能交货。", "Nothing to do; a sale needs the goods in the warehouse."))
	add.call([Rect2(TW.WEIGH.x - 0.5, TW.BELT_Y - 5.5, TW.WEIGH.y - TW.WEIGH.x + 3.2, 6.0)], w("过磅台", "WEIGHBRIDGE"), w("每箱货过磅，读数是这笔成交的真实吨数。", "Each crate is weighed; the reading is the deal's real tonnes."), ["%.2f t" % TW.weigh_show, "ok" if TW.job.is_empty() else "work"], w("看着读数就知道这笔交了多少。", "The reading is how much of the deal has gone."))
	add.call([Rect2(TW.SEAL_X - 1.3, TW.BELT_Y - 3.8, 2.6, 3.8)], w("封签机", "SEALER"), w("给过了磅的货箱打铅封，橙色标签就是封好的。", "Seals each weighed crate; the orange tag is its seal."), TW.dock_state(), w("不用操作。", "Nothing to do."))
	var nm2 := str(names.get(TW.lighter_for, {}).get("name", ""))
	add.call([Rect2(46.0, TW.CRANE_Y - 0.5, 14.0, FLOOR - TW.CRANE_Y + 0.5)], w("码头吊车与驳船口", "DOCK CRANE · LIGHTER PORT"), w("和港内公司成交后，对方的驳船靠进东墙下的口子，吊车把货箱吊进吊出。", "A deal with one of the port's companies brings its lighter into the port under the east wall; the crane swings the crates in or out."), TW.lighter_state(nm2), w("在柜台或终端和港内公司成交，就会看到它来交货。", "Deal with a port company at a counter or the exchange and it comes."))
	for lk: Vector2 in TW.LOCKS:
		add.call([Rect2(56.5, lk.x - 0.4, 3.6, lk.y - lk.x + 0.8)], w("客人气闸", "VISITORS' AIRLOCK"), w("独立商人和个体船主的小船靠在这里，廊桥接上舱门，接驳小车把客人送到业务终端旁边。", "The independent merchants' small ships berth here; the gangway meets the hatch and the cart takes the visitor to the business console."), [w("%d 位客人在港" % TradePeople.here().size(), "%d VISITORS IN" % TradePeople.here().size()), "work" if not TradePeople.here().is_empty() else "ok"], w("到西边业务终端按 %s：接受、还价或拒绝。急着要货的客人一分钟内不谈就走。", "At the business console in the west, %s: accept, haggle or send away. One in a hurry leaves after a minute.") % Keys.label("use"))
	return out
