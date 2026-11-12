extends Node2D
# 2026-11-11 (user: "按右键就是自己伸出一个管子，能把已经漏出来的液体给吸走"): the hose tool's right button.
# The left button is the hose on a port, as ever (tools.gd / game.do_hose). Held (past a short click,
# which keeps its old work: let go of a load, stop a job, mark), the drone puts out its own suction
# tube toward the pointer, MAX_LEN at most, stopping at the first wall; at its nozzle what is adrift
# (scripts/liquids.gd's globules: a leak's, a burst tank's, a careless take's spill from
# scripts/mishap.gd) is drawn in and drunk. What it drinks is the ship's liquid recovered: by the
# globule's look, the ship's fluid of that look (Systems.fluid_rec, the way the hose on a port books
# it; off Systems.fluid_lost, where the spill was written); a liquid the ship does not price is only
# cleaned up. A ball frozen to ice does not go up a tube. Let go, the tube goes back in.
# Drawn: the tube (a slack line that sways with the drone), its nozzle, the suction drawing in round
# it, the liquid's own colour running up the tube in slugs, drops streaming off the globule into the
# nozzle. Sounds: hooks "slurp_start" / "slurp_flow" / "slurp_stop" (silent until recordings are
# added to sfx.gd), the existing hose cues meanwhile — no synthesis.
# It only reads and changes liquids.gd's globules (their vol, vel, and taking a drunk one out of its
# list): nothing of how they leak, spill or burn. A child of tools.gd; tests read `stats`.

const LiqColors = preload("res://scripts/liquid_colors.gd")
const LIQ = preload("res://scripts/liquids.gd")

const HOLD_T := 0.15            # s the right button is held before the tube comes out (a click stays a click)
const MAX_LEN := 4.5 * 48.0     # px: the tube's reach
const OUT_V := 7.0 * 48.0       # px/s it runs out
const IN_V := 11.0 * 48.0       # px/s it goes back in
const NOZ := 0.45 * 48.0        # px: a globule this close to the nozzle (beyond its own radius) is drunk
const PULL_R := 2.0 * 48.0      # px: within this the suction draws globules in
const PULL_A := 3.2 * 48.0      # px/s² of that draw at the nozzle, to nothing at PULL_R
const RATE0 := 0.025            # m³/s the nozzle drinks at least
const RATE_K := 0.6             # and this much more per m³ of the globule (a big ball goes faster)
const RATE_MAX := 0.12          # m³/s at most
const SLUG_DT := 0.045          # s between slugs of liquid running up the tube
const SLUG_V := 3.6 * 48.0      # px/s they run

var tools
var t := 0.0
var held_t := 0.0               # s the right button has been held
var engaged := false            # this press is the tube's (the click on letting go is not a click)
var len_now := 0.0              # px the tube is out
var dir := Vector2.RIGHT
var tip := Vector2.ZERO
var sway := 0.0
var drinking := ""              # the look being drunk this step ("" none)
var _slug_t := 0.0
var slugs: Array = []           # [s 0..1 from the nozzle, colour]
var streams: Array = []         # [from, to, colour] of the globules being drunk this step
var _flow_snd := 0.0
var _hinted := false
var _ice_said := -9.0
var took := 0.0                 # m³ drunk since the tube came out (said on letting go)
var stats := {"drunk": 0.0, "booked": 0.0, "unpriced": 0.0, "blobs_gone": 0, "out": false, "len": 0.0, "slugs": 0, "by_look": {}}


func _init() -> void:
	z_index = 9
	z_as_relative = false


func game():
	return tools.game if tools != null else null


# the right button, this step: the bot's "rmb", else the real one pressed in the world
func _rmb(g) -> bool:
	if g.bot != null and g.bot.has("rmb"):
		return bool(g.bot.rmb)
	return g.rmb_down and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _ready_to_use(g) -> bool:
	return g.state == "play" and tools.tool == 5 and g.drone != null and is_instance_valid(g.drone) and g.drone.alive \
		and not g.menu_open and not g.contract_open and g.console_ui == null and not g.in_vehicle()


# the press was the tube's: game.gd does not take its letting go for a click
func took_press() -> bool:
	return engaged


