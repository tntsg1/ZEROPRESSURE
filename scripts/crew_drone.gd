extends Node2D
# A construction drone of the works crew (user 2026-10-28: "硬核的修复就是无人机真的修复那个位置，
# 把残骸拉走，而不是目前这种随意的动画"; Q: the crew's drones do it by themselves, every step as fine
# as it can be). It flies with inertia — thrust up to ACCEL, braking in time to stop where it is
# sent — and does its trade where it stops:
#   bot     tags the circuit out at its box      cutter  burns through a weld (beam and sparks)
#   hauler  carries a real body on a tether       torque  runs a bolt home (wrench and sparks)
#   cable   lays a cable from the box to the part tester  holds its probe on the work
# It does not collide (it flies round the work, it is not part of it); since 2026-11-10 what it
# carries does not either (FreeBody.hold_begin): the load is pulled by a spring and a damper toward
# a point under it, so it swings, but passes through what is in its way. Driven by scripts/crew.gd.

const CrewArt = preload("res://scripts/crew_art.gd")
static var prof_us := 0         # tests: µs spent (step + draw), with Crew.prof_us
const SPEED := 300.0
const ACCEL := 620.0
const R := 16.0
const ARM := 26.0               # px: one link of its tool arm (it works within ~45 px of where it stands)
const APART := 40.0             # px: two crew drones keep this far apart (the one at work does not yield)
const HANG := 30.0              # px under the drone where a load is held

var game
var role := "bot"
var vel := Vector2.ZERO
var goal := Vector2.INF
var heading := 0.0
var tool := false               # the beam, the wrench or the probe on
var tool_at := Vector2.ZERO
var load = null                 # the FreeBody on the tether
var load_pt := Vector2.ZERO     # where on it (its own frame)
var load_spin := 0.0            # the angle it is steadied to, when steady
var steady := false
var cable: PackedVector2Array = PackedVector2Array()   # the cable laid so far (world px)
var laying := false
var t := 0.0
var slow := 1.0                 # a share of its top speed (the last of a lowering, a fine approach)
var reel := 0.0                 # the winch or reel's turn, for the drawing
var work := 0.0                 # 0..1 how hard the tool works (eased in and out)
var _thrust := Vector2.ZERO
var _frame_n := 0


func _init() -> void:
	z_index = 7
	z_as_relative = false
	top_level = true


func go(p: Vector2) -> void:
	goal = p


func at(p: Vector2, tol: float = 6.0) -> bool:
	return global_position.distance_to(p) <= tol and vel.length() <= 24.0


func hook(b, local_pt: Vector2 = Vector2.INF) -> void:
	load = b
	# 2026-11-10 (user: "辅助无人机……抓取的那一瞬间就直接没有碰撞了"): on the hook it collides with nothing
	# (FreeBody.hold_begin); let go it touches again once clear (hold_end)
	b.hold_begin()
	load_pt = local_pt if local_pt != Vector2.INF else b.center_of_mass
	steady = false


func drop() -> void:
	_let_go()
	steady = false


func _let_go() -> void:
	if load != null and is_instance_valid(load) and load.held():
		load.hold_end()
	load = null


func hold_point() -> Vector2:
	return global_position + Vector2(0, HANG)


func _physics_process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_step_frame(dt)
	prof_us += Time.get_ticks_usec() - t0


func _step_frame(dt: float) -> void:
	if game != null and (game.paused_sim or game.state not in ["play", "build", "porttour"]):
		return
	t += dt
	var desired := Vector2.ZERO
	if goal != Vector2.INF:
		var off := goal - global_position
		# braking distance: never asked to go faster than it can stop
		var sp := minf(SPEED * slow, minf(off.length() * 3.5, sqrt(2.0 * ACCEL * 0.8 * maxf(off.length() - 1.0, 0.0))))
		desired = off.normalized() * sp if off.length() > 0.5 else Vector2.ZERO
		if off.length() > 6.0 and not tool:
			heading = lerp_angle(heading, off.angle(), 1.0 - exp(-6.0 * dt))
	# at work it faces what it works on
	if tool:
		heading = lerp_angle(heading, (tool_at - global_position).angle(), 1.0 - exp(-8.0 * dt))
	work = move_toward(work, 1.0 if tool else 0.0, dt * 5.0)
	# the others give way: a drone at its tool, or lowering a part, holds its place; the rest ease off
	# (2026-11-12: two of them sat one on the other at the box and the part)
	# (a drone at its goal holds its place — the cutter beside the rigger waiting over a weld — only one
	# on its way gives way, or two at work side by side would push each other off for ever)
	var en_route := goal != Vector2.INF and global_position.distance_to(goal) > 24.0
	if en_route and not tool and not (load != null and steady) and get_parent() != null:
		for o in get_parent().get_children():
			if o == self or o.get_script() != get_script():
				continue
			var away: Vector2 = global_position - o.global_position
			var dd := away.length()
			if dd < APART:
				desired += (away / maxf(dd, 0.5) if dd > 0.5 else Vector2.from_angle(float(get_instance_id() % 628) / 100.0)) * (APART - dd) * 6.0
	# a heavy load makes it slow to answer
	var heavy := 1.0
	if load != null and is_instance_valid(load):
		heavy = 1.0 + clampf(float(load.mass) / 2.0, 0.0, 2.5)
	_thrust = ((desired - vel) * 7.0).limit_length(ACCEL / heavy)
	vel += _thrust * dt
	global_position += vel * dt
	if laying:
		reel += dt * vel.length() / 40.0
		if cable.is_empty() or cable[cable.size() - 1].distance_to(global_position) > 10.0:
			cable.append(global_position)
	if load != null:
		reel += dt * vel.y / 60.0
	_carry(dt)
	# redrawn every frame while it moves or works; parked, every sixth (its lamp still blinks), and
	# not at all off the screen (2026-11-12: seven drones redrawn every frame cost 0.8 ms)
	_frame_n += 1
	var live := vel.length() > 3.0 or _thrust.length() > 8.0 or work > 0.0 or load != null or laying
	if (live or _frame_n % 6 == 0) and _on_screen():
		queue_redraw()


