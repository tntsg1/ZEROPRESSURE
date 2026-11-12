extends RefCounted
# Physical G4 tug operator. Only the pilot is staged; material is removed by
# normal held-beam input, fixings by the production wrench, cargo by physics.
# This helper never deletes a connection or assigns a load transform.
const HandTools = preload("res://scripts/tools.gd")
var g: Node
var tree: SceneTree
var strokes := 0
var hand_deliveries := 0
var stream_manual := false
var keep_reading_sites := true
var errors: Array[String] = []
var requested_read_at := {}
func _init(game: Node) -> void:
	g = game
	tree = g.get_tree()
func frames(n: int) -> void:
	for i in n: await tree.process_frame
func safe() -> bool:
	# Open the real powered doors after recovering room gas. Visibility must
	# come from Systems' actual open geometry, never a test-side reveal call.
	for id in ["GAS-A","GAS-M"]:
		await sample(id)
		g.do_hose(control(id))
	for i in 9000:
		if g.sys.P("A") <= 1.0 and g.sys.P("M") <= 1.0: break
		await tree.process_frame
	if g.sys.P("A") > 1.0 or g.sys.P("M") > 1.0: return safety_failed("room recovery")
	for id in ["HATCH-A","DR-AM"]:
		g.do_wrench(control(id))
		await frames(120)
	if g.world.room_hidden("A") or g.world.room_hidden("M"): return safety_failed("real door visibility")
	var tanks: Array[String] = []
	for c in g.world.ctrls.values():
		if c.kind == "port" and c.medium in ["gas","fuel"] and not g.sys.hoses.has(c.id) and not g.world.room_hidden(c.hidden_room): tanks.append(c.id)
	for id in tanks:
		await sample(id)
		g.do_hose(control(id))
	for i in 9000:
		if tanks_empty(tanks): break
		await tree.process_frame
	if not tanks_empty(tanks): return safety_failed("tank recovery")
	# Restore the authored closed-door cut geometry while drive power remains.
	for id in ["DR-AM","HATCH-A"]:
		g.do_wrench(control(id))
		await frames(120)
	g.do_wrench(control("K-T"))
	await frames(120)
	await sample("E-T01")
	for id in ["GAS-A","GAS-M"]+tanks:
		await sample(id)
		g.do_hose(control(id))
		await frames(3)
	if g.sys.bus_live or not g.incidents.is_empty(): return safety_failed("power or incident")
	print("TUG REAL SAFETY rooms=",g.sys.P("A")," / ",g.sys.P("M")," O2=",g.sys.P("O2")," fuel=",g.sys.fluid("fuel"))
	return true
func tanks_empty(ports: Array[String]) -> bool:
	for id in ports:
		var c = g.world.ctrls[id]
		if c.medium == "gas" and g.sys.P(c.target) > 1.0: return false
		if c.medium != "gas" and g.sys.fluid(g.sys.fluid_at_port(id)) > 0.005: return false
	return true
func safety_failed(reason: String) -> bool:
	errors.append("actual tug safety failed: "+reason)
	return false
