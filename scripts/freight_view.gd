extends Node2D
# 130 号: the freight trains drawn (scripts/freight_works.gd runs them): a locomotive and two roller-bed
# flat wagons each, the crates on them (metal as bundles, skips, pallets; a machine in an open cage
# with its own line art — scripts/hub_art.gd goods_at), the crate the rollers are moving between a
# wagon and a hatch, the lock lamps; the floor lifts at the district freight stops; the card when the
# pointer rests on a train. With the shuttle over the rails (z 4; it never shares track with them); the
# floor lifts under the rails (z 1); a crate rolling off a wagon under the arm parked over the hatch (z 2)
# until it is half across.
const FW = preload("res://scripts/freight_works.gd")
const W = preload("res://scripts/hub_works.gd")
const HubArt = preload("res://scripts/hub_art.gd")
const MeshPen = preload("res://scripts/mesh_pen.gd")
const TramArt = preload("res://scripts/tram_art.gd")
const Art = preload("res://scripts/freight_art.gd")
const FastDraw = preload("res://scripts/fast_draw.gd")

var game
var art
var card
var still: Node2D
var low: Node2D
var _meshes := {}
var t := 0.0
var draw_us := 0.0           # tests: the drawing a frame (µs, smoothed)
var tick_us := 0.0
var roll_dir := {}            # tests: per wagon, the way its lit roller steps (+1 / −1 local y, 0 still)
var tick_max := 0.0          # tests: the slowest step seen (µs)
var tick_n := 0              # tests: steps run, and how many took over 2 ms and over 4 ms
var tick_over2 := 0
var tick_over4 := 0


func _ready() -> void:
	z_index = 4
	z_as_relative = false
	# 火车看不见 (2026-11-10): the trains are meshes; the engine's own bounds for them missed the screen when
	# the camera was close in on the hub, and the whole layer was culled — no train drawn at all (seen from
	# far out it was). Its bounds are the whole port: what is off the screen is skipped in _draw itself
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6))
	FW.reset()
	FW.on = true
	W.trains_feed = true
	FW.tram = game.tram if game != null else null
	Tram.avoid = FW.avoid_cost
	Tram.wait_est = FW.est_wait
	if FW.tram != null:
		FW.passenger_arrived(FW.tram)
	art = HubArt.new()
	art.font = Fonts.get_font("Medium")
	art.c = Vector2.ZERO
	art.m = Geom.M
	still = Node2D.new()
	still.z_index = 1
	still.z_as_relative = false
	still.draw.connect(_draw_still)
	add_child(still)
	low = Node2D.new()
	low.z_index = 2
	low.z_as_relative = false
	low.draw.connect(_draw_low)
	add_child(low)
	card = preload("res://scripts/facility_card.gd").new()
	card.game = game
	card.items = _items
	add_child(card)


func _exit_tree() -> void:
	FW.on = false
	W.trains_feed = false
	FW.tram = null
	Tram.avoid = Callable()
	Tram.wait_est = Callable()


func active() -> bool:
	return game != null and game.in_berth() and game.career() and not Career.data.is_empty()


func _physics_process(dt: float) -> void:
	if not active():
		return
	var t0 := Time.get_ticks_usec()
	FW.tick(dt)
	var us := float(Time.get_ticks_usec() - t0)
	tick_us = lerpf(tick_us, us, 0.05)
	tick_max = maxf(tick_max, us)
	tick_n += 1
	if us > 2000.0:
		tick_over2 += 1
	if us > 4000.0:
		tick_over4 += 1


func _process(dt: float) -> void:
	t += dt
	visible = active()
	if visible:
		queue_redraw()
		low.queue_redraw()


