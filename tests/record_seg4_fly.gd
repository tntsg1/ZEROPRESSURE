extends "res://tests/seg4_sketch.gd"
# 128 号 第 4 段 (方案 A 改): a flight through the processing district, about 30 s, with captions — off the
# shuttle at the arrival lane, up past the gallery's end into the empty corridor, along it over the five
# consoles while the machines work below (the baler, the mould change, the pour). Own test saves only.
#   tools/run_test.sh tests/record_seg4_fly.gd --write-movie recordings/zeropressure_seg4_gallery_fly.avi --fixed-fps 30

const FPS := 30.0
var cap: Control
var cap_n := 0
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0


func _initialize() -> void:
	Career.path = "user://zp_test_recfly_career.json"
	SaveGame.path = "user://zp_test_recfly_save.json"
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
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 加工区观察廊 %d / 5" % cap_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 30.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))


# the drone a frame towards goal (box metres) at speed (m/s), the camera following a little below it
func _fly_to(goal_l: Vector2, speed: float, zoom: float, cam_dy: float, every: Callable = Callable()) -> void:
	var Gal = preload("res://scripts/process_gallery.gd")
	var goal: Vector2 = Gal.at(goal_l)
	var M := Geom.M
	for f in int(FPS * 40):
		var d: Vector2 = goal - g.drone.global_position
		if d.length() < 0.15 * M:
			break
		g.drone.linear_velocity = d.normalized() * minf(speed * M, d.length() * FPS)
		var cam: Vector2 = g.drone.global_position + Vector2(0, cam_dy) * M
		g.cam_override = g.cam_pos.lerp(cam, 0.12)
		g.zoom_override = lerpf(g.zoom_now, zoom, 0.06)
		g.cam_pos = g.cam_override
		g.zoom_now = g.zoom_override
		if every.is_valid():
			every.call((g.drone.global_position - PortStructure.box("process").position) / M)
		await _frames(1)
	g.drone.linear_velocity = Vector2.ZERO


func _run() -> void:
	_career()
	await _spawn()
	await _frames(6)
	var Gal = preload("res://scripts/process_gallery.gd")
	var box := PortStructure.box("process")
	var M := Geom.M
	# ---- 1: off the shuttle at the arrival lane
	_beat(1, "从接驳站下车：加工区的到站通道", "左边隔着玻璃是机器层，上面是观察廊")
	g.drone.global_position = Gal.at(Vector2(57.5, 14.0))
	g.drone.linear_velocity = Vector2.ZERO
	_put(Gal.at(Vector2(47.0, 12.0)), 0.72)
	for i in int(FPS * 2.2):
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
	# ---- 2: up past the walkway's end into the corridor
	_beat(2, "上升到空走廊：廊道上方什么都不放", "从入口沿这条走廊直线飞过全场，不碰任何东西")
	await _fly_to(Vector2(58.4, 14.0), 3.0, 0.72, 4.0)
	await _fly_to(Vector2(58.4, Gal.FLY_Y), 4.0, 0.8, 6.0)
	# the machines get to work as the drone comes by: the baler first, then the mould change, the pour
	ProcessLine.send_to_press("g:g1")
	var state := {"cast": false}
	var f = g.plant.smelter
	var every := func(l: Vector2) -> void:
		if not state.cast and l.x < 37.0:
			state.cast = true
			Career.data.process_queue = []
			ProcessLine.start_change("slab")
	# ---- 3: along the corridor over the consoles
	_beat(3, "五台矮控制台贴在栏杆上，都在飞行线下面", "每台正对下面自己的机器：业务、轧机、压块机、浇铸换模、电弧炉")
	await _fly_to(Vector2(42.0, Gal.FLY_Y), 2.6, 0.8, 7.5, every)
	_beat(4, "飞到哪台上面，往下看就是那台在干活", "压块机压扁设备；行车在廊道下面换模；电弧炉出钢浇进模具")
	await _fly_to(Vector2(14.0, Gal.FLY_Y), 2.6, 0.8, 8.5, every)
	# ---- 5: at the furnace's console, E opens the processing queue
	_beat(5, "炉体控制台按 E：打开加工队列", "浇铸换模、压块机终端按 E 报状态；换模全程 9 秒，炉子出钢浇进板坯模")
	await _fly_to(Vector2(15.0, Gal.DECK - Gal.HEAD - 0.6), 2.0, 0.85, 6.0)
	# the new slab mould is in: the furnace taps into it
	for i in int(FPS * 3.0):
		if not ProcessLine.changing():
			break
		await _frames(1)
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
	await _frames(int(FPS * 1.6))
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(int(FPS * 3.0))
	print("RECORD SEG4 FLY DONE")
	g.queue_free()
	await _frames(4)
	quit()
