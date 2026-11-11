extends Node2D
# The works crew, for real (design/…/92_硬核施工_2026-10-28; user 2026-10-28: "硬核的修复就是无人机
# 真的修复那个位置，把残骸拉走，而不是目前这种随意的动画"; Q1 the crew's own drones do it by themselves,
# every step as fine as it can be; Q2 every repair and every port work at once; Q3 the crew order
# stays as it is; Q4 the player may lend a hand; Q5 no camera). A job ordered at the terminal or a
# district console (scripts/works.gd) is built on site by the steps of its plan (works_plan.gd):
#   arrive    the work boat brings the crew in and goes again
#   isolate   the bot flies to the circuit's box, opens it, throws the isolator, hangs the tag
#   remove    the broken part is really there (welded in place); the cutter burns through each
#             weld; freed, each piece is a real loose body the hauler tethers and carries off — into
#             the furnace in the berth, aboard the boat at a port district. A piece the player takes
#             (and delivers) is one less for the crew.
#   bring     the boat comes back with the new parts hanging under it, real bodies on its hook
#   lift      the hauler takes each from the hook, carries it to its seat, steadies it, sets it down
#   fasten    the wrench (or the welder) at each bolt or seam point in turn
#   connect   a cable laid from the box to the part, plugged in at both ends
#   test      the probe on the work; the lamp lights, the fire catches, the readings come up
# Every step moves on when its work is done, not when a clock runs out. The step reached is kept
# (Career.data.works.step); after a load the crew comes back and does that step again from its
# start. What the crew puts in the world is keyed "crew:" and cleared before it is rebuilt.

const CrewDrone = preload("res://scripts/crew_drone.gd")
static var in_tests := false     # tests that want the real crew switch it on
const FLOOR_LAYER := 4           # Dock.bounds_body: the berth's floor, rail and tower lines

var game
var job_id := ""
var steps: Array = []
var i := -1
var queue: Array = []
var drones := {}                 # role -> CrewDrone
var wreck: Array = []            # pieces: the broken part
var parts: Array = []            # pieces: the new part(s)
var seats: Array = []            # where each new part goes (world px)
var bolts: Array = []            # [pos, done]
var cable := PackedVector2Array()
var tagged := false
var box_open := 0.0
var lit := 0.0                   # the test: 0..1 how far the work has come alive
var boat_pos := Vector2.INF
var boat_goal := Vector2.INF
var boat_vel := Vector2.ZERO
var boat_hung: Array = []        # parts on the boat's hook
var t := 0.0
var step_t := 0.0
var _busy := {}                  # an action's own state
var _left_base := 0.0
var swallowed := 0               # wreck the furnace took (tests: really hauled, not cleared)
var carried := 0                 # wreck carried off aboard the boat, or cleared after a long wait
var lent := 0                    # wreck the operator took over
var font: Font


func _init() -> void:
	z_index = 8
	z_as_relative = false


func _ready() -> void:
	font = Fonts.get_font("Medium")


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func enabled() -> bool:
	return game != null and game.career() and Career.usable() and (not game.testing or in_tests)


# ---------------------------------------------------------------- the site

func spec() -> Dictionary:
	return WorksPlan.spec(job_id)


func spot() -> Vector2:
	return Works.spot()


func in_port() -> bool:
	return job_id.begins_with("port:")


func seat() -> Vector2:
	if WorksPlan.PLANS.has(job_id) and game.works_site != null:
		return game.works_site.seat(job_id)
	return spot()


func box() -> Vector2:
	return spot() + Vector2(-3.4, -1.6) * Geom.M


func boat_hover() -> Vector2:
	return seat() + Vector2(0, -4.6 * Geom.M)


func boat_away() -> Vector2:
	return seat() + Vector2(-26.0, -11.0) * Geom.M


# where the new parts go: the plan's part on its seat and its extra beside it; a family's units
func _seat_list() -> Array:
	var M := Geom.M
	var sp := spec()
	var out: Array = []
	if WorksPlan.PLANS.has(job_id):
		out.append([seat(), str(sp.part[0]), sp.part[1]])
		if sp.has("extra"):
			out.append([seat() + Vector2(((sp.part[1] as Vector2).x * 0.5 + (sp.extra[1] as Vector2).x * 0.5 + 0.4) * M, 0.0), str(sp.extra[0]), sp.extra[1]])
		return out
	var n := int(sp.get("units", 3))
	for k in n:
		var p: Vector2 = game.works_site._unit_pos(Works.current(), k) if game.works_site != null else spot()
		out.append([p, str(sp.part[0]), sp.part[1]])
	return out


