extends Node2D
# 128 号 第 6 段 顶部快线 (user 2026-11-07, 128 号设计文档末尾): a long berth's drone tow rail. An I-beam hung
# under the boom from the tower to the berth's far end, a hook station at the gate (where the drone comes
# in) and every ~30 m along it, a carriage parked at each. At a station Enter: the carriage's arm drops,
# its jaws close on the drone's top mount (a latch you see and hear); hooked, left / right moves it with
# no inertia at all — it goes while the key is held and stops the frame it is let go — at 20 % of the
# rail's length a second, so the whole length is ~5 s whatever the berth's tier. Enter again: the jaws
# open and the drone flies on with its own inertia from rest; the carriage runs home to its station.
# The rail itself is solid (a bright line, layer 4) and sits in the boom's shadow: over the crane's
# carrying height, over the equipment bays' lips, clear of the gate (that span is a dim guide, not solid).
# Dock-local metres (the dock sits at the origin).

const K_SPEED := 0.2              # of the rail's length a second, hooked
const CanvasBatch = preload("res://scripts/canvas_batch.gd")
const SPACING := 30.0             # m between hook stations
const TRACK_H := 0.35             # m: the beam's depth under the boom
const HANG := 1.6                 # m: the hooked drone's centre under the boom line
const REACH := 2.4                # m: how close to a station's hook point Enter takes
const LATCH_S := 0.28             # s: the arm drops and the jaws close
const HINT_KEY := "top_rail"

var game
var body: StaticBody2D
var t := 0.0
var _sig := ""
var x0 := 0.0
var x1 := 0.0
var gap := Vector2.ZERO           # the gate's span (no beam there), or zero
var stations: Array = []          # [{x, car (carriage x), lamp}]
var hooked := -1                  # the station whose carriage holds the drone
var latch := 0.0                  # 0 open … 1 closed (the jaws)
var latching := false
var hx := 0.0                     # the hooked drone's x on the rail (m)
var _layer_was := 2
var _hinted := false
var beam: Node2D
var _beam_key := ""
var _beam_view := Rect2()
var _pen: RefCounted
var _ambient_key: Array = []
var _next_redraw_ms := 0


func _ready() -> void:
	z_index = 7     # over the drone (6): the jaws close round its top mount
	z_as_relative = false
	beam = Node2D.new()
	beam.show_behind_parent = true
	beam.draw.connect(_draw_beam)
	add_child(beam)
	body = StaticBody2D.new()
	body.name = "TopRail"
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	rebuild()


func active() -> bool:
	return game != null and is_instance_valid(game) and game.dock != null and game.dock.visible and not game.get("belt")


func y_beam() -> float:
	return Dock.RAIL_Y


func y_hang() -> float:
	return Dock.RAIL_Y + HANG


func length() -> float:
	return x1 - x0


func speed() -> float:
	return length() * K_SPEED


# the rail laid out for the berth as it is now (its length, its lift, the gate)
func rebuild() -> void:
	x0 = Dock.TOWER_X + 1.2
	x1 = Dock.FLOOR_X1 - 1.5
	gap = Vector2.ZERO
	if game != null and game.dock != null and game.dock.port_open():
		var gr: Rect2 = game.dock.port_gate()
		gap = Vector2(gr.position.x, gr.end.x)
	_sig = _signature()
	for c in body.get_children():
		c.queue_free()
	var M := Geom.M
	var spans: Array = [Vector2(x0, x1)] if gap == Vector2.ZERO else [Vector2(x0, gap.x), Vector2(gap.y, x1)]
	for sp: Vector2 in spans:
		if sp.y - sp.x < 0.2:
			continue
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(sp.y - sp.x, TRACK_H) * M
		cs.shape = sh
		cs.position = Vector2((sp.x + sp.y) * 0.5, y_beam() + TRACK_H * 0.5) * M
		body.add_child(cs)
	# the stations: the gate (the way in) first, then every SPACING m, the far end
	var xs: Array = []
	if gap != Vector2.ZERO:
		xs.append((gap.x + gap.y) * 0.5)
	xs.append(x0 + 2.0)
	var n := maxi(1, int(round((x1 - 2.0 - (x0 + 2.0)) / SPACING)))
	for i in range(1, n + 1):
		xs.append(lerpf(x0 + 2.0, x1 - 2.0, float(i) / n))
	xs.sort()
	var keep: Array = []
	for x in xs:
		if keep.is_empty() or absf(float(x) - float(keep.back())) > 6.0:
			keep.append(x)
		elif gap != Vector2.ZERO and absf(float(x) - (gap.x + gap.y) * 0.5) < 0.01:
			keep[keep.size() - 1] = x
	var old := stations
	stations = []
	for x in keep:
		stations.append({"x": float(x), "car": float(x), "lamp": 0.0})
	if hooked >= 0:
		hooked = clampi(hooked, 0, stations.size() - 1)
		stations[hooked].car = hx
	if old.is_empty():
		pass


