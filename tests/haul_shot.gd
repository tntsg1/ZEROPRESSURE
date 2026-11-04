extends "res://tests/guide_check.gd"
# 119 号 回收整理页：拍三张 —— 刚打开（全部待整理）、整理到一半（钢锭入库、一件入库、一件卖掉）、零件架页。
# Own test saves only.
#   tools/run_test.sh tests/haul_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_haulshot_career.json"
	SaveGame.path = "user://zp_test_haulshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, cls: String, nk: String, cond: float, value: float, job := "011-M-14") -> Dictionary:
	return {"uid": uid, "cls": cls, "tag": uid.to_upper(), "nk": nk, "cond": cond, "value": value, "ship": "m14", "job": job}


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.money = 3284458.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 0, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.gear = {"anchor": 2, "pump": 1, "probe": 3}
	Career.data.parts = [_part("gen-7", "power", "p_gen", 0.81, 16000.0, "009-GR-7"), _part("hx-2", "thermal", "p_pump", 0.66, 7200.0, "009-GR-7")]
	Career.save()
	preload("res://scripts/industrial_exchange.gd").command("view")
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["mixed_metal:0"] = 18.4
	st["steel_billet:1"] = 6.2
	st["nonferrous_mix:0"] = 2.1
	st["steel_plate:1"] = 3.5
	Career.data.active = {"id": "011-M-14", "ship": "m14", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	Career.settle({"job_id": "011-M-14", "earned": 103050.0, "grade": 2, "ingot_value": 12900.0, "ingot_t": 43.0, "structure_t": 5.3,
		"parts": [_part("hpu-m", "power", "p_gen", 0.88, 21000.0), _part("mot-1", "drive", "p_motor", 0.74, 9800.0), _part("cool-m", "thermal", "p_pump", 0.41, 5200.0)], "parts_value": 36000.0})
	await _spawn()
	if g.drone != null:
		g.drone.integrity = 64.0
	if g.gear != null:
		g.gear.carried.append({"type": "anchor", "lent": false})
		g.gear.carried.append({"type": "probe", "lent": false})
		g.gear.lost.append({"type": "pump", "lent": false, "why": "gear_why_left"})
	g.open_disposal()
	await _frames(40)
	Cap.save(root, "res://tests/out/haul_1_open.png")
	var p = g.disposal_ui
	p.move("ingot", "wh")
	p.move("hpu-m", "wh")
	p.move("cool-m", "sold")
	p.tab = "rack"
	p.hover_id = "mot-1"
	await _frames(40)
	Cap.save(root, "res://tests/out/haul_2_sorting.png")
	p.hover_id = ""
	p.tab = "parts"
	await _frames(40)
	Cap.save(root, "res://tests/out/haul_3_parts.png")
	p.tab = "gear"
	await _frames(30)
	Cap.save(root, "res://tests/out/haul_4_gear.png")
	# drag: press on the last card to sort, move it onto the warehouse, let go; then one onto the sale strip
	p.move("mot-1", "left")
	await _frames(20)
	var drag := func(id: String, to: Vector2) -> void:
		var r: Rect2 = p._rects[id]
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = r.get_center()
		p._gui_input(ev)
		var mv := InputEventMouseMotion.new()
		mv.position = to
		p._gui_input(mv)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = to
		p._gui_input(up)
	drag.call("mot-1", p._right_rect().get_center())
	print("DRAG to the warehouse: %s" % p._item("mot-1").place)
	p.move("hpu-m", "left")
	await _frames(20)
	drag.call("hpu-m", p._sale_rect().get_center())
	print("DRAG to the sale: %s · cash %s" % [p._item("hpu-m").place, Pal.money(p.cash_now())])
	# a click on a sold chip takes it back
	await _frames(20)
	var r: Rect2 = p._rects["hpu-m"]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = r.get_center()
	p._gui_input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	p._gui_input(ev)
	print("CLICK the sold chip: %s" % p._item("hpu-m").place)
	print("HAUL SHOTS DONE")
	quit(0)