# where the broken part is: [centre, size m, art] for each piece, and the welds holding each
func _wreck_list() -> Array:
	var M := Geom.M
	var sp := spec()
	match job_id:
		"lights":
			return [[seat(), Vector2(1.4, 0.8), "lamp"], [seat() + Vector2(0.2, 1.2) * M, Vector2(0.14, 1.3), ""]]
		"net_fix":
			return [[seat() + Vector2(-0.9, 0.1) * M, Vector2(0.9, 0.35), ""], [seat() + Vector2(0.2, 0.3) * M, Vector2(1.1, 0.3), ""], [seat() + Vector2(1.1, -0.1) * M, Vector2(0.7, 0.4), ""]]
		"furnace_main":
			return [[seat(), Vector2(1.2, 1.0), "nozzle"]]
	var out: Array = []
	var list := _seat_list()
	for k in mini(list.size(), 3):
		var sz: Vector2 = list[k][2]
		out.append([list[k][0], sz * Vector2(0.9, 0.8), "" if WorksPlan.family(job_id) != "power" else "inverter"])
	return out


func _has(key: String) -> bool:
	for s in steps:
		if str(s[0]) == key:
			return true
	return false


func _index(key: String) -> int:
	for k in steps.size():
		if str(steps[k][0]) == key:
			return k
	return -1


# ---------------------------------------------------------------- what it puts in the world

func _clear_world() -> void:
	var w0 = game.world
	for id in w0.order.duplicate():
		var p = w0.pieces[id]
		if not p.gone and str(p.key).begins_with("crew:"):
			w0.remove_piece(p)
	wreck.clear()
	parts.clear()
	for q in boat_hung:
		if q.body != null and is_instance_valid(q.body) and q.body.held():
			q.body.hold_end()
	boat_hung.clear()


func _poly(c: Vector2, sz: Vector2, ragged: bool) -> PackedVector2Array:
	var h := sz * Geom.M * 0.5
	if not ragged:
		return PackedVector2Array([c - h, c + Vector2(h.x, -h.y), c + h, c + Vector2(-h.x, h.y)])
	# a broken edge: one side torn
	return PackedVector2Array([c - h, c + Vector2(h.x * 0.6, -h.y), c + Vector2(h.x, -h.y * 0.2), c + Vector2(h.x * 0.75, h.y * 0.4), c + h, c + Vector2(-h.x, h.y)])


func _spawn_wreck() -> void:
	var w0 = game.world
	var k := 0
	for e in _wreck_list():
		var c: Vector2 = e[0]
		var sz: Vector2 = e[1]
		var art: String = e[2]
		var opts := {"mass": maxf(0.08, sz.x * sz.y * 0.35), "mat": "steel", "scope": false, "key": "crew:wreck:%d" % k, "intact": false, "cond": 0.15}
		if art != "":
			opts.art = art
			opts.art_size = sz * Geom.M
			opts.art_xf = Transform2D(0.0, c - sz * Geom.M * 0.5)
		var p = w0.add_piece("plate", _poly(c, sz, art == ""), opts)
		var h := sz * Geom.M * 0.5
		for s: float in [-1.0, 1.0]:
			w0.add_joint(p, null, "weld", c + Vector2(h.x * 0.8 * s, 0.0))
		w0.rebuild_cols(p)
		w0.redraw_near([p], true)
		wreck.append(p)
		k += 1


func _welds() -> Array:
	var out: Array = []
	for p in wreck:
		for j in game.world.joints_of(p):
			out.append(j)
	return out


func _spawn_parts_on_boat() -> void:
	var w0 = game.world
	var k := 0
	var list := _seat_list()
	for e in list:
		var sz: Vector2 = e[2]
		var c: Vector2 = boat_pos + Vector2((k - (list.size() - 1) * 0.5) * 1.6 * Geom.M, 1.6 * Geom.M + sz.y * Geom.M * 0.5)
		var art: String = e[1]
		var opts := {"mass": maxf(0.15, sz.x * sz.y * 0.5), "mat": "steel", "scope": false, "key": "crew:part:%d" % k, "cls": "equip", "value": 0.0}
		if art != "":
			opts.art = art
			opts.art_size = sz * Geom.M
			opts.art_xf = Transform2D(0.0, c - sz * Geom.M * 0.5)
		var p = w0.add_piece("fixture", _poly(c, sz, false), opts)
		parts.append(p)
		k += 1
	w0.relink()
	for p in parts:
		if p.body != null:
			p.body.set_meta("crew_part", true)
			p.body.hold_begin()      # on the boat's hook: no collision (FreeBody.hold_begin)
			boat_hung.append(p)