# ------------------------------------------------------------------ meshes (metres, car along +x)
func _mesh(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var pen := MeshPen.new()
		build.call(pen)
		_meshes[key] = pen.mesh()
	return _meshes[key]


func _plate(p, at: Vector2, d: Vector2) -> void:
	var n := d.orthogonal()
	var hx := 2.0
	var hy := 1.6
	var q := PackedVector2Array([at - d * hx - n * hy, at + d * hx - n * hy, at + d * hx + n * hy, at - d * hx + n * hy])
	p.poly(q, Color(0.03, 0.032, 0.037))
	q.append(q[0])
	p.polyline(q, Pal.heat(0.4, 0.9), 0.1)
	var inner := PackedVector2Array([at - d * (hx - 0.3) - n * (hy - 0.3), at + d * (hx - 0.3) - n * (hy - 0.3), at + d * (hx - 0.3) + n * (hy - 0.3), at - d * (hx - 0.3) + n * (hy - 0.3), at - d * (hx - 0.3) - n * (hy - 0.3)])
	p.polyline(inner, Pal.ink(0.2), 0.04)


# the floor lifts at each district's freight stop, under where its two wagons stand (world metres)
func _draw_still() -> void:
	if not active():
		return
	var mesh := _mesh("plates", func(p):
		for z in FW.ZONES:
			var st := FW._dstop(z)
			var line: Array = st.line
			for off: float in [4.35, 8.7]:
				var r := TramArt.at_len(line, off * Geom.M)
				_plate(p, (r[0] as Vector2) / Geom.M, (r[1] as Vector2).normalized())
		# the buffer stop at the end of each district's freight line (and the berth's siding): a striped
		# beam on two struts
		for z in FW.EXT_ZONES + ["salvage"]:
			var b: Vector2 = (FW.ext_end(z) if z != "salvage" else FW.siding_pts()[-1]) / Geom.M
			var d: Vector2 = -Tram.station_dir(z) if z != "salvage" else Vector2.from_angle(float(W.spokes().get("salvage", PI * 0.5)))
			var n := d.orthogonal()
			p.line(b - n * 1.0, b + n * 1.0, TramArt.DARK, 0.34)
			for j in 6:
				var x0 := -0.9 + j * 0.3
				p.line(b + n * x0, b + n * (x0 + 0.15), Pal.heat(0.85, 0.9), 0.3)
			for sd: float in [-1.0, 1.0]:
				p.line(b + n * sd * 0.55, b - d * 0.9 + n * sd * 0.55, Pal.ink(0.32), 0.1)
			p.circle(b + d * 0.25, 0.12, Pal.heat(0.9, 1.3), 8))
	still.draw_mesh(mesh, null, Transform2D(0.0, Vector2(Geom.M, Geom.M), 0.0, Vector2.ZERO), Color.WHITE)


# ------------------------------------------------------------------ the trains (as scripts/tram.gd draws the shuttle)
const K_LAT := 0.025           # m of lean a m/s² sideways, m of pitch a m/s² along (the shuttle's springs)
const K_LONG := 0.008
const SPRING_W := 9.0
const SPRING_Z := 0.45
var _spring := {}              # train id -> {th: [], lean: [], lv: []} per car


# each car from the head: [centre px, angle, kind, wagon index or -1, [[bogie px, bogie angle] × 2]]
func poses(tr: Dictionary) -> Array:
	var out: Array = []
	var o := FW.order(tr)
	var of := FW.offs(tr)
	var M := Geom.M
	for k in 3:
		var ci := int(o[k])
		var kind := "loco" if ci == 0 else "wagon"
		var s := -float(of[k])
		var bg := float(Art.BOGIE[kind])
		var b0 := FW.along(tr, (s + bg) * M)
		var b1 := FW.along(tr, (s - bg) * M)
		var ax := b0 - b1
		var ang: float = ax.angle() if ax.length() > 0.01 else float(tr.heading)
		var bogs: Array = []
		for bs: float in [s + bg, s - bg]:
			var tg := FW.along(tr, (bs + 0.3) * M) - FW.along(tr, (bs - 0.3) * M)
			bogs.append([FW.along(tr, bs * M), tg.angle() if tg.length() > 0.01 else ang])
		out.append([(b0 + b1) * 0.5, ang, kind, ci - 1, bogs])
	return out


# the bodies on their springs: leaning out of a curve, pitching as it pulls and brakes
func _springs(tr: Dictionary, ps: Array, dt: float) -> Array:
	var id := int(tr.id)
	if not _spring.has(id):
		_spring[id] = {"th": [INF, INF, INF], "lean": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], "lv": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]}
	var sp: Dictionary = _spring[id]
	var M := Geom.M
	for k in 3:
		var th: float = ps[k][1]
		var dir := Vector2.from_angle(th)
		var w: float = 0.0 if float(sp.th[k]) == INF else angle_difference(float(sp.th[k]), th) / maxf(dt, 1e-4)
		sp.th[k] = th
		var a_lat := float(tr.speed) / M * w
		var a_long := float(tr.acc) / M
		var target := -(dir * a_long * K_LONG + dir.rotated(PI * 0.5) * a_lat * K_LAT)
		var lv: Vector2 = sp.lv[k]
		lv += ((target - (sp.lean[k] as Vector2)) * SPRING_W * SPRING_W - lv * 2.0 * SPRING_Z * SPRING_W) * dt
		sp.lv[k] = lv
		sp.lean[k] = ((sp.lean[k] as Vector2) + lv * dt).limit_length(0.16)
	return sp.lean


