extends "res://tests/record108.gd"
# 108 号 第 4 件 (remote business), about 30 s for the owner: the terminal's three remote jobs
# (locked, then open), the parts rack from anywhere (F4) with a sale, the grid's dispatch (F5) with
# a group moved up, the processing queue (F6) with a batch moved to the front, the terminal's own
# button folding into the queue. Own test saves only.
#   tools/run_test.sh tests/record108b.gd --write-movie recordings/record108b.avi --fixed-fps 30


func _ui() -> Object:
	return g.console_ui if g != null and g.console_ui != null and is_instance_valid(g.console_ui) else null


func _shut() -> void:
	var ui = _ui()
	if ui == null:
		return
	if ui.get("on_close") != null and ui.on_close.is_valid():
		ui.on_close.call()
	elif ui.has_method("close"):
		ui.close()
	await _secs(0.4)


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	await _secs(0.2)


func _run() -> void:
	Txt.zh = true
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.walk_job = 99
	Career.data.history = [{"id": "TUG-001", "ship": "tug", "net": 9000.0, "time": 600.0}]
	Career.data.money = 80000.0
	Career.data.market = true
	Career.data.port = {"trade": 1, "power": 1, "process": 0, "tug": 1}
	Career.data.parts = [
		{"uid": "J1:NAV-T:1", "cls": "drive", "tag": "NAV-T", "nk": "p_nav", "cond": 0.92, "value": 4000.0, "ship": "tug", "job": "TUG-001"},
		{"uid": "J1:BAT-T:2", "cls": "power", "tag": "BAT-T", "nk": "p_battery", "cond": 0.81, "value": 2000.0, "ship": "tug", "job": "TUG-001"},
		{"uid": "J1:ENG-T:3", "cls": "drive", "tag": "ENG-T", "nk": "p_engt", "cond": 0.55, "value": 5000.0, "ship": "tug", "job": "TUG-001"}]
	Career.data.process_queue = []
	Career.save()
	for i in 3:
		ProcessQueue.add("lot%d" % i, ["gr7", "tw64", "m14"][i], "J-%d" % i, [11.8, 7.2, 14.5][i])
	await _scene("berth", {}, {})

	# ---- 1: the terminal's foot, locked
	_beat(1, "远程办理：三件常规事，任意终端都能办", "零件架 F4 · 电网调度 F5 · 加工排队 F6；亲自办过一次才解锁")
	g.open_console("terminal")
	await _secs(4.6)
	await _shut()
	Career.data.seen["rack_used"] = true
	Career.data.seen["walk_power"] = true
	Career.data.seen["walk_process"] = true

	# ---- 2: the parts rack from anywhere
	_beat(2, "F4：零件架", "在船坞任何地方打开，挂牌、撤牌、出售")
	await _secs(0.8)
	await _key(KEY_F4)
	await _secs(1.6)
	var rack = _ui()
	if rack != null and rack.has_method("_select"):
		rack._select(1, 0)
		await _secs(1.2)
		rack._sell_sel()
	await _secs(2.6)
	await _shut()

	# ---- 3: the grid's dispatch
	_beat(3, "F5：电网调度", "电不够时谁先用：把加工区往前调一位")
	await _key(KEY_F5)
	await _secs(1.8)
	var pw = _ui()
	if pw != null and pw.has_method("_apply"):
		pw._apply("order", Grid.moved("process", -1))
	await _secs(3.6)
	await _shut()

	# ---- 4: the processing queue
	_beat(4, "F6：加工排队", "哪批钢锭先炼：把 M-14 那批放到最前")
	await _key(KEY_F6)
	await _secs(1.8)
	var qp = _ui()
	if qp != null:
		qp.sel = 2
		qp._fill()
		await _secs(1.0)
		qp._move(2, -99)
	await _secs(3.0)
	await _shut()

	# ---- 5: from the terminal
	_beat(5, "终端里点一下，直接打开", "炉台、轧机、搬货这些现场操作还要亲自去")
	g.open_console("terminal")
	await _secs(2.0)
	var t = _ui()
	if t != null and t.get("remote_box") != null:
		t.remote_box.get_node("Remote_queue").pressed.emit()
	await _secs(3.4)
	print("RECORD108B DONE")
	quit()
