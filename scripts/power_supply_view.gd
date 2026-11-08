extends Node2D
# 128 号 第 5 段 动力 —— 草图: what scripts/power_supply.gd runs, drawn where it happens.
#   the battery berth on the power district's roof (two slots between the radiator fins, the bus cable
#   to the roof transformers), the blocks in it, the delivery ship holding station over it and its
#   winch, spreader and cables; the processing district's cryo stand, the tug and its frame (an LH2
#   tank and a LOX sphere, vacuum-jacketed lines, relief vents), frost and white vapour, the fill
#   coupling on the power district's left wall; inside the power district: each set's heat bar, the
#   trip and the wrench mark, the fuel cells' tank. Black and white and the theme colours; the solid
#   things (berth frame, ship, tug, tanks) bright line with a light fill, piping and cables dim.
# Under scripts/port_structure.gd (world px). Ticks the sketch while the port is the empty berth.

const PS = preload("res://scripts/power_supply.gd")
const HULL := Color(0.07, 0.074, 0.084)      # the drone's own hull colours (scripts/drone_art.gd)
const HULL_HI := Color(0.11, 0.115, 0.13)

var game
var font: Font
var _puffs: Array = []           # [pos px, vel px/s, age, life, r m]
var _rng := RandomNumberGenerator.new()
var tick_us := 0.0


func _ready() -> void:
	font = Fonts.get_font("Medium")
	_rng.seed = 5128


func _active() -> bool:
	return game != null and is_instance_valid(game) and game.in_berth() and game.career() and PS.on()


func _process(dt: float) -> void:
	visible = _active()
	if not visible:
		return
	var t0 := Time.get_ticks_usec()
	PS.tick(game, dt)
	_vapour(dt)
	tick_us = lerpf(tick_us, float(Time.get_ticks_usec() - t0), 0.05)
	queue_redraw()


func M() -> float:
	return PortStructure.M()


func _b(v: Vector2) -> Vector2:          # power box-local m → world px
	return PortStructure.box("power").position + v * M()


func _pm(v: Vector2) -> Vector2:         # port m → world px
	return PortStructure.centre() + v * M()


# ---------------------------------------------------------------- palette (the house's)
func _ink(a: float) -> Color:
	return Pal.ink(a)


func _fill() -> Color:
	return Color(0.055, 0.06, 0.07)


func _fill2() -> Color:
	return Color(0.085, 0.09, 0.1)


func _solid(r: Rect2, a := 0.85, fill := Color(0.075, 0.08, 0.09)) -> void:
	draw_rect(r, fill)
	draw_rect(r, _ink(a), false, maxf(1.0, 0.09 * M()))


func _poly(pts: PackedVector2Array, a := 0.85, fill := Color(0.075, 0.08, 0.09)) -> void:
	draw_colored_polygon(pts, fill)
	var c := pts.duplicate()
	c.append(pts[0])
	draw_polyline(c, _ink(a), maxf(1.0, 0.09 * M()), true)


func _thin(a: Vector2, b: Vector2, al := 0.35, wm := 0.05) -> void:
	draw_line(a, b, _ink(al), maxf(1.0, wm * M()), true)


func _text(at: Vector2, s: String, size_m: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width_m := -1.0) -> void:
	draw_string(font, at, s, align, width_m * M() if width_m > 0.0 else -1.0, maxi(6, int(size_m * M())), col)


# ---------------------------------------------------------------- vapour
func _emit(at: Vector2, dir: Vector2, n: int, speed_m: float, life: float, r_m: float) -> void:
	for i in n:
		var a := dir.angle() + _rng.randf_range(-0.45, 0.45)
		_puffs.append([at, Vector2.from_angle(a) * speed_m * M() * _rng.randf_range(0.6, 1.2), 0.0, life * _rng.randf_range(0.7, 1.2), r_m * _rng.randf_range(0.7, 1.3)])


func _vapour(dt: float) -> void:
	for p in _puffs:
		p[0] += p[1] * dt
		p[1] *= exp(-dt * 0.8)
		p[2] += dt
	_puffs = _puffs.filter(func(p): return p[2] < p[3])
	if _puffs.size() > 900:
		_puffs = _puffs.slice(_puffs.size() - 900)
	var c: Dictionary = PS.d().cryo
	var ph := str(c.phase)
	var pose := PS.cryo_pose(c)
	var F := _pm(pose.p)
	var k := dt * 60.0
	# the precool: the line's vent stack blows white while the cold goes through it
	if ph == "p_precool" or ph == "d_precool":
		var vent := _stand_vent() if ph == "p_precool" else _b(Vector2(-0.4, 22.2))
		if _rng.randf() < 0.9 * k:
			_emit(vent, Vector2.UP, 3, 3.5, 1.6, 0.35)
	# the hose's couplings smoke as they are made and broken
	if ph in ["p_close", "d_close", "d_connect"] and _rng.randf() < 0.5 * k:
		_emit(_coupling_px(ph), Vector2.UP.rotated(_rng.randf_range(-1.0, 1.0)), 2, 1.6, 1.2, 0.25)
	# full tanks boil off a thread from the relief vents, all the way
	if float(c.h2) > 0.05 and ph not in ["home"] and _rng.randf() < 0.35 * k:
		_emit(F + Vector2(-1.2, -1.55) * M(), Vector2.UP, 1, 1.2, 1.4, 0.16)
	if float(c.o2) > 0.05 and ph not in ["home"] and _rng.randf() < 0.2 * k:
		_emit(F + Vector2(2.3, -1.35) * M(), Vector2.UP, 1, 1.0, 1.2, 0.13)


func _stand_vent() -> Vector2:
	return _pm(PS.route()[0] + Vector2(-4.2, -2.8))


func _coupling_px(ph: String) -> Vector2:
	var pose := PS.cryo_pose(PS.d().cryo)
	if ph.begins_with("p_"):
		return _pm(PS.route()[0] + Vector2(-3.2, 0.8))
	return _pm(pose.p) + Vector2(3.8, 0.0) * M()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if not visible:
		return
	_berth()
	_cryo_fixed()
	_cryo_run()
	_ship()
	_inside()
	for p in _puffs:
		var k: float = float(p[2]) / float(p[3])
		var r: float = float(p[4]) * M() * (1.0 + 2.6 * k)
		draw_circle(p[0], r, Color(0.92, 0.96, 1.0, 0.22 * (1.0 - k) * (1.0 - k)))


