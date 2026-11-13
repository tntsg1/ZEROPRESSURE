extends SceneTree
# Where the crew's time goes (2026-11-12): each action of a job, how long it took. Own saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/crew_pace_probe.gd -- job=lights

const Crew = preload("res://scripts/crew.gd")
var g


func _initialize() -> void:
	Career.path = "user://zp_test_crew_pace_career.json"
	SaveGame.path = "user://zp_test_crew_pace_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	var id := "lights"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("job="):
			id = a.substr(4)
	Career.start_new()
	DevPanel.skip_guides()
	Career.data.upgrades.erase(id)
	Career.data.works = {"id": id, "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
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
	var t0 := 0
	var f := 0
	var worst := 0
	var sum := 0
	var sum_c := 0
	while Works.busy() and f < 60 * 200:
		Crew.prof_us = 0
		Crew.CrewDrone.prof_us = 0
		await process_frame
		var us: int = Crew.prof_us + Crew.CrewDrone.prof_us
		sum += us
		sum_c += Crew.prof_us
		if us > worst:
			worst = us
			print("    new worst %.2f ms at %s" % [us / 1000.0, "" if g.crew.queue.is_empty() else str(g.crew.queue[0].do)])
		f += 1
		var q: Array = g.crew.queue
		var now := "" if q.is_empty() else "%s/%s" % [WorksPlan.at(Works.current())[1], q[0].do]
		if now != last:
			if last != "":
				print("  %6.2f s  %s" % [(f - t0) / 60.0, last])
			last = now
			t0 = f
	print("  total %.1f s, swallowed %d carried %d, crew logic mean %.3f ms (crew %.3f, drones %.3f) max %.2f ms" % [f / 60.0, g.crew.swallowed, g.crew.carried, sum / 1000.0 / maxf(1, f), sum_c / 1000.0 / maxf(1, f), (sum - sum_c) / 1000.0 / maxf(1, f), worst / 1000.0])
	Crew.in_tests = false
	SaveGame.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
