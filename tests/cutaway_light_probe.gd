extends SceneTree
# 工业剖面 v2：工作灯 / 指示灯 / 发动机余热照到旁边结构。强制打开所有舱室并点亮，拍开关前后。
# Own test saves only.   tools/run_test.sh tests/cutaway_light_probe.gd --fixed-fps 60 -- [ship=gr7]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_cutlight_career.json"
	SaveGame.path = "user://zp_test_cutlight_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	var sid := "gr7"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "cutlight-probe", "ship": sid}
	for i in 50: await process_frame
	g.tutorial = null
	for n in g.world.rooms:
		g.world.rooms[n].revealed = true
		g.world.rooms[n].reveal_t = 1.0
		g.world.rooms[n].lit = true
	var lamps: Dictionary = g.ship.get("power", {}).get("lamps", {})
	for n in lamps:
		var l = g.world.tag(lamps[n])
		if l != null:
			l.set_meta("lit", true)
	var c := Vector2.ZERO
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.art == "eng_core":
			c = Geom.centroid(p.poly) + Vector2(-8.0, 0.0) * Geom.M
	for tag in ["before", "after"]:
		Pal.solid = tag == "after"
		g.world.redraw_all(true)
		for i in 40:
			g.cam_override = c
			g.zoom_override = Game.CAM_ZOOM
			g.zoom_now = Game.CAM_ZOOM
			g.cam_pos = c
			g.drone.global_position = c + Vector2(-20, -14) * Geom.M
			g.drone.linear_velocity = Vector2.ZERO
			await process_frame
		Cap.save(root, "res://tests/out/cutaway_%s_%s_lit.png" % [tag, sid])
	print("stand sig %d" % g.world.cut_light._sig)
	Pal.solid = false
	g.queue_free()
	for i in 6: await process_frame
	quit(0)
