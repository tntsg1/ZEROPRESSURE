extends "res://tests/seg4_sketch.gd"
# 128 号 第 4 段 加工: the new play, about 30 s, with captions (the owner's video for each task).
# Reuses seg4_sketch's career; the slow machine steps run at a stated speed-up. Own test saves only.
#   tools/run_test.sh tests/record_seg4.gd --write-movie recordings/zeropressure_seg4_process.avi --fixed-fps 30

const FPS := 30.0
var cap: Control
var cap_n := 0
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0


func _initialize() -> void:
	Career.path = "user://zp_test_recseg4_career.json"
	SaveGame.path = "user://zp_test_recseg4_save.json"
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
	await _frames(int(s * FPS))


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
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 加工区新玩法 %d / 6" % cap_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 30.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))


func _run() -> void:
	_career()
	await _spawn()
	await _frames(6)
	var M := Geom.M
	var Gal = preload("res://scripts/process_gallery.gd")
	var box := PortStructure.box("process")
	# ---- 1: the gallery
	_beat(1, "观察通道：从区门一条直道进来", "终端排在通道地面上，隔着玻璃看两边的机器干活")
	g.drone.global_position = Gal.at(Vector2(58.0, 17.2))
	g.drone.linear_velocity = Vector2.ZERO
	_put(box.get_center(), 0.62)
	await _secs(2.2)
	for i in int(2.4 * FPS):
		var k := float(i) / (2.4 * FPS)
		g.drone.global_position = Gal.at(Vector2(lerpf(58.0, 42.0, k), 17.2))
		g.drone.linear_velocity = Vector2.ZERO
		_put(Gal.at(Vector2(lerpf(54.0, 46.0, k), 17.0)), lerpf(0.62, 1.0, k))
		await _frames(1)
	# ---- 2: the queue
	var r1 := ProcessLine.queue_ingots(2.0, {"kind": "keep"}, "billet")
	var r2 := ProcessLine.queue_ingots(4.0)
	var r3 := ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	_beat(2, "加工队列：每批写清用途，可以拖动排序", "为订单排的批次锁定模具；模具不同的两批之间提示换模停炉")
	g.drone.global_position = g.industrial_heat.site()
	_put(_box(Vector2(20.0, 15.0)), 0.75)
	g.open_queue_panel()
	await _secs(2.4)
	var ui = g.console_ui
	if r3.ok:
		ui.test_drag(str(r3.entry.lot), 1)
	await _secs(1.6)
	ui.close()
	# ---- 3: the mould change (×2.5)
	Career.data.process_queue = []
	_beat(3, "换模：行车把方坯模吊上架，换上板坯模", "实际约 11 秒，炉子停着等；画面 2.5 倍速")
	_put(_box(Vector2(26.0, 14.0)), 0.95)
	ProcessLine.start_change("slab")
	Engine.time_scale = 2.5
	for i in int(FPS * 20):
		await _frames(1)
		if not ProcessLine.changing():
			break
	Engine.time_scale = 1.0
	await _secs(0.4)
	# ---- 4: the pour into the slab block, the strip, the rollers (×2)
	_beat(4, "浇铸：钢水从底部注满模腔，冷却后顶出上辊道", "三种模具：方坯 1 t×2、板坯 2 t、小锭 0.25 t×8；画面 2 倍速")
	var f = g.plant.smelter
	f.begin_manual()
	f.m_s = 0.0
	f.bunker = 0.0
	f.m_l = 2.0
	f.T = 1660.0
	f.phase = "hold"
	f.sample_count = 1
	f.tc_age = 0.0
	f.mould = "slab"
	f.manual_command("tap")
	_put(Vector2(g.plant.X + 4.5, g.plant.F + 7.5) * M, 1.35)
	Engine.time_scale = 2.0
	for i in int(FPS * 12):
		await _frames(1)
		if f._strip_t0 >= 0.0 and f.t - f._strip_t0 > 1.2:
			break
	Engine.time_scale = 1.0
	await _secs(0.6)
	# ---- 5: the baler (×2)
	_beat(5, "压块机：整件设备压成方块，占格更少、略贵一点", "带压的储气罐被探头拦下退回，不会进压箱、不会炸；画面 2 倍速")
	_put(_box(Vector2(47.5, 21.8)), 0.9)
	ProcessLine.send_to_press("g:g1")
	ProcessLine.send_to_press("g:g2")
	Engine.time_scale = 2.0
	var seen_probe := false
	for i in int(FPS * 14):
		await _frames(1)
		if str(ProcessLine.press_phase()[0]) in ["probe", "reject"]:
			seen_probe = true
		if seen_probe and ProcessLine.press().get("cur", {}).is_empty():
			break
	Engine.time_scale = 1.0
	await _secs(0.5)
	# ---- 6: the stores
	_beat(6, "仓库里选中就能用：“压块 [P]”、“炼成钢坯 [P]”", "钢锭排进加工队列；压机拒收过的罐子写明原因和怎么处理")
	g.cam_override = null
	g.zoom_override = -1.0
	g.open_store("all")
	await _frames(10)
	var st = g.console_ui
	for want in ["WINCH-T", "ingot", "O2-T"]:
		for u in StoreBook.units():
			if (want == "ingot" and str(u.id).begins_with("r:" + Ex.INGOT)) or str(u.get("tag", "")) == want:
				st.select(str(u.id))
				break
		await _secs(1.5)
	print("RECORD SEG4 DONE")
	g.queue_free()
	await _frames(4)
	quit()