# the battery berth on the roof, between the fins
func _berth() -> void:
	var m := M()
	var lw := maxf(1.0, 0.08 * m)
	# the cradle (PS.BASE, PS.POSTS_X, PS.FLARES): base plate, three posts, the outer ones flared outward
	var base := Rect2(_b(PS.BASE.position), PS.BASE.size * m)
	_solid(base, 0.85, HULL_HI)
	_thin(base.position + Vector2(0.1, 0.35) * m, base.position + Vector2(PS.BASE.size.x - 0.1, 0.35) * m, 0.3, 0.03)
	for x in PS.POSTS_X:
		var pr := Rect2(_b(Vector2(float(x) - PS.POST_W * 0.5, PS.POST_TOP)), Vector2(PS.POST_W, PS.BASE.position.y - PS.POST_TOP) * m)
		_solid(pr, 0.85, HULL_HI)
		draw_circle(_b(Vector2(float(x), PS.POST_TOP)), PS.POST_W * 0.6 * m, _ink(0.8))
	for k in 2:
		var x0: float = PS.POSTS_X[0 if k == 0 else 2]
		var sd := -1.0 if k == 0 else 1.0
		draw_line(_b(Vector2(x0, PS.POST_TOP)), _b(Vector2(x0 + sd * 0.35, PS.POST_TOP - 0.5)), _ink(0.8), lw)
	for i in PS.SLOTS:
		var cx: float = PS.SLOT_X[i]
		var sl: Dictionary = PS.d().slots[i]
		var live: bool = not sl.is_empty() and float(sl.get("left", 0.0)) > 0.0001
		# the bus socket set into the base plate, lit while its block feeds
		_solid(Rect2(_b(Vector2(cx - 0.4, -0.58)), Vector2(0.8, 0.22) * m), 0.75, _fill2())
		draw_circle(_b(Vector2(cx + 0.6, -0.47)), 0.09 * m, Pal.tint(Pal.VOLT, 0.95, 1.4) if live else _ink(0.25))
		_text(_b(Vector2(cx - 0.15, 0.55)), "AB"[i], 0.42, _ink(0.55))
		if not sl.is_empty():
			_block(Vector2(cx, PS.BASE.position.y), str(sl.size), float(sl.left) / float(PS.SIZES[str(sl.size)].mwh), 1.0)
	# the bus cable along the roof to the transformers (dim: not solid)
	var cab := PackedVector2Array([_b(Vector2(44.45, -0.35)), _b(Vector2(44.0, -0.35)), _b(Vector2(43.6, -0.15))])
	draw_polyline(cab, Pal.tint(Pal.VOLT, 0.45, 1.0), maxf(1.0, 0.12 * m), true)
	_text(_b(Vector2(44.6, 1.25)), PS.w("电池泊位", "BATTERY BERTH"), 0.4, _ink(0.45))


# a block standing at `foot` (box-local m, its bottom centre): cells, lugs, terminals, charge
func _block(foot: Vector2, size: String, k: float, lugs_a: float, world := Vector2.INF) -> void:
	var m := M()
	var h: float = PS.SIZES[size].h
	var wb := PS.SLOT_W
	var o := world if world != Vector2.INF else _b(foot)
	var r := Rect2(o + Vector2(-wb * 0.5, -h) * m, Vector2(wb, h) * m)
	var spent := k <= 0.0001
	_solid(r, 0.55 if spent else 0.9, Color(0.07, 0.075, 0.08) if not spent else Color(0.05, 0.05, 0.055))
	# cell modules
	var rows := int(round(h / 0.55))
	for j in rows:
		var y := r.position.y + (j + 0.5) * r.size.y / rows
		draw_line(Vector2(r.position.x + 0.15 * m, y), Vector2(r.end.x - 0.15 * m, y), _ink(0.22), maxf(1.0, 0.04 * m))
	for j in 3:
		var x := r.position.x + (j + 1) * r.size.x / 4.0
		draw_line(Vector2(x, r.position.y + 0.2 * m), Vector2(x, r.end.y - 0.2 * m), _ink(0.14), maxf(1.0, 0.03 * m))
	# the lifting lugs and the terminal box on top
	for sx: float in [-0.55, 0.55]:
		draw_arc(o + Vector2(sx, -h - 0.12) * m, 0.14 * m, PI, TAU, 8, _ink(0.75 * lugs_a), maxf(1.0, 0.06 * m))
	_solid(Rect2(o + Vector2(-0.3, -h - 0.18) * m, Vector2(0.6, 0.18) * m), 0.7, _fill2())
	# the charge, a bar down the right side, and its lamp
	var bar := Rect2(r.end.x - 0.28 * m, r.position.y + 0.2 * m, 0.12 * m, r.size.y - 0.4 * m)
	draw_rect(bar, _ink(0.1))
	if not spent:
		var col := Pal.tint(Pal.VOLT, 0.9, 1.3) if k > PS.LOW_AT else UiSkin.ACCENT
		draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * k, bar.size.x, bar.size.y * k), col)
	_text(r.position + Vector2(0.18, 0.55) * m, PS.size_name(size) if not spent else PS.w("空壳", "SPENT"), 0.34, _ink(0.75) if not spent else _ink(0.4))
	_text(r.position + Vector2(0.18, 0.95) * m, "%.1f MWh" % (float(PS.SIZES[size].mwh) * k), 0.26, _ink(0.5))


