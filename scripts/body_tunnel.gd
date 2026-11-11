extends Node
# 2026-11-11 量子隧穿·机体 (user: "再添加一个很贵的更新，就是无人机本身也可以进行量子隧穿，无视其他的东西"):
# the late, dear upgrade after the grapple's tunnelling (Terminal.SHOP "tunnel_body", needs "tunnel").
# On once bought (user 2026-11-11: "升级默认开启"; an old save that has it too — the switch is not saved);
# its own key (U, Keys "tunnel_body") or the key strip's "机体" button switches it; on, the drone touches nothing: hull,
# structure, the berth's facilities, loose pieces. It is still a body with its inertia, its thrust and
# its brake (drone.gd is untouched: only its collision mask changes).
# What it does not pass (the rules of the work stay):
#   - the berth's edge (Dock.bounds_body, also on EDGE_LAYER: its floor, tower and rail — the port's
#     gate in the rail stays open) and the port's own drone-only walls (layer 16): solid as ever;
#   - a room still under pressure (more than Systems.SAFE_KPA): its outline stays solid from outside,
#     with the reason said there — no reaching into an un-vented room to fish things out.
# Switched off inside something: the drone is not shot out; it stays untouchable and is eased, at a
# walking pace with a gentle acceleration, to the nearest open space, then touches again.
# tools.gd owns it (a child); tunnel_fx.gd draws the drone's tunnelling; tests read `state`.

const EASE_V := 90.0          # px/s it is eased out of a wall at, at most
const EASE_A := 240.0         # px/s² and no harder than this
const SEARCH := 12            # rings of 0.5 m searched for open space
const EDGE_LAYER := 128       # Dock.bounds_body is on it too
const KEEP := 16 | EDGE_LAYER # what stays solid to the drone while it tunnels
const SAY_GAP := 1.6          # s between "still under pressure" notes
const WALL := 0.6 * 48.0      # px: a pressurised room is held off this far outside its inside (its wall)

var tools
var on := true                # the switch (on by default: it only acts once fitted)
var state := "off"            # off | on | clearing
var mask0 := -1               # the drone's own collision mask, kept while tunnelling
var drone_id := 0             # the drone it holds the masks of (a new drone starts afresh)
var layer0 := -1              # and its layer (loose pieces look for the drone on it: off it, they don't)
var clear_to := Vector2.INF   # where it is eased to
var ease_v := Vector2.ZERO    # the easing's own speed (the drone's flight assist would brake it away)
var said_t := -9.0
var t := 0.0
var blocked := ""             # the room that held it back last (tests)
var stats := {"held_room": 0, "eased": 0.0}


func _init() -> void:
	# after the drone's own step: its velocity is set, then held back here
	process_physics_priority = 50


func game():
	return tools.game if tools != null else null


func fitted() -> bool:
	var g = game()
	return g != null and g.has_upgrade("tunnel_body")


func active() -> bool:
	return state == "on"


# the drone is drawn as tunnelling (on, or easing out of a wall after)
func showing() -> bool:
	return state != "off"


func toggle() -> void:
	var g = game()
	var d = tools.drone
	var at: Vector2 = d.global_position + Vector2(0, -44) if d != null else Vector2.INF
	if not fitted():
		g.say("qtb_unfitted", at)
		g.sfx.play("deny")
		return
	on = not on
	_apply()
	g.say("qtb_on" if on else "qtb_off", at)
	g.sfx.play("holo", Vector2.INF, 0.8, 0.42 if on else 0.32)
	g.sfx.play("reveal", Vector2.INF, 0.35, 1.5 if on else 1.2)
	g.sfx.play("switch")


func _apply() -> void:
	var d = tools.drone
	if d == null or not is_instance_valid(d):
		return
	if on and fitted():
		if state == "off":
			mask0 = d.collision_mask
			layer0 = d.collision_layer
			drone_id = d.get_instance_id()
		state = "on"
		d.collision_layer = 0
		# only the berth's edge and the port's drone-only walls stay solid
		d.collision_mask = (mask0 & 16) | EDGE_LAYER
		return
	if state == "on":
		state = "clearing"
		clear_to = Vector2.INF
		ease_v = d.linear_velocity.limit_length(EASE_V)


