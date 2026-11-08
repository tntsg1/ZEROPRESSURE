extends "res://tests/seg4_sketch.gd"
# 2026-11-07 加工区面板重做 (user: "这个 UI 重做，太难看了，太复杂了"; sketch 2 仪表式): the processing queue
# empty (ingot → arc furnace → billet, one line, "排一炉 [Enter]", "去仓库挑别的") and with batches (cards, grips,
# the mould changes, the switch, "再排一炉"); the processing district's console (three tanks, the next step's
# one key on Enter, the passing ship's order; the rest under "更多", every control still there). And no
# native "关闭" tooltip anywhere (the floating yellow box in the user's screenshots). Own test saves only.
#   tools/run_test.sh tests/seg4_panels_check.gd --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_seg4pan_career.json"
	SaveGame.path = "user://zp_test_seg4pan_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)
	await _frames(6)


# every node under the root: a Control whose own tooltip says just "关闭", or a tooltip popup up
func _close_tips() -> Array:
	var out: Array = []
	for n in root.find_children("*", "", true, false):
		if n is Control and str((n as Control).tooltip_text).strip_edges() in ["关闭", "CLOSE"]:
			out.append(str(n.get_path()))
		if n is Window and n != root and (n as Window).visible and (n.get_class() == "PopupPanel" or str(n.name).to_lower().contains("tooltip")):
			out.append("popup " + str(n.get_path()))
	return out


func _hover(r: Rect2) -> void:
	BenchFx.shot_mouse = r.get_center()
	await _frames(40)


func _run() -> void:
	_career()
	HallMarket.data().orders = []
	await _spawn()
	await _frames(10)
	# ---- the queue, empty
	g.open_queue_panel()
	await _frames(40)
	var q = g.console_ui
	check(q != null and q._btns.has("one") and q._btns.has("store") and q._open().is_empty(), "empty: 排一炉 [Enter] and 去仓库挑别的")
	check(q.BG.a >= 1.0 and q._rect().size.x >= q.size.x * 0.5 - 1.0, "a solid dark half of the screen (%.0f of %.0f px)" % [q._rect().size.x, q.size.x])
	await _hover(q._btns["close"])
	check(_close_tips().is_empty(), "no native 关闭 tooltip with the pointer on the close key (%s)" % str(_close_tips()))
	BenchFx.shot_mouse = Vector2.INF
	await _shot("7a_queue_empty")
	await _key(KEY_ENTER)
	check(ProcessQueue.open_entries().size() == 1, "Enter queues a heat (%d)" % ProcessQueue.open_entries().size())
	# ---- with batches
	ProcessLine.queue_ingots(4.0)
	ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	ProcessLine.send_to_press("g:g1")
	for i in 60 * 6:
		await _frames(1)
	await _frames(20)
	check(q._btns.has("auto") and q._btns.has("one") and q._btns.keys().filter(func(k): return str(k).begins_with("row:")).size() == 3, "batches: three cards, the switch, 再排一炉")
	await _shot("7b_queue_list")
	var lots: Array = ProcessQueue.open_entries().map(func(e): return str(e.lot))
	q.test_drag(lots[2], 1)
	await _frames(10)
	check(str(ProcessQueue.open_entries()[1].lot) == lots[2], "a card dragged to second")
	q._press("auto")
	check(ProcessLine.auto_on(), "the switch turns auto-ordering on")
	q._press("auto")
	q._press("use:" + str(lots[1]))
	q._press("mould:" + str(lots[2]))
	await _key(KEY_ESCAPE)
	check(g.console_ui == null, "Esc closes the queue")
	# ---- the processing console
	Career.data.upgrades["gas_line"] = 1
	Career.data.upgrades["lox_tank"] = 1
	GasLine.receive({"o2": 13.0, "n2": 45.0}, "TUG-001")
	GasLine.receive({"o2": 52.0, "n2": 174.0}, "S09-001")
	GasLine.data().o2.ind = 420.0
	GasLine.data().lox.kg = 3600.0
	GasLine.new_caller()
	g.open_district("process")
	await _frames(40)
	var d = g.console_ui
	check(d != null and d.tanks != null and d.next_key != null and d.call_box != null, "the console: tanks, the next step, the passing ship")
	check(d.next_key.visible and not d.next_key.disabled and d.next_key.text.begins_with("开始分离"), "the next step's one key: 开始分离 (%s)" % d.next_key.text)
	check(not d.more_box.visible and d.gas_box.get_child_count() > 4, "the rest folded under 更多, every control still built (%d)" % d.gas_box.get_child_count())
	var texts: Array = d.call_box.find_children("*", "Button", true, false).map(func(b): return str(b.text))
	check(texts.has("接下") and texts.has("不接"), "the passing ship's order: 接下 / 不接 (%s)" % str(texts))
	var pane = d.get_node("Pane")
	check(pane.size.x >= d.size.x * 0.5 - 40.0 and (pane.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 1.0, "a solid dark half of the screen (%.0f px)" % pane.size.x)
	for b in d.find_children("*", "Button", true, false):
		if str(b.text).begins_with("关闭"):
			await _hover(b.get_global_rect())
	check(_close_tips().is_empty(), "no native 关闭 tooltip on the console either (%s)" % str(_close_tips()))
	BenchFx.shot_mouse = Vector2.INF
	await _shot("7c_biz")
	await _key(KEY_ENTER)
	check(not GasLine.data().job.is_empty(), "Enter starts the separation (%s)" % GasLine.job_text())
	d.more_key.pressed.emit()
	await _frames(30)
	var all: Array = d.more_box.find_children("*", "Button", true, false).map(func(b): return str(b.text))
	var autos: int = d.gas_box.find_children("*", "CheckButton", true, false).size()
	check(d.more_box.visible and autos == 4, "更多: the four automation switches (%d)" % autos)
	for want in ["外购混合气", "液化", "生命支持检测", "放空剩余气", "处置污染剩余"]:
		check(all.any(func(t): return t.begins_with(want)), "更多: %s" % want)
	await _shot("7d_biz_more")
	await _key(KEY_ESCAPE)
	await _frames(40)
	check(g.console_ui != null and not d.more_box.visible, "Esc folds 更多 first")
	if g.console_ui != null:
		await _key(KEY_ESCAPE)
	check(g.console_ui == null, "and Esc closes the console")
	print("SEG4 PANELS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	g.queue_free()
	await _frames(4)
	quit()
