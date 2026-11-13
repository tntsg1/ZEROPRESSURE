class_name Crane
extends Node2D
# The heavy crane (roadmap 4.4, a berth facility): a gantry over the berth
# with a hook on a cable. It lifts what the grapple and the haulers cannot —
# up to 12 t — whole: an empty cryogenic tank, a crusher drum, an engine block.
# Marked with the mark key (anything over the hauler's 1.5 t goes on its list),
# it lifts it to its carrying height (over the ships, under the equipment bay),
# runs along, and brings it to the lip of the mouth it belongs in.
# It takes nothing unasked, waits its turn over a mouth, holds back for the
# operator's drone, keeps out of keep-out zones, and the automation key stops
# it (what it holds is let go where it is). Slow: it is a crane.

const MAX_T := 12.0
const SPEED := 2.5 * 48.0        # px/s with a load
const EMPTY := 6.0 * 48.0        # px/s empty
const CLEAR := 3.0 * 48.0        # px it keeps from the operator's drone
const LIFT_Y := -7.4             # m: the height it carries a load at (over the ships, under the equipment bay's lip)

var game: Game
var queue: Array = []            # marked bodies, in order
var body = null
var path: Array = []
var pos := Vector2.ZERO          # the hook
var state := "idle"              # idle reach carry release
var zone := "equip"              # the mouth it is making for (an id: "equip2" is a mouth of its own)
var off := Vector2.ZERO
var hold_t := 0.0
var t := 0.0
var carried := 0
var wait_t := 0.0
const LoadMotion = preload("res://scripts/load_motion.gd")
const Crew = preload("res://scripts/crew.gd")
var wait_reason := ""
var route_t := 0.0
var _rail_node: Node2D = null   # 工业剖面: the rail, drawn once


func _init() -> void:
	z_index = 6
	z_as_relative = false


# the rail along the top of the berth (px)
static func rail_y() -> float:
	return (Dock.BOUNDS.position.y + 1.4) * Geom.M


func home() -> Vector2:
	return Vector2(2.0 * Geom.M, LIFT_Y * Geom.M)


func can_take(b) -> bool:
	return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty() and b.total_mass() <= Methods.crane_t() and game.tools.held_body != b and not b.get_meta("arm", false) and not Crew.owns(b) and not LoadMotion.tied_skip(b)


# the mark key on a load too heavy for the haulers
func toggle(b) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	if queue.has(b):
		queue.erase(b)
		return "crane_unmarked"
	if b.total_mass() > Methods.crane_t():
		return "crane_heavy"
	if _zone_for(b) == "":
		return "hauler_no_mouth"
	queue.append(b)
	return "crane_marked"


func _zone_for(b) -> String:
	var planned: String = str(b.get_meta("plan_zone", ""))
	if planned in ["metal", "equip", "hazard"]:
		return Dock.for_load(planned, b)
	if b.pieces.any(func(p): return game.sys.dest_of(p) == "anti") and Dock.ZONES.has("anti"):
		return "anti"
	var k := "equip"
	# 认真拆有奖励: harmless leftovers go to the equipment mouth's drain rack
	var drainable: bool = game.clean != null and game.clean.active() and game.clean.body_residual(b) != ""
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard" and not drainable:
			k = "hazard"
	if k != "hazard" and game.dock.is_scrap(b):
		k = "metal"
	return Dock.for_load(k, b)


# just off the mouth's lip, inside its catch: the mouth takes it from the hook
func _drop_point(z: String) -> Vector2:
	return Dock.zpos(z) + Dock.ZONES[z].face * 0.4 * Geom.M


