extends "res://tests/record108.gd"
# 2026-11-05 公司仓库页精修，约 30 秒：打开入场 → 鼠标划过格子（网格亮、浮起、聚光、小卡）→ 右键菜单 →
# 拖动挪位并预览落点 → R 旋转 → Ctrl 框选多件 → 批量卖给回收站 → 筛选渐暗 → 一键整理。
# 只用测试存档；指针是画出来的假指针（BenchFx.shot_mouse），真实鼠标不动；Ctrl 用测试开关。
#   tools/run_test.sh tests/record_store_fx.gd --write-movie recordings/record_store_fx.avi --fixed-fps 30

var ui


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_store_fx_career.json"
	SaveGame.path = "user://zp_test_record_store_fx_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the stand-in pointer, drawn over everything (the film has no real cursor)
func _draw_caption() -> void:
	super._draw_caption()
	if BenchFx.shot_mouse.is_finite():
		var p: Vector2 = BenchFx.shot_mouse
		var arrow := PackedVector2Array([p, p + Vector2(0, 22), p + Vector2(6, 16), p + Vector2(11, 26), p + Vector2(15, 24), p + Vector2(10, 14), p + Vector2(18, 14)])
		cap.draw_colored_polygon(arrow, Color(1, 1, 1, 0.95))
		arrow.append(p)
		cap.draw_polyline(arrow, Color(0, 0, 0, 0.9), 1.2, true)


# the pointer glides from where it is to `to` over `s` seconds (eased)
func _glide(to: Vector2, s: float) -> void:
	var from: Vector2 = BenchFx.shot_mouse if BenchFx.shot_mouse.is_finite() else to
	var n := maxi(1, int(s * FPS))
	for i in n:
		var k := BenchFx.e_io(float(i + 1) / n)
		BenchFx.shot_mouse = from.lerp(to, k)
		await _secs(1.0 / FPS)


