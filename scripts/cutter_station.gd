extends Node2D
# One physical cutter serves all authorized packages. The plan owns safety and
# kerf progress. This service never cuts material or moves cargo itself.
const Robot = preload("res://scripts/cutter_drone.gd")
var game
var robot
var executor = null
var berth := Vector2.ZERO
var station := Vector2.INF
var reason := "idle"
var search_t := 0.0
var blocked_t := 0.0
var _target = null           # the piece being cut now (its surface is what the beam must see)
var _bad_stations: Array = []  # work positions the robot settled at but could not fire from
var _bad_at := Vector2.INF     # the kerf point those were for

func _trace() -> bool:
	return get_meta("trace",false) or OS.get_environment("ZP_CUTTER_TRACE") != ""

func setup(g) -> void:
	game = g
	berth = Dock.BAY*Geom.M+Vector2(38,-44)
	robot = Robot.new()
	robot.game = game
	add_child(robot)
	robot.global_position = berth

func release(who) -> void:
	if executor != who: return
	executor = null
	station = Vector2.INF
	blocked_t = 0.0
	robot.stop()
	reason = "stopped"

func save_state() -> Dictionary:
	return robot.save_state()

func load_state(saved: Dictionary) -> void:
	executor = null
	station = Vector2.INF
	robot.load_state(saved)

func shapes(p) -> Array:
	if p.body != null: return []
	return game.world.static_cols.get(p.id,[])

func contact(p,at: Vector2,kerf: float) -> Vector2:
	var poly: PackedVector2Array = game.world.world_poly(p)
	var best := Vector2.INF
	var distance := INF
	for k in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(at,poly[k],poly[(k+1)%poly.size()])
		var d := q.distance_to(at)
		if d < distance:
			distance = d
			best = q
	# The kerf's real footprint may touch a surface just outside its center.
	# A deeper point needs the preceding material removed first.
	return best if distance <= kerf+1.0 else Vector2.INF