func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		return
	t += dt
	game.nav_grid().step(dt)
	if pos == Vector2.ZERO:
		pos = home()
	for b in queue.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			queue.erase(b)
	if game.auto_paused:
		if body != null:
			halt()
		pos = pos.move_toward(home(), EMPTY * dt)
		return
	if is_instance_valid(body) and game.tools.held_body == body:
		# 106 号: the operator took it: it is theirs now, the crane leaves it alone unless marked
		body.set_meta("crane_skip", true)
		halt()
		return
	if state in ["carry","release"] and is_instance_valid(body) and body.capture == null:
		pos = body.global_position-off
	if state in ["reach", "carry"] and game.keepout_blocks(pos, _heading()):
		return
	var k := 1.0
	if state in ["reach", "carry"] and game.drone_near(pos, CLEAR, _heading()):
		wait_t += dt
		if wait_t < 1.0:
			return
		k = 0.4
	else:
		wait_t = 0.0
	dt *= k
	# 106 号: a piece taken unasked that cannot be got out is put down again and left for the
	# operator, so the crane is not held up by it
	if is_instance_valid(body) and body.get_meta("crane_auto", false) and wait_reason in ["load_no_route", "load_obstructed", "load_pickup_blocked"]:
		stuck_t += dt
		if stuck_t > STUCK_S:
			stuck_t = 0.0
			body.set_meta("crane_skip", true)
			halt()
			return
	else:
		stuck_t = 0.0
	match state:
		"idle":
			for b in queue:
				if can_take(b):
					body = b
					queue.erase(b)
					body.set_meta("arm", true)
					body.set_meta("arm_by", "crane")
					game.ops["crane_lift"] = int(game.ops.get("crane_lift", 0)) + 1
					path = _overhead(pos, body.global_transform * body.center_of_mass)
					state = "reach"
					break
			if state == "idle" and queue.is_empty():
				# 106 号 (Q1 C): a cut-loose piece the drone cannot pull and the crane can lift is
				# taken by itself, once it has come to rest
				auto_t -= dt
				if auto_t <= 0.0:
					auto_t = 0.5
					var pick = auto_pick()
					if pick != null:
						pick.set_meta("crane_auto", true)
						queue.append(pick)
			if state == "idle":
				pos = pos.move_toward(home(), EMPTY * dt)
		"reach":
			if not is_instance_valid(body) or body.capture != null or game.tools.held_body == body:
				_done()
				return
			# the load may have drifted: the last leg follows it
			var target: Vector2 = body.global_transform * body.center_of_mass
			if path.size() <= 1:
				path = [target]
			pos = pos.move_toward(path[0], EMPTY * dt)
			if pos.distance_to(path[0]) < 3.0:
				path.pop_front()
			if path.is_empty() and pos.distance_to(target) < 6.0:
				if not LoadMotion.grip(body):
					wait_reason = "load_pickup_blocked"
					return
				wait_reason = ""
				off = body.global_position - pos
				zone = _zone_for(body)
				path.clear()
				route_t = 0.0
				state = "carry"
				game.sfx.play("grab", pos, 0.7)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
				return
			LoadMotion.line_up(body, zone, 0.6, dt)
			var drop := _drop_point(zone)
			if Dock.kind(zone) == "equip": drop = LoadMotion.intake_point(body, zone, pos)
			# user 2026-11-08: the load passes through whatever is in the way (LoadMotion.grip): no
			# route to plan, nothing to wait for but the mouth. Up to the carrying height, along, down
			# (the last point follows the mouth's intake point as the load is turned).
			if path.is_empty(): path = _overhead(pos, drop)
			path[path.size() - 1] = drop
			while path.size() > 1 and pos.distance_to(path[0]) < 2.0: path.pop_front()
			wait_reason = ""
			if pos.distance_to(drop) < 2.0:
				state = "release"
				hold_t = 0.0
				return
			if path.size() == 1 and not game.mouth_take(zone, "crane"):
				return
			var next: Vector2 = pos.move_toward(path[0], SPEED * dt)
			# the hook goes only where the load goes (a cable to the ship holds both: 公测 bug #8)
			if LoadMotion.move(body, next-pos):
				pos = next
			elif LoadMotion.tied_long(body):
				queue.erase(body)
				LoadMotion.give_up_tied(game, body, pos)
				_done()
				return
		"release":
			hold_t += dt
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
			elif hold_t > 0.4:
				LoadMotion.let_go(body)
				body.linear_velocity = Dock.ZONES[zone].face * -50.0
				body.set_meta("arm", false)
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_done()


# to the carrying height, along, and straight to the point
var auto_t := 0.0
var stuck_t := 0.0
const STUCK_S := 8.0             # s a piece taken unasked may hold the crane up before it is put down
const AUTO_AGE := 0.8            # s a piece has been loose before the crane comes for it
const AUTO_V := 0.6              # m/s: and no faster than this


# the loose piece the crane takes unasked, nearest first; null for none
func auto_pick():
	# hauling set to marks only (Shift+J, 公测 bug #8): the crane takes only what is marked
	if game.haul_manual():
		return null
	if game.manual_only() or game.training or game.exam != null:
		return null
	# 2026-11-11 (user: every loose body to its mouth with the machines on): with hauling drones in the
	# berth, whatever they cannot lift (over 1.5 t) is the crane's — not only what the grapple cannot pull
	var lim: float = Hauler.MAX_T if not game.haulers().is_empty() else game.grab_max()
	var taken := {}
	for h in game.haulers():
		for b in h.queue:
			taken[b] = true
		if h.body != null:
			taken[h.body] = true
	var best = null
	var bd := INF
	for b in game.world.bodies:
		if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty() or taken.has(b) or game.tools.held_body == b:
			continue
		if b.get_meta("arm", false) or b.get_meta("arm_extraction", false) or b.get_meta("manual_mark", false) or b.get_meta("crane_skip", false) or Crew.owns(b) or LoadMotion.tied_skip(b):
			continue
		var m: float = b.total_mass()
		if m <= lim + 0.001 or m > Methods.crane_t() or b.age < AUTO_AGE or b.linear_velocity.length() > AUTO_V * Geom.M:
			continue
		if _zone_for(b) == "":
			continue
		var d := pos.distance_to(b.global_position)
		if d < bd:
			bd = d
			best = b
	return best


