extends RigidBody2D
# The work boat (design/成长版本/G5-G7_工业港成长重设计_2026-10-22/21, Q26/Q27): a compact
# industrial tug-barge, ~10 x 4 m, parked at the berth's boat pad outside the gate.
# The drone flies into its rack (E), the player drives the boat with the same keys
# (thrust and inertia, braking, attitude held), docks at one of the port's exterior
# pads and lets the drone out again (E). From a pad it can also fly itself to any pad
# already visited, along a lane round the outside of the station; any movement key
# takes over. Only at the empty berth of a career.
class_name WorkBoat

var game
var input := {"move": Vector2.ZERO, "dash": false, "brake": false}
var aboard := false              # the drone is in the rack
var heading := 0.0
var flame := [0.0, 0.0]          # main, retro
var pad := "berth"               # the pad the boat is docked at ("" under way)
var docking := ""                # the pad the assist is settling on
var route: Array = []            # autopilot waypoints (world px), empty when manual
var route_to := ""
var t := 0.0
const LEN := 10.0                # m
const WID := 4.0
const ACCEL := 2.6 * 48.0        # px/s²
const VMAX := 10.0 * 48.0
const DASH_K := 1.8
const BRAKE_K := 2.0
const AUTO_V := 14.0 * 48.0
const RACK_REACH := 3.5          # m: the drone boards from this close
const DOCK_REACH := 12.0         # m: the assist takes over from here
const LANE := 22.0               # m outside the districts' ellipse: the autopilot's lane
# pads: id -> name key; positions from pad_at()
const PADS := ["berth", "trade", "tug", "power", "ark"]


func _init() -> void:
	mass = 6.0
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 2
	collision_mask = 1 | 4 | World.STATIC_LAYER
	z_index = 5
	z_as_relative = false
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.2
	pm.friction = 0.3
	physics_material_override = pm
	var cs := CollisionShape2D.new()
	var sh := CapsuleShape2D.new()
	sh.radius = WID * 0.5 * Geom.M
	sh.height = LEN * Geom.M
	cs.shape = sh
	cs.rotation = PI / 2.0
	add_child(cs)


static func pad_at(id: String) -> Vector2:
	var m := Geom.M * PortArt.PM
	var c := Backdrop.port_centre_px()
	match id:
		"berth":
			return Vector2(Dock.TOWER_X - 14.0, Dock.RAIL_Y - 8.0) * Geom.M
		"trade":
			var r := PortStructure.box("trade")
			return Vector2(r.end.x + 76.0 * m, r.get_center().y - 6.0 * m)
		"tug":
			var r2 := PortStructure.box("tug")
			return Vector2(r2.position.x - 22.0 * m, r2.get_center().y)
		"power":
			var r3 := PortStructure.box("power")
			return Vector2(r3.get_center().x, r3.position.y - 34.0 * m)
		"ark":
			return c + (PortArt.ARK_AT - Vector2(50.0 * PortArt.ARK_K + 12.0, 0.0)) * m
	return c


static func pad_name(id: String) -> String:
	return Txt.t("boat_pad_" + id)


func active() -> bool:
	return game != null and game.in_berth() and game.career()


func _ready() -> void:
	var saved: String = str(Career.data.get("boat_pad", "berth")) if not Career.data.is_empty() else "berth"
	pad = saved if saved in PADS else "berth"
	global_position = pad_at(pad)
	heading = 0.0
	# 108 号 帧率: the pads stand still — drawn once in their own layer, in the world, and again only
	# when the pad in use or the zoom changes (they were redrawn with the hull every frame)
	pads_layer = Node2D.new()
	pads_layer.top_level = true
	pads_layer.z_as_relative = true
	pads_layer.z_index = -1
	pads_layer.draw.connect(_draw_pads)
	add_child(pads_layer)


var pads_layer: Node2D
var _pads_key := ""


# the pad the boat is sitting on, or "" ("near" means within the assist's reach)
func pad_near() -> String:
	var best := ""
	var bd := DOCK_REACH * Geom.M
	for id in PADS:
		var d := global_position.distance_to(pad_at(id))
		if d < bd:
			bd = d
			best = id
	return best


func stopped() -> bool:
	return linear_velocity.length() < 0.6 * Geom.M


func drone_can_board() -> bool:
	return active() and not aboard and game.drone != null and game.drone.alive and game.drone.global_position.distance_to(global_position) <= RACK_REACH * Geom.M