func _physics_process(dt: float) -> void:
	var g = game()
	if g == null or g.world == null:
		return
	t += dt
	var ok := _ready_to_use(g)
	var down := ok and _rmb(g)
	held_t = held_t + dt if down else 0.0
	var was := engaged
	if down and held_t >= HOLD_T:
		engaged = true
	elif not down:
		engaged = false
	var d = g.drone
	if engaged and not was:
		took = 0.0
		_snd(g, "slurp_start", "hose_on", d.global_position, 0.55, 1.35)
		_hint(g)
	if was and not engaged:
		if took > 0.0005:
			g.say("as_slurp_took", d.global_position + Vector2(0, -44), "%.0f" % (took * 1000.0))
		_snd(g, "slurp_stop", "unplug", d.global_position, 0.45, 1.25)
	drinking = ""
	streams.clear()
	if not ok and len_now <= 0.0:
		slugs.clear()
		stats.out = false
		stats.len = 0.0
		stats.slugs = 0
		if get_meta("drawn", false):
			set_meta("drawn", false)
			queue_redraw()
		return
	# out toward the pointer, stopping at a wall; back in when let go
	var from: Vector2 = d.global_position if d != null and is_instance_valid(d) else tip
	var want := 0.0
	if engaged:
		var to: Vector2 = tools.aim - from
		if to.length() > 1.0:
			dir = dir.slerp(to.normalized(), clampf(dt * 14.0, 0.0, 1.0)).normalized()
		want = minf(MAX_LEN, maxf(Drone.R + 12.0, to.length()))
		want = minf(want, _wall_at(g, from, dir, want))
	len_now = move_toward(len_now, want, (OUT_V if want > len_now else IN_V) * dt)
	sway = lerpf(sway, clampf(-(d.linear_velocity.dot(Vector2(-dir.y, dir.x))) / 240.0, -1.0, 1.0) if d != null else 0.0, clampf(dt * 4.0, 0.0, 1.0))
	tip = from + dir * maxf(len_now, Drone.R)
	stats.out = len_now > Drone.R + 4.0
	stats.len = len_now / Geom.M
	if engaged and len_now >= want - 2.0 and len_now > Drone.R + 8.0:
		_drink(g, dt)
	# the slugs run up the tube; new ones while it drinks
	for s in slugs:
		s[0] += SLUG_V * dt / maxf(len_now, 1.0)
	slugs = slugs.filter(func(s): return s[0] < 1.0)
	if drinking != "":
		_slug_t -= dt
		if _slug_t <= 0.0:
			_slug_t = SLUG_DT
			slugs.append([0.0, LiqColors.of(drinking, 0.9)])
		_flow_snd -= dt
		if _flow_snd <= 0.0:
			_flow_snd = 0.32
			_snd(g, "slurp_flow", "hose", tip, 0.22, 0.75 + randf() * 0.1)
	stats.slugs = slugs.size()
	queue_redraw()


