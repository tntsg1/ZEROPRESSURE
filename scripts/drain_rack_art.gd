extends RefCounted
# The drain rack beside an equipment mouth (scripts/mishap.gd, 认真拆有奖励 design §7.1), drawn as the berth's
# own machinery: it hangs from the rail on a trolley like the mouth does, two telescopic hanger rods down to
# its head; the head carries a vent stack (gas out), a finned load bank (charge out, glowing while it works)
# and a small display; two hydraulic arms clamp what it holds over a catch tray whose pipe runs into the
# mouth's housing (liquid out). No words on it (127 号).
# Local frame: origin at the cradle (where the held machine sits), +y out into the berth (the mouth's face),
# +x toward the mouth. Lengths in px (48 a metre). Plain lines and filled rects only (cheap: no AA polylines,
# arcs or concave polygons): the static part is drawn once into its own node, the live part each frame.

const M := 48.0
const FACE := Color(0.07, 0.073, 0.082)
const DARK := Color(0.045, 0.047, 0.053)
const SCREEN := Color(0.012, 0.013, 0.015)
const ACC := Color(1.0, 0.353, 0.122)
# where things are on the head
const HEAD := Rect2(-1.05 * M, -1.2 * M, 2.1 * M, 0.52 * M)
const STACK := Rect2(-0.98 * M, -1.62 * M, 0.24 * M, 0.42 * M)
const BANK := Rect2(0.5 * M, -1.6 * M, 0.46 * M, 0.4 * M)
const DISPLAY := Rect2(-0.55 * M, -1.12 * M, 1.1 * M, 0.26 * M)
const SHOULDER := Vector2(0.72 * M, -0.68 * M)
const TRAY_Y := 0.92 * M


static func ink(a: float) -> Color:
	return Color(0.9, 0.9, 0.895, a)


# four narrow rects instead of a stroked rect
static func frame(ci: CanvasItem, r: Rect2, col: Color, w: float = 1.4) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), col)
	ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	ci.draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), col)


static func rivet(ci: CanvasItem, p: Vector2, a: float = 0.45) -> void:
	ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), ink(a))


# ---------------------------------------------------------------- what does not move

