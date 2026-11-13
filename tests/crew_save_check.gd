extends SceneTree
# 2026-11-12 (60 FPS is a release gate): the crew saved the whole career at every step of a job — on a
# real 1 MB career 50 ms a frame, seven times a job. Now each step goes to the works journal off the
# main thread (Career.keep_works). On a COPY of a big career (`big=<user:// file>`, or the test's own
# small one when there is none):
#   A  the longest frame of a lights job: the old way (Career.journal_off) and the journal
#   B  quit mid-job (no whole save after the order): read back, the step reached is there, and the
#      crew goes on from it
#   C  a damaged journal, another order's journal: ignored, the career as saved; a journal left as .tmp
#      by a crash mid-rename: read
#   D  the job done and the career read back: the facility the berth's, no job left
# Own test files only (the real career is only ever copied from).
#   godot --headless --path . --fixed-fps 60 -s tests/crew_save_check.gd -- big=user://zeropower_career.json

const Crew = preload("res://scripts/crew.gd")
const FILE := "user://zp_test_crew_save_career.json"
var fails := 0
var g
var base: Dictionary = {}


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = FILE
	SaveGame.path = "user://zp_test_crew_save_save.json"
	SaveGame.allow_test = true
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for ext in ["", ".bak", ".tmp", ".works", ".works.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE + ext))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _step() -> String:
	var j := Works.current()
	return "" if j.is_empty() else str(WorksPlan.at(j)[1])


# a fresh copy of the career with a lights job just ordered, saved whole (as Works.order_repair does)
func _order() -> void:
	Career.data = base.duplicate(true)
	Career.data.upgrades.erase("lights")
	Career.data.erase("works")
	Career.data.works = {"id": "lights", "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0, "jr": Works.token()}
	Career.save()


func _berth() -> void:
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null


# the job run to its end (or until `stop` says so): [the longest frame while the crew worked after
# its first two seconds (the scene still settling), the longest frame a step changed on] (ms)
var _worst_step := 0.0
var _worst_step_crew := 0.0   # the crew's own ms on a step's change (not the last: the completion)
var _done_ms := 0.0           # the frame the job was done on
func _work(stop: Callable = Callable()) -> float:
	var worst := 0.0
	_worst_step = 0.0
	_worst_step_crew = 0.0
	_done_ms = 0.0
	var last := Time.get_ticks_usec()
	var was := _step()
	for k in 60 * 120:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if k > 120:
			worst = maxf(worst, ms)
		var crew_ms: float = (Crew.prof_us + Crew.CrewDrone.prof_us) / 1000.0
		Crew.prof_us = 0
		Crew.CrewDrone.prof_us = 0
		if _step() != was:
			if "trace" in OS.get_cmdline_user_args():
				print("    step %s -> %s: frame %.1f ms, the crew's own %.1f ms" % [was, _step(), ms, crew_ms])
			was = _step()
			if was == "":
				_done_ms = ms
			else:
				_worst_step = maxf(_worst_step, ms)
				_worst_step_crew = maxf(_worst_step_crew, crew_ms)
		if not Works.busy():
			break
		if stop.is_valid() and stop.call():
			break
	return worst


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	var src := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("big="):
			src = a.substr(4)
	if src != "" and FileAccess.file_exists(src):
		base = SaveGame.read_career(src)
	if base.is_empty():
		Career.start_new()
		DevPanel.skip_guides()
		base = Career.data.duplicate(true)
	print("  career: %d KB as JSON" % (JSON.stringify(base).length() / 1024))

	# ---- A: the longest frame, the old way and the journal
	var worst := {}
	var at_step := {}
	var crew_step := {}
	var done_ms := {}
	for mode in ["old", "journal"]:
		Career.journal_off = mode == "old"
		_order()
		await _berth()
		worst[mode] = await _work()
		at_step[mode] = _worst_step
		crew_step[mode] = _worst_step_crew
		done_ms[mode] = _done_ms
		check(not Works.busy() and Career.data.upgrades.has("lights"), "A %s: the job done" % mode)
		g.queue_free()
		await _frames(3)
	Career.journal_off = false
	Career.journal_flush()
	print("  A longest frame while the crew worked: whole save each step %.1f ms | journal %.1f ms" % [worst.old, worst.journal])
	print("  A longest frame a step changed on:      whole save each step %.1f ms (the crew's own %.1f) | journal %.1f ms (the crew's own %.1f)" % [at_step.old, crew_step.old, at_step.journal, crew_step.journal])
	print("  A the frame the job was done on:        whole save each step %.1f ms | journal %.1f ms" % [done_ms.old, done_ms.journal])
	# a whole save of a small career is ~4 ms, lost in the step's own work: judged on a big one only
	if JSON.stringify(base).length() > 200 * 1024:
		# relative: a loaded machine (or a low-priority run) stretches every number alike
		check(crew_step.journal < crew_step.old * 0.2, "A a step's change: the crew's own work that frame a fifth of the old way or less (%.1f ms, was %.1f)" % [crew_step.journal, crew_step.old])
	else:
		print("  A (a small career: the step frames not judged; run with big=<copy of a real career>)")

	# ---- B: quit mid-job, read back
	_order()
	Career.save_trace = true
	Career.save_trace_print = "trace" in OS.get_cmdline_user_args()
	Career.save_log.clear()
	await _berth()
	await _work(func(): return _step() == "fasten")
	var reached := int(Works.current().get("step", -1))
	Career.save_trace = false
	Career.journal_flush()
	g.queue_free()
	await _frames(3)
	Career.data = {}
	Career.load_or_new()
	var w: Dictionary = Career.data.get("works", {})
	check(reached >= 3 and int(w.get("step", -1)) == reached, "B quit at a later step (%d): read back at it (%d)" % [reached, int(w.get("step", -1))])
	var on_disk := SaveGame.read_career(FILE)
	# (other berth systems still save the whole career now and then; the crew itself no more)
	var by_crew: int = Career.save_log.count("res://scripts/crew.gd")
	check(by_crew == 0, "B the crew saved the whole career %d times through %d steps (whole saves by others: %d)" % [by_crew, reached, Career.save_log.size()])
	await _berth()
	await _frames(10)
	check(_step() == "fasten" and g.crew.parts.size() == 2 and g.crew.parts.all(func(p): return p.body != null and p.body.freeze), "B the crew goes on from the fastening, the parts on their seats")
	g.queue_free()
	await _frames(3)

	# ---- C: damaged, another order's, a .tmp left over
	var jp := Career.journal_path()
	var good := FileAccess.get_file_as_string(jp)
	var f := FileAccess.open(jp, FileAccess.WRITE)
	f.store_string(good.substr(0, good.length() / 2))
	f.close()
	Career.data = {}
	Career.load_or_new()
	check(int(Career.data.works.get("step", -1)) == int(on_disk.works.get("step", -1)), "C a damaged journal: ignored, the career as saved (step %d)" % int(Career.data.works.get("step", -1)))
	# another order of the same job (a new token): the old journal is not its
	f = FileAccess.open(jp, FileAccess.WRITE)
	f.store_string(good)
	f.close()
	var d2 := SaveGame.read_career(FILE)
	d2.works.jr = Works.token() + "x"
	SaveGame.write_file(FILE, d2)
	Career.data = {}
	Career.load_or_new()
	check(int(Career.data.works.get("step", -1)) == int(d2.works.get("step", -1)), "C another order's journal: ignored")
	# the crash between removing the journal and renaming its .tmp: the .tmp is read
	d2.works.jr = on_disk.works.jr
	SaveGame.write_file(FILE, d2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jp))
	f = FileAccess.open(jp + ".tmp", FileAccess.WRITE)
	f.store_string(good)
	f.close()
	Career.data = {}
	Career.load_or_new()
	check(int(Career.data.works.get("step", -1)) == reached, "C only the journal's .tmp left: read (step %d)" % int(Career.data.works.get("step", -1)))

	# ---- D: done, read back
	await _berth()
	await _work()
	check(not Works.busy(), "D the job done")
	g.queue_free()
	await _frames(3)
	Career.journal_flush()
	Career.data = {}
	Career.load_or_new()
	check(Career.data.upgrades.has("lights") and not Career.data.has("works"), "D read back: the lights the berth's, no job left (the stale journal changes nothing)")
	check(not (Career.data.get("repaired_pending", []) as Array).has("lights"), "D not left on the repaired list (one whole save at the end)")

	Crew.in_tests = false
	Career.journal_flush()
	_clean()
	print("CREW_SAVE %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
