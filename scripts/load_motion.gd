extends RefCounted

# A dispatch berth is shared by physical consignments. Wait for an actual
# empty footprint instead of spawning a second load overlapping the first.
static func clear_spawn(space: PhysicsDirectSpaceState2D, at: Vector2, size: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0,at)
	query.collision_mask = FreeBody.MASK
	query.margin = 1.0
	return space.intersect_shape(query,1).is_empty()
# Shared by carrier machines and receiving bays. Carrying never removes collision
# shapes or masks; every displacement sweeps the complete compound body.
static func bounds(body) -> Rect2:
	var result := Rect2()
	var first := true
	for p in body.pieces:
		if p.gone: continue
		var box := Geom.bbox(body.world.world_poly(p))
		result = box if first else result.merge(box)
		first = false
	return result

static func half_extents(body) -> Vector2:
	var centre: Vector2 = body.global_transform*body.center_of_mass
	var box := bounds(body)
	return Vector2(maxf(absf(box.position.x-centre.x),absf(box.end.x-centre.x)),maxf(absf(box.position.y-centre.y),absf(box.end.y-centre.y)))+Vector2.ONE*2.0

static func move(body, delta: Vector2) -> bool:
	if delta.length_squared() < 0.00001: return true
	var from: Transform2D = body.global_transform
	if body.test_move(from,delta):
		var hit := KinematicCollision2D.new()
		body.test_move(from,delta,hit)
		var collider := hit.get_collider()
		var obstacle := Txt.t("load_structure")
		if collider is FreeBody:
			var names: Array = []
			for p in collider.pieces: names.append(Txt.piece_name(p)+" "+(p.tag if p.tag != "" else p.key))
			obstacle = ", ".join(names)
		elif collider is CollisionObject2D:
			var shape_owner: Object = hit.get_collider_shape()
			for id in body.world.static_cols:
				if body.world.static_cols[id].has(shape_owner):
					var p = body.world.pieces[id]
					obstacle = Txt.piece_name(p)+" "+(p.tag if p.tag != "" else p.key)
					break
		body.set_meta("carrier_obstacle",obstacle)
		body.set_meta("carrier_normal",hit.get_normal())
		return false
	body.remove_meta("carrier_obstacle")
	body.remove_meta("carrier_normal")
	body.global_position += delta
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	return true

static func wait_line(body, reason: String) -> String:
	if reason == "": return ""
	var line := Txt.t(reason)
	if reason == "load_obstructed" and is_instance_valid(body):
		var obstacle: String = str(body.get_meta("carrier_obstacle",""))
		if obstacle != "": line += " · "+obstacle
	return line

static func clear_to(body, delta: Vector2) -> bool:
	return not body.test_move(body.global_transform, delta)

static func grip(body) -> bool:
	# A newly released object may still be separating from authored contacts.
	# Freezing it mid-recovery locks the overlap in place and every later sweep
	# fails, even when the route ahead is open. Keep it dynamic until clear.
	if body.ghost > 0.0: return false
	var contact := KinematicCollision2D.new()
	if body.test_move(body.global_transform,Vector2.ZERO,contact,0.05,true):
		if not body.freeze:
			var normal := contact.get_normal()
			var along: float = body.linear_velocity.dot(normal)
			var acceleration := clampf((40.0-along)*5.0,0.0,150.0)
			body.sleeping = false
			body.apply_central_force(normal*acceleration*minf(body.mass,1.5))
		return false
	body.collision_mask = FreeBody.MASK
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.set_deferred("freeze", true)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	return true

static func span(body, face: Vector2) -> Vector2:
	var tangent := Vector2(-face.y,face.x)
	var low := INF
	var high := -INF
	for p in body.pieces:
		if p.gone: continue
		for q in body.world.world_poly(p):
			var d: float = q.dot(tangent)
			low = minf(low,d)
			high = maxf(high,d)
	return Vector2(low,high)

static func fits(body, width: float, face: Vector2) -> bool:
	var projection := span(body,face)
	return projection.y-projection.x <= width-2.0