func _ship() -> void:
	var o := PS.ship()
	if o.is_empty():
		return
	var pose := PS.ship_pose(o)
	var m := M()
	var c := _b(pose.p)       # the belly's middle
	var a: Vector2 = pose.a
	var thrust := -a.y        # upward force ⇒ exhaust down
	var hw := PS.SHIP_HALF
	var hh := PS.SHIP_H
	var doors := PS.bay_doors(o)
	var lw := maxf(1.0, 0.07 * m)
	# the bay's floodlight on the berth while it works (faint, under everything)
	var gm := PS.hoist_geom(o)
	if doors > 0.3:
		# the bay's floodlight on the slot being worked, down to the guide posts' tops (it lights the opening)
		var fl := c + Vector2(float(gm.spx) - pose.p.x, -0.15) * m
		var far_y := _b(Vector2(0, PS.POST_TOP)).y
		var sw: float = 0.9 * m
		draw_colored_polygon(PackedVector2Array([fl + Vector2(-0.4, 0) * m, fl + Vector2(0.4, 0) * m, Vector2(fl.x + sw, far_y), Vector2(fl.x - sw, far_y)]), Color(1.0, 0.97, 0.9, 0.05 * doors))
	# the two retro engines in their pods on the belly's corners
	var bh2 := PS.BAY_HALF
	for sx: float in [-(hw - 0.55), hw - 0.55]:
		_engine(c + Vector2(sx, 0.0) * m, thrust, sx)
	# the hull: a narrow freighter, belly down
	var hull := PackedVector2Array([c + Vector2(-hw, -0.05) * m, c + Vector2(-hw, -hh * 0.6) * m, c + Vector2(-hw + 1.1, -hh) * m, c + Vector2(hw - 1.1, -hh) * m,
		c + Vector2(hw, -hh * 0.6) * m, c + Vector2(hw, -0.05) * m, c + Vector2(bh2, -0.05) * m, c + Vector2(bh2, -0.95) * m, c + Vector2(-bh2, -0.95) * m, c + Vector2(-bh2, -0.05) * m])
	_poly(hull, 0.92, HULL)
	# the top deck's light edge, the deck plates
	draw_colored_polygon(PackedVector2Array([c + Vector2(-hw + 1.1, -hh) * m, c + Vector2(hw - 1.1, -hh) * m, c + Vector2(hw - 0.95, -hh + 0.22) * m, c + Vector2(-hw + 0.95, -hh + 0.22) * m]), HULL_HI)
	_thin(c + Vector2(-hw + 0.1, -hh * 0.6) * m, c + Vector2(hw - 0.1, -hh * 0.6) * m, 0.35, 0.05)
	_thin(c + Vector2(-hw + 0.1, -1.35) * m, c + Vector2(hw - 0.1, -1.35) * m, 0.22, 0.04)
	# side armour plates with their bolts, and the seams between
	for sd: float in [-1.0, 1.0]:
		var x0 := sd * (hw - 0.12)
		var x1 := sd * (hw - 1.05)
		var pr := Rect2(Vector2(minf(x0, x1), -1.25) * m + c, Vector2(absf(x1 - x0), 1.05) * m)
		draw_rect(pr, HULL_HI)
		draw_rect(pr, _ink(0.45), false, lw * 0.7)
		for k in 3:
			draw_circle(pr.position + Vector2(pr.size.x * (0.2 + 0.3 * k), 0.14 * m), 0.045 * m, _ink(0.5))
			draw_circle(pr.position + Vector2(pr.size.x * (0.2 + 0.3 * k), pr.size.y - 0.14 * m), 0.045 * m, _ink(0.5))
	for k in 5:
		var x := -2.0 + k * 1.0
		_thin(c + Vector2(x, -hh + 0.25) * m, c + Vector2(x, -hh * 0.6) * m, 0.2, 0.035)
	# the heat-rejection fins along the top, warm with the engines
	for k in 7:
		var x := -1.8 + k * 0.6
		draw_line(c + Vector2(x, -hh) * m, c + Vector2(x, -hh - 0.32) * m, Pal.heat(0.25 + 0.4 * clampf(thrust / 4.0, 0.0, 1.0), 1.0), lw)
	# the antenna mast and its dish; the strobe
	var mast := c + Vector2(-2.3, -hh) * m
	_thin(mast, mast + Vector2(0, -1.25) * m, 0.7, 0.06)
	draw_arc(mast + Vector2(0.18, -1.0) * m, 0.32 * m, PI * 0.6, PI * 1.4, 10, _ink(0.75), lw, true)
	var strobe := fmod(PS.t + 0.4, 1.1) < 0.06
	draw_circle(mast + Vector2(0, -1.3) * m, (0.09 if not strobe else 0.22) * m, Color(1, 1, 1, 1.0 if strobe else 0.35))
	# the bridge's windows, mullioned
	var wr := Rect2(c + Vector2(-1.3, -hh + 0.4) * m, Vector2(2.6, 0.42) * m)
	draw_rect(wr, Color(UiSkin.DATA, 0.5))
	for k in 3:
		var x := wr.position.x + wr.size.x * (k + 1) / 4.0
		draw_line(Vector2(x, wr.position.y), Vector2(x, wr.end.y), HULL, lw)
	draw_rect(wr, _ink(0.7), false, lw * 0.7)
	draw_line(wr.position + Vector2(0.1, 0.08) * m, wr.position + Vector2(0.9, 0.08) * m, Color(1, 1, 1, 0.35), lw * 0.6)
	# RCS quads at the four corners, three nozzles each; a short white puff while it trims
	for q in [Vector2(-hw, -hh * 0.6), Vector2(hw, -hh * 0.6), Vector2(-hw, -0.35), Vector2(hw, -0.35)]:
		var qc: Vector2 = c + q * m
		var sd2 := signf(q.x)
		_solid(Rect2(qc + Vector2(-0.18 + 0.12 * sd2, -0.18) * m, Vector2(0.36, 0.36) * m), 0.75, HULL_HI)
		for nd in [Vector2(sd2, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_line(qc + Vector2(0.12 * sd2, 0) * m + nd * 0.18 * m, qc + Vector2(0.12 * sd2, 0) * m + nd * 0.3 * m, _ink(0.7), lw)
	if str(o.phase) in ["lift_old", "lower", "latch"] and fmod(PS.t * 3.1, 1.0) < 0.14:
		var sd3: float = 1.0 if sin(PS.t * 0.7) > 0.0 else -1.0
		var q2 := c + Vector2(sd3 * (hw + 0.42), -hh * 0.6) * m
		draw_colored_polygon(PackedVector2Array([q2 + Vector2(0, -0.08) * m, q2 + Vector2(0, 0.08) * m, q2 + Vector2(sd3 * 0.6, 0) * m]), Color(1, 1, 1, 0.55))
	# nav lights, docking lights
	var blink := fmod(PS.t, 1.4) < 0.12
	draw_circle(c + Vector2(-hw - 0.05, -hh * 0.6 - 0.35) * m, 0.12 * m, Color(1, 0.3, 0.25, 1.0 if blink else 0.3))
	draw_circle(c + Vector2(hw + 0.05, -hh * 0.6 - 0.35) * m, 0.12 * m, Color(0.3, 1, 0.5, 1.0 if blink else 0.3))
	for sd4: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(sd4 * (bh2 + 0.2), -0.1) * m, 0.08 * m, Color(1, 0.75, 0.3, 0.5 + 0.5 * absf(sin(PS.t * 2.0))))
	# decals
	_text(c + Vector2(-hw + 0.25, -1.45) * m, "CB-7", 0.42, _ink(0.75))
	_text(c + Vector2(hw - 1.6, -1.45) * m, PS.w("外星系货运", "FREIGHT"), 0.24, _ink(0.45))
	# the cargo bay: dark inside, the trolley rail, the winch drum, its lamp; hazard stripes on its lip
	var bay := Rect2(c + Vector2(-bh2, -0.95) * m, Vector2(2.0 * bh2, 0.9) * m)
	draw_rect(bay, Color(0.02, 0.022, 0.026))
	_thin(bay.position + Vector2(0.05, 0.22) * m, bay.position + Vector2(2.0 * bh2 - 0.05, 0.22) * m, 0.55, 0.06)
	var drum := c + Vector2(0.0, -0.62) * m
	draw_circle(drum, 0.26 * m, HULL_HI)
	draw_arc(drum, 0.26 * m, 0.0, TAU, 16, _ink(0.7), lw, true)
	draw_arc(drum, 0.12 * m, PS.t * 3.0, PS.t * 3.0 + 4.5, 8, _ink(0.6), lw * 0.7, false)
	draw_circle(c + Vector2(bh2 - 0.4, -0.85) * m, 0.07 * m, Color(1.0, 0.95, 0.85, 0.4 + 0.6 * doors))
	for k in 8:
		var x := -bh2 + k * 0.55
		draw_line(c + Vector2(x, -0.05) * m, c + Vector2(x + 0.25, -0.05) * m, Color(UiSkin.ACCENT, 0.8), maxf(1.0, 0.1 * m))
	# the winch: a trolley on its rail, two sheaves, the cables, the spreader, what it holds
	var hk: Dictionary = gm.hook
	var slot := int(gm.slot)
	var trolley := _b(gm.trolley)
	_solid(Rect2(trolley - Vector2(0.5, 0.0) * m, Vector2(1.0, 0.3) * m), 0.8, HULL_HI)
	for sx5: float in [-0.32, 0.32]:
		draw_circle(trolley + Vector2(sx5, 0.0) * m, 0.08 * m, _ink(0.75))
		draw_circle(trolley + Vector2(sx5, 0.3) * m, 0.1 * m, HULL)
		draw_arc(trolley + Vector2(sx5, 0.3) * m, 0.1 * m, 0.0, TAU, 10, _ink(0.6), lw * 0.7)
	var sp := _b(Vector2(float(gm.spx), float(gm.sp_y)))
	var holds := str(gm.holds)
	for sx: float in [-0.32, 0.32]:
		draw_line(trolley + Vector2(sx, 0.4) * m, sp + Vector2(sx * 1.7, 0.0) * m, _ink(0.6), maxf(1.0, 0.04 * m), true)
	# the spreader: a box beam with its two twistlock pins (narrower than the slot's opening)
	var spr := Rect2(sp - Vector2(PS.SPREADER.x * 0.5, 0.0) * m, PS.SPREADER * m)
	draw_rect(spr, HULL_HI)
	draw_rect(spr, _ink(0.85), false, lw)
	_thin(spr.position + Vector2(0.1, 0.12) * m, spr.position + Vector2(PS.SPREADER.x - 0.1, 0.12) * m, 0.3, 0.03)
	for sx6: float in [-1.0, 1.0]:
		draw_line(sp + Vector2(sx6 * 0.55, PS.SPREADER.y) * m, sp + Vector2(sx6 * 0.55, PS.SPREADER.y + 0.16) * m, Color(UiSkin.ACCENT, 0.9), maxf(1.0, 0.08 * m))
	draw_circle(sp + Vector2(0, 0.12) * m, 0.06 * m, Color(0.3, 1, 0.5, 0.9) if holds != "" else Color(1, 0.75, 0.3, 0.9))
	if holds != "":
		var blk: Rect2 = gm.block
		_block(Vector2.ZERO, str(gm.hsz), 1.0 if holds == "new" else 0.0, 1.0, _b(Vector2(blk.get_center().x, blk.end.y)))
	# the bay doors: two roller shutters that wind back into drums at the bay's lips (never below the belly)
	for sd5: float in [-1.0, 1.0]:
		var drum5 := c + Vector2(sd5 * (bh2 - 0.12), -0.12) * m
		var wdt := bh2 * (1.0 - doors)
		if wdt > 0.02:
			var r5 := Rect2(c + Vector2(minf(sd5 * bh2, sd5 * (bh2 - wdt)), -0.08) * m, Vector2(wdt, 0.12) * m)
			draw_rect(r5, HULL_HI)
			draw_rect(r5, _ink(0.85), false, lw)
			var xk := r5.position.x + 0.2 * m
			while xk < r5.end.x - 0.05 * m:
				draw_line(Vector2(xk, r5.position.y), Vector2(xk, r5.end.y), _ink(0.35), lw * 0.5)
				xk += 0.2 * m
		draw_circle(drum5, (0.1 + 0.05 * doors) * m, HULL_HI)
		draw_arc(drum5, (0.1 + 0.05 * doors) * m, 0.0, TAU, 10, _ink(0.75), lw * 0.7)
	# the latch: the clamps swing shut and the plug goes home, a spark of light as it makes
	if str(o.phase) == "latch":
		var lk := float(hk.get("latch", 0.0))
		var cx: float = PS.SLOT_X[slot]
		for sx: float in [-1.0, 1.0]:
			var piv := _b(Vector2(cx + sx * (PS.SLOT_W * 0.5 + 0.065), -1.4))
			draw_line(piv, piv + Vector2(-sx * 0.06 * lk, 0.0) * m, _ink(0.9), maxf(1.0, 0.12 * m))
		if lk > 0.7:
			draw_circle(_b(Vector2(cx, -0.85)), (0.25 + 0.4 * (1.0 - lk)) * m, Color(Pal.tint(Pal.VOLT, 0.9, 1.6), 0.6))


# a retro engine on the belly: its pod, gimbal ring and bell; the plume as long as the thrust
func _engine(at: Vector2, thrust: float, seed_x: float) -> void:
	var m := M()
	var lw := maxf(1.0, 0.07 * m)
	_solid(Rect2(at + Vector2(-0.55, -1.3) * m, Vector2(1.1, 1.3) * m), 0.8, HULL_HI)
	_thin(at + Vector2(-0.55, -0.7) * m, at + Vector2(0.55, -0.7) * m, 0.3, 0.035)
	for k in 3:
		draw_line(at + Vector2(-0.4 + k * 0.4, -1.2) * m, at + Vector2(-0.4 + k * 0.4, -1.0) * m, _ink(0.4), lw * 0.7)
	draw_circle(at + Vector2(0, 0.06) * m, 0.17 * m, HULL)
	draw_arc(at + Vector2(0, 0.06) * m, 0.17 * m, 0.0, TAU, 12, _ink(0.75), lw, true)
	var bell := PackedVector2Array([at + Vector2(-0.13, 0.18) * m, at + Vector2(0.13, 0.18) * m, at + Vector2(0.27, 0.78) * m, at + Vector2(-0.27, 0.78) * m])
	draw_colored_polygon(bell, Color(0.05, 0.05, 0.055))
	draw_polyline(PackedVector2Array([bell[0], bell[3], bell[2], bell[1]]), _ink(0.85), lw, true)
	_thin(at + Vector2(-0.2, 0.5) * m, at + Vector2(0.2, 0.5) * m, 0.35, 0.03)
	if thrust <= 0.2:
		return
	var L := (1.1 + 1.5 * thrust) * m * (0.93 + 0.07 * sin(PS.t * 43.0 + seed_x * 3.0))
	var ex := at + Vector2(0, 0.78) * m
	draw_circle(ex, 0.32 * m, Color(Pal.heat(0.9, 1.6), 0.35))
	draw_colored_polygon(PackedVector2Array([ex + Vector2(-0.3, 0) * m, ex + Vector2(0.3, 0) * m, ex + Vector2(0, L)]), Color(UiSkin.ACCENT, 0.45))
	draw_colored_polygon(PackedVector2Array([ex + Vector2(-0.15, 0) * m, ex + Vector2(0.15, 0) * m, ex + Vector2(0, L * 0.6)]), Color(1.0, 0.95, 0.85, 0.85))
	# shock diamonds down the core
	for k in 3:
		var dy := L * (0.12 + 0.13 * k)
		var r := (0.09 - 0.02 * k) * m
		var dc := ex + Vector2(0, dy)
		draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -r * 1.6), dc + Vector2(r, 0), dc + Vector2(0, r * 1.6), dc + Vector2(-r, 0)]), Color(1, 1, 1, 0.8 - 0.2 * k))