func board() -> void:
	aboard = true
	route = []
	game.drone.collision_layer = 0
	game.drone.collision_mask = 0
	game.drone.visible = false
	game.drone.linear_velocity = Vector2.ZERO


func leave() -> bool:
	if not aboard or not stopped():
		return false
	aboard = false
	var d = game.drone
	d.global_position = global_position + Vector2(0, -(WID * 0.5 + 1.2) * Geom.M)
	d.linear_velocity = linear_velocity
	d.collision_layer = 2
	d.collision_mask = 1 | 4 | World.STATIC_LAYER
	d.visible = true
	route = []
	if pad != "":
		_remember(pad)
	return true


func _remember(id: String) -> void:
	if Career.data.is_empty():
		return
	var v: Array = Career.data.get("boat_visited", [])
	if id not in v:
		v.append(id)
	Career.data.boat_visited = v
	Career.data.boat_pad = pad


func visited() -> Array:
	var v: Array = Career.data.get("boat_visited", []) if not Career.data.is_empty() else []
	if "berth" not in v:
		v.append("berth")
	return v


# the autopilot's lane: an ellipse LANE metres outside the districts; a pad links to the
# lane at its own angle, the boat rides the arc between the two angles
func plan(to: String) -> bool:
	if to == pad or to not in visited():
		return false
	var m := Geom.M * PortArt.PM
	var c := Backdrop.port_centre_px()
	var rx := (PortArt.RADIUS.x + PortArt.BOX.x * 0.5 + LANE) * m
	var ry := (PortArt.RADIUS.y + PortArt.BOX.y * 0.5 + LANE) * m
	var a0 := (global_position - c).angle()
	var dest := pad_at(to)
	var a1 := (dest - c).angle()
	route = []
	route.append(c + Vector2(cos(a0) * rx, sin(a0) * ry))
	var diff := angle_difference(a0, a1)
	var steps := maxi(2, int(absf(diff) / 0.15))
	for i in range(1, steps + 1):
		var a := a0 + diff * float(i) / steps
		route.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	route.append(dest)
	route_to = to
	pad = ""
	docking = ""
	return true


func _physics_process(dt: float) -> void:
	t += dt
	if not active():
		return
	var mv: Vector2 = input.move
	var acc := Vector2.ZERO
	if mv.length() > 0.05 and not route.is_empty():
		route = []          # the pilot takes over
		route_to = ""
	if not route.is_empty():
		var wp: Vector2 = route[0]
		var d := wp - global_position
		var last: bool = route.size() == 1
		var want_v := d.normalized() * minf(AUTO_V, sqrt(2.0 * ACCEL * 1.5 * d.length()) if last else AUTO_V)
		acc = ((want_v - linear_velocity) * 3.0).limit_length(ACCEL * 2.0)
		if d.length() < (1.0 if last else 4.0) * Geom.M:
			route.pop_front()
			if route.is_empty():
				linear_velocity = Vector2.ZERO
				pad = route_to
				route_to = ""
				_remember(pad)
	elif mv.length() > 0.05:
		acc = mv.normalized() * ACCEL * (DASH_K if input.dash else 1.0)
		if linear_velocity.dot(mv.normalized()) > VMAX:
			acc = Vector2.ZERO
		pad = ""
		docking = ""
	elif input.brake:
		var v := linear_velocity
		acc = -v.normalized() * ACCEL * BRAKE_K if v.length() > 4.0 else -v / maxf(dt, 0.001)
	else:
		# docking assist: near a pad, hands off and slow, it eases onto the pad and holds
		var near := pad_near()
		if near != "" and linear_velocity.length() < 3.0 * Geom.M:
			docking = near
			var to := pad_at(near) - global_position
			acc = (to * 2.2 - linear_velocity * 2.4).limit_length(ACCEL)
			if to.length() < 0.5 * Geom.M and linear_velocity.length() < 0.3 * Geom.M:
				linear_velocity = Vector2.ZERO
				global_position = pad_at(near)
				acc = Vector2.ZERO
				if pad != near:
					pad = near
					_remember(near)
		else:
			docking = ""
	apply_central_force(acc * mass)
	# the hull turns to follow where it is going; the nozzles answer the real acceleration
	var v2 := linear_velocity
	if v2.length() > 0.8 * Geom.M:
		heading = lerp_angle(heading, v2.angle(), 2.5 * dt)
	var fwd := Vector2.from_angle(heading)
	var along := acc.dot(fwd) / ACCEL
	flame[0] = lerpf(flame[0], clampf(along, 0.0, 1.5), 8.0 * dt)
	flame[1] = lerpf(flame[1], clampf(-along, 0.0, 1.5), 8.0 * dt)
	if aboard and game.drone != null:
		game.drone.global_position = global_position
		game.drone.linear_velocity = Vector2.ZERO
	# 108 号 帧率: only while its part of the port is in view (scripts/view_cull.gd)
	if ViewCull.sees(game, Rect2(global_position - Vector2(40, 40) * Geom.M, Vector2(80, 80) * Geom.M)):
		queue_redraw()
	var pk := "%s|%s|%s|%d" % [pad, docking, str(active()), int(round(maxf(game.cam_zoom(), 0.02) * 2000.0))]
	if pk != _pads_key and pads_layer != null:
		_pads_key = pk
		pads_layer.queue_redraw()


