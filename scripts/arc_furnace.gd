extends "res://scripts/smelter.gd"
# The processing district's own furnace (design/…/36 号; player 2026-10-25: "it is the same as
# the furnace under the berth — design another one"): an electric arc furnace. The process is
# the smelter's own (heat balance, melt, sample, tap, meter: one truth for the books and the
# tests); only the machine is different, and drawn so you can tell it at a glance:
#   a charging basket hangs over the open roof; the roof swings aside to charge and back to melt;
#   three graphite electrodes on their arms come down through the roof and strike arcs on the
#   scrap, bore in as it melts and ride up as the bath rises; the vessel rolls on its rockers to
#   tap from its eccentric bottom tap hole into the mould line.
# Only the big parts are named; the rest is named when you are close.

const SHELL_R := 2.3           # m: the vessel's half width
const ROOF_Y := 3.55           # m below the line: the roof ring
const HEARTH_Y := 6.7          # the hearth's bottom
const MAST_X := -3.4           # the electrode mast
var crane_basket := false      # 101 号: the hall crane carries the basket (scripts/process_art.gd); none drawn here
# 101 号: the vessel, its roof, the mast and the arms as meshes built once (scripts/mesh_pen.gd) and
# placed each frame — finer and far cheaper than the polygons they were; draw() then draws only the
# bath, the scrap, the mould line and the pour
var meshes := false
const MeshPen = preload("res://scripts/mesh_pen.gd")
static var _built := {}


static func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _built.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_built[key] = pen.mesh()
	return _built[key]


func _poly(ci, pts: Array, fill_c: Color, edge: Color = Color(0, 0, 0, 0), w: float = 1.0) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, fill_c)
	if edge.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, edge, w)


# the electrodes' tips: up out of the roof when idle, down on the scrap while melting, riding the bath
func tip_y() -> float:
	if power < 0.5 or phase in ["tilt", "pour", "back"]:
		return ROOF_Y - 1.4
	var surface := HEARTH_Y - 0.4 - 2.2 * clampf((m_l + m_s) / CAP, 0.0, 1.0)
	return surface - 0.25


# ---------------------------------------------------------------- 128 号 第 4 段 浇铸
const CastArt = preload("res://scripts/cast_art.gd")
const Works = preload("res://scripts/process_works.gd")
const SEAT_DX := 2.95           # the seated block's left, from the axis (FILL_X + 0.3: the trumpet under the stream)
const SEAT_DY := 5.5            # its top, below the line (F + DY)
const ROLL_X0 := 5.4            # the roller line's start
const STRIP_T := 900.0          # °C: the pieces are pushed out of the block once this cool
var _strip_t0 := -1.0           # this object's clock when the pieces were pushed out (-1: still in)


func piece_t() -> float:
	return float(ProcessLine.SPEC.get(mould, ProcessLine.SPEC.billet).t)


# a cavity in world metres (x from the axis's world x, y from the block's top)
func _cav_world(k: int, m: String) -> Rect2:
	var cav := CastArt.cavities(m)
	var r: Rect2 = cav[k % cav.size()][0]
	return Rect2(Vector2(X + SEAT_DX, 0.0) + r.position, r.size)


