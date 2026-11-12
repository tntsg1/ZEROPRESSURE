class_name WorkPlan
extends Node
# Basic work plans (roadmap 3.5). While the operator makes a ship safe, each
# control worked and each hose put on or taken off is written down together
# with the readings that stood at that moment (which port read what, which
# test point read what). Settlement keeps the successful order for this type.
# Unrelated later incidents never discard it; an operation that itself causes
# an incident stops recording at the preceding valid prefix.
#
# On the next ship of the type the plan can be run (the plan key): the berth
# does the steps one by one, as a machine, but before each step every reading
# the operator had then must be there now, taken on this ship and not gone
# stale since, and be no worse than it was then (a room that read empty must
# read empty, a circuit that read dead must read dead). Missing, stale or
# worse: it stops and says
# which, and goes on by itself once the operator has put it right. A control
# the plan names that is not on this ship stops it for good: the ship is not
# the one the plan was made on. The automation key (or the plan key) stops it
# at any time.

const STEP_TIME := 1.6           # s of sim time a step takes the machine
const CUT_TIME_M := 1.2          # s more per metre of kerf the machine cuts
const SAFE_KPA := 5.0            # a room beside a piece must read no more than this before the machine cuts it
var haul_watch: Array = []       # recorded hauls waiting for their body to come loose: [{keys, zone}]
var watch_t := 0.0
var machine_steps := 0           # 108 号: replayed steps passed this contract (the showcase's count)
var cuts_rec := 0                # this contract's recorded cuts and hauls (the settlement says)
var hauls_rec := 0
var preset := false
var _preset_driver

var game
var rec: Array = []              # this contract's order, as the operator did it
var steps: Array = []            # the plan being run
var i := 0
var running := false
var wait := ""                   # why it is not going on: a Txt key
var wait_arg := ""
var step_t := 0.0
var record_blocked := ""
var rejected := ""
var message_arg := ""
var result_key := ""
var result_arg := ""
var _record_index := -1
var _incident_count := 0
var packages = null
var package_mode := false
var package_worker := false
var _cutter_service = null
var cut_motion: Dictionary = {}
# 切割宝典 (2026-11-11, 评审选②): a marked line the cutter cannot see yet: the hull piece over it, for the
# "下一步" mark (scripts/next_step.gd); the machine cuts on its own the moment the player has it off
var expose_at := Vector2.INF
var expose_tag := ""
var expose_t := 0.0
var expose_piece = null
var seg_done := 0              # marked lines the machine cut whole this job
# 2026-11-11 切割宝典: where the steps came from — "own" (this career's recording), "codex" (the
# shipwrights' plan, scripts/plan_codex.gd) or "" (none / the grey heron preset)
var source := ""
const Codex = preload("res://scripts/plan_codex.gd")

func cutter_service():
	if package_worker and game.plan != null and game.plan != self:
		return game.plan.cutter_service()
	if not is_instance_valid(_cutter_service):
		_cutter_service = load("res://scripts/cutter_station.gd").new()
		game.add_child(_cutter_service)
		_cutter_service.setup(game)
	return _cutter_service

func _release_cutter() -> void:
	var host = game.plan if game != null and game.plan != null else self
	if is_instance_valid(host._cutter_service): host._cutter_service.release(self)


func setup(g) -> void:
	game = g
	packages = load("res://scripts/plan_packages.gd").new(self)
	if g.career() and Career.usable():
		Career.load_or_new()
		var picked: Array = Codex.pick(g.ship_id) if not g.manual_only() else [[], ""]
		steps = picked[0].duplicate(true)
		source = str(picked[1])
		if steps.is_empty() and g.ship_id == "gr7":
			preset = true
			_preset_driver = load("res://scripts/grey_heron_plan.gd")
			steps = _preset_driver.steps()
	packages.refresh()


func _exit_tree() -> void:
	if packages != null:
		packages.dispose()
		packages = null


func _notification(what: int) -> void:
	# Save validation can construct an executor outside the scene tree. It still
	# owns its package workers, even though _exit_tree will never run there.
	if what == NOTIFICATION_PREDELETE and packages != null:
		packages.dispose()
		packages = null


# the readings that stand now, as a step's preconditions; the rooms named get their
# port's pressure whether or not the operator read it this time
func _pre_readings(rooms: Array) -> Array:
	var pre: Array = []
	for k in game.sys.readings:
		var r: Dictionary = game.sys.readings[k]
		if str(k).begins_with("L:") or str(k).begins_with("P:") or str(k).find("/") >= 0:
			continue
		if game.sys.stale(r):
			continue
		var site = game.world.ctrls.get(str(k))
		if site == null or not game.world.ctrl_alive(site):
			continue # A delivered instrument's historical value is not a current prerequisite.
		pre.append({"key": str(k), "kind": r.kind, "val": snappedf(float(r.val), 0.1)})
	for room in rooms:
		var port := _gas_port(room)
		if port == "" or pre.any(func(q): return q.key == port):
			continue
		pre.append({"key": port, "kind": "pressure", "val": snappedf(game.sys.P(room), 0.1)})
	return pre


# the operator worked a control or a hose (never called for the plan's own steps)
func on_player(kind: String, c) -> void:
	if c == null or record_blocked != "":
		return
	_record_index = rec.size()
	_incident_count = game.incidents.size()
	# a door is never opened on the plan's word alone: the rooms behind it must
	# have been read, whether the operator read them that time or not
	var pre := _pre_readings(_rooms_by(c) if c.kind in ["door", "hatch"] else [])
	rec.append({"do": kind, "ctrl": c.id, "pre": pre})