func _overhead(from: Vector2, to: Vector2) -> Array:
	var y := LIFT_Y * Geom.M
	return [Vector2(from.x, y), Vector2(to.x, y), to]


func _heading() -> Vector2:
	return path[0] if not path.is_empty() else pos


func halt() -> void:
	if body != null and is_instance_valid(body):
		if state in ["carry", "release"]:
			LoadMotion.let_go(body)
			body.linear_velocity = Vector2.ZERO
		body.set_meta("arm", false)
	_done()


func _done() -> void:
	wait_reason = ""
	game.mouth_release(zone, "crane")
	if body != null and is_instance_valid(body) and state == "reach":
		body.set_meta("arm", false)
	body = null
	path = []
	state = "idle"


var art := MechArt.new()          # 91 号: the trolley's swing, wheels and beacon


func _process(dt: float) -> void:
	art.step(pos, dt)
	if art.hard_stop() and game != null and Txt.anim_level() >= 2:
		for s in [-1.0, 1.0]:
			game.fx.puff(Vector2(pos.x + art.x + s * 20.0, rail_y() - 3.0), Vector2(s * 30.0, -10.0), 0.9, 3.0, 16.0, Pal.ink(0.1))
	queue_redraw()


func _draw() -> void:
	var ry := rail_y()
	var x0 := (Dock.BOUNDS.position.x + 0.6) * Geom.M
	var x1 := (Dock.FLOOR_X1 - 0.6) * Geom.M
	# the rail
	# 工业剖面: the rail never moves — a child node draws it once (60 FPS: drawn here each frame it
	# cost ARK-01's long berth ~20 ms); redrawn only when the berth's span changes
	if _rail_node == null:
		_rail_node = Node2D.new()
		_rail_node.show_behind_parent = true
		_rail_node.draw.connect(func() -> void:
			var k: Array = _rail_node.get_meta("k")
			Cutaway.crane_rail(_rail_node, k[0], k[1], k[2]))
		add_child(_rail_node)
	# far out (the whole ship on screen) the stiffeners and rivets are under a pixel and cost ARK-01's
	# long berth ~8 ms of render a frame: the rail as two flat bands there
	var far: bool = game != null and game.cam_zoom() < 0.3
	_rail_node.visible = Pal.solid and not far and not Cutaway.skip.has("crane")
	if Pal.solid and far:
		draw_rect(Rect2(x0, ry - 4.0, x1 - x0, 6.0), Color(0.36, 0.37, 0.4))
		draw_rect(Rect2(x0, ry + 2.0, x1 - x0, 17.0), Color(0.12, 0.125, 0.138))
	elif Pal.solid:
		var key := [x0, x1, ry]
		if _rail_node.get_meta("k", []) != key:
			_rail_node.set_meta("k", key)
			_rail_node.queue_redraw()
	else:
		draw_line(Vector2(x0, ry), Vector2(x1, ry), Pal.ink(0.5), 3.0)
		draw_line(Vector2(x0, ry + 6.0), Vector2(x1, ry + 6.0), Pal.ink(0.22), 1.0)
		var x := x0
		while x < x1:
			draw_line(Vector2(x, ry), Vector2(x + 10.0, ry + 6.0), Pal.ink(0.18), 1.0)
			x += 26.0
	# marks on the queued loads
	for i in queue.size():
		var b = queue[i]
		if not is_instance_valid(b):
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		var s := 12.0 + 2.0 * sin(t * 4.0 + i)
		draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Pal.tint(Pal.AIR, 0.85, 1.3), false, 1.6)
		draw_string(Fonts.get_font("Medium"), c + Vector2(s + 4, 4), ("C%d" % (i + 1)) + (Ops.w(" 吊车自动", " CRANE") if b.get_meta("crane_auto", false) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.9, 1.2))
	# the trolley, the cable, the hook
	# 91 号: the trolley rides a little ahead of or behind the hook as the load swings
	var tr := Vector2(pos.x + art.x, ry)
	MechArt.cable_and_hook(self, tr + Vector2(-4, 38.0 if Pal.solid else 12.0), pos, 4, state in ["carry", "release"])
	if Pal.solid:
		Cutaway.trolley(self, tr, 56.0, state != "idle", t, art.wheel)
	else:
		art.trolley(self, tr, 56.0, state != "idle", t)
	if wait_reason != "":
		draw_string(Fonts.get_font("Medium"), pos + Vector2(18, 28), LoadMotion.wait_line(body,wait_reason), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.heat(0.95, 1.2))
	if body != null and is_instance_valid(body) and state in ["carry", "release"]:
		draw_line(pos, body.global_transform * body.center_of_mass, Pal.tint(Pal.AIR, 0.45, 1.2), 1.2, true)