func _cast_line(ci, F: float, lw: float, zoom: float) -> void:
	var seat := str(Works.seat_m) if not Career.data.is_empty() else "billet"
	var o := Vector2(X + SEAT_DX, F + SEAT_DY) * M
	# the roller line: its bed, the rollers turning as the line indexes
	_rect(ci, ROLL_X0 - 0.1, 5.9, LINE_X1 + 0.4, 6.35, F, Color(0.05, 0.052, 0.058), Pal.ink(0.55), lw)
	var rx := ROLL_X0 + 0.15
	while rx < LINE_X1 + 0.2:
		var c := Vector2(X + rx, F + 5.92) * M
		ci.draw_circle(c, 0.11 * M, Color(0.16, 0.165, 0.18))
		ci.draw_arc(c, 0.11 * M, 0.0, TAU, 10, Pal.ink(0.45), lw)
		ci.draw_line(c, c + Vector2.from_angle(line_off / 0.11) * 0.1 * M, Pal.ink(0.5), lw)
		rx += 0.42
	# the seat: a cradle with its locating pins, the spray header over it
	_rect(ci, SEAT_DX - 0.5, 6.3, SEAT_DX + 2.4, 6.55, F, Color(0.075, 0.078, 0.088), Pal.ink(0.5), lw)
	for px: float in [SEAT_DX + 0.3, SEAT_DX + 1.9]:
		_rect(ci, px - 0.08, 6.18, px + 0.08, 6.3, F, Color(0.3, 0.24, 0.16), Pal.ink(0.4), lw)
	var pipe := Color(0.35, 0.45, 0.55)
	ci.draw_line(Vector2(X + SEAT_DX + 0.05, F + SEAT_DY - 0.45) * M, Vector2(X + SEAT_DX + 2.25, F + SEAT_DY - 0.45) * M, pipe, maxf(1.0, 0.06 * M))
	ci.draw_line(Vector2(X + SEAT_DX + 2.25, F + SEAT_DY - 0.45) * M, Vector2(X + SEAT_DX + 2.25, F + SEAT_DY - 1.4) * M, pipe, maxf(1.0, 0.06 * M))
	var k0 := 0.0
	while k0 < 2.1:
		ci.draw_line(Vector2(X + SEAT_DX + 0.15 + k0, F + SEAT_DY - 0.45) * M, Vector2(X + SEAT_DX + 0.15 + k0, F + SEAT_DY - 0.36) * M, pipe, maxf(1.0, 0.03 * M))
		k0 += 0.3
	# this heat's pieces, the first cast first
	var n := CastArt.cavities(seat).size() if seat != "" else 1
	var pt := piece_t()
	var cooling := false
	var coolest := 9999.0
	for ig in ingots:
		coolest = minf(coolest, float(ig[1]))
	if ingots.is_empty() and cast_t <= 0.0:
		_strip_t0 = -1.0
	elif _strip_t0 < 0.0 and phase not in ["tilt", "pour"] and not ingots.is_empty() and coolest < STRIP_T:
		_strip_t0 = t
	var s := t - _strip_t0 if _strip_t0 >= 0.0 else -1.0
	var lift := clampf(s / 0.6, 0.0, 1.0) * 0.55 if s >= 0.0 else 0.0
	var slide := BenchFx.e_io(clampf((s - 0.6) / 1.0, 0.0, 1.0)) if s >= 0.0 else 0.0
	var levels: Array = []
	var temps: Array = []
	if seat != "" and slide <= 0.0:
		for k in n:
			if k < ingots.size():
				levels.append(clampf(float(ingots[k][2]) / pt, 0.0, 1.0))
				temps.append(float(ingots[k][1]))
				cooling = cooling or float(ingots[k][1]) > 300.0
			elif k == ingots.size() and cast_t > 0.0:
				levels.append(clampf(cast_t / pt, 0.0, 1.0))
				temps.append(T - 60.0)
			else:
				levels.append(0.0)
				temps.append(25.0)
	if seat != "":
		CastArt.trumpet(ci, o, M, 1.0 if phase == "pour" and gate > 0.2 else 0.0)
		CastArt.block(ci, seat, o, M, levels, temps, lift, 2 if zoom >= 0.7 else (1 if zoom >= 0.4 else 0), 1.0, 1.0 if cooling and phase != "pour" and s < 0.0 else 0.0, t)
	# out of the block: the pusher's plate drives them onto the rollers, then they go with the line
	var count := ingots.size()
	for k in count:
		var ig: Array = ingots[k]
		var on_roll := slide > 0.0 or k >= n or seat == ""
		if not on_roll:
			continue
		var cw := _cav_world(k, seat if seat != "" else "billet")
		var lv := clampf(float(ig[2]) / pt, 0.15, 1.0)
		var hgt := cw.size.y * lv
		var wd := cw.size.x
		var base := X + ROLL_X0 + 0.12 + float(count - 1 - k) * (wd + 0.1)
		var phys := X + FILL_X + line_off - float(ig[0]) - wd * 0.5
		var to := maxf(base, phys)
		var x0 := lerpf(cw.position.x, to, slide) if k < n and seat != "" else to
		var y1 := lerpf(F + SEAT_DY + cw.end.y - lift, F + 5.81, slide) if k < n and seat != "" else F + 5.81
		if x0 > X + LINE_X1 + 0.2:
			continue
		var pr := Rect2(Vector2(x0, y1 - hgt) * M, Vector2(wd, hgt) * M)
		var tc := float(ig[1])
		var col := glow_col(tc) if tc > 480.0 else Color(0.26, 0.26, 0.28).lerp(glow_col(480.0), clampf((tc - 200.0) / 280.0, 0.0, 1.0))
		ci.draw_rect(pr, col)
		ci.draw_rect(pr, Pal.ink(0.55), false, lw)
		if tc < 520.0:
			# the scale's dark skin along the top
			ci.draw_line(pr.position + Vector2(0, 0.04 * M), pr.position + Vector2(pr.size.x, 0.04 * M), Pal.ink(0.3), lw)
	# the pusher: its plate travels with the pieces and back, its rod out of the cylinder on the left
	if s >= 0.0 and s < 2.4 and seat != "":
		var px2 := X + SEAT_DX - 0.35 + 2.4 * slide * (1.0 - clampf((s - 1.6) / 0.8, 0.0, 1.0))
		ci.draw_line(Vector2(X + SEAT_DX - 0.7, F + SEAT_DY + 0.15) * M, Vector2(px2 - 0.08, F + SEAT_DY + 0.15) * M, Color(0.6, 0.62, 0.66), maxf(1.0, 0.05 * M))
		_rect(ci, px2 - 0.08, SEAT_DY - 0.1 + 0.55 * (1.0 - slide), px2, SEAT_DY + 0.45, F, Color(0.85, 0.62, 0.2), Pal.ink(0.6), lw)
	# the lift at the line's end that takes them to the trolley
	_rect(ci, LINE_X1 - 0.2, 5.0, LINE_X1 + 0.4, 5.9, F, Color(0.07, 0.072, 0.08), Pal.ink(0.45), lw)


