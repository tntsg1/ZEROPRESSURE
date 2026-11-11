extends "res://tests/guide_check.gd"
# The hub's loop and its turnouts from above, for a before/after picture (道岔缩短 2026-11-10).
#   tools/run_test.sh tests/turnout_shots.gd --fixed-fps 60 -- <tag>   → tests/out/turnout_<tag>.png
const OUT := "res://tests/out/turnout_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_turnshots_career.json"
	SaveGame.path = "user://zp_test_turnshots_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.save()
	await _spawn()
	await _frames(30)
	var args := OS.get_cmdline_user_args()
	var tag: String = str(args[0]) if not args.is_empty() else "now"
	g.cam_override = PortStructure.centre()
	g.zoom_override = 1080.0 / (72.0 * Geom.M)
	await _frames(90)
	Cap.save(root, OUT % tag)
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	quit(0)
