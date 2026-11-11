extends "res://tests/guide_check.gd"
# 相位接驳 (user 2026-11-11): the shuttle running through the freight trains, drawn tunnelling. The camera
# rides with the shuttle on a mended port with the freight at work; every crossing is logged by frame
# ("CROSS in/out f=N") so tools/cut can keep the 15 s with the most of them; three stills from the first
# good crossing (going in, inside, coming out). Test saves only.
#   tools/run_test.sh tests/record_phase_shuttle.gd --write-movie <dir>/phase.avi --fixed-fps 30 [-- secs=60]
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_phase_career.json"
	SaveGame.path = "user://zp_test_record_phase_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return float(a.substr(k.length() + 1))
	return d


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.tram_found = ["ring", "salvage", "trade", "process", "cargo", "tug", "power"]
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.save()
	await _spawn()
	g.freight.card.probe = Vector2(-1e7, -1e7)
	FW.on = true
	W.demo = true
	var M := Geom.M
	var fx = g.tram.phase_fx
	var secs := _arg("secs", 60.0)
	var stops: Array = ["ring", "cargo", "process", "trade", "power", "tug", "salvage"]
	var si := 0
	var f := 0
	var was_in := false
	var shots := 0
	var in_f := -1
	var zoom := 1920.0 / (34.0 * M)
	g.cam_pos = g.tram.position_px
	g.zoom_now = zoom
	while f < int(secs * 30.0):
		# ride on: the drone aboard from stop to stop
		if g.tram.phase == "":
			var here: String = str(g.tram.at) if str(g.tram.at) != "" else "ring"
			var to: String = stops[si % stops.size()]
			si += 1
			if to == here:
				to = stops[si % stops.size()]
				si += 1
			g.drone.global_position = Tram.station_at(here) + Tram.platform_side(here) * 1.2 * M
			g.drone.linear_velocity = Vector2.ZERO
			g.tram.call_to(here, to)
		var at: Vector2 = g.tram.position_px
		g.cam_override = at
		g.zoom_override = zoom
		g.cam_pos = (g.cam_pos as Vector2).lerp(at, 0.25)
		g.zoom_now = zoom
		g.cam_vel = Vector2.ZERO
		await process_frame
		f += 1
		var now_in: bool = fx.inside
		if now_in and not was_in:
			print("CROSS in f=%d" % f)
			in_f = f
		elif was_in and not now_in:
			print("CROSS out f=%d (%d frames)" % [f, f - in_f])
			if shots == 1:
				await _shot("3_out")
				shots = 2
		was_in = now_in
		if now_in and shots == 0 and f - in_f == 4:
			await _shot("1_in")
		if now_in and shots == 0 and f - in_f == 14:
			await _shot("2_inside")
			shots = 1
	print("record_phase_shuttle: %d frames, crossings %d" % [f, preload("res://scripts/tram_phase_fx.gd").crossings])
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := "user://shots_phase"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(dir + "/" + name + ".png")
	print("  shot: ", ProjectSettings.globalize_path(dir + "/" + name + ".png"))