func _draw() -> void:
	if not active() or FW.trains.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var M := Geom.M
	var sc := Vector2(M, M)
	var dt := maxf(get_process_delta_time(), 1.0 / 240.0)
	var view: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(8.0 * M)
	var c := Backdrop.port_centre_px()
	var sells: Array = []
	var rs := _recycle_frame()
	var rs_seen: bool = not rs.is_empty() and view.has_point(rs.o)
	if rs_seen:
		_recycle_ground(rs)
	for tr in FW.trains:
		if not view.has_point(tr.pos) and not view.has_point(FW.behind(tr, 8.7 * M)):
			continue
		var ps := poses(tr)
		var lean := _springs(tr, ps, dt)
		var lock := float(tr.lock)
		var braking: bool = float(tr.acc) < -0.4 * M and float(tr.speed) > 0.2 * M
		# shadows, then the bodies' sides on the bogies (they show where the body has swung)
		for k in 3:
			draw_mesh(Art.shadow_mesh(ps[k][2]), null, Transform2D(ps[k][1], sc, 0.0, ps[k][0] + ((lean[k] as Vector2) + Vector2(0.18, 0.28)) * M))
		for k in 3:
			draw_mesh(Art.side_mesh(ps[k][2]), null, Transform2D(ps[k][1], sc, 0.0, ps[k][0]))
		# the couplers between the cars' ends
		var of := FW.offs(tr)
		var o := FW.order(tr)
		for k in 2:
			var la: float = Art.LOCO_L if int(o[k]) == 0 else Art.WAGON_L
			var sj := -(float(of[k]) + la * 0.5 + 0.25)
			var jp := FW.along(tr, sj * M)
			var jt := FW.along(tr, (sj + 0.4) * M) - FW.along(tr, (sj - 0.4) * M)
			draw_mesh(Art.coupler_mesh(), null, Transform2D(jt.angle(), sc, 0.0, jp))
		var pu: Dictionary = tr.get("pushing", {})
		for k in 3:
			var at: Vector2 = (ps[k][0] as Vector2) + (lean[k] as Vector2) * M
			var xf := Transform2D(ps[k][1], sc, 0.0, at)
			var v := Vector2.from_angle(ps[k][1]).orthogonal()
			if str(ps[k][2]) == "loco":
				# its cab faces the way it leads; pushing, it faces back along the train
				var lx := xf if bool(tr.lf) else Transform2D(float(ps[k][1]) + PI, sc, 0.0, at)
				draw_mesh(Art.loco_mesh(), null, lx)
				# the roof's marker lamps: amber blinking while it moves, green locked
				var ml: Color = Pal.tint(Pal.FLUID, 0.9, 1.4) if lock >= 0.999 else (Pal.heat(1.0, 1.5) if fmod(FW.t * 2.0, 1.0) < 0.6 else Pal.heat(0.4, 1.0))
				for mp: Vector2 in [Vector2(0.75, -0.95), Vector2(0.75, 0.95), Vector2(-1.55, -0.95), Vector2(-1.55, 0.95)]:
					FastDraw.circle(self, lx * mp, 0.07 * M, ml)
				continue
			var wi: int = ps[k][3]
			draw_mesh(Art.wagon_mesh(), null, xf)
			# the rollers, their highlight stepping across while a crate moves on them
			var rolling: bool = not pu.is_empty() and int(pu.wi) == wi
			# 传送带方向 (user 2026-11-10): the lit roller steps the way the crate rolls — toward the hatch
			# pushing in, toward the wagon's middle taking one off (it always stepped toward −y before)
			var roll_s := 0
			if rolling:
				var inw := 1.0 if v.dot(c - (ps[k][0] as Vector2)) > 0.0 else -1.0
				roll_s = int(inw) if str(W.pushing(str(pu.z)).get("dir", "")) == "in" else -int(inw)
			roll_dir[Vector2i(int(tr.id), wi)] = roll_s
			for i in 8:
				var y := -1.05 + i * 0.3
				var rm := Color(1.35, 1.35, 1.35) if rolling and posmod(i - roll_s * int(FW.t * 14.0), 3) == 0 else Color.WHITE
				draw_mesh(Art.roller_mesh(), null, Transform2D(ps[k][1], sc, 0.0, xf * Vector2(0.0, y)), rm)
			# the hatch is on the loop's inside: the far plate follows a crate across towards it
			var inward := 1.0 if v.dot(c - (ps[k][0] as Vector2)) > 0.0 else -1.0
			var pa: Array = FW.push_at(tr) if rolling else []
			var pushing_in: bool = not pa.is_empty() and str(W.pushing(str(pu.z)).get("dir", "")) == "in"
			for sd: float in [-1.0, 1.0]:
				var py := sd * 1.3
				if pushing_in and sd == -inward:
					py = lerpf(sd * 1.3, inward * 0.6, clampf(1.0 - float(pa[2]), 0.0, 1.0))
				draw_mesh(Art.plate_mesh(), null, Transform2D(float(ps[k][1]) + (PI if sd < 0.0 else 0.0), sc, 0.0, xf * Vector2(0.0, py)))
			# the twistlocks at the corners: their levers swing in as it locks
			for cx: float in [-1.0, 1.0]:
				for cy: float in [-1.0, 1.0]:
					var open_a := 0.0 if cx > 0.0 else PI
					var shut_a := atan2(-cy, -cx)
					draw_mesh(Art.lock_mesh(), null, Transform2D(float(ps[k][1]) + lerp_angle(open_a, shut_a, lock), sc, 0.0, xf * Vector2(cx * 1.72, cy * 1.27)))
			var cg = tr.wag[wi]
			if cg != null and str((tr.anim[wi] as Dictionary).get("dir", "")) == "sell":
				sells.append([at, float(tr.anim[wi].t), cg, float(ps[k][1])])
				cg = null
			if cg != null:
				var an: Dictionary = tr.anim[wi]
				var e := 1.0
				if not an.is_empty():
					e = float(an.t) if str(an.dir) == "up" else 1.0 - float(an.t)
					e = e * e * (3.0 - 2.0 * e)
				var sh := lerpf(0.35, 1.0, e)
				art.goods_at(self, cg, at / M, ps[k][1], Color(sh, sh, sh), lerpf(0.72, 0.98, e))
			# the lock lamps on the sills
			var lc: Color = Pal.tint(Pal.FLUID, 0.9, 1.3) if lock >= 0.999 else Pal.heat(0.85, 1.2)
			FastDraw.circle(self, xf * Vector2(1.75, 1.42), 0.07 * M, lc)
			FastDraw.circle(self, xf * Vector2(-1.75, -1.42), 0.07 * M, lc)
		# the bogies through the bodies as hidden lines (the shuttle's own), the brake shoes on while it brakes
		for k in 3:
			for bq in ps[k][4]:
				draw_mesh(TramArt.bogie_mesh(str(ps[k][2]) == "loco"), null, Transform2D(float(bq[1]), sc, 0.0, bq[0]), Color(1, 1, 1, 0.13))
				if braking or lock >= 0.999:
					var bu := Vector2.from_angle(float(bq[1]))
					var bn := bu.orthogonal()
					for wx: float in [-0.36, 0.36]:
						for wy: float in [-0.55, 0.55]:
							var q: Vector2 = (bq[0] as Vector2) + (bu * (wx + signf(wx) * 0.2) + bn * wy) * M
							draw_line(q - bn * 0.08 * M, q + bn * 0.08 * M, Pal.heat(0.85, 1.3) if braking else Pal.ink(0.5), 0.05 * M)
		# the lights: headlamps and their beam at the leading end, tail lamps at the far end
		var hd := Vector2.from_angle(float(ps[0][1]))
		var hl: float = (Art.LOCO_L if str(ps[0][2]) == "loco" else Art.WAGON_L) * 0.5
		var nose: Vector2 = (ps[0][0] as Vector2) + (lean[0] as Vector2) * M + hd * hl * M
		var tl: float = (Art.LOCO_L if str(ps[2][2]) == "loco" else Art.WAGON_L) * 0.5
		var td := Vector2.from_angle(float(ps[2][1]))
		var tail: Vector2 = (ps[2][0] as Vector2) + (lean[2] as Vector2) * M - td * tl * M
		for sy: float in [-0.75, 0.75]:
			FastDraw.circle(self, nose + hd.orthogonal() * sy * M, 0.1 * M, Pal.ink(0.95, 1.7 if tr.moving else 1.1))
			FastDraw.circle(self, tail + td.orthogonal() * sy * M, 0.09 * M, Pal.heat(0.95, 1.6))
		if tr.moving:
			var v2 := float(tr.speed) / (FW.V_MAX * M)
			var cone := Color(0.75, 0.9, 1.0, 0.08 + 0.06 * v2)
			draw_primitive(PackedVector2Array([nose, nose + hd * 9.0 * M + hd.orthogonal() * 2.6 * M, nose + hd * 9.0 * M - hd.orthogonal() * 2.6 * M]), PackedColorArray([cone, Color(cone, 0.0), Color(cone, 0.0)]), PackedVector2Array())
		_push_crate(self, tr, FW.cars(tr), true)
	if rs_seen:
		_recycle_crane(rs, sells)
	if FW.show_blocks:
		_draw_blocks()
	draw_us = lerpf(draw_us, float(Time.get_ticks_usec() - t0), 0.05)


