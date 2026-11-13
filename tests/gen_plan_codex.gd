extends SceneTree
# 切割宝典 generator (phase B, 2026-11-11; 评审选②), one ship type per run (tools/gen_plan_codex.sh runs them all):
#   1. record: tests/salvage_bot.gd makes the ship safe and strips it; the game's own WorkPlan writes
#      down what a plan can replay — the controls and hoses of the safety work.
#   2. trim: a fresh ship of the type, a career owning the codex, P: the safety work replayed (hidden
#      rooms are opened from the drawings). Any hold (a reading, a pressure, a live line) fails the type.
#   3. lines: on that ship, made safe, every marked line of the heavy equipment still on it is cut once,
#      as one kerf along the line from edge to edge, to learn the parts' keys in order; each is a step
#      {"do":"cut","seg":true}. The berth's cutter makes them when the hull over them is off.
#   4. verify: once more, clean, the whole plan on P. Standing in for the player, this script takes off
#      the hull piece the plan marks ("等待露出") — joints and lines undone, the loose piece sent to a
#      mouth by the bot — and nothing else. Passed: every step done, every marked line cut whole by the
#      machine, no incident, in time. Only then data/plan_codex/<ship>.json is kept.
# Test careers and saves only. Usage: tools/run_test.sh tests/gen_plan_codex.gd --fixed-fps 60 -- <ship> [--shot]
const Bot = preload("res://tests/salvage_bot.gd")
const Codex = preload("res://scripts/plan_codex.gd")
const Cap = preload("res://tests/cap.gd")
const HOLD_S := 45.0            # sim s any one wait may last
const LIMIT_RECORD := 72000     # frames
const LIMIT_REPLAY := 108000    # frames per replay pass
const M := 48.0
var seg_waits := {}
var ship := ""
var g
var bot
var phase := "record"
var frame := 0
var steps: Array = []
var shot := false
var shot_done := false
var shot_expose := false
var expose_frames := 0
var t0 := 0
var held_key := ""
var held_t := 0.0
var line_note := {}             # marked lines left to the player, by why
var opened := 0                 # hull pieces this script took off in verify
var safety: Array = []          # the safety work, as recorded (the plan before the lines)
var skip_origin := {}           # equipment whose lines are left to the player -> why
var restarts := 0
var stamps: Array = []          # sim time each recorded step was written down
const GAP_MAX := 300.0
const RESTARTS := 8

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--shot": shot = true
		elif not a.begins_with("--"): ship = a
	root.add_child(preload("res://tests/test_window.gd").new())
	# one ship per process, several at once: each its own test files
	Career.path = "user://zp_test_codex_gen_%s_career.json" % ship
	SaveGame.path = "user://zp_test_codex_gen_%s_save.json" % ship
	SaveGame.train_path = "user://zp_test_codex_gen_%s_train.json" % ship
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	t0 = Time.get_ticks_msec()
	if ship == "" or ship in Codex.EXCLUDE:
		_out("SKIP", "excluded or no ship")
		return
	Career.data = Career.fresh()
	Career.data.methods = {"cutter": 1}
	_spawn()
	bot = Bot.new(g, {})

func _spawn() -> void:
	Career.data.active = {}
	Game.start_ship = ship
	Game.contract = {"id":"CODEX-%s-%d" % [ship, Time.get_ticks_msec()],"ship":ship,"fee":0,"time":7200,"kit":{}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)

func _count(list: Array) -> String:
	var n := {}
	for s in list:
		var k := "line" if s.get("seg", false) else str(s.get("do",""))
		n[k] = int(n.get(k, 0)) + 1
	return str(n)

func _out(verdict: String, why: String) -> void:
	print("CODEX %s %s %s (%.0f s)" % [ship, verdict, why, (Time.get_ticks_msec() - t0) / 1000.0])
	Engine.time_scale = 1.0
	quit(0 if verdict != "FAIL" else 1)

func _write(list: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Codex.DIR))
	var f := FileAccess.open(Codex.DIR + ship + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"ship": ship, "made": Time.get_date_string_from_system(), "by": "tools/gen_plan_codex.sh", "steps": list}, "\t"))
	f.close()
	Codex._cache.erase(ship)

func _replay_start(next: String) -> void:
	if is_instance_valid(g): g.queue_free()
	Career.data = Career.fresh()
	Career.data.methods = {}
	Career.data.plan_codex = true
	phase = next
	frame = 0
	held_key = ""
	held_t = 0.0
	_spawn()
	bot = Bot.new(g, {})