# rail_dy: the rail's height from the cradle (negative, px); to_mouth_x: where the mouth's lip edge is (px)
static func draw_static(ci: CanvasItem, rail_dy: float, to_mouth_x: float) -> void:
	var ln := ink(0.55)
	var dim := ink(0.28)
	# the trolley on the rail (as the mouth's own): a box and two wheels
	var tr := Rect2(-0.8 * M, rail_dy, 1.6 * M, 10.0)
	ci.draw_rect(tr, FACE)
	frame(ci, tr, ln)
	for wx in [-0.52 * M, 0.52 * M]:
		ci.draw_circle(Vector2(wx, rail_dy), 5.0, DARK)
		frame(ci, Rect2(Vector2(wx - 5.0, rail_dy - 5.0), Vector2(10, 10)), ln, 1.2)
		ci.draw_line(Vector2(wx, rail_dy), Vector2(wx + 3.5, rail_dy - 3.5), ln, 1.2)
	# telescopic hanger rods: an outer sleeve, the inner rod, collars, a cross brace
	var top := rail_dy + 10.0
	var bot := HEAD.position.y
	var mid := lerpf(top, bot, 0.45)
	for sx in [-0.42 * M, 0.42 * M]:
		ci.draw_rect(Rect2(Vector2(sx - 3.5, top), Vector2(7.0, mid - top)), DARK)
		frame(ci, Rect2(Vector2(sx - 3.5, top), Vector2(7.0, mid - top)), ln, 1.2)
		ci.draw_line(Vector2(sx, mid), Vector2(sx, bot), ln, 2.2)
		ci.draw_rect(Rect2(Vector2(sx - 5.0, mid - 3.0), Vector2(10.0, 6.0)), ink(0.62))
		ci.draw_rect(Rect2(Vector2(sx - 5.0, top + 3.0), Vector2(10.0, 4.0)), ink(0.4))
	ci.draw_line(Vector2(-0.42 * M, top + 10.0), Vector2(0.42 * M, mid - 6.0), dim, 1.0)
	ci.draw_line(Vector2(0.42 * M, top + 10.0), Vector2(-0.42 * M, mid - 6.0), dim, 1.0)
	# the head: housing, bevel, seams, rivets
	ci.draw_rect(HEAD, FACE)
	ci.draw_rect(Rect2(HEAD.position, Vector2(HEAD.size.x, 3.0)), ink(0.18))
	frame(ci, HEAD, ln)
	for sx in [-0.55 * M, 0.42 * M]:
		ci.draw_line(Vector2(sx, HEAD.position.y + 4.0), Vector2(sx, HEAD.end.y - 4.0), dim, 1.0)
	for p in [HEAD.position + Vector2(5, 6), Vector2(HEAD.end.x - 5, HEAD.position.y + 6), Vector2(HEAD.position.x + 5, HEAD.end.y - 5), HEAD.end - Vector2(5, 5)]:
		rivet(ci, p)
	# the display's window (the live part lights it)
	ci.draw_rect(DISPLAY.grow(2.0), DARK)
	ci.draw_rect(DISPLAY, SCREEN)
	frame(ci, DISPLAY.grow(2.0), ink(0.4), 1.0)
	# the vent stack: louvres and a cap
	ci.draw_rect(STACK, DARK)
	frame(ci, STACK, ln, 1.2)
	for i in 4:
		var y := STACK.position.y + 8.0 + i * 4.5
		ci.draw_line(Vector2(STACK.position.x + 3.0, y), Vector2(STACK.end.x - 3.0, y + 2.0), dim, 1.0)
	ci.draw_rect(Rect2(STACK.position + Vector2(-3.0, -4.0), Vector2(STACK.size.x + 6.0, 4.0)), ink(0.5))
	# the load bank: a finned box on the head, its cable up to the trolley
	ci.draw_rect(BANK, DARK)
	frame(ci, BANK, ln, 1.2)
	for i in 6:
		var x := BANK.position.x + 3.0 + i * (BANK.size.x - 6.0) / 5.0
		ci.draw_line(Vector2(x, BANK.position.y + 3.0), Vector2(x, BANK.end.y - 3.0), dim, 1.0)
	var c0 := Vector2(BANK.end.x - 4.0, BANK.position.y)
	var c1 := Vector2(0.62 * M, rail_dy + 10.0)
	var sag := Vector2(0.95 * M, lerpf(c0.y, c1.y, 0.5))
	for i in 8:
		var u0 := i / 8.0
		var u1 := (i + 1) / 8.0
		ci.draw_line(_bez(c0, sag, c1, u0), _bez(c0, sag, c1, u1), ink(0.35), 1.6)
	# the hydraulic block under the head the arms pivot on
	for sx in [-1.0, 1.0]:
		var sh := Vector2(sx * SHOULDER.x, SHOULDER.y)
		ci.draw_rect(Rect2(Vector2(sh.x - 7.0, HEAD.end.y), Vector2(14.0, SHOULDER.y - HEAD.end.y + 4.0)), DARK)
		frame(ci, Rect2(Vector2(sh.x - 7.0, HEAD.end.y), Vector2(14.0, SHOULDER.y - HEAD.end.y + 4.0)), ln, 1.0)
	# the catch tray under the cradle, its lip striped, its drain pipe into the mouth's housing
	var tw := 1.0 * M
	ci.draw_rect(Rect2(Vector2(-tw, TRAY_Y), Vector2(2.0 * tw, 0.16 * M)), DARK)
	ci.draw_line(Vector2(-tw - 6.0, TRAY_Y - 6.0), Vector2(-tw, TRAY_Y), ln, 2.0)
	ci.draw_line(Vector2(tw + 6.0, TRAY_Y - 6.0), Vector2(tw, TRAY_Y), ln, 2.0)
	ci.draw_line(Vector2(-tw, TRAY_Y), Vector2(-tw * 0.85, TRAY_Y + 0.16 * M), ln, 1.6)
	ci.draw_line(Vector2(tw, TRAY_Y), Vector2(tw * 0.85, TRAY_Y + 0.16 * M), ln, 1.6)
	ci.draw_line(Vector2(-tw * 0.85, TRAY_Y + 0.16 * M), Vector2(tw * 0.85, TRAY_Y + 0.16 * M), ln, 1.6)
	for i in 9:
		var x0 := -tw + 6.0 + i * (2.0 * tw - 12.0) / 8.0
		ci.draw_line(Vector2(x0, TRAY_Y + 2.0), Vector2(x0 + 5.0, TRAY_Y + 0.14 * M), Color(ACC, 0.32), 2.0)
	# the tray hangs from the head on two thin stays
	for sx in [-0.92 * M, 0.92 * M]:
		ci.draw_line(Vector2(sx, HEAD.end.y), Vector2(sx * 1.05, TRAY_Y - 6.0), dim, 1.0)
	# the drain pipe: along under the tray, up into the mouth's housing
	var px := minf(to_mouth_x, 1.6 * M)
	var py := TRAY_Y + 0.22 * M
	ci.draw_line(Vector2(0.6 * M, TRAY_Y + 0.16 * M), Vector2(0.6 * M, py), ln, 3.0)
	ci.draw_line(Vector2(0.6 * M, py), Vector2(px, py), ln, 3.0)
	ci.draw_line(Vector2(px, py), Vector2(px, -1.75 * M), ln, 3.0)
	for y in [py - 0.6 * M, -0.6 * M]:
		ci.draw_rect(Rect2(Vector2(px - 4.0, y - 2.0), Vector2(8.0, 4.0)), ink(0.55))