func _signature() -> String:
	var g := ""
	if game != null and game.dock != null and game.dock.port_open():
		g = str(game.dock.port_gate())
	return "%.2f %.2f %s" % [Dock.FLOOR_X1, Dock.RAIL_Y, g]


# the station whose hook point the drone is at (-1: none)
func near_station() -> int:
	if game == null or game.drone == null or not game.drone.alive:
		return -1
	var p: Vector2 = (game.drone.global_position - global_position) / Geom.M
	var best := -1
	var bd := REACH
	for i in stations.size():
		var d := p.distance_to(Vector2(float(stations[i].x), y_hang()))
		if d < bd and absf(float(stations[i].car) - float(stations[i].x)) < 0.3:
			bd = d
			best = i
	return best


func can_use() -> bool:
	if not active() or game.state != "play" or game.menu_open or game.contract_open or game.console_ui != null:
		return false
	if game.drone == null or not game.drone.alive or game.in_vehicle():
		return false
	return true


func hook(i: int) -> void:
	if i < 0 or hooked >= 0:
		return
	hooked = i
	hx = float(stations[i].x)
	latch = 0.0
	latching = true
	var d = game.drone
	_layer_was = int(d.collision_layer)
	d.collision_layer = 0
	d.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	d.freeze = true
	d.linear_velocity = Vector2.ZERO
	_place()
	if game.get("sfx") != null:
		game.sfx.play("clamp")


func release() -> void:
	if hooked < 0:
		return
	var d = game.drone
	if d != null and is_instance_valid(d):
		d.freeze = false
		d.collision_layer = _layer_was
		d.linear_velocity = Vector2.ZERO
		d.angular_velocity = 0.0
	hooked = -1
	latching = false
	latch = 0.0
	if game.get("sfx") != null:
		game.sfx.play("switch")


func _place() -> void:
	var d = game.drone
	d.global_position = global_position + Vector2(hx, y_hang()) * Geom.M
	d.linear_velocity = Vector2.ZERO


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
		return
	if hooked >= 0:
		release()
		get_viewport().set_input_as_handled()
		return
	if not can_use():
		return
	var i := near_station()
	if i >= 0:
		hook(i)
		get_viewport().set_input_as_handled()


func _physics_process(dt: float) -> void:
	if hooked < 0:
		return
	if not can_use() and not (game != null and game.drone != null and game.drone.alive):
		release()
		return
	if game.drone == null or not game.drone.alive or game.state != "play":
		release()
		return
	if latching:
		latch = minf(1.0, latch + dt / LATCH_S)
		if latch >= 1.0:
			latching = false
	else:
		# no inertia: the key held moves it, let go it stands
		var mx: float = game.drone.input.move.x
		if absf(mx) > 0.2:
			hx = clampf(hx + signf(mx) * speed() * dt, x0 + 0.6, x1 - 0.6)
	stations[hooked].car = hx
	_place()


