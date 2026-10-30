extends SceneTree
# The crew's hauler never stalls (user 2026-10-28: the torn mesh "一直往上拉，一直拉不起来"; a part
# held still over its seat "等好久才自动放上去"). The net hangs and the furnace throat opens below the
# berth's floor line, so the crew's pieces pass it; the part on the tether is turned upright by the
# steadying torque. Through the net and the furnace repairs: every piece of wreck hauled into the
# furnace (none cleared at the long wait), every part set down well before the 20 s fallback.
# Logs each change of action (and each second with log=1). Own saves only.
#   tools/run_test.sh tests/crew_stall_check.gd --fixed-fps 60 [-- job=net_fix log=1]

const Crew = preload("res://scripts/crew.gd")
var g
var verbose := false
var checks := 0
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_crew_stall_career.json"
	SaveGame.path = "user://zp_test_crew_stall_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	var jobs := ["net_fix", "furnace_main"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("job="):
			jobs = [a.substr(4)]
		if a == "log=1":
			verbose = true
	for job in jobs:
		await _job(job)
	Crew.in_tests = false
	SaveGame.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	print("CREW STALL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _job(job: String) -> void:
	print("== ", job)
	Txt.zh = true
	Crew.in_tests = true
	Career.start_new()
	DevPanel.skip_guides()
	Career.data.upgrades.erase(job)
	Career.data.works = {"id": job, "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	for k in 40:
		await process_frame
	g.tutorial = null
	var last := ""
	var since := 0.0
	var longest := {}
	var done := -1.0
	var nw := 0
	for f in 60 * 240:
		await process_frame
		if not Works.busy():
			done = f / 60.0
			break
		var j := Works.current()
		var step := str(WorksPlan.at(j)[1])
		var c = g.crew
		nw = maxi(nw, c.wreck.size())
		var a: String = str(c.queue[0].do) if not c.queue.is_empty() else "-"
		var key := step + "/" + a + "/" + str(c._busy.get("st", "")) + "/" + str(c._busy.has("j"))
		if key != last:
			print("%6.1f  %s  (%.1f s on the last)" % [f / 60.0, key, since])
			var lk := last.get_slice("/", 1) + "/" + last.get_slice("/", 2)
			longest[lk] = maxf(float(longest.get(lk, 0.0)), since)
			last = key
			since = 0.0
		since += 1.0 / 60.0
		if verbose and f % 60 == 0:
			var hd = c.drones.get("hauler")
			if hd != null:
				var ld = hd.load
				var lp: Vector2 = ld.global_transform * hd.load_pt if ld != null and is_instance_valid(ld) else Vector2.INF
				print("        hauler %s goal %s load %s at %s v %s freeze %s" % [hd.global_position.round(), hd.goal.round() if hd.goal != Vector2.INF else hd.goal, ld != null, lp.round() if lp != Vector2.INF else lp, ld.linear_velocity.round() if ld != null and is_instance_valid(ld) else Vector2.ZERO, ld.freeze if ld != null and is_instance_valid(ld) else false])
				if ld != null and is_instance_valid(ld):
					var cols := []
					for b2 in ld.get_colliding_bodies():
						cols.append(str(b2.name))
					print("        load mass %.3f contacts %s rot %.2f" % [ld.mass, cols, ld.global_rotation])
	var c = g.crew
	check(done > 0.0, "%s: the job done (%.0f s)" % [job, done])
	check(float(longest.get("place/2", 0.0)) < 6.0, "%s: each part set down in %.1f s at most (the fallback is 20 s)" % [job, float(longest.get("place/2", 0.0))])
	check(float(longest.get("haul/1", 0.0)) < 20.0, "%s: each piece of wreck carried in %.1f s at most" % [job, float(longest.get("haul/1", 0.0))])
	check(c.carried == 0 and nw > 0 and c.swallowed == nw, "%s: all %d piece(s) of wreck into the furnace (%d swallowed, %d cleared at the long wait)" % [job, nw, c.swallowed, c.carried])
	g.queue_free()
	for k in 3:
		await process_frame