# 130 号 (user): the trade port's recycling station, by its freight stop. A sale comes by train
# (scripts/freight_works.gd sell); a crane lifts the crate off the wagon, carries it across over the
# chute beside the track and lowers it in. Parked at the runway's far end otherwise. Top-down line art
# like the shuttle's; height shown by the crate's size and its shadow.
# 接驳站穿模修复 (user: “贸易港这很多铁轨……属于穿模”): its two runway rails ran 6 m down across the hall
# floor and the dock, its bridge over the business console's column, its chute down in the dock. Now it
# all stays in the line's own bay, between the counters (10 m) and the hall floor (15.8 m): one runway
# girder along the bay's upper edge, a jib from its end truck out over the wagon, the chute between the
# girder and the track; the jib telescopes out over the wagon only while it lifts a crate. Across: m from
# the track's middle, up positive.
const RS_X := Vector2(1.9, 12.5)     # m along the line from the stop's head (towards the ring): the runway (0.4 m short of counter 1)
const RS_RUN := 3.6                  # m up: the runway girder (the counters' desks end 4.0 m up)
const RS_TIP := -0.55                # m: the jib's tip run out, just past the wagon's middle
const RS_IN := 2.6                   # m: run in (parked, or between sales), over the chute, clear of the track
const RS_CHUTE := Rect2(3.0, 1.95, 5.0, 1.3)   # along, across (up): 0.45 m clear of a wagon's side, 0.2 m of the girder
const RS_PARK := 11.6