# a part already set on its seat (a load after the lift): straight there, held fast
func _spawn_parts_seated() -> void:
	var w0 = game.world
	var k := 0
	for e in _seat_list():
		var sz: Vector2 = e[2]
		var c: Vector2 = e[0]
		var art: String = e[1]
		var opts := {"mass": maxf(0.15, sz.x * sz.y * 0.5), "mat": "steel", "scope": false, "key": "crew:part:%d" % k, "cls": "equip", "value": 0.0}
		if art != "":
			opts.art = art
			opts.art_size = sz * Geom.M
			opts.art_xf = Transform2D(0.0, c - sz * Geom.M * 0.5)
		parts.append(w0.add_piece("fixture", _poly(c, sz, false), opts))
		k += 1
	w0.relink()
	for p in parts:
		if p.body != null:
			p.body.set_meta("crew_part", true)
			_set_down(p.body, c_of(parts.find(p)))


func c_of(k: int) -> Vector2:
	return _seat_list()[k][0]


func _set_down(b, at: Vector2) -> void:
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	var xf := Transform2D(0.0, Vector2.ZERO)
	xf.origin = at - xf.basis_xform(b.center_of_mass)
	b.global_transform = xf
	b.reset_physics_interpolation()


# ---------------------------------------------------------------- starting, keeping, finishing

func _drone(role: String):
	if drones.has(role) and is_instance_valid(drones[role]):
		return drones[role]
	var d = CrewDrone.new()
	d.game = game
	d.role = role
	add_child(d)
	d.global_position = (boat_pos if boat_pos != Vector2.INF else boat_away()) + Vector2(randf_range(-30, 30), 20)
	drones[role] = d
	return d


func _start() -> void:
	var job := Works.current()
	job_id = str(job.id)
	steps = WorksPlan.steps(job_id, float(job.get("total", 60.0)))
	_clear_world()
	for d in drones.values():
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()
	cable = PackedVector2Array()
	bolts.clear()
	tagged = false
	lit = 0.0
	# the step it had reached (an older save: the step its clock had come to)
	var at := int(job.get("step", WorksPlan.at(job)[0]))
	i = clampi(at, 0, maxi(0, steps.size() - 1))
	job.crew = true
	job.step = i
	tagged = i > _index("isolate") and _has("isolate")
	# what earlier steps left behind
	if _has("remove") and i <= _index("remove"):
		_spawn_wreck()
	var li := _index("lift")
	if li >= 0 and i > li:
		_spawn_parts_seated()
		if i > _index("fasten") and _has("fasten"):
			_make_bolts(true)
	if _has("connect") and i > _index("connect"):
		cable = PackedVector2Array([box(), _cable_end()])
	# the crew comes in on the boat
	boat_pos = boat_away()
	boat_goal = boat_hover()
	queue = [{"do": "boat_to", "to": boat_hover()}, {"do": "call", "f": _deploy}, {"do": "boat_to", "to": boat_away(), "nowait": true}]
	queue.append_array(_build(str(steps[i][0])))
	_keep()


func _deploy() -> void:
	for r in _roles():
		_drone(r).go(boat_hover() + Vector2(randf_range(-2.0, 2.0), randf_range(1.0, 2.0)) * Geom.M)


func _roles() -> Array:
	var out: Array = ["bot"]
	if _has("remove"):
		out.append_array(["cutter", "hauler"])
	elif _has("lift"):
		out.append("hauler")
	if _has("fasten"):
		out.append("torque")
	if _has("connect"):
		out.append("cable")
	out.append("tester")
	return out


func _keep() -> void:
	var job := Works.current()
	job.step = i
	job.step_f = 0.0
	var rest := 0.0
	for k in range(i, steps.size()):
		rest += float(steps[k][1])
	job.left = rest
	_left_base = rest
	step_t = 0.0
	Career.save()


func _next() -> void:
	game.sfx.play("menu", spot(), 0.5)
	i += 1
	if i >= steps.size():
		_finish()
		return
	_keep()
	game.sfx.play(str(preload("res://scripts/works_site.gd").STEP_SOUND.get(WorksPlan.machine(job_id, i), "tool")), spot(), 0.8)
	queue = _build(str(steps[i][0]))


func _finish() -> void:
	# the work is the berth's now: the facility's own drawing takes over from the crew's pieces
	var w0 = game.world
	for p in parts:
		if p.body != null and is_instance_valid(p.body):
			p.body.freeze = false
		w0.remove_piece(p)
	parts.clear()
	_clear_world()
	var id := job_id
	if Works.finish():
		var pend: Array = Career.data.get("repaired_pending", [])
		pend.erase(id)
		Career.data.repaired_pending = pend
		Career.save()
		game.fx.flash(seat(), 220.0, 0.6, Pal.ink(0.9, 2.0))
		game.sfx.play("ok", seat())
		if game.dock != null and game.dock.static_node != null:
			game.dock.static_node.queue_redraw()
		if game.hud != null:
			game.hud.show_hint(w("施工完成：%s", "BUILT: %s") % (Repair.name_of(id) if not id.begins_with("port:") else Port.name_of(id.split(":")[1])))
	for d in drones.values():
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()
	cable = PackedVector2Array()
	bolts.clear()
	tagged = false
	boat_pos = Vector2.INF
	job_id = ""
	i = -1
	queue.clear()


