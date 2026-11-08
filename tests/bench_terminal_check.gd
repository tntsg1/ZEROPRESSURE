extends SceneTree
# 2026-11-04 终端（手绘）的人性化：指针在一样东西上停 0.4 秒出白话说明；界面缩放 120% 时整个终端跟着放大。
# 只用测试存档，不动真实鼠标（pointer_override）。
#   tools/run_test.sh tests/bench_terminal_check.gd

const Cap = preload("res://tests/cap.gd")
var checks := 0
var fails := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_bench_terminal_career.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 41250.0
	Career.data.seen = {"market": true}
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _run() -> void:
	var was := Txt.ui_scale
	Txt.ui_scale = 1.0
	var term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _wait_s(0.8)
	term.set_tab(term.HOME)
	await _wait_s(0.5)
	term.pointer_override = term._item_rect(0).get_center()
	await _wait_s(0.2)
	check(term._note_t < BenchFx.NOTE_S, "no note before 0.4 s")
	await _wait_s(0.4)
	check(term._note_key == "app0" and term._note_t >= BenchFx.NOTE_S and term._note_text(term._note_key).contains("找下一艘"), "on the find-ships tile 0.4 s: its plain note (%s)" % term._note_text(term._note_key))
	Cap.save(root, "res://tests/out/bench_terminal_note.png")
	# the page's own key: find ships when a card is up, else the supplies page's buy key
	var page := 0
	term.set_tab(0)
	await _wait_s(0.6)
	if not term._go_live:
		page = 4
		term.set_tab(4)
		await _wait_s(0.6)
	term.pointer_override = term._go_rect().get_center()
	await _wait_s(0.6)
	var nk := "go%d" % page
	check(term._note_key == nk and term._note_text(nk) != "", "on the page's own key: what it does (%s: %s)" % [term._note_key, term._note_text(nk)])
	Cap.save(root, "res://tests/out/bench_terminal_note_go.png")
	term._open_app(3)
	await _wait_s(0.6)
	check(term.tab == term.DRONE_PAGE and term.items().size() == 3 and term._go_live and term._go_rect().has_area(), "the fourth app shows three drone upgrades and its buy button")
	Cap.save(root, "res://tests/out/bench_terminal_drone.png")
	var funds := float(Career.data.money)
	term.act()
	check(Career.data.upgrades.has("scan_kit") and is_equal_approx(float(Career.data.money), funds - 24000.0), "buying the scanner installs and charges for the existing upgrade")
	term.queue_free()
	await _wait_s(0.2)
	# the interface scale
	Txt.ui_scale = 1.2
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _wait_s(0.8)
	var vp: Vector2 = term.get_viewport_rect().size
	check(term.scale.is_equal_approx(Vector2(1.2, 1.2)) and (term.size * 1.2).distance_to(vp) < 2.0, "120%%: the terminal is drawn larger and still fills the screen (%s)" % str(term.size))
	Cap.save(root, "res://tests/out/bench_terminal_scale_120.png")
	Txt.ui_scale = was
	print("BENCH TERMINAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