static func _rs_axes() -> Array:
	var st := FW._dstop("trade")
	var line: Array = st.line
	var o: Vector2 = line[0]
	var u: Vector2 = ((line[1] as Vector2) - o).normalized()
	var n := u.orthogonal()
	if n.y > 0.0:
		n = -n
	return [o, u, n]


func _recycle_frame() -> Dictionary:
	if not FW._open("trade"):
		return {}
	var ax := _rs_axes()
	return {"o": ax[0], "u": ax[1], "n": ax[2]}


func _rs(rs: Dictionary, x: float, y: float) -> Vector2:
	return (rs.o as Vector2) + ((rs.u as Vector2) * x + (rs.n as Vector2) * y) * Geom.M


# the station's still parts and the jib's reach, world px rects (tests/tram_clear_check.gd)
static func recycle_rects() -> Array:
	if not FW._open("trade"):
		return []
	var ax := _rs_axes()
	var o: Vector2 = ax[0]
	var u: Vector2 = ax[1]
	var n: Vector2 = ax[2]
	var M := Geom.M
	var f := func(x: float, y: float) -> Vector2: return o + (u * x + n * y) * M
	var out: Array = []
	out.append(Rect2(f.call(RS_X.x - 0.3, RS_RUN + 0.35), Vector2.ZERO).expand(f.call(RS_X.y + 0.3, RS_RUN - 0.35)))
	out.append(Rect2(f.call(RS_CHUTE.position.x, RS_CHUTE.position.y), Vector2.ZERO).expand(f.call(RS_CHUTE.end.x, RS_CHUTE.end.y)))
	out.append(Rect2(f.call(RS_X.x - 0.75, RS_RUN), Vector2.ZERO).expand(f.call(RS_X.y + 0.75, RS_TIP - 0.1)))
	return out


