class_name RecoveryArm
extends Node2D
const Crew = preload("res://scripts/crew.gd")
# The industrial recovery arm (berth upgrade, basic grade): a trolley on the
# boom with a claw on a cable. It only ever takes loose scrap — a drifting
# body of metal up to 1 t with no whole equipment in it, that the grapple is
# not holding — carries it slowly round the ship to the furnace and lets go
# over the mouth. It never touches equipment.
# It waits its turn over the furnace mouth (the hauler may be dropping there),
# holds back for the operator's drone in its way (then edges past slowly), and the
# automation key stops it: what it holds is let go where it is.

const MAX_T := 1.0               # t it can lift
const SPEED := 4.0 * 48.0        # px/s with a load
const EMPTY := 9.0 * 48.0        # px/s back to the next one
var RAIL_Y: float:              # the boom it runs on (a tall ship's berth lifts it)
	get: return Dock.RAIL_Y * 48.0
const CLEAR := 2.5 * 48.0        # px it keeps from the operator's drone

var game: Game
var body = null                  # what it is carrying
var path: Array = []             # waypoints still to go (px)
var claw := Vector2.ZERO
var state := "idle"              # idle reach carry release
var hold_t := 0.0
var off := Vector2.ZERO          # the body's position relative to the claw
var carried := 0                 # bodies delivered this contract
var t := 0.0
var wait_t := 0.0               # s spent holding back for the drone
var queue: Array = []           # explicitly authorized plan loads
var zone := "metal"

func enqueue(b, destination: String, rated_t: float) -> bool:
	if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty() or b.total_mass() > rated_t or game.tools.held_body == b: return false
	b.set_meta("arm_rated_t",rated_t)
	b.set_meta("plan_zone",destination)
	if _zone_for(b) == "":
		b.remove_meta("plan_zone")
		return false
	b.set_meta("arm_receiver",_zone_for(b))
	if body != b and not queue.has(b): queue.append(b)
	return true

func _zone_for(b) -> String:
	var planned: String = str(b.get_meta("plan_zone",""))
	if planned in ["equip","metal","hazard"]: return Dock.for_load(planned,b,false)
	# 认真拆有奖励: harmless leftovers go to the equipment mouth's drain rack
	if game.clean != null and game.clean.active() and game.clean.body_residual(b) != "":
		return Dock.for_load("equip",b,false)
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard": return "hazard"
	return Dock.for_load("metal" if game.dock.is_scrap(b) else "equip",b,false)


# where it waits: over the berth, a little short of the furnace
func home() -> Vector2:
	return Vector2((Dock.metal_home - 3.0) * 48.0, Dock.RAIL_Y * 48.0 + 40.0)


func _init() -> void:
	z_index = 4
	z_as_relative = false


# can the arm take this body?
func takes(b) -> bool:
	if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty():
		return false
	var assigned: bool = b.get_meta("arm_extraction",false) and queue.has(b)
	if b.total_mass() > float(b.get_meta("arm_rated_t",MAX_T) if assigned else MAX_T): return false
	if game.tools.held_body == b or b.get_meta("arm", false) or Crew.owns(b):
		return false
	# just let go over the mouth: give the mouth a moment
	if t - float(b.get_meta("arm_drop", -99.0)) < 5.0:
		return false
	if assigned: return true
	if b.get_meta("arm_parked",false): return false
	if game.plan != null and game.plan.reserves_body(b): return false
	for p in b.pieces:
		if (p.cls == "equip" and p.intact) or game.sys.dest_of(p) == "hazard":
			return false
	return true


func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		return
	t += dt
	if claw == Vector2.ZERO:
		claw = home()
	if game.auto_paused:
		if body != null:
			halt()
		claw = claw.move_toward(home(), EMPTY * dt)
		return
	if is_instance_valid(body) and game.tools.held_body == body:
		halt()
		return
	# never into a keep-out zone
	if state in ["reach", "carry"] and game.keepout_blocks(claw, _heading()):
		return
	# keep clear of the drone: wait for it to move on, then edge past slowly
	var k := 1.0
	if state in ["reach", "carry"] and game.drone_near(claw, CLEAR, _heading()):
		wait_t += dt
		if wait_t < 1.0:
			return
		k = 0.4
	else:
		wait_t = 0.0
	dt *= k
	match state:
		"idle":
			for b in queue.duplicate():
				if not is_instance_valid(b) or b.capture != null: queue.erase(b)
			var candidates: Array = queue.duplicate()
			if candidates.is_empty(): candidates = game.world.bodies.duplicate()
			for b in candidates:
				if takes(b):
					body = b
					zone = _zone_for(b)
					queue.erase(b)
					body.set_meta("arm", true)
					body.set_meta("arm_by", "arm")
					state = "reach"
					break
			if state == "idle":
				claw = claw.move_toward(home(), EMPTY * dt)
		"reach":
			if not is_instance_valid(body) or body.capture != null:
				_drop_it()
				return
			var target: Vector2 = body.global_transform * body.center_of_mass
			claw = claw.move_toward(target, EMPTY * dt)
			if claw.distance_to(target) < 4.0:
				# the claw closes: the body is the arm's now, out of the physics
				body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				body.set_deferred("freeze", true)
				body.hold_begin()   # FreeBody: the one way into every hold
				body.remove_meta("arm_parked")
				body.set_meta("arm_receiver",zone)
				off = body.global_position - claw
				path = _route(claw)
				state = "carry"
				game.sfx.play("grab", claw, 0.5)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				# the mouth took it out of the claw on the way down: delivered all the same
				carried += 1
				_drop_it()
				return
			if path.is_empty():
				state = "release"
				hold_t = 0.0
				return
			# the last leg is over the mouth: only once nothing else is dropping there
			if path.size() == 1 and not game.mouth_take(zone, "arm"):
				return
			claw = claw.move_toward(path[0], SPEED * dt)
			if claw.distance_to(path[0]) < 2.0:
				path.pop_front()
			body.global_position = claw + off
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
		"release":
			hold_t += dt
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_drop_it()
			elif hold_t > 0.3:
				# let go over the mouth: physics back on, a nudge down, the mouth does the rest
				body.set_deferred("freeze", false)
				body.linear_velocity = -Dock.ZONES[zone].face*80.0
				body.hold_end()     # overlapping something it stays untouchable until clear
				# (the drop point follows a furnace mouth moved along its rail)
				body.set_meta("arm", false)
				body.remove_meta("arm_by")
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_drop_it()


