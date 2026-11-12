extends SceneTree
# 切割宝典 generator (phase B, 2026-11-11), one ship type per run (tools/gen_plan_codex.sh runs them all):
#   1. record: tests/salvage_bot.gd makes the ship safe and strips it; the game's own WorkPlan writes
#      down what a plan can replay — the controls and hoses of the safety work, and the cuts along
#      marked lines. The parts it then takes off by hand are not in it (that stays the player's).
#   2. trim: a fresh ship of the type, a career owning the codex, P. A cut the berth's cutter cannot
#      get at with the parts still on (the bot had taken them off first) is held > HOLD_S: it is
#      dropped from the plan. Any other hold (a reading, a pressure, a live line) fails the type.
#   3. verify: once more, clean, with the trimmed plan: every step done, no incident, in time.
#      Only then data/plan_codex/<ship>.json is written. A failure writes nothing and prints why.
# Test careers and saves only. Usage: tools/run_test.sh tests/gen_plan_codex.gd --fixed-fps 60 -- <ship> [--shot]
const Bot = preload("res://tests/salvage_bot.gd")
const Codex = preload("res://scripts/plan_codex.gd")
const Cap = preload("res://tests/cap.gd")
const HOLD_S := 45.0            # sim s a cut may wait for the cutter before it is dropped (trim pass)
const LIMIT_RECORD := 72000     # frames
const LIMIT_REPLAY := 54000     # frames per replay pass
var ship := ""
var g
var bot
var phase := "record"
var frame := 0
var steps: Array = []
var dropped: Array = []
var shot := false
var t0 := 0
var held_i := -1
var held_t := 0.0

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
	for s in list: n[str(s.get("do",""))] = int(n.get(str(s.get("do","")), 0)) + 1
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
	held_i = -1
	held_t = 0.0
	_spawn()

func _process(_dt: float) -> bool:
	frame += 1
	if phase == "record":
		if frame == 10: g.tutorial = null
		if frame < 10: return false
		if bot.step() or frame > LIMIT_RECORD:
			steps = g.plan.rec.duplicate(true)
			print("RECORD %s frames=%d state=%s blocked=%s steps=%d %s" % [ship, frame, g.state, g.plan.record_blocked, steps.size(), _count(steps)])
			if g.state != "ending":
				_out("FAIL", "the bot did not finish the ship (%s)" % ("timeout" if frame > LIMIT_RECORD else g.state))
				return true
			if g.plan.record_blocked != "":
				_out("FAIL", "the recording stopped at an incident (%s)" % g.plan.record_blocked)
				return true
			if steps.is_empty():
				_out("FAIL", "nothing a plan can replay was recorded")
				return true
			Engine.time_scale = 1.0
			# the plan under test is read from its file, as the game will read it
			_write(steps)
			_replay_start("trim")
		return false
	if frame == 10:
		g.tutorial = null
		if g.plan.source != "codex":
			return _fail("the career with the codex did not load it (source=%s)" % g.plan.source)
		g.plan_key()
		if not g.plan.running:
			return _fail("P did not start the codex plan")
	if frame <= 10:
		return false
	if shot and phase == "verify" and frame == 1200:
		Cap.save(root, "res://proofs/plan_codex_%s.png" % ship)
	if not g.incidents.is_empty():
		return _fail("incident during the %s replay: %s" % [phase, str(g.incidents.slice(0, 3))])
	var p = g.plan
	if p.running and p.wait != "":
		if held_i != p.i:
			held_i = p.i
			held_t = 0.0
		held_t += 1.0 / 60.0
		if held_t > HOLD_S:
			var st: Dictionary = p.steps[p.i]
			if phase == "trim" and st.get("do", "") == "cut" and p.wait == "plan_cutter_wait":
				# the cutter cannot get at it with the ship whole: not in the codex
				dropped.append(p.i)
				p._release_cutter()
				p.cut_motion.clear()
				p.step_t = 0.0
				p.wait = ""
				p.i += 1
				held_i = -1
			else:
				return _fail("%s held at step %d/%d: %s %s" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	else:
		held_i = -1
	if frame % 3600 == 0:
		print("  %s t=%ds i=%d/%d wait=%s %s" % [phase, frame / 60, p.i, p.steps.size(), p.wait, p.wait_arg])
	if frame > LIMIT_REPLAY:
		return _fail("%s timeout at step %d/%d (%s %s)" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	if p.running:
		return false
	if p.i < p.steps.size():
		return _fail("%s stopped at step %d/%d (%s %s)" % [phase, p.i, p.steps.size(), p.wait, p.wait_arg])
	if phase == "trim":
		var kept: Array = []
		for k in steps.size():
			if not dropped.has(k): kept.append(steps[k])
		print("TRIM %s dropped %d cuts %s; kept %d %s" % [ship, dropped.size(), str(dropped.map(func(k): return str(steps[k].key)).slice(0, 8)), kept.size(), _count(kept)])
		if kept.is_empty():
			return _fail("no step left after trimming")
		steps = kept
		_write(steps)
		_replay_start("verify")
		return false
	var cuts := steps.filter(func(s): return s.get("do","") == "cut").size()
	_out("PASS", "%d steps (%d safety, %d cuts, %d cuts dropped), replay %d s" % [steps.size(), steps.size() - cuts, cuts, dropped.size(), frame / 60])
	return true

func _fail(why: String) -> bool:
	# a plan that does not replay is not shipped
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Codex.DIR + ship + ".json"))
	_out("FAIL", why)
	return true