# the fixed cryo plant: the processing district's stand and the power district's fill coupling
func _cryo_fixed() -> void:
	var m := M()
	var s: Vector2 = PS.route()[0]
	# the stand: a saddle frame on the roof, the vacuum-jacketed supply riser from the separator below
	var base := _pm(s + Vector2(0, 1.6))
	_solid(Rect2(base + Vector2(-4.2, -0.4) * m, Vector2(8.4, 0.4) * m), 0.8)
	for sx: float in [-2.6, 1.4]:
		_poly(PackedVector2Array([base + Vector2(sx - 0.6, -0.4) * m, base + Vector2(sx + 0.6, -0.4) * m, base + Vector2(sx + 0.3, -0.9) * m, base + Vector2(sx - 0.3, -0.9) * m]), 0.7)
	# riser and vent stack at the stand's left
	var riser := PackedVector2Array([base + Vector2(-3.6, 0.0) * m, base + Vector2(-3.6, -1.6) * m])
	_jacket(riser, 0.35)
	_thin(base + Vector2(-4.2, 0.0) * m, base + Vector2(-4.2, -4.4) * m, 0.55, 0.12)
	draw_arc(base + Vector2(-4.2, -4.4) * m, 0.18 * m, PI, TAU, 8, _ink(0.6), maxf(1.0, 0.08 * m))
	_text(base + Vector2(-4.2, 1.0) * m, PS.w("低温灌装台 · 液氢 / 液氧", "CRYO FILL STAND · LH2 / LOX"), 0.42, _ink(0.5))
	# the fill coupling on the power district's left wall: a bayonet box, its swing arm stowed or out
	var cp := _b(Vector2(0.0, 25.2))
	_solid(Rect2(cp + Vector2(-0.7, -1.3) * m, Vector2(0.7, 2.6) * m), 0.85, _fill2())
	_thin(cp + Vector2(-0.35, -1.3) * m, cp + Vector2(-0.35, -3.4) * m, 0.55, 0.1)   # the precool vent
	draw_arc(cp + Vector2(-0.35, -3.4) * m, 0.16 * m, PI, TAU, 8, _ink(0.6), maxf(1.0, 0.07 * m))
	var lit := float(PS.d().get("fc_fuel", 0.0)) > 0.001
	draw_circle(cp + Vector2(-0.35, 0.95) * m, 0.12 * m, Pal.tint(Pal.FLUID, 0.95, 1.4) if lit else _ink(0.25))
	_text(cp + Vector2(-8.4, 2.4) * m, PS.w("燃料电池加注口", "FUEL-CELL FILL"), 0.4, _ink(0.45))