func _process(dt: float) -> void:
	t += dt
	visible = active()
	if not visible:
		if hooked >= 0:
			release()
		return
	if _signature() != _sig:
		rebuild()
	# the free carriages run home to their stations at the rail's speed
	var car_moving := hooked >= 0
	for i in stations.size():
		var s: Dictionary = stations[i]
		car_moving = car_moving or absf(float(s.car) - float(s.x)) > 0.001
		if i != hooked:
			s.car = move_toward(float(s.car), float(s.x), speed() * dt)
		var want := 1.0 if i == hooked else (0.6 if i == near_station() and hooked < 0 else 0.0)
		s.lamp = move_toward(float(s.lamp), want, dt * 4.0)
	_hint()
	visible = ViewCull.sees(game, Rect2(Vector2(x0, y_beam() - 1.0) * Geom.M, Vector2(x1 - x0, HANG + 4.0) * Geom.M))
	if visible:
		var view := ViewCull.view(game)
		var key := str([_sig, roundi(log(maxf(game.cam_zoom(), 0.02)) * 200.0), ViewCull.off])
		if key != _beam_key or not _beam_view.encloses(view):
			_beam_key = key
			_beam_view = view.grow(4.0 * Geom.M)
			beam.queue_redraw()
		var now := Time.get_ticks_msec()
		var view_key := [get_viewport().get_canvas_transform(), get_viewport_rect().size, _sig, ViewCull.off]
		if game.cam_zoom() >= 0.2 or car_moving or view_key != _ambient_key or now >= _next_redraw_ms:
			_next_redraw_ms = now + 33
			_ambient_key = view_key
			queue_redraw()


# 第一次飞到挂钩点：一行提示，走现有的提示规则（引导在说话时不出、提示等级、每个存档一次）
func _hint() -> void:
	if _hinted or hooked >= 0 or near_station() < 0 or not can_use():
		return
	if game.get("training") or game.get("exam") != null:
		return
	if game.has_method("guide_coach") and game.guide_coach() != null:
		return
	var gc = load("res://scripts/guide_cards.gd")
	if gc != null and gc.has_method("showing") and gc.showing():
		return
	if Txt.hint_tier == "hardcore":
		return
	_hinted = true
	if game.career() and not Career.hint_once(HINT_KEY):
		return
	if game.get("hints_seen") != null:
		if game.hints_seen.has(HINT_KEY):
			return
		game.hints_seen[HINT_KEY] = true
	if game.get("hud") != null:
		game.hud.show_hint(w("Enter 挂上快线", "ENTER: HOOK ON THE TOP RAIL"))


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


# ---------------------------------------------------------------- drawing
func _ink(a: float) -> Color:
	return Pal.ink(a)


func _draw() -> void:
	if not visible:
		return
	_pen = CanvasBatch.new(self)
	_pen.circle_segments = 64
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var view := ViewCull.view(game).grow(3.0 * M + 64.0 / z)
	_pen.circle_segments = 16 if M * z < 6.0 else 64
	for i in stations.size():
		if ViewCull.off or view.has_point(Vector2(float(stations[i].x), y_hang()) * M):
			_station(stations[i], i, M, lw, z)
	for i in stations.size():
		if ViewCull.off or view.has_point(Vector2(float(stations[i].car), y_hang()) * M):
			_carriage(stations[i], i, M, lw, z)
	_pen.flush()
	_pen = null