# ---------------------------------------------------------------- the steps, as actions

func _build(key: String) -> Array:
	var M := Geom.M
	var q: Array = []
	match key:
		"isolate":
			var m := WorksPlan.machine(job_id, i)
			q.append({"do": "fly", "who": "bot", "to": box() + Vector2(-1.4, 0.0) * M})
			q.append({"do": "call", "f": _box_opened})
			q.append({"do": "tool", "who": "bot", "at": box(), "s": 1.2, "fx": "purge" if m == "purge" else "switch"})
			q.append({"do": "call", "f": _isolated})
			q.append({"do": "tool", "who": "bot", "at": box() + Vector2(0, 0.5) * M, "s": 0.8, "fx": ""})
			q.append({"do": "call", "f": _box_closed})
			q.append({"do": "fly", "who": "bot", "to": box() + Vector2(-2.6, -2.0) * M})
		"remove":
			if wreck.is_empty():
				_spawn_wreck()
			# at a port district the wreck goes aboard the boat: it comes back for it
			if in_port():
				q.append({"do": "boat_to", "to": boat_hover(), "nowait": true})
			# piece by piece: its welds burnt through (the hauler over it for the last), carried off
			for p in wreck:
				q.append({"do": "cuts", "piece": p})
				q.append({"do": "haul", "piece": p})
			q.append({"do": "call", "f": _relink})
			q.append({"do": "fly", "who": "cutter", "to": box() + Vector2(-4.0, -2.4) * M, "nowait": true})
			if in_port():
				q.append({"do": "boat_to", "to": boat_away(), "nowait": true})
		"bring":
			q.append({"do": "boat_to", "to": boat_hover()})
			q.append({"do": "call", "f": _spawn_parts_on_boat})
			q.append({"do": "wait", "s": 0.8})
		"lift":
			if parts.is_empty():
				# a load in the middle of the lift: the boat is back with them
				q.append({"do": "boat_to", "to": boat_hover()})
				q.append({"do": "call", "f": _spawn_parts_on_boat})
			for k in _seat_list().size():
				q.append({"do": "place", "k": k})
			q.append({"do": "boat_to", "to": boat_away(), "nowait": true})
		"fasten":
			q.append({"do": "call", "f": _make_bolts.bind(false)})
			q.append({"do": "bolts"})
		"connect":
			q.append({"do": "fly", "who": "cable", "to": box() + Vector2(0, 0.6) * M})
			q.append({"do": "tool", "who": "cable", "at": box(), "s": 0.6, "fx": "plug"})
			q.append({"do": "call", "f": _lay_start})
			q.append({"do": "fly", "who": "cable", "to": (box() + _cable_end()) * 0.5 + Vector2(0, -1.4) * M})
			q.append({"do": "fly", "who": "cable", "to": _cable_end() + Vector2(0, -0.8) * M})
			q.append({"do": "call", "f": _lay_end})
			q.append({"do": "tool", "who": "cable", "at": _cable_end(), "s": 0.7, "fx": "plug"})
			q.append({"do": "fly", "who": "cable", "to": _cable_end() + Vector2(1.6, -2.4) * M})
		"test":
			q.append({"do": "fly", "who": "tester", "to": seat() + Vector2(1.6, -1.6) * M})
			q.append({"do": "tool", "who": "tester", "at": seat(), "s": 2.6, "fx": "test"})
			q.append({"do": "wait", "s": 0.6})
		_:
			q.append({"do": "wait", "s": 1.0})
	q.append({"do": "call", "f": _next})
	return q


func _box_opened() -> void:
	box_open = 1.0
	game.sfx.play("unbolt", box(), 0.6)


func _isolated() -> void:
	tagged = true
	game.sfx.play("switch", box(), 0.9)


func _box_closed() -> void:
	box_open = 0.0


func _relink() -> void:
	game.world.relink()
	for p in wreck:
		if p.body != null and is_instance_valid(p.body) and in_port():
			# out at a district the berth's field must not drag it home
			p.body.set_meta("crew_part", true)


func _lay_start() -> void:
	var d = _drone("cable")
	d.cable = PackedVector2Array([box()])
	d.laying = true


