extends SceneTree
# 工业剖面: how quiet the background is (user 2026-11-10, PS-12 dismantled to 36 %: the back walls'
# and the structure's long horizontal and vertical lines "很花", they drowned the machines and the
# drone). One ship, three states — whole (rooms open), 36 % (the equipment and fittings gone, the
# structure left), half (the lower half's structure gone too) — each in the old picture and at every
# Cutaway.calm level, whole-ship and mid views; plus the line-brightness numbers the pick is judged
# by. Own test saves only.
#   tools/run_test.sh tests/calm_shot.gd --fixed-fps 60 -- [ship=ps12]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_calm_career.json"
	SaveGame.path = "user://zp_test_calm_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _redraw(w) -> void:
	w.redraw_all(true)
	w.dirty_back = true
	w.cover_layer.queue_redraw()
	w.back_layer.queue_redraw()
	w.light_layer.queue_redraw()
	w.line_layer.queue_redraw()


func _run() -> void:
	var sid := "ps12"
	var looks := ["old", "c0", "c1", "c2", "c3"]
	var states := ["full", "p36", "half"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		elif a.begins_with("looks="):
			looks = Array(a.substr(6).split(","))
		elif a.begins_with("states="):
			states = Array(a.substr(7).split(","))
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
	await _frames(10)
	g.job = {"id": "calm-shot", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var w = g.world
	for n in w.rooms:
		w.rooms[n].revealed = true
		w.rooms[n].reveal_t = 1.0
	var bb := Rect2()
	var first := true
	for id in w.order:
		var b := Geom.bbox(w.pieces[id].poly)
		bb = b if first else bb.merge(b)
		first = false
	var mid := bb.get_center().y
	var zw := minf(1920.0 * 0.86 / bb.size.x, 1080.0 * 0.8 / bb.size.y)
	var views := [["whole", zw, bb.get_center()], ["mid", Game.CAM_ZOOM * 0.55, bb.get_center() + Vector2(-bb.size.x * 0.12, 0)]]
	var area_all := 0.0
	for id in w.order:
		area_all += Geom.area(w.pieces[id].poly)
	for state in states:
		if state == "p36" or state == "half":
			# the equipment and the fittings gone (what a salvage takes first)
			for id in w.order:
				var p = w.pieces[id]
				if p.cls in ["equip", "fixture"] or p.kind in ["fixture", "door"]:
					p.gone = true
		if state == "half":
			# the equipment and the lower half's structure gone
			for id in w.order:
				var p = w.pieces[id]
				if p.cls in ["equip", "fixture"] or p.kind in ["fixture", "door"]:
					p.gone = true
			for id in w.order:
				var p = w.pieces[id]
				if Geom.bbox(p.poly).get_center().y > mid + 0.3 * Geom.M:
					p.gone = true
		var gone_a := 0.0
		for id in w.order:
			if w.pieces[id].gone:
				gone_a += Geom.area(w.pieces[id].poly)
		print("%s: %.0f%% of the ship's area taken off" % [state, gone_a / area_all * 100.0])
		for look in looks:
			Pal.solid = look != "old"
			if look != "old":
				Cutaway.calm = int(look.substr(1))
			_redraw(w)
			for v in views:
				for i in 26:
					g.cam_override = v[2]
					g.zoom_override = v[1]
					g.zoom_now = v[1]
					g.cam_pos = v[2]
					g.drone.global_position = v[2] + Vector2(-6, -4) * Geom.M
					g.drone.linear_velocity = Vector2.ZERO
					await process_frame
				Cap.save(root, "res://tests/out/calm_%s_%s_%s_%s.png" % [sid, state, look, v[0]])
	# the numbers the pick is judged by: the background's lines against the foreground's
	Cutaway.calm = Cutaway.CALM
	for lv in 4:
		Cutaway.calm = lv
		print("calm %d: structure line %.2f, frame line %.2f (hull line %.2f; a quarter is %.2f); wall grid %s; hold frames %s" % [lv,
			Cutaway.MATS["structure"][3] * Cutaway._calm_k("structure"), Cutaway.MATS["frame"][3] * Cutaway._calm_k("frame"),
			Pal.T1, Pal.T1 * 0.25, Cutaway.back_grid(1.0), lv < 1])
	Cutaway.calm = Cutaway.CALM
	Pal.solid = false
	g.queue_free()
	await _frames(6)
	quit(0)
