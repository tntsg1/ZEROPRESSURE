extends "res://tests/record108.gd"
# 128 号 第 3 段 video for the owner (~30 s): the broken trade port → the one "修" and its bill →
# the whole district lighting up a stretch at a time → the done card and the new chapters.
# Own test saves only.
#   tools/run_test.sh tests/record_seg3.gd --write-movie recordings/seg3.avi --fixed-fps 30

const PS = preload("res://scripts/port_structure.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_recseg3_career.json"
	SaveGame.path = "user://zp_test_recseg3_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, nk: String, cls: String, v: float, tag: String, mass: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": cls, "cond": 1.0, "value": v, "ship": "tug", "tag": tag, "mass": mass, "job": "TUG-001"}


func _run() -> void:
	Txt.zh = true
	cap_total = 4
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.onboard = "done"
	Career.data.history = [{"id": "TUG-001"}, {"id": "S09-001"}]
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1}
	Career.data.upgrades = {"lights": 1, "furnace_main": 1, "net_fix": 1}
	Career.data.main_card = {"trade": true}
	Career.data.parts = [_part("s1", "p_battery", "power", 2000.0, "BAT-T", 0.4), _part("s2", "p_nav", "drive", 4000.0, "NAV-T", 0.25)]
	Career.data.structure_t = 40.6
	Career.data.money = 26000.0
	Career.save()
	_caption_layer()
	preload("res://scripts/trade_works.gd").reset()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	var b: Rect2 = PS.box("trade")
	g.drone.global_position = b.get_center() + Vector2(-b.size.x * 0.3, b.size.y * 0.32)
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = b.get_center()
	g.zoom_override = 1920.0 / (b.size.x * 1.15) / 1.2
	await _frames(40)
	var host = g.get_meta("revive_host")
	while not host.nodes.has("trade"):
		await process_frame

	_beat(1, "贸易港还没修", "主灯灭、应急灯慢闪、积灰挂霜、屏幕全黑、吊车停在半路、门卡住了")
	host.nodes.trade.hover = true
	await _secs(4.4)
	host.nodes.trade.hover = false

	_beat(2, "一个“修”按钮", "仓库里有的先用自己的，缺的按市价一键买齐，施工队不收工钱")
	g.open_district("trade")
	await _secs(1.4)
	var panel = g.console_ui
	panel.open_order()
	await _secs(4.2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	root.push_input(ev)
	await _secs(0.6)
	panel.close()
	await _secs(0.3)

	_beat(3, "修好时整区逐段点亮", "施工小艇进场焊接 → 合闸 → 电沿电缆送过去、脏污揭开、顶灯接力 → 门打开、设备依次启动、吊车归位")
	Works.finish()
	await _secs(13.8)

	_beat(4, "主线跟着需要走", "完工卡写开放了什么和下一步 · 点主线条看全部章节")
	g.cam_override = Vector2.INF
	g.zoom_override = 0.0
	await _secs(3.0)
	g.hud.voice.fold()
	await _secs(0.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	g.hud.voice._gui_input(click)
	await _secs(3.6)
	quit()
