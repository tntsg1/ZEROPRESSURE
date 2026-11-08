extends "res://tests/guide_check.gd"
# 128 号 第 6 段: F12 开发者工作台 → “显示碰撞”. The card is on the workbench; pressing it turns the
# view on (every body the drone can hit is found and drawn), the workbench closed the view stays on
# over the berth; pressed again it goes off; "退出开发模式" turns it off too. Own test saves only.
#   tools/run_test.sh tests/collision_view_check.gd --fixed-fps 60

const CV = preload("res://scripts/collision_view.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_colview_career.json"
	SaveGame.path = "user://zp_test_colview_save.json"
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
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(20)
	var dev: DevPanel = g.find_children("*", "DevPanel", true, false)[0]
	Txt.dev = true
	dev.set_open(true)
	await _frames(5)
	var b: Button = dev.bench.buttons.get("dev_collision")
	check(b != null and not CV.on, "the workbench has the 显示碰撞 card, off")
	b.pressed.emit()
	await _frames(5)
	var b2: Button = dev.bench.buttons.get("dev_collision")
	check(CV.on and b2 != null and b2.text.contains("已开启"), "pressed: on, the card says so")
	Cap.save(root, "res://tests/out/collision_view_bench.png")
	dev.set_open(false)
	await _frames(10)
	var v = g.get_node_or_null("CollisionView")
	check(v != null and v._bodies.size() >= 2, "the berth's bodies are found (%d)" % (v._bodies.size() if v != null else -1))
	var names := ""
	for bd in v._bodies:
		names += str(bd.name) + " "
	check(names.contains("PortWalls"), "the port's walls are among them")
	check(not v._bodies.has(g.drone), "the drone itself is left out")
	Cap.save(root, "res://tests/out/collision_view_on.png")
	dev.set_open(true)
	await _frames(5)
	dev.bench.buttons.get("dev_collision").pressed.emit()
	await _frames(5)
	check(not CV.on, "pressed again: off")
	dev.bench.buttons.get("dev_collision").pressed.emit()
	await _frames(3)
	dev.disable()
	await _frames(5)
	check(not CV.on, "退出开发模式 turns it off too")
	g.queue_free()
	await _frames(4)
	print("COLLISION VIEW %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
