extends "res://tests/guide_check.gd"
# 131 号 追加 (user 2026-11-05: on the terminal's home the walk's card lay over the third key, the
# orange frame on the first, the main line's "take me" on top — three voices). The walk's step
# "open the berth" with the terminal open: the berth key lit and selected, the walk's card hidden,
# the main line folded to one grey line; Enter opens the berth page. Own test saves only.
#   tools/run_test.sh tests/walk_terminal_shot.gd --fixed-fps 60

const OUT := "res://tests/out/walk_terminal_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_walk_terminal_career.json"
	SaveGame.path = "user://zp_test_walk_terminal_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(name: String) -> void:
	await _frames(4)
	Cap.save(root, OUT % name)
	print("SHOT ", ProjectSettings.globalize_path(OUT % name))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "store_guide_done": true}
	Career.data.money = 20000.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	await _spawn()
	await _frames(20)
	g.start_port_walk(true)
	await _frames(6)
	var wk = g.port_walk
	var at := -1
	for i in wk.steps.size():
		if str(wk.steps[i][0]) == "repair":
			at = i
	check(at >= 0, "the core walk has the berth step (%d of %d)" % [at + 1, wk.steps.size()])
	wk.step = at
	wk._begin()
	await _frames(30)
	g.open_console("terminal")
	await _frames(150)
	var term = g.console_ui
	check(term != null and term.tab == term.HOME, "the terminal opens on its home")
	check(term.walk_berth(), "the walk's berth step is shown on the terminal")
	check(term.sel == term._app_of(1), "the berth key is the one selected (%d)" % term.sel)
	check(not wk.layer.visible, "the walk's card is hidden over the terminal")
	check(term._walk_quiet(), "the main line is folded to one grey line while the walk runs")
	await _shot("1_home")
	# Enter: the selected key, the berth page
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.pressed = true
	term._unhandled_input(ev)
	await _frames(60)
	check(term.tab == 1 and wk.page_open(), "Enter opens the berth page (tab %d)" % term.tab)
	check(not wk.layer.visible, "the walk's card stays hidden on the berth page")
	await _shot("2_berth_page")
	print("DONE %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)