func _lay_end() -> void:
	var d = _drone("cable")
	d.laying = false
	d.cable.append(_cable_end())
	cable = d.cable.duplicate()
	d.cable = PackedVector2Array()


func _cable_end() -> Vector2:
	var list := _seat_list()
	var sz: Vector2 = list[0][2]
	return (list[0][0] as Vector2) + Vector2(-sz.x * 0.5 * Geom.M + 6.0, -sz.y * 0.5 * Geom.M + 4.0)


# four bolts a part (a welded family: four points along its top seam)
func _make_bolts(done: bool) -> void:
	bolts.clear()
	for e in _seat_list():
		var c: Vector2 = e[0]
		var h: Vector2 = (e[2] as Vector2) * Geom.M * 0.5 * 0.8
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			bolts.append([c + h * corner, done])


func _welding() -> bool:
	var k := _index("fasten")
	return k >= 0 and WorksPlan.machine(job_id, k) == "welder"


# ---------------------------------------------------------------- running them

func _physics_process(dt: float) -> void:
	if not enabled():
		return
	if not Works.busy():
		if job_id != "":
			_finish()
		return
	if game.paused_sim or not game.state in ["play", "build", "porttour"]:
		return
	if job_id != str(Works.current().id):
		_start()
	t += dt
	step_t += dt
	_pass_floor()
	_boat_step(dt)
	# whatever the operator takes hold of, the crew lets go of (Q4: they may lend a hand)
	for d in drones.values():
		if is_instance_valid(d) and d.load != null and is_instance_valid(d.load) and _operator_has(d.load):
			d.drop()
	# the time left on the sign: this step's share counted down, never below what follows it
	var job := Works.current()
	if i >= 0 and i < steps.size():
		var after := _left_base - float(steps[i][1])
		job.left = maxf(after, _left_base - step_t)
	while not queue.is_empty():
		var q0 := queue
		if not _run(queue[0], dt):
			break
		# a step that ended in this action has put the next step's actions in place: keep them
		if is_same(q0, queue):
			queue.pop_front()
		_busy = {}
	queue_redraw()


# The net hangs, and the furnace throat opens, below the berth's floor line (the dock's bounds,
# layer 4): the crew's own pieces pass through it, so the torn mesh comes up out of the net and the
# burner goes down into the throat (user 2026-10-28: the mesh "一直往上拉，一直拉不起来", a part
# held over its seat for ages, then put there). A relink makes bodies anew: kept each step.
func _pass_floor() -> void:
	for p in wreck + parts:
		var b = p.body
		if not p.gone and b != null and is_instance_valid(b) and b.collision_mask & FLOOR_LAYER:
			b.collision_mask &= ~FLOOR_LAYER


# true when the action is done
func _run(a: Dictionary, dt: float) -> bool:
	match str(a.do):
		"call":
			(a.f as Callable).call()
			return true
		"wait":
			_busy.t = float(_busy.get("t", 0.0)) + dt
			return float(_busy.t) >= float(a.s)
		"fly":
			var d = _drone(str(a.who))
			d.go(a.to)
			_busy.t = float(_busy.get("t", 0.0)) + dt
			return a.get("nowait", false) or d.at(a.to, 8.0) or float(_busy.t) > 12.0
		"tool":
			var d2 = _drone(str(a.who))
			if not _busy.has("t"):
				_busy.t = 0.0
				d2.go(d2.global_position)
			_busy.t = float(_busy.t) + dt
			d2.tool = true
			d2.tool_at = a.at
			_tool_fx(str(a.fx), a.at, dt)
			if float(_busy.t) >= float(a.s):
				d2.tool = false
				return true
			return false
		"boat_to":
			boat_goal = a.to
			return a.get("nowait", false) or boat_pos.distance_to(a.to) < 10.0
		"cuts":
			return _cuts(a.piece, dt)
		"haul":
			return _haul(a.piece, dt)
		"place":
			return _place(int(a.k), dt)
		"bolts":
			return _bolts(dt)
	return true


func _tool_fx(fx: String, at: Vector2, dt: float) -> void:
	_busy.fx = float(_busy.get("fx", 0.0)) - dt
	if float(_busy.fx) > 0.0:
		return
	_busy.fx = 0.09
	match fx:
		"cut":
			game.fx.sparks(at, Vector2.DOWN.rotated(randf_range(-0.8, 0.8)), 4, Pal.heat(1.0, 2.2), 220.0, 0.45, 1.6)
		"bolt":
			game.fx.sparks(at, Vector2.UP.rotated(randf_range(-1.2, 1.2)), 2, Pal.ink(0.9, 1.8), 120.0, 0.25, 2.0)
		"weld":
			game.fx.sparks(at, Vector2.UP.rotated(randf_range(-1.4, 1.4)), 4, Pal.heat(1.0, 2.4), 180.0, 0.35, 2.4)
		"purge":
			game.fx.sparks(at, Vector2.UP.rotated(randf_range(-0.5, 0.5)), 2, Pal.ink(0.5, 1.0), 60.0, 0.6, 1.0)
		"test":
			lit = minf(1.0, lit + 0.035)


