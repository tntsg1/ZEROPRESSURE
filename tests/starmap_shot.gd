extends "res://tests/guide_check.gd"
# The star map on screen (user 2026-10-26: "地图太假了…右边的选项甚至没在屏幕里面"): mid-sweep, and
# with a hulk found and a long label in the column, at 1600 x 900. Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/starmap_shot.gd


func _initialize() -> void:
	Career.path = "user://zp_test_starmap_shot_career.json"
	SaveGame.path = "user://zp_test_starmap_shot_save.json"
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
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(10)
	var sm = g.console_ui
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	Scan.advance(Scan.SWEEP_S * 0.45)
	sm._sig_key = ""
	sm._fill()
	await _frames(40)
	Cap.save(root, "res://tests/out/starmap_sweep_zh.png")
	Scan.advance(Scan.SWEEP_S)
	for sg in Scan.signals(near):
		Scan.analyze(str(sg.id))
		Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	sm._fill()
	await _frames(40)
	Cap.save(root, "res://tests/out/starmap_found_zh.png")
	# the pointer on another station: the lock and its card, its orbit faint
	var other: int = Scan.order()[1]
	sm.mouse = sm._to(Orbits.pos(Orbits.station(other), Shipping.day()))
	await _frames(30)
	Cap.save(root, "res://tests/out/starmap_hover_zh.png")
	check(str(sm.hover.get("key", "")) == "st%d" % other, "the pointer on a station locks on it (%s)" % str(sm.hover.get("title", "")))
	# zoomed in about the pointer
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = sm.mouse
	for n in 4:
		sm._map_input(ev)
	await _frames(60)
	check(sm.view_z > 1.8, "the wheel zooms in smoothly (x%.2f)" % sm.view_z)
	Cap.save(root, "res://tests/out/starmap_zoom_zh.png")
	var pane: Control = sm.find_child("Pane", true, false)
	var vw: float = sm.get_viewport_rect().size.x
	check(pane != null and pane.get_global_rect().end.x <= vw + 1.0, "the column stays on screen (ends at %.0f of %.0f)" % [pane.get_global_rect().end.x if pane != null else -1.0, vw])
	print("STARMAP SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
