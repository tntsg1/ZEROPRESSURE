extends RefCounted
# 128 号 第 4 段 打包压块机 (缝自《深空压机》; 2026-11-07 问答定案 ③④): a vertical downstroke baler on the
# processing district's floor under the baghouse (方案 A 改). Runs from ProcessLine.press_phase() (real time,
# seen or not); drawn in the district's front layer (scripts/process_art.gd). Box-local metres, floor at 26.8.
#
# 2026-11-12 (user: "压块机从火车上卸下来，然后再放到这个压块机里面，这动画做得很糟糕"; Jev: by the real
# train, a hoist through the spur's hatch). The port is weightless: nothing falls, everything is carried.
#   the train  — the piece comes by freight train (scripts/freight_works.gd: the press's crate, "press") to the
#                spur's stop over the hall; the hatch in the deck under its wagon slides open, the hatch's push
#                plate presses it down out of the hatch between the straddle hoist's two clamp arms, which
#                close on it (the wagon's crate and the piece cross over there: the deck is drawn from above,
#                the hall from the side)
#   land       — the hatch shuts; the hoist's trolley, set in the deck's soffit, runs to over the belt's head
#                (speeding up and braking: a trapezoid), the arms telescope down and set it on the belt,
#                open, and pull up clear
#   feed       — the feed gate in the box's right wall slides up; the cleated belt carries it under the
#                pressure probe, stops, the probe's needle comes down and touches it (0 kPa: on), the belt
#                pushes it through the gate; past the belt's tail it coasts on until the far wall stops it
#   close      — the gate slides down
#   press      — the platen comes down, meets it, sweeps it to the box's floor and crushes it to the bale
#   tie        — three strapping needles run down through the platen's slots, the straps round it
#   eject      — the box's two bottom doors swing down into the pit, the platen pushes the bale through, the
#                pit's drive rollers take it down to the warehouse's line; the platen goes back up, the
#                doors shut
#   a charged one (gas or liquid still inside) is stopped at the probe (approach, probe), its lamp red, and
#                goes back: the belt returns it, the arms take it up the hatch (reject)

const FLOOR := 26.8
const COL_L := 32.15              # the frame's columns
const COL_R := 36.05
const HEAD := Rect2(31.8, 19.9, 4.6, 0.6)     # the crosshead, under the baghouse
const CYL := Rect2(33.4, 20.5, 1.4, 1.6)      # the main cylinder
const BOX := Rect2(32.7, 23.0, 2.8, 3.4)      # the box (chamber), inside
const PLATEN_UP := 22.6                       # the platen's face, up
const PLATEN_T := 0.5
const HATCH_X := 38.6                         # (process_art keeps its floor clear up to here + 1.5)
# the freight spur over the hall: its deck's soffit, the hatches under where its cars stand
# (scripts/freight_works.gd: the stop's head at 39.7, the cars 4.2 and 8.7 m behind it)
const DECK := 16.25
const HATCHES := [39.7, 43.9, 48.4]
const HATCH_W := 2.6
# the straddle hoist: its trolley in the soffit, running from over the belt to the far hatch
const RUN := Vector2(37.0, 50.0)
const TROLLEY_B := 16.75                      # the trolley's underside, where the arms hang from
const CARRY_TOP := 16.95                      # a carried piece's top (just under the hatch)
const LAND_X := 38.5                          # where it sets a piece on the belt
const TRAV_A := 2.5                           # m/s²: the trolley's acceleration and braking
const TRAV_V := 3.0                           # m/s: its top speed
# the belt: level, cleated, from the box's feed gate out to under the hoist
const BELT := Vector2(35.75, 40.05)           # its tail at the gate, its head
const BELT_TOP := 24.6
const BELT_T := 0.42
const GATE_Y := Vector2(23.15, 24.65)         # the feed gate's opening in the box's right wall
const MAX_SIZE := Vector2(2.2, 1.35)          # a piece fitted to the gate (as the belt shows it)
# the pressure probe: a needle on a cylinder hung from the deck, over the belt; its gauge window beside it
const PROBE := Vector2(36.3, 19.4)            # the probe's housing, its top middle
const PROBE_X := 36.3
const PROBE_WIN := Rect2(34.0, 17.45, 2.0, 1.25)
const PIT := Rect2(32.7, 26.4, 2.8, 1.55)     # under the box's bottom doors: down to the warehouse's line
const IRON := Color(0.105, 0.108, 0.118)
const IRON_HI := Color(0.15, 0.152, 0.162)
const DARK := Color(0.06, 0.064, 0.072)
const YEL := Color(0.85, 0.62, 0.2)
const STEEL := Color(0.62, 0.64, 0.68)

static var belt_run := 0.0       # m the belt has run (its cleats), + toward its head (east)
static var belt_v := 0.0         # m/s its surface moves now, + east (tests: tests/belt_direction_check.gd)
static var _bx := NAN            # the piece's x on the belt last step
static var platen := 0.0         # 0 up … 1 at the bale (tests, the gauge)
static var tro_x := LAND_X       # the trolley while it is not on a scripted run (waiting for a train, idle)
static var tro_v := 0.0
static var _seed_parts := {}
static var draw_us := 0.0        # perf tests: the last draw and tick, µs
static var tick_us := 0.0


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func belt_y(_x: float) -> float:
	return BELT_TOP


static func belt_ang() -> float:
	return 0.0