func draw(ci, F: float, mx: float, font: Font, font_b: Font, zoom: float, txt: Callable) -> void:
	F += DY
	var edge := Pal.ink(0.55)
	var lw := 1.4 / maxf(zoom, 0.05)
	var shapes: bool = not ci.no_shapes
	if shapes:
		# ---- 128 号 第 4 段: the mould block in its seat under the tap hole, the roller line to the right
		_cast_line(ci, F, lw, zoom)
		# ---- the vessel on its rockers (it tilts round the trunnion to tap)
		var shell := [] if meshes else [body_pt(-SHELL_R, ROOF_Y + 0.2, F), body_pt(SHELL_R, ROOF_Y + 0.2, F), body_pt(SHELL_R, HEARTH_Y - 1.0, F), body_pt(SHELL_R - 0.7, HEARTH_Y, F), body_pt(-SHELL_R + 0.7, HEARTH_Y, F), body_pt(-SHELL_R, HEARTH_Y - 1.0, F)]
		if not meshes:
			_poly(ci, shell, STEEL, edge, lw)
			# water-cooled panels on the upper shell, refractory below
			for k in 9:
				var px := -SHELL_R + 0.25 + k * (2.0 * SHELL_R - 0.5) / 8.0
				ci.draw_line(body_pt(px, ROOF_Y + 0.35, F), body_pt(px, ROOF_Y + 1.5, F), Pal.ink(0.22), lw)
			_poly(ci, [body_pt(-SHELL_R + 0.25, ROOF_Y + 1.6, F), body_pt(SHELL_R - 0.25, ROOF_Y + 1.6, F), body_pt(SHELL_R - 0.25, HEARTH_Y - 1.05, F), body_pt(SHELL_R - 0.85, HEARTH_Y - 0.25, F), body_pt(-SHELL_R + 0.85, HEARTH_Y - 0.25, F), body_pt(-SHELL_R + 0.25, HEARTH_Y - 1.05, F)], MGO)
		# the bath, and the scrap still standing in it
		var fill_k := clampf(m_l / CAP, 0.0, 1.0)
		if fill_k > 0.001:
			var by := HEARTH_Y - 0.25 - 2.0 * fill_k
			_poly(ci, [body_pt(-SHELL_R + 0.5, by, F), body_pt(SHELL_R - 0.5, by, F), body_pt(SHELL_R - 0.85, HEARTH_Y - 0.25, F), body_pt(-SHELL_R + 0.85, HEARTH_Y - 0.25, F)], glow_col(T, 0.95))
			if meshes:
				# 101 号: the bath's depth — cooler towards the hearth, the slag floating on it, a white-hot skin
				var deep := HEARTH_Y - 0.25 - 0.9 * fill_k
				_poly(ci, [body_pt(-SHELL_R + 0.62, deep, F), body_pt(SHELL_R - 0.62, deep, F), body_pt(SHELL_R - 0.85, HEARTH_Y - 0.25, F), body_pt(-SHELL_R + 0.85, HEARTH_Y - 0.25, F)], Color(glow_col(T - 140.0, 0.9), 0.55))
				_poly(ci, [body_pt(-SHELL_R + 0.5, by, F), body_pt(SHELL_R - 0.5, by, F), body_pt(SHELL_R - 0.52, by + 0.16, F), body_pt(-SHELL_R + 0.52, by + 0.16, F)], Color(0.32, 0.18, 0.1, 0.85))
				ci.draw_line(body_pt(-SHELL_R + 0.55, by + 0.17, F), body_pt(SHELL_R - 0.55, by + 0.17, F), Color(1.0, 0.97, 0.85, 0.9), 0.05 * M)
		var sk := clampf(m_s / 2.0, 0.0, 1.0)
		if sk > 0.001:
			var base := HEARTH_Y - 0.3 - 2.0 * fill_k
			var pts: Array = []
			for k in 9:
				var sx := -1.5 + k * 3.0 / 8.0
				pts.append(body_pt(sx, base - sk * (0.6 + 0.5 * absf(sin(k * 2.3))), F))
			pts.append(body_pt(1.5, base, F))
			pts.append(body_pt(-1.5, base, F))
			_poly(ci, pts, Color(0.22, 0.21, 0.2), Pal.ink(0.4), lw)
		if not meshes:
			# the eccentric bottom tap hole, on the side towards the moulds
			_poly(ci, [body_pt(SHELL_R - 0.3, HEARTH_Y - 0.6, F), body_pt(SHELL_R + 0.5, HEARTH_Y - 0.6, F), body_pt(SHELL_R + 0.5, HEARTH_Y, F), body_pt(SHELL_R - 0.3, HEARTH_Y, F)], STEEL_HI, edge, lw)
			# rockers and the tilt cylinder
			ci.draw_arc(body_pt(0.0, HEARTH_Y + 0.1, F), 1.6 * M, 0.25 * PI + tilt, 0.75 * PI + tilt, 12, Pal.ink(0.5), 2.0 * lw)
			_rect(ci, -2.6, HEARTH_Y + 0.6, 2.6, HEARTH_Y + 0.9, F, Color(0.06, 0.062, 0.07), edge, lw)
			# the roof: over the vessel to melt, swung aside (up and to the mast) to charge
			var rx := -2.6 * hood
			var ry := ROOF_Y - 0.9 * hood
			_poly(ci, [Vector2(X + rx - SHELL_R - 0.1, F + ry) * M, Vector2(X + rx + SHELL_R + 0.1, F + ry) * M, Vector2(X + rx + 1.2, F + ry - 0.7) * M, Vector2(X + rx - 1.2, F + ry - 0.7) * M], Color(0.075, 0.078, 0.088), edge, lw)
			# ---- the electrode mast and its arms
			_rect(ci, MAST_X - 0.25, -1.8, MAST_X + 0.25, HEARTH_Y + 0.2, F, STEEL_HI, edge, lw)
			var ty := tip_y()
			var arm_y := ty - 3.4
			_rect(ci, MAST_X, arm_y - 0.35, 0.9, arm_y, F, STEEL, edge, lw)
			for k in 3:
				var ex := -0.7 + 0.7 * k
				# the graphite column, the clamp on the arm, the bus tubes
				_rect(ci, ex - 0.17, arm_y, ex + 0.17, ty, F, Color(0.3, 0.3, 0.32), Pal.ink(0.75), lw)
				_rect(ci, ex - 0.3, arm_y - 0.5, ex + 0.3, arm_y - 0.05, F, COPPER.darkened(0.35), edge, lw)
				ci.draw_line(Vector2(X + MAST_X + 0.3, F + arm_y - 0.6 + k * 0.12) * M, Vector2(X + ex, F + arm_y - 0.5) * M, COPPER.darkened(0.2), lw)
		# the charging basket over the roof: its load is the scrap waiting to go in
		# (the crane brings it over the furnace only while the roof is swung aside to charge)
		var fl := clampf(fill(), 0.0, 1.0)
		var bx := 0.0
		if hood > 0.05 and not crane_basket:
			_basket(ci, F, bx, fl, lw)
		# the pour: from the tap hole down into the mould under it
		if phase == "pour" and gate > 0.2:
			var from := body_pt(SHELL_R + 0.1, HEARTH_Y, F)
			ci.draw_line(from, Vector2(X + FILL_X + 0.05, F + 5.0) * M, glow_col(T, 0.9), 0.16 * M)
		# the probe lance, coming in from the right over the roof
		if dip > 0.01 or lance_phase != "idle":
			var ly := ROOF_Y - 1.2 + 2.2 * dip
			ci.draw_line(Vector2(X + 3.6, F + ROOF_Y - 2.0) * M, Vector2(X + 1.0, F + ly) * M, Pal.ink(0.7), 2.0 * lw)
	# ---- names: the big parts only; the rest when you are close
	if not ci.no_text and zoom >= 0.5:
		var big := [[Vector2(X - SHELL_R, F + HEARTH_Y + 1.6), txt.call("eaf_name")], [Vector2(X + MAST_X - 0.4, F - 2.2), txt.call("eaf_electrodes")],
			[Vector2(X + LINE_X0, F + 6.9), txt.call("eaf_moulds")]]
		for b in big:
			# world-size names: under a few pixels when far in (0 the engine refuses)
			if int(13.0 / maxf(zoom, 0.3)) >= 4:
				ci.draw_string(font_b, (b[0] as Vector2) * M, str(b[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 / maxf(zoom, 0.3)), Pal.ink(0.6))
		if zoom >= 1.6:
			_label(ci, font, Vector2(X + SHELL_R + 0.6, F + HEARTH_Y - 0.4) * M, txt.call("eaf_tap"), zoom)
			_label(ci, font, Vector2(X - SHELL_R - 0.2, F + ROOF_Y - 0.9) * M, txt.call("eaf_roof"), zoom, true)
			_label(ci, font, Vector2(X - 1.5, F + HEARTH_Y + 1.2) * M, txt.call("eaf_rockers"), zoom)


# ================================================================== 101 号: the furnace as meshes
# F is the line's floor (as draw() takes it); lod 1 adds the bolts, the brick courses, the coils
func draw_meshes(ci: CanvasItem, F: float, lod: int) -> void:
	F += DY
	var sc := Vector2(M, M)
	var f0 := Vector2(X, F) * M
	ci.draw_mesh(_mesh("base", _build_base), null, Transform2D(0.0, sc, 0.0, f0))
	ci.draw_mesh(_mesh("mast%d" % lod, func(p): _build_mast(p, lod)), null, Transform2D(0.0, sc, 0.0, Vector2(X + MAST_X, F) * M))
	# the tilt cylinder: from its pin on the cradle to the lug on the shell
	var pin := Vector2(X - 2.2, F + HEARTH_Y + 0.75) * M
	var lug := body_pt(-SHELL_R + 0.35, HEARTH_Y - 0.15, F)
	var mid := pin.lerp(lug, 0.55)
	ci.draw_line(pin, mid, Color(0.32, 0.33, 0.35), 0.24 * M)
	ci.draw_line(mid, lug, Color(0.72, 0.74, 0.78), 0.1 * M)
	ci.draw_mesh(_mesh("shell%d" % lod, func(p): _build_shell(p, lod)), null, Transform2D(tilt, sc, 0.0, Vector2(X, F + PIV) * M))
	ci.draw_mesh(_mesh("roof%d" % lod, func(p): _build_roof(p, lod)), null, Transform2D(0.0, sc, 0.0, Vector2(X - 2.6 * hood, F + ROOF_Y - 0.9 * hood) * M))
	# the arms ride on the mast with the electrodes; the columns run from the arm to the tips
	var ty := tip_y()
	var arm_y := ty - 3.4
	ci.draw_mesh(_mesh("arms%d" % lod, func(p): _build_arms(p, lod)), null, Transform2D(0.0, sc, 0.0, Vector2(X, F + arm_y) * M))
	var col := _mesh("electrode", _build_electrode)
	for k in 3:
		var ex := -0.7 + 0.7 * k
		ci.draw_mesh(col, null, Transform2D(0.0, Vector2(M, M * maxf(0.05, ty - arm_y)), 0.0, Vector2(X + ex, F + arm_y) * M))


# the cradle and its rocker rails, the slag pit's edge: they stay while the vessel rolls
func _build_base(p) -> void:
	var ink := Pal.ink(0.55)
	p.rect(Rect2(-2.7, HEARTH_Y + 0.6, 5.4, 0.32), Color(0.07, 0.072, 0.08))
	p.rect(Rect2(-2.7, HEARTH_Y + 0.6, 5.4, 0.32), ink, false, 0.04)
	for x: float in [-1.4, 1.4]:
		p.rect(Rect2(x - 0.55, HEARTH_Y + 0.38, 1.1, 0.24), STEEL_HI)
		p.line(Vector2(x - 0.55, HEARTH_Y + 0.38), Vector2(x + 0.55, HEARTH_Y + 0.38), Pal.ink(0.6), 0.04)
	p.rect(Rect2(-2.45, HEARTH_Y + 0.5, 0.5, 0.42), STEEL_HI)
	p.circle(Vector2(-2.2, HEARTH_Y + 0.75), 0.12, Pal.ink(0.55), 8)


func _build_mast(p, lod: int) -> void:
	var ink := Pal.ink(0.55)
	p.rect(Rect2(-0.28, -1.8, 0.56, HEARTH_Y + 2.0), STEEL_HI)
	p.rect(Rect2(-0.28, -1.8, 0.56, HEARTH_Y + 2.0), ink, false, 0.04)
	# the guide rails the arms' carriages ride on
	for x: float in [-0.18, 0.18]:
		p.line(Vector2(x, -1.6), Vector2(x, HEARTH_Y), Pal.ink(0.3), 0.04)
	p.rect(Rect2(-0.5, HEARTH_Y - 0.1, 1.0, 0.3), STEEL)
	p.rect(Rect2(-0.4, -2.1, 0.8, 0.32), STEEL)
	p.rect(Rect2(-0.4, -2.1, 0.8, 0.32), ink, false, 0.03)
	if lod > 0:
		var y := -1.5
		while y < HEARTH_Y - 0.2:
			p.bolt(Vector2(0.0, y), 0.05, Pal.ink(0.5))
			y += 0.9


# the vessel in its own frame: the trunnion axis at the origin (body_pt's y less PIV)
func _build_shell(p, lod: int) -> void:
	var q := func(x: float, y: float) -> Vector2: return Vector2(x, y - PIV)
	var R := SHELL_R
	var ink := Pal.ink(0.6)
	var outer := PackedVector2Array([q.call(-R, ROOF_Y + 0.2), q.call(R, ROOF_Y + 0.2), q.call(R, HEARTH_Y - 1.0), q.call(R - 0.7, HEARTH_Y), q.call(-R + 0.7, HEARTH_Y), q.call(-R, HEARTH_Y - 1.0)])
	p.poly(outer, STEEL)
	# the water-cooled panels: a ring of serpentine pipe under the roof
	var top := ROOF_Y + 0.35
	var bot := ROOF_Y + 1.5
	p.rect(Rect2(q.call(-R + 0.12, top), Vector2(2.0 * R - 0.24, bot - top)), Color(0.085, 0.09, 0.1))
	var rows := 7 if lod > 0 else 4
	for k in rows:
		var y := top + 0.08 + k * (bot - top - 0.16) / (rows - 1)
		p.line(q.call(-R + 0.2, y), q.call(R - 0.2, y), Pal.ink(0.24), 0.05)
	for k in 9:
		var px := -R + 0.25 + k * (2.0 * R - 0.5) / 8.0
		p.line(q.call(px, top), q.call(px, bot), Pal.ink(0.36), 0.035)
	# the refractory lining below, laid in courses
	var lining := PackedVector2Array([q.call(-R + 0.25, ROOF_Y + 1.6), q.call(R - 0.25, ROOF_Y + 1.6), q.call(R - 0.25, HEARTH_Y - 1.05), q.call(R - 0.85, HEARTH_Y - 0.25), q.call(-R + 0.85, HEARTH_Y - 0.25), q.call(-R + 0.25, HEARTH_Y - 1.05)])
	p.poly(lining, MGO)
	if lod > 0:
		var y2 := ROOF_Y + 1.85
		var row := 0
		while y2 < HEARTH_Y - 0.35:
			var half := R - 0.3 if y2 < HEARTH_Y - 1.05 else R - 0.3 - (y2 - (HEARTH_Y - 1.05)) * 0.75
			p.line(q.call(-half, y2), q.call(half, y2), Color(0.12, 0.095, 0.08), 0.025)
			var bx := -half + (0.2 if row % 2 == 0 else 0.45)
			while bx < half:
				p.line(q.call(bx, y2 - 0.25), q.call(bx, y2), Color(0.12, 0.095, 0.08), 0.02)
				bx += 0.5
			y2 += 0.25
			row += 1
	# the top ring, the slag door on the left, the shell's stiffening bands
	p.rect(Rect2(q.call(-R - 0.08, ROOF_Y + 0.2), Vector2(2.0 * R + 0.16, 0.16)), STEEL_HI)
	for y3: float in [ROOF_Y + 1.6, HEARTH_Y - 1.0]:
		p.line(q.call(-R, y3), q.call(R, y3), Pal.ink(0.3), 0.06)
	p.rect(Rect2(q.call(-R - 0.22, ROOF_Y + 1.7), Vector2(0.3, 1.1)), STEEL_HI)
	p.rect(Rect2(q.call(-R - 0.22, ROOF_Y + 1.7), Vector2(0.3, 1.1)), Pal.ink(0.5), false, 0.03)
	p.line(q.call(-R - 0.22, ROOF_Y + 2.25), q.call(-R - 0.6, ROOF_Y + 2.25), Pal.ink(0.45), 0.05)
	# the eccentric bottom tap hole's box and its slide gate, towards the moulds
	p.poly(PackedVector2Array([q.call(R - 0.3, HEARTH_Y - 0.6), q.call(R + 0.5, HEARTH_Y - 0.6), q.call(R + 0.5, HEARTH_Y), q.call(R - 0.3, HEARTH_Y)]), STEEL_HI)
	p.polyline(PackedVector2Array([q.call(R - 0.3, HEARTH_Y - 0.6), q.call(R + 0.5, HEARTH_Y - 0.6), q.call(R + 0.5, HEARTH_Y), q.call(R - 0.3, HEARTH_Y)]), Pal.ink(0.5), 0.035, true)
	p.rect(Rect2(q.call(R + 0.05, HEARTH_Y - 0.05), Vector2(0.4, 0.14)), Color(0.5, 0.36, 0.22))
	# the rockers it rolls on, the lug the cylinder pushes
	p.arc(q.call(0.0, HEARTH_Y + 0.1), 1.6, 0.25 * PI, 0.75 * PI, Pal.ink(0.55), 0.1, 14)
	p.circle(q.call(-R + 0.35, HEARTH_Y - 0.15), 0.13, STEEL_HI, 8)
	p.polyline(outer, ink, 0.05, true)
	# cooling water: the hoses from the panels down the side
	for k2 in 2:
		var x2 := R - 0.1 - k2 * 0.18
		p.polyline(PackedVector2Array([q.call(x2, ROOF_Y + 0.6), q.call(x2 + 0.35, ROOF_Y + 1.2), q.call(x2 + 0.3, ROOF_Y + 2.4)]), Color(0.2, 0.3, 0.32), 0.07)
	if lod > 0:
		for k3 in 10:
			p.bolt(q.call(-R + 0.1 + k3 * (2.0 * R - 0.2) / 9.0, ROOF_Y + 0.28), 0.035, Pal.ink(0.55))


# the roof in its own frame (the ring's centre at the origin): its water panels, the delta, the
# electrode ports, and on its right the side chute the hall crane's basket feeds
func _build_roof(p, lod: int) -> void:
	var R := SHELL_R + 0.1
	var ink := Pal.ink(0.6)
	var dome := PackedVector2Array([Vector2(-R, 0.0), Vector2(R, 0.0), Vector2(1.2, -0.7), Vector2(-1.2, -0.7)])
	p.poly(dome, Color(0.085, 0.088, 0.1))
	for k in 3:
		var f := (k + 1) / 4.0
		p.line(Vector2(-R + (R - 1.2) * f, -0.7 * f), Vector2(R - (R - 1.2) * f, -0.7 * f), Pal.ink(0.22), 0.035)
	p.rect(Rect2(-1.0, -0.82, 2.0, 0.16), MGO)
	for k in 3:
		var ex := -0.7 + 0.7 * k
		p.rect(Rect2(ex - 0.24, -0.86, 0.48, 0.2), Color(0.04, 0.04, 0.045))
	p.polyline(dome, ink, 0.05, true)
	# the fourth hole's elbow up into the hood
	p.rect(Rect2(-1.9, -1.05, 0.55, 0.5), STEEL_HI)
	p.rect(Rect2(-1.9, -1.05, 0.55, 0.5), Pal.ink(0.45), false, 0.03)
	# the side charging chute
	var chute := PackedVector2Array([Vector2(1.8, -1.6), Vector2(4.2, -1.6), Vector2(2.95, -0.2), Vector2(2.3, -0.2)])
	p.poly(chute, Color(0.075, 0.078, 0.088))
	p.polyline(chute, ink, 0.045, true)
	p.hatch(Rect2(1.8, -1.6, 2.4, 0.18), Pal.heat(0.7, 1.0), 0.05, 0.22)
	p.line(Vector2(2.3, -0.2), Vector2(R - 0.1, 0.0), Pal.ink(0.4), 0.05)
	if lod > 0:
		for k2 in 6:
			p.bolt(Vector2(-R + 0.2 + k2 * (2.0 * R - 0.4) / 5.0, -0.06), 0.035, Pal.ink(0.55))


# the three arms on their carriage, the clamps and the copper bus tubes (origin: the arm's top at X)
func _build_arms(p, lod: int) -> void:
	var ink := Pal.ink(0.55)
	p.rect(Rect2(MAST_X - 0.45, -0.75, 0.9, 1.05), STEEL)
	p.rect(Rect2(MAST_X - 0.45, -0.75, 0.9, 1.05), ink, false, 0.04)
	p.rect(Rect2(MAST_X, -0.38, 0.9 - MAST_X, 0.38), STEEL_HI)
	p.rect(Rect2(MAST_X, -0.38, 0.9 - MAST_X, 0.38), ink, false, 0.04)
	for k in 3:
		var ex := -0.7 + 0.7 * k
		p.rect(Rect2(ex - 0.3, -0.52, 0.6, 0.48), COPPER.darkened(0.3))
		p.rect(Rect2(ex - 0.3, -0.52, 0.6, 0.48), ink, false, 0.03)
		p.line(Vector2(MAST_X + 0.35, -0.62 + k * 0.1), Vector2(ex, -0.52), COPPER.darkened(0.1), 0.06)
	if lod > 0:
		for k2 in 4:
			p.bolt(Vector2(MAST_X + 0.6 + k2 * 0.9, -0.19), 0.04, Pal.ink(0.5))


# a graphite column one unit long (scaled to its length): only lines along it, so the scale keeps them
func _build_electrode(p) -> void:
	p.rect(Rect2(-0.17, 0.0, 0.34, 1.0), Color(0.3, 0.3, 0.32))
	p.rect(Rect2(-0.12, 0.0, 0.07, 1.0), Color(0.42, 0.42, 0.45))
	p.line(Vector2(-0.17, 0.0), Vector2(-0.17, 1.0), Pal.ink(0.75), 0.025)
	p.line(Vector2(0.17, 0.0), Vector2(0.17, 1.0), Pal.ink(0.6), 0.025)


func _basket(ci, F: float, bx: float, fl: float, lw: float) -> void:
	_rect(ci, bx - 1.3, 0.4, bx + 1.3, 2.4, F, Color(0.045, 0.047, 0.054), Pal.ink(0.5), lw)
	if fl > 0.01:
		_rect(ci, bx - 1.15, 2.3 - 1.8 * fl, bx + 1.15, 2.3, F, Color(0.25, 0.24, 0.22))
	# its two lifting lugs (the crane hook is above, out of the picture)
	for sx in [-1.0, 1.0]:
		ci.draw_line(Vector2(X + bx + sx * 1.3, F + 0.4) * M, Vector2(X + bx + sx * 1.0, F + 0.05) * M, Pal.ink(0.5), lw)
		ci.draw_circle(Vector2(X + bx + sx * 1.0, F + 0.05) * M, 0.12 * M, Pal.ink(0.5), false, lw)


func draw_add(ci, F: float, tex: Texture2D) -> void:
	F += DY
	# the arcs: a white-violet flare under each electrode, flickering with the current
	if power > 0.5 and phase not in ["tilt", "pour", "back"]:
		var k := clampf(power / P_RATED, 0.0, 1.0)
		var ty := tip_y()
		for i in 3:
			var ex := -0.7 + 0.7 * i
			var fl := 0.55 + 0.45 * sin(t * 37.0 + i * 2.1) * sin(t * 13.0 + i)
			var c := Vector2(X + ex, F + ty + 0.1) * M
			ci.draw_texture_rect(tex, Rect2(c - Vector2(1.1, 1.1) * M, Vector2(2.2, 2.2) * M), false, Color(0.85, 0.8, 1.0, 0.75 * k * fl))
			ci.draw_texture_rect(tex, Rect2(c - Vector2(0.35, 0.35) * M, Vector2(0.7, 0.7) * M), false, Color(1.0, 1.0, 1.0, 0.9 * k * fl))
	if m_l > 0.01:
		var c2 := body_pt(0.0, HEARTH_Y - 1.0, F)
		ci.draw_texture_rect(tex, Rect2(c2 - Vector2(2.2, 1.2) * M, Vector2(4.4, 2.4) * M), false, glow_col(T, 0.06 + 0.06 * clampf(m_l / CAP, 0.0, 1.0)))
	if phase == "pour" and gate > 0.2:
		var land := Vector2(X + SEAT_DX + 1.1, F + SEAT_DY + 0.3) * M
		ci.draw_texture_rect(tex, Rect2(land - Vector2(1.0, 0.8) * M, Vector2(2.0, 1.6) * M), false, glow_col(T, 0.5 * gate))
	for ig in ingots:
		var it: float = ig[1]
		if it < 600.0:
			continue
		var ix: float = FILL_X + line_off - float(ig[0])
		if ix < LINE_X0 or ix > LINE_X1:
			continue
		ci.draw_texture_rect(tex, Rect2(Vector2(X + ix - 0.6, F + 5.2) * M, Vector2(1.2, 1.0) * M), false, glow_col(it, 0.3 * clampf((it - 600.0) / 800.0, 0.0, 1.0)))
