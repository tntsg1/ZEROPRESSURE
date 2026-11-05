class_name PortArt
# Zero Pressure Port, drawn far behind the berth (G6; player 2026-10-21: "the structure
# in the sketch: the central transfer ring in the middle, the districts around it on
# spokes, like a space station; big, every part as detailed as you can").
# Everything here is in port metres (pm) around the station's centre; the caller gives
# the centre in world px and M = px per pm. The layout follows the planning sketch:
#   power district at the top, tug station upper left, processing left, trade port
#   right, cargo district lower right, the salvage (berth) district at the bottom,
#   the central transfer ring in the middle, a dashed outer rail round it, spokes
#   from the ring to every district; ARK-01 lies off to the right.
# lit: zone -> stages built (0..2): outlines brighten, windows fill, lamps come on.

# Compact station (2026-10-24, Jev A 0.74; player: "the six districts are too spread out"):
# one port unit is one metre. The districts sit on a 78 x 60 m ellipse round a 24 m hub,
# each main block 60 x 28 m: the whole station ~300 x 190 m, the berth inside its
# salvage district at the bottom. scripts/port_structure.gd gives the same geometry
# walls, doors, corridors, interiors and consoles.
const PM := 1.0
const HUB_R := 24.0          # m: the ring's outer radius
const HUB_R2 := 16.0         # the inner ring
const CORE_R := 8.0          # the hub core
const RAIL_R := 44.0         # the dashed outer rail
const RADIUS := Vector2(96.0, 75.0)     # the districts sit on this ellipse (35 号: was 78 × 60, “not so cramped”)
const BOX := Vector2(60.0, 28.0)        # a district's main block
# the zone the operator is inside: its shell is drawn see-through (set by port_structure)
static var inside := ""
static var _ghost := false
static var _code := ""          # the district's stencil code while its block is drawn
# every lit lamp drawn this frame: [world px, radius px, colour]; scripts/backdrop.gd draws
# a soft additive halo on each (the title screen draws the port without halos)
static var lamps: Array = []
static var _no_lamps := false
# Performance (2026-10-24, design/…/24_港站绘制性能): the berth keeps the still drawing
# as retained geometry and only replays what moves or sizes itself to the screen. While
# _recording, every such piece is kept as a call (ci, t, z) in _rec instead of drawn;
# drawn directly otherwise (the title screen), so both paths draw the very same thing.
static var _recording := false
static var _rec: Array = []
static var _rz := 1.0          # the zoom a piece is drawn at (the frame's, when replayed)


static func _anim(ci, t: float, f: Callable) -> void:
	if _recording:
		_rec.append(f)
	else:
		f.call(ci, t, _rz)


static func _lamp(ci, p: Vector2, r: float, col: Color, halo: float = 4.0) -> void:
	ci.draw_circle(p, r, col)
	if not _no_lamps:
		lamps.append([p, r * halo, col])
# zone -> angle (degrees, y down: -90 is up)
const ANGLE := {"power": -90.0, "tug": -148.0, "process": 180.0, "trade": 0.0, "cargo": 42.0, "salvage": 90.0}
const ARK_AT := Vector2(308.0, -56.0)   # m: ARK-01's centre, off the port (moved out with the districts, 35 号)
const ARK_K := 3.0                      # ARK-01 drawn at 3 m per unit: ~300 m long
const FILL := Color(0.028, 0.03, 0.036)
const FILL2 := Color(0.04, 0.042, 0.05)


# the station's box in port units, ARK-01 included (for the panorama): left, top, right, bottom
static func bounds() -> Rect2:
	# the station itself; ARK-01 lies past the right edge and shows in part
	var left := -(RADIUS.x + BOX.x * 0.5 + 40.0)
	var right := RADIUS.x + BOX.x * 0.5 + 84.0
	var top := -(RADIUS.y + BOX.y * 0.5 + 34.0)
	var bottom := RADIUS.y + 15.0 + 26.0
	return Rect2(left, top, right - left, bottom - top)


static func extent() -> Vector2:
	return bounds().size


# where a district's door is, in port units from the station's centre: the point where
# the line from the block's centre towards the hub leaves the block, kept off the corner;
# with the inward normal. Spokes are drawn to it and port_structure builds its walls on it.
const DOOR := 6.0
static func door_at(zone: String) -> Array:
	var c := district_at(zone)
	var dir := (-c).normalized()
	# the door sits at the middle of the side that faces the hub most squarely
	if absf(dir.x) > absf(dir.y):
		var sx := signf(dir.x)
		return [c + Vector2(sx * BOX.x * 0.5, 0.0), Vector2(-sx, 0.0)]
	var sy := signf(dir.y)
	return [c + Vector2(0.0, sy * BOX.y * 0.5), Vector2(0.0, -sy)]


static func district_at(zone: String) -> Vector2:
	var a: float = deg_to_rad(float(ANGLE.get(zone, 0.0)))
	return Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y)


# the outline's alpha and the share of windows lit, by stages built
static func _ink(n: int) -> float:
	return [0.11, 0.2, 0.3][clampi(n, 0, 2)]


const PARTS := ["base", "power", "tug", "process", "trade", "cargo", "salvage", "ark"]


static func draw(ci, c: Vector2, M: float, z: float, t: float, lit: Dictionary) -> void:
	lamps = []
	_rz = z
	for part in PARTS:
		draw_part(ci, part, c, M, z, t, lit)


# one part of the station: the rail, spokes and ring ("base"), a district, or ARK-01
static func draw_part(ci, part: String, c: Vector2, M: float, z: float, t: float, lit: Dictionary) -> void:
	if part == "ark":
		_ark(ci, c + ARK_AT * M, M * ARK_K, z, t)
		return
	if part != "base":
		_district(ci, c + district_at(part) * M, part, M, z, t, int(lit.get(part, 0)))
		return
	var lw := 1.0 / z
	var nr: int = int(lit.get("ring", 0))
	# the outer rail, dashed; its cars run once the ring has power
	_dashed_ellipse(ci, c, Vector2(RAIL_R, RAIL_R * 0.86) * M, 72, Pal.ink(0.08 + 0.05 * nr), lw)
	if nr >= 1:
		_anim(ci, t, func(cc, tt: float, _z: float):
			for i in 3:
				var a := tt * 0.12 + TAU * i / 3.0
				var p := c + Vector2(cos(a) * RAIL_R, sin(a) * RAIL_R * 0.86) * M
				cc.draw_rect(Rect2(p - Vector2(2.0, 1.2) * M, Vector2(4.0, 2.4) * M), Pal.ink(0.5, 1.2))
				cc.draw_circle(p, 0.6 * M, Pal.heat(0.9, 1.6)))
	# spokes: a corridor from the ring to every district, crossbars along it, a junction on the rail
	for zid in ANGLE:
		var dp: Array = door_at(zid)
		var d: Vector2 = dp[0]
		var dir := d.normalized()
		var a0 := c + dir * HUB_R * M
		var a1 := c + d * M
		var n: int = int(lit.get(zid, 0))
		var col := Pal.ink(0.08 + 0.06 * n)
		var hw := PortStructure.half(zid)
		_truss(ci, a0, a1, hw * M, 5.0 * M, col, lw)
		# the tube's glazing strip and its ribs every five metres
		ci.draw_line(a0, a1, Pal.tint(Pal.AIR, 0.05 + 0.07 * n, 1.1), lw * 2.0)
		var len := a0.distance_to(a1)
		var step := 8.0 * M
		var ribs := int(len / (5.0 * M))
		for rb in ribs:
			var q := a0 + dir * (rb + 0.5) * 5.0 * M
			ci.draw_line(q + dir.orthogonal() * (hw + 0.6) * M, q - dir.orthogonal() * (hw + 0.6) * M, Pal.ink(0.1 + 0.05 * n), lw * 1.6)
		# 100 号 (Q1 C): the feeder cable along the spoke, its current as pulses — into the hub from
		# the power district, out from the hub to each district by what it draws now
		var side_v := dir.orthogonal() * 2.3 * M
		ci.draw_line(a0 + side_v, a1 + side_v, Pal.tint(Pal.VOLT, 0.12 + 0.06 * n, 1.0), lw * 1.4)
		var zz2: String = zid
		_anim(ci, t, func(cc, tt: float, _z: float):
			var mw := _feeder_mw(zz2)
			if mw <= 0.005:
				return
			var L := len
			var stp := 7.0 * M
			var off := fmod(tt * (5.0 + 4.0 * sqrt(mw)) * M, stp)
			var vc := Pal.tint(Pal.VOLT, 0.45 + 0.5 * clampf(mw / 12.0, 0.0, 1.0), 1.4)
			var dd := off
			while dd < L:
				var k := dd / L if zz2 != "power" else 1.0 - dd / L
				FastDraw.circle(cc, a0.lerp(a1, k) + side_v, (0.28 + 0.2 * clampf(mw / 20.0, 0.0, 1.0)) * M, vc)
				dd += stp)
		# a junction where the spoke crosses the rail
		var jp := c + Vector2(dir.x * RAIL_R, dir.y * RAIL_R * 0.86) * M
		ci.draw_rect(Rect2(jp - Vector2(3.0, 3.0) * M, Vector2(6.0, 6.0) * M), FILL2)
		ci.draw_rect(Rect2(jp - Vector2(3.0, 3.0) * M, Vector2(6.0, 6.0) * M), Pal.ink(0.1 + 0.08 * n), false, lw)
		if n >= 1:
			# a lit corridor: lamps along it
			var m := 0
			while m * step + 4.0 * M < len:
				ci.draw_circle(a0 + dir * (m * step + 4.0 * M), 0.5 * M, Pal.ink(0.35, 1.2))
				m += 1
	_hub(ci, c, M, z, t, nr)