func _btn(at: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ui._gui_input(ev)


func _centre(id: String) -> Vector2:
	var r: Rect2 = ui.unit_rect(id)
	return ui._grid_rect().position + r.get_center()


func _run() -> void:
	cap_total = 6
	_caption_layer()
	Txt.reduce_motion = false
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 10000.0
	Career.save()
	await _spawn()
	await _secs(1.0)
	var gds: Array = []
	for i in 6:
		gds.append({"cat": "equip", "tag": "LOW-%d" % i, "nk": "p_pod", "value": 300.0 + i * 40.0, "cond": 1.0, "mass": 0.6})
	for i in 4:
		gds.append({"cat": "equip", "tag": "MID-%d" % i, "nk": "p_pod", "value": 900.0 + i * 200.0, "cond": 1.0, "mass": 1.5})
	for i in 2:
		gds.append({"cat": "equip", "tag": "TOP-%d" % i, "nk": "p_pod", "value": 3200.0 + i * 500.0, "cond": 1.0, "mass": 3.0})
	for i in 2:
		gds.append({"cat": "special", "tag": "HAZ-%d" % i, "nk": "p_pod", "value": 800.0, "cond": 1.0, "mass": 0.5})
	StoreBook.receive("201-REC", "gr7", 14.0, [], gds)
	StoreBook.admit()
	Career.save()
	# 1. the page comes up
	BenchFx.shot_mouse = Vector2(1500, 600)
	g.open_store()
	ui = g.console_ui
	_beat(1, "公司仓库：磨砂玻璃与货架剪影", "格子有内阴影和刻线；底部淡色光晕和左上角色点是价值档位")
	await _secs(3.0)
	# 2. the pointer over the grid
	_beat(2, "鼠标划过：网格亮起、物品浮起、聚光跟手", "停 0.3 秒弹出小卡：名字、价格阶梯、来自哪艘船")
	var gr: Rect2 = ui._grid_rect()
	await _glide(gr.position + Vector2(60, 60), 0.8)
	await _glide(gr.position + Vector2(gr.size.x * 0.55, gr.size.y * 0.35), 1.6)
	var top := ""
	for it in ui.shown():
		if ui.tier_of(it) == "precious":
			top = str(it.id)
			break
	await _glide(_centre(top) + Vector2(10, -6), 1.0)
	await _secs(1.6)
	# 3. the right-click menu
	_beat(3, "右键菜单：卖、留、转向", "每一项都标着快捷键")
	_btn(BenchFx.shot_mouse, MOUSE_BUTTON_RIGHT)
	await _secs(1.2)
	await _glide(BenchFx.shot_mouse + Vector2(40, 52), 0.5)
	await _secs(0.6)
	ui._menu = {}
	# 4. drag a small machine to the free cells below, turning it on the way
	_beat(4, "拖动：空位微微发亮，预览落点，R 旋转", "放得下是冰蓝框，放不下是橙框；松手吸附带一点过冲")
	# the wheel throws the grid down a few rows (inertia), so free cells come into view
	await _glide(gr.position + Vector2(gr.size.x * 0.75, gr.size.y * 0.5), 0.4)
	ui._vel += ui.WHEEL * 7.0
	await _secs(0.25)
	ui._vel += ui.WHEEL * 7.0
	await _secs(0.9)
	var small := ""
	for it in ui.shown():
		var ur: Rect2 = ui.unit_rect(str(it.id))
		if ur.position.y < 0.0 or ur.end.y > gr.size.y - 20.0:
			continue
		if int(it.w) != int(it.h):
			small = str(it.id)
			break
	if small == "":
		for it in ui.shown():
			var ur2: Rect2 = ui.unit_rect(str(it.id))
			if ur2.position.y >= 0.0 and ur2.end.y <= gr.size.y:
				small = str(it.id)
				break
	await _glide(_centre(small), 0.6)
	_btn(BenchFx.shot_mouse)
	await _glide(BenchFx.shot_mouse + Vector2(14, 10), 0.2)
	await _secs(0.3)
	# R while it is held: it turns a quarter in the hand; the free places are found for its new shape
	ui.turn()
	ui.drag_grab = Vector2(0.5, 0.5)
	await _secs(0.5)
	# a place it really fits, clear of the caption (bottom left), as far from where it was as can be
	var dest := BenchFx.shot_mouse
	var best := -1.0
	var c: float = ui.cell()
	for yy in range(0, int(gr.size.y / c)):
		for xx in range(0, 8):
			var p := gr.position + Vector2((xx + 0.5) * c, (yy + 0.5) * c)
			if p.y > ui.size.y - 230.0 and p.x < 760.0:
				continue
			if ui.drop_ok(p):
				var d := p.distance_to(BenchFx.shot_mouse)
				if d > best:
					best = d
					dest = p
	print("RECORD drag to ", dest, " fits ", best)
	await _glide(dest, 1.2)
	await _secs(0.4)
	_btn(BenchFx.shot_mouse, MOUSE_BUTTON_LEFT, false)
	await _secs(1.0)
	# 5. Ctrl box over the top rows, then sell them all
	_beat(5, "按住 Ctrl 拖出选框，一次选上多件", "右边变成“已选 N 件”的汇总；全部卖给回收站，依次飞走")
	ui._test_ctrl = true
	var a0 := gr.position + Vector2(6, 6)
	await _glide(a0, 0.5)
	_btn(a0)
	await _glide(gr.position + Vector2(gr.size.x * 0.62, ui.cell() * 1.6), 1.2)
	_btn(BenchFx.shot_mouse, MOUSE_BUTTON_LEFT, false)
	ui._test_ctrl = false
	await _secs(0.8)
	var sb: Rect2 = ui._btns["sell"]
	await _glide(sb.get_center(), 0.8)
	_btn(sb.get_center())
	_btn(sb.get_center(), MOUSE_BUTTON_LEFT, false)
	await _secs(2.6)
	# 6. the filter fades what is left out; tidy brings the shown kind to the top
	_beat(6, "筛选渐暗、一键整理", "不相干的东西暗到约 28%；整理时按距离错开飞到位，到点轻轻一顿")
	await _glide(gr.get_center() + Vector2(260, 120), 0.6)
	ui.open_kind("special")
	await _secs(1.6)
	ui.open_kind("equip")
	await _secs(1.0)
	ui.tidy()
	await _secs(2.6)
	BenchFx.shot_mouse = Vector2.INF
	print("RECORD STORE FX DONE")
	quit()
