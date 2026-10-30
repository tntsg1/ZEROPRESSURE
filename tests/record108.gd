extends "res://tests/guide_check.gd"
# 108 号: the new play, about 30 s, for the owner (user 2026-10-29: "生成新玩法视频，30s，以后每次新任务
# 完成都要给我视频"). Five beats, each with its own caption: the first machine bought on the spot,
# the field grapple picking by material, F7 in the playtest recorder, the port walk's repair step,
# the ship market's showcase. Own test saves and recorder folder only.
#   tools/run_test.sh tests/record108.gd --write-movie recordings/record108.avi --fixed-fps 30

const FPS := 30
var cap_layer: CanvasLayer
var cap: Control
var cap_n := 0
var cap_total := 5
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0


func _initialize() -> void:
	Career.path = "user://zp_test_record108_career.json"
	SaveGame.path = "user://zp_test_record108_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * FPS):
		cap_t += 1.0 / FPS
		if cap != null:
			cap.queue_redraw()
		await process_frame


# ---------------------------------------------------------------- the caption

func _caption_layer() -> void:
	cap_layer = CanvasLayer.new()
	cap_layer.layer = 126
	cap_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(cap_layer)
	cap = Control.new()
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(_draw_caption)
	cap_layer.add_child(cap)


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
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 新玩法 %d / %d" % [cap_n, cap_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 30.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))


# ---------------------------------------------------------------- the scenes

func _scene(ship: String, contract: Dictionary, kit: Dictionary) -> void:
	if g != null:
		g.queue_free()
		await process_frame
	Game.start_ship = ship
	Game.contract = contract
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _secs(0.3)
	g.tutorial = null


func _loose(at: Vector2, mat: String, mass: float, opts: Dictionary = {}) -> Object:
	var h := Vector2(18, 13)
	var poly := PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)])
	var o := {"mat": mat, "mass": mass}
	o.merge(opts, true)
	return g.world.add_piece("plate", poly, o)


func _run() -> void:
	Txt.zh = true
	_caption_layer()
	Playtest.force = true
	Playtest.root = "user://zp_test_record108_playtest"
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.active = Career.opening(0)
	Career.data.methods = {"field": 2}
	Career.save()
	var M := Geom.M
	await _scene(str(Career.active().ship), Career.active(), {"skill_grapple_multi": 2})

	# ---- 1: the first machine, bought on the spot
	_beat(1, "第一件设备：回收站当场收购", "送进设备口那一刻，现金直接到账（约 4 分钟）")
	var wp = g.world.tag("WINCH-T")
	for j in g.world.joints_of(wp).duplicate():
		g.world.kill_joint(j)
	for l in g.world.lines_of(wp).duplicate():
		g.world.kill_line(l)
	g.world.relink()
	await _secs(0.1)
	wp = g.world.tag("WINCH-T")
	var mouth: Vector2 = Dock.zpos("equip")
	wp.body.global_position = mouth + Vector2(0, 2.6 * M)
	wp.body.linear_velocity = Vector2(0, -1.4 * M)
	wp.body.set_meta("hauled", true)
	g.cam_override = mouth + Vector2(0, 2.0 * M)
	g.zoom_override = 0.75
	var f := 0
	while not Career.data.get("seen", {}).has("first_receipt") and f < FPS * 3:
		await _secs(1.0 / FPS)
		f += 1
	if not Career.data.get("seen", {}).has("first_receipt"):
		g.on_swallowed(wp.body, "equip")
	await _secs(5.4)

	# ---- 2: the field grapple picks by material
	_beat(2, "范围抓钩：按材质挑着抓", "X 依次切换：全部 → 只抓钢 → 只抓设备")
	var c := Vector2(10.0 * M, -9.0 * M)
	for i in 5:
		_loose(c + Vector2(-70 + 34 * i, (i % 2) * 30 - 15), ["steel", "al", "steel", "ti", "steel"][i], 0.4)
	_loose(c + Vector2(10, -48), "steel", 0.3, {"cls": "equip", "value": 2000.0, "dest": "equip", "name_key": "p_console"})
	g.world.redraw_all(true)
	g.world.dirty_links = true
	g.tools.tool = 3
	g.drone.global_position = c + Vector2(-4.0 * M, -1.5 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.bot.aim = c
	g.cam_override = c + Vector2(-1.0 * M, 0)
	g.zoom_override = 1.15
	await _secs(0.4)
	g.tools.toggle_multi(false)
	await _secs(2.0)
	g.tools.toggle_multi(false)
	await _secs(2.2)
	g.tools.toggle_multi(false)
	await _secs(2.4)

	# ---- 3: F7, the playtest recorder
	_beat(3, "试玩记录器：卡住、出事、按 F7 都会记一条", "当场截图，写下当时的引导、页面、操作和推测原因")
	g.cam_override = null
	g.zoom_override = -1.0
	await _secs(0.8)
	var ev := InputEventKey.new()
	ev.keycode = KEY_F7
	ev.pressed = true
	Input.parse_input_event(ev)
	await _secs(0.4)
	var pt = Playtest.I
	if pt != null and pt.note_box != null:
		var line := "不知道去哪找第二艘船"
		for i in line.length():
			pt.note_box.text = line.substr(0, i + 1)
			await _secs(0.09)
		await _secs(0.6)
		pt.note_box.text_submitted.emit(pt.note_box.text)
	await _secs(1.2)

	# ---- 4: the port walk, only the core first: its repair step
	Playtest.force = false
	Career.data.active = {}
	Career.data.history = [{"id": "TUG-001", "ship": "tug", "net": 9000.0, "time": 600.0}]
	Career.data.seen.erase("port_walk")
	Career.data.walk_v = 2
	Career.data.market = true
	Career.data.port = {"trade": 1, "tug": 1}
	Career.data.money = 60000.0
	Career.data.methods = {"pump": 1}
	Career.save()
	await _scene("berth", {}, {})
	_beat(4, "港区导览：第一次只讲 8 步", "其余五个区，等第一次用得上时再带你去")
	g.start_port_walk(true)
	await _secs(0.2)
	var pw = g.port_walk
	pw.step = pw.steps.find(["repair", ""])
	pw.back = []
	pw._begin()
	await _secs(1.0)
	g.open_console("terminal")
	await _secs(0.6)
	g.console_ui._open_app(1)
	await _secs(4.0)
	if g.console_ui.has_method("close"):
		g.console_ui.close()
	else:
		g.console_ui.on_close.call()
	pw.stop()
	await _secs(0.3)

	# ---- 5: the showcase on the ship market
	_beat(5, "学会新拆法：船市挂一艘“试试新拆法”", "按拆法布置的船，结算时和不用它对比")
	ShipMarket.refresh()
	g.open_ship_market()
	await _secs(2.2)
	var sp = g.console_ui
	if sp != null:
		for l in ShipMarket.data().listings:
			if l.has("showcase"):
				sp.chosen = str(l.id)
				sp._detail()
	await _secs(3.4)
	Playtest.force = false
	print("RECORD108 DONE")
	quit()