# 78 号 P0-1: the narrowest the load can be made across a mouth by turning it, and the turn
# (radians, added to its rotation now) that gives it — its real outline, not its class or mass
const TURN_STEPS := 24
const TURN_SPARE := 0.5       # m: a load that fits a mouth by less than this is turned its narrowest way
static func narrowest(body, face: Vector2) -> Vector2:
	var tangent := Vector2(-face.y, face.x)
	var pts: Array = []
	var c: Vector2 = body.global_transform * body.center_of_mass
	for p in body.pieces:
		if p.gone: continue
		for q in body.world.world_poly(p):
			pts.append(q - c)
	if pts.is_empty():
		return Vector2(0.0, 0.0)
	var best := INF
	var best_turn := 0.0
	for i in TURN_STEPS:
		var a := PI * float(i) / float(TURN_STEPS)
		var low := INF
		var high := -INF
		for q in pts:
			var d: float = (q as Vector2).rotated(a).dot(tangent)
			low = minf(low, d)
			high = maxf(high, d)
		if high - low < best - 0.01:
			best = high - low
			best_turn = a if a <= PI * 0.5 else a - PI
	return Vector2(best, best_turn)


# can the load go into a mouth this wide at all, turned the best way (2 px margin as fits())
static func fits_turned(body, width: float, face: Vector2) -> bool:
	return narrowest(body, face).x <= width - 2.0


# 78 号 P0-1: turn a carried load about its centre of mass, only into free space
static func turn(body, by: float) -> bool:
	if absf(by) < 0.0001: return true
	var from: Transform2D = body.global_transform
	var com: Vector2 = from * body.center_of_mass
	var to: Transform2D = Transform2D(0.0, com) * Transform2D(by, Vector2.ZERO) * Transform2D(0.0, -com) * from
	if body.test_move(to, Vector2.ZERO, null, 0.05): return false
	body.global_transform = to
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	return true


# 78 号 P0-1: where a carrier's grip has to be for the load to sit centred across an
# equipment mouth with its leading surface 0.4 m short of the lip (the grip point
# itself at the lip pushed a tall load's far half into the rack's frame: no route)
static func intake_point(body, zone: String, grip_at: Vector2) -> Vector2:
	var zp: Vector2 = Dock.zpos(zone)
	var face: Vector2 = Dock.ZONES[zone].face
	var com: Vector2 = body.global_transform * body.center_of_mass
	var lead := 0.0
	for p in body.pieces:
		if p.gone: continue
		for q in body.world.world_poly(p):
			lead = maxf(lead, (com - q).dot(face))
	return zp + face * (lead + 0.4 * Geom.M) + (grip_at - com)


# 78 号 P0-1: on the way to an equipment mouth, swing the load toward its narrowest
# pose across it when it doesn't go in as it is, rate rad/s (false while it still has turning to do)
static func line_up(body, zone: String, rate: float, dt: float) -> bool:
	if Dock.kind(zone) != "equip": return true
	# a load that already goes in as it is, with room to spare, is left as it is
	if fits(body, (Dock.ZONES[zone].w - TURN_SPARE) * Geom.M, Dock.ZONES[zone].face): return true
	var n: Vector2 = narrowest(body, Dock.ZONES[zone].face)
	if absf(n.y) < 0.02: return true
	turn(body, clampf(n.y, -rate * dt, rate * dt))
	return false


# 78 号 P0-1: half_extents() of the load as it will be once turned by `by` about its centre
static func half_extents_turned(body, by: float) -> Vector2:
	var centre: Vector2 = body.global_transform*body.center_of_mass
	var h := Vector2.ZERO
	for p in body.pieces:
		if p.gone: continue
		for q in body.world.world_poly(p):
			var r: Vector2 = (q-centre).rotated(by)
			h = Vector2(maxf(h.x,absf(r.x)),maxf(h.y,absf(r.y)))
	return h+Vector2.ONE*2.0


# the footprint a carrier plans with on its way to a zone: as the load lies, or as it
# will be once line_up() has turned it for an equipment mouth it doesn't go in as it is
static func plan_extents(body, zone: String) -> Vector2:
	if zone == "" or Dock.kind(zone) != "equip" or fits(body, (Dock.ZONES[zone].w-TURN_SPARE)*Geom.M, Dock.ZONES[zone].face):
		return half_extents(body)
	return half_extents_turned(body, narrowest(body, Dock.ZONES[zone].face).y)


# where the load's centre is headed for an equipment mouth, as it will lie on arrival
# (its leading surface 0.4 m short of the lip; the mouths face straight down or left)
static func plan_intake(body, zone: String) -> Vector2:
	var face: Vector2 = Dock.ZONES[zone].face
	var h := plan_extents(body, zone)
	var lead: float = absf(face.x)*h.x+absf(face.y)*h.y
	return Dock.zpos(zone)+face*(lead+0.4*Geom.M)