# the operator (or the test's bot) cut a piece (G4): the kerf is written down in the
# piece's own frame with the readings that stood, and the rooms beside it. Only a
# safe cut of structure still on the ship is recorded: a cut into whole equipment, a
# cut that set something off, a cut on a loose body or a door are the operator's own.
func on_cut(p, pl: PackedVector2Array, incident: bool, attached: bool, context: Dictionary = {}, by_machine: bool = false) -> void:
	if by_machine or p == null or record_blocked != "" or pl.is_empty():
		return
	if incident:
		record_blocked = p.key if p.key != "" else p.tag
		return
	if not attached or p.cls == "equip" or p.door or p.key == "":
		return
	var rooms: Array = context.get("rooms", _rooms_by_piece(p))
	var pts: Array = []
	for q in pl:
		pts.append([q.x, q.y])
	# A normal held beam commits its final dot when released. World applies
	# that real disk kerf and advances the piece's fragment sequence even
	# when it only revisits an existing notch. Omitting it makes later child
	# identities diverge during replay. Geom.stroke treats duplicate endpoints
	# exactly like the original single-point disk; the saved path stays valid.
	if pts.size() == 1: pts.append(pts[0].duplicate())
	var st := {"do": "cut", "key": p.key, "pl": pts, "rooms": rooms, "pre": context.get("pre", _pre_readings(rooms))}
	if context.has("shape"):
		st.before = context.shape
		st.after = _shape(p)
		st.links = context.links
		st.kerf = context.kerf
	rec.append(st)
	cuts_rec += 1


# Capture before material, connections or pressure change. A cut's prerequisites
# describe the site the player examined, not the opening it creates afterwards.
func cut_context(p) -> Dictionary:
	var rooms := _rooms_by_piece(p)
	return {"rooms": rooms, "pre": _pre_readings(rooms), "shape": _shape(p), "links": _links(p), "kerf": game.skill_value("laser_kerf")}


func _shape(p) -> Array:
	var points: Array = []
	for q in p.poly:
		# String tokens avoid exact-float equality changing after JSON round trips.
		points.append("%.2f:%.2f" % [q.x, q.y])
	return points


# 2026-10-25 (G4 replay stuck at AF-H): a physical replay never rounds a kerf exactly as the
# recording did — the same cut leaves a corner a pixel off. Two outlines are the same shape when
# every corner of each lies within SHAPE_SLACK px (just under a kerf) of the other's edge.
const SHAPE_SLACK := 3.0