# a vacuum-jacketed line: the outer jacket, its convolutions, the inner line dimly through the gap
func _jacket(pts: PackedVector2Array, wm: float, frost := 0.0) -> void:
	var m := M()
	draw_polyline(pts, _ink(0.6 + 0.3 * frost), maxf(1.5, wm * m), true)
	draw_polyline(pts, Color(0.05, 0.055, 0.06), maxf(1.0, wm * 0.62 * m), true)
	draw_polyline(pts, Color(Pal.tint(Pal.FLUID, 0.5, 1.0), 0.7), maxf(1.0, wm * 0.2 * m), true)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		var n := int(L / (0.32 * m))
		var nrm := (b - a).normalized().orthogonal()
		for k in n:
			var p := a.lerp(b, (k + 0.5) / maxf(1.0, n))
			draw_line(p - nrm * wm * 0.5 * m, p + nrm * wm * 0.5 * m, _ink(0.45 + 0.4 * frost), maxf(1.0, 0.035 * m))


func _cryo_run() -> void:
	var m := M()
	var c: Dictionary = PS.d().cryo
	var ph := str(c.phase)
	var pose := PS.cryo_pose(c)
	var F := _pm(pose.p)
	var frost := float(c.frost)
	var a: Vector2 = pose.a
	# the tug behind the frame (to its left), its grapple closed on the frame's end post
	_tug(F + Vector2(-7.0, 0.0) * m, a, F + Vector2(-3.8, 0.0) * m)
	# the frame: a skid truss, two end posts with lifting eyes, the tanks' saddles and straps
	_frame(F)
	# LH2: a long cylinder with domed heads in its vacuum jacket; the manifold and relief stack on top
	var hc := F + Vector2(-1.2, -0.15) * m
	_capsule(hc, 2.2, 1.05, frost)
	_level(Rect2(hc + Vector2(-1.4, 0.55) * m, Vector2(2.8, 0.14) * m), float(c.h2), Pal.tint(Pal.FLUID, 0.9, 1.3))
	_text(hc + Vector2(-1.8, -0.3) * m, PS.w("液氢 −253 °C", "LH2 −253 °C"), 0.34, _ink(0.85))
	_text(hc + Vector2(-1.8, 0.15) * m, "UN1966 · %.0f kg" % (float(c.get("h2_kg", 0.0)) * float(c.h2)), 0.22, _ink(0.5))
	_manifold(hc + Vector2(1.1, -1.05) * m, frost, ph)
	_relief(hc + Vector2(-0.6, -1.05) * m, frost)
	_gauge(hc + Vector2(0.2, -1.32) * m, 0.22, 0.25 + 0.5 * float(c.h2))
	# LOX: a sphere in its jacket on a ring saddle
	var oc := F + Vector2(2.3, 0.0) * m
	draw_circle(oc, 0.95 * m, HULL)
	draw_arc(oc, 0.95 * m, 0.0, TAU, 32, _ink(0.85 + 0.15 * frost), maxf(1.0, 0.09 * m), true)
	draw_arc(oc, 0.8 * m, 0.0, TAU, 28, _ink(0.22), maxf(1.0, 0.03 * m), true)
	_thin(oc + Vector2(-0.95, 0.0) * m, oc + Vector2(0.95, 0.0) * m, 0.35, 0.05)
	_frost_dots(Rect2(oc - Vector2(0.9, 0.9) * m, Vector2(1.8, 1.8) * m), frost, 33, oc, 0.92 * m)
	_level(Rect2(oc + Vector2(-0.6, 0.35) * m, Vector2(1.2, 0.12) * m), float(c.o2), Color(0.75, 0.88, 1.0))
	_text(oc + Vector2(-0.75, -0.2) * m, PS.w("液氧", "LOX"), 0.32, _ink(0.85))
	_text(oc + Vector2(-0.75, 0.2) * m, "UN1073", 0.2, _ink(0.5))
	_relief(oc + Vector2(0.0, -0.95) * m, frost)
	# the frame's two outlets at its right end and the hose when connected
	var outl := F + Vector2(3.8, 0.0) * m
	# the LH2 line over the LOX sphere's top to the outlets (it must not cross the sphere)
	_jacket(PackedVector2Array([F + Vector2(0.95, -0.75) * m, F + Vector2(1.2, -1.9) * m, F + Vector2(3.38, -1.9) * m, F + Vector2(3.38, 0.3) * m, F + Vector2(3.8, 0.3) * m]), 0.2, frost)
	var ph_conn := ph in ["d_connect", "d_precool", "d_fill", "d_close"]
	if ph_conn:
		var k := clampf(float(c.t) / 2.5, 0.0, 1.0) if ph == "d_connect" else (1.0 - clampf(float(c.t) / 2.5, 0.0, 1.0) if ph == "d_close" else 1.0)
		var wall := _b(Vector2(-0.7, 25.2))
		var mid := wall.lerp(outl, 0.5) + Vector2(0, 0.9 * m * k)
		var tip := wall.lerp(outl, k)
		_jacket(PackedVector2Array([wall, wall.lerp(mid, k), tip]), 0.28, frost)
		if ph in ["d_precool", "d_fill"]:
			_valve(wall + Vector2(-0.2, -1.0) * m, ph == "d_fill")
			if ph == "d_fill":
				# the liquid moving in the line: cold dots crawling to the wall
				var Ln := tip.distance_to(wall)
				var off := fmod(PS.t * 2.2 * m, 0.6 * m)
				var dd := off
				while dd < Ln:
					draw_circle(tip.lerp(wall, dd / Ln), 0.06 * m, Pal.tint(Pal.FLUID, 0.95, 1.5))
					dd += 0.6 * m
	# at the stand: the supply hose to the frame's left while it fills there
	if ph in ["p_precool", "p_fill", "p_close"]:
		var riser_top := _pm(PS.route()[0] + Vector2(-3.6, 0.0))
		var inlet := F + Vector2(-3.2, 0.8) * m
		var k2 := 1.0 - clampf(float(c.t) / 2.0, 0.0, 1.0) if ph == "p_close" else 1.0
		_jacket(PackedVector2Array([riser_top, riser_top.lerp(inlet, k2)]), 0.24, frost)
		_valve(riser_top + Vector2(-0.5, -0.4) * m, ph == "p_fill")
	# the run's status over the frame (one line, small)
	var st := _cryo_words(ph)
	if st != "":
		_text(F + Vector2(-3.8, -2.0) * m, st, 0.36, Color(Pal.tint(Pal.FLUID, 0.9, 1.3), 0.95))


