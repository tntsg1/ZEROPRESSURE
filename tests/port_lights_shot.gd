extends SceneTree
# 港区外部灯光方案: the trade and power districts' outsides, the same cameras, under each of
# PortArt.light_scheme 0 (as it was) .. 4. Own test saves only.
#   tools/run_test.sh tests/port_lights_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_portlights_career.json"
	SaveGame.path = "user://zp_test_portlights_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "gr7"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "port-lights", "ship": "gr7"}
	for i in 50: await process_frame
	g.tutorial = null
	g.drone.global_position = Vector2(-20, -20) * Geom.M
	var tb: Rect2 = PortStructure.box("trade")
	var pb: Rect2 = PortStructure.box("power")
	var hub := PortStructure.centre()
	var both := tb.merge(pb).merge(Rect2(hub, Vector2.ONE))
	var views := [["trade_near", 0.22, tb.get_center()], ["power_near", 0.22, pb.get_center()],
		["right_far", minf(1920.0 * 0.9 / both.size.x, 1080.0 * 0.9 / both.size.y), both.get_center()]]
	var tidy := "tidy" in OS.get_cmdline_user_args()
	for sc in (3 if tidy else 5):
		if tidy:
			PortArt.hull_style = sc
		else:
			PortArt.light_scheme = sc
		for v in views:
			for i in 40:
				g.cam_override = v[2]; g.zoom_override = v[1]; g.zoom_now = v[1]; g.cam_pos = v[2]
				await process_frame
			Cap.save(root, "res://tests/out/%s_%d_%s.png" % ["porttidy" if tidy else "portlights", sc, v[0]])
		print("scheme %d" % sc)
	PortArt.light_scheme = 0
	PortArt.hull_style = 0
	g.queue_free()
	for i in 6: await process_frame
	quit(0)