func _draw_beam() -> void:
	if not active():
		return
	var M := Geom.M
	var z: float = maxf(game.cam_zoom(), 0.02)
	var lw := 1.0 / z
	var yb := y_beam() * M
	var yh := (y_beam() + TRACK_H) * M
	var face := Color(0.12, 0.126, 0.138)
	# the beam: hangers up into the boom every 3 m, the I-beam (web, flanges), its lit lower flange edge
	var spans: Array = [Vector2(x0, x1)] if gap == Vector2.ZERO else [Vector2(x0, gap.x), Vector2(gap.y, x1)]
	for sp: Vector2 in spans:
		if sp.y - sp.x < 0.2:
			continue
		var r := Rect2(Vector2(sp.x * M, yb), Vector2((sp.y - sp.x) * M, yh - yb))
		if not ViewCull.off and not _beam_view.intersects(r.grow(M)):
			continue
		beam.draw_rect(r, face)
		beam.draw_rect(Rect2(r.position, Vector2(r.size.x, 0.07 * M)), Color(0.17, 0.176, 0.19))
		beam.draw_rect(Rect2(Vector2(r.position.x, r.end.y - 0.08 * M), Vector2(r.size.x, 0.08 * M)), Color(0.2, 0.208, 0.224))
		beam.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), _ink(0.85), 1.6 * lw)
		beam.draw_line(r.position, Vector2(r.end.x, r.position.y), _ink(0.55), lw)
		beam.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), _ink(0.85), 1.6 * lw)
		beam.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), _ink(0.85), 1.6 * lw)
		# the conductor bar along the web, a hanger and a bolt pair every 3 m
		beam.draw_line(Vector2(r.position.x, yb + 0.2 * M), Vector2(r.end.x, yb + 0.2 * M), Pal.tint(Pal.VOLT, 0.35, 1.0), maxf(1.0, 0.04 * M))
		if z * M >= 6.0:
			var hx2 := sp.x + 0.6
			if not ViewCull.off:
				hx2 += maxf(0.0, floor((_beam_view.position.x / M - hx2) / 3.0)) * 3.0
			var limit := sp.y - 0.3 if ViewCull.off else minf(sp.y - 0.3, _beam_view.end.x / M + 0.3)
			while hx2 < limit:
				beam.draw_line(Vector2(hx2 * M, yb), Vector2(hx2 * M, yb + 0.12 * M), _ink(0.45), lw)
				beam.draw_circle(Vector2((hx2 - 0.12) * M, yb + 0.06 * M), 0.035 * M, _ink(0.5))
				beam.draw_circle(Vector2((hx2 + 0.12) * M, yb + 0.06 * M), 0.035 * M, _ink(0.5))
				hx2 += 3.0
		# end stops: a buffer block with a hazard face
		for ex in ([sp.x, sp.y] as Array):
			var er := Rect2(Vector2((float(ex) - 0.18) * M, yh), Vector2(0.36 * M, 0.22 * M))
			beam.draw_rect(er, Pal.heat(0.55, 1.0))
			beam.draw_rect(er, _ink(0.6), false, lw)
	# the gate's span: a dim guide the carriages run across (not solid: the drone comes in under it)
	if gap != Vector2.ZERO:
		var gx := gap.x
		while gx < gap.y:
			beam.draw_line(Vector2(gx * M, yh - 0.05 * M), Vector2(minf(gx + 0.35, gap.y) * M, yh - 0.05 * M), _ink(0.22), lw)
			gx += 0.7


func _station(s: Dictionary, i: int, M: float, lw: float, z: float) -> void:
	var x := float(s.x)
	var yh := (y_beam() + TRACK_H) * M
	var br := Rect2(Vector2((x - 0.9) * M, yh), Vector2(1.8 * M, 0.16 * M))
	_pen.draw_rect(br, Color(0.09, 0.094, 0.104))
	_pen.draw_rect(br, _ink(0.55), false, lw)
	for sx in [-0.75, 0.75]:
		_pen.draw_rect(Rect2(Vector2((x + sx - 0.06) * M, yh + 0.16 * M), Vector2(0.12 * M, 0.22 * M)), _ink(0.5))
	var lit: float = float(s.lamp)
	var on_col := Pal.tint(Pal.AIR, 0.9, 1.6) if i == hooked else Pal.tint(Pal.FLUID, 0.85, 1.5)
	var idle := Pal.tint(Pal.FLUID, 0.35 + 0.15 * sin(t * 2.0 + i), 1.1)
	_pen.draw_circle(Vector2((x + 1.05) * M, yh + 0.08 * M), 0.09 * M, idle.lerp(on_col, lit))
	# the hook point: a ring where the drone is to wait (bright while it is in reach)
	if hooked < 0:
		var hp := Vector2(x, y_hang()) * M
		var a := 0.18 + 0.6 * lit
		_pen.draw_arc(hp, (0.55 + 0.06 * sin(t * 3.0)) * M, 0.0, TAU, 8 if M * z < 6.0 else 28, Color(Pal.tint(Pal.FLUID, 1.0, 1.3), a), 1.4 * lw, true)
		if lit > 0.3 and z * M >= 5.0:
			_pen.draw_set_transform(hp + Vector2(0.75 * M, 0.1 * M), 0.0, Vector2.ONE / z)
			_pen.draw_string(Fonts.get_font("Medium"), Vector2.ZERO, w("[Enter] 挂上快线", "[ENTER] HOOK ON"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Pal.ink(0.9), lit))
			_pen.draw_set_transform(Vector2.ZERO)