func _cryo_words(ph: String) -> String:
	match ph:
		"p_precool": return PS.w("灌装：管路预冷", "FILL: PRECOOLING THE LINE")
		"p_fill": return PS.w("灌装：开阀", "FILL: VALVE OPEN")
		"p_close": return PS.w("关阀 · 断开软管", "VALVE SHUT · HOSE OFF")
		"lift": return PS.w("起吊", "LIFT")
		"fly": return PS.w("拖船运往动力区", "TO THE POWER DISTRICT")
		"d_connect": return PS.w("对接加注口", "MATING THE FILL COUPLING")
		"d_precool": return PS.w("加注：管路预冷", "PRECOOLING THE LINE")
		"d_fill": return PS.w("加注燃料电池储罐", "FILLING THE FUEL CELLS")
		"d_close": return PS.w("关阀 · 断开软管", "VALVE SHUT · HOSE OFF")
		"back": return PS.w("空罐返回", "BACK EMPTY")
	return ""


func _plume(src: Vector2, dir: Vector2, L: float, wpx: float) -> void:
	var n := dir.orthogonal()
	var flick := 0.9 + 0.1 * sin(PS.t * 37.0 + src.x)
	draw_colored_polygon(PackedVector2Array([src + n * wpx, src - n * wpx, src + dir * L * flick]), Color(UiSkin.ACCENT, 0.5))
	draw_colored_polygon(PackedVector2Array([src + n * wpx * 0.45, src - n * wpx * 0.45, src + dir * L * 0.55 * flick]), Color(1.0, 0.96, 0.88, 0.85))


func _capsule(c: Vector2, half_l: float, r: float, frost: float) -> void:
	var m := M()
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(c + Vector2(half_l - r * 0.55, 0.0) * m + Vector2.from_angle(-PI * 0.5 + PI * i / 12.0) * Vector2(r * 0.55, r) * m)
	for i in 13:
		pts.append(c + Vector2(-half_l + r * 0.55, 0.0) * m + Vector2.from_angle(PI * 0.5 + PI * i / 12.0) * Vector2(r * 0.55, r) * m)
	_poly(pts, 0.85 + 0.15 * frost)
	# the jacket's stiffening rings
	for k in 5:
		var x := -half_l + 0.6 + k * (2.0 * half_l - 1.2) / 4.0
		_thin(c + Vector2(x, -r + 0.08) * m, c + Vector2(x, r - 0.08) * m, 0.25 + 0.3 * frost, 0.04)
	_frost_dots(Rect2(c - Vector2(half_l, r) * m, Vector2(2.0 * half_l, 2.0 * r) * m), frost, 71, c, -1.0, pts)


# frost: a white rime that thickens — speckles inside the shape and a whitened lower edge
func _frost_dots(r: Rect2, frost: float, seed_: int, centre: Vector2, rad: float, poly := PackedVector2Array()) -> void:
	# rime: grows from the lower half and the fittings up as the cold soaks through; specks and a few
	# six-armed crystals, whiter where it is thick
	if frost <= 0.02:
		return
	var m := M()
	var n := int(46 * frost)
	for i in n:
		var hx := absf(fmod(sin(float(i) * 12.9898 + seed_) * 43758.5453, 1.0))
		var hy := absf(fmod(sin(float(i) * 78.233 + seed_ * 1.7) * 12345.678, 1.0))
		# biased low: the band creeps up the shell with the frost
		var yk := 1.0 - hy * hy * clampf(frost * 1.4, 0.2, 1.0)
		var p := r.position + Vector2(hx * r.size.x, yk * r.size.y)
		if rad > 0.0 and p.distance_to(centre) > rad * 0.93:
			continue
		if not poly.is_empty() and not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var a := 0.3 + 0.55 * frost * yk
		if i % 7 == 0:
			var cr := (0.06 + 0.05 * hx) * m
			for k in 3:
				var dv := Vector2.from_angle(PI * k / 3.0 + hy) * cr
				draw_line(p - dv, p + dv, Color(0.93, 0.97, 1.0, a), maxf(1.0, 0.02 * m))
		else:
			draw_circle(p, (0.025 + 0.04 * hx * hy) * m, Color(0.93, 0.97, 1.0, a))
	if not poly.is_empty():
		var rim := poly.slice(0, 13)
		draw_polyline(rim, Color(0.93, 0.97, 1.0, 0.6 * frost), maxf(1.0, 0.12 * m * frost), true)
	elif rad > 0.0:
		draw_arc(centre, rad, 0.15, PI - 0.15, 16, Color(0.93, 0.97, 1.0, 0.6 * frost), maxf(1.0, 0.1 * m * frost), true)


func _level(r: Rect2, k: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, _ink(0.4), false, 1.0)


func _valve(at: Vector2, open: bool) -> void:
	var m := M()
	var h := 0.32 * m
	draw_colored_polygon(PackedVector2Array([at + Vector2(-h, -h * 0.6), at + Vector2(h, h * 0.6), at + Vector2(h, -h * 0.6), at + Vector2(-h, h * 0.6)]), Pal.tint(Pal.FLUID, 0.95, 1.4) if open else _ink(0.55))
	_thin(at, at + Vector2(0, -0.45) * m, 0.7, 0.06)
	draw_line(at + Vector2(-0.25, -0.45) * m, at + Vector2(0.25, -0.45) * m, _ink(0.8), maxf(1.0, 0.07 * m))


