extends "res://tests/fps108_survey.gd"
# 108 号 帧率: the same views before and after (run once with tag=old against the old files and
# ViewCull off, once with tag=new): the berth, the ring, the processing and cargo districts.
#   tools/run_test.sh tests/fps108_shots.gd --fixed-fps 60 -- tag=new
const Cap = preload("res://tests/cap.gd")


func _run() -> void:
	var tag := "new"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	ViewCull.off = tag == "old"
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 1, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	for pl in [["berth", Dock.centre() * Geom.M], ["ring", Backdrop.port_centre_px()], ["process", PortStructure.console_spot("process")], ["cargo", PortStructure.console_spot("cargo")],
			["tug", PortStructure.console_spot("tug")], ["ring_stop", Tram.station_at("ring")], ["tug_stop", Tram.station_at("tug")], ["process_stop", Tram.station_at("process")]]:
		await _at(pl[1])
		await _frames(60)
		Cap.save(root, "res://tests/out/fps108_%s_%s.png" % [pl[0], tag])
	print("FPS108 SHOTS DONE")
	quit()
