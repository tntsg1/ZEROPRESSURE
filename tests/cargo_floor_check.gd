extends "res://tests/guide_check.gd"
# 85 号 (user 2026-10-26: "怎么直接收东西？……我应该搬左边的箱。左边的这个柜台就显示左边柜台的东西"):
# a storage lot taken by hand comes up as crates on the receiving counter, no rent yet; E by a
# crate lifts it; E at the wrong rack's mouth says which side; E at its own sets it down; the last
# one up starts the rent; E at a mouth with nothing hung opens that side's rows only. Own saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/cargo_floor_check.gd --fixed-fps 60
const CF = preload("res://scripts/cargo_floor.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_cargo_floor_career.json"
	SaveGame.path = "user://zp_test_cargo_floor_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _put(p: Vector2) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(6)


func _e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(4)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true}
	Career.data.port = {"salvage": 1, "cargo": 1, "trade": 1}
	Career.data.money = 50000.0
	Career.save()
	Warehouse.set_row(7, "client")
	var o := Depot.new_offer()
	o.t = 12.0
	var r := Depot.accept(str(o.id))
	var l := Depot.lot(str(o.id))
	check(r.ok and int(r.crates) == 3 and str(l.state) == "dock", "taken by hand: 12 t comes as 3 crates on the counter")
	await _spawn()
	await _frames(20)
	var cf = g.cargo_floor
	check(cf != null and cf.visible, "the cargo floor is there")
	g.cam_override = CF.at(Vector2(30, 18))
	g.zoom_override = 0.6
	await _put(CF.at(CF.slot(0)) + Vector2(0, -2.0 * Geom.M))
	await _frames(20)
	Cap.save(root, "res://tests/out/cargo_counter_zh.png")
	var clock0 := float(l.clock)
	Depot.advance(30.0)
	check(is_equal_approx(float(l.clock), clock0), "on the counter the rent does not run")
	for k in 3:
		await _put(CF.at(CF.slot(0)) + Vector2(0, -1.0 * Geom.M))
		await _e()
		check(not cf.held.is_empty(), "crate %d: E by it lifts it" % (k + 1))
		if k == 0:
			await _put(CF.mouth("A"))
			await _e()
			check(not cf.held.is_empty(), "at the left rack's mouth it is kept (it goes on B4, the right)")
			await _put(CF.mouth("B") + Vector2(-6.0 * Geom.M, -2.0 * Geom.M))
			g.drone.linear_velocity = Vector2(6.0 * Geom.M, 0)
			await _frames(30)
			Cap.save(root, "res://tests/out/cargo_carry_zh.png")
		await _put(CF.mouth("B"))
		await _e()
		check(cf.held.is_empty(), "crate %d: set down at the right rack" % (k + 1))
	check(str(l.state) == "stored" and Depot.dock_crates().is_empty(), "all three up: stored, the rent runs")
	Depot.advance(30.0)
	check(float(l.clock) > 29.0, "the rent clock runs now")
	await _frames(10)
	Cap.save(root, "res://tests/out/cargo_racked_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	await _put(CF.mouth("B"))
	await _e()
	var ui = g.console_ui
	check(ui != null and str(ui.get("side")) == "B" and ui.rows_box.get_child_count() == 4, "E at the right mouth opens B1–B4 only")
	await _frames(10)
	var texts := ""
	for lb in ui.find_children("*", "Label", true, false):
		texts += str(lb.text)
	check(texts.contains("客户箱") and not texts.contains("A1"), "the right rack shows the client's crates and nothing of the left")
	Cap.save(root, "res://tests/out/cargo_rack_panel_zh.png")
	ui.close()
	print("CARGO FLOOR %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