func _on_screen() -> bool:
	if game == null or game.cam == null:
		return true
	var z: float = maxf(0.05, game.cam_zoom())
	var view: Vector2 = get_viewport_rect().size / z
	return Rect2(game.cam.position - view * 0.5, view).grow(120.0).has_point(global_position)


# the tether: a spring and a damper between the hold point and the load's grip, its angle steadied
# when asked (lowering a part onto its seat)
func _carry(dt: float) -> void:
	if load == null:
		return
	if not is_instance_valid(load) or load.freeze:
		_let_go()
		return
	var grip: Vector2 = load.global_transform * load_pt
	var d: Vector2 = hold_point() - grip
	var m: float = maxf(0.05, load.mass)
	var f: Vector2 = d * 26.0 * m - (load.linear_velocity - vel) * 7.0 * m
	load.apply_central_force(f.limit_length(9000.0 * m))
	if steady:
		var err := wrapf(load_spin - load.global_rotation, -PI, PI)
		# the body's own inertia reads 0 while the engine works it out: ask the server for it
		var st := PhysicsServer2D.body_get_direct_state(load.get_rid())
		var inertia: float = load.inertia if load.inertia > 0.0 else (1.0 / st.inverse_inertia if st != null and st.inverse_inertia > 0.0 else 0.0)
		load.apply_torque(inertia * (err * 40.0 - load.angular_velocity * 9.0))
		load.angular_velocity *= exp(-4.0 * dt)
	if d.length() > 8.0 * Geom.M:
		# the tether gave: the load is lost (stuck fast, or pulled away by someone)
		_let_go()


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_paint()
	prof_us += Time.get_ticks_usec() - t0


func _paint() -> void:
	var lamp: Color = {"bot": Color(1.0, 0.82, 0.3), "cutter": Pal.heat(1.0, 1.6), "hauler": Color(0.55, 0.85, 1.0),
		"torque": Color(0.95, 0.95, 1.0), "torque2": Color(0.95, 0.95, 1.0), "cable": Color(0.6, 1.0, 0.7), "tester": Color(0.75, 0.6, 1.0)}.get(role, Pal.ink(1.0))
	var trade := "torque" if role == "torque2" else role
	# the cable laid so far, paid out of the reel's fairlead
	if cable.size() >= 1:
		var pts := PackedVector2Array()
		for p in cable:
			pts.append(to_local(p))
		if laying:
			pts.append(Vector2.from_angle(heading + PI) * R * 0.9)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0, 0, 0, 0.5), 3.6, true)
			draw_polyline(pts, Color(0.3, 0.32, 0.36), 2.0, true)
			draw_polyline(pts, Color(0.55, 0.58, 0.62, 0.6), 0.7, true)
	# the tether off the winch drum to its load, and the shackle on it
	if load != null and is_instance_valid(load):
		var grip: Vector2 = to_local(load.global_transform * load_pt)
		draw_line(Vector2.ZERO, grip, Color(0, 0, 0, 0.5), 2.6, true)
		draw_line(Vector2.ZERO, grip, Pal.ink(0.8), 1.1, true)
		draw_arc(grip + Vector2(0, -2.5), 2.6, PI * 0.1, PI * 0.9 + PI, 10, Pal.ink(0.9), 1.2, true)
		draw_rect(Rect2(grip - Vector2(3.2, 1.0), Vector2(6.4, 3.2)), lamp)
	# the airframe
	var sc := R / 20.0
	var z: float = game.cam_zoom() if game != null and game.has_method("cam_zoom") else 1.0
	CrewArt.Art.set_scale(sc * z)
	var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(xf)
	var push := (_thrust / ACCEL).limit_length(1.0) if Txt.anim_level() > 0 else Vector2.ZERO
	CrewArt.draw(self, {"heading": heading, "t": t, "thrust": push, "role": trade, "busy": work, "lamp": lamp, "reel": reel,
		"seed": float(get_instance_id() % 7) * 0.13, "base_xf": xf})
	draw_set_transform_matrix(Transform2D.IDENTITY)
	CrewArt.Art.lite = false
	# the tool arm from its nose to the work, the trade's head on the work
	if work > 0.02:
		var sh := Vector2.from_angle(heading) * R * 0.75
		var to := to_local(tool_at)
		var rest := sh + Vector2.from_angle(heading) * 6.0
		var tip := CrewArt.arm(self, sh, rest.lerp(to, work), ARM, 2.2)
		CrewArt.head(self, trade, tip, sh, t, work, lamp)
