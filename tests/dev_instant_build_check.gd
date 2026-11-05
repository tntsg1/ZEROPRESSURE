extends SceneTree
# The developer workbench's "施工瞬间完成" (user 2026-11-05): with it on, an ordered port works job is
# done on the next tick; off (or out of developer mode) it runs its clock as before. Own test save.
#   godot --headless --path . -s tests/dev_instant_build_check.gd

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("[PASS] " if ok else "[FAIL] ") + what)


func _initialize() -> void:
	Career.path = "user://zp_test_dev_instant_career.json"
	SaveGame.path = "user://zp_test_dev_instant_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 5000000.0
	Career.data.market = true
	Career.save()
	# off: the clock runs
	Txt.dev = true
	DevPanel.instant_build = false
	var why := Works.order_port("cargo", false)
	check(why == "" and Works.busy(), "a port job is ordered (%s)" % why)
	Works.advance(0.5)
	check(Works.busy(), "instant off: still building after 0.5 s")
	# on: done at once
	DevPanel.instant_build = true
	var done := Works.advance(0.016)
	check(done and not Works.busy() and int(Career.data.port.get("cargo", 0)) >= 1, "instant on: done on the next tick (cargo stage %d)" % int(Career.data.port.get("cargo", 0)))
	# out of developer mode it does nothing
	Txt.dev = false
	for z in ["trade", "process", "power", "tug"]:
		why = Works.order_port(z, false)
		if why == "":
			break
	check(why == "" and Works.busy(), "a second job is ordered (%s)" % why)
	Works.advance(0.016)
	check(Works.busy(), "developer mode off: the switch does nothing")
	DevPanel.instant_build = false
	print("DEV INSTANT BUILD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