func _physics_process(dt: float) -> void:
	var g = game()
	if g == null or tools.drone == null or not is_instance_valid(tools.drone):
		return
	t += dt
	var d = tools.drone
	# a new drone (a new scene, a relaunch): it has its own masks; start afresh with it
	if state != "off" and d.get_instance_id() != drone_id:
		state = "off"
		mask0 = -1
		layer0 = -1
	# lost (a new drone, a dead one, the upgrade gone): back to its own mask
	if state != "off" and (not d.alive or not fitted()):
		_restore(d)
		return
	if state == "off":
		# on and fitted (bought, a fresh drone, a new scene): it takes hold by itself
		if on and fitted() and d.alive and g.state == "play":
			_apply()
		return
	if g.paused_sim:
		return
	if state == "on":
		_hold_in(g, d, dt)
		return
	# clearing: eased out to open space, then it touches again
	if _free_at(d, d.global_position):
		_restore(d)
		return
	if clear_to == Vector2.INF or not _free_at(d, clear_to):
		clear_to = _nearest_free(d)
	if clear_to == Vector2.INF:
		return
	var to: Vector2 = clear_to - d.global_position
	var want: Vector2 = to.normalized() * minf(EASE_V, to.length() * 3.0)
	ease_v = ease_v.move_toward(want, EASE_A * dt)
	d.linear_velocity = ease_v
	stats.eased += dt


func _restore(d) -> void:
	if mask0 >= 0:
		d.collision_mask = mask0
	if layer0 >= 0:
		d.collision_layer = layer0
	mask0 = -1
	layer0 = -1
	state = "off"
	clear_to = Vector2.INF


# what the drone's own mask would touch at p (the gallery's walls aside, those it never passes)
func _free_at(d, p: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := CircleShape2D.new()
	sh.radius = Drone.R
	q.shape = sh
	q.transform = Transform2D(0.0, p)
	q.collision_mask = (mask0 if mask0 >= 0 else d.collision_mask) & ~KEEP
	q.exclude = [d.get_rid()]
	return d.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# the nearest open space: rings of 0.5 m round the drone, sixteen ways each, inside the berth
func _nearest_free(d) -> Vector2:
	var p0: Vector2 = d.global_position
	for ring in range(1, SEARCH + 1):
		var r := ring * 0.5 * Geom.M
		var best := Vector2.INF
		var bd := INF
		for k in 16:
			var p := p0 + Vector2.from_angle(TAU * k / 16.0) * r
			if _free_at(d, p) and _room_held(game(), p, Drone.R) == "":
				# of those at this distance, the one most along its drift
				var s: float = -p.direction_to(p0).dot(d.linear_velocity)
				if s < bd:
					bd = s
					best = p
		if best != Vector2.INF:
			return best
	return Vector2.INF


# the room under pressure whose wall p (radius r) is in, from outside ("" for none)
func _room_held(g, p: Vector2, r: float) -> String:
	if g == null or g.world == null or g.sys == null:
		return ""
	for n in g.world.rooms:
		var room = g.world.rooms[n]
		if not room.bbox.grow(r + WALL).has_point(p):
			continue
		if g.sys.P(str(n)) <= Systems.SAFE_KPA:
			continue
		if Geometry2D.is_point_in_polygon(p, room.poly) or p.distance_to(_closest_on(room.poly, p)) < r + WALL:
			return str(n)
	return ""


# the berth's edge and the rooms still under pressure stay solid to it
func _hold_in(g, d, dt: float) -> void:
	var p: Vector2 = d.global_position
	var v: Vector2 = d.linear_velocity
	var nxt := p + v * dt
	# a room still under pressure: its outline from outside
	blocked = ""
	for n in g.world.rooms:
		var room = g.world.rooms[n]
		var poly: PackedVector2Array = room.poly
		if not room.bbox.grow(Drone.R + WALL + absf(v.length() * dt) + 4.0).has_point(p):
			continue
		if g.sys.P(str(n)) <= Systems.SAFE_KPA:
			continue
		if Geometry2D.is_point_in_polygon(p, poly):
			# inside already (it flew in through an opening, or the room filled round it): free to leave
			continue
		var cp := _closest_on(poly, nxt)
		var gap := nxt.distance_to(cp)
		var inside_next := Geometry2D.is_point_in_polygon(nxt, poly)
		if gap < Drone.R + WALL or inside_next:
			var nrm := (p - cp).normalized() if p.distance_to(cp) > 0.5 else -v.normalized()
			var into := v.dot(-nrm)
			if into > 0.0:
				v += nrm * into
			# the thrust's own push in the step after: back out to the wall's face, gently
			var deep := Drone.R + WALL - p.distance_to(_closest_on(poly, p))
			if deep > 1.0 and not Geometry2D.is_point_in_polygon(p, poly):
				v += nrm * minf(deep * 4.0, EASE_V)
			blocked = str(n)
			stats.held_room += 1
			if t - said_t > SAY_GAP:
				said_t = t
				g.say("qtb_pressure", cp + nrm * 30.0, g.room_name(str(n)))
				g.sfx.play("deny", cp, 0.4)
	d.linear_velocity = v


static func _closest_on(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var dd := c.distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = c
	return best