static func _poly_of(tokens: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in tokens:
		var xy := str(t).split(":")
		if xy.size() == 2: out.append(Vector2(float(xy[0]), float(xy[1])))
	return out


static func _near_outline(pts: PackedVector2Array, poly: PackedVector2Array) -> bool:
	var ring := poly.duplicate()
	ring.append(poly[0])
	for q in pts:
		if Geom.dist_to_polyline(q, ring) > SHAPE_SLACK: return false
	return true


static func _same_shape(a: Array, b: Array) -> bool:
	if a == b: return true
	var pa := _poly_of(a)
	var pb := _poly_of(b)
	if pa.size() < 3 or pb.size() < 3: return false
	return _near_outline(pa, pb) and _near_outline(pb, pa)


# 2026-10-25: a part split off a neighbour is named by cut order ("PUSH~6.1" on one ship,
# "PUSH~7.1" on its sister); the joint is the same one. Compare the parent key, type and place.
static func _same_links(a: Array, b: Array) -> bool:
	if a == b: return true
	if a.size() != b.size(): return false
	var na: Array = a.map(func(x): return _link_norm(str(x)))
	var nb: Array = b.map(func(x): return _link_norm(str(x)))
	na.sort()
	nb.sort()
	return na == nb


static func _link_norm(t: String) -> String:
	var parts := t.split(":")
	if parts.size() > 0:
		parts[0] = parts[0].split("~")[0]
	return ":".join(parts)


func _links(p) -> Array:
	var links: Array = []
	for j in game.world.joints_of(p):
		var other: int = j.b if j.a == p.id else j.a
		var q = game.world.pieces.get(other)
		var key: String = "@anchor" if other == Model.ANCHOR else (q.key if q != null else "@missing")
		var at: Vector2 = game.world.frame(p).affine_inverse() * game.world.joint_world(j)
		links.append("%s:%s:%.2f:%.2f" % [key, j.type, at.x, at.y])
	for line in game.world.lines_of(p):
		var path: PackedVector2Array = game.world.frame(p).affine_inverse() * game.world.line_path_world(line)
		var points: Array = []
		for at in path: points.append("%.2f:%.2f" % [at.x,at.y])
		links.append("line:%s:%s:%s:%s" % [line.id,line.kind,line.net,"/".join(points)])
	links.sort()
	return links


# a body went down a mouth by the operator's hand or on their mark (G4): what it was
# and where it went
func on_haul(b, zone: String, record: bool = true) -> void:
	if not is_instance_valid(b): return
	if packages != null: packages.delivered(b, zone)
	# Delivery is an observed event, not the act of putting a body in a queue.
	for w in haul_watch.duplicate():
		if _body_keys(b) == w.keys:
			if zone == str(w.zone):
				haul_watch.erase(w)
			else:
				w.failed = true
				_pause("plan_haul_wrong", str(w.keys[0]))
	if not record or b.get_meta("plan_dispatch", false) or record_blocked != "":
		return
	var keys: Array = []
	for p in b.pieces:
		if p.key != "":
			keys.append(p.key)
	if keys.is_empty():
		return
	keys.sort()
	# 108 号: a replayed haul already kept in an edited plan is not written twice
	for st in rec:
		if str(st.get("do", "")) == "haul" and st.get("keys", []) == keys:
			return
	rec.append({"do": "haul", "keys": keys, "zone": zone, "pre": []})
	hauls_rec += 1


# the rooms a piece stands against (a wall's two sides, a deck's above and below)
func _rooms_by_piece(p) -> Array:
	var out: Array = []
	var c: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	for n in 12:
		var room: String = game.world.room_at(c + Vector2.from_angle(TAU * n / 12.0) * 0.8 * Geom.M)
		if room != "" and not room in out:
			out.append(room)
	if p.room != "" and not p.room in out:
		out.append(p.room)
	return out


func finish_player(success: bool) -> void:
	if _record_index < 0: return
	var ctrl: String = rec[_record_index].ctrl
	var unsafe: bool = game.incidents.size() > _incident_count
	if not success or unsafe:
		rec.resize(_record_index)
		rejected = ctrl
	if unsafe:
		record_blocked = ctrl
	if success and not unsafe:
		var st: Dictionary = rec[_record_index]
		var c = game.world.ctrls.get(ctrl)
		if c != null:
			st.value = game.sys.hoses.has(ctrl) if st.do == "h" else c.state
	_record_index = -1


# the rooms on either side of a door's piece
func _rooms_by(c) -> Array:
	var out: Array = []
	var p = game.world.pieces.get(c.piece)
	if p == null:
		return out
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	for n in 12:
		var room: String = game.world.room_at(at + Vector2.from_angle(TAU * n / 12.0) * 0.8 * Geom.M)
		if room != "" and not room in out:
			out.append(room)
	return out


func _gas_port(room: String) -> String:
	for id in game.world.ctrls:
		var k = game.world.ctrls[id]
		if k.kind == "port" and k.medium == "gas" and k.target == room and game.world.ctrl_alive(k):
			return id
	return ""


# Both menu settlement and automatic completion file the valid recorded prefix.
func commit() -> void:
	if Career.data.is_empty() or not game.career() or game.dev_job():
		result_key = "plan_career_only"
		return
	if source == "codex" and machine_steps > 0:
		# the shipwrights' plan ran this job: what the operator added is not a plan of their own
		result_key = "as_plan_codex_ran"
		result_arg = ""
	elif rec.is_empty():
		result_key = "plan_preset_ready" if preset else ("plan_record_blocked" if record_blocked != "" else ("plan_rejected" if rejected != "" else "plan_no_actions"))
		result_arg = record_blocked if record_blocked != "" else rejected
	else:
		var plans: Dictionary = Career.data.get("plans", {})
		plans[game.ship_id] = rec.duplicate(true)
		Career.data.plans = plans
		if packages != null: packages.archive_recording(rec)
		result_key = "plan_saved_prefix" if record_blocked != "" else "plan_saved"
		result_arg = str(rec.size())
	var notes: Dictionary = Career.data.get("plan_notes", {})
	notes[game.ship_id] = {"key":result_key,"arg":result_arg}
	Career.data.plan_notes = notes


func result_text() -> String:
	if result_key == "": return ""
	var s: String = Txt.t(result_key) % result_arg if "%s" in Txt.t(result_key) else Txt.t(result_key)
	if result_key in ["plan_saved", "plan_saved_prefix"] and (cuts_rec > 0 or hauls_rec > 0):
		s += "  " + Txt.t("plan_saved_cuts") % [cuts_rec, hauls_rec]
	return s


func save_state() -> Dictionary:
	var d := {"rec": rec.duplicate(true), "i": i, "record_blocked":record_blocked, "rejected":rejected, "preset":preset,
		"steps": steps.duplicate(true), "watch": haul_watch.duplicate(true), "cuts": cuts_rec, "hauls": hauls_rec, "source": source}
	d.cut_motion = cut_motion.duplicate(true)
	if not package_worker and is_instance_valid(_cutter_service): d.cutter = _cutter_service.save_state()
	if packages != null:
		d.packages = packages.save_state()
		d.package_mode = package_mode
	return d


func load_state(d: Dictionary) -> void:
	cut_motion = d.get("cut_motion",{}).duplicate(true)
	if not package_worker and d.has("cutter"): cutter_service().load_state(d.cutter)
	rec = d.get("rec", []).duplicate(true)
	i = int(d.get("i", 0))
	if d.has("steps"):
		preset = bool(d.get("preset", false))
		steps = d.steps.duplicate(true)
		source = str(d.get("source", "own" if not preset and not steps.is_empty() else ""))
	elif preset and not d.get("preset",false):
		i = 0
	record_blocked = str(d.get("record_blocked", ""))
	rejected = str(d.get("rejected", ""))
	haul_watch = d.get("watch", []).duplicate(true)
	cuts_rec = int(d.get("cuts", 0))
	hauls_rec = int(d.get("hauls", 0))
	if packages != null and d.has("packages"):
		packages.load_state(d.packages)
		package_mode = bool(d.get("package_mode", false))
		# a save from before the rule: whatever ran, does not run on a manual-only ship
		if game != null and game.manual_only():
			running = false


func has_plan() -> bool:
	return not steps.is_empty() or (packages != null and not packages.catalogue.is_empty())


func toggle() -> String:
	# 78 号 P0②: no work plan, replay or package on a manual-only ship (ARK-01)
	if game != null and game.manual_only():
		running = false
		return "plan_manual_only"
	if package_mode and packages != null:
		if running:
			cancel()
			return "plan_stopped"
		running = true
		return "plan_running"
	if steps.is_empty():
		message_arg = ""
		if not game.career() or game.dev_job(): return "plan_career_only"
		if not rec.is_empty():
			message_arg = str(rec.size())
			return "plan_pending_prefix" if record_blocked != "" else "plan_pending"
		if record_blocked != "" or rejected != "":
			message_arg = record_blocked if record_blocked != "" else rejected
			return "plan_record_blocked" if record_blocked != "" else "plan_rejected"
		var note: Dictionary = Career.data.get("plan_notes", {}).get(game.ship_id, {})
		if note.get("key", "") in ["plan_record_blocked", "plan_rejected", "plan_no_actions"]:
			message_arg = str(note.get("arg", ""))
			return note.key
		return "plan_none"
	if running:
		cancel()
		return "plan_stopped"
	if i >= steps.size() and haul_watch.is_empty():
		return "plan_done"
	running = true
	wait = ""
	return "plan_preset_running" if preset else "plan_running"


# 108 号 Q15 (the cutter's second tier: the plan can be edited): a replayed step that is passed
# stays in this job's record, the operator's own cuts and hauls go in between as they are made,
# so the plan saved at the settlement is the one replayed, with what was added and without what
# was skipped (Shift + the plan key skips the step the machine is on)
func editing() -> bool:
	return not preset and not package_mode and source != "codex" and Methods.level("cutter") >= 2


# 切割宝典: both plans for this type — Shift + the plan key (not running) changes which one P runs
func can_switch() -> bool:
	return game != null and not running and Codex.owned() and Codex.has(game.ship_id) and not Career.data.get("plans", {}).get(game.ship_id, []).is_empty()


func switch_source() -> String:
	if not can_switch():
		return ""
	var to := "own" if source == "codex" else "codex"
	Codex.set_pick(game.ship_id, to)
	var picked: Array = Codex.pick(game.ship_id)
	steps = picked[0].duplicate(true)
	source = str(picked[1])
	i = 0
	wait = ""
	haul_watch.clear()
	return "as_plan_src_" + source


func _passed() -> void:
	machine_steps += 1
	if editing() and i < steps.size():
		rec.append(steps[i].duplicate(true))
		if str(steps[i].get("do", "")) == "cut":
			cuts_rec += 1
	i += 1


func skip_step() -> bool:
	if not running or not editing() or i >= steps.size():
		return false
	i += 1
	step_t = 0.0
	cut_motion.clear()
	_release_cutter()
	wait = ""
	return true


func cancel() -> void:
	running = false
	_release_cutter()
	if packages != null:
		for j in packages.jobs:
			j.worker.running = false
			j.worker._release_cutter()
	# Revoke work this plan queued. Already captured loads finish swallowing;
	# unrelated manually marked loads remain with their machines.
	if game == null: return
	for b in game.world.bodies:
		if not is_instance_valid(b) or not b.get_meta("plan_dispatch", false): continue
		for h in game.haulers():
			h.queue.erase(b)
			if h.body == b: h.halt()
		if game.crane != null:
			game.crane.queue.erase(b)
			if game.crane.body == b: game.crane.halt()
		if game.arm != null:
			game.arm.queue.erase(b)
			if game.arm.body == b: game.arm.halt()
		if b.get_meta("arm_parked",false):
			b.remove_meta("arm_parked")
			b.collision_layer = 1
			b.collision_mask = FreeBody.MASK
			b.set_deferred("freeze",false)
		b.remove_meta("plan_dispatch")
		b.remove_meta("plan_zone")


# what a reading says: something there (gas, voltage, fluid, heat, field) or not
static func present(kind: String, v: float) -> bool:
	match kind:
		"pressure":
			return v > 5.0
		"volts":
			return v > 1.0
		"fluid":
			return v > 0.02
		"temp":
			return v > 60.0
		"field":
			return v > 2.0
	return false


# no worse than when the plan was made: what was dead or empty then is now too
static func no_worse(kind: String, now: float, then: float) -> bool:
	return present(kind, then) or not present(kind, now)


func _pause(key: String, arg: String) -> void:
	_release_cutter()
	wait = key
	wait_arg = arg
	step_t = 0.0


func _physics_process(dt: float) -> void:
	if package_mode and packages != null:
		packages.tick(dt)
		return
	if running and game != null and game.state == "play" and not game.paused_sim and not game.auto_paused:
		watch_t += dt
		if watch_t > 0.5:
			watch_t = 0.0
			_watch_hauls()
	if not running or game == null or game.state != "play" or game.paused_sim:
		return
	if game.auto_paused:
		return
	if i >= steps.size():
		if not haul_watch.is_empty():
			return
		running = false
		wait = ""
		if not package_worker: game.say("plan_done", game.drone.global_position + Vector2(0, -44))
		return
	if preset:
		_preset_driver.tick(self,dt)
		return
	var st: Dictionary = steps[i]
	# the cuts and hauls the plan learned (G4)
	if st.get("do", "") == "cut":
		_step_cut(st, dt)
		return
	if st.get("do", "") == "haul":
		haul_watch.append({"keys": st.keys.duplicate(), "zone": str(st.zone)})
		_passed()
		return
	var c = game.world.ctrls.get(st.ctrl)
	if c == null or not game.world.ctrl_alive(c):
		# not the ship the plan was made on: the operator takes over from here
		_pause("plan_changed", st.ctrl)
		running = false
		game.say("plan_changed", game.drone.global_position + Vector2(0, -44), st.ctrl)
		return
	if game.world.room_hidden(c.hidden_room):
		# 切割宝典: the shipwrights' drawings show the room; the machine opens it
		if source == "codex":
			game.world.reveal(c.hidden_room, game.world.ctrl_world(c))
		else:
			_pause("plan_hidden", st.ctrl)
			return
	for pr in st.pre:
		var reading_site = game.world.ctrls.get(pr.key)
		if reading_site == null or not game.world.ctrl_alive(reading_site):
			_pause("plan_changed", pr.key)
			running = false
			return
		var r = game.sys.readings.get(pr.key)
		if r == null or game.sys.stale(r):
			_pause("plan_measure", pr.key)
			return
		if not no_worse(pr.kind, float(r.val), float(pr.val)):
			_pause("plan_differs", pr.key)
			return
	wait = ""
	if st.has("value"):
		var actual: bool = game.sys.hoses.has(c.id) if st.do == "h" else c.state
		if actual == bool(st.value):
			_passed()
			step_t = 0.0
			return
	step_t += dt
	if step_t < STEP_TIME:
		return
	step_t = 0.0
	var incident_count: int = game.incidents.size()
	if not game.plan_do(st.do, c):
		_pause("plan_preset_blocked", c.id)
		return
	if game.incidents.size() > incident_count:
		_pause("plan_preset_blocked", c.id)
		running = false
		return
	_passed()


# the machine cuts a recorded kerf: the same piece, still on the ship and uncut, the
# rooms beside it empty, nothing live or charged through it, the readings as they were
func _step_cut(st: Dictionary, dt: float) -> void:
	if game.plan != null and game.plan.packages != null and not game.plan.packages.cut_conflicts(st).is_empty():
		_pause("plan_cut_preserved", str(st.key))
		return
	var p = game.world.key_piece(str(st.key))
	if p == null:
		_pause("plan_changed", str(st.key))
		running = false
		game.say("plan_changed", game.drone.global_position + Vector2(0, -44), str(st.key))
		return
	if p.body != null or p.gone:
		# the operator was here first (or it came loose): nothing for the machine to do
		_passed()
		step_t = 0.0
		cut_motion.clear()
		_release_cutter()
		return
	var continuing: bool = int(cut_motion.get("step",-1)) == i and str(cut_motion.get("key","")) == str(st.key)
	if st.has("before"):
		var shape := _shape(p)
		var expected_shape: Array = cut_motion.shape if continuing else st.before
		var expected_links: Array = cut_motion.links if continuing else st.get("links",[])
		# the operator did this step (also while the machine was held part-way, waiting for a spot
		# it could reach): the piece is as the step leaves it, so on to the next
		if _same_shape(shape, st.get("after", [])) and not _same_shape(shape, expected_shape):
			_passed()
			step_t = 0.0
			cut_motion.clear()
			_release_cutter()
			return
		if not _same_shape(shape, expected_shape) or not _same_links(_links(p), expected_links):
			_pause("plan_cut_structure", str(st.key))
			return
	if game.world.room_hidden(p.room):
		if source == "codex":
			game.world.reveal(p.room, game.world.frame(p).origin)
		else:
			_pause("plan_hidden", str(st.key))
			return
	for room in st.get("rooms", []):
		if game.sys.P(str(room)) > SAFE_KPA:
			_pause("plan_cut_pressure", str(room))
			return
	for l in game.world.lines_of(p):
		if l.alive and l.kind == "cable" and game.sys.line_live(l):
			_pause("plan_cut_live", l.id)
			return
	if game.sys.bursts(p) or (game.sys.fluid_in_piece(p) != "" and game.sys.fluid(game.sys.fluid_in_piece(p)) > 0.02):
		_pause("plan_cut_vessel", p.tag if p.tag != "" else str(st.key))
		return
	for pr in st.pre:
		var reading_site = game.world.ctrls.get(pr.key)
		if reading_site == null or not game.world.ctrl_alive(reading_site):
			_pause("plan_changed", pr.key)
			running = false
			return
		var r = game.sys.readings.get(pr.key)
		if r == null or game.sys.stale(r):
			_pause("plan_measure", pr.key)
			return
		if not no_worse(pr.kind, float(r.val), float(pr.val)):
			_pause("plan_differs", pr.key)
			return
	wait = ""
	var pl := PackedVector2Array()
	for q in st.pl:
		pl.append(Vector2(float(q[0]), float(q[1])))
	var wpl: PackedVector2Array = game.world.frame(p) * pl
	# A cable or pipe need not be attached to the target plate to cross its
	# actual kerf. Production cutting can sever every crossing world line.
	for line in game.world.lines.values():
		if not line.alive: continue
		var path: PackedVector2Array = game.world.line_path_world(line)
		var intersects: bool = Geom.polyline_hits_polyline(wpl,path) != null
		if not intersects:
			for at in wpl:
				if Geom.dist_to_polyline(at,path) <= maxf(World.KERF,float(st.get("kerf",World.KERF))):
					intersects = true
					break
		if not intersects: continue
		if line.kind == "cable" and game.sys.line_live(line):
			_pause("plan_cut_live",line.id)
			return
		if line.kind == "pipe":
			var volume: String = game.sys.fluid_of_net(line.net)
			if volume != "" and game.sys.fluid_behind(volume) > float(game.sys.fvol[volume].get("leak_min",0.02)):
				_pause("plan_cut_pipe",line.id)
				return
	if pl.is_empty():
		_pause("plan_cut_structure",str(st.key))
		return
	var remaining := PackedVector2Array()
	if continuing:
		remaining.append(Vector2(float(cut_motion.front[0]),float(cut_motion.front[1])))
		for index in range(int(cut_motion.segment),pl.size()): remaining.append(pl[index])
	else:
		remaining = pl
	if st.has("after") and _same_shape(_shape(p), st.after) and _air_only(p,remaining,float(st.get("kerf",World.KERF))):
		# Released player strokes include an empty tail/dot. There is no material
		# or fixing here to cut. Retain the source operation's identity sequence,
		# but never report an air-only tail as actual machine cutting.
		p.cut_seq = int(cut_motion.sequence) if continuing else p.cut_seq+1
		cut_motion.clear()
		step_t = 0.0
		_release_cutter()
		_passed()
		return
	if not continuing:
		var basis: Array = []
		for point in p.poly: basis.append([point.x,point.y])
		cut_motion = {"step":i,"key":str(st.key),"segment":1,"front":[pl[0].x,pl[0].y],"shape":_shape(p),"links":_links(p),"basis":basis,"prefix":[[pl[0].x,pl[0].y]],"sequence":p.cut_seq+1}
	var front := Vector2(float(cut_motion.front[0]),float(cut_motion.front[1]))
	var segment: int = int(cut_motion.segment)
	while segment < pl.size() and front.distance_to(pl[segment]) < 0.001:
		segment += 1
	var at: Vector2 = game.world.frame(p)*front
	# a marked line is cut whole at its end (_seg_motion): until then the beam works from where it went in
	if bool(st.get("seg", false)): at = game.world.frame(p)*pl[0]
	# 104 号: the cutter working your plan is a dismantling method; before it is learned the
	# plan still works the controls and hoses, and holds at each cut for you to make by hand
	if game.career() and not game.dev_job() and not game.has_upgrade("cutter") and source != "codex":
		wait = "plan_needs_method"
		wait_arg = Methods.name_of("cutter")
		return
	var service = cutter_service()
	if not service.prepare(self,p,at,float(st.get("kerf",World.KERF)),dt):
		wait = "plan_cutter_wait"
		wait_arg = str(st.key)
		if bool(st.get("seg", false)) and step_t <= 0.0 and service.reason in ["tool_blocked", "route_blocked"]:
			_expose_wait(p, at, dt)
		return
	expose_at = Vector2.INF
	# Same actual material speed budget as a held beam, capped by the berth
	# machine's rated feed. Never apply an arbitrarily large dt as an instant cut.
	# 87-1: the machine's feed through this part's material (armour 3-5x slower than plate)
	var feed: float = Mat.machine_feed(p,Geom.M/CUT_TIME_M)
	cut_motion.feed = float(cut_motion.get("feed",0.0))+minf(dt,1.0/60.0)*feed
	var amount: float = float(cut_motion.feed)
	# Geom.stroke deliberately treats a sub-0.5px two-point path as a disk.
	# Accumulate real cutting time to cross that threshold before committing a
	# moving stroke; otherwise a rounded *disk* is substituted at every seam.
	if segment < pl.size() and amount < minf(0.5,front.distance_to(pl[segment])): return
	cut_motion.feed = 0.0
	if bool(st.get("seg", false)):
		_seg_motion(st, p, pl, front, segment, amount, dt)
		return
	var end := front
	if segment < pl.size(): end = front.move_toward(pl[segment],amount)
	var patch := PackedVector2Array([front,end])
	var prefix: Array = cut_motion.prefix.duplicate(true)
	prefix.append([end.x,end.y])
	# The player's stroke was one kerf: the piece came apart with the whole of it cut. Patch by
	# patch, a piece that separates part-way had its fragments cut only up to there and the rest
	# laid on a reset outline (2026-10-27: a sliver on every separated keel segment, p6's edge
	# 2 px off, then the cutter's route blocked). Where this patch would separate it, the step's
	# few remaining pixels are cut with it, in one commit, as the player's were.
	if segment < pl.size() and _separates(cut_motion.basis, prefix, float(st.get("kerf",World.KERF))):
		for index in range(segment, pl.size()):
			prefix.append([pl[index].x, pl[index].y])
			patch.append(pl[index])
		end = pl[pl.size()-1]
		segment = pl.size()
	var world_patch: PackedVector2Array = game.world.frame(p)*patch
	var source := {"basis":cut_motion.basis,"prefix":prefix,"sequence":cut_motion.sequence,"keep_shape":st.get("after",[])}
	var incident_count: int = game.incidents.size()
	game.cut_kerf(p, world_patch, float(st.get("kerf", World.KERF)), true, source)
	game.log_op("plan")
	if game.incidents.size() > incident_count:
		cancel()
		_pause("plan_cut_incident",str(st.key))
		return
	cut_motion.front = [end.x,end.y]
	cut_motion.segment = segment
	cut_motion.shape = _shape(p)
	cut_motion.links = _links(p)
	if int(source.get("split",0)) > 1:
		var next_basis: Array = []
		for point in p.poly: next_basis.append([point.x,point.y])
		cut_motion.basis = next_basis
		cut_motion.prefix = [[end.x,end.y]]
	step_t += minf(dt,1.0/60.0)
	if segment < pl.size() and end.distance_to(pl[segment]) >= 0.001: return
	if segment+1 < pl.size():
		cut_motion.prefix.append([end.x,end.y])
		cut_motion.segment = segment+1
		return
	if st.has("after") and not p.gone and not _same_shape(_shape(p), st.after):
		_pause("plan_cut_result", str(st.key))
		return
	cut_motion.clear()
	step_t = 0.0
	_release_cutter()
	_passed()

# 切割宝典 (2026-11-11): a cut along a piece's marked line. The line only takes the piece apart
# whole when it is cut as one kerf (World.segment_cut), so the machine runs the beam down its
# length and commits the whole line at the end, as the player's single stroke would.
func _seg_motion(st: Dictionary, p, pl: PackedVector2Array, front: Vector2, segment: int, amount: float, dt: float) -> void:
	var end := front
	if segment < pl.size(): end = front.move_toward(pl[segment], amount)
	cut_motion.front = [end.x, end.y]
	step_t += minf(dt, 1.0/60.0)
	if segment < pl.size() and end.distance_to(pl[segment]) >= 0.001: return
	if segment + 1 < pl.size():
		cut_motion.segment = segment + 1
		return
	var incident_count: int = game.incidents.size()
	var wpl: PackedVector2Array = game.world.frame(p) * pl
	if game.world.segment_cut(p, wpl):
		seg_done += 1
		st["machine_cut"] = true
	game.cut_kerf(p, wpl, float(st.get("kerf", World.KERF)), true)
	game.log_op("plan")
	if game.incidents.size() > incident_count:
		cancel()
		_pause("plan_cut_incident", str(st.key))
		return
	cut_motion.clear()
	step_t = 0.0
	_release_cutter()
	_passed()


# 切割宝典: the marked line waits for the hull over it to come off. Another marked line the player has
# already opened goes first; else the hull piece to take off is marked (the outermost on the shortest way out).
func _expose_wait(p, at: Vector2, dt: float) -> void:
	expose_t -= dt
	if expose_t > 0.0:
		if expose_at.is_finite():
			wait = "as_plan_expose"
			wait_arg = expose_tag
		return
	expose_t = 0.6
	var origin := str(p.get_meta("origin", p.tag))
	for k in range(i + 1, steps.size()):
		var o: Dictionary = steps[k]
		if not bool(o.get("seg", false)):
			continue
		var q = game.world.key_piece(str(o.key))
		if q == null or q.gone or q.body != null or str(q.get_meta("origin", q.tag)) == origin:
			continue
		var qa: Vector2 = game.world.frame(q) * Vector2(float(o.pl[0][0]), float(o.pl[0][1]))
		if _cover(q, qa).is_empty():
			steps.remove_at(k)
			steps.insert(i, o)
			cut_motion.clear()
			_release_cutter()
			wait = ""
			expose_at = Vector2.INF
			expose_t = 0.0
			return
	var c := _cover(p, at)
	if c.is_empty():
		expose_at = Vector2.INF
		expose_piece = null
		return
	expose_piece = c.piece
	expose_at = c.at
	expose_tag = str(c.tag)
	wait = "as_plan_expose"
	wait_arg = expose_tag


# the pieces still on the ship between a point and open space: {} when there is a clear way out,
# else the outermost of the fewest in the way {at, tag}
const CORRIDOR := 16.0           # px either side of the beam the cutter's body needs
func _cover(p, at: Vector2) -> Dictionary:
	var origin := str(p.get_meta("origin", p.tag))
	var service = cutter_service()
	# what it is mounted on is not in the way: taken off, the equipment would come loose with it
	var mounts := {}
	for j in game.world.joints_of(p):
		mounts[j.b if j.a == p.id else j.a] = true
	var best := {}
	var best_n := 1 << 30
	for k in 16:
		var d := Vector2.from_angle(TAU * k / 16.0)
		var n := 0
		var last = null
		var s := 6.0
		var out := false
		var tries := 0
		while s < 1200.0:
			var pt: Vector2 = at + d * s
			var q = game.world.piece_at(pt, [], false)
			if q != null and (mounts.has(q.id) or (q == p and s > 12.0)):
				break
			# the beam is thin; the cutter needs room for its body: the corridor either side counts too
			# (past where the beam starts, s > 2 R)
			var side = null
			if s > 2.0 * CORRIDOR:
				for off in [-CORRIDOR, CORRIDOR]:
					var qs = game.world.piece_at(pt + d.orthogonal() * off, [], false)
					if qs != null and qs != p and str(qs.get_meta("origin", qs.tag)) != origin and not mounts.has(qs.id):
						side = qs
						break
			if q != null and q != p and str(q.get_meta("origin", q.tag)) != origin:
				if q != last:
					n += 1
					last = q
			elif side != null:
				if side != last:
					n += 1
					last = side
			elif q == null and service._open(pt):
				# open space the berth's cutter can fly to (not a pocket shut inside the ship)
				tries += 1
				if service._reachable(pt):
					out = true
					break
				if tries >= 3:
					break
				s += 30.0
			s += 6.0
		if not out:
			continue
		if n == 0:
			return {}
		if n < best_n:
			best_n = n
			var c := Vector2.ZERO
			var poly: PackedVector2Array = game.world.world_poly(last)
			for v in poly: c += v
			best = {"piece": last, "at": c / maxf(1.0, poly.size()), "tag": last.tag if str(last.tag) != "" else str(last.key)}
	return best


# would cutting this much of the stroke from the step's outline leave it in more than one part
static func _separates(basis: Array, prefix: Array, kerf: float) -> bool:

	var outline := PackedVector2Array()
	for point in basis: outline.append(Vector2(float(point[0]),float(point[1])))
	var path := PackedVector2Array()
	for point in prefix: path.append(Vector2(float(point[0]),float(point[1])))
	var parts: Array = Geom.cut(outline, Geom.stroke(path, kerf)).filter(func(q): return Geom.area(q) >= 8.0)
	return parts.size() > 1


func _air_only(p, path: PackedVector2Array, kerf: float) -> bool:
	if path.is_empty(): return false
	for cutter in Geom.stroke(path,kerf):
		for overlap in Geometry2D.intersect_polygons(p.poly,cutter):
			if Geom.area(overlap) > 0.001: return false
	for joint in game.world.joints_of(p):
		var local: Vector2 = game.world.frame(p).affine_inverse()*game.world.joint_world(joint)
		if joint.alive and Geom.dist_to_polyline(local,path) <= kerf+3.0: return false
	var actual: PackedVector2Array = game.world.frame(p)*path
	for line in game.world.lines.values():
		if not line.alive: continue
		var line_path: PackedVector2Array = game.world.line_path_world(line)
		if Geom.polyline_hits_polyline(actual,line_path) != null: return false
		for point in actual:
			if Geom.dist_to_polyline(point,line_path) <= kerf: return false
	return true


# the hauls the plan learned: a body that matches a recorded one is given to the
# berth's machines the moment it comes loose
func _watch_hauls() -> void:
	if not running or haul_watch.is_empty():
		return
	wait = "plan_haul_wait"
	wait_arg = str(haul_watch[0].keys[0])
	for w in haul_watch:
		if w.get("failed", false):
			_pause("plan_haul_wrong", str(w.keys[0]))
			return
	for b in game.world.bodies.duplicate():
		if not is_instance_valid(b) or b.pieces.is_empty() or b.capture != null or (b.get_meta("arm",false) and b.get_meta("arm_by","") == "arm") or game.tools.held_body == b:
			continue
		var keys := _body_keys(b)
		for w in haul_watch.duplicate():
			if keys == w.keys:
				if game.plan_mark(b, str(w.zone)):
					if not w.get("counted", false):
						game.log_op("plan")
						w.counted = true
				else:
					# Delivery polling runs beside the current cut/control. An
					# unavailable carrier must not erase that independent step's
					# elapsed work every 0.5 s (all cuts take at least 1.6 s).
					# The load stays pending; its actual receipt still resolves it.
					wait = "plan_haul_nobody"
					wait_arg = str(w.keys[0])
				break


func _body_keys(b) -> Array:
	var keys: Array = []
	if not is_instance_valid(b): return keys
	for p in b.pieces:
		if p.key != "": keys.append(p.key)
	keys.sort()
	return keys

func reserves_body(b) -> bool:
	if not running: return false
	if package_mode and packages != null:
		for job in packages.jobs:
			if job.enabled and job.worker.reserves_body(b): return true
	var keys := _body_keys(b)
	for pending in haul_watch:
		if pending.keys == keys: return true
	for index in range(i,steps.size()):
		var step: Dictionary = steps[index]
		if step.get("do","") == "haul" and step.get("keys",[]) == keys: return true
	return false


func transport_wait() -> String:
	if game == null: return ""
	var machines: Array = game.haulers()
	if game.crane != null: machines.append(game.crane)
	for machine in machines:
		if machine.wait_reason == "" or not is_instance_valid(machine.body): continue
		var keys := _body_keys(machine.body)
		for pending in haul_watch:
			if keys == pending.keys:
				return str(keys[0])+" · "+preload("res://scripts/load_motion.gd").wait_line(machine.body,machine.wait_reason)
	return ""


func status() -> Array:
	if package_mode and packages != null: return packages.summary()
	# [title, line] for the HUD; empty when there is nothing to show
	if steps.is_empty():
		# 2026-11-11: what is being written down for this type's plan, while the operator works
		if game != null and game.career() and not game.dev_job() and not game.manual_only():
			return [Txt.t("as_plan_rec_title"), Txt.t("as_plan_rec_stopped" if record_blocked != "" else "as_plan_rec_line") % rec.size()]
		return []
	var head := Txt.t("plan_preset_title" if preset else ("as_plan_title_codex" if source == "codex" else "as_plan_title")) % [mini(i + (0 if i >= steps.size() else 1), steps.size()), steps.size()]
	if i >= steps.size():
		if not haul_watch.is_empty():
			var obstruction := transport_wait()
			if running and obstruction != "": return [head,obstruction]
			if wait != "" and running: return [head, Txt.t(wait) % wait_arg]
			return [head, Txt.t("plan_haul_wait") % str(haul_watch[0].keys[0]) if running else Txt.t("plan_ready")]
		return [head, Txt.t("plan_done")]
	if not running:
		if wait != "":
			return [head, Txt.t(wait) % wait_arg]
		return [head, Txt.t("plan_preset_idle" if preset else "plan_ready")]
	if wait != "":
		return [head, Txt.t(wait) % wait_arg]
	var st: Dictionary = steps[i]
	if st.get("do", "") == "cut":
		return [head, Txt.t("plan_step_cut") % str(st.key)]
	if st.get("do", "") == "haul":
		return [head, Txt.t("plan_step_haul")]
	return [head, Txt.t("plan_step") % st.ctrl]