# the cutter at the welds: the one nearest it that still holds, in close, the beam on it until it
# gives; the welds are looked up again each time (a relink may have made them anew)
func _cuts(piece0, dt: float) -> bool:
	var d = _drone("cutter")
	if not _busy.has("j"):
		var best = null
		for j in game.world.joints_of(piece0):
			if j.alive and (best == null or d.global_position.distance_to(j.pos) < d.global_position.distance_to(best.pos)):
				best = j
		if best == null:
			return true
		_busy.j = best
	var j = _busy.j
	if not j.alive:
		_busy = {}
		return false
	var at: Vector2 = j.pos
	var stand := at + Vector2(-0.6, -1.3) * Geom.M
	# the last weld of a piece: the hauler over it first, ready to take it the moment it gives
	var piece = game.world.pieces.get(j.a)
	var last: bool = piece != null and game.world.joints_of(piece).size() == 1
	if last:
		var hd = _drone("hauler")
		var over: Vector2 = Geom.centroid(piece.poly) - Vector2(0, CrewDrone.HANG)
		hd.go(over)
		if not _busy.has("on") and not hd.at(over, 16.0):
			d.go(stand)
			return false
	if not _busy.has("on"):
		d.go(stand)
		if not d.at(stand, 10.0):
			return false
		_busy.on = 0.0
		game.sfx.play("arc", at, 0.7)
	_busy.on = float(_busy.on) + dt
	d.tool = true
	d.tool_at = at
	_tool_fx("cut", at, dt)
	if float(_busy.on) < 1.8:
		return false
	d.tool = false
	game.world.kill_joint(j)
	game.sfx.play("free", at, 0.6)
	game.fx.flash(at, 50.0, 0.25, Pal.heat(0.9, 2.0))
	if last:
		game.world.relink()
		if piece.body != null and is_instance_valid(piece.body):
			if in_port():
				piece.body.set_meta("crew_part", true)
			_drone("hauler").hook(piece.body)
			game.sfx.play("clamp", at, 0.6)
	_busy = {}
	return false


# the hauler with one piece of wreck: to it, on the tether, up and over, and let go where it goes
func _haul(p, dt: float) -> bool:
	if p.gone:
		# taken in while on the tether or let go over the mouth: the furnace has it
		if int(_busy.get("st", 0)) >= 1 and not _busy.get("lent", false):
			swallowed += 1
		return true
	var b = p.body
	if b == null or not is_instance_valid(b):
		# still welded somewhere: the next look at it after the relink
		game.world.relink()
		return p.gone
	var d = _drone("hauler")
	_busy.t = float(_busy.get("t", 0.0)) + dt
	var player_has := _operator_has(b)
	var st := int(_busy.get("st", 0))
	if player_has:
		# the operator lends a hand (Q4): the crew leaves it to them
		if not _busy.get("lent", false):
			lent += 1
		_busy.lent = true
		d.drop()
		_busy.st = 0
		d.go(d.global_position)
		return false
	match st:
		0:
			var grip: Vector2 = b.global_transform * b.center_of_mass
			d.go(grip - Vector2(0, CrewDrone.HANG))
			if d.load == b or d.global_position.distance_to(grip - Vector2(0, CrewDrone.HANG)) < 12.0:
				if d.load != b:
					d.hook(b)
				game.sfx.play("clamp", grip, 0.7)
				var dest := _wreck_dest()
				# in the berth: out into the open middle first (a part under the rail would catch on
				# it going up), across, then down over the mouth; out at a district: up and over
				var lane := minf(d.global_position.y, dest.y) - 3.0 * Geom.M
				if not in_port():
					lane = (Dock.RAIL_Y + Dock.FLOOR_Y) * 0.5 * Geom.M
				_busy.path = [Vector2(d.global_position.x, lane), Vector2(dest.x, lane), dest]
				_busy.st = 1
		1:
			var path: Array = _busy.path
			d.go(path[0])
			if d.at(path[0], 18.0):
				path.pop_front()
				if path.is_empty():
					d.drop()
					game.sfx.play("clamp", d.global_position, 0.5)
					_busy.st = 2
					_busy.rel = 0.0
			elif d.load == null:
				# taken off the tether over the mouth (the furnace draws scrap in hard): delivered;
				# anywhere else it slipped off: back to it
				var dest2: Vector2 = path[path.size() - 1]
				if d.global_position.distance_to(dest2) < 8.0 * Geom.M:
					_busy.st = 2
					_busy.rel = 0.0
				else:
					_busy.st = 0
		2:
			_busy.rel = float(_busy.rel) + dt
			if in_port() or float(_busy.rel) > 9.0:
				# aboard the boat (a port district), or not taken in: carried off
				game.fx.ring(b.global_position, 6.0, 60.0, 0.4, Pal.ink(0.7, 1.4), 1.5)
				game.world.remove_piece(p)
				carried += 1
				return true
			d.go(d.global_position + Vector2(0, -1.0 * Geom.M))
	if float(_busy.t) > 60.0:
		game.world.remove_piece(p)
		d.drop()
		return true
	return false


