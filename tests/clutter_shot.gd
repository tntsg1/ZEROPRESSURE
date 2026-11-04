extends SceneTree
# 117 号 信息清理：每艘船的拆解现场拍两张（维护工具指着核心资产、激光在它旁边切），看压字和重复。
# Own test saves only.
#   tools/run_test.sh tests/clutter_shot.gd --fixed-fps 60 -- [ship ...] [tag=before]
const Cap = preload("res://tests/cap.gd")
const CoreAsset = preload("res://scripts/core_asset.gd")
const DEFAULT := ["tug", "pod", "s09", "gr7", "h22", "jd38", "qc30", "st40", "nr95", "m14"]


func _initialize() -> void:
	Career.path = "user://zp_test_clutter_career.json"
	SaveGame.path = "user://zp_test_clutter_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _park(g, at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _target(g):
	for gr in CoreAsset.spec(g).get("groups", []):
		for t in gr.tags:
			var p = g.world.tag(str(t))
			if p != null and p.body == null:
				return p
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.cls == "equip" and p.body == null:
			return p
	return null


func _run() -> void:
	var ships: Array = []
	var tag := "before"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		else:
			ships.append(a)
	if ships.is_empty():
		ships = DEFAULT
	Txt.zh = true
	for sid in ships:
		Career.data = Career.fresh()
		Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
		Career.save()
		Game.contract = {}
		Game.start_ship = sid
		var g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(10)
		g.job = {"id": "clutter-shot", "ship": sid}
		await _frames(50)
		g.tutorial = null
		var p = _target(g)
		if p == null:
			print("SKIP %s: nothing to aim at" % sid)
			g.queue_free()
			await _frames(4)
			continue
		var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
		# the wrench on the asset
		g.tools.tool = 4
		g.bot.aim = at
		for i in 60:
			_park(g, at + Vector2(-4.0, -3.0) * Geom.M)
			await process_frame
		Cap.save(root, "res://tests/out/clutter_%s_%s_a.png" % [tag, sid])
		# the laser a metre and a half off it, cutting
		g.tools.tool = 2
		g.bot.aim = at + Vector2(0.0, -1.6) * Geom.M
		g.bot.lmb = true
		for i in 30:
			_park(g, at + Vector2(-4.0, -3.0) * Geom.M)
			await process_frame
		g.bot.lmb = false
		Cap.save(root, "res://tests/out/clutter_%s_%s_b.png" % [tag, sid])
		print("shot %s" % sid)
		g.queue_free()
		await _frames(6)
	quit(0)
