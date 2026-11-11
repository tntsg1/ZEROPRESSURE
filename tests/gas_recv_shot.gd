extends "res://tests/guide_check.gd"
# The berth's gas recovery receiver and its run (2026-11-11, user: "为什么这里的这个箱子在这里呢？它难道
# 不应该是在底下吗？"): the empty berth and a ship being stripped, the same framing before / after.
#   tools/run_test.sh tests/gas_recv_shot.gd --fixed-fps 60 -- tag=before|after mode=empty|strip


func _initialize() -> void:
	Career.path = "user://zp_test_gas_recv_career.json"
	SaveGame.path = "user://zp_test_gas_recv_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true, "gas_flow_film": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	if not Career.data.has("upgrades"):
		Career.data.upgrades = {}
	Career.data.upgrades["gas_line"] = true
	Career.data.upgrades["lox_tank"] = true
	Career.save()
	var mode := _arg("mode", "empty")
	if mode == "strip":
		Game.contract = {"id": "RECV-1", "ship": "m14"}
		Game.start_ship = "m14"
	else:
		Game.contract = {}
		Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	var w := 0
	while str(g.state) != "play" and w < 60 * 25:
		await process_frame
		w += 1
	var M := PortStructure.M()
	var c := PortStructure.centre()
	g.drone.global_position = c + Vector2(-20.0, 128.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	for v in [["near", Vector2(-30.0, 138.0), 14.0], ["wide", Vector2(-40.0, 110.0), 6.0]]:
		g.cam_override = c + (v[1] as Vector2) * M
		g.zoom_override = float(v[2]) / M
		g.cam_pos = g.cam_override
		g.zoom_now = g.zoom_override
		await _frames(30)
		Cap.save(root, "res://tests/out/gasrecv_%s_%s_%s.png" % [mode, v[0], _arg("tag", "after")])
	g.queue_free()
	quit(0)