# 2026-11-10 (user: "无人机明明能捡的，还在那傻站了"): the one body the arm, idle, will reach for next
# (the haulers leave only that one to it; once it is after a body its claim, "arm", keeps it).
# Worked out once a physics frame.
# (kept as an instance id: a held reference to a body freed later crashed the engine on quit)
var _pick_frame := -1
var _pick_id := 0
func next_pick():
	var f := Engine.get_physics_frames()
	if f != _pick_frame:
		_pick_frame = f
		_pick_id = 0
		if state == "idle" and body == null and not game.auto_paused:
			var candidates: Array = []
			for q in queue:
				if is_instance_valid(q) and q.capture == null:
					candidates.append(q)
			if candidates.is_empty(): candidates = game.world.bodies
			for b in candidates:
				if takes(b):
					_pick_id = b.get_instance_id()
					break
	if _pick_id == 0:
		return null
	var o := instance_from_id(_pick_id)
	return o if is_instance_valid(o) else null


# where it is making for now
func _heading() -> Vector2:
	if state == "carry" and not path.is_empty():
		return path[0]
	if state == "reach" and is_instance_valid(body):
		return body.global_transform * body.center_of_mass
	return claw


# let go of what it holds, where it is, and stand by
func halt() -> void:
	if body != null and is_instance_valid(body) and body.capture == null and state in ["carry", "release"]:
		body.set_deferred("freeze", false)
		body.linear_velocity = Vector2.ZERO
		body.hold_end()
	if body != null and is_instance_valid(body):
		body.set_meta("arm", false)
		body.remove_meta("arm_by")
		body.remove_meta("arm_receiver")
	_drop_it()


func _drop_it() -> void:
	game.mouth_release(zone, "arm")
	if is_instance_valid(body):
		body.set_meta("arm",false)
		body.remove_meta("arm_by")
		if body.capture != null or not body.get_meta("arm_extraction",false): body.remove_meta("arm_receiver")
	body = null
	path = []
	state = "idle"


# round the ship's nearer end while it still stands between the load and the furnace
func _route(from: Vector2) -> Array:
	# User explicitly authorized clipping extraction (2026-10-22). The claw
	# carries the actual load continuously through obstructions, not a deletion
	# or a synthetic receipt. Unassigned scrap retains its existing route.
	if is_instance_valid(body) and body.get_meta("arm_extraction",false):
		return [Dock.zpos(zone)+Dock.ZONES[zone].face*0.4*Geom.M]
	var bb := Rect2()
	var first := true
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var pb := Geom.bbox(p.poly)
		bb = pb if first else bb.merge(pb)
		first = false
	var drop := Dock.zpos("metal") + Vector2(0, -0.8 * Geom.M)
	if first:
		return [drop]
	bb = bb.grow(40.0)
	if not bb.has_point(from) and not _crosses(from, drop, bb):
		return [drop]
	var x: float = bb.end.x + 30.0 if absf(from.x - bb.end.x) < absf(from.x - bb.position.x) else bb.position.x - 30.0
	var y: float = from.y if not bb.has_point(from) else bb.position.y - 30.0
	return [Vector2(from.x, y), Vector2(x, y), Vector2(x, drop.y), drop]


func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


var art := MechArt.new()          # 91 号: the trolley's swing, wheels and beacon


func _process(dt: float) -> void:
	art.step(claw, dt)
	queue_redraw()


func _draw() -> void:
	# the trolley on the boom, the cable, the claw
	var tx := clampf(claw.x, -6.0 * 48.0, (Dock.ARM_X1 - 0.5) * 48.0)
	var swing := art.x if absf(claw.x - tx) < 2.0 else 0.0
	var trolley := Vector2(tx + swing, RAIL_Y)
	var mid := Vector2(claw.x, trolley.y) if absf(claw.x - tx) > 2.0 else trolley
	if mid != trolley:
		draw_line(trolley + Vector2(0, 8), mid + Vector2(0, 8), Pal.ink(0.45), 1.4, true)
	MechArt.cable_and_hook(self, mid + Vector2(0, 10), claw + Vector2(0, 14), 2, state in ["carry", "release"], 1.0, false)
	art.trolley(self, trolley + Vector2(0, -8), 44.0, state != "idle", t)
	var open := 0.4 if state in ["idle", "reach"] else 0.1
	for s in [-1.0, 1.0]:
		var a: Vector2 = Vector2(s * 6.0, 0).rotated(s * open)
		draw_line(claw, claw + a + Vector2(0, 8), Pal.ink(0.85), 2.0, true)
		draw_line(claw + a + Vector2(0, 8), claw + Vector2(s * 3.0, 14), Pal.ink(0.85), 2.0, true)
	draw_circle(claw, 3.0, Pal.heat(0.8 if state == "carry" else 0.3, 1.2))
