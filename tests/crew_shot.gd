extends SceneTree
# Stills of the works crew at work (92 号): the lights repair in the berth, one at each step —
# the tag going on, the cutter at a weld, the wreck on the tether, the new lamp on the boat's hook,
# set on its seat, the bolts, the cable, the test. Writes tests/out/crew_*.png. Own saves only.
#   tools/run_test.sh tests/crew_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const Crew = preload("res://scripts/crew.gd")
var g


func _initialize() -> void:
	Career.path = "user://zp_test_crew_shot_career.json"
	SaveGame.path = "user://zp_test_crew_shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _step() -> String:
	var j := Works.current()
	return "" if j.is_empty() else str(WorksPlan.at(j)[1])


# wait until the condition, or a minute
func _until(f: Callable) -> void:
	for k in 60 * 60:
		await process_frame
		if f.call():
			return


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	Career.start_new()
	DevPanel.skip_guides()
	Career.data.upgrades.erase("lights")
	Career.data.works = {"id": "lights", "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	g.drone.global_position = g.crew.seat() + Vector2(-9.0, 4.0) * Geom.M
	g.cam_override = g.crew.seat() + Vector2(-1.0, 1.5) * Geom.M
	g.zoom_override = 0.95
	await _until(func(): return g.crew.tagged)
	await _frames(20)
	Cap.save(root, "res://tests/out/crew_1_isolate.png")
	await _until(func(): var c = g.crew.drones.get("cutter"); return c != null and c.tool)
	await _frames(40)
	Cap.save(root, "res://tests/out/crew_2_cut.png")
	await _until(func(): var h = g.crew.drones.get("hauler"); return h != null and h.load != null)
	await _frames(70)
	g.cam_override = g.crew.drones["hauler"].global_position + Vector2(0, 2.0 * Geom.M)
	await _frames(10)
	Cap.save(root, "res://tests/out/crew_3_haul.png")
	g.cam_override = g.crew.seat() + Vector2(-1.0, -1.0) * Geom.M
	await _until(func(): return _step() == "lift")
	await _frames(30)
	Cap.save(root, "res://tests/out/crew_4_lift.png")
	await _until(func(): return _step() == "fasten")
	await _frames(90)
	g.cam_override = g.crew.seat() + Vector2(-1.0, 1.0) * Geom.M
	await _frames(5)
	Cap.save(root, "res://tests/out/crew_5_fasten.png")
	await _until(func(): var c = g.crew.drones.get("cable"); return c != null and c.laying)
	await _frames(60)
	Cap.save(root, "res://tests/out/crew_6_cable.png")
	await _until(func(): return _step() == "test")
	await _frames(100)
	Cap.save(root, "res://tests/out/crew_7_test.png")
	await _until(func(): return not Works.busy())
	await _frames(30)
	Cap.save(root, "res://tests/out/crew_8_done.png")
	Crew.in_tests = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