# ---------------------------------------------------------------- the central transfer ring
static func _hub(ci, c: Vector2, M: float, z: float, t: float, n: int) -> void:
	var lw := 1.0 / z
	var ink := _ink(n)
	# the core: a filled disc with a window ring and a beacon
	ci.draw_circle(c, CORE_R * M, FILL)
	ci.draw_arc(c, CORE_R * M, 0.0, TAU, 48, Pal.ink(ink + 0.05), lw * 1.5, true)
	for i in 12:
		var a := TAU * i / 12.0
		if n == 0:
			# a dark ring: its windows flicker
			_anim(ci, t, func(cc, tt: float, _z: float):
				var on: bool = i < 2 or fmod(tt * 0.5 + i * 0.37, 1.0) < 0.1
				cc.draw_circle(c + Vector2.from_angle(a) * CORE_R * 0.7 * M, 0.7 * M, Pal.ink(0.5 if on else 0.08, 1.2)))
		else:
			var on: bool = i < [2, 7, 12][n]
			ci.draw_circle(c + Vector2.from_angle(a) * CORE_R * 0.7 * M, 0.7 * M, Pal.ink(0.5 if on else 0.08, 1.2))
	if n >= 1:
		_anim(ci, t, func(cc, tt: float, _z: float): cc.draw_circle(c, 2.0 * M, Pal.heat(0.4 + 0.5 * (0.5 + 0.5 * sin(tt * 2.0)), 1.5)))
	else:
		ci.draw_circle(c, 2.0 * M, Pal.ink(0.12))
	# inner ring and the outer ring, eight spokes between them
	ci.draw_arc(c, HUB_R2 * M, 0.0, TAU, 64, Pal.ink(ink), lw * 1.5, true)
	ci.draw_arc(c, HUB_R * M, 0.0, TAU, 96, Pal.ink(ink + 0.08), lw * 2.2, true)
	ci.draw_arc(c, (HUB_R - 2.5) * M, 0.0, TAU, 96, Pal.ink(ink * 0.6), lw, true)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var v := Vector2.from_angle(a)
		ci.draw_line(c + v * CORE_R * M, c + v * HUB_R2 * M, Pal.ink(ink), lw * 1.2)
		_truss(ci, c + v * HUB_R2 * M, c + v * HUB_R * M, 1.4 * M, 2.4 * M, Pal.ink(ink * 0.8), lw)
	# the ring's habitation: window blocks on the outer ring, between the spokes
	for i in 8:
		var a := TAU * i / 8.0
		var on_k: float = [0.08, 0.5, 1.0][n]
		for w in 5:
			var aw := a + (w - 2) * 0.07
			var flick: bool = n == 0 and fmod(t * 0.6 + i * 0.3 + w * 0.5, 1.0) < 0.2
			var on: bool = float(w * 8 + i) / 40.0 < on_k and not flick
			var p := c + Vector2.from_angle(aw) * (HUB_R - 1.2) * M
			ci.draw_rect(Rect2(p - Vector2(0.6, 0.4) * M, Vector2(1.2, 0.8) * M), Pal.ink(0.55, 1.2) if on else Pal.ink(0.06))
	# the rim's plating: twenty-four plates between the two outer rings, every other one darker
	for i in 24:
		var pa := TAU * i / 24.0
		var pb := TAU * (i + 1) / 24.0
		var plate := PackedVector2Array()
		for k in 5:
			plate.append(c + Vector2.from_angle(lerpf(pa, pb, float(k) / 4.0)) * (HUB_R - 0.4) * M)
		for k in 5:
			plate.append(c + Vector2.from_angle(lerpf(pb, pa, float(k) / 4.0)) * (HUB_R - 2.3) * M)
		ci.draw_colored_polygon(plate, Color(0.045, 0.048, 0.056) if i % 2 == 0 else Color(0.032, 0.034, 0.04))
		ci.draw_line(c + Vector2.from_angle(pa) * (HUB_R - 2.3) * M, c + Vector2.from_angle(pa) * (HUB_R - 0.4) * M, Pal.ink(ink * 0.6), lw)
	# radiator fins radiating from the inner ring, in the bays between the spokes
	for i in 4:
		var a := TAU * i / 4.0 + PI / 8.0 + PI / 4.0
		var v := Vector2.from_angle(a)
		for k in 3:
			var ro := (HUB_R2 + 2.0 + k * 2.6) * M
			ci.draw_line(c + v.rotated(-0.08) * ro, c + v.rotated(0.08) * ro, Pal.heat(0.12 + 0.1 * n, 1.0) if n >= 1 else Pal.ink(0.12), lw * 1.6)
	# the comms mast on top of the hub, its warning light blinking
	var mast := c + Vector2(0, -(HUB_R + 3.0) * M)
	ci.draw_line(mast, mast + Vector2(0, -12.0 * M), Pal.ink(ink + 0.12), lw * 1.4)
	for k in 3:
		var my := mast.y - (3.0 + k * 3.5) * M
		ci.draw_line(Vector2(mast.x - (2.0 - k * 0.5) * M, my), Vector2(mast.x + (2.0 - k * 0.5) * M, my), Pal.ink(ink * 0.8), lw)
	ci.draw_arc(mast + Vector2(2.2 * M, -9.0 * M), 2.0 * M, PI * 1.1, PI * 1.9, 14, Pal.ink(ink + 0.1), lw * 1.2, true)
	_anim(ci, t, func(cc, tt: float, _z: float):
		if fmod(tt, 1.2) < 0.1:
			_lamp(cc, mast + Vector2(0, -12.3 * M), 0.4 * M, Pal.heat(1.0, 1.8), 6.0))
	# the sixteen lamp segments round the rim: lit section by section
	var segs16: int = [0, 6, 16][n]
	for i in 16:
		var a0 := TAU * i / 16.0
		var col := Pal.heat(0.85, 1.5) if i < segs16 else Pal.ink(0.05)
		ci.draw_arc(c, (HUB_R + 3.0) * M, a0 + 0.04, a0 + TAU / 16.0 - 0.04, 6, col, lw * 2.4, true)
		if i < segs16 and not _no_lamps:
			# 109 号: a small halo (3 m threw orange blobs over the hub's rim up close)
			lamps.append([c + Vector2.from_angle(a0 + TAU / 32.0) * (HUB_R + 3.0) * M, 1.2 * M, col])
	# four docking arms off the ring, a pad at each end (a shuttle on one once it runs)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var v := Vector2.from_angle(a)
		var p0 := c + v * (HUB_R + 3.5) * M
		var p1 := c + v * (HUB_R + 12.0) * M
		ci.draw_line(p0, p1, Pal.ink(ink), lw * 1.4)
		ci.draw_circle(p1, 2.4 * M, FILL2)
		ci.draw_arc(p1, 2.4 * M, 0.0, TAU, 20, Pal.ink(ink + 0.1), lw * 1.3, true)
		ci.draw_arc(p1, 1.4 * M, 0.0, TAU, 16, Pal.ink(ink * 0.7), lw, true)
		for k in 8:
			var ca := TAU * k / 8.0
			ci.draw_line(p1 + Vector2.from_angle(ca) * 1.4 * M, p1 + Vector2.from_angle(ca) * 2.4 * M, Pal.ink(ink * 0.6), lw)
		if n >= 2 and i == 1:
			ci.draw_rect(Rect2(p1 + v * 2.5 * M - Vector2(1.5, 1.0) * M, Vector2(3.0, 2.0) * M), Pal.ink(0.4))
	# cars on the ring once it runs
	if n >= 1:
		_anim(ci, t, func(cc, tt: float, _z: float):
			for i: int in [0, 1, 2, 3, 4, 5]:
				if i >= [0, 3, 6][n]:
					break
				var a := -tt * 0.25 + TAU * i / 6.0
				var p := c + Vector2.from_angle(a) * (HUB_R + 1.0) * M
				_lamp(cc, p, 0.9 * M, Pal.heat(0.8, 1.5), 1.3))
	_anim(ci, t, func(cc, _t: float, zz: float): _plate(cc, c + Vector2(-HUB_R * M, -(HUB_R + 9.0) * M), Port.name_of("ring"), "TR-0", n, M, zz))


