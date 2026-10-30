extends SceneTree
# The title screen's frame time (user 2026-10-26: "首页的优化太低，帧率太低"). The title with a
# saved career at its port sheet, vsync off, measured over 240 frames after it has settled; the
# CPU time of drawing the page (one frame's redraw) measured on its own. Run windowed:
#   tools/run_test.sh tests/title_perf_check.gd --fixed-fps 0
var fails := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	Career.path = "user://zp_test_title_perf_career.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t = load("res://scenes/title.tscn").instantiate()
	root.add_child(t)
	await frames(10)
	# the sheet a returning player sees: the port
	t.sheet_mode = "port"
	await frames(240)
	var t0 := Time.get_ticks_usec()
	for i in 240:
		await process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 240.0 / 1000.0
	print("TITLE frame %.2f ms (%.0f fps) sheet=%s" % [ms, 1000.0 / ms, str(t.get("sheet_mode"))])
	var cap = preload("res://tests/cap.gd")
	cap.save(root, "res://tests/out/title_perf.png")
	check(ms < 8.0, "the title runs at over 120 fps (%.2f ms a frame)" % ms)
	print("TITLE PERF %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