func _process(_dt: float) -> bool:
	frame += 1
	if phase == "record":
		if frame == 10: g.tutorial = null
		if frame < 10: return false
		# the plan is the safety work: once the bot has made the ship safe and starts to strip it
		# (salvage_bot.gd _go_strip: its hoses off; it works no control after that) the recording ends
		var done_rec: bool = bot.step() or bot.phase == "strip" or frame > LIMIT_RECORD
		while stamps.size() < g.plan.rec.size(): stamps.append(g.sys.time)
		if done_rec:
			# each step keeps the sim time the bot let pass since the one before (its waits for a
			# tank to draw down, a room to drain): the replay keeps that pace (scripts/plan.gd "gap")
			steps = []
			var last := 0.0
			for k in g.plan.rec.size():
				var s: Dictionary = g.plan.rec[k].duplicate(true)
				if s.get("do", "") == "cut": continue
				var at: float = float(stamps[k]) if k < stamps.size() else last
				s["gap"] = snappedf(clampf(at - last, 0.0, GAP_MAX), 0.1)
				last = at
				steps.append(s)
			print("RECORD %s frames=%d state=%s blocked=%s steps=%d %s" % [ship, frame, g.state, g.plan.record_blocked, steps.size(), _count(steps)])
			if bot.phase != "strip" or int(bot.forced) > 0:
				_out("FAIL", "the bot did not make the ship safe (%s)" % ("timeout" if frame > LIMIT_RECORD else ("gave up: %s" % str(bot._unsafe())) if int(bot.forced) > 0 else bot.phase))
				return true
			if g.plan.record_blocked != "":
				_out("FAIL", "the recording stopped at an incident (%s)" % g.plan.record_blocked)
				return true
			Engine.time_scale = 1.0
			# the plan under test is read from its file, as the game will read it
			safety = steps.duplicate(true)
			_write(steps)
			_replay_start("trim")
		return false
	if frame == 10:
		g.tutorial = null
		if g.plan.source != "codex":
			return _fail("the career with the codex did not load it (source=%s)" % g.plan.source)
		if g.plan.steps.is_empty():
			return _lines()
		g.plan_key()
		if not g.plan.running:
			return _fail("P did not start the codex plan")
	if frame <= 10:
		return false
	var p = g.plan
	if shot and phase == "verify":
		# the hull piece marked while a line waits for it; the machine cutting a marked line
		if not shot_expose and p.wait == "as_plan_expose":
			# as the player would: fly over to look, then the shot a moment later
			expose_frames += 1
			if expose_frames == 1:
				g.drone.global_position = p.expose_at + Vector2(-90, -60)
				g.drone.linear_velocity = Vector2.ZERO
			if expose_frames == 45:
				shot_expose = true
				Cap.save(root, "res://proofs/plan_codex_%s_expose.png" % ship)
			return false
		if not shot_done and p.i < p.steps.size() and p.steps[p.i].get("seg", false) and p.step_t > 0.4 and p._cutter_service != null and p._cutter_service.robot.beam_on:
			shot_done = true
			Cap.save(root, "res://proofs/plan_codex_%s.png" % ship)
	if not g.incidents.is_empty():
		if phase == "verify" and p.i < p.steps.size() and p.steps[p.i].get("seg", false):
			return _leave(str(p.steps[p.i].get("origin", "")), "incident %s" % str(g.incidents[0]))
		var cur: Dictionary = p.steps[mini(p.i, p.steps.size() - 1)] if not p.steps.is_empty() else {}
		return _fail("incident during the %s replay: %s at step %d/%d %s %s value=%s, wait=%s, hoses on %s" % [phase, str(g.incidents.slice(0, 3)), p.i, p.steps.size(), cur.get("do", ""), cur.get("ctrl", cur.get("key", "")), str(cur.get("value", "")), p.wait, str(g.sys.hoses.keys())])
	if phase == "verify":
		_player(p)
		# one marked line may take its machine at most SEG_MAX s of sim (a wait that keeps
		# changing never trips HOLD_S)
		if p.i != step_at:
			step_at = p.i
			step_s = 0.0
		step_s += 1.0 / 60.0
		if p.i < p.steps.size() and p.steps[p.i].get("seg", false):
			seg_waits[p.wait] = int(seg_waits.get(p.wait, 0)) + 1
		if step_s == 1.0 / 60.0: seg_waits = {}
		if OS.get_environment("CODEX_DEBUG") != "" and frame % 600 == 0 and p.i < p.steps.size() and p.steps[p.i].get("seg", false):
			print("SEG WAITS ", seg_waits, " args ", p.wait_arg, " state=", g.state, " paused_sim=", g.paused_sim, " auto_paused=", g.auto_paused, " running=", p.running, " preset=", p.preset, " package_mode=", p.package_mode, " src=", p.source, " pause_why=", g.get("pause_why") if "pause_why" in g else "-", " card=", g.get("guide") != null if "guide" in g else "-")
			var sv2 = p._cutter_service
			var sq = g.world.key_piece(str(p.steps[p.i].get("key", "")))
			print("SEG DBG i=%d wait=%s station=%s robot=%s beam=%s front=%s seg=%s/%d step_t=%.1f cont=%s gone=%s body=%s" % [p.i, p.wait, sv2.reason if sv2 != null else "-", sv2.robot.reason if sv2 != null else "-", str(sv2.robot.beam_on) if sv2 != null else "-", str(p.cut_motion.get("front", "")), str(p.cut_motion.get("segment", "")), p.steps[p.i].pl.size(), p.step_t, str(p.cut_motion.get("step", "")), str(sq.gone) if sq != null else "null", str(sq.body != null) if sq != null else "-"])
		if p.running and step_s > SEG_MAX and p.i < p.steps.size() and p.steps[p.i].get("seg", false) and p.wait != "as_plan_expose":
			var sv = p._cutter_service
			_pass_over(p, str(p.steps[p.i].get("origin", "")), "cutter cannot finish it in %d s (%s, cutter %s)" % [int(SEG_MAX), p.wait, sv.reason if sv != null else "-"])
			held_key = ""
			return false
	if p.running and p.wait != "":
		var k := "%d %s %s" % [p.i, p.wait, p.wait_arg]
		if held_key != k:
			held_key = k
			held_t = 0.0
		held_t += 1.0 / 60.0
		if OS.get_environment("CODEX_DEBUG") != "" and frame % 300 == 0 and p._cutter_service != null:
			var sv = p._cutter_service
			var st: Dictionary = p.steps[mini(p.i, p.steps.size() - 1)]
			var q = g.world.key_piece(str(st.get("key", "")))
			print("HOLD DBG reason=", sv.reason, " robot=", sv.robot.global_position, " robot_reason=", sv.robot.reason, " cover=", p._cover(q, g.world.frame(q) * Vector2(float(st.pl[0][0]), float(st.pl[0][1]))) if q != null and st.has("pl") else "-")
		# (a hose waiting for its room to drain is capped by the plan itself, DRAIN_MAX)
		# a gauge still falling (plan_differs) may take a few minutes to drain
		var hold: float = 240.0 if p.wait == "plan_differs" else HOLD_S
		# a cutter still flying to its spot (not route_blocked) gets twice as long
		if p.wait == "plan_cutter_wait" and p._cutter_service != null and p._cutter_service.reason == "travelling": hold = HOLD_S * 2.0
		if p.wait == "as_plan_drain": held_t = 0.0
		if held_t > hold and phase == "verify" and p.i < p.steps.size() and p.steps[p.i].get("seg", false):
			# nothing was cut: that equipment's lines are passed over here, and the plan without
			# them gets one clean verify at the end
			# the evidence: the berth cutter's own reason (route_blocked: no open spot within its
			# TOOL_REACH it can fly to; tool_blocked: the line's start is under material or the beam
			# has no clear line to it) and the hull piece over it, if the plan found one
			var sv = p._cutter_service
			_pass_over(p, str(p.steps[p.i].get("origin", "")), "cutter cannot reach (%s, cutter %s, hull over it %s)" % [p.wait, sv.reason if sv != null else "-", p.expose_tag if p.expose_at.is_finite() else "none found"])
			held_key = ""
			return false
		if held_t > hold:
			return _fail("%s held at step %d/%d: %s %s" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	else:
		held_key = ""
	if frame % 3600 == 0:
		print("  %s t=%ds i=%d/%d wait=%s %s opened=%d lines=%d" % [phase, frame / 60, p.i, p.steps.size(), p.wait, p.wait_arg, opened, p.seg_done])
	if frame > LIMIT_REPLAY:
		return _fail("%s timeout at step %d/%d (%s %s)" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	if p.running:
		return false
	if p.i < p.steps.size() and phase == "verify" and p.wait == "plan_changed" and p.steps[p.i].get("seg", false):
		# a line put first (its hull already off) cut a part another line's key was learned on
		return _leave(str(p.steps[p.i].get("origin", "")), "the part it is on changed: a line on it was cut in another order")
	if p.i < p.steps.size():
		return _fail("%s stopped at step %d/%d (%s %s)" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	if phase == "trim":
		return _lines()
	if passed_over > 0:
		passed_over = 0
		restarts += 1
		if restarts > RESTARTS:
			return _fail("too many lines left to the player to verify")
		steps = steps.filter(func(s): return not (s.get("seg", false) and skip_origin.has(str(s.get("origin", "")))))
		print("PASS OVER %s: verify again with %d steps, left %s" % [ship, steps.size(), str(skip_origin)])
		_write(steps)
		_replay_start("verify")
		return false
	var lines := steps.filter(func(s): return s.get("seg", false)).size()
	if p.seg_done != lines:
		if not dropped_line_origin(p).is_empty():
			return _leave(dropped_line_origin(p), "came off before the cutter got to it")
		return _fail("the machine cut %d of %d marked lines whole" % [p.seg_done, lines])
	_out("PASS", "%d steps (%d safety, %d marked lines; left to the player %s %s), hull pieces opened %d, replay %d s" % [steps.size(), steps.size() - lines, lines, str(line_note), str(skip_origin), opened, frame / 60])
	return true

# the player's part in verify: the hull piece the plan marks comes off; what is loose goes to a mouth
func _player(p) -> void:
	if p.wait == "as_plan_expose" and p.expose_piece != null and not p.expose_piece.gone and p.expose_piece.body == null:
		var q = p.expose_piece
		var keep := {}
		for k in range(p.i, p.steps.size()):
			var t = g.world.key_piece(str(p.steps[k].get("key", ""))) if p.steps[k].get("seg", false) else null
			if t != null: keep[t.id] = true
		for j in g.world.joints_of(q):
			# a player takes the plate off, not the equipment's own mounts
			if keep.has(j.a) or keep.has(j.b): continue
			g.world.kill_joint(j)
		for l in g.world.lines_of(q):
			g.world.kill_line(l)
		opened += 1
		p.expose_t = 0.0
		if OS.get_environment("CODEX_DEBUG") != "":
			var st: Dictionary = p.steps[p.i]
			var t = g.world.key_piece(str(st.key))
			print("OPEN DBG ", q.tag, "/", q.key, " for ", st.key, " target loose=", t.body != null if t != null else "gone", " joints=", g.world.joints_of(t).filter(func(j): return j.alive).size() if t != null else -1)
	if frame % 20 == 0:
		for b in g.world.bodies:
			if is_instance_valid(b) and b.capture == null and not bot.sent.has(b):
				bot._send(b)
				break

# step 3: the marked lines, cut here once each to learn the parts' keys
func _holder(origin: String, at: Vector2):
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.gone or not q.intact or q.cls != "equip" or q.body != null or q.key == "":
			continue
		if str(q.get_meta("origin", q.tag)) != origin:
			continue
		if Geometry2D.is_point_in_polygon(g.world.frame(q).affine_inverse() * at, q.poly):
			return q
	return null

func _lines() -> bool:
	var p = g.plan
	steps = p.steps.duplicate(true)
	var jobs: Array = []
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.gone or not q.intact or q.cls != "equip" or q.body != null or q.key == "":
			continue
		for sg in q.get_meta("segments", []):
			var a: Vector2 = g.world.frame(q) * (Vector2(sg[0], sg[1]) * M)
			var bb: Vector2 = g.world.frame(q) * (Vector2(sg[2], sg[3]) * M)
			var og := str(q.get_meta("origin", q.tag))
			if skip_origin.has(og):
				continue
			# what the berth's cutter will not cut (its own rules, scripts/plan.gd): a vessel still
			# holding, a room beside still under pressure — those lines stay the player's
			var why := ""
			if g.sys.bursts(q) or (g.sys.fluid_in_piece(q) != "" and g.sys.fluid(g.sys.fluid_in_piece(q)) > 0.02):
				why = "vessel not empty"
			for room in p._rooms_by_piece(q):
				if g.sys.P(str(room)) > p.SAFE_KPA: why = "room %s under pressure" % room
			if why != "":
				skip_origin[og] = why
				continue
			jobs.append([og, a, bb])
	for job in jobs:
		var a: Vector2 = job[1]
		var bb: Vector2 = job[2]
		var mid: Vector2 = a.lerp(bb, 0.5)
		var q = _holder(job[0], mid)
		if q == null:
			line_note["off the ship"] = int(line_note.get("off the ship", 0)) + 1
			continue
		# from edge to edge along the line: the cutter starts on the piece's outline
		var d := (bb - a).normalized()
		var chords: Array = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a - d * 4000.0, bb + d * 4000.0]), g.world.world_poly(q))
		var chord := PackedVector2Array()
		for c in chords:
			if c.size() >= 2 and Geometry2D.get_closest_point_to_segment(mid, c[0], c[c.size() - 1]).distance_to(mid) < 2.0:
				chord = PackedVector2Array([c[0], c[c.size() - 1]])
		if OS.get_environment("CODEX_DEBUG") != "":
			print("LINE DBG ", q.tag, " a=", a, " b=", bb, " chords=", chords, " chord=", chord, " seg=", g.world.segment_cut(q, PackedVector2Array([a, bb])), " intact=", q.intact, " poly=", g.world.world_poly(q))
		if chord.is_empty() or not g.world.segment_cut(q, chord):
			line_note["not a clean line"] = int(line_note.get("not a clean line", 0)) + 1
			continue
		var inv: Transform2D = g.world.frame(q).affine_inverse()
		var la: Vector2 = inv * chord[0]
		var lb: Vector2 = inv * chord[1]
		var st := {"do": "cut", "seg": true, "origin": str(job[0]), "key": q.key, "pl": [[la.x, la.y], [lb.x, lb.y]], "rooms": p._rooms_by_piece(q), "pre": []}
		var n0: int = g.incidents.size()
		g.cut_kerf(q, chord)
		if g.incidents.size() > n0:
			return _leave(str(job[0]), "incident %s" % str(g.incidents[n0]))
		steps.append(st)
	var lines := steps.filter(func(s): return s.get("seg", false)).size()
	print("LINES %s %d marked lines, left to the player %s %s; plan %s" % [ship, lines, str(line_note), str(skip_origin), _count(steps)])
	if steps.is_empty():
		return _fail("nothing a plan can replay")
	_write(steps)
	_replay_start("verify")
	return false