# inside the power district: each set's heat bar over it, its trip, the fuel cells' tank
func _inside() -> void:
	var m := M()
	var p := PS.d()
	for id in PS.gen_list():
		var g: Dictionary = p.gens[id]
		var at := _b(Vector2(48.6, 5.2) if id == "tg" else Vector2(1.0, 18.6))
		var wbar := 6.4
		var heat := float(g.get("heat", 0.0))
		var trip: bool = g.get("trip", false)
		var over: bool = g.get("over", false)
		_text(at + Vector2(0, -0.3) * m, "%s%s" % [PS.gen_name(id), PS.w(" · 超载", " · OVERLOAD") if over else ""], 0.42, UiSkin.ACCENT if over or trip else _ink(0.75))
		var br := Rect2(at + Vector2(0, 0.0) * m, Vector2(wbar, 0.3) * m)
		draw_rect(br, Color(0, 0, 0, 0.7))
		var col := Hmi.ok_col().lerp(UiSkin.ACCENT, clampf((heat - 0.4) / 0.4, 0.0, 1.0))
		draw_rect(Rect2(br.position, Vector2(br.size.x * heat, br.size.y)), col)
		draw_rect(br, _ink(0.5), false, 1.0)
		# the trip line at the bar's end
		draw_line(br.end - Vector2(0.0, br.size.y), br.end + Vector2(0, 0.15 * m), Color(1, 0.3, 0.25), maxf(1.0, 0.06 * m))
		_text(at + Vector2(wbar + 0.2, 0.3) * m, PS.w("热量 %d%%", "HEAT %d%%") % int(heat * 100.0), 0.34, _ink(0.65))
		if trip:
			var blink := fmod(PS.t, 0.8) < 0.45
			var rp := _b(PS.repair_at(id))
			draw_arc(rp, 1.1 * m, 0.0, TAU, 32, Color(1, 0.3, 0.25, 0.9 if blink else 0.4), maxf(1.0, 0.1 * m), true)
			draw_arc(rp, (1.1 + 0.5 * fmod(PS.t, 1.0)) * m, 0.0, TAU, 32, Color(1, 0.3, 0.25, 0.4 * (1.0 - fmod(PS.t, 1.0))), maxf(1.0, 0.06 * m), true)
			# the wrench at work: a few sparks off the trip latch while it is held on it
			if PS.fixing:
				for k in 5:
					var ang := PS.t * 9.0 + k * 1.3
					var L := (0.3 + 0.5 * absf(sin(PS.t * 23.0 + k))) * m
					draw_line(rp, rp + Vector2.from_angle(ang) * L, Color(1.0, 0.85, 0.5, 0.85), maxf(1.0, 0.04 * m))
			var fx := float(g.get("fix", 0.0))
			if fx > 0.0:
				draw_arc(rp, 0.8 * m, -PI * 0.5, -PI * 0.5 + TAU * fx, 32, Hmi.ok_col(), maxf(1.0, 0.16 * m), true)
			_text(at + Vector2(0, 1.0) * m, PS.w("过热停机 · 待修：用维护工具（4）按住修一下", "TRIPPED · TAKE THE WRENCH (4) TO IT"), 0.36, Color(1, 0.4, 0.33, 1.0 if blink else 0.75))
	# the fuel cells' tank from the deliveries
	var fk := float(p.get("fc_fuel", 0.0)) / PS.FC_TANK
	var tr := Rect2(_b(Vector2(1.0, 17.0)), Vector2(6.4, 0.26) * m)
	draw_rect(tr, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(tr.position, Vector2(tr.size.x * fk, tr.size.y)), Pal.tint(Pal.FLUID, 0.85, 1.3))
	draw_rect(tr, _ink(0.45), false, 1.0)
	_text(tr.position + Vector2(0, -0.12 * m), PS.w("氢氧储罐 %d%% · 第二组电堆 %s", "H2/O2 TANK %d%% · STACK 2 %s") % [int(fk * 100.0), PS.w("+%.0f 兆瓦" % PS.FC2_MW, "+%.0f MW" % PS.FC2_MW) if fk > 0.0 else PS.w("没燃料", "NO FUEL")], 0.34, _ink(0.6))


# the tug: hull, canopy, main engine aft, propellant spheres seen through the skin, RCS quads, grapple.
# Plumes opposite the acceleration (strict inertia): the main engine pushes forward, the forward quads
# brake, the belly or dorsal quads move it up or down.
func _tug(tug: Vector2, a: Vector2, post: Vector2) -> void:
	var m := M()
	var lw := maxf(1.0, 0.07 * m)
	var al := a.length()
	if al > 0.05:
		var dir := -a.normalized()
		if dir.x < -0.5:
			_plume(tug + Vector2(-2.95, 0.0) * m, Vector2(-1, 0), (1.0 + 1.4 * al) * m, 0.34 * m)
		elif dir.x > 0.5:
			for sy: float in [-1.0, 1.0]:
				_plume(tug + Vector2(2.05, sy * 1.25) * m, Vector2(1.0, sy * 0.55).normalized(), (0.7 + 0.9 * al) * m, 0.18 * m)
		else:
			for sx: float in [-1.5, 1.2]:
				_plume(tug + Vector2(sx, signf(dir.y) * 1.3) * m, Vector2(0, signf(dir.y)), (0.7 + 1.0 * al) * m, 0.18 * m)
	# the main engine's bell aft
	var bell := PackedVector2Array([tug + Vector2(-2.2, -0.2) * m, tug + Vector2(-2.95, -0.4) * m, tug + Vector2(-2.95, 0.4) * m, tug + Vector2(-2.2, 0.2) * m])
	draw_colored_polygon(bell, Color(0.05, 0.05, 0.055))
	draw_polyline(PackedVector2Array([bell[0], bell[1], bell[2], bell[3]]), _ink(0.85), lw, true)
	_thin(tug + Vector2(-2.55, -0.3) * m, tug + Vector2(-2.55, 0.3) * m, 0.35, 0.03)
	# the hull
	var tb := PackedVector2Array([tug + Vector2(-2.2, -1.1) * m, tug + Vector2(1.2, -1.1) * m, tug + Vector2(2.1, -0.5) * m, tug + Vector2(2.1, 0.5) * m,
		tug + Vector2(1.2, 1.1) * m, tug + Vector2(-2.2, 1.1) * m])
	_poly(tb, 0.92, HULL)
	draw_colored_polygon(PackedVector2Array([tug + Vector2(-2.1, -1.1) * m, tug + Vector2(1.2, -1.1) * m, tug + Vector2(1.45, -0.93) * m, tug + Vector2(-2.1, -0.9) * m]), HULL_HI)
	# propellant spheres behind the skin, the frames between
	for sy: float in [-0.45, 0.45]:
		draw_arc(tug + Vector2(-1.3, sy) * m, 0.36 * m, 0.0, TAU, 16, _ink(0.25), lw * 0.7, true)
	for k in 3:
		_thin(tug + Vector2(-1.6 + k * 0.9, -1.0) * m, tug + Vector2(-1.6 + k * 0.9, 1.0) * m, 0.18, 0.03)
	# the canopy, angled, mullioned, with its glint
	var cw := PackedVector2Array([tug + Vector2(0.15, -0.95) * m, tug + Vector2(1.15, -0.95) * m, tug + Vector2(1.75, -0.45) * m, tug + Vector2(0.15, -0.45) * m])
	draw_colored_polygon(cw, Color(UiSkin.DATA, 0.5))
	draw_polyline(PackedVector2Array([cw[0], cw[1], cw[2], cw[3], cw[0]]), _ink(0.75), lw * 0.7, true)
	draw_line(tug + Vector2(0.8, -0.95) * m, tug + Vector2(0.8, -0.45) * m, HULL, lw)
	draw_line(tug + Vector2(0.3, -0.85) * m, tug + Vector2(0.75, -0.85) * m, Color(1, 1, 1, 0.35), lw * 0.6)
	# hazard stripes on the nose
	for k in 4:
		var y := -0.4 + k * 0.22
		draw_line(tug + Vector2(1.95, y) * m, tug + Vector2(2.08, y + 0.12) * m, Color(UiSkin.ACCENT, 0.85), maxf(1.0, 0.08 * m))
	# RCS quads at the four corners
	for q in [Vector2(-1.9, -1.1), Vector2(1.6, -1.1), Vector2(-1.9, 1.1), Vector2(1.6, 1.1)]:
		var qc: Vector2 = tug + q * m
		var sy2 := signf(q.y)
		_solid(Rect2(qc + Vector2(-0.2, -0.16 + 0.1 * sy2) * m, Vector2(0.4, 0.32) * m), 0.75, HULL_HI)
		for nd in [Vector2(0, sy2), Vector2(-1, 0), Vector2(1, 0)]:
			draw_line(qc + Vector2(0, 0.1 * sy2) * m + nd * 0.2 * m, qc + Vector2(0, 0.1 * sy2) * m + nd * 0.3 * m, _ink(0.7), lw)
	# antenna, nav lights, its name
	_thin(tug + Vector2(-0.6, -1.1) * m, tug + Vector2(-0.6, -1.7) * m, 0.65, 0.05)
	draw_circle(tug + Vector2(-0.6, -1.72) * m, 0.07 * m, Color(1, 1, 1, 0.9 if fmod(PS.t, 1.2) < 0.08 else 0.35))
	var blink := fmod(PS.t + 0.3, 1.4) < 0.12
	draw_circle(tug + Vector2(-2.2, -0.9) * m, 0.09 * m, Color(1, 0.3, 0.25, 1.0 if blink else 0.3))
	draw_circle(tug + Vector2(-2.2, 0.9) * m, 0.09 * m, Color(0.3, 1, 0.5, 1.0 if blink else 0.3))
	_text(tug + Vector2(-1.95, 0.75) * m, "TUG-C2", 0.32, _ink(0.7))
	# the grapple: two arms (shoulder, elbow) and two-finger claws closed on the post
	for sy3: float in [-1.0, 1.0]:
		var sh := tug + Vector2(2.1, sy3 * 0.35) * m
		var el := tug + Vector2(2.75, sy3 * 0.75) * m
		var hd := post + Vector2(-0.25, sy3 * 0.55) * m
		draw_line(sh, el, _ink(0.85), maxf(1.5, 0.16 * m), true)
		draw_line(el, hd, _ink(0.85), maxf(1.2, 0.12 * m), true)
		draw_circle(sh, 0.12 * m, HULL_HI)
		draw_arc(sh, 0.12 * m, 0.0, TAU, 10, _ink(0.8), lw * 0.7)
		draw_circle(el, 0.1 * m, HULL_HI)
		draw_arc(el, 0.1 * m, 0.0, TAU, 10, _ink(0.8), lw * 0.7)
		draw_line(hd, hd + Vector2(0.35, -sy3 * 0.12) * m, _ink(0.9), lw)
		draw_line(hd, hd + Vector2(0.35, sy3 * 0.18) * m, _ink(0.9), lw)


