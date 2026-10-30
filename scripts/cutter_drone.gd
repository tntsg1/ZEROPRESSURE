extends RigidBody2D
# Physical actuator for G4 cutting. The plan remains responsible for safety
# authorization and material accounting. No material is changed by this node.
const RADIUS := 14.0
const SPEED := 200.0
const ACCEL := 540.0
const TOOL_REACH := 120.0
const SETTLE_SPEED := 5.0
var exact_surface := Vector2.INF   # the exact (unsimplified) surface the station aims at
var exact_inside: Callable = func(_a, _b): return INF   # px of a→b inside the target's exact outline
var game = null
var destination := Vector2.ZERO
var commanded := false
var heading := 0.0
var beam_on := false
var beam_target := Vector2.ZERO
var reason := "idle"
var thrust := Vector2.ZERO
var route := PackedVector2Array()
var route_age := 0.0
var _beam_frame := -1

func _init() -> void:
	mass = 0.45
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | World.STATIC_LAYER
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	z_index = 6
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func move_to(point: Vector2) -> void:
	if not commanded or point.distance_to(destination) > 2.0:
		route.clear()
		route_age = 2.0
	destination = point
	commanded = true
	beam_on = false
	reason = "travelling"

func stop() -> void:
	commanded = false
	beam_on = false
	route.clear()
	reason = "stopped"

func settled_at(point: Vector2) -> bool:
	return global_position.distance_to(point) <= 3.0 and linear_velocity.length() <= SETTLE_SPEED

func save_state() -> Dictionary:
	return {"position":[global_position.x,global_position.y],"heading":heading}

func load_state(saved: Dictionary) -> void:
	# Restoring the machine's own location is not moving its workpiece. A
	# loaded field always requires new plan authorization before motion/fire.
	stop()
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	var at: Array = saved.get("position",[])
	if at.size() == 2:
		var restored := Vector2(float(at[0]),float(at[1]))
		if restored.is_finite(): global_position = restored
	var angle := float(saved.get("heading",0.0))
	heading = angle if is_finite(angle) else 0.0

func muzzle() -> Vector2:
	return global_position + Vector2.from_angle(heading) * (RADIUS + 3.0)

# Only actual collision shapes belonging to the authorized target may intercept
# the tool ray. Attached ship polygons share one StaticBody2D, so allowing the
# entire collider would incorrectly allow every wall on the ship.
func beam_clear(point: Vector2, target_shapes: Array) -> bool:
	if not is_inside_tree() or target_shapes.is_empty(): return false
	return beam_clear_from(global_position,point,target_shapes)

func beam_clear_from(origin: Vector2, point: Vector2, target_shapes: Array) -> bool:
	if origin.distance_to(point) > TOOL_REACH: return false
	var start := origin+origin.direction_to(point)*(RADIUS+3.0)
	# Include the surface itself despite subpixel ray endpoint rounding. This
	# extends the query by 0.25 px, not the authorized kerf or tool reach.
	var ray := PhysicsRayQueryParameters2D.create(start,point+origin.direction_to(point)*0.25,collision_mask,[get_rid()])
	ray.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		# a sliver under the collision outline's simplification: the station checked the exact
		# surface; nothing stands between the beam and it
		return exact_surface.is_finite() and point.distance_to(exact_surface) <= World.KERF + 1.0 and float(exact_inside.call(origin, exact_surface)) <= World.KERF + 1.0
	var collider: CollisionObject2D = hit.collider
	var owner_id: int = collider.shape_find_owner(int(hit.shape))
	if not target_shapes.has(collider.shape_owner_get_owner(owner_id)):
		# a neighbour butted against the target at the kerf: the seam the station sighted
		return exact_surface.is_finite() and point.distance_to(exact_surface) <= World.KERF + 1.0 and (hit.position as Vector2).distance_to(exact_surface) <= World.KERF + 2.0
	# Authorization for a plate does not permit firing through its nearer
	# surface at a distant part of the same polygon.
	return (hit.position as Vector2).distance_to(point) <= World.KERF + 1.0

# Must be called after the plan's safety authorization on every physics step.
# It never sets a persistent permission to fire on later, unchecked steps.
func aim_tool(point: Vector2, target_shapes: Array) -> bool:
	beam_on = false
	if not commanded:
		reason = "stopped"
		return false
	if game != null and (game.state != "play" or game.paused_sim or game.auto_paused):
		reason = "paused"
		return false
	heading = (point-global_position).angle()
	beam_target = point
	if linear_velocity.length() > SETTLE_SPEED:
		reason = "stabilizing"
		return false
	if not beam_clear(point,target_shapes):
		reason = "tool_blocked"
		return false
	beam_on = true
	_beam_frame = Engine.get_physics_frames()
	reason = "cutting"
	queue_redraw()
	return true

func _physics_process(dt: float) -> void:
	# Authorization expires each step; the executor must explicitly renew it.
	if _beam_frame != Engine.get_physics_frames(): beam_on = false
	var desired := Vector2.ZERO
	if game != null and (game.state != "play" or game.paused_sim or game.auto_paused):
		reason = "paused"
	elif commanded:
		var delta := destination-global_position
		var waypoint := destination
		route_age += dt
		if test_move(global_transform,delta):
			if game != null and route_age >= 1.0:
				route_age = 0.0
				route = game.nav_grid().payload_path(global_position,destination,Vector2.ONE*RADIUS,self)
			while route.size() > 0 and global_position.distance_to(route[0]) < 5.0:
				route.remove_at(0)
			if route.is_empty():
				reason = "route_blocked"
				waypoint = global_position
			else:
				waypoint = route[0]
		var offset := waypoint-global_position
		# Braking distance limits requested speed; force stays finite and contact
		# resolution belongs to the physics engine, never a position assignment.
		var speed := minf(SPEED,minf(offset.length()*4.0,sqrt(2.0*ACCEL*maxf(offset.length()-1.0,0.0))))
		desired = offset.normalized()*speed
		if settled_at(destination): reason = "ready"
		if offset.length() > 4.0: heading = offset.angle()
	thrust = ((desired-linear_velocity)*8.0).limit_length(ACCEL)
	apply_central_force(thrust*mass)
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.68,0.82,0.87)
	draw_arc(Vector2.ZERO,RADIUS,0,TAU,24,ink,1.2,true)
	draw_rect(Rect2(-8,-8,16,16),ink,false,1.0)
	var direction := Vector2.from_angle(heading)
	draw_line(direction*8.0,direction*(RADIUS+5.0),Color(1.0,0.44,0.18),3.0,true)
	for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var intensity := maxf(0.0,thrust.dot(axis)/ACCEL)
		if intensity > 0.02:
			draw_line(-axis*RADIUS,-axis*(RADIUS+4.0+intensity*10.0),Color(0.38,0.73,0.9),2.0,true)
	if beam_on:
		draw_line(to_local(muzzle()),to_local(beam_target),Color(1.0,0.35,0.12),2.0,true)