# ---------------------------------------------------------------- a district
static func _district(ci, c: Vector2, zone: String, M: float, z: float, t: float, n: int) -> void:
	var lw := 1.0 / z
	var ink := _ink(n)
	var r := Rect2(c - BOX * 0.5 * M, BOX * M)
	_ghost = inside == zone
	_code = "%s-%d" % [{"power": "PWR", "tug": "TUG", "process": "PRC", "trade": "TRD", "cargo": "CGO", "salvage": "SLV"}.get(zone, "Z"), n]
	match zone:
		"power": _power(ci, c, r, M, lw, t, n)
		"tug": _tug(ci, c, r, M, lw, t, n)
		"process": _process(ci, c, r, M, lw, t, n)
		"trade": _trade(ci, c, r, M, lw, t, n)
		"cargo": _cargo(ci, c, r, M, lw, t, n)
		"salvage": _salvage(ci, c, r, M, lw, t, n)
	_ghost = false
	# a beacon on the roof once the district works, the name plate, the works still to do
	if n >= 1 and zone != "salvage":
		_anim(ci, t, func(cc, tt: float, _z: float): cc.draw_circle(Vector2(r.get_center().x, r.position.y) - Vector2(0, 2.0 * M), 0.5 * M, Pal.heat(0.6 + 0.4 * sin(tt * 2.0 + c.x), 1.6)))
	var codes := {"power": "PWR", "tug": "TUG", "process": "PRC", "trade": "TRD", "cargo": "CGO", "salvage": "SLV"}
	var at := r.position + Vector2(0, -8.0 * M) if zone != "salvage" else r.position + Vector2(-20.0 * M, -2.0 * M)
	_anim(ci, t, func(cc, _t: float, zz: float): _plate(cc, at, Port.name_of(zone), "%s-%d" % [codes.get(zone, "Z"), n], n, M, zz))
	# 43 号 (player 2026-10-25: "you haven't built it, how do you know something is there?"):
	# the next stage is previewed at the district's works desk, never drawn on the station


# 43 号: what stands outside each district, in port units from the station's centre, as rects
# (the same numbers the drawing uses): nothing here may cut into another district or the hub
const VENT := Vector2(2.0, 6.0)          # the processing district's one clean exhaust, w × h
const VENT_X := 41.0                     # 56 号: over the baghouse's riser inside (x 42 m)
const ROOF_H := 3.0                      # 56 号: the processing roof's plant stays under this
const XFMR := Vector2(2.0, 7.0)          # 56 号: the furnace transformer's HV entry, x from / to
const COOLER := Vector2(12.0, 26.0)      # 56 号: the dry cooler on the roof, x from / to
static func exterior_rects(zone: String) -> Array:
	var c := district_at(zone)
	var r := Rect2(c - BOX * 0.5, BOX)
	match zone:
		"power":
			var out: Array = []
			for side: float in [-1.0, 1.0]:
				var x0 := c.x + side * (BOX.x * 0.5 + 3.0)
				out.append(Rect2(Vector2(minf(x0 - side * 3.0, x0 + side * 34.0), c.y - 6.6), Vector2(37.0, 13.2)))
			out.append(Rect2(Vector2(r.position.x, r.position.y - 26.0), Vector2(BOX.x, 26.0)))
			return out
		"tug":
			return [Rect2(r.position - Vector2(0, 6.0), Vector2(BOX.x, 6.0)), Rect2(Vector2(r.position.x - 14.0, r.position.y + 3.0), Vector2(14.0, 25.0))]
		"process":
			return [Rect2(Vector2(r.position.x + VENT_X, r.position.y - VENT.y), VENT), Rect2(Vector2(r.position.x, r.position.y - ROOF_H), Vector2(BOX.x, ROOF_H))]
		"trade":
			return [Rect2(Vector2(c.x - 10.0, r.position.y - 10.0), Vector2(20.0, 10.0)), Rect2(Vector2(r.end.x, c.y - 3.5), Vector2(72.0, 5.0))]
	return []


# a name plate like the berth's: a dark box, a heat edge, the name and a code
static func _plate(ci, at: Vector2, name: String, code: String, n: int, M: float, z: float) -> void:
	var font := Fonts.get_font("Regular")
	# drawn in screen pixels at its corner (a font size of 12 / zoom rounds to nothing zoomed far in)
	var fs := 12
	var w: float = font.get_string_size(name + "   " + code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24.0
	var r := Rect2(Vector2.ZERO, Vector2(w, 24.0))
	ci.draw_set_transform(at, 0.0, Vector2.ONE / maxf(z, 0.001))
	ci.draw_rect(r, Color(0.02, 0.022, 0.026, 0.9))
	ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Pal.heat(0.9, 1.1) if n >= 1 else Pal.ink(0.3))
	ci.draw_string(font, r.position + Vector2(10.0, 17.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.6 + 0.3 * n))
	ci.draw_string(font, r.end - Vector2(8.0 + font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 7.0), code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.ink(0.35))
	ci.draw_set_transform(Vector2.ZERO)


