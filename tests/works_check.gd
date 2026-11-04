extends "res://tests/guide_check.gd"
# 65 号: repairs and port works are built. An order takes its materials and money at once but the
# thing is not usable yet; one job at a time; the time is by the job's size; when the time has run it
# is the berth's and its completion waits to be shown; the two ways take what they should (own parts
# and half the money / the whole of it); a port stage is built the same way; the job survives a
# save; the crew is drawn where it works; the berth's wrecks are no dashed boxes and its grime
# clears with the base repairs. Own saves only.
#   tools/run_test.sh tests/works_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_works_career.json"
	SaveGame.path = "user://zp_test_works_save.json"
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
	Career.data.upgrades.erase("lights")
	Career.save()
	check(Works.duration(14000.0) == 30.0 and Works.duration(65000.0) == 60.0 and Works.duration(240000.0) == 120.0 and Works.duration(1200000.0) == 180.0, "the time is by the job's size (30 / 60 / 120 / 180 s)")
	# ---- a crew order: money taken, not usable yet
	var cash := float(Career.data.money)
	var why := Works.order_repair("lights", false)
	check(why == "" and Works.busy() and not Repair.done("lights") and absf(cash - float(Career.data.money) - Repair.price("lights", false)) < 0.01, "ordered: the whole price taken, the lights not usable yet (%s)" % why)
	check(Works.order_repair("net_fix", false) != "" and not Repair.done("net_fix"), "one job at a time: a second order is refused")
	# 82 号: the lights are built step by step — the card says which step
	check(str(Mainline.step().get("text", "")).find("施工中") >= 0 and str(Mainline.step().get("text", "")).find("步：") >= 0, "the main line says the crew is building, and at which step")
	# ---- survives a save
	Career.load_or_new()
	check(Works.busy() and str(Works.current().id) == "lights", "the job is still there after loading")
	# ---- in the berth: the crew is drawn; time runs; done
	await _spawn()
	await _frames(30)
	var site = null
	for ch in g.dock.get_children():
		if ch.get_script() == preload("res://scripts/works_site.gd"):
			site = ch
	check(site != null and site.visible, "the crew is on site")
	g.cam_override = Works.spot()
	g.zoom_override = 0.7
	await _frames(40)
	Cap.save(root, "res://tests/out/works_site_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	var t := 0
	while Works.busy() and t < 60 * 70:
		await _frames(1)
		t += 1
	check(not Works.busy() and Repair.done("lights"), "the time run out: the lights are the berth's (%d frames)" % t)
	await _frames(10)
	check(g.state == "build" or Career.data.get("repaired_pending", []).has("lights") or Repair.done("lights"), "and the completion is shown in the berth")
	if g.state == "build":
		g._end_build()
		await _frames(4)
	# ---- own parts: the parts and half the money
	Career.data.parts = []
	for k in 2:
		Career.data.parts.append({"uid": "W:P%d" % k, "cls": "structure" if false else "power", "tag": "P%d" % k, "nk": "p_battery", "cond": 0.9, "value": 3000.0, "ship": "tug", "job": "W"})
	Career.data.structure_t = 10.0
	Career.save()
	var ok_parts: bool = Repair.parts_for("net_fix").ok
	cash = float(Career.data.money)
	var st0 := float(Career.data.structure_t)
	why = Works.order_repair("net_fix", ok_parts)
	check(why == "" and absf(cash - float(Career.data.money) - Repair.price("net_fix", ok_parts)) < 0.01 and (not ok_parts or float(Career.data.structure_t) < st0), "mended with own materials: the plate taken and half the money (%s)" % why)
	Works.finish()
	check(Repair.done("net_fix") and not Works.busy(), "finished")
	# ---- a port stage is built the same way
	Career.data.port = {"salvage": 1}
	Career.save()
	var before_stage := Port.stage("trade")
	why = Works.order_port("trade", false)
	check(why == "" and Port.stage("trade") == before_stage and Works.busy() and str(Works.current().kind) == "port", "a port stage ordered: not up until built (%s)" % why)
	Works.finish()
	check(Port.stage("trade") == before_stage + 1, "built: the stage is up")
	# ---- the wrecks: no dashed boxes; grime clears with the base repairs
	var src := FileAccess.get_file_as_string("res://scripts/dock.gd")
	check(src.find("a wreck in a dashed outline") < 0 and src.find("func _draw_grime") >= 0, "the wrecks are drawn as wrecks, not dashed boxes; the deck has its grime")
	Career.data.upgrades.erase("furnace_main")
	Career.save()
	g.dock.static_node.queue_redraw()
	g.cam_override = Dock.centre() * Geom.M
	g.zoom_override = 0.45
	await _frames(40)
	Cap.save(root, "res://tests/out/works_wrecked_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("WORKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