func _recycle_ground(rs: Dictionary) -> void:
	var M := Geom.M
	# the chute: a dark pit with a lit rim, its grate, a lip on the track's side
	var ch := RS_CHUTE
	var q := PackedVector2Array([_rs(rs, ch.position.x, ch.position.y), _rs(rs, ch.end.x, ch.position.y), _rs(rs, ch.end.x, ch.end.y), _rs(rs, ch.position.x, ch.end.y)])
	draw_colored_polygon(q, Color(0.02, 0.022, 0.026))
	var ring := q.duplicate()
	ring.append(q[0])
	draw_polyline(ring, Pal.heat(0.55, 0.9), 0.09 * M)
	for k in 9:
		var gx := ch.position.x + 0.4 + k * (ch.size.x - 0.8) / 8.0
		draw_line(_rs(rs, gx, ch.position.y + 0.2), _rs(rs, gx, ch.end.y - 0.2), Pal.ink(0.14), 0.04 * M)
	draw_line(_rs(rs, ch.position.x, ch.position.y - 0.12), _rs(rs, ch.end.x, ch.position.y - 0.12), Pal.ink(0.4), 0.06 * M)
	# the runway: one girder along the bay's edge, the hangers it hangs on, its end stops
	draw_line(_rs(rs, RS_X.x, RS_RUN), _rs(rs, RS_X.y, RS_RUN), Color(0.09, 0.095, 0.105), 0.3 * M)
	draw_line(_rs(rs, RS_X.x, RS_RUN + 0.15), _rs(rs, RS_X.y, RS_RUN + 0.15), Pal.ink(0.5), 0.05 * M)
	draw_line(_rs(rs, RS_X.x, RS_RUN - 0.15), _rs(rs, RS_X.y, RS_RUN - 0.15), Pal.ink(0.36), 0.04 * M)
	for k in 6:
		var px := RS_X.x + 0.4 + k * (RS_X.y - RS_X.x - 0.8) / 5.0
		draw_rect(Rect2(_rs(rs, px, RS_RUN) - Vector2(0.12, 0.12) * M, Vector2(0.24, 0.24) * M), Pal.ink(0.3))
	for x: float in [RS_X.x, RS_X.y]:
		draw_line(_rs(rs, x, RS_RUN - 0.3), _rs(rs, x, RS_RUN + 0.3), Pal.heat(0.7, 1.0), 0.12 * M)