# a label a constant size on screen at a world point (offset in screen pixels): a font size of
# n / zoom rounds to nothing zoomed far in
static func _screen_text(ci, at: Vector2, off: Vector2, text: String, px: int, z: float, col: Color, font: Font = null) -> void:
	ci.draw_set_transform(at, 0.0, Vector2.ONE / maxf(z, 0.001))
	ci.draw_string(font if font != null else Fonts.get_font("Medium"), off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	ci.draw_set_transform(Vector2.ZERO)


# a truss between two points: two chords and a zigzag web
static func _truss(ci, a: Vector2, b: Vector2, half_w: float, step: float, col: Color, lw: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.orthogonal() * half_w
	ci.draw_line(a + side, b + side, col, lw)
	ci.draw_line(a - side, b - side, col, lw)
	var len := a.distance_to(b)
	var n := maxi(1, int(len / step))
	for i in n:
		var p0: Vector2 = a + dir * (len * i / n) + (side if i % 2 == 0 else -side)
		var p1: Vector2 = a + dir * (len * (i + 1) / n) + (side if i % 2 == 1 else -side)
		ci.draw_line(p0, p1, col, lw)


# a block with its outline and a grid of windows, lit by stage
static func _block(ci, r: Rect2, M: float, lw: float, t: float, n: int, seed: int, warm: bool = false, plain: bool = false) -> void:
	if _ghost:
		# the operator is inside: the shell as a faint outline, the interior shows through
		ci.draw_rect(r, Color(FILL.r, FILL.g, FILL.b, 0.2))
		ci.draw_rect(r, Pal.ink(_ink(n) + 0.1), false, lw)
		return
	# An industrial hull, not an office block (player 2026-10-24: "from outside it looks
	# like a building with little dots, not hard sci-fi"): plating with seams, structural
	# frames with hatched flanges, a pipe run with flanges and valve boxes along the top,
	# louvres, hatches, a single strip of portholes, a cable tray and a segmented lamp bar
	# along the bottom, hazard chevrons at the feet. The works done light the lamp bar,
	# the portholes and the process glow; a dark district only flickers.
	var ink := _ink(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# the hull throws a shadow onto whatever is behind it; its corners are chamfered
	var ch := 1.5 * M
	var shell := PackedVector2Array([r.position + Vector2(ch, 0), Vector2(r.end.x - ch, r.position.y), Vector2(r.end.x, r.position.y + ch), Vector2(r.end.x, r.end.y - ch), Vector2(r.end.x - ch, r.end.y), Vector2(r.position.x + ch, r.end.y), Vector2(r.position.x, r.end.y - ch), r.position + Vector2(0, ch)])
	var shadow := PackedVector2Array()
	for pt in shell:
		shadow.append(pt + Vector2(1.4, 1.8) * M)
	ci.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.4))
	ci.draw_colored_polygon(shell, FILL)
	# plating: panel seams, every panel a little different in tone
	var px := 6.0 * M
	var cols := int(r.size.x / px)
	var rows := 3
	for i in cols:
		for j in rows:
			var pr := Rect2(r.position + Vector2(i * px, j * r.size.y / rows), Vector2(px, r.size.y / rows))
			var tone := 0.028 + rng.randf() * 0.012
			ci.draw_rect(pr.grow(-0.15 * M), Color(tone, tone + 0.003, tone + 0.008))
			ci.draw_rect(pr, Pal.ink(ink * 0.45), false, lw)
			# rivet rows along the seams of some panels
			if rng.randf() < 0.35:
				for k in 4:
					ci.draw_circle(pr.position + Vector2((k + 0.5) * px / 4.0, 0.5 * M), 0.12 * M, Pal.ink(ink * 0.7))
	# light from above: a pale band along the top edge, a dark one along the bottom
	ci.draw_rect(Rect2(r.position + Vector2(ch, 0), Vector2(r.size.x - 2.0 * ch, 0.9 * M)), Color(0.07, 0.074, 0.084))
	ci.draw_rect(Rect2(Vector2(r.position.x + ch, r.end.y - 0.9 * M), Vector2(r.size.x - 2.0 * ch, 0.9 * M)), Color(0.012, 0.014, 0.018))
	# the hull code stencilled on the plating, big and faint
	var stencil := Fonts.get_font("SemiBold")
	ci.draw_string(stencil, r.position + Vector2(r.size.x * 0.08, r.size.y * 0.5 + 2.2 * M), _code, HORIZONTAL_ALIGNMENT_LEFT, -1, int(6.0 * M), Pal.ink(0.055))
	# structural frames every two panels: a flange with a hatched web
	var fx := r.position.x + px * 2.0
	while fx < r.end.x - px:
		var fr := Rect2(Vector2(fx - 0.6 * M, r.position.y), Vector2(1.2 * M, r.size.y))
		ci.draw_rect(fr, FILL2)
		ci.draw_rect(fr, Pal.ink(ink + 0.05), false, lw)
		_hatch(ci, fr, M, lw, Pal.ink(ink * 0.6), 1.0)
		fx += px * 2.0
	# a pipe run along the top edge: two pipes, flanges, a valve box and a vent
	for k in 2:
		var py := r.position.y - (1.0 + k * 1.1) * M
		ci.draw_line(Vector2(r.position.x + 2.0 * M, py), Vector2(r.end.x - 2.0 * M, py), Pal.ink(ink + 0.08), lw * (2.4 - k * 0.8))
		var fxp := r.position.x + 6.0 * M
		while fxp < r.end.x - 4.0 * M:
			ci.draw_line(Vector2(fxp, py - 0.45 * M), Vector2(fxp, py + 0.45 * M), Pal.ink(ink + 0.1), lw * 1.6)
			fxp += 8.0 * M
	# 56 号: a plain hull carries only its district's own roof plant, no stock valve box or vent
	if not plain:
		var vb := Rect2(r.position + Vector2(r.size.x * 0.3, -3.4 * M), Vector2(2.4, 2.0) * M)
		ci.draw_rect(vb, FILL2)
		ci.draw_rect(vb, Pal.ink(ink + 0.08), false, lw)
		if n >= 1:
			_lamp(ci, vb.get_center(), 0.5 * M, Pal.heat(0.6, 1.3), 3.0)
		else:
			ci.draw_circle(vb.get_center(), 0.5 * M, Pal.ink(0.15))
		var vent := Rect2(r.position + Vector2(r.size.x * 0.7, -2.6 * M), Vector2(3.0, 1.4) * M)
		ci.draw_rect(vent, Pal.ink(ink), false, lw)
		for k in 4:
			var vy := vent.position.y + (k + 0.5) * vent.size.y / 4.0
			ci.draw_line(Vector2(vent.position.x, vy), Vector2(vent.end.x, vy), Pal.ink(ink * 0.7), lw)
	# a strip of portholes at the upper third: lit from the left as the works go on
	# (56 号: a plain hull has none — "a building with little dots")
	var pn := 0 if plain else int(r.size.x / (3.0 * M))
	var lit_n: int = [int(pn * 0.15), int(pn * 0.55), pn][n]
	for k in pn:
		var pp := r.position + Vector2((k + 0.5) * 3.0 * M, r.size.y * 0.3)
		var on: bool = k < lit_n
		ci.draw_circle(pp, 0.5 * M, Pal.ink(ink + 0.1))
		if n == 0 and on:
			# a dark district: its few lit portholes flicker
			_anim(ci, t, func(cc, tt: float, _z: float):
				if fmod(tt * 0.6 + k * 0.7, 1.0) < 0.25:
					cc.draw_circle(pp, 0.36 * M, Color(0.02, 0.022, 0.026))
				else:
					_lamp(cc, pp, 0.36 * M, Pal.heat(0.75, 1.4) if warm else Pal.tint(Pal.AIR, 0.8, 1.3), 5.0))
		elif on:
			_lamp(ci, pp, 0.36 * M, Pal.heat(0.75, 1.4) if warm else Pal.tint(Pal.AIR, 0.8, 1.3), 5.0)
		else:
			ci.draw_circle(pp, 0.36 * M, Color(0.02, 0.022, 0.026))
	# louvre blocks and a hatch on the lower half
	for k in 2:
		var lr := Rect2(r.position + Vector2(r.size.x * (0.15 + k * 0.55), r.size.y * 0.55), Vector2(5.0, 3.2) * M)
		ci.draw_rect(lr, Color(0.02, 0.022, 0.026))
		ci.draw_rect(lr, Pal.ink(ink + 0.05), false, lw)
		for j in 5:
			var ly := lr.position.y + (j + 0.5) * lr.size.y / 5.0
			ci.draw_line(Vector2(lr.position.x + 0.3 * M, ly), Vector2(lr.end.x - 0.3 * M, ly), Pal.ink(ink * 0.9), lw)
	var hr := Rect2(r.position + Vector2(r.size.x * 0.46, r.size.y * 0.58), Vector2(2.6, 2.6) * M)
	ci.draw_rect(hr, FILL2)
	ci.draw_rect(hr, Pal.ink(ink + 0.08), false, lw)
	ci.draw_circle(hr.get_center(), 0.8 * M, Pal.ink(ink + 0.05))
	ci.draw_line(hr.get_center() + Vector2(-0.8, 0) * M, hr.get_center() + Vector2(0.8, 0) * M, Pal.ink(ink + 0.1), lw)
	ci.draw_line(hr.get_center() + Vector2(0, -0.8) * M, hr.get_center() + Vector2(0, 0.8) * M, Pal.ink(ink + 0.1), lw)
	# a conduit bundle along the base on brackets, and the segmented lamp bar under the eave
	var ty := r.end.y - 2.6 * M
	for k in 3:
		ci.draw_line(Vector2(r.position.x + 1.0 * M, ty + k * 0.35 * M), Vector2(r.end.x - 1.0 * M, ty + k * 0.35 * M), Pal.ink(ink * (0.9 - k * 0.2)), lw)
	var bx := r.position.x + 2.0 * M
	while bx < r.end.x - 1.0 * M:
		ci.draw_line(Vector2(bx, ty - 0.3 * M), Vector2(bx, ty + 1.0 * M), Pal.ink(ink + 0.05), lw * 1.4)
		bx += 4.0 * M
	var segs := 0 if plain else int(r.size.x / (4.0 * M))
	var lit_s: int = [0, segs / 2, segs][n]
	for k in segs:
		var sx := r.position.x + (k + 0.15) * 4.0 * M
		var on_s: bool = k < lit_s
		var col := (Pal.heat(0.9, 1.5) if warm else Pal.tint(Pal.AIR, 0.9, 1.5)) if on_s else Pal.ink(0.07)
		ci.draw_line(Vector2(sx, r.position.y + 1.4 * M), Vector2(sx + 2.8 * M, r.position.y + 1.4 * M), col, lw * 2.2)
		if on_s and not _no_lamps:
			lamps.append([Vector2(sx + 1.4 * M, r.position.y + 1.4 * M), 2.2 * M, col])
	if not plain:
		# an antenna cluster on the roof: a mast, a dish, a whip, a blinking warning light
		var ax := r.position.x + r.size.x * 0.86
		var ay := r.position.y
		ci.draw_line(Vector2(ax, ay), Vector2(ax, ay - 7.0 * M), Pal.ink(ink + 0.1), lw * 1.3)
		ci.draw_line(Vector2(ax - 1.2 * M, ay), Vector2(ax, ay - 2.5 * M), Pal.ink(ink * 0.7), lw)
		ci.draw_line(Vector2(ax + 1.2 * M, ay), Vector2(ax, ay - 2.5 * M), Pal.ink(ink * 0.7), lw)
		ci.draw_arc(Vector2(ax + 1.6 * M, ay - 4.5 * M), 1.6 * M, PI * 1.15, PI * 1.85, 12, Pal.ink(ink + 0.1), lw * 1.2, true)
		ci.draw_line(Vector2(ax + 1.6 * M, ay - 4.5 * M), Vector2(ax + 1.6 * M, ay - 3.0 * M), Pal.ink(ink * 0.8), lw)
		ci.draw_line(Vector2(ax - 2.0 * M, ay - 1.0 * M), Vector2(ax - 2.4 * M, ay - 6.0 * M), Pal.ink(ink * 0.7), lw)
		_anim(ci, t, func(cc, tt: float, _z: float):
			if fmod(tt, 1.6) < 0.12:
				_lamp(cc, Vector2(ax, ay - 7.2 * M), 0.3 * M, Pal.heat(1.0, 1.8), 6.0)
			else:
				cc.draw_circle(Vector2(ax, ay - 7.2 * M), 0.25 * M, Pal.heat(0.25, 1.0)))
	# hazard chevrons at both feet
	for side: float in [0.0, 1.0]:
		var cx := r.position.x + side * (r.size.x - 4.0 * M)
		for k in 4:
			var x0 := cx + k * 1.0 * M
			ci.draw_line(Vector2(x0, r.end.y), Vector2(x0 + 0.8 * M, r.end.y - 1.2 * M), Pal.heat(0.45, 1.0), lw)
	ci.draw_polyline(shell, Pal.ink(ink + 0.08), lw * 1.4)
	ci.draw_line(shell[7], shell[0], Pal.ink(ink + 0.08), lw * 1.4)
	ci.draw_polyline(PackedVector2Array([shell[0] + Vector2(0, 0.6 * M), shell[1] + Vector2(0, 0.6 * M)]), Pal.ink(0.5), lw)


static func _hatch(ci, r: Rect2, M: float, lw: float, col: Color, step: float = 2.0) -> void:
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var p0 := Vector2(maxf(x, r.position.x), r.position.y + minf(r.size.y, maxf(0.0, r.position.x - x)))
		var p1 := Vector2(minf(x + r.size.y, r.end.x), r.end.y - maxf(0.0, x + r.size.y - r.end.x))
		if p1.x > p0.x:
			ci.draw_line(p0, p1, col, lw)
		x += step * M


# 动力区: the block, two reactor domes on top, radiator fins out the back, solar wings
static func _power(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	var ink := _ink(n)
	# 48 号 (Q39: "the big radiators outside, plain to see"): either side a radiator array on the
	# coolant headers — a supply and a return pipe out along the boom, panels hung between them
	# with their tubes, warming in colour with the load the sets carry (one more panel a stage)
	for side: float in [-1.0, 1.0]:
		var x0 := r.get_center().x + side * (BOX.x * 0.5 + 3.0) * M
		var cy := r.get_center().y
		for hy: float in [-6.2, 6.2]:
			ci.draw_line(Vector2(x0 - side * 3.0 * M, cy + hy * M), Vector2(x0 + side * 34.0 * M, cy + hy * M), Pal.ink(ink + 0.1), lw * 2.2)
		ci.draw_line(Vector2(x0 - side * 3.0 * M, cy), Vector2(x0 + side * 34.0 * M, cy), Pal.ink(ink * 0.8), lw)
		var panels := 5 + n
		for i in panels:
			var px := x0 + side * (i * (33.0 / panels) + 0.6) * M
			var wpx := (33.0 / panels - 0.8) * M
			var pr := Rect2(Vector2(minf(px, px + side * wpx), cy - 5.8 * M), Vector2(wpx, 11.6 * M))
			ci.draw_rect(pr, Color(0.035, 0.04, 0.05))
			ci.draw_rect(pr, Pal.ink(ink + 0.05), false, lw)
			var tx := pr.position.x + 0.5 * M
			while tx < pr.end.x - 0.3 * M:
				ci.draw_line(Vector2(tx, pr.position.y), Vector2(tx, pr.end.y), Pal.ink(ink * 0.6), lw)
				tx += 0.9 * M
			if n >= 1:
				_anim(ci, t, func(cc, _tt: float, _z: float):
					# 100 号: as warm as the radiator loop really runs (scripts/power_works.gd)
					var frac := clampf((PowerWorksRef.rad_t - 20.0) / 95.0, 0.0, 1.0)
					cc.draw_rect(pr.grow(-0.2 * M), Pal.heat(0.02 + 0.2 * frac, 1.0)))
	_block(ci, r, M, lw, t, n, 11, true)
	# 100 号 (Q5 B): a containment dome over each reactor bay — the third an open frame of ribs
	# until stage 2 — its vent, and a lamp as warm as that unit's core
	for i in 3:
		var dc := Vector2(r.position.x + (0.8 + 4.7 + i * 9.6) * M, r.position.y)
		var built := i < 2 or n >= 2
		if built:
			ci.draw_circle(dc, 4.4 * M, FILL)
			ci.draw_arc(dc, 4.4 * M, PI, TAU, 24, Pal.ink(ink + 0.06), lw * 1.3, true)
			ci.draw_arc(dc, 3.0 * M, PI, TAU, 18, Pal.ink(ink * 0.7), lw, true)
			ci.draw_line(dc + Vector2(0, -4.4 * M), dc + Vector2(0, -6.6 * M), Pal.ink(ink), lw)
			var ui := i
			_anim(ci, t, func(cc, tt: float, _z: float):
				var q := clampf(float(PowerWorksRef.q_th[ui]) / maxf(1.0, PowerWorksRef.cap / maxf(1, PowerWorksRef.units) / PowerWorksRef.ETA), 0.0, 1.0)
				cc.draw_circle(dc + Vector2(0, -2.2 * M), 0.8 * M, Pal.heat(0.15 + 0.6 * q + 0.1 * q * sin(tt * 2.0 + ui), 1.5) if q > 0.01 else Pal.ink(0.12)))
		else:
			for k in 5:
				var a := PI + PI * (k + 0.5) / 5.0
				ci.draw_line(dc, dc + Vector2.from_angle(a) * 4.4 * M, Pal.ink(ink * 0.5), lw)
			ci.draw_arc(dc, 4.4 * M, PI, TAU, 24, Pal.ink(ink * 0.5), lw, true)
			ci.draw_line(dc + Vector2(-4.6, -0.3) * M, dc + Vector2(4.6, -0.3) * M, Pal.heat(0.45, 1.0), lw * 1.5)
	# the step-up transformers on the roof: the hub's feeders start here
	for k in 2:
		var tx := r.position.x + (36.0 + k * 5.0) * M
		var tr := Rect2(Vector2(tx, r.position.y - 2.6 * M), Vector2(3.4 * M, 2.6 * M))
		ci.draw_rect(tr, FILL2)
		ci.draw_rect(tr, Pal.ink(ink + 0.05), false, lw)
		for f in 5:
			ci.draw_line(Vector2(tx + (0.4 + f * 0.65) * M, tr.position.y + 0.3 * M), Vector2(tx + (0.4 + f * 0.65) * M, tr.end.y - 0.2 * M), Pal.ink(ink * 0.6), lw)
		for b in 3:
			var bp := Vector2(tx + (0.7 + b * 1.0) * M, tr.position.y)
			ci.draw_line(bp, bp + Vector2(0, -1.4 * M), Pal.tint(Pal.VOLT, 0.55, 1.0), lw * 1.6)
			ci.draw_circle(bp + Vector2(0, -1.4 * M), 0.22 * M, Pal.tint(Pal.VOLT, 0.7, 1.0))
	# 100 号 (Q6 C): the shore line's umbilical on the roof — stowed along it, swung up and plugged
	# into the shore line's socket while the port draws shore power; the current down the line
	var root := r.position + Vector2(56.0, -0.4) * M
	var sock := root + Vector2.from_angle(-PI * 0.42) * 9.0 * M
	var far := sock + Vector2(34.0, -40.0) * M
	ci.draw_rect(Rect2(root - Vector2(0.9, 0.4) * M, Vector2(1.8, 0.8) * M), FILL2)
	ci.draw_rect(Rect2(root - Vector2(0.9, 0.4) * M, Vector2(1.8, 0.8) * M), Pal.ink(ink + 0.08), false, lw)
	ci.draw_line(sock, far, Pal.ink(ink * 0.55), lw)
	ci.draw_circle(far, 1.1 * M, FILL2)
	ci.draw_arc(far, 1.1 * M, 0.0, TAU, 16, Pal.ink(ink + 0.05), lw, true)
	ci.draw_rect(Rect2(sock - Vector2(0.45, 0.45) * M, Vector2(0.9, 0.9) * M), FILL2)
	ci.draw_rect(Rect2(sock - Vector2(0.45, 0.45) * M, Vector2(0.9, 0.9) * M), Pal.ink(ink + 0.1), false, lw)
	_anim(ci, t, func(cc, tt: float, zz: float):
		var u := PowerWorksRef.umb
		var a := lerpf(PI, -PI * 0.42, Pal.ease_io(u))
		var tip := root + Vector2.from_angle(a) * 9.0 * M
		cc.draw_line(root, tip, Pal.ink(0.55), maxf(2.0 / zz, 0.35 * M))
		cc.draw_line(root, tip, Pal.heat(0.6, 1.0), maxf(1.0 / zz, 0.12 * M))
		cc.draw_circle(tip, 0.4 * M, Pal.tint(Pal.FLUID, 0.95, 1.4) if u >= 1.0 else Pal.heat(0.8, 1.3))
		_lamp(cc, far, 0.35 * M, Pal.heat(0.6 + 0.4 * absf(sin(tt * 2.0)), 1.5) if PowerWorksRef.shore > 0.05 else Pal.ink(0.3))
		if u >= 1.0 and PowerWorksRef.shore > 0.05:
			var L := far.distance_to(sock)
			var stp := 5.0 * M
			var off := fmod(tt * (4.0 + 2.0 * sqrt(PowerWorksRef.shore)) * M, stp)
			var d := off
			while d < L:
				FastDraw.circle(cc, far.lerp(sock, d / L), 0.3 * M, Pal.tint(Pal.VOLT, 0.95, 1.4))
				d += stp)
	# radiator fins out the top, hatched; they glow faintly once the reactors run
	for i in 5:
		var fx := r.position.x + (6.0 + i * 11.0) * M
		var fr := Rect2(Vector2(fx, r.position.y - 26.0 * M), Vector2(2.2 * M, 14.0 * M))
		ci.draw_rect(fr, FILL2)
		ci.draw_rect(fr, Pal.ink(ink), false, lw)
		_hatch(ci, fr, M, lw, Pal.heat(0.1 + 0.15 * n, 1.0) if n >= 1 else Pal.ink(ink * 0.5), 1.4)


const TugWorksRef = preload("res://scripts/tug_works.gd")
const PowerWorksRef = preload("res://scripts/power_works.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")


# 100 号: what a spoke's feeder carries now (MW): the power district's own spoke all of it, the
# others their group (the hub and the trade port on the base)
static func _feeder_mw(zone: String) -> float:
	match zone:
		"power":
			return PowerWorksRef.own + PowerWorksRef.shore
		"trade":
			return float(PowerWorksRef.groups.get("base", 0.0)) * 0.2
	return float(PowerWorksRef.groups.get(zone, 0.0))

const TradeWorksRef = preload("res://scripts/trade_works.gd")

# 拖船站: a hangar with three open bays, tugs parked in them, approach lights
static func _tug(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	var ink := _ink(n)
	_block(ci, r, M, lw, t, n, 23)
	# a gantry frame over the roof
	ci.draw_rect(Rect2(r.position - Vector2(0, 6.0 * M), Vector2(r.size.x, 6.0 * M)), Pal.ink(ink * 0.8), false, lw)
	for i in 8:
		var gx := r.position.x + i * r.size.x / 8.0
		ci.draw_line(Vector2(gx, r.position.y - 6.0 * M), Vector2(gx + r.size.x / 8.0, r.position.y), Pal.ink(ink * 0.6), lw)
	# 96 号 (user 2026-10-28: "既然叫拖船站，为什么船在外面？"): the tugs berth inside now and the
	# next hulk lies stern first in the station's mouth (scripts/tug_works.gd). The left wall shows
	# the two ways in: the tug gate above, the mouth below — a dark throat in a hazard-marked
	# frame, its doors open while a hulk lies in it — each with its lamp; a beacon on the roof
	# turns while the station works.
	var g: Vector2 = TugWorksRef.GATE * M
	var mo: Vector2 = TugWorksRef.MOUTH * M
	var x0 := r.position.x
	var y0 := r.position.y
	for span in [g, mo]:
		var th := Rect2(Vector2(x0 - 0.5 * M, y0 + span.x), Vector2(3.2 * M, span.y - span.x))
		ci.draw_rect(th, Color(0.012, 0.013, 0.016))
		ci.draw_rect(th, Pal.ink(ink + 0.12), false, lw * 1.6)
		var hy := th.position.y
		while hy < th.end.y - 0.4 * M:
			ci.draw_line(Vector2(th.position.x, hy), Vector2(th.position.x + 0.5 * M, hy + 0.5 * M), Pal.heat(0.4, 1.0), lw)
			hy += 1.1 * M
	var nn := n
	_anim(ci, t, func(cc, tt: float, zz: float):
		var on := nn >= 1
		# the mouth's doors (two leaves), the gate's leaf
		var open := smoothstep(0.0, 1.0, TugWorksRef.mouth_door)
		var half := (mo.y - mo.x) * 0.5 * (1.0 - open)
		if half > 1.0:
			cc.draw_rect(Rect2(Vector2(x0 - 0.3 * M, y0 + mo.x), Vector2(2.6 * M, half)), Color(0.09, 0.094, 0.104))
			cc.draw_rect(Rect2(Vector2(x0 - 0.3 * M, y0 + mo.y - half), Vector2(2.6 * M, half)), Color(0.09, 0.094, 0.104))
		var gl := (g.y - g.x) * (1.0 - smoothstep(0.0, 1.0, TugWorksRef.gate))
		if gl > 1.0:
			cc.draw_rect(Rect2(Vector2(x0 - 0.3 * M, y0 + g.x), Vector2(2.6 * M, gl)), Color(0.09, 0.094, 0.104))
		var busy: bool = TugWorksRef.busy() or not TugWorksRef.prep_steps.is_empty() or (TugWorksRef.gate > 0.01 and TugWorksRef.gate < 0.99)
		var amber := Pal.heat(0.35 + 0.65 * absf(sin(tt * 6.0)), 1.6)
		var calm := Pal.tint(Pal.FLUID, 0.85, 1.3) if on else Pal.ink(0.15)
		cc.draw_circle(Vector2(x0 - 1.2 * M, y0 + g.x - 0.6 * M), 0.5 * M, amber if TugWorksRef.gate > 0.01 else calm)
		cc.draw_circle(Vector2(x0 - 1.2 * M, y0 + mo.x - 0.6 * M), 0.5 * M, amber if not TugWorksRef.prep_steps.is_empty() else calm)
		# the roof beacon: a turning beam while anything in the station works
		var bp := Vector2(x0 + 8.0 * M, y0 - 6.6 * M)
		cc.draw_circle(bp, 0.6 * M, amber if busy else (Pal.ink(0.35) if on else Pal.ink(0.12)))
		if busy:
			var a := tt * 3.2
			for s2 in [-1.0, 1.0]:
				cc.draw_line(bp, bp + Vector2(cos(a) * s2 * 7.0, -absf(sin(a)) * 3.0) * M, Pal.heat(0.18, 1.4), 0.5 * M)
		_screen_text(cc, Vector2(x0 - 1.6 * M, y0 + g.x + 2.0 * M), Vector2(-70.0, 0.0), "拖船门" if Txt.zh else "TUG GATE", 11, zz, Pal.ink(0.6))
		_screen_text(cc, Vector2(x0 - 1.6 * M, y0 + mo.x + 2.0 * M), Vector2(-70.0, 0.0), "船坞口" if Txt.zh else "MOUTH", 11, zz, Pal.ink(0.6)))


# an industrial tug on its berth, bow out (left): hull, cockpit glazing forward, four thruster
# pods, the tow winch drum and the tow boom aft, its name on the side
static func _tugboat(ci, c: Vector2, M: float, lw: float, name: String, z: float) -> void:
	var hull := PackedVector2Array([c + Vector2(-5.6, 0.0) * M, c + Vector2(-4.2, -1.9) * M, c + Vector2(4.6, -1.9) * M, c + Vector2(5.2, -1.2) * M, c + Vector2(5.2, 1.2) * M, c + Vector2(4.6, 1.9) * M, c + Vector2(-4.2, 1.9) * M])
	ci.draw_colored_polygon(hull, Color(0.075, 0.08, 0.09))
	var ol := hull.duplicate()
	ol.append(hull[0])
	ci.draw_polyline(ol, Pal.ink(0.85), lw * 1.4)
	# frames and the deck line
	for x: float in [-2.5, 0.0, 2.5]:
		ci.draw_line(c + Vector2(x, -1.9) * M, c + Vector2(x, 1.9) * M, Pal.ink(0.25), lw)
	# the cockpit forward
	ci.draw_rect(Rect2(c + Vector2(-4.0, -1.0) * M, Vector2(2.0, 2.0) * M), Pal.tint(Pal.AIR, 0.45, 1.2))
	ci.draw_rect(Rect2(c + Vector2(-4.0, -1.0) * M, Vector2(2.0, 2.0) * M), Pal.ink(0.7), false, lw)
	# four thruster pods with their bells
	for p: Vector2 in [Vector2(-3.0, -2.4), Vector2(3.4, -2.4), Vector2(-3.0, 2.4), Vector2(3.4, 2.4)]:
		ci.draw_rect(Rect2(c + (p - Vector2(0.7, 0.4)) * M, Vector2(1.4, 0.8) * M), Color(0.12, 0.13, 0.14))
		ci.draw_rect(Rect2(c + (p - Vector2(0.7, 0.4)) * M, Vector2(1.4, 0.8) * M), Pal.ink(0.6), false, lw)
		var out := signf(p.y)
		ci.draw_line(c + (p + Vector2(-0.4, 0.4 * out)) * M, c + (p + Vector2(-0.6, 0.9 * out)) * M, Pal.ink(0.55), lw)
		ci.draw_line(c + (p + Vector2(0.4, 0.4 * out)) * M, c + (p + Vector2(0.6, 0.9 * out)) * M, Pal.ink(0.55), lw)
	# the tow winch drum and the boom aft
	ci.draw_circle(c + Vector2(3.0, 0.0) * M, 0.9 * M, Color(0.1, 0.1, 0.11))
	ci.draw_arc(c + Vector2(3.0, 0.0) * M, 0.9 * M, 0.0, TAU, 16, Pal.ink(0.7), lw, true)
	ci.draw_line(c + Vector2(3.9, 0.0) * M, c + Vector2(5.8, 0.0) * M, Pal.heat(0.7, 1.1), lw * 2.0)
	ci.draw_circle(c + Vector2(5.8, 0.0) * M, 0.3 * M, Pal.heat(0.8, 1.2))
	ci.draw_string(Fonts.get_font("Medium"), c + Vector2(-1.6, 0.5) * M, name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(6.0, 0.9 * M)), Pal.ink(0.8))


# 加工区: the works, three stacks, a furnace mouth, a conveyor to the hub side, radiators
static func _process(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	var ink := _ink(n)
	# 56 号 (player 2026-10-25: hard, real, nothing for show): a plain hull; on the roof only what
	# serves the plant inside — the furnace transformer's HV entry, the furnace's dry cooler, the
	# baghouse's exhaust — each moving or lit by the arc furnace's real state. No sawtooth roof.
	_block(ci, r, M, lw, t, n, 37, true, true)
	var top := r.position.y
	var x0 := r.position.x
	# the roof walkway: a handrail on posts the length of the roof
	ci.draw_line(Vector2(x0 + 1.0 * M, top - 1.1 * M), Vector2(r.end.x - 1.0 * M, top - 1.1 * M), Pal.ink(ink * 0.8), lw)
	var hx := x0 + 1.0 * M
	while hx <= r.end.x - 0.9 * M:
		ci.draw_line(Vector2(hx, top), Vector2(hx, top - 1.1 * M), Pal.ink(ink * 0.7), lw)
		hx += 3.0 * M
	# the furnace transformer's HV entry over the transformer inside: a box, three bushings, the
	# cable tray coming along the roof edge from the hub side
	var xb := Rect2(Vector2(x0 + XFMR.x * M, top - 1.6 * M), Vector2((XFMR.y - XFMR.x) * M, 1.6 * M))
	ci.draw_rect(xb, FILL2)
	ci.draw_rect(xb, Pal.ink(ink + 0.08), false, lw)
	for k in 3:
		var bx := xb.position.x + (1.0 + k * 1.5) * M
		for j in 3:
			var sy := xb.position.y - (0.35 + j * 0.4) * M
			ci.draw_line(Vector2(bx - 0.45 * M, sy), Vector2(bx + 0.45 * M, sy), Pal.ink(ink + 0.1), lw * 1.6)
		ci.draw_line(Vector2(bx, xb.position.y), Vector2(bx, xb.position.y - 1.4 * M), Pal.ink(ink + 0.05), lw)
	ci.draw_line(Vector2(xb.end.x, top - 0.5 * M), Vector2(r.end.x - 1.0 * M, top - 0.5 * M), Pal.ink(ink * 0.9), lw * 2.0)
	ci.draw_line(Vector2(xb.end.x, top - 0.25 * M), Vector2(r.end.x - 1.0 * M, top - 0.25 * M), Pal.ink(ink * 0.6), lw)
	var lamp_at := Vector2(xb.end.x - 0.6 * M, xb.position.y + 0.6 * M)
	_anim(ci, t, func(cc, _tt: float, _z: float):
		if furnace_on():
			_lamp(cc, lamp_at, 0.3 * M, Pal.heat(0.9, 1.6), 4.0)
		else:
			cc.draw_circle(lamp_at, 0.25 * M, Pal.ink(0.18)))
	# the dry cooler: a steel frame, a coil bank, three fans that turn while the furnace runs
	var cr := Rect2(Vector2(x0 + COOLER.x * M, top - 2.6 * M), Vector2((COOLER.y - COOLER.x) * M, 2.6 * M))
	ci.draw_rect(cr, Color(0.035, 0.04, 0.05))
	ci.draw_rect(cr, Pal.ink(ink + 0.06), false, lw)
	var fx := cr.position.x + 0.6 * M
	while fx < cr.end.x - 0.4 * M:
		ci.draw_line(Vector2(fx, cr.position.y + 1.1 * M), Vector2(fx, cr.end.y - 0.2 * M), Pal.ink(ink * 0.5), lw)
		fx += 0.6 * M
	var fans: Array = []
	for k in 3:
		fans.append(Vector2(cr.position.x + (k + 0.5) * cr.size.x / 3.0, cr.position.y + 0.55 * M))
	_anim(ci, t, func(cc, tt: float, _z: float):
		_turn_fans(tt)
		for fc: Vector2 in fans:
			cc.draw_line(fc - Vector2(1.9 * M, 0), fc + Vector2(1.9 * M, 0), Pal.ink(ink + 0.08), lw * 1.4)
			# a fan seen edge-on: the blade tips sweep across its width
			for b in 3:
				var s := cos(_fan + b * TAU / 3.0)
				cc.draw_line(fc + Vector2(s * 1.7 * M, -0.35 * M), fc + Vector2(s * 1.7 * M, 0.0), Pal.ink(ink + 0.12), lw * 1.6))
	# the baghouse's exhaust over its riser inside; a warm lip while the furnace runs, no plume
	var vr := Rect2(Vector2(x0 + VENT_X * M, top - VENT.y * M), VENT * M)
	ci.draw_rect(vr, FILL2)
	ci.draw_rect(vr, Pal.ink(ink + 0.04), false, lw)
	ci.draw_line(vr.position + Vector2(-0.4 * M, 0), Vector2(vr.end.x + 0.4 * M, vr.position.y), Pal.ink(ink + 0.08), lw * 1.5)
	ci.draw_line(Vector2(vr.position.x, vr.position.y + 2.0 * M), Vector2(vr.end.x, vr.position.y + 2.0 * M), Pal.ink(ink * 0.6), lw)
	_anim(ci, t, func(cc, _tt: float, _z: float):
		if furnace_on():
			cc.draw_line(vr.position + Vector2(0.2 * M, 0.15 * M), Vector2(vr.end.x - 0.2 * M, vr.position.y + 0.15 * M), Pal.heat(0.55, 1.3), lw * 2.0))


# 56 号: the arc furnace is heating on power the grid gave it (Grid.loads' "run")
# 56 号: the parts the berth repairs can use, really held
static func parts_held() -> int:
	if not Career.usable() or Career.data.is_empty():
		return 0
	return Career.data.get("parts", []).size()


static var test_furnace := false      # tests: draw the roof as if the furnace heats


static func furnace_on() -> bool:
	if test_furnace:
		return true
	if not Career.usable() or Career.data.is_empty():
		return false
	var heat: Dictionary = Career.data.get("industrial_heat", {})
	return str(heat.get("state", "")) == "processing" and not heat.get("grid", {}).is_empty()


static var _fan := 0.0
static var _fan_t := -1.0


# the cooler's fans: they turn only while the furnace runs, and stop where they are
static func _turn_fans(tt: float) -> void:
	if _fan_t >= 0.0 and tt > _fan_t and furnace_on():
		_fan = fmod(_fan + (tt - _fan_t) * 9.0, TAU)
	_fan_t = tt


static func fan_angle() -> float:
	return _fan


# 贸易港: the hall, a long pier out to the right with three docking arms, freighters at them
static func _trade(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	var ink := _ink(n)
	_block(ci, r, M, lw, t, n, 41)
	# a dome on the hall (the exchange)
	var dc := Vector2(r.get_center().x, r.position.y)
	ci.draw_circle(dc, 10.0 * M, FILL)
	ci.draw_arc(dc, 10.0 * M, PI, TAU, 28, Pal.ink(ink + 0.06), lw * 1.3, true)
	for i in 5:
		var a := PI + PI * (i + 0.5) / 5.0
		ci.draw_line(dc, dc + Vector2.from_angle(a) * 10.0 * M, Pal.ink(ink * 0.5), lw)
	# the pier: two rails with ties, running out to the right
	var py := r.get_center().y
	var px0 := r.end.x
	var px1 := r.end.x + 72.0 * M
	ci.draw_line(Vector2(px0, py - 1.5 * M), Vector2(px1, py - 1.5 * M), Pal.ink(ink + 0.04), lw * 1.3)
	ci.draw_line(Vector2(px0, py + 1.5 * M), Vector2(px1, py + 1.5 * M), Pal.ink(ink + 0.04), lw * 1.3)
	var tx := px0
	while tx < px1:
		ci.draw_line(Vector2(tx, py - 1.5 * M), Vector2(tx, py + 1.5 * M), Pal.ink(ink * 0.6), lw)
		tx += 4.0 * M
	# the pier's edge lights, steady once the trade port is open (43 号: no running lights, no
	# stand-in freighters, no empty sheds; the real freighters berth at the cargo pier)
	for k in 18:
		var lp := Vector2(px0 + (2.0 + k * 4.0) * M, py - 3.5 * M)
		ci.draw_circle(lp, 0.4 * M, Pal.tint(Pal.AIR, 0.55, 1.2) if n >= 1 else Pal.ink(0.07))
	# 98 号: the east wall's two visitors' airlocks and the lighter's port below (scripts/trade_works.gd),
	# each a dark opening in a hazard-marked frame; the dome's ribs and its beacon, turning while
	# the hand-over dock or a visitor is busy
	for span in [TradeWorksRef.LOCKS[0], TradeWorksRef.LOCKS[1], TradeWorksRef.PORT]:
		var th := Rect2(Vector2(r.end.x - 2.6 * M, r.position.y + span.x * M), Vector2(3.0 * M, (span.y - span.x) * M))
		ci.draw_rect(th, Color(0.012, 0.013, 0.016))
		ci.draw_rect(th, Pal.ink(ink + 0.12), false, lw * 1.6)
		var hy := th.position.y
		while hy < th.end.y - 0.4 * M:
			ci.draw_line(Vector2(th.end.x - 0.5 * M, hy), Vector2(th.end.x, hy + 0.5 * M), Pal.heat(0.4, 1.0), lw)
			hy += 1.1 * M
	for i in 7:
		var a2 := PI + PI * (i + 0.5) / 7.0
		ci.draw_line(dc + Vector2.from_angle(a2) * 6.0 * M, dc + Vector2.from_angle(a2) * 10.0 * M, Pal.ink(ink * 0.35), lw)
	ci.draw_arc(dc, 6.0 * M, PI, TAU, 24, Pal.ink(ink * 0.5), lw, true)
	var nn := n
	_anim(ci, t, func(cc, tt: float, _z: float):
		var busy: bool = (not TradeWorksRef.job.is_empty() and not bool(TradeWorksRef.job.get("done", true))) or not TradeWorksRef.visitors.is_empty()
		var bp := dc + Vector2(0.0, -10.6 * M)
		cc.draw_circle(bp, 0.6 * M, Pal.heat(0.35 + 0.65 * absf(sin(tt * 6.0)), 1.6) if busy else (Pal.tint(Pal.FLUID, 0.7, 1.2) if nn >= 1 else Pal.ink(0.12)))
		if busy:
			var a3 := tt * 3.0
			for s2 in [-1.0, 1.0]:
				cc.draw_line(bp, bp + Vector2(cos(a3) * s2 * 8.0, -absf(sin(a3)) * 3.0) * M, Pal.heat(0.16, 1.4), 0.5 * M)
		for i2 in 2:
			var lk: Vector2 = TradeWorksRef.LOCKS[i2]
			var used := false
			for e in TradeWorksRef.visitors.values():
				if int(e.lock) == i2 and float(e.g) >= 1.0:
					used = true
			cc.draw_circle(Vector2(r.end.x + 1.2 * M, r.position.y + (lk.x - 0.6) * M), 0.45 * M, Pal.tint(Pal.FLUID, 0.9, 1.3) if used else (Pal.ink(0.3) if nn >= 1 else Pal.ink(0.1))))


# 货运区: the depot, container stacks in rows, a gantry crane over them, a trolley running
static func _cargo(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	_block(ci, r, M, lw, t, n, 53)
	# 43 号 (Q42: "no unrelated container loops"): no stand-in container yard or idle gantry here;
	# the real stock is shown in the depot and at the cargo pier (scripts/freight_pier.gd)


# 船坞区: the player's berth sits in it (drawn by the dock itself); round it the district's
# quay truss, the workshop block to the left, the second berth's frame to the right (dashed
# until the footing is built at stage 2), pit cranes and floodlight masts along the quay.
# Here the units are metres (m), to line up with the berth.
static func _salvage(ci, c: Vector2, r: Rect2, M: float, lw: float, t: float, n: int) -> void:
	var ink := _ink(n)
	var m := M / PM
	var o := c - Dock.centre() * m        # world px of the berth's (0, 0)
	var fy: float = Dock.FLOOR_Y
	var x1: float = Dock.FLOOR_X1
	# the quay truss under the whole district, pylons down from it
	var q0 := o + Vector2(-70.0, fy + 5.0) * m
	var q1 := o + Vector2(x1 + 125.0, fy + 5.0) * m
	_truss(ci, q0, q1, 2.0 * m, 4.0 * m, Pal.ink(ink + 0.04), lw)
	var px := -60.0
	while px < x1 + 120.0:
		var top := o + Vector2(px, fy + 7.0) * m
		ci.draw_line(top, top + Vector2(0, 14.0 * m), Pal.ink(ink), lw * 1.2)
		ci.draw_line(top + Vector2(-3.0 * m, 14.0 * m), top + Vector2(3.0 * m, 14.0 * m), Pal.ink(ink), lw)
		px += 24.0
	# 56 号: the workshop to the left is the parts store the berth repairs draw on — a plain hull,
	# its roll door open, inside it one crate per part really held (up to eight), the count on the door
	var wb := Rect2(o + Vector2(-68.0, -16.0) * m, Vector2(50.0, fy + 19.0) * m)
	_block(ci, wb, m * 1.3, lw, t, n, 67, true, true)
	var door := Rect2(wb.end - Vector2(18.0, 9.0) * m, Vector2(14.0, 9.0) * m)
	ci.draw_rect(door, Color(0.02, 0.022, 0.028))
	ci.draw_rect(door, Pal.ink(ink + 0.08), false, lw * 1.3)
	# the rolled-up door in its box over the opening
	ci.draw_rect(Rect2(door.position - Vector2(0.4, 1.4) * m, Vector2(door.size.x + 0.8 * m, 1.4 * m)), FILL2)
	ci.draw_rect(Rect2(door.position - Vector2(0.4, 1.4) * m, Vector2(door.size.x + 0.8 * m, 1.4 * m)), Pal.ink(ink + 0.05), false, lw)
	_anim(ci, t, func(cc, _tt: float, zz: float):
		var held := parts_held()
		for k in mini(held, 8):
			var col := k % 4
			var row := k / 4
			var cr := Rect2(door.position + Vector2(0.6 + col * 3.3, door.size.y / m - 2.6 - row * 2.7) * m, Vector2(2.9, 2.4) * m)
			cc.draw_rect(cr, Color(0.11, 0.1, 0.085))
			cc.draw_rect(cr, Pal.ink(0.45), false, lw)
			cc.draw_line(cr.position + Vector2(0, 0.8 * m), Vector2(cr.end.x, cr.position.y + 0.8 * m), Pal.ink(0.3), lw)
		var font := Fonts.get_font("Regular")
		_screen_text(cc, door.position + Vector2(0.2 * m, -1.9 * m), Vector2.ZERO, Ops.w("零件库 · %d 件", "PARTS STORE · %d") % held, 12, zz, Pal.ink(0.75), font))
	# the second berth's frame to the right (G7): only once its footing is built (43 号: no ghost)
	var fr := Rect2(o + Vector2(x1 + 30.0, -15.0) * m, Vector2(70.0, fy + 15.0) * m)
	if n >= 2:
		ci.draw_rect(fr, Pal.ink(ink), false, lw * 1.3)
		for gy: float in [fr.position.y, fr.end.y]:
			_truss(ci, Vector2(fr.position.x, gy), Vector2(fr.end.x, gy), 1.0 * m, 3.0 * m, Pal.ink(ink * 0.8), lw)
	# 56 号: no idle pit cranes (the berth has its own); the floodlight masts along the quay light it
	for mx: float in [-40.0, x1 + 60.0, x1 + 100.0]:
		var base := o + Vector2(mx, fy + 5.0) * m
		ci.draw_line(base, base + Vector2(0, -30.0 * m), Pal.ink(ink), lw)
		var lp := base + Vector2(0, -30.0 * m)
		# 46 号: a lamp head the size of a lamp (the big white discs were too much)
		ci.draw_rect(Rect2(lp - Vector2(0.6, 0.25) * m, Vector2(1.2, 0.5) * m), Pal.ink(0.4))
		ci.draw_circle(lp + Vector2(0, 0.3 * m), 0.3 * m, Pal.ink(0.45, 1.1) if n >= 1 else Pal.ink(0.1))


# ARK-01 off the port: a long hull, two habitat rings, the engine block, the bow; dark
static func _ark(ci, ac: Vector2, M: float, z: float, t: float) -> void:
	var lw := 1.0 / z
	var hull := Rect2(ac + Vector2(-50.0, -2.5) * M, Vector2(100.0, 5.0) * M)
	ci.draw_rect(hull, Color(0.03, 0.032, 0.038))
	ci.draw_rect(hull, Pal.ink(0.14), false, lw)
	# the spine's frames
	var fx := hull.position.x + 4.0 * M
	while fx < hull.end.x:
		ci.draw_line(Vector2(fx, hull.position.y), Vector2(fx, hull.end.y), Pal.ink(0.06), lw)
		fx += 5.0 * M
	# two habitat rings, with their hubs and spokes
	for rx: float in [-18.0, 10.0]:
		var rc := ac + Vector2(rx * M, 0)
		ci.draw_arc(rc, 12.0 * M, 0.0, TAU, 48, Pal.ink(0.13), lw * 1.5, true)
		ci.draw_arc(rc, 10.0 * M, 0.0, TAU, 48, Pal.ink(0.07), lw, true)
		_anim(ci, t, func(cc, tt: float, zz: float):
			for i in 6:
				var a := TAU * i / 6.0 + tt * 0.02
				cc.draw_line(rc, rc + Vector2.from_angle(a) * 12.0 * M, Pal.ink(0.07), 1.0 / zz))
	# the engine block and three bells at the stern, the bow sensor spike
	var eb := Rect2(ac + Vector2(-58.0, -4.0) * M, Vector2(9.0, 8.0) * M)
	ci.draw_rect(eb, Color(0.03, 0.032, 0.038))
	ci.draw_rect(eb, Pal.ink(0.13), false, lw)
	for e: float in [-2.6, 0.0, 2.6]:
		ci.draw_line(eb.position + Vector2(0, (4.0 + e) * M), eb.position + Vector2(-5.0 * M, (4.0 + e * 1.4) * M), Pal.ink(0.12), lw)
	ci.draw_line(ac + Vector2(50.0 * M, 0), ac + Vector2(64.0 * M, -3.0 * M), Pal.ink(0.12), lw)
	ci.draw_line(ac + Vector2(50.0 * M, 0), ac + Vector2(64.0 * M, 3.0 * M), Pal.ink(0.12), lw)
	# one running light still blinking, slow
	_anim(ci, t, func(cc, tt: float, zz: float):
		cc.draw_circle(ac + Vector2(64.0 * M, 0), 0.7 * M, Pal.heat(0.6 if fmod(tt, 3.0) < 0.2 else 0.08, 1.4))
		_screen_text(cc, ac + Vector2(-50.0 * M, -16.0 * M), Vector2.ZERO, "ARK-01", 11, zz, Pal.ink(0.2), Fonts.get_font("Regular")))


static func _dashed_ellipse(ci, c: Vector2, r: Vector2, segs: int, col: Color, lw: float) -> void:
	for i in segs:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var pts := PackedVector2Array()
		for k in 4:
			var a: float = lerpf(a0, a1, float(k) / 3.0)
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		ci.draw_polyline(pts, col, lw)


static func _dashed_rect(ci, r: Rect2, M: float, col: Color, lw: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / (2.0 * M)))
		for k in n:
			if k % 2 == 0:
				ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, lw)
