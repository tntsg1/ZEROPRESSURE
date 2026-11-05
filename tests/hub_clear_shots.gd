extends "res://tests/guide_check.gd"
# 129 号: the central ring with the demo flow running, shot when the arms are reaching out — the
# whole hall, and the bottom of the ring (the berth's spoke: its arm, the business console, the
# shuttle stop) and the cargo spoke close up. Same cameras before and after.
#   tools/run_test.sh tests/hub_clear_shots.gd --fixed-fps 60 -- tag=before
const W = preload("res://scripts/hub_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_clear_shots_career.json"
	SaveGame.path = "user://zp_test_hub_clear_shots_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _shot(name: String, at: Vector2, zoom: float) -> void:
	_put(at, zoom)
	await _frames(3)
	var p := "res://tests/out/hub129_%s_%s.png" % [name, _arg("tag", "after")]
	Cap.save(root, p)
	print("  shot " + ProjectSettings.globalize_path(p))


# wait (the machines running) until the arm at `z` is in one of `phases`
func _arm_in(z: String, phases: Array, max_s: float) -> bool:
	for i in int(max_s * 60.0):
		await _frames(1)
		if W.arms.has(z) and str(W.arms[z].phase) in phases:
			return true
	return false


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	await _frames(10)
	var c := PortStructure.centre()
	var M := PortStructure.M()
	# the drone out of the way, on the far side of the hall
	g.drone.global_position = c + Vector2(-14.0, -17.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	W.demo = true
	W._flow_scan = 0.0
	_put(c, 0.55)
	# a crate held over the berth's hatch, then the arm reaching for its cradle
	var ok1: bool = await _arm_in("salvage", ["hold", "lift_hatch"], 120.0)
	await _shot("hall_hold", c, 0.55)
	await _shot("bottom_hold", c + Vector2(0.0, 15.0) * M, 1.1)
	var ok2: bool = await _arm_in("salvage", ["lower_cradle", "set_cradle", "grip_cradle"], 120.0)
	await _shot("hall_reach", c, 0.55)
	await _shot("bottom_reach", c + Vector2(0.0, 15.0) * M, 1.1)
	var cargo_a: float = ((PortStructure.door("cargo")[0] as Vector2) - c).angle()
	var ok3: bool = await _arm_in("cargo", ["hold", "lift_hatch", "to_cradle"], 120.0)
	await _shot("cargo", c + Vector2.from_angle(cargo_a) * 15.0 * M, 1.1)
	print("  moments found: %s %s %s" % [ok1, ok2, ok3])
	W.demo = false
	g.queue_free()
	await _frames(4)
	quit(0)