# the transport frame: bottom chord, posts with lifting eyes, diagonal bracing, two saddles and straps
func _frame(F: Vector2) -> void:
	var m := M()
	var lw := maxf(1.0, 0.07 * m)
	var fr := Rect2(F + Vector2(-3.8, 1.0) * m, Vector2(7.6, 0.38) * m)
	draw_rect(fr, HULL_HI)
	draw_rect(fr, _ink(0.85), false, lw)
	for k in 8:
		var x := -3.6 + k * 0.95
		draw_line(F + Vector2(x, 1.38) * m, F + Vector2(x + 0.47, 1.0) * m, _ink(0.35), lw * 0.6)
		draw_line(F + Vector2(x + 0.47, 1.0) * m, F + Vector2(x + 0.95, 1.38) * m, _ink(0.35), lw * 0.6)
	for px: float in [-3.8, 3.5]:
		var pr := Rect2(F + Vector2(px, -1.4) * m, Vector2(0.3, 2.4) * m)
		draw_rect(pr, HULL_HI)
		draw_rect(pr, _ink(0.85), false, lw)
		draw_arc(F + Vector2(px + 0.15, -1.55) * m, 0.14 * m, PI, TAU, 8, _ink(0.8), lw, true)
		draw_line(F + Vector2(px + 0.15, 0.95) * m, F + Vector2(px + (0.9 if px < 0.0 else -0.6), 0.2) * m, _ink(0.45), lw * 0.7)
	# saddles under the LH2 tank and the LOX ring
	for sx: float in [-2.6, 0.2]:
		_poly(PackedVector2Array([F + Vector2(sx - 0.45, 1.0) * m, F + Vector2(sx + 0.45, 1.0) * m, F + Vector2(sx + 0.35, 0.65) * m, F + Vector2(sx - 0.35, 0.65) * m]), 0.75, HULL_HI)
		_thin(F + Vector2(sx - 0.3, 0.68) * m, F + Vector2(sx - 0.3, -1.12) * m, 0.4, 0.05)
	_poly(PackedVector2Array([F + Vector2(1.7, 1.0) * m, F + Vector2(2.9, 1.0) * m, F + Vector2(2.6, 0.75) * m, F + Vector2(2.0, 0.75) * m]), 0.75, HULL_HI)


# the fill/drain manifold: two valves on a jacketed header, their handwheels, the quick coupling
func _manifold(at_m: Vector2, frost: float, ph: String) -> void:
	var m := M()
	var at := at_m
	var lw := maxf(1.0, 0.06 * m)
	_jacket(PackedVector2Array([at, at + Vector2(0, -0.35) * m, at + Vector2(1.3, -0.35) * m]), 0.16, frost)
	for k in 2:
		var vp := at + Vector2(0.35 + k * 0.6, -0.35) * m
		_valve(vp, ph in ["p_fill", "d_fill"])
		draw_arc(vp + Vector2(0, -0.48) * m, 0.12 * m, 0.0, TAU, 10, _ink(0.75), lw, true)
	draw_rect(Rect2(at + Vector2(1.25, -0.5) * m, Vector2(0.18, 0.3) * m), Color(UiSkin.ACCENT, 0.85))


# a relief stack: the valve body, the rupture disc's holder, the vent pipe turned away
func _relief(at: Vector2, frost: float) -> void:
	var m := M()
	var lw := maxf(1.0, 0.06 * m)
	_solid(Rect2(at + Vector2(-0.12, -0.3) * m, Vector2(0.24, 0.3) * m), 0.8, HULL_HI)
	draw_line(at + Vector2(0, -0.3) * m, at + Vector2(0, -0.6) * m, _ink(0.75 + 0.2 * frost), lw)
	draw_line(at + Vector2(0, -0.6) * m, at + Vector2(0.22, -0.72) * m, _ink(0.75 + 0.2 * frost), lw)
	draw_rect(Rect2(at + Vector2(-0.16, -0.42) * m, Vector2(0.32, 0.06) * m), Color(UiSkin.ACCENT, 0.8))


func _gauge(at: Vector2, r: float, k: float) -> void:
	var m := M()
	var lw := maxf(1.0, 0.05 * m)
	draw_circle(at, r * m, Color(0.85, 0.87, 0.9))
	draw_arc(at, r * m, 0.0, TAU, 14, _ink(0.9), lw, true)
	var ang := lerpf(PI * 0.75, PI * 2.25, clampf(k, 0.0, 1.0))
	draw_line(at, at + Vector2.from_angle(ang) * r * 0.8 * m, Color(0.1, 0.1, 0.12), lw)
	draw_arc(at, r * 0.8 * m, PI * 1.9, PI * 2.25, 6, Color(1, 0.3, 0.25), lw, false)