func _recycle_crane(rs: Dictionary, sells: Array) -> void:
	var M := Geom.M
	var e := func(a: float, b: float, x: float) -> float:
		var q := clampf((x - a) / (b - a), 0.0, 1.0)
		return q * q * (3.0 - 2.0 * q)
	var bx := RS_PARK
	var cy := RS_CHUTE.get_center().y
	var ty := cy
	var hook := 0.0
	var reach := 0.0
	var crate: Array = []
	if not sells.is_empty():
		var sl: Array = sells[0]
		var ts := float(sl[1])
		# the jib runs out over the wagon first and back in last (parked, it is in over the chute)
		reach = float(e.call(0.0, 0.15, ts)) * (1.0 - float(e.call(0.9, 1.0, ts)))
		var wx: float = ((sl[0] as Vector2) - (rs.o as Vector2)).dot(rs.u) / M
		# out over the wagon, hook down, lift, across over the chute, down into it, back to park
		bx = lerpf(RS_PARK, wx, e.call(0.0, 0.2, ts))
		bx = lerpf(bx, RS_PARK, e.call(0.9, 1.0, ts))
		ty = lerpf(cy, 0.0, e.call(0.0, 0.2, ts))
		ty = lerpf(ty, cy, e.call(0.5, 0.75, ts))
		hook = float(e.call(0.2, 0.35, ts)) * (1.0 - float(e.call(0.85, 0.95, ts)))
		var lift: float = float(e.call(0.35, 0.5, ts)) * (1.0 - float(e.call(0.75, 0.9, ts)))
		var sunk: float = e.call(0.75, 0.9, ts)
		if ts < 0.9:
			var at: Vector2 = _rs(rs, bx, ty) if ts >= 0.35 else (sl[0] as Vector2)
			crate = [sl[2], at, float(sl[3]), lift, sunk]
	# the crate on the hook: its shadow on the deck, itself bigger the higher it is, smaller as it goes in
	if not crate.is_empty():
		var lift: float = crate[3]
		var sunk: float = crate[4]
		var sh := Color(0, 0, 0, 0.35 * lift)
		draw_circle((crate[1] as Vector2) + Vector2(0.3, 0.4) * M * lift, 1.1 * M, sh)
		var k: float = lerpf(0.98, 1.1, lift) * lerpf(1.0, 0.7, sunk)
		var v: float = lerpf(1.0, 0.25, sunk)
		art.goods_at(self, crate[0], (crate[1] as Vector2) / M, crate[2], Color(v, v, v, 1.0 - 0.8 * sunk), k)
	# the end truck on the runway, the telescopic jib out from it (its sleeve, the inner section's two
	# chords and their lacing), the trolley on it, the hook below
	var side: Vector2 = (rs.u as Vector2) * 0.22 * M
	var nn: Vector2 = (rs.n as Vector2) * 0.28 * M
	var a := _rs(rs, bx, RS_RUN)
	var tip := lerpf(RS_IN, RS_TIP, reach)
	var b := _rs(rs, bx, tip)
	var tq := PackedVector2Array([a - side * 3.2 - nn, a + side * 3.2 - nn, a + side * 3.2 + nn, a - side * 3.2 + nn])
	draw_colored_polygon(tq, Color(0.05, 0.055, 0.06))
	tq.append(tq[0])
	draw_polyline(tq, Pal.ink(0.6), 0.04 * M)
	var sl0 := _rs(rs, bx, RS_IN)
	var sq := PackedVector2Array([a - side * 1.5, a + side * 1.5, sl0 + side * 1.5, sl0 - side * 1.5])
	draw_colored_polygon(sq, Color(0.075, 0.08, 0.088))
	sq.append(sq[0])
	draw_polyline(sq, Pal.ink(0.55), 0.04 * M)
	draw_line(a - side, b - side, Pal.ink(0.75), 0.07 * M)
	draw_line(a + side, b + side, Pal.ink(0.75), 0.07 * M)
	var lac := PackedVector2Array()
	var yy := RS_IN
	var flip := 1.0
	while yy - 0.5 > tip:
		lac.append_array([_rs(rs, bx, yy) - side * flip, _rs(rs, bx, yy - 0.5) + side * flip])
		yy -= 0.5
		flip = -flip
	if not lac.is_empty():
		draw_multiline(lac, Pal.ink(0.4), 0.03 * M)
	draw_line(b - side * 1.3, b + side * 1.3, Pal.ink(0.75), 0.08 * M)
	var tp := _rs(rs, bx, ty)
	var tw: Vector2 = (rs.u as Vector2) * 0.6 * M
	var tn: Vector2 = (rs.n as Vector2) * 0.42 * M
	var tr := PackedVector2Array([tp - tw - tn, tp + tw - tn, tp + tw + tn, tp - tw + tn])
	draw_colored_polygon(tr, Color(0.06, 0.065, 0.07))
	tr.append(tr[0])
	draw_polyline(tr, Pal.heat(0.8, 1.1), 0.05 * M)
	FastDraw.circle(self, tp, (0.16 + 0.1 * hook) * M, Pal.ink(0.5 + 0.4 * hook))
	# the warning lamp on the end truck blinks while it works
	if not sells.is_empty() and fmod(t, 0.5) < 0.25:
		FastDraw.circle(self, a, 0.16 * M, Pal.heat(1.0, 1.6))