static func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


# ---------------------------------------------------------------- what moves (each frame)

# grip 0 open … 1 closed on its load; work 0..1 how far the draining is (-1 idle); kind batt/cap/gas/liq; t time
static func draw_live(ci: CanvasItem, grip: float, work: float, kind: String, t: float) -> void:
	var ln := ink(0.7)
	var busy := work >= 0.0
	# the arms: upper arm from the shoulder, a piston, the jaw with its pad
	for sx in [-1.0, 1.0]:
		var sh := Vector2(sx * SHOULDER.x, SHOULDER.y)
		var elbow: Vector2 = Vector2(sx * lerpf(1.08, 0.66, grip) * M, lerpf(-0.46, -0.24, grip) * M)
		var jaw: Vector2 = Vector2(sx * lerpf(1.12, 0.5, grip) * M, lerpf(-0.04, 0.2, grip) * M)
		ci.draw_line(sh, elbow, ln, 4.0)
		ci.draw_line(sh, elbow, Color(DARK, 1.0), 1.6)
		ci.draw_line(elbow, jaw, ln, 3.0)
		# the pad: a short thick bar across the jaw's end, facing in
		var inward := Vector2(-sx, 0.0)
		var along := (jaw - elbow).normalized()
		ci.draw_line(jaw - along * 7.0 + inward * 1.0, jaw + along * 5.0 + inward * 1.0, ink(0.85), 5.0)
		# piston: cylinder from the head, rod to the arm's middle
		var p0 := Vector2(sx * 0.3 * M, -0.7 * M)
		var p1: Vector2 = sh.lerp(elbow, 0.55)
		var pm: Vector2 = p0.lerp(p1, 0.55)
		ci.draw_line(p0, pm, ink(0.55), 4.0)
		ci.draw_line(pm, p1, ink(0.8), 1.6)
		for p in [sh, elbow]:
			ci.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), DARK)
			ci.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), ink(0.75))
	# the lamp on the head: orange beating while it works, dim at rest; its halo
	var lamp := Vector2(0.0, HEAD.position.y - 3.0)
	if busy:
		var b := 0.6 + 0.4 * sin(t * 9.0)
		ci.draw_rect(Rect2(lamp - Vector2(9, 5), Vector2(18, 7)), Color(ACC, 0.18 * b))
		ci.draw_rect(Rect2(lamp - Vector2(5, 3), Vector2(10, 4)), Color(ACC, 0.95 * b))
	else:
		ci.draw_rect(Rect2(lamp - Vector2(5, 3), Vector2(10, 4)), ink(0.22))
	# the display: what it is letting out (a mark), and how far (eight segments)
	var d := DISPLAY
	var icon := d.position + Vector2(9.0, d.size.y * 0.5)
	var ic := Color(ACC, 0.95) if busy else ink(0.18)
	match kind:
		"batt", "cap":
			ci.draw_line(icon + Vector2(1, -5), icon + Vector2(-2, 0), ic, 1.6)
			ci.draw_line(icon + Vector2(-2, 0), icon + Vector2(2, 0), ic, 1.6)
			ci.draw_line(icon + Vector2(2, 0), icon + Vector2(-1, 5), ic, 1.6)
		"gas":
			for i in 3:
				ci.draw_line(icon + Vector2(-4 + i * 4, 4), icon + Vector2(-3 + i * 4, -4), ic, 1.4)
		"liq":
			ci.draw_line(icon + Vector2(0, -5), icon + Vector2(-3, 1), ic, 1.6)
			ci.draw_line(icon + Vector2(0, -5), icon + Vector2(3, 1), ic, 1.6)
			ci.draw_line(icon + Vector2(-3, 1), icon + Vector2(3, 1), ic, 1.6)
			ci.draw_line(icon + Vector2(-3, 1), icon + Vector2(0, 4), ic, 1.6)
			ci.draw_line(icon + Vector2(3, 1), icon + Vector2(0, 4), ic, 1.6)
		_:
			ci.draw_line(icon + Vector2(-3, 0), icon + Vector2(3, 0), ink(0.14), 1.4)
	var sx0 := d.position.x + 20.0
	var sw := (d.end.x - 4.0 - sx0) / 8.0
	for i in 8:
		var lit: bool = busy and work * 8.0 > float(i)
		var c := Color(ACC, 0.95) if lit else ink(0.08 + (0.1 if not busy and i == int(t * 1.5) % 8 else 0.0))
		ci.draw_rect(Rect2(Vector2(sx0 + i * sw + 1.0, d.position.y + 4.0), Vector2(sw - 2.0, d.size.y - 8.0)), c)
	# the load bank glows while it takes a charge in
	if busy and kind in ["batt", "cap"]:
		var hk := clampf(1.0 - work, 0.0, 1.0)
		for i in 6:
			var x := BANK.position.x + 3.0 + i * (BANK.size.x - 6.0) / 5.0
			ci.draw_line(Vector2(x, BANK.position.y + 3.0), Vector2(x, BANK.end.y - 3.0), Color(ACC, (0.35 + 0.5 * hk) * (0.8 + 0.2 * sin(t * 13.0 + i))), 1.6)
	# the vent stack's mouth breathes while it lets gas out
	if busy and kind == "gas":
		ci.draw_rect(Rect2(STACK.position + Vector2(-3.0, -4.0), Vector2(STACK.size.x + 6.0, 4.0)), Color(0.75, 0.88, 1.0, 0.55 + 0.3 * sin(t * 15.0)))
	# the catch tray's drain lit while liquid runs into it
	if busy and kind == "liq":
		ci.draw_line(Vector2(-0.9 * M, TRAY_Y + 0.08 * M), Vector2(0.9 * M, TRAY_Y + 0.08 * M), Color(0.55, 0.75, 0.95, 0.5), 3.0)
	# how far: twelve ticks round the cradle, lit as it goes
	if busy:
		for i in 12:
			var a := -PI * 0.5 + TAU * i / 12.0
			var on: bool = work * 12.0 > float(i)
			var r0 := 1.02 * M
			ci.draw_line(Vector2.from_angle(a) * r0, Vector2.from_angle(a) * (r0 + 7.0), Color(ACC, 0.9) if on else ink(0.16), 2.0)