func control(id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind":"ctrl","ctrl":c,"pos":g.world.ctrl_world(c)}
func sample(id: String) -> void:
	if not await ensure_consumable("probe",1.0): return
	g.do_measure(control(id))
	await frames(3)
func ensure_consumable(tool: String, minimum: float) -> bool:
	if Consum.left(g,tool) >= minimum: return true
	var money: float = Career.data.money
	var why := Consum.buy(tool,1)
	if why != "": return safety_failed("paid consumable purchase: "+why)
	why = Consum.fit_later(tool,Consum.shelf(tool).size()-1,g.job)
	if why != "": return safety_failed("consumable fit request: "+why)
	# Only the pilot is staged. Production bay proximity applies the pending
	# fitted part; material stays in its actual physical location throughout.
	g.bot.lmb = false
	g.drone.global_position = Dock.BAY*Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await frames(10)
	if Consum.left(g,tool) < minimum or float(Career.data.money) > money-Consum.price(tool,1)+0.01:
		return safety_failed("paid bay fitting did not complete: "+tool)
	print("TUG PAID BAY SERVICE ",tool," left=",Consum.left(g,tool)," paid=",money-float(Career.data.money))
	return true
func read_changed() -> void:
	for c in g.world.ctrls.values():
		if c.kind not in ["port","test"] or not g.world.ctrl_alive(c) or g.world.room_hidden(c.hidden_room): continue
		var reading = g.sys.readings.get(c.id)
		if reading == null or g.sys.stale(reading):
			await sample(c.id)
func read_requested() -> void:
	# Inspect the named requested evidence. During a pump wait, deliberate
	# sampling avoids spending probe tips on dozens of sub-second readings;
	# the real executor still enforces fresh, safe evidence before proceeding.
	var id: String = str(g.plan.wait_arg)
	var c = g.world.ctrls.get(id)
	if c == null or not g.world.ctrl_alive(c) or g.world.room_hidden(c.hidden_room): return
	if g.plan.wait == "plan_differs" and g.sys.time-float(requested_read_at.get(id,-100.0)) < 4.0: return
	await sample(id)
	requested_read_at[id] = g.sys.time
func stroke(a_m: Vector2,b_m: Vector2,label: String) -> bool:
	await read_changed()
	if not await ensure_consumable("lens",a_m.distance_to(b_m)+1.0): return false
	var count: int = g.incidents.size()
	var a := a_m*Geom.M
	var b := b_m*Geom.M
	for p in g.world.pieces.values():
		if p.gone or p.cls != "equip" or not p.intact: continue
		var poly: PackedVector2Array = g.world.world_poly(p)
		if Geometry2D.is_point_in_polygon(a,poly) and not Geometry2D.is_point_in_polygon(b,poly):
			var swap := a
			a = b
			b = swap
			break
	# Stop the authored stroke before intact equipment, including its kerf.
	# A weld can be cut from the exposed face without sawing into the unit on
	# its back. This changes only pilot input, never the production hazard test.
	var nearest := 1.0
	var length := a.distance_to(b)
	var guard: float = g.skill_value("laser_kerf")+2.0
	for p in g.world.pieces.values():
		if p.gone or p.cls != "equip" or not p.intact: continue
		var poly: PackedVector2Array = g.world.world_poly(p)
		if Geometry2D.is_point_in_polygon(a,poly):
			errors.append("stroke starts inside intact equipment: "+label+" / "+p.key)
			return false
		for i in poly.size():
			var hit = Geometry2D.segment_intersects_segment(a,b,poly[i],poly[(i+1)%poly.size()])
			if hit != null: nearest = minf(nearest,maxf(0.0,(a.distance_to(hit)-guard)/maxf(length,0.001)))
	b = a.lerp(b,nearest)
	# Use the final equipment-protected stroke and actual world polygons. A
	# compound body's empty bounding-box interior is not physical stock.
	# Real obstruction still requires an actual force-driven grapple move.
	for attempt in 5:
		var obstruction = stroke_obstruction(a,b)
		if obstruction == null: break
		if attempt == 4:
			errors.append("normal laser path still obstructed after actual physical staging: "+label)
			return false
		print("TUG ACTUAL KERF OBSTRUCTION ",label," keys=",obstruction.pieces.map(func(p):return p.key))
		if not await hand_delivery(obstruction,false,Vector2(-3,-7)*Geom.M):
			# a carry out of the way that got stuck: it has moved, so look again (up to the 5 tries)
			var last: String = str(errors.back()) if not errors.is_empty() else ""
			if last.begins_with("grapple route blocked") or last.begins_with("no full-size physical grapple route"):
				errors.pop_back()
				g.bot.lmb = false
				await frames(30)
				continue
			return false
	g.bot.lmb = false
	await frames(3)
	g.tools.set_tool(2,true,true)
	g.drone.freeze = true
	g.drone.global_position = a-(b-a).normalized()*1.4*Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = a
	g.bot.lmb = true
	await frames(3)
	g.bot.aim = b
	# Physical beam speed and material resistance remain production values.
	for i in 600:
		await tree.process_frame
		if g.tools.front.distance_to(b) < 0.6: break
	g.bot.lmb = false
	await frames(10)
	strokes += 1
	if g.incidents.size() != count:
		errors.append("unsafe stroke "+label+": "+str(g.incidents.slice(count)))
		return false
	print("TUG BEAM ",label," recorded=",g.plan.cuts_rec," bodies=",g.world.bodies.size())
	if stream_manual and not await drain_free(): return false
	return true
func stroke_obstruction(a: Vector2,b: Vector2):
	var kerfs: Array = Geom.stroke(PackedVector2Array([a,b]),g.skill_value("laser_kerf")+2.0)
	for cargo in g.world.bodies:
		if not is_instance_valid(cargo) or cargo.capture != null: continue
		for piece in cargo.pieces:
			if piece.gone: continue
			var poly: PackedVector2Array = g.world.world_poly(piece)
			for kerf in kerfs:
				for overlap in Geometry2D.intersect_polygons(poly,kerf):
					if Geom.area(overlap) > 0.001: return cargo
	return null
func segment_heavy() -> bool:
	# Recover the named winch before dividing its deck/keel support. Otherwise
	# a newly released drive can drift toward the furnace during hull work.
	if not await stroke(Vector2(14.05,-4.15),Vector2(14.05,-3.4),"aft frame crown"): return false
	for x in [13.1,14.8]:
		if not await stroke(Vector2(x-0.9,-0.8),Vector2(x+0.9,-0.8),"aft frame %.1f" % x): return false
	for key in ["AF-1","AF-2","WINCH-T"]:
		await unfix_piece(key)
		if stream_manual and not await drain_free(): return false
	# Clear the exposed propulsion pod before releasing the keel stock above
	# it. Leaving it underneath a berth full of loose steel dents its real
	# casing even when no threshold-sized collision incident is emitted.
	await unfix_piece("POD-T")
	if stream_manual and not await drain_free(): return false
	# The keel stays on its actual mounts while its long stock is divided.
	for x in [2.9,4.5,6.1,7.7,9.3,10.9,12.5,14.1]:
		if not await stroke(Vector2(x,3.4),Vector2(x,2.5),"keel %.1f" % x): return false
	for y in [-0.8,0.8]:
		if not await stroke(Vector2(-0.55,y),Vector2(0.1,y),"push %.1f" % y): return false
	if not await stroke(Vector2(13.8,2.75),Vector2(13.8,2.05),"aft deck"): return false
	return true
func unfix_piece(key: String) -> void:
	var piece = g.world.key_piece(key)
	if piece == null or piece.gone: return
	for j in g.world.joints_of(piece).duplicate():
		if j.alive and j.type in ["bolt","lock"]:
			g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
			await frames(3)
func separate_shell() -> bool:
	# Read the real factory welds. Nearby paired welds share one physical seam
	# stroke; all connection changes must come from that held beam.
	var seams := {}
	for j in g.world.joints:
		if not j.alive or j.type != "weld": continue
		var ids := [j.a,j.b]
		ids.sort()
		var key := str(ids)
		if not seams.has(key): seams[key] = []
		seams[key].append(j)
	var ordered: Array = []
	# Interior welds are cut while their parent structure is still anchored.
	# Cutting them only after the roof drifts free cannot become a replayable
	# attached-structure operation and can leave an oversized transport group.
	var bottom: Array = [["p18","p1"],["p17","p18"],["p16","p17"],["p15","p16"],["p14","p15"]]
	for interior in [true,false]:
		for group in seams.values():
			var inside: bool = g.world.pieces[group[0].a].kind not in ["hull","hatch"] or g.world.pieces[group[0].b].kind not in ["hull","hatch"]
			var pair: Array = [g.world.pieces[group[0].a].key,g.world.pieces[group[0].b].key]
			var is_bottom: bool = bottom.any(func(q):return q.has(pair[0]) and q.has(pair[1]))
			if inside == interior and not is_bottom: ordered.append(group)
	# Work back toward the still-supported p15 floor. Cutting either of its
	# two perimeter seams early drops the remaining bow ring as one 3.9 t load.
	for pair in bottom:
		for group in seams.values():
			if pair.has(g.world.pieces[group[0].a].key) and pair.has(g.world.pieces[group[0].b].key): ordered.append(group)
	for group in ordered:
		var live: Array = group.filter(func(j):return j.alive)
		if live.is_empty(): continue
		var stage: String = g.world.pieces[live[0].a].key
		if not await cut_seam(live): return false
		if stream_manual and stage in ["p8","TOP-3"]:
			if not await recover_room_equipment("A" if stage == "p8" else "M"): return false
	return true
func cut_seam(group: Array) -> bool:
	var live: Array = group.filter(func(j):return j.alive)
	if live.is_empty(): return true
	var piece = g.world.pieces[live[0].a]
	var other = g.world.pieces[live[0].b]
	var door_seam: bool = piece.door or other.door
	if piece.door and not other.door: piece = other
	if piece.body != null: return true
	var center := Vector2.ZERO
	for j in live: center += g.world.joint_world(j)
	center /= float(live.size())
	var poly: PackedVector2Array = g.world.world_poly(piece)
	var box := Geom.bbox(poly)
	var direction := Vector2.RIGHT if box.size.y > box.size.x else Vector2.DOWN
	if door_seam:
		# Cut actual frame metal alongside its weld. Cutting the door first is
		# deliberately a manual-only decision and cannot teach an automatic
		# frame operation that silently assumes those door welds are gone.
		if live.size() > 1:
			direction = (g.world.joint_world(live[-1])-g.world.joint_world(live[0])).normalized()
		else:
			var distance := INF
			for i in poly.size():
				var next := (i+1)%poly.size()
				var edge_point := Geometry2D.get_closest_point_to_segment(center,poly[i],poly[next])
				if center.distance_to(edge_point) < distance:
					distance = center.distance_to(edge_point)
					direction = (poly[next]-poly[i]).normalized()
		var inward := Vector2(-direction.y,direction.x)
		if inward.dot(g.world.frame(piece)*Geom.centroid(piece.poly)-center) < 0.0: inward = -inward
		center += inward*(g.skill_value("laser_kerf")+1.0)
	var extent := 0.28*Geom.M
	for j in live: extent = maxf(extent,absf((g.world.joint_world(j)-center).dot(direction))+0.18*Geom.M)
	if not await stroke((center-direction*extent)/Geom.M,(center+direction*extent)/Geom.M,("frame seam " if door_seam else "seam ")+piece.key): return false
	if live.any(func(j):return j.alive):
		errors.append("physical seam stroke left welds attached: "+piece.key)
		return false
	return true
func recover_room_equipment(room: String) -> bool:
	# Exposed equipment comes out while its supporting floor is still held.
	# This is an actual removal/haul sequence, not collision protection.
	var equipment: Array = g.world.pieces.values().filter(func(p):return not p.gone and p.cls == "equip" and p.room == room)
	equipment.sort_custom(func(a,b):return a.value > b.value)
	for p in equipment:
		if p.gone: continue
		await unfix_piece(p.key)
		# Let the real newly detached body's pickup immunity expire; do not
		# skip it and release the next unit into the same confined workspace.
		await frames(30)
		if not await drain_free(): return false
	return true
func unfix_all() -> void:
	# Room pressure ports and the bus test point stay physically available
	# throughout structural teaching. Only now may their actual loads leave.
	keep_reading_sites = false
	await disconnect_all()
	# Keep the berth clamps until all non-weld fixings have been undone.
	for kind in ["bolt","lock","clamp"]:
		for j in g.world.joints.duplicate():
			if j.alive and j.type == kind:
				g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
				await frames(3)
				if stream_manual and not await drain_free(): return
func disconnect_all() -> void:
	for line in g.world.lines.values():
		if line.alive:
			g.do_wrench({"kind":"connector","line":line,"end":0,"pos":g.world.line_end_world(line,0)})
			await frames(3)

func destination(body) -> String:
	var kind := "metal" if g.dock.is_scrap(body) else "equip"
	for p in body.pieces:
		if g.sys.dest_of(p) == "hazard": kind = "hazard"
	# delivered by the player's grapple, which cannot turn a load: the mouth it goes in as it lies
	return Dock.for_load(kind,body,false)

func hand_delivery(body, defer_if_enclosed: bool = false, park_at: Vector2 = Vector2.INF) -> bool:
	if not is_instance_valid(body) or body.capture != null: return true
	if not await ensure_consumable("cap",maxf(Consum.CAP_MIN,body.total_mass())+0.01): return false
	if body.total_mass() > g.grab_max():
		errors.append("physical grapple capacity exceeded: "+str(body.total_mass()))
		return false
	g.bot.lmb = false
	g.drone.global_position = Vector2(-5,-12)*Geom.M
	for frame in 120:
		if not is_instance_valid(body) or body.capture != null: return true
		if frame >= 2 and body.ghost <= 0.0: break
		await tree.process_frame
	if not is_instance_valid(body) or body.capture != null: return true
	var zone := destination(body)
	var mouth: Vector2 = Dock.zpos(zone)+Dock.ZONES[zone].face*0.4*Geom.M
	if park_at != Vector2.INF: mouth = park_at
	var route: PackedVector2Array = physical_route(body,mouth)
	# 2026-10-25: moving an obstruction out of a stroke's way, the fixed parking spot can be out of
	# reach from an enclosed compartment; an operator pushes it aside within the compartment instead
	if route.is_empty() and park_at != Vector2.INF and is_instance_valid(body):
		var c0: Vector2 = body.global_transform*body.center_of_mass
		for dist in [1.5,2.5,3.5]:
			for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				var spot: Vector2 = c0+dir*dist*Geom.M
				var alt: PackedVector2Array = physical_route(body,spot)
				if not alt.is_empty():
					route = alt
					mouth = spot
					break
			if not route.is_empty(): break
	# A freed plate is still settling: an operator waits a moment for it to clear the
	# structure it brushed against and looks again, rather than abandoning the load.
	for retry in 8:
		if not route.is_empty() or defer_if_enclosed or not is_instance_valid(body) or body.capture != null: break
		await frames(30)
		if not is_instance_valid(body) or body.capture != null: return true
		route = physical_route(body,mouth)
	if route.is_empty():
		if defer_if_enclosed:
			print("TUG DEFER after physical separation ",body.pieces.map(func(p):return p.key))
			return true
		errors.append("no full-size physical grapple route for "+str(body.pieces.map(func(p):return p.key)))
		return false
	var pieces: Array = body.pieces.filter(func(p):return not p.gone)
	pieces.sort_custom(func(a,b):return Geom.area(a.poly)>Geom.area(b.poly))
	var target_piece = pieces[0]
	var point: Vector2 = g.world.frame(target_piece)*Geom.centroid(target_piece.poly)
	g.bot.lmb = false
	await frames(3)
	point = g.world.frame(target_piece)*Geom.centroid(target_piece.poly)
	g.tools.set_tool(3,true,true)
	g.drone.freeze = true
	var pilot_distance: float = maxf(2.5*Geom.M,preload("res://scripts/load_motion.gd").half_extents(body).y+Drone.R+12.0)
	g.drone.global_position = point+Vector2(0,-pilot_distance)
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = point
	g.bot.lmb = true
	await frames(5)
	if g.tools.held_body != body:
		var diagnostic := "normal grapple did not acquire %s; hover=%s cap=%.2f range=%.2f" % [target_piece.key,str(g.tools.hover),Consum.left(g,"cap"),g.drone.global_position.distance_to(point)/Geom.M]
		g.bot.lmb = false
		await frames(3)
		if defer_if_enclosed:
			print("TUG DEFER ",diagnostic)
			return true
		errors.append(diagnostic)
		return false
	for waypoint in route.size():
		var goal: Vector2 = route[waypoint]
		var reached := false
		var observed_position := Vector2.INF
		for i in 3600:
			await tree.process_frame
			if not is_instance_valid(body) or body.capture != null or target_piece.gone:
				reached = true
				break
			if g.tools.held_body != body:
				# 认真拆有奖励 (2026-11-11): a charged machine caught by the equipment mouth has its small
				# mishap and is thrown out of the grapple; the berth brings it back to the mouth by itself
				if g.get("mishap") != null and g.mishap.back.any(func(e): return e.body == body):
					reached = true
					break
				errors.append("grapple lost physical cargo "+target_piece.key)
				return false
			var grab: Vector2 = g.tools.grab_point()
			var center: Vector2 = body.global_transform*body.center_of_mass
			if i%120 == 0:
				if center.distance_to(observed_position) < 1.0: break
				observed_position = center
			if waypoint+1 < route.size() and preload("res://scripts/load_motion.gd").clear_to(body,route[waypoint+1]-center):
				reached = true
				break
			g.drone.global_position = grab+Vector2(0,-pilot_distance)
			g.drone.linear_velocity = Vector2.ZERO
			var steer := goal
			if park_at != Vector2.INF or not g.dock.is_scrap(body):
				# Cursor input alone requests a gentle steady haul below the game's
				# 55 px/s impact threshold. Actual tether force/damping stay intact.
				var damping: float = 1.2*sqrt(HandTools.K_TETHER*body.total_mass())*g.skill_value("grapple_stable")
				steer = center.move_toward(goal,damping*35.0/HandTools.K_TETHER)
			g.bot.aim = steer+(grab-center)
			if center.distance_to(goal) < 8.0 and body.linear_velocity.length() < 35.0:
				reached = true
				break
		if not reached:
			if defer_if_enclosed:
				g.bot.lmb = false
				await frames(3)
				print("TUG DEFER physical contact ",target_piece.key," at ",body.global_transform*body.center_of_mass/Geom.M)
				return true
			errors.append("grapple route blocked: "+target_piece.key+" at "+str(g.tools.grab_point()/Geom.M)+" toward "+str(goal/Geom.M))
			return false
		if not is_instance_valid(body) or body.capture != null: break
		if g.get("mishap") != null and g.mishap.back.any(func(e): return e.body == body): break
	g.bot.lmb = false
	if park_at != Vector2.INF and is_instance_valid(body) and body.capture == null:
		await frames(10)
		var parked: Vector2 = body.global_transform*body.center_of_mass
		if parked.distance_to(park_at) > 0.5*Geom.M:
			errors.append("actual grapple staging did not reach its clear holding area")
			return false
		print("TUG PHYSICALLY PARKED ",body.pieces.map(func(p):return p.key)," at ",parked/Geom.M)
		return true # Still material in the field; not a delivery or completed haul.
	# Touching the belt begins transport, not payment. Its real journey can
	# take several seconds before the receiver's own swallow animation starts.
	var receiving_frames := 120
	if is_instance_valid(body) and body.capture == "trough":
		var com: Vector2 = body.global_transform*body.center_of_mass
		receiving_frames += ceili(absf(com.x-Dock.zpos("metal").x)/(Dock.CONVEY*Geom.M)*60.0)
	var frame := 0
	while frame < receiving_frames:
		if target_piece.gone: break
		# 认真拆有奖励 (2026-11-11): a charged machine brought by hand has its small mishap first — thrown
		# out, emptied, drawn back — and is taken a few seconds later: wait for it as for the belt
		if frame == receiving_frames - 1 and g.get("mishap") != null and g.mishap.back.any(func(e): return e.body == body) and receiving_frames < 900:
			receiving_frames += 600
		await tree.process_frame
		frame += 1
	if not target_piece.gone:
		errors.append("physical mouth has not received "+target_piece.key+" / verdict="+str(g.judge(body,Dock.kind(zone)))+" / position="+str(body.global_transform*body.center_of_mass/Geom.M))
		return false
	hand_deliveries += 1
	print("TUG HAND DELIVERED ",target_piece.key," zone=",zone," recorded=",g.plan.hauls_rec)
	return true

func physical_route(body, destination_point: Vector2) -> PackedVector2Array:
	var center: Vector2 = body.global_transform*body.center_of_mass
	if preload("res://scripts/load_motion.gd").clear_to(body,destination_point-center): return PackedVector2Array([destination_point])
	var way: PackedVector2Array = g.nav_grid().payload_path(center,destination_point,preload("res://scripts/load_motion.gd").half_extents(body),body)
	var result := PackedVector2Array()
	var pose: Transform2D = body.global_transform
	var current := center
	var i := 0
	# Read-only full-shape sweeps pull the static-grid path straight. Only the
	# grapple force later moves the actual cargo along these waypoints.
	while i < way.size():
		var far := i
		for j in range(way.size()-1,i-1,-1):
			if not body.test_move(pose,way[j]-current):
				far = j
				break
		result.append(way[far])
		pose.origin += way[far]-current
		current = way[far]
		i = far+1
	return result

func deliver_all_by_hand() -> bool:
	g.auto_paused = true
	for attempt in 100:
		if g.ended: return true
		var loads: Array = g.world.bodies.filter(func(b):return is_instance_valid(b) and b.capture == null)
		if loads.is_empty():
			await frames(90)
			return g.ended
		# Clear the highest actual piece first, then lift through the opening it
		# leaves. The side approach to the furnace goes beyond the tug's stern.
		loads.sort_custom(load_before)
		if not await hand_delivery(loads[0]): return false
	return false

func drain_free() -> bool:
	# Real operators clear released work before filling the berth with drift.
	# Break only normal removable fixings of an already-free oversized group;
	# its remaining welds and geometry are never deleted by this controller.
	for b in g.world.bodies.duplicate():
		if not is_instance_valid(b) or b.capture != null: continue
		var kind := Dock.kind(destination(b))
		if b.total_mass() <= Hauler.MAX_T and g.judge(b,kind).get("ok",false): continue
		var ids: Array = b.pieces.map(func(p):return p.id)
		for j in g.world.joints.duplicate():
			if j.alive and j.type in ["bolt","lock"] and ids.has(j.a) and ids.has(j.b):
				g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)})
				await frames(3)
	var loads: Array = g.world.bodies.filter(func(b):return is_instance_valid(b) and b.capture == null and b.total_mass() <= Hauler.MAX_T)
	loads.sort_custom(load_before)
	for b in loads:
		if not is_instance_valid(b) or b.capture != null or b.ghost > 0.0: continue
		if keep_reading_sites and carries_reading_site(b): continue
		g.drone.global_position = Vector2(-5,-12)*Geom.M
		var zone := destination(b)
		var mouth: Vector2 = Dock.zpos(zone)+Dock.ZONES[zone].face*0.4*Geom.M
		if physical_route(b,mouth).is_empty():
			print("TUG DEFER enclosed load ",b.pieces.map(func(p):return p.key))
			continue
		if not await hand_delivery(b,true): return false
	return true
func carries_reading_site(body) -> bool:
	var ids: Array = body.pieces.map(func(p):return p.id)
	for c in g.world.ctrls.values():
		if not ids.has(c.piece) or not g.world.ctrl_alive(c): continue
		if c.kind == "test" and c.medium == "volt": return true
		if c.kind == "port" and c.medium == "gas" and g.world.rooms.has(str(c.target)): return true
	return false
func load_before(a,b) -> bool:
	var equipment_a: bool = not g.dock.is_scrap(a)
	var equipment_b: bool = not g.dock.is_scrap(b)
	if equipment_a != equipment_b: return equipment_a
	return preload("res://scripts/load_motion.gd").bounds(a).position.y < preload("res://scripts/load_motion.gd").bounds(b).position.y