func _process(_dt: float) -> void:
	visible = active()


func _draw() -> void:
	if not active():
		return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var font := Fonts.get_font("Medium")
	_draw_hull(M, z, lw, font)


# the pads, in world space (their own layer, scripts above)
func _draw_pads() -> void:
	if not active():
		return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var font := Fonts.get_font("Medium")
	var c := pads_layer
	for id in PADS:
		var p := pad_at(id)
		var on: bool = id == pad or id == docking
		var col := Pal.tint(Pal.AIR, 0.9 if on else 0.45, 1.3)
		var w := (LEN * 0.5 + 1.5) * M
		var h := (WID * 0.5 + 1.0) * M
		# 43 号: a pad is a thing, not a screen marker: a landing deck under the boat on a
		# bracket, two mooring bollards at its ends and one steady berthing lamp
		var deck := Rect2(p + Vector2(-w, h), Vector2(w * 2.0, 0.8 * M))
		c.draw_rect(deck, Color(0.06, 0.064, 0.072))
		c.draw_rect(deck, Pal.ink(0.45), false, lw)
		var x := deck.position.x + 1.5 * M
		while x < deck.end.x - 0.5 * M:
			c.draw_line(Vector2(x, deck.position.y), Vector2(x - 0.6 * M, deck.end.y), Pal.heat(0.25, 1.0), lw)
			x += 2.0 * M
		c.draw_line(deck.get_center() + Vector2(0, 0.4 * M), deck.get_center() + Vector2(0, 2.4 * M), Pal.ink(0.4), 1.5 * lw)
		for sx: float in [-1.0, 1.0]:
			var bp := Vector2(p.x + sx * (w - 0.6 * M), deck.position.y)
			c.draw_rect(Rect2(bp - Vector2(0.35 * M, 1.0 * M), Vector2(0.7, 1.0) * M), Pal.ink(0.5))
			c.draw_rect(Rect2(bp - Vector2(0.55 * M, 1.15 * M), Vector2(1.1, 0.3) * M), Pal.ink(0.6))
		c.draw_circle(Vector2(p.x, deck.position.y - 0.3 * M), 0.3 * M, col)
		if z >= 0.1 or on:
			c.draw_set_transform(p, 0, Vector2.ONE / z)
			c.draw_string(font, Vector2(-40, -h * z - 8), pad_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			c.draw_set_transform(Vector2.ZERO)


func _draw_hull(M: float, z: float, lw: float, font: Font) -> void:
	# the autopilot's lane while it runs
	if not route.is_empty():
		var prev := Vector2.ZERO
		for wp in route:
			var q: Vector2 = wp - global_position
			draw_line(prev, q, Pal.tint(Pal.AIR, 0.25, 1.0), lw)
			prev = q
	# the hull, nose along the heading
	draw_set_transform(Vector2.ZERO, heading, Vector2.ONE)
	var L := LEN * M
	var W := WID * M
	var hull := PackedVector2Array([Vector2(L * 0.5, -W * 0.25), Vector2(L * 0.38, -W * 0.5), Vector2(-L * 0.42, -W * 0.5), Vector2(-L * 0.5, -W * 0.3), Vector2(-L * 0.5, W * 0.3), Vector2(-L * 0.42, W * 0.5), Vector2(L * 0.38, W * 0.5), Vector2(L * 0.5, W * 0.25)])
	draw_colored_polygon(hull, Color(0.05, 0.053, 0.06))
	draw_polyline(hull, Pal.ink(0.85), 1.6 * lw)
	draw_line(hull[0], hull[7], Pal.ink(0.85), 1.6 * lw)
	# plating seams
	for k in 4:
		var x := -L * 0.35 + k * L * 0.2
		draw_line(Vector2(x, -W * 0.5), Vector2(x, W * 0.5), Pal.ink(0.18), lw)
	# the control cabin forward: a window band
	draw_rect(Rect2(Vector2(L * 0.2, -W * 0.32), Vector2(L * 0.22, W * 0.64)), Pal.ink(0.5), false, lw)
	draw_rect(Rect2(Vector2(L * 0.24, -W * 0.22), Vector2(L * 0.14, W * 0.44)), Pal.tint(Pal.AIR, 0.35, 1.2))
	# the drone rack amidships: a U cradle, its lock lamp lit when the drone is in
	var rack := Rect2(Vector2(-L * 0.12, -W * 0.3), Vector2(L * 0.22, W * 0.6))
	draw_rect(rack, Color(0.03, 0.034, 0.04))
	draw_polyline(PackedVector2Array([rack.position, rack.position + Vector2(0, rack.size.y), rack.end, Vector2(rack.end.x, rack.position.y)]), Pal.ink(0.6), 1.4 * lw)
	draw_circle(rack.get_center(), 0.35 * M, Pal.heat(0.9, 1.5) if aboard else Pal.ink(0.2))
	if aboard:
		# the drone's silhouette in the cradle
		draw_colored_polygon(PackedVector2Array([rack.get_center() + Vector2(0.5 * M, 0), rack.get_center() + Vector2(-0.4 * M, -0.35 * M), rack.get_center() + Vector2(-0.4 * M, 0.35 * M)]), Pal.ink(0.7))
	# the grapple arms either side, folded
	for sy: float in [-1.0, 1.0]:
		draw_line(Vector2(-L * 0.05, sy * W * 0.5), Vector2(L * 0.1, sy * W * 0.72), Pal.ink(0.5), 1.4 * lw)
		draw_line(Vector2(L * 0.1, sy * W * 0.72), Vector2(L * 0.22, sy * W * 0.62), Pal.ink(0.5), 1.4 * lw)
		draw_circle(Vector2(-L * 0.05, sy * W * 0.5), 0.2 * M, Pal.ink(0.6))
	# the thruster block aft: two bells, their flames by the real acceleration
	for sy: float in [-1.0, 1.0]:
		var bell := Vector2(-L * 0.5, sy * W * 0.22)
		draw_line(bell, bell + Vector2(-0.6 * M, -0.25 * M * sy), Pal.ink(0.7), 1.4 * lw)
		draw_line(bell, bell + Vector2(-0.6 * M, 0.25 * M * sy), Pal.ink(0.7), 1.4 * lw)
		if flame[0] > 0.05:
			draw_colored_polygon(PackedVector2Array([bell + Vector2(-0.6 * M, -0.35 * M), bell + Vector2(-(0.6 + 2.5 * flame[0]) * M, 0), bell + Vector2(-0.6 * M, 0.35 * M)]), Pal.heat(0.6 * minf(flame[0], 1.0), 1.6))
	# retro nozzles at the bow
	if flame[1] > 0.05:
		for sy: float in [-1.0, 1.0]:
			var nz := Vector2(L * 0.42, sy * W * 0.4)
			draw_colored_polygon(PackedVector2Array([nz + Vector2(0, -0.2 * M), nz + Vector2((0.4 + 1.5 * flame[1]) * M, 0), nz + Vector2(0, 0.2 * M)]), Pal.heat(0.6 * minf(flame[1], 1.0), 1.6))
	# running lights
	draw_circle(Vector2(L * 0.46, -W * 0.3), 0.15 * M, Pal.heat(0.9, 1.5))
	draw_circle(Vector2(L * 0.46, W * 0.3), 0.15 * M, Pal.tint(Pal.FLUID, 0.9, 1.5))
	draw_set_transform(Vector2.ZERO)
	draw_string(font, Vector2(-L * 0.3, -W * 0.5 - 8.0 / z), "WB-1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 / z), Pal.ink(0.55))
	# the prompt when the drone can board
	if drone_can_board() and z >= 0.1:
		draw_set_transform(Vector2(0, -W * 0.5 - 2.0 * M), 0, Vector2.ONE / z)
		draw_string(font, Vector2(-70, 0), Txt.t("boat_board") % Keys.label("use"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.heat(0.9, 1.2))
		draw_set_transform(Vector2.ZERO)