func _operator_has(b) -> bool:
	var tl = game.tools
	if tl == null:
		return false
	if tl.held_body == b:
		return true
	var mg = tl.get("multi")
	if mg != null and mg.get("held") is Array:
		for h in mg.held:
			if h is Dictionary and h.get("body") == b:
				return true
	return false


func _wreck_dest() -> Vector2:
	if in_port():
		return boat_hover() + Vector2(0, 1.2 * Geom.M)
	# over the furnace mouth (its face points out of it, up into the berth)
	return Dock.zpos("metal") + (Dock.ZONES.metal.face as Vector2) * 2.2 * Geom.M


# the hauler takes part k off the hook and sets it on its seat
func _place(k: int, dt: float) -> bool:
	if k >= parts.size():
		return true
	var p = parts[k]
	var b = p.body
	if p.gone or b == null or not is_instance_valid(b):
		return true
	var d = _drone("hauler")
	var to: Vector2 = c_of(k)
	_busy.t = float(_busy.get("t", 0.0)) + dt
	match int(_busy.get("st", 0)):
		0:
			if b.freeze:
				return true
			var grip: Vector2 = b.global_transform * b.center_of_mass
			d.go(grip - Vector2(0, CrewDrone.HANG))
			if d.global_position.distance_to(grip - Vector2(0, CrewDrone.HANG)) < 12.0:
				d.hook(b)
				boat_hung.erase(p)
				d.steady = true
				d.load_spin = 0.0
				game.sfx.play("clamp", grip, 0.7)
				_busy.st = 1
		1:
			# over the seat first, then down slowly
			var over := to - Vector2(0, CrewDrone.HANG + 1.6 * Geom.M)
			d.go(over)
			if d.at(over, 14.0):
				_busy.st = 2
		2:
			d.go(to - Vector2(0, CrewDrone.HANG))
			var com: Vector2 = b.global_transform * b.center_of_mass
			var still: bool = b.linear_velocity.length() < 14.0 and absf(wrapf(b.global_rotation, -PI, PI)) < 0.06
			if (com.distance_to(to) < 7.0 and still) or float(_busy.t) > 20.0:
				d.drop()
				_set_down(b, to)
				game.sfx.play("clamp", to, 0.9)
				game.fx.sparks(to + Vector2(0, (_seat_list()[k][2] as Vector2).y * Geom.M * 0.5), Vector2.UP, 6, Pal.ink(0.8, 1.6), 140.0, 0.3, 2.4)
				return true
	return false


# the wrench (or the welder) at each bolt in turn
func _bolts(dt: float) -> bool:
	var n := -1
	for k in bolts.size():
		if not bolts[k][1]:
			n = k
			break
	if n < 0:
		return true
	var d = _drone("torque")
	var at: Vector2 = bolts[n][0]
	var stand := at + Vector2(0.0, -1.0) * Geom.M
	if not _busy.has("on"):
		d.go(stand)
		if not d.at(stand, 9.0):
			return false
		_busy.on = 0.0
		game.sfx.play("arc" if _welding() else "wrench", at, 0.6)
	_busy.on = float(_busy.on) + dt
	d.tool = true
	d.tool_at = at
	_tool_fx("weld" if _welding() else "bolt", at, dt)
	if float(_busy.on) < (1.1 if _welding() else 0.7):
		return false
	d.tool = false
	bolts[n][1] = true
	_busy = {}
	return false


