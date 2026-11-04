extends "res://tests/guide_check.gd"
# 120 号 用户改字（2026-11-04）：拆船区一期在建时的工地牌、主线卡、船坞机器、机体/载荷/导航框名。
# Own test saves only.
#   tools/run_test.sh tests/copy120_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_copy120_career.json"
	SaveGame.path = "user://zp_test_copy120_save.json"
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
	Career.data.money = 2000000.0
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.save()
	var why := Works.order_port("salvage", false)
	print("order: '%s' busy %s" % [why, Works.busy()])
	print("MAIN: " + str(Mainline.step().get("text", "")))
	print("BUSY: " + Works.busy_text())
	await _spawn()
	await _frames(30)
	# well into the job: the fifth step
	var j := Works.current()
	j.left = float(j.total) * 0.12
	await _frames(20)
	print("MAIN late: " + str(Mainline.step().get("text", "")))
	g.cam_override = Works.spot()
	g.zoom_override = 0.7
	await _frames(40)
	Cap.save(root, "res://tests/out/copy120_site.png")
	g.cam_override = null
	g.zoom_override = -1.0
	await _frames(40)
	Cap.save(root, "res://tests/out/copy120_berth.png")
	g.toggle_auto()
	await _frames(20)
	Cap.save(root, "res://tests/out/copy120_auto_off.png")
	print("COPY120 SHOTS DONE")
	quit(0)