func _open(at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = robot.get_child(0).shape
	query.transform = Transform2D(0,at)
	query.collision_mask = robot.collision_mask
	query.exclude = [robot.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _contact_from(origin: Vector2, at: Vector2, kerf: float, targets: Array) -> Vector2:
	# 2026-10-25 (G4 replay stuck at AF-H, p17): a stroke may start in a notch, a little off the
	# material. Sight the kerf point itself first, then the nearest real surface; either will do.
	var surface_at := Vector2.INF
	if _target != null:
		surface_at = contact(_target, at, kerf)
	var first := _sight(origin, at, at, surface_at, kerf, targets)
	if first.is_finite() or not surface_at.is_finite(): return first
	return _sight(origin, surface_at, at, surface_at, kerf, targets)

# how much of the segment a→b runs inside the target's exact outline (px)
func _inside_exact(a: Vector2, b: Vector2) -> float:
	if _target == null: return INF
	var poly: PackedVector2Array = game.world.world_poly(_target)
	var total := 0.0
	for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
		for k in range(1, seg.size()): total += seg[k-1].distance_to(seg[k])
	return total

# one sight line toward aim: the target's surface near the kerf point, or INF
func _sight(origin: Vector2, aim: Vector2, at: Vector2, surface_at: Vector2, kerf: float, targets: Array) -> Vector2:
	var direction := origin.direction_to(aim)
	var ray := PhysicsRayQueryParameters2D.create(origin+direction*(Robot.RADIUS+3.0),aim+direction*(kerf+2.0),robot.collision_mask,[robot.get_rid()])
	ray.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		# The collision outline is simplified (World.rebuild_cols, 1.4 px): a last sliver of a
		# kerf can be real material with no collision under it. A clear sight line all the way
		# to the exact surface is then a clear sight line to that material.
		# A ray down an open kerf slit also hits nothing: the exact outline must not stand in the way.
		if aim == surface_at and surface_at.is_finite() and origin.distance_to(surface_at) <= Robot.TOOL_REACH and _inside_exact(origin, surface_at) <= kerf+1.0:
			return surface_at
		return Vector2.INF
	var collider: CollisionObject2D = hit.collider
	var shape_owner: int = collider.shape_find_owner(int(hit.shape))
	var surface: Vector2 = hit.position
	if not targets.has(collider.shape_owner_get_owner(shape_owner)):
		# A neighbour butted against the target at the kerf is the seam itself, not a wall in the
		# way (p22 against PUSH): the beam reaches the target's surface there. Only the target is
		# cut. Anything farther than the kerf from it still blocks.
		if surface_at.is_finite() and surface.distance_to(surface_at) <= kerf+2.0 and surface.distance_to(at) <= kerf+2.0:
			return surface_at
		return Vector2.INF
	var near: bool = surface.distance_to(at) <= kerf+1.0 or (surface_at.is_finite() and surface.distance_to(surface_at) <= kerf+2.0)
	return surface if near else Vector2.INF

# 2026-10-25: a work position counts only if the robot's own beam check passes from it too (the
# station's sight and the beam rule disagreed at seams and slits, and the robot sat forever)
func _fires_from(origin: Vector2, p, at: Vector2, kerf: float, targets: Array) -> bool:
	var pt := _contact_from(origin,at,kerf,targets)
	if not pt.is_finite(): return false
	robot.exact_surface = contact(p,at,kerf)
	robot.exact_inside = _inside_exact
	return robot.beam_clear_from(origin,pt,targets)

# can the robot fly there from where it is (the berth's payload grid, its own size)
func _reachable(point: Vector2) -> bool:
	if robot.global_position.distance_to(point) < 6.0 or not robot.test_move(robot.global_transform, point - robot.global_position):
		return true
	return game.nav_grid().payload_path(robot.global_position, point, Vector2.ONE*Robot.RADIUS, robot).size() > 0


func _bad(candidate: Vector2) -> bool:
	for b in _bad_stations:
		if candidate.distance_to(b) < 6.0: return true
	return false

func prepare(who, p, at: Vector2, kerf: float, dt: float) -> bool:
	if executor != null and executor != who and is_instance_valid(executor) and executor.running:
		reason = "busy"
		return false
	if executor != who:
		executor = who
		station = Vector2.INF
		search_t = 0.0
	robot.beam_on = false
	_target = p
	if not _bad_at.is_finite() or _bad_at.distance_to(at) > kerf*2.0:
		_bad_stations.clear()
		_bad_at = at
	var point := contact(p,at,kerf)
	if not point.is_finite():
		reason = "tool_blocked"
		return false
	var targets := shapes(p)
	search_t -= dt
	if _trace() and Engine.get_physics_frames() % 120 == 0: print("CUTTER PREP frame=",Engine.get_physics_frames()," dt=",dt," search_t=",search_t," station=",station," executor_same=",executor == who)
	if station.is_finite():
		if station.distance_to(at) > Robot.TOOL_REACH-5.0 or not _open(station):
			station = Vector2.INF
			search_t = 0.0
		elif not _fires_from(station,p,at,kerf,targets):
			# A material commit replaces CollisionPolygon2D owners. The physics
			# server sees that replacement on the next step. Hold fire, retain the
			# work position, and recheck; do not charge a new search cooldown for
			# each subpixel of legitimate cutting.
			blocked_t += dt
			if blocked_t < 0.05:
				robot.move_to(station)
				reason = "tool_blocked"
				return false
			station = Vector2.INF
			search_t = 0.0
		else:
			blocked_t = 0.0
	if not station.is_finite() and search_t <= 0.0:
		search_t = 0.75
		# Prefer the current physically reached position if it already works.
		if robot.global_position.distance_to(at) <= Robot.TOOL_REACH-5.0 and not _bad(robot.global_position) and _open(robot.global_position) and _fires_from(robot.global_position,p,at,kerf,targets):
			station = robot.global_position
		else:
			# 2026-10-25: a kerf front inside a notch is seen only down the notch: search finer
			var found: Array = []
			for distance in [32.0,48.0,64.0,80.0,96.0,108.0]:
				for k in 32:
					var candidate: Vector2 = at+Vector2.from_angle(TAU*k/32.0)*distance
					if _bad(candidate) or not _open(candidate) or not _fires_from(candidate,p,at,kerf,targets): continue
					found.append([robot.global_position.distance_squared_to(candidate), candidate])
			found.sort_custom(func(x, y): return x[0] < y[0])
			# 2026-10-27: the nearest spot it could fire from can be in a closed compartment (G4
			# replay: right of BH-AM, under a whole deck): it sat "route blocked" forever. The
			# nearest one the robot can actually fly to, of the closest few (a path search each: few)
			# (2026-11-11 切割宝典: a line opened up in a hold has its clear spots behind a wall of shut
			# ones nearer the robot — the first 8 were all shut on POD's CG-3: then the 16 nearest the work)
			var tryout: Array = found.slice(0, 8)
			if found.size() > 8:
				var rest: Array = found.slice(8)
				rest.sort_custom(func(x, y): return x[1].distance_squared_to(at) < y[1].distance_squared_to(at))
				tryout.append_array(rest.slice(0, 16))
			for f in tryout:
				if _reachable(f[1]):
					station = f[1]
					break
		if _trace(): print("CUTTER SEARCH frame=",Engine.get_physics_frames()," at=",at," kerf=",kerf," station=",station," dt=",dt," current=",robot.global_position," target=",p.key)
	if _trace() and station.is_finite(): print("CUTTER KEEP frame=",Engine.get_physics_frames()," station=",station," robot=",robot.global_position," settled=",robot.settled_at(station)," robot_reason=",robot.reason)
	if not station.is_finite():
		robot.stop()
		reason = "route_blocked"
		return false
	robot.move_to(station)
	if not robot.settled_at(station):
		reason = "travelling"
		return false
	point = _contact_from(robot.global_position,at,kerf,targets)
	robot.exact_surface = contact(p,at,kerf)
	robot.exact_inside = _inside_exact
	if not point.is_finite() or not robot.aim_tool(point,targets):
		reason = robot.reason
		# settled here and still cannot fire: give this spot up and look for another
		if robot.reason == "tool_blocked" or not point.is_finite():
			_bad_stations.append(station)
			station = Vector2.INF
			search_t = 0.0
		return false
	reason = "cutting"
	return true

func _physics_process(_dt: float) -> void:
	if robot == null: return
	if game.state != "play" or game.paused_sim or game.auto_paused:
		# Pause revokes the assignment. On resume the plan must pass all safety
		# checks and explicitly acquire the robot again.
		executor = null
		station = Vector2.INF
		robot.stop()
		robot.freeze = true
		robot.linear_velocity = Vector2.ZERO
	elif robot.freeze:
		robot.freeze = false
	elif executor != null and (not is_instance_valid(executor) or not executor.running):
		release(executor)

func _draw() -> void:
	if robot == null: return
	draw_rect(Rect2(berth-Vector2(22,22),Vector2(44,44)),Color(0.25,0.48,0.56),false,1.0)