func _boat_step(dt: float) -> void:
	if boat_pos == Vector2.INF:
		return
	var off := boat_goal - boat_pos
	var sp := minf(300.0, sqrt(2.0 * 260.0 * maxf(off.length() - 1.0, 0.0)))
	var want := off.normalized() * sp if off.length() > 1.0 else Vector2.ZERO
	boat_vel += ((want - boat_vel) * 3.0).limit_length(260.0) * dt
	boat_pos += boat_vel * dt
	# the parts on its hook hang under it
	var hook := boat_pos + Vector2(0, 0.6 * Geom.M)
	var k := 0
	for p in boat_hung:
		if p.body == null or not is_instance_valid(p.body) or p.body.freeze:
			continue
		var b = p.body
		var hang := hook + Vector2((k - (boat_hung.size() - 1) * 0.5) * 1.6 * Geom.M, 1.6 * Geom.M)
		var com: Vector2 = b.global_transform * b.center_of_mass
		var m: float = maxf(0.05, b.mass)
		b.apply_central_force(((hang - com) * 24.0 * m - (b.linear_velocity - boat_vel) * 7.0 * m).limit_length(9000.0 * m))
		b.angular_velocity *= exp(-3.0 * dt)
		k += 1


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if job_id == "":
		return
	var M := Geom.M
	# the circuit's box, its door open while the bot is at it, the tag once hung
	var bx := box()
	var r := Rect2(bx - Vector2(0.5, 0.6) * M, Vector2(1.0, 1.2) * M)
	draw_rect(r, Color(0.07, 0.075, 0.085))
	draw_rect(r, Pal.ink(0.7), false, 1.4)
	if box_open > 0.0:
		draw_rect(Rect2(r.position - Vector2(0.9 * M, 0), Vector2(0.9 * M, r.size.y)), Pal.ink(0.5), false, 1.0)
	draw_line(bx + Vector2(-0.2, -0.3) * M, bx + Vector2(-0.2, 0.0) * M if tagged else bx + Vector2(0.15, -0.35) * M, Pal.ink(0.9), 2.0)
	if tagged:
		var tag := Rect2(bx + Vector2(-0.45, 0.65) * M, Vector2(1.5, 0.55) * M)
		draw_rect(tag, Color(0.55, 0.12, 0.08, 0.92))
		draw_string(font, tag.position + Vector2(5, 17), w("检修 · 勿合闸", "LOCKED OUT"), HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 6, 11, Pal.ink(0.95))
	# the cable laid, from the box to the part
	if cable.size() >= 2:
		draw_polyline(cable, Color(0, 0, 0, 0.5), 3.4)
		draw_polyline(cable, Color(0.32, 0.34, 0.38), 1.8)
	# the bolts: dark until run home, then a bright head
	for bt in bolts:
		var c: Vector2 = bt[0]
		if _welding():
			draw_line(c - Vector2(5, 0), c + Vector2(5, 0), Pal.heat(0.6, 1.4) if bt[1] else Pal.ink(0.25), 2.0)
		else:
			draw_circle(c, 3.2, Pal.ink(0.9) if bt[1] else Pal.ink(0.25))
	# the test: the work coming alive
	if lit > 0.0:
		var glow: Color = Pal.heat(0.35 * lit, 1.6) if job_id == "furnace_main" else Pal.ink(0.35 * lit, 2.0)
		draw_circle(seat(), (1.2 + 0.6 * lit) * M, Color(glow, 0.12 * lit))
	# the work boat, with its hook
	if boat_pos != Vector2.INF and game.works_site != null:
		_draw_boat(boat_pos)


func _draw_boat(p: Vector2) -> void:
	var M := Geom.M
	var hull := PackedVector2Array([p + Vector2(-2.2, -0.4) * M, p + Vector2(1.8, -0.4) * M, p + Vector2(2.4, 0.2) * M, p + Vector2(1.6, 0.6) * M, p + Vector2(-2.2, 0.6) * M])
	draw_colored_polygon(hull, Color(0.09, 0.095, 0.11))
	var ol := hull.duplicate()
	ol.append(hull[0])
	draw_polyline(ol, Pal.ink(0.85), 1.5)
	draw_rect(Rect2(p + Vector2(-1.9, -1.1) * M, Vector2(1.2, 0.7) * M), Pal.ink(0.7), false, 1.2)
	draw_line(p + Vector2(-0.4, -0.4) * M, p + Vector2(0.3, -1.4) * M, Pal.ink(0.75), 2.0)
	draw_circle(p + Vector2(1.2, -0.55) * M, 0.1 * M, Pal.heat(0.9, 1.6) if fmod(t, 0.8) < 0.3 else Pal.ink(0.25))
	draw_string(font, p + Vector2(-1.1, 0.35) * M, "WB-2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.6))
	for q in boat_hung:
		if q.body != null and is_instance_valid(q.body) and not q.body.freeze:
			var com: Vector2 = q.body.global_transform * q.body.center_of_mass
			draw_line(p + Vector2(0, 0.6 * M), com, Pal.ink(0.7), 1.2)
