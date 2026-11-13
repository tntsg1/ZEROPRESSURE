extends SceneTree
# Keyframes of the works crew (2026-11-12 user: "施工队的动画确实需要搞一下"): the lights and the furnace
# repairs in the berth, a still at each beat, the seconds each step took. For the before / after
# comparison: `tag=before` or `tag=after` (tests/out/crew_anim/<tag>_<job>_<n>.png), `job=lights`
# or `job=furnace_main` (both when not given). Own test saves only; no focus, no mouse.
#   tools/run_test.sh tests/crew_anim_shot.gd --fixed-fps 60 -- tag=after

const Cap = preload("res://tests/cap.gd")
const Crew = preload("res://scripts/crew.gd")
var g
var tag := "now"
var _n := 0
var _times := {}
var _last_step := ""
var _step_t0 := 0


func _initialize() -> void:
	Career.path = "user://zp_test_crew_anim_career.json"
	SaveGame.path = "user://zp_test_crew_anim_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _step() -> String:
	var j := Works.current()
	return "" if j.is_empty() else str(WorksPlan.at(j)[1])


var _frame := 0
var _ms: Array = []        # each frame's process + physics time (ms) while it is recorded
var _rec := false
var _wall: Array = []      # each frame's wall time (ms)
var _last_us := 0
func _tick() -> void:
	_frame += 1
	if _rec:
		var now := Time.get_ticks_usec()
		_ms.append((Crew.prof_us + Crew.CrewDrone.prof_us) / 1000.0)
		_wall.append((now - _last_us) / 1000.0)
	Crew.prof_us = 0
	Crew.CrewDrone.prof_us = 0
	_last_us = Time.get_ticks_usec()
	var s := _step()
	if s != _last_step:
		if _last_step != "":
			_times[_last_step] = (_frame - _step_t0) / 60.0
		_last_step = s
		_step_t0 = _frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		_tick()


func _until(f: Callable, max_s: float = 60.0) -> void:
	for k in int(60 * max_s):
		await process_frame
		_tick()
		if f.call():
			return


func _shot(job: String, what: String) -> void:
	_n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out/crew_anim"))
	Cap.save(root, "res://tests/out/crew_anim/%s_%s_%d_%s.png" % [tag, job, _n, what])


func _drone(role: String):
	return g.crew.drones.get(role)


func _job(id: String) -> void:
	_n = 0
	_times = {}
	_last_step = ""
	_frame = 0
	Career.data.upgrades.erase(id)
	Career.data.works = {"id": id, "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var seat: Vector2 = g.crew.seat()
	g.drone.global_position = seat + Vector2(-9.0, 4.0) * Geom.M
	g.cam_override = seat + Vector2(-1.0, 0.5) * Geom.M
	g.zoom_override = 1.25
	await _frames(70)
	var t0 := _frame
	_ms = []
	_wall = []
	_rec = true
	await _until(func(): var b = _drone("bot"); return b != null and b.tool)
	await _frames(20)
	_shot(id, "isolate")
	await _until(func(): return g.crew.tagged)
	await _frames(40)
	_shot(id, "tagged")
	await _until(func(): var c = _drone("cutter"); return c != null and c.tool)
	await _frames(40)
	_shot(id, "cut")
	await _until(func(): var h = _drone("hauler"); return h != null and h.load != null)
	await _frames(50)
	_shot(id, "haul")
	await _until(func(): return _step() == "bring")
	await _frames(150)
	_shot(id, "bring")
	await _until(func(): var h = _drone("hauler"); return _step() == "lift" and h != null and h.load != null)
	await _frames(60)
	_shot(id, "lift")
	await _until(func(): return _step() == "fasten")
	await _frames(20)
	_shot(id, "seated")
	await _frames(70)
	_shot(id, "fasten")
	await _until(func(): return _step() == "connect")
	await _frames(150)
	_shot(id, "connect")
	await _until(func(): return _step() == "test")
	await _frames(90)
	_shot(id, "test")
	await _until(func(): return not Works.busy(), 90.0)
	var total := (_frame - t0) / 60.0
	var busy_ms := _stats(_ms)
	var busy_wall := _stats(_wall)
	await _frames(40)
	_shot(id, "done")
	# the same berth, the same view, the crew gone: the baseline
	_ms = []
	_wall = []
	await _frames(600)
	_rec = false
	var idle_wall := _stats(_wall)
	print("  %s: %.1f s on site, steps %s" % [id, total, _times])
	print("  %s crew's own code ms/frame: mean %.3f p95 %.3f p99 %.3f max %.3f" % [id, busy_ms[0], busy_ms[1], busy_ms[2], busy_ms[3]])
	print("  %s wall ms/frame: crew at work mean %.2f p95 %.2f p99 %.2f | crew gone mean %.2f p95 %.2f p99 %.2f" % [id, busy_wall[0], busy_wall[1], busy_wall[2], idle_wall[0], idle_wall[1], idle_wall[2]])
	g.queue_free()
	await _frames(3)


func _stats(a: Array) -> Array:
	if a.is_empty():
		return [0.0, 0.0, 0.0, 0.0]
	var b := a.duplicate()
	b.sort()
	var sum := 0.0
	for v in b:
		sum += v
	return [sum / b.size(), b[int(b.size() * 0.95)], b[int(b.size() * 0.99)], b[b.size() - 1]]


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	tag = _arg("tag", "now")
	Career.start_new()
	DevPanel.skip_guides()
	Career.save()
	var only := _arg("job", "")
	for id in ["lights", "furnace_main"]:
		if only == "" or only == id:
			await _job(id)
	Crew.in_tests = false
	SaveGame.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
