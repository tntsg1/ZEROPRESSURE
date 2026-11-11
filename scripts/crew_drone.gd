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

const SPEED := 240.0
const ACCEL := 620.0
const R := 13.0
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
var _thrust := Vector2.ZERO


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
	if game != null and (game.paused_sim or game.state not in ["play", "build", "porttour"]):
		return
	t += dt
	var desired := Vector2.ZERO
	if goal != Vector2.INF:
		var off := goal - global_position
		# braking distance: never asked to go faster than it can stop
		var sp := minf(SPEED, minf(off.length() * 3.5, sqrt(2.0 * ACCEL * 0.8 * maxf(off.length() - 1.0, 0.0))))
		desired = off.normalized() * sp if off.length() > 0.5 else Vector2.ZERO
		if off.length() > 6.0:
			heading = lerp_angle(heading, off.angle(), 1.0 - exp(-6.0 * dt))
	# a heavy load makes it slow to answer
	var heavy := 1.0
	if load != null and is_instance_valid(load):
		heavy = 1.0 + clampf(float(load.mass) / 2.0, 0.0, 2.5)
	_thrust = ((desired - vel) * 7.0).limit_length(ACCEL / heavy)
	vel += _thrust * dt
	global_position += vel * dt
	if laying:
		if cable.is_empty() or cable[cable.size() - 1].distance_to(global_position) > 10.0:
			cable.append(global_position)
	_carry(dt)
	queue_redraw()


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
	var ink := Color(0.86, 0.9, 0.96)
	var dark := Color(0.07, 0.075, 0.085)
	var lamp: Color = {"bot": Color(1.0, 0.82, 0.3), "cutter": Pal.heat(1.0, 1.6), "hauler": Color(0.55, 0.85, 1.0),
		"torque": Color(0.95, 0.95, 1.0), "cable": Color(0.6, 1.0, 0.7), "tester": Color(0.75, 0.6, 1.0)}.get(role, ink)
	# the cable laid so far, sagging a little between its points
	if cable.size() >= 1:
		var pts := PackedVector2Array()
		for p in cable:
			pts.append(to_local(p))
		if laying:
			pts.append(Vector2.ZERO)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0, 0, 0, 0.5), 3.4)
			draw_polyline(pts, Color(0.32, 0.34, 0.38), 1.8)
	# the tether to its load
	if load != null and is_instance_valid(load):
		var grip: Vector2 = to_local(load.global_transform * load_pt)
		draw_line(Vector2(0, R * 0.6), grip, Color(0, 0, 0, 0.5), 2.6)
		draw_line(Vector2(0, R * 0.6), grip, Pal.ink(0.75), 1.2)
		draw_rect(Rect2(grip - Vector2(3, 3), Vector2(6, 6)), lamp)
	# the tool
	if tool:
		var tp := to_local(tool_at)
		var nose := Vector2.from_angle((tool_at - global_position).angle()) * (R + 2.0)
		match role:
			"cutter":
				var fl := 0.7 + 0.3 * sin(t * 61.0)
				draw_line(nose, tp, Pal.heat(0.9, 2.2), 2.4)
				draw_line(nose, tp, Color(1.0, 0.95, 0.85, fl), 1.0)
				draw_circle(tp, 4.0 * fl, Pal.heat(0.8 * fl, 2.4))
			"torque":
				draw_line(nose, tp, Pal.ink(0.8), 2.4)
				var a := t * 14.0
				for k in 3:
					var dd := Vector2.from_angle(a + TAU * k / 3.0) * 5.0
					draw_line(tp - dd, tp + dd, Pal.ink(0.9), 1.4)
			"tester":
				draw_line(nose, tp, Color(0.75, 0.6, 1.0, 0.9), 1.4)
				draw_circle(tp, 2.5, Color(0.75, 0.6, 1.0))
			_:
				draw_line(nose, tp, Pal.ink(0.7), 1.6)
	# the airframe: a hex hull, two pods, its trade's lamp
	var hull := PackedVector2Array()
	for i in 6:
		hull.append(Vector2.from_angle(TAU * i / 6.0 + 0.52) * R)
	draw_colored_polygon(hull, dark)
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, ink, 1.5)
	var fw := Vector2.from_angle(heading)
	var side := fw.orthogonal()
	for s: float in [-1.0, 1.0]:
		var pod := side * s * (R + 3.0)
		draw_rect(Rect2(pod - Vector2(3, 4), Vector2(6, 8)), Pal.ink(0.55), false, 1.0)
	# thrust: short plumes against the push
	var k := _thrust.length() / ACCEL
	if k > 0.08:
		var back := -_thrust.normalized()
		draw_line(back * R, back * (R + 4.0 + 10.0 * k), Color(0.55, 0.8, 1.0, 0.5 + 0.4 * k), 2.0)
	var blink := 1.0 if fmod(t + float(get_instance_id() % 7) * 0.13, 1.2) < 0.7 else 0.35
	draw_circle(fw * 4.0, 2.6, Color(lamp, blink))
