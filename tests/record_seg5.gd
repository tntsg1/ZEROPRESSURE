extends "res://tests/seg5_sketch.gd"
# 128 号 第 5 段 动力: about 30 s with Chinese captions (the owner's video for each task) — the order, the ship
# lowering the block, the dispatch order dragged, the overload's trip, the wrench and the restart, the LH2 / LOX
# fill. Reuses seg5_sketch's career and stock; the slow steps run at a stated speed-up. Own test saves only.
#   tools/run_test.sh tests/record_seg5.gd --write-movie recordings/zeropressure_seg5_power.avi --fixed-fps 30

const FPS := 30.0
var cap: Control
var cap_n := 0
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0


func _initialize() -> void:
	Career.path = "user://zp_test_recseg5_career.json"
	SaveGame.path = "user://zp_test_recseg5_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	var layer := CanvasLayer.new()
	layer.layer = 126
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	cap = Control.new()
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(_draw_caption)
	layer.add_child(cap)
	process_frame.connect(func():
		cap_t += 1.0 / FPS
		cap.queue_redraw())
	_run.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * FPS):
		_fold()
		await _frames(1)


func _beat(n: int, title: String, sub: String) -> void:
	cap_n = n
	cap_title = title
	cap_sub = sub
	cap_t = 0.0


func _draw_caption() -> void:
	if cap_n <= 0:
		return
	var f: Font = Fonts.get_font("Medium")
	var fr: Font = Fonts.get_font("Regular")
	var k := Pal.ease_out(clampf(cap_t / 0.4, 0.0, 1.0))
	var x := lerpf(-40.0, 40.0, k)
	var y := cap.size.y - 150.0
	var w := maxf(f.get_string_size(cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, fr.get_string_size(cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) + 64.0
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(w, 150.0)), Color(0.03, 0.035, 0.04, 0.86 * k))
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(5.0, 150.0)), Color(UiSkin.ACCENT, k))
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 动力区 %d / 6" % cap_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 30.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))


func _run() -> void:
	_career()
	await _spawn()
	await _frames(6)
	var p := PS.d()
	p.fc_fuel = 0.0
	# ---- 1: the order
	_beat(1, "供电屏：像买东西一样订电池块", "小 / 中 / 大三档：容量、价格、到港时间不同；点下单立刻扣钱，有完成提示")
	g.open_power_screen()
	await _secs(1.8)
	g.console_ui.supply5._order("m")
	await _secs(1.4)
	# ---- 2: the dispatch order dragged (still on the screen)
	_beat(2, "调度：拆船现场默认先用电", "按住一行拖动，就能改谁先用电；松手立刻生效")
	var pan = g.console_ui
	pan.scroll.scroll_vertical = int(pan.order_box.get_parent().get_parent().position.y) - 40
	await _secs(0.6)
	pan.drag_begin(0)
	await _secs(0.4)
	pan.drag_to(1)
	await _secs(0.4)
	pan.drag_to(2)
	await _secs(0.4)
	pan.drag_end()
	await _secs(1.2)
	Grid.set_ctl("order", Grid.GROUPS.duplicate())
	pan.close()
	await _frames(10)
	p = PS.d()
	# ---- 3: the ship
	_beat(3, "外星系货船 CB-7 送货", "反推刹停在两片散热片之间，开舱门，绞车把电池吊进泊位接上总线（2 倍速）")
	# slot B holds a spent shell: the ship sets the new block in A, then lifts the shell away
	p.slots[1] = {"size": "s", "left": 0.0, "t": 0.0}
	p.pickup_t = 999.0
	var o: Dictionary = PS.pending()[0]
	o.t = 7.0
	g.drone.global_position = _b(Vector2(30.0, -8.0))
	g.drone.linear_velocity = Vector2.ZERO
	Engine.time_scale = 2.0
	for i in int(13 * FPS):
		var close: bool = str(o.phase) in ["lower", "latch", "lift_old"]
		_put(_b(Vector2(46.0, -6.0 if close else -11.0)), 1.05 if close else 0.62)
		_fold()
		await _frames(1)
		if str(o.phase) == "leave" and float(o.pt) > 2.5:
			break
	Engine.time_scale = 1.0
	# ---- 4: overload, trip
	_beat(4, "发电机超载：多发 20%，热量一直涨", "热量满了强制停机，必须用维护工具去修（热量 6 倍速）")
	PS.set_over("tg", true)
	p.gens.tg.heat = 0.8
	var at := _b(PS.repair_at("tg"))
	g.drone.global_position = at + Vector2(-0.6, 3.0) * PortStructure.M()
	g.drone.linear_velocity = Vector2.ZERO
	_put(_b(Vector2(50.0, 11.0)), 0.95)
	for i in int(1.8 * FPS):
		PS._drain(g, 34.8, 6.0 / FPS)
		_fold()
		await _frames(1)
	await _secs(0.8)
	# ---- 5: the wrench, the restart
	_beat(5, "按 4 拿维护工具，对准按住，修好重启", "修好后热量降下来，可以重新打开超载")
	await _key(KEY_4)
	g.bot.aim = at
	g.bot.lmb = true
	for i in int(3.2 * FPS):
		_fold()
		await _frames(1)
		if not p.gens.tg.trip:
			break
	g.bot.lmb = false
	await _secs(1.0)
	await _key(KEY_2)
	# ---- 6: the cryo fill
	_beat(6, "液氢液氧按库存自动加注", "加工区液氧和拖船站拆下的液氢罐：预冷、结霜、白汽，拖船守惯性运到燃料电池（8–16 倍速）")
	PS.start_cryo()
	var c: Dictionary = p.cryo
	for i in int(9 * FPS):
		var ph := str(c.phase)
		Engine.time_scale = 8.0 if ph.begins_with("p_") or ph.begins_with("d_") else 16.0
		var pose := PS.cryo_pose(c)
		_put(PortStructure.centre() + (pose.p + Vector2(-2.0, -2.0)) * PortStructure.M(), 1.0)
		_fold()
		await _frames(1)
		if ph == "d_fill" and float(c.t) > 4.0:
			break
	Engine.time_scale = 1.0
	await _secs(1.2)
	cap_n = 0
	await _secs(0.3)
	quit(0)