# a marked line the codex cannot make: every line of that equipment is the player's (its later
# lines' part keys follow from the earlier cuts; other equipment's keys do not depend on them).
# The plan without them, verified again from a fresh ship.
func _leave(origin: String, why: String) -> bool:
	restarts += 1
	if origin == "" or skip_origin.has(origin) or restarts > RESTARTS:
		return _fail("could not leave %s to the player (%s)" % [origin, why])
	skip_origin[origin] = why
	print("LEAVE %s %s: %s" % [ship, origin, why])
	steps = steps.filter(func(s): return not (s.get("seg", false) and skip_origin.has(str(s.get("origin", "")))))
	opened = 0
	passed_over = 0
	_write(steps)
	_replay_start("verify")
	return false

# the cutter cannot get at a line (held past HOLD_S, nothing cut): that equipment's lines are
# passed over where they stand and the run goes on
var passed_over := 0
var step_at := -1
var step_s := 0.0
const SEG_MAX := 180.0
func _pass_over(p, origin: String, why: String) -> void:
	skip_origin[origin] = why
	passed_over += 1
	print("PASS OVER %s %s: %s" % [ship, origin, why])
	while p.i < p.steps.size() and p.steps[p.i].get("seg", false) and str(p.steps[p.i].get("origin", "")) == origin:
		p.i += 1
	# and its lines further on (put out of order while a hull was off): all of that equipment's
	# lines are the player's now (sv122: ENG met again later, "could not leave ENG")
	for k in range(p.steps.size() - 1, p.i - 1, -1):
		if p.steps[k].get("seg", false) and str(p.steps[k].get("origin", "")) == origin:
			p.steps.remove_at(k)
	p.cut_motion.clear()
	p._release_cutter()
	p.wait = ""
	p.step_t = 0.0
	p.expose_at = Vector2.INF
	p.expose_piece = null


func dropped_line_origin(p) -> String:
	# the first marked line whose part came off before the cutter had cut it
	for k in p.steps.size():
		var st: Dictionary = p.steps[k]
		if st.get("seg", false) and not st.get("machine_cut", false):
			return str(st.get("origin", ""))
	return ""


func _fail(why: String) -> bool:
	# a plan that does not replay is not shipped
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Codex.DIR + ship + ".json"))
	_out("FAIL", why)
	return true