# how far the tube gets before a wall (the attached ship, the berth's edges)
func _wall_at(g, from: Vector2, d: Vector2, want: float) -> float:
	var space = get_world_2d().direct_space_state if is_inside_tree() else null
	if space == null:
		return want
	var q := PhysicsRayQueryParameters2D.create(from + d * (Drone.R + 2.0), from + d * want, 8 | 4)
	q.exclude = [g.drone.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return want
	return maxf(Drone.R + 10.0, from.distance_to(hit.position) - 4.0)


func _drink(g, dt: float) -> void:
	var lq = g.liquids
	if lq == null or lq.blobs.is_empty():
		return
	var gone: Array = []
	var ice_near := false
	for b in lq.blobs:
		var r: float = LIQ.radius_m(float(b.vol)) * Geom.M
		var to: Vector2 = tip - b.pos
		var dd := to.length()
		if dd > PULL_R + r:
			continue
		if b.ice:
			ice_near = ice_near or dd < NOZ + r + 20.0
			continue
		# drawn in: harder the nearer, a stuck one let go of its wall
		if int(b.stuck) >= 0 and dd < NOZ + r + 30.0:
			b.stuck = -1
		var k := clampf(1.0 - (dd - r) / PULL_R, 0.0, 1.0)
		if dd > 1.0:
			b.vel = b.vel * (1.0 - clampf(dt * 3.0, 0.0, 1.0)) + to / dd * PULL_A * k * dt * 6.0
		if dd > NOZ + r:
			continue
		var rate := minf(RATE_MAX, RATE0 + RATE_K * float(b.vol))
		var v := minf(float(b.vol), rate * dt)
		b.vol = float(b.vol) - v
		_book(g, str(b.look), v)
		drinking = str(b.look)
		took += v
		streams.append([b.pos + to.normalized() * r * 0.8, tip, LiqColors.of(drinking, 0.85)])
		if float(b.vol) < 2e-5:
			gone.append(b)
	for b in gone:
		lq.blobs.erase(b)
		stats.blobs_gone += 1
	if ice_near and drinking == "" and t - _ice_said > 2.5:
		_ice_said = t
		g.say("as_slurp_ice", tip + Vector2(0, -30))


# what it drank, on the books: the ship's fluid of that look, recovered (never past what it had)
func _book(g, look: String, v: float) -> void:
	stats.drunk += v
	stats.by_look[look] = float(stats.by_look.get(look, 0.0)) + v
	var s = g.sys
	var fluid := ""
	var best := -1.0
	for k in s.fvol:
		var fv: Dictionary = s.fvol[k]
		if LIQ.look_of(fv) != look:
			continue
		var f: String = str(fv.get("fluid", ""))
		var f0: float = float(s.fluid0.get(f, 0.0))
		if f0 > best:
			best = f0
			fluid = f
	if fluid == "" or best <= 0.0:
		stats.unpriced += v
		return
	var room: float = maxf(0.0, best - float(s.fluid_rec.get(fluid, 0.0)))
	var add := minf(v, room)
	s.fluid_rec[fluid] = float(s.fluid_rec.get(fluid, 0.0)) + add
	s.fluid_lost = maxf(0.0, float(s.fluid_lost) - add)
	stats.booked += add
	if add < v:
		stats.unpriced += v - add


func _snd(g, hook: String, fallback: String, at: Vector2, vol: float, pitch: float) -> void:
	if g.sfx == null:
		return
	g.sfx.play(hook if g.sfx.streams.has(hook) else fallback, at, vol, pitch)


# once: what the right button does (【占位】 text in data/台词.txt)
func _hint(g) -> void:
	if _hinted or g.training or g.exam != null or Txt.hint_tier == "hardcore":
		return
	_hinted = true
	if g.career():
		if Career.data.get("hints_once", {}).has("as_slurp_hint"):
			return
		Career.hint_once("as_slurp_hint")
	g.say_text(g.txt("as_slurp_hint"), tip)


func _curve() -> PackedVector2Array:
	var d = tools.drone
	var from: Vector2 = d.global_position + dir * Drone.R * 0.8
	var to := tip
	var n := Vector2(-dir.y, dir.x)
	var L := from.distance_to(to)
	var sag := (0.10 * sway + 0.035 * sin(t * 3.1)) * L
	var mid := from.lerp(to, 0.5) + n * sag
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var u := float(i) / float(steps)
		pts.append(from.lerp(mid, u).lerp(mid.lerp(to, u), u))
	return pts


func _at(pts: PackedVector2Array, s: float) -> Vector2:
	# s: 0 at the nozzle, 1 at the drone
	var f := clampf(1.0 - s, 0.0, 1.0) * float(pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - float(i))


func _draw() -> void:
	var g = game()
	if g == null or tools.drone == null or not is_instance_valid(tools.drone) or len_now <= Drone.R + 4.0:
		return
	set_meta("drawn", true)
	var z: float = maxf(0.05, g.cam_zoom())
	var pts := _curve()
	# the tube: a dark core, a lit skin, rings along it
	draw_polyline(pts, Pal.ink(0.18), 5.0 / z, true)
	draw_polyline(pts, Pal.ink(0.75, 1.1), 3.2 / z, true)
	draw_polyline(pts, Color(0.05, 0.055, 0.065, 0.95), 1.8 / z, true)
	for i in range(2, pts.size() - 1, 3):
		var a: Vector2 = pts[i]
		var tg: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		var nn := Vector2(-tg.y, tg.x)
		draw_line(a - nn * 2.2 / z, a + nn * 2.2 / z, Pal.ink(0.55), 1.0 / z, true)
	# the liquid running up it
	for s in slugs:
		var p0 := _at(pts, s[0])
		var p1 := _at(pts, minf(1.0, s[0] + 0.05))
		draw_line(p0, p1, s[1], 1.8 / z, true)
	# the nozzle: a short flared mouth on the tube's end
	var tg2: Vector2 = (pts[pts.size() - 1] - pts[pts.size() - 3]).normalized()
	var nn2 := Vector2(-tg2.y, tg2.x)
	var m0 := tip - tg2 * 7.0 / z
	var mouth := PackedVector2Array([m0 + nn2 * 2.2 / z, tip + nn2 * 5.0 / z, tip - nn2 * 5.0 / z, m0 - nn2 * 2.2 / z])
	draw_colored_polygon(mouth, Color(0.06, 0.065, 0.075, 1.0))
	draw_polyline(PackedVector2Array([mouth[0], mouth[1], mouth[2], mouth[3]]), Pal.ink(0.85, 1.2), 1.2 / z, true)
	# the suction: rings drawn in toward the mouth while it is out
	if engaged:
		var live := 1.0 if drinking != "" else 0.45
		for k in 3:
			var ph := fmod(t * 1.8 + float(k) / 3.0, 1.0)
			var rad := (1.0 - ph) * PULL_R * 0.55 + 4.0 / z
			draw_arc(tip, rad, 0.0, TAU, 28, Pal.tint(Pal.AIR, 0.28 * ph * live, 1.1), 1.0 / z, true)
	# drops streaming off the globules into the mouth
	for st in streams:
		var a: Vector2 = st[0]
		var b: Vector2 = st[1]
		for k in 4:
			var ph := fmod(t * 3.2 + float(k) / 4.0, 1.0)
			draw_circle(a.lerp(b, ph), (2.2 - 1.2 * ph) / z, st[2])