# a carriage: four wheels on the lower flange, the motor box, the drop arm and its two jaws
func _carriage(s: Dictionary, i: int, M: float, lw: float, z: float) -> void:
	var x := float(s.car)
	var yh := (y_beam() + TRACK_H) * M
	var body_col := Color(0.15, 0.158, 0.172)
	var edge := _ink(0.8)
	if M * z < 6.0:
		# The whole carriage is only 3–8 screen pixels. Its wheels are fractions
		# of a pixel: keep the body and moving drop arm, rather than rebuilding
		# four wheels, their ten-segment rims, the motor and every jaw separately.
		var r := Rect2(Vector2((x - 0.65) * M, yh + 0.06 * M), Vector2(1.3, 0.42) * M)
		_pen.draw_rect(r, body_col)
		_pen.draw_rect(r, edge, false, 1.3 * lw)
		var amount := latch if i == hooked else 0.0
		var arm := lerpf(0.15, 0.62, amount) * M
		_pen.draw_line(Vector2(x * M, yh + 0.48 * M), Vector2(x * M, yh + 0.68 * M + arm), edge, 1.8 * lw)
		return
	# wheels riding the flange
	for wx in [-0.5, -0.18, 0.18, 0.5]:
		_pen.draw_circle(Vector2((x + wx) * M, yh - 0.02 * M), 0.08 * M, Color(0.2, 0.205, 0.22))
		_pen.draw_arc(Vector2((x + wx) * M, yh - 0.02 * M), 0.08 * M, 0.0, TAU, 10, _ink(0.6), lw)
	var cr := Rect2(Vector2((x - 0.65) * M, yh + 0.06 * M), Vector2(1.3 * M, 0.42 * M))
	_pen.draw_rect(cr, body_col)
	_pen.draw_rect(cr, edge, false, 1.3 * lw)
	_pen.draw_rect(Rect2(Vector2((x + 0.3) * M, yh + 0.12 * M), Vector2(0.26 * M, 0.18 * M)), Color(0.04, 0.05, 0.055))
	_pen.draw_circle(Vector2((x - 0.45) * M, yh + 0.2 * M), 0.05 * M, Pal.tint(Pal.AIR, 0.9, 1.5) if i == hooked else _ink(0.3))
	# the drop arm: telescopes down while latching, the jaws close round the drone's mount
	var k := latch if i == hooked else 0.0
	var arm_top := yh + 0.48 * M
	var arm_len := lerpf(0.15, 0.62, k if i == hooked else 0.0) * M
	if i == hooked and not latching:
		arm_len = 0.62 * M
	_pen.draw_rect(Rect2(Vector2((x - 0.07) * M, arm_top), Vector2(0.14 * M, arm_len)), _ink(0.55))
	var jy := arm_top + arm_len
	var open := 1.0 - (k if i == hooked else 0.0)
	for sd in [-1.0, 1.0]:
		var root := Vector2(x * M + sd * 0.08 * M, jy)
		var tip := root + Vector2(sd * (0.08 + 0.18 * open) * M, 0.22 * M)
		var hook_end := tip + Vector2(-sd * 0.12 * M * (1.0 - open * 0.6), 0.04 * M)
		_pen.draw_line(root, tip, edge, 1.8 * lw)
		_pen.draw_line(tip, hook_end, edge, 1.8 * lw)
	# the moment the jaws meet: a short spark of the latch
	if i == hooked and latching and k > 0.85:
		_pen.draw_circle(Vector2(x * M, jy + 0.2 * M), 0.1 * M, Pal.tint(Pal.AIR, 1.0, 2.0))