static func e_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func sm(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func k(u: float, a: float, b: float) -> float:
	return clampf((u - a) / maxf(b - a, 1e-4), 0.0, 1.0)


# the bale's height in the box: the more it weighs, the taller (it must pass under the belt in the pit)
static func bale_h(mass: float) -> float:
	return clampf(0.55 + mass * 0.22, 0.6, 1.2)


# the hatch a wagon standing at x hands down through
static func hatch_near(x: float) -> float:
	var best := float(HATCHES[0])
	for h in HATCHES:
		if absf(float(h) - x) < absf(best - x):
			best = float(h)
	return best


# a trapezoid run of d metres (speeding up at TRAV_A to TRAV_V, braking the same): its time, and how far
# along it is t seconds in
static func trav_t(d: float) -> float:
	d = absf(d)
	if d < TRAV_V * TRAV_V / TRAV_A:
		return 2.0 * sqrt(d / TRAV_A)
	return d / TRAV_V + TRAV_V / TRAV_A


static func trav_s(d: float, t: float) -> float:
	var T := trav_t(d)
	var ad := absf(d)
	if T <= 0.0:
		return d
	t = clampf(t, 0.0, T)
	var vp := minf(TRAV_V, sqrt(ad * TRAV_A))
	var ta := vp / TRAV_A
	var s: float
	if t < ta:
		s = 0.5 * TRAV_A * t * t
	elif t < T - ta:
		s = 0.5 * TRAV_A * ta * ta + vp * (t - ta)
	else:
		var r := T - t
		s = ad - 0.5 * TRAV_A * r * r
	return signf(d) * s


# land's steps (s): the hatch shut, the run to the belt, the arms down, open, up clear
const LAND_SHUT := 0.6
const LAND_DOWN := 2.4
const LAND_OPEN := 0.4
const LAND_CLEAR := 0.7
static func land_s(hx: float) -> float:
	if hx < 0.0:
		hx = float(HATCHES[0])
	return LAND_SHUT + trav_t(hx - LAND_X) + LAND_DOWN + LAND_OPEN + LAND_CLEAR


# the thing's look: [size m, lk] (lk {} for loose raw goods), fitted to the gate
static func _look(cur: Dictionary) -> Array:
	var lk: Dictionary = cur.get("look", {})
	if str(lk.get("cat", "")) == "raw" or str(lk.get("key", "")) != "":
		return [Vector2(1.8, 0.8), {}]
	var l := StoreBook.look_any(str(lk.get("ship", "")), str(lk.get("tag", "")), str(lk.get("nk", "")))
	if l.is_empty():
		var s := clampf(0.6 + float(cur.get("mass", 0.5)) * 0.5, 0.8, 1.3)
		return [Vector2(s, s * 0.8), {}]
	var sz: Vector2 = l.size
	var kk := minf(MAX_SIZE.x / maxf(sz.x, 0.1), MAX_SIZE.y / maxf(sz.y, 0.1))
	return [sz * minf(kk, 1.4), l]


# the platen's face (m) now
static func face_at(cur: Dictionary, st: String, u: float) -> float:
	var hb := bale_h(float(cur.get("mass", 1.0))) if not cur.is_empty() else 1.0
	var low := BOX.end.y - hb
	match st:
		"press":
			return lerpf(PLATEN_UP, low, sm(k(u, 0.05, 0.9)))
		"tie":
			return low
		"eject":
			if u < 0.15:
				return low
			if u < 0.5:
				return lerpf(low, BOX.end.y, sm(k(u, 0.15, 0.5)))
			return lerpf(BOX.end.y, PLATEN_UP, e_io(k(u, 0.5, 0.95)))
	return PLATEN_UP


# the bottom doors: 0 shut … 1 hanging open in the pit
static func doors_at(st: String, u: float) -> float:
	if st != "eject":
		return 0.0
	return sm(k(u, 0.0, 0.15)) * (1.0 - sm(k(u, 0.78, 0.95)))


# the feed gate: 0 shut … 1 up
static func gate_at(st: String, u: float) -> float:
	match st:
		"feed":
			return sm(k(u, 0.0, 0.2))
		"close":
			return 1.0 - sm(k(u, 0.1, 0.9))
	return 0.0


# where a piece stops under the probe: its middle under the needle, or as near as it can come without its
# end in the gate (shut for a charged one)
static func probe_stop(pw: float) -> float:
	return maxf(PROBE_X, BELT.x + 0.05 + pw * 0.5)


# the piece's x on the belt in feed (its middle)
static func _feed_x(pw: float, u: float) -> float:
	var ps := probe_stop(pw)
	if u < 0.3:
		return lerpf(LAND_X, ps, e_io(u / 0.3))
	if u < 0.5:
		return ps
	# pushed off: speeding up over the first 0.15 of the stroke, then on at speed until the far wall
	var x_end := BOX.position.x + 0.05 + pw * 0.5
	var d := ps - x_end
	var tt := (u - 0.5) / 0.43
	if tt >= 1.0:
		return x_end
	var a := 0.15
	var s := (tt * tt / (2.0 * a)) if tt < a else (tt - a * 0.5)
	return ps - d * clampf(s / (1.0 - a * 0.5), 0.0, 1.0)


# the probe's needle: 0 up … 1 on the piece
static func needle_at(st: String, u: float) -> float:
	match st:
		"feed":
			return sm(k(u, 0.3, 0.37)) * (1.0 - sm(k(u, 0.43, 0.5)))
		"approach":
			return sm(k(u, 0.75, 1.0))
		"probe":
			return 1.0 - sm(k(u, 0.8, 1.0))
	return 0.0


# the hoist and the hatches now: {x (trolley), sp (the arms' inner span), pad (the pads' height), held,
# top (a held piece's top), hatch {x: open 0…1}, plate (the hatch's push plate: y of its face, or -1), alpha}
static func hoist(cur: Dictionary, st: String, u: float, pw: float, ph: float) -> Dictionary:
	var open_sp := pw + 0.4
	var shut_sp := pw + 0.04
	var park_pad := CARRY_TOP + 0.6
	var out := {"x": tro_x, "sp": open_sp, "pad": park_pad, "held": false, "top": CARRY_TOP, "hatch": {}, "plate": -1.0, "alpha": 1.0}
	var hx := float(cur.get("hx", HATCHES[0])) if not cur.is_empty() else float(HATCHES[0])
	var low_top := BELT_TOP - ph
	match st:
		"wait":
			var hand := hand_now(cur)
			if not hand.is_empty() and float(hand[2]) >= 0.0:
				var ht := float(hand[2])
				var hh := hatch_near(float(hand[3]))
				out.x = hh
				out.hatch = {hh: sm(k(ht, 0.0, 0.25))}
				# the push plate comes down to the hatch's mouth, presses the piece down between the arms
				if ht >= 0.25:
					var top := lerpf(DECK + 0.05, CARRY_TOP, sm(k(ht, 0.62, 0.85)))
					out.plate = lerpf(DECK - 0.6, top, sm(k(ht, 0.25, 0.5))) if ht < 0.95 else lerpf(top, DECK - 0.4, k(ht, 0.95, 1.0))
					if ht >= 0.5:
						out.held = true
						out.top = top
						out.alpha = sm(k(ht, 0.5, 0.62))
						out.pad = top + ph * 0.5
						out.sp = lerpf(open_sp, shut_sp, sm(k(ht, 0.85, 1.0)))
		"land":
			var T := land_s(hx)
			var t := u * T
			var trv := trav_t(hx - LAND_X)
			out.held = true
			out.sp = shut_sp
			out.top = CARRY_TOP
			out.x = hx
			out.hatch = {hatch_near(hx): 1.0 - sm(k(t, 0.0, LAND_SHUT))}
			out.plate = lerpf(DECK - 0.4, DECK - 1.2, k(t, 0.0, 0.3))
			var t1 := t - LAND_SHUT
			if t1 > 0.0:
				out.x = hx + trav_s(LAND_X - hx, t1)
			var t2 := t1 - trv
			if t2 > 0.0:
				out.top = lerpf(CARRY_TOP, low_top, e_io(t2 / LAND_DOWN))
			var t3 := t2 - LAND_DOWN
			if t3 > 0.0:
				out.sp = lerpf(shut_sp, open_sp, sm(t3 / LAND_OPEN))
			var t4 := t3 - LAND_OPEN
			if t4 > 0.0:
				out.held = false
			out.pad = out.top + ph * 0.5
			if t4 > 0.0:
				out.pad = lerpf(low_top + ph * 0.5, low_top - 0.5, e_io(t4 / LAND_CLEAR))
		"feed", "approach", "probe":
			out.x = LAND_X
			# up from where it let go, to parked under the soffit
			var since := u * (float(ProcessLine.PRESS_S[st]))
			if st != "feed" and st != "approach":
				since = 9.0
			out.pad = lerpf(low_top - 0.5, park_pad, e_io(since / 1.6))
		"reject":
			var t := u * float(ProcessLine.PRESS_S.reject)
			out.x = LAND_X
			var grab_top := low_top
			if t < 2.2:
				out.pad = lerpf(park_pad, grab_top + ph * 0.5, e_io(k(t, 0.9, 2.2)))
			elif t < 2.5:
				out.held = true
				out.top = grab_top
				out.pad = grab_top + ph * 0.5
				out.sp = lerpf(open_sp, shut_sp, sm(k(t, 2.2, 2.5)))
			else:
				out.held = true
				out.sp = shut_sp
				out.top = lerpf(grab_top, CARRY_TOP, e_io(k(t, 2.5, 3.8)))
				var h0 := float(HATCHES[0])
				out.x = LAND_X + trav_s(h0 - LAND_X, t - 3.8)
				out.hatch = {h0: sm(k(t, 3.8, 4.3)) * (1.0 - sm(k(t, 5.3, 5.8)))}
				if t > 4.6:
					out.top = lerpf(CARRY_TOP, DECK + 0.05, sm(k(t, 4.6, 5.1)))
					out.alpha = 1.0 - sm(k(t, 5.0, 5.3))
				out.pad = out.top + ph * 0.5
	return out


# the train standing at the spur's stop handing this job's crate down: [train, wagon, t (-1 not yet), x]
static func hand_now(cur: Dictionary) -> Array:
	if cur.is_empty():
		return []
	var FW = load("res://scripts/freight_works.gd")
	var h: Array = FW.press_hand()
	if h.is_empty():
		return []
	var it = h[0].wag[int(h[1])]
	if not (it is Dictionary) or str(it.get("press", "")) != str(cur.get("id", "")):
		return []
	return [h[0], h[1], float(h[2]), FW.press_x(h[0], int(h[1]))]


# where the thing is and how it is squeezed now: {at (bottom-centre, m), size, sx, sy, rot, shown, crush, alpha}
static func _pose(cur: Dictionary, ph: String, u: float) -> Dictionary:
	var lk := _look(cur)
	var sz: Vector2 = lk[0]
	var out := {"size": sz, "sx": 1.0, "sy": 1.0, "rot": 0.0, "shown": true, "at": Vector2(LAND_X, BELT_TOP), "crush": 0.0, "alpha": 1.0}
	match ph:
		"wait", "land", "reject":
			var hs := hoist(cur, ph, u, sz.x, sz.y)
			if ph == "reject" and not bool(hs.held) and u * float(ProcessLine.PRESS_S.reject) < 2.2:
				# rolled back along the belt to under the hoist
				var t := u * float(ProcessLine.PRESS_S.reject)
				var rx := lerpf(probe_stop(sz.x), LAND_X, e_io(k(t, 0.0, 0.9)))
				out.at = Vector2(rx, BELT_TOP)
				return out
			if ph == "land" and not bool(hs.held):
				out.at = Vector2(LAND_X, BELT_TOP)
				return out
			out.shown = bool(hs.held) and float(hs.alpha) > 0.01
			out.alpha = float(hs.alpha)
			out.at = Vector2(float(hs.x), float(hs.top) + sz.y)
		"feed":
			out.at = Vector2(_feed_x(sz.x, u), BELT_TOP)
		"approach":
			out.at = Vector2(lerpf(LAND_X, probe_stop(sz.x), e_io(k(u, 0.0, 0.7))), BELT_TOP)
		"probe":
			out.at = Vector2(probe_stop(sz.x), BELT_TOP)
		"close":
			out.at = Vector2(BOX.position.x + 0.05 + sz.x * 0.5, BELT_TOP)
		"press", "tie", "eject":
			var hb := bale_h(float(cur.mass))
			var face := face_at(cur, ph, u)
			var x0 := BOX.position.x + 0.05 + sz.x * 0.5
			if ph == "press":
				# floating where it stopped until the platen meets it, then swept down, then crushed
				var bottom := clampf(face + sz.y, BELT_TOP, BOX.end.y)
				var hgt := bottom - maxf(face, bottom - sz.y)
				var c := clampf((sz.y - hgt) / maxf(sz.y - hb, 0.01), 0.0, 1.0)
				out.crush = c
				var fit_x := (BOX.size.x - 0.08) / maxf(sz.x, 0.1)
				out.sx = lerpf(1.0, fit_x, c)
				out.sy = hgt / maxf(sz.y, 0.01)
				out.at = Vector2(lerpf(x0, BOX.get_center().x, c), bottom)
			else:
				var fit_x2 := (BOX.size.x - 0.08) / maxf(sz.x, 0.1)
				out.crush = 1.0
				out.sx = fit_x2
				out.sy = hb / maxf(sz.y, 0.1)
				var bottom2 := BOX.end.y
				if ph == "eject":
					if u < 0.5:
						bottom2 = face + hb
					else:
						bottom2 = BOX.end.y + hb + (28.0 - BOX.end.y) * sm(k(u, 0.5, 0.75))
					out.shown = bottom2 - hb < PIT.end.y
				out.at = Vector2(BOX.get_center().x, bottom2)
	return out


static func tick(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_tick(dt)
	tick_us = Time.get_ticks_usec() - t0


static func _tick(dt: float) -> void:
	var ph: Array = ProcessLine.press_phase()
	var st := str(ph[0])
	var u := float(ph[1])
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {}) if not pr.is_empty() else {}
	# the belt's surface moves exactly as the piece on it does (cleats: no sliding)
	var on_belt := false
	var x := 0.0
	if not cur.is_empty() and st in ["feed", "approach", "probe", "reject"]:
		var pose := _pose(cur, st, u)
		var pw := float((pose.size as Vector2).x)
		x = float((pose.at as Vector2).x)
		on_belt = float((pose.at as Vector2).y) >= BELT_TOP - 0.01 and x + pw * 0.5 > BELT.x and x - pw * 0.5 < BELT.y
		if st == "reject" and u * float(ProcessLine.PRESS_S.reject) > 2.2:
			on_belt = false
	belt_v = 0.0
	if on_belt:
		if not is_nan(_bx):
			belt_run += x - _bx
			belt_v = (x - _bx) / maxf(dt, 1e-4)
		_bx = x
	else:
		_bx = NAN
	platen = clampf((face_at(cur, st, u) - PLATEN_UP) / maxf(BOX.end.y - 1.0 - PLATEN_UP, 0.1), 0.0, 1.0)
	# the trolley between its scripted runs: to the hatch a train is about to hand down through, else home
	var want := LAND_X
	var hand := hand_now(cur) if st == "wait" else []
	if not hand.is_empty():
		want = hatch_near(float(hand[3]))
		if float(hand[2]) >= 0.0:
			# handing down: the arms are under the hatch (the train's approach gave them the time)
			tro_x = want
			tro_v = 0.0
			return
	if st in ["land", "feed", "approach", "probe"]:
		tro_x = LAND_X
		tro_v = 0.0
		return
	if st == "reject":
		var lk := _look(cur)
		tro_x = float(hoist(cur, st, u, (lk[0] as Vector2).x, (lk[0] as Vector2).y).x)
		tro_v = 0.0
		return
	# speed toward it, braking in time (守惯性)
	var d := want - tro_x
	var stop_v := sqrt(2.0 * TRAV_A * absf(d))
	var v_want := signf(d) * minf(TRAV_V, stop_v)
	tro_v = move_toward(tro_v, v_want, TRAV_A * dt)
	tro_x += tro_v * dt
	if absf(want - tro_x) < 0.01 and absf(tro_v) < 0.05:
		tro_x = want
		tro_v = 0.0


# ================================================================== drawing
static func draw(ci: CanvasItem, a, t: float, lod: int) -> void:
	var t0 := Time.get_ticks_usec()
	# 2026-11-12: in the districts' solid look its members have more to them (shade, shadow, edges); all
	# its shapes gathered into a few triangle batches (scripts/canvas_batch.gd) so it costs no more a frame
	if DistrictStyle.solid():
		var cb = preload("res://scripts/canvas_batch.gd").new(ci)
		_draw(cb, a, t, lod)
		cb.flush()
	else:
		_draw(ci, a, t, lod)
	draw_us = Time.get_ticks_usec() - t0


static func _draw(ci, a, t: float, lod: int) -> void:
	var m: float = a.m
	var lw := maxf(1.0, 0.035 * m)
	var P := func(v: Vector2) -> Vector2: return a._p(v)
	var pr := ProcessLine.press()
	var cur: Dictionary = pr.get("cur", {}) if not pr.is_empty() else {}
	var ph: Array = ProcessLine.press_phase() if not pr.is_empty() else ["idle", 0.0]
	var st := str(ph[0])
	var u := float(ph[1])
	var ink := DistrictStyle.ink(0.6)
	var lk := _look(cur) if not cur.is_empty() else [Vector2(1.6, 1.0), {}]
	var psz: Vector2 = lk[0]
	var hs := hoist(cur, st, u, psz.x, psz.y)
	# ---- the hydraulic hoses up from the basement gland to the cylinder
	var hose := Color(0.12, 0.12, 0.13)
	for kk in 2:
		var pts := PackedVector2Array()
		var from := Vector2(COL_L - 0.6 + kk * 0.22, FLOOR)
		var to := Vector2(CYL.position.x, CYL.position.y + 0.4 + kk * 0.8)
		for q in 9:
			var f := q / 8.0
			pts.append(P.call(from.lerp(to, f) + Vector2(-0.35 * sin(f * PI), 0.0)))
		ci.draw_polyline(pts, hose, maxf(1.0, 0.09 * m))
	_box(ci, P, m, Rect2(COL_L - 0.85, FLOOR - 0.18, 0.7, 0.18), DARK, lw)
	var gauge := Vector2(COL_L - 0.5, FLOOR - 0.75)
	ci.draw_circle(P.call(gauge), 0.16 * m, Color(0.03, 0.035, 0.04))
	ci.draw_arc(P.call(gauge), 0.16 * m, 0.0, TAU, 12, ink, lw)
	var load := 0.9 if st == "press" else (0.6 if st == "eject" and u > 0.15 and u < 0.5 else (0.4 if st in ["close", "tie", "eject"] else 0.08))
	ci.draw_line(P.call(gauge), P.call(gauge + Vector2.from_angle(PI * 0.75 + PI * 1.5 * load) * 0.13), Pal.heat(0.9, 1.3), lw)
	# ---- the pit under the box: its walls, the drive rollers that take a bale down
	ci.draw_rect(Rect2(P.call(PIT.position), PIT.size * m), Color(0.02, 0.022, 0.026))
	for wx in [PIT.position.x - 0.18, PIT.end.x]:
		_box(ci, P, m, Rect2(wx, PIT.position.y, 0.18, PIT.size.y), IRON, lw)
	var roll_turn := 0.0
	if st == "eject":
		roll_turn = (28.0 - BOX.end.y) * sm(k(u, 0.5, 0.75)) / 0.14
	for ry in [PIT.position.y + 0.55, PIT.position.y + 1.2]:
		for rx in [PIT.position.x + 0.14, PIT.end.x - 0.14]:
			var rc := Vector2(rx, ry)
			ci.draw_circle(P.call(rc), 0.14 * m, IRON_HI)
			ci.draw_arc(P.call(rc), 0.14 * m, 0.0, TAU, 10, DistrictStyle.ink(0.45), lw)
			var sgn := 1.0 if rx < PIT.get_center().x else -1.0
			ci.draw_line(P.call(rc), P.call(rc + Vector2.from_angle(sgn * roll_turn) * 0.12), DistrictStyle.ink(0.45), lw)
	# ---- the box: its back plate (a cut-away inspection side)
	if not DistrictStyle.solid_rect(ci, Rect2(P.call(BOX.position), BOX.size * m), Color(0.035, 0.037, 0.042), m):
		ci.draw_rect(Rect2(P.call(BOX.position), BOX.size * m), Color(0.035, 0.037, 0.042))
	var y := BOX.position.y + 0.6
	while y < BOX.end.y:
		ci.draw_line(P.call(Vector2(BOX.position.x, y)), P.call(Vector2(BOX.end.x, y)), DistrictStyle.ink(0.06), lw)
		y += 0.6
	# ---- the frame: columns, crosshead, the main cylinder and its rod, the platen on its guides
	for cx in [COL_L, COL_R]:
		_box(ci, P, m, Rect2(cx - 0.18, HEAD.end.y, 0.36, FLOOR - HEAD.end.y), IRON_HI, lw)
		ci.draw_line(P.call(Vector2(cx, HEAD.end.y + 0.2)), P.call(Vector2(cx, FLOOR - 0.2)), DistrictStyle.ink(0.12), lw)
	_box(ci, P, m, HEAD, IRON_HI, lw)
	for bx in [HEAD.position.x + 0.25, HEAD.end.x - 0.25]:
		ci.draw_circle(P.call(Vector2(bx, HEAD.get_center().y)), 0.07 * m, DistrictStyle.ink(0.5))
	_box(ci, P, m, CYL, Color(0.18, 0.19, 0.21), lw)
	ci.draw_rect(Rect2(P.call(CYL.position + Vector2(0.1, 0.0)), Vector2(0.18, CYL.size.y) * m), Color(1, 1, 1, 0.06))
	var face := face_at(cur, st, u)
	ci.draw_rect(Rect2(P.call(Vector2(CYL.get_center().x - 0.28, CYL.end.y)), Vector2(0.56, face - PLATEN_T - CYL.end.y) * m), Color(0.7, 0.72, 0.76))
	ci.draw_line(P.call(Vector2(CYL.get_center().x - 0.16, CYL.end.y)), P.call(Vector2(CYL.get_center().x - 0.16, face - PLATEN_T)), Color(1, 1, 1, 0.5), lw)
	var plat := Rect2(Vector2(BOX.position.x + 0.04, face - PLATEN_T), Vector2(BOX.size.x - 0.08, PLATEN_T))
	_box(ci, P, m, plat, YEL, lw)
	ci.draw_line(P.call(plat.position + Vector2(0.0, 0.12)), P.call(plat.position + Vector2(plat.size.x, 0.12)), Color(0.1, 0.1, 0.1, 0.5), lw)
	# the platen's three strapping slots
	for sk in 3:
		var sx := plat.position.x + plat.size.x * (0.2 + 0.3 * sk)
		ci.draw_rect(Rect2(P.call(Vector2(sx - 0.04, plat.position.y)), Vector2(0.08, PLATEN_T) * m), Color(0.1, 0.08, 0.04))
	# the thing (in the box, on the belt, or in the hoist's arms)
	if not cur.is_empty() and st != "idle":
		_thing(ci, a, cur, st, u, t, lw)
	# the box's walls; the feed gate in the right wall's top, its guide box over it
	_box(ci, P, m, Rect2(BOX.position.x - 0.18, BOX.position.y, 0.18, BOX.size.y), IRON, lw)
	_box(ci, P, m, Rect2(BOX.end.x, GATE_Y.y, 0.18, BOX.end.y - GATE_Y.y), IRON, lw)
	_box(ci, P, m, Rect2(BOX.end.x, BOX.position.y, 0.18, GATE_Y.x - BOX.position.y), IRON, lw)
	for kk in 4:
		var ry := BOX.position.y + 0.5 + kk * 0.8
		ci.draw_rect(Rect2(P.call(Vector2(BOX.position.x - 0.26, ry)), Vector2(0.18, 0.26) * m), IRON_HI)
	var gate := gate_at(st, u)
	var gh := GATE_Y.y - GATE_Y.x
	_box(ci, P, m, Rect2(BOX.end.x - 0.06, GATE_Y.x - gh - 0.25, 0.3, gh + 0.25), DARK, lw)
	_box(ci, P, m, Rect2(BOX.end.x + 0.02, GATE_Y.x - gh * gate, 0.14, gh), YEL if gate > 0.01 else IRON_HI, lw)
	# the bottom: the frame round the doors, the two doors (hinged at the walls, swinging down into the pit)
	_box(ci, P, m, Rect2(BOX.position.x - 0.18, BOX.end.y, 0.18, 0.4), IRON, lw)
	_box(ci, P, m, Rect2(BOX.end.x, BOX.end.y, 0.18, 0.4), IRON, lw)
	var dr := doors_at(st, u)
	var dl := BOX.size.x * 0.5 - 0.02
	for sd in [-1.0, 1.0]:
		var hinge := Vector2(BOX.position.x if sd < 0.0 else BOX.end.x, BOX.end.y + 0.2)
		var ang: float = (0.0 if sd < 0.0 else PI) - float(sd) * dr * PI * 0.5
		var tip: Vector2 = hinge + Vector2.from_angle(ang) * dl
		ci.draw_line(P.call(hinge), P.call(tip), YEL if dr > 0.01 else IRON_HI, maxf(1.0, 0.11 * m))
		ci.draw_circle(P.call(hinge), 0.1 * m, DistrictStyle.ink(0.5))
	# ---- the belt: level, cleated, its drums, its legs to the floor, the drive under its head
	var t0 := Vector2(BELT.x, BELT_TOP)
	var t1 := Vector2(BELT.y, BELT_TOP)
	for lx in [BELT.x + 0.9, BELT.y - 0.9]:
		ci.draw_line(P.call(Vector2(lx, BELT_TOP + BELT_T)), P.call(Vector2(lx, FLOOR - 0.05)), DistrictStyle.ink(0.3), maxf(1.0, 0.07 * m))
	if not DistrictStyle.solid_rect(ci, Rect2(P.call(t0), Vector2(BELT.y - BELT.x, BELT_T) * m), Color(0.09, 0.094, 0.104), m):
		ci.draw_rect(Rect2(P.call(t0), Vector2(BELT.y - BELT.x, BELT_T) * m), Color(0.09, 0.094, 0.104))
	ci.draw_line(P.call(t0), P.call(t1), DistrictStyle.ink(0.6), lw)
	ci.draw_line(P.call(t0 + Vector2(0, BELT_T)), P.call(t1 + Vector2(0, BELT_T)), DistrictStyle.ink(0.3), lw)
	var cx2 := BELT.x + 0.2 + fposmod(belt_run, 0.7)
	while cx2 < BELT.y - 0.2:
		ci.draw_line(P.call(Vector2(cx2, BELT_TOP)), P.call(Vector2(cx2, BELT_TOP - 0.1)), DistrictStyle.ink(0.45), lw)
		cx2 += 0.7
	for ex in [BELT.x + 0.21, BELT.y - 0.21]:
		var dc := Vector2(ex, BELT_TOP + 0.21)
		ci.draw_circle(P.call(dc), 0.2 * m, IRON_HI)
		ci.draw_arc(P.call(dc), 0.2 * m, 0.0, TAU, 12, ink, lw)
		ci.draw_line(P.call(dc), P.call(dc + Vector2.from_angle(belt_run / 0.2) * 0.18), ink, lw)
	_box(ci, P, m, Rect2(BELT.y - 0.8, BELT_TOP + 0.55, 0.7, 0.5), Color(0.2, 0.22, 0.26), lw)
	# ---- the pressure probe: its cylinder hung from the deck, the needle down to the piece, its lamp
	ci.draw_line(P.call(Vector2(PROBE.x, DECK)), P.call(PROBE), DistrictStyle.ink(0.3), maxf(1.0, 0.07 * m))
	_box(ci, P, m, Rect2(PROBE - Vector2(0.25, 0.0), Vector2(0.5, 1.0)), IRON_HI, lw)
	var nd := needle_at(st, u)
	var touch_y := BELT_TOP - psz.y - 0.02
	var tip_y := lerpf(PROBE.y + 1.25, touch_y, nd)
	ci.draw_line(P.call(Vector2(PROBE.x, PROBE.y + 1.0)), P.call(Vector2(PROBE.x, tip_y)), STEEL, maxf(1.0, 0.07 * m))
	ci.draw_circle(P.call(Vector2(PROBE.x, tip_y)), 0.06 * m, DistrictStyle.ink(0.8))
	var bad: bool = st in ["probe", "reject"] and cur.get("charged", false)
	var lamp := PROBE + Vector2(0.45, 0.3)
	ci.draw_circle(P.call(lamp), 0.14 * m, Color(1.0, 0.25, 0.2, 0.9 if fmod(t, 0.5) < 0.3 else 0.35) if bad else (Pal.tint(Pal.FLUID, 0.9, 1.3) if nd > 0.9 else DistrictStyle.ink(0.2)))
	# its gauge window (2026-11-10: background glass, words small and dim) on a bracket off the cylinder
	var CA = preload("res://scripts/console_art.gd")
	var scr := PROBE_WIN
	ci.draw_line(P.call(Vector2(scr.end.x, scr.get_center().y)), P.call(Vector2(PROBE.x, PROBE.y + 0.3)), DistrictStyle.ink(0.25), lw)
	ci.draw_line(P.call(Vector2(scr.get_center().x, DECK)), P.call(Vector2(scr.get_center().x, scr.position.y)), DistrictStyle.ink(0.25), lw)
	ci.draw_rect(Rect2(P.call(scr.position), scr.size * m), CA.BG_GLASS)
	ci.draw_rect(Rect2(P.call(scr.position), scr.size * m), DistrictStyle.ink(0.22), false, lw)
	if Pal.labels:
		var line1 := w("压力探头", "PRESSURE PROBE")
		var line2 := w("待料", "IDLE")
		if bad:
			line1 = w("有压力 · 拒收", "PRESSURE · REJECTED")
			line2 = str(cur.get("held", ""))
		elif nd > 0.5:
			line2 = w("0 kPa · 放行", "0 kPa · CLEAR")
		a._text(ci, scr.position + Vector2(0.12, 0.5), line1, 0.22, CA.bg(Color(1.0, 0.45, 0.4) if bad else Pal.tint(Pal.AIR, 0.85, 1.3)))
		a._text(ci, scr.position + Vector2(0.12, 0.98), line2, 0.2, CA.bg(Color(1.0, 0.6, 0.55) if bad else Pal.tint(Pal.AIR, 0.7, 1.2)))
	else:
		# no words on the machine: a dial and a bar (the reading), red while it holds pressure
		var dial := scr.position + Vector2(0.45, scr.size.y * 0.5)
		ci.draw_arc(P.call(dial), 0.3 * m, PI * 0.8, PI * 2.2, 14, DistrictStyle.ink(0.35), lw)
		var rd := 0.85 if bad else 0.04
		ci.draw_line(P.call(dial), P.call(dial + Vector2.from_angle(PI * 0.8 + PI * 1.4 * rd) * 0.26), Color(1.0, 0.4, 0.35) if bad else Pal.tint(Pal.AIR, 0.8, 1.2), lw)
		var bar := Rect2(scr.position + Vector2(0.95, 0.5), Vector2(0.85, 0.22))
		ci.draw_rect(Rect2(P.call(bar.position), bar.size * m), Color(0.02, 0.03, 0.035))
		ci.draw_rect(Rect2(P.call(bar.position), Vector2(bar.size.x * (0.9 if bad else 0.05), bar.size.y) * m), Color(1.0, 0.35, 0.3, 0.8) if bad else Pal.tint(Pal.AIR, 0.6, 1.1))
	if bad:
		ci.draw_rect(Rect2(P.call(scr.position), scr.size * m), Color(0.6, 0.08, 0.05, 0.14 + 0.06 * sin(t * 9.0)))
	# ---- the spur's soffit: the hoist's runway, the hatches (their sliding doors), the push plate
	_box(ci, P, m, Rect2(RUN.x, DECK, RUN.y - RUN.x, 0.22), IRON, lw)
	var hatch: Dictionary = hs.hatch
	for hx in HATCHES:
		var op := float(hatch.get(hx, 0.0))
		var hl := float(hx) - HATCH_W * 0.5
		ci.draw_rect(Rect2(P.call(Vector2(hl, DECK)), Vector2(HATCH_W, 0.22) * m), Color(0.02, 0.022, 0.026) if op > 0.01 else IRON_HI)
		for sd in [-1.0, 1.0]:
			var leaf_w := HATCH_W * 0.5 * (1.0 - op)
			var lx0 := float(hx) + (-HATCH_W * 0.5 if sd < 0.0 else HATCH_W * 0.5 - leaf_w)
			if leaf_w > 0.01:
				_box(ci, P, m, Rect2(lx0, DECK + 0.02, leaf_w, 0.18), YEL if op > 0.01 else IRON_HI, lw)
		ci.draw_line(P.call(Vector2(hl, DECK + 0.22)), P.call(Vector2(hl + HATCH_W, DECK + 0.22)), DistrictStyle.ink(0.4), lw)
	var plate := float(hs.plate)
	if plate > DECK - 0.3:
		var px := float(hs.x)
		_box(ci, P, m, Rect2(px - minf(psz.x * 0.4, 1.0), plate - 0.14, minf(psz.x * 0.8, 2.0), 0.14), YEL, lw)
		ci.draw_line(P.call(Vector2(px, DECK - 0.2)), P.call(Vector2(px, plate - 0.14)), STEEL, maxf(1.0, 0.12 * m))
	# ---- the straddle hoist: the trolley's two end trucks in the soffit (its cross girder behind),
	# the two telescoping arms down to their clamp pads
	var tx := float(hs.x)
	var sp := float(hs.sp)
	var pad := float(hs.pad)
	var arm_x := sp * 0.5 + 0.18
	ci.draw_line(P.call(Vector2(tx - arm_x, DECK + 0.4)), P.call(Vector2(tx + arm_x, DECK + 0.4)), DistrictStyle.ink(0.18), maxf(1.0, 0.12 * m))
	for sd in [-1.0, 1.0]:
		var ax: float = tx + sd * arm_x
		_box(ci, P, m, Rect2(ax - 0.35, DECK + 0.22, 0.7, TROLLEY_B - DECK - 0.22), Color(0.2, 0.21, 0.23), lw)
		for wx in [ax - 0.2, ax + 0.2]:
			ci.draw_circle(P.call(Vector2(wx, DECK + 0.3)), 0.07 * m, DistrictStyle.ink(0.5))
		# three telescoping sections, each a little narrower, sharing the length
		var top := TROLLEY_B
		var bot := pad + 0.35
		var L := bot - top
		var ws := [0.22, 0.17, 0.12]
		for s in 3:
			var s0 := top + L * s / 3.0 - (0.08 if s > 0 else 0.0)
			var s1 := top + L * (s + 1) / 3.0
			var ww: float = ws[s]
			ci.draw_rect(Rect2(P.call(Vector2(ax - ww * 0.5, s0)), Vector2(ww, s1 - s0) * m), Color(0.2, 0.21, 0.23) if s == 0 else STEEL.darkened(0.25 * s))
			ci.draw_rect(Rect2(P.call(Vector2(ax - ww * 0.5, s0)), Vector2(ww, s1 - s0) * m), DistrictStyle.ink(0.4), false, lw)
		# the pad on the arm's foot, facing in
		var pr2 := Rect2(Vector2(ax - sd * 0.18 - (0.12 if sd > 0.0 else 0.0), pad - 0.3), Vector2(0.12, 0.6))
		_box(ci, P, m, pr2, YEL, lw)
	if Pal.labels and lod > 0:
		_box(ci, P, m, Rect2(BOX.position.x + 0.4, BOX.position.y - 1.1, 2.0, 0.5), DARK, lw)
		a._text(ci, Vector2(BOX.position.x + 0.5, BOX.position.y - 0.72), w("打包压块机 BP-1", "BALER BP-1"), 0.26, DistrictStyle.ink(0.6))


static func _box(ci, P: Callable, m: float, r: Rect2, fill: Color, lw: float) -> void:
	# 2026-11-12 (the districts' solid look, user: "纯2D、纯扁平"): the frame's members as lit steel —
	# shade, shadow, lit and dark edges (DistrictStyle.solid_rect); drawing only, nothing it does changes
	if not DistrictStyle.solid_rect(ci, Rect2(P.call(r.position), r.size * m), fill, m, true):
		ci.draw_rect(Rect2(P.call(r.position), r.size * m), fill)
	ci.draw_rect(Rect2(P.call(r.position), r.size * m), DistrictStyle.ink(0.5), false, lw)


# the thing: its own outline and lines, squeezed; the crumple's creases and the straps over it
static func _thing(ci, a, cur: Dictionary, st: String, u: float, t: float, lw: float) -> void:
	var m: float = a.m
	var pose := _pose(cur, st, u)
	if not pose.shown:
		return
	var lk := _look(cur)
	var sz: Vector2 = pose.size
	var sx := float(pose.sx)
	var sy := float(pose.sy)
	var crush := float(pose.crush)
	var at: Vector2 = pose.at
	var al := float(pose.alpha)
	var bale := st in ["tie", "eject"]
	if not bale:
		var xf := Transform2D(float(pose.rot), Vector2(sx * m, sy * m), 0.0, a._p(at))
		ci.draw_set_transform_matrix(xf)
		var l: Dictionary = lk[1]
		var col := Color(0.14, 0.145, 0.16, al)
		if l.is_empty():
			# loose goods: a heap of scrap bits in a strapped cage
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str(cur.get("id", "")))
			var pts := PackedVector2Array([Vector2(-sz.x * 0.5, 0.0)])
			for kk in 11:
				pts.append(Vector2(-sz.x * 0.5 + sz.x * (kk + 0.5) / 11.0, -sz.y * rng.randf_range(0.55, 1.0)))
			pts.append(Vector2(sz.x * 0.5, 0.0))
			ci.draw_colored_polygon(pts, Color(0.26, 0.25, 0.23, al))
			for kk in 10:
				var p0 := Vector2(rng.randf_range(-0.45, 0.45) * sz.x, -rng.randf_range(0.1, 0.7) * sz.y)
				ci.draw_line(p0, p0 + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 0.35, Color(0.45, 0.43, 0.4, al), 0.05)
		else:
			var asz: Vector2 = l.size
			var k2 := sz.x / maxf(asz.x, 0.01)
			var poly: PackedVector2Array = l.poly
			var pts2 := PackedVector2Array()
			var i := 0
			for q in poly:
				var v: Vector2 = q * k2 - Vector2(sz.x * 0.5, sz.y)
				v += Vector2(sin(i * 2.7) * 0.12, cos(i * 1.9) * 0.08) * crush
				pts2.append(v)
				i += 1
			if pts2.size() >= 3:
				ci.draw_colored_polygon(pts2, col)
				pts2.append(pts2[0])
				ci.draw_polyline(pts2, DistrictStyle.ink(0.75 * al), 0.04 / maxf(sx, 0.2))
			if str(l.art) != "" and al > 0.5:
				ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k2 / Geom.M, k2 / Geom.M), 0.0, -Vector2(sz.x * 0.5, sz.y)))
				# (drawn through a CanvasBatch in the solid look: its shapes so far out first, the art straight to
				# the node — it draws on a CanvasItem)
				var art_ci = ci
				if not (ci is CanvasItem):
					ci.flush()
					art_ci = ci.node
				Art.draw(art_ci, str(l.art), asz * Geom.M, null, Fonts.get_font("Regular"))
				ci.draw_set_transform_matrix(xf)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if crush > 0.05:
		# the crushed block: dense creases where the metal folded, the edges ragged (the part of it still
		# above the pit's foot: going down to the warehouse's line it passes out of the hall)
		var hb := sz.y * sy
		var wb := sz.x * sx
		var top := at.y - hb
		var bot := minf(at.y, PIT.end.y)
		if bot - top > 0.02:
			var r := Rect2(a._p(Vector2(at.x - wb * 0.5, top)), Vector2(wb, bot - top) * m)
			ci.draw_rect(r, Color(0.2, 0.2, 0.21, 0.4 * crush * crush) if not bale else Color(0.17, 0.17, 0.18))
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = hash(str(cur.get("id", ""))) + 3
			var full := Rect2(a._p(Vector2(at.x - wb * 0.5, top)), Vector2(wb, hb) * m)
			for kk in int(10 + 22 * crush):
				var p1 := full.position + Vector2(rng2.randf() * full.size.x, rng2.randf() * full.size.y)
				var d := Vector2.from_angle(rng2.randf_range(-0.6, 0.6)) * rng2.randf_range(0.2, 0.7) * m
				if p1.y < r.end.y and p1.y + d.y < r.end.y:
					ci.draw_line(p1, p1 + d, DistrictStyle.ink(0.32 * crush), lw)
			ci.draw_rect(r, DistrictStyle.ink(0.6 * crush), false, lw)
			# the straps: run down by the needles through the platen's slots, then round it
			var strap := 0.0
			if st == "tie":
				strap = sm(k(u, 0.05, 0.65))
			elif st == "eject":
				strap = 1.0
			for kk in 3:
				var sxk := r.position.x + r.size.x * (0.2 + 0.3 * kk)
				var len := r.size.y * strap
				if len > 0.0:
					ci.draw_line(Vector2(sxk, r.position.y), Vector2(sxk, r.position.y + len), Color(0.75, 0.75, 0.8), maxf(1.0, 0.05 * m))
				if st == "tie" and strap < 1.0:
					# the needle's tip leading the strap down
					ci.draw_circle(Vector2(sxk, r.position.y + len), 0.06 * m, Pal.heat(0.9, 1.4))
				if st == "tie" and u > 0.7:
					# the knotter clamps it under the bale: a small bright seal
					ci.draw_rect(Rect2(Vector2(sxk - 0.08 * m, r.end.y - 0.1 * m), Vector2(0.16, 0.1) * m), Color(0.8, 0.8, 0.85, sm(k(u, 0.7, 0.85))))
	# the dust and the sparks of the crush
	if st == "press" and crush > 0.05 and crush < 0.98:
		var base: Vector2 = a._p(at)
		for kk in 6:
			var ph := fposmod(t * 2.3 + kk * 0.17, 1.0)
			var side := -1.0 if kk % 2 == 0 else 1.0
			var p2 := base + Vector2(side * (BOX.size.x * 0.3 + ph * 0.25) * m, -(0.3 + ph * 0.9) * m)
			ci.draw_circle(p2, (0.06 + 0.12 * ph) * m, Color(0.45, 0.43, 0.4, 0.35 * (1.0 - ph)))
		if fmod(t, 0.31) < 0.12:
			for kk in 4:
				var sp: Vector2 = a._p(at + Vector2(randf_range(-1.0, 1.0), -sz.y * sy))
				ci.draw_line(sp, sp + Vector2(randf_range(-0.3, 0.3), randf_range(-0.4, -0.1)) * m, Pal.heat(1.0, 1.6), lw)