# developer view (FW.show_blocks): each train's held track in its own colour, the shuttle's wanted
# track in white, a red bar where a train stands at a signal
const BLOCK_COL := [Color(1.0, 0.55, 0.15), Color(0.3, 0.85, 1.0), Color(0.6, 1.0, 0.4)]
func _draw_blocks() -> void:
	var M := Geom.M
	var cs := FW.CELL * M
	for k in FW.pending:
		draw_rect(Rect2(Vector2(k) * cs, Vector2(cs, cs)), Color(1, 1, 1, 0.18))
	for k in FW.claims:
		var o := int(FW.claims[k])
		var col: Color = Color(1, 1, 1, 0.45) if o < 0 else BLOCK_COL[o % BLOCK_COL.size()]
		draw_rect(Rect2(Vector2(k) * cs, Vector2(cs, cs)), Color(col, 0.35))
	for tr in FW.trains:
		var col: Color = BLOCK_COL[int(tr.id) % BLOCK_COL.size()]
		var held := float(tr.get("blocked_t", 0.0)) > 0.0
		FastDraw.circle(self, tr.pos, 0.6 * M, Color(1, 0.15, 0.1, 0.9) if held else col)
		var txt := "#%d %s" % [int(tr.id), ("%.0fm" % float(tr.auth_left)) if float(tr.get("auth_left", INF)) < INF else "∞"]
		if held:
			txt += " 停 %.1fs" % float(tr.blocked_t)
		draw_string(ThemeDB.fallback_font, tr.pos + Vector2(0.8, -0.8) * M, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.9 * M), col)


# the crate the rollers are moving between the wagon and the hatch: over the rails near the wagon, under
# the arm near the hatch
func _push_crate(ci: CanvasItem, tr: Dictionary, cs: Array, high: bool) -> void:
	var pa := FW.push_at(tr)
	if pa.is_empty():
		return
	var e2: float = pa[2]
	if (e2 > 0.5) != high:
		return
	var pos: Vector2 = (pa[0] as Vector2).lerp(pa[1], e2)
	var sh2 := lerpf(0.35, 1.0, e2)
	art.goods_at(ci, pa[3], pos / Geom.M, float(cs[order_k(tr, int(tr.pushing.wi))][1]), Color(sh2, sh2, sh2), lerpf(0.705, 0.98, e2))


func _draw_low() -> void:
	if not active():
		return
	for tr in FW.trains:
		if not (tr.get("pushing", {}) as Dictionary).is_empty():
			_push_crate(low, tr, FW.cars(tr), false)


func order_k(tr: Dictionary, wi: int) -> int:
	return FW.order(tr).find(wi + 1)


# ------------------------------------------------------------------ the card
func _items() -> Array:
	if not active():
		return []
	var out: Array = []
	var M := Geom.M
	for tr in FW.trains:
		var say := FW.says(tr)
		var goods: Array = say.goods
		var now := str(say.status)
		if not goods.is_empty():
			now += "\n" + FW.w("拉着：", "CARRYING: ") + "、".join(PackedStringArray(goods))
		else:
			now += "\n" + FW.w("空车", "EMPTY")
		if str(say.route) != "":
			now += "\n" + str(say.route)
		var item := {"title": FW.w("货运列车 %d", "FREIGHT TRAIN %d") % (int(tr.id) + 1),
			"use": FW.w("机车加两节滚道平板车：在各区走廊里装卸，到中央环停在舱口旁，车厢滚道把货箱推进舱口，机械臂送上转盘；反过来把舱口降下的货接上车。", "A locomotive and two roller-bed wagons: they load in the districts' corridors, stand by the ring's hatches and roll crates onto the lifts for the arms, and take the ones handed down."),
			"now": now,
			"can": FW.w("自动调度，载人接驳车优先；拉的是仓库里真实的入库、出售和炼钢的货。", "Runs itself, the shuttle first; it carries what really moves in the warehouse."),
			"lamp": "work" if tr.moving or not (tr.step as Dictionary).is_empty() else "ok"}
		for c in FW.cars(tr):
			var r := Rect2(c[0], Vector2.ZERO).grow(2.0 * M)
			var it := item.duplicate()
			it.rect = r
			out.append(it)
	return out
