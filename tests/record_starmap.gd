extends "res://tests/record108.gd"
# 星图（2026-11-05）：约 30 秒，给用户远程看。打开星图的入场 → 扫描中卡片只说“正在扫描”带进度 → 扫完信号出现、
# 卡片才提示分析 → 分析光扫、#012 形变、名字升起 → 派拖船、航线画出 → 倒计时一秒一秒减少、拖船在走 →
# 到港闪一下并给出提示。只用测试存档，不动真实鼠标。
#   tools/run_test.sh tests/record_starmap.gd --write-movie recordings/record_starmap.avi --fixed-fps 30

const Mo := preload("res://scripts/star_map_motion.gd")
var _frame_n := 0
var _base := -1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_starmap_career.json"
	SaveGame.path = "user://zp_test_record_starmap_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the movie is written slower than real time on a fixed 30 fps clock: the map's motion clock steps
# with the frames (star_map_motion.gd fake_ms), not with the wall
func _secs(s: float) -> void:
	for i in int(s * FPS):
		cap_t += 1.0 / FPS
		if cap != null:
			cap.queue_redraw()
		_frame_n += 1
		if _base < 0:
			_base = Time.get_ticks_msec()
		Mo.fake_ms = _base + int(_frame_n * 1000.0 / FPS)
		await process_frame


func _key(sm, k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	sm._input(ev)


func _run() -> void:
	cap_total = 6
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "tow_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _secs(0.5)

	# ---- 1: the map opens
	_beat(1, "打开星图", "面板从右侧滑入，导览从第一步讲起")
	g.open_star_map("find")
	var sm = g.console_ui
	sm.mouse = Vector2(-99999, -99999)
	await _secs(2.4)
	_key(sm, KEY_SPACE)
	await _secs(1.0)
	_key(sm, KEY_SPACE)
	await _secs(1.2)

	# ---- 2: the sweep: the card only says it is sweeping
	_beat(2, "扫描中：卡片只说“正在扫描”", "信号出来之前不讲分析；橙框框住扫描进度条")
	sm._tour_parts.sweep.pressed.emit()
	sm._tour_next(true)
	while sm._sweeping_here():
		await _secs(0.1)
	await _secs(0.4)

	# ---- 3: swept: the signals, then the analyse step
	_beat(3, "扫完信号出现，才提示分析", "先讲信号点，再框住信号行讲“分析电磁特征”")
	await _secs(2.0)
	_key(sm, KEY_SPACE)
	await _secs(2.0)

	# ---- 4: the analysis: the shine, the #012 morph, the name rising
	_beat(4, "分析：光扫 → 形变 → 名字升起", "认出是船：菱形变成橙色船标，名字从线后升起")
	var near: int = sm.sel_sector
	var ship_sig := ""
	for s in Scan.signals(near):
		if str(s.get("kind", "")) == "ship" and ship_sig == "":
			ship_sig = str(s.id)
	sm.sel_sig = ship_sig
	sm._sig_key = ""
	sm._fill()
	await _secs(0.4)
	Scan.analyze(ship_sig)
	sm._sig_key = ""
	sm._fill()
	while Scan.busy():
		await _secs(0.1)
	await _secs(1.8)

	# ---- 5: the tug sent, its route drawn on
	_beat(5, "派拖船：航线一笔画出", "关着开着星图，拖船都在飞；倒计时一秒一秒减少")
	var send = sm._tour_parts.get("send")
	if send != null and is_instance_valid(send):
		send.pressed.emit()
		sm._tour_next(true)
	await _secs(0.1)
	_key(sm, KEY_ESCAPE)
	# the tow cut to about 9 s, for the video's length
	for a in ShipMarket.data().assets:
		if str(a.state) == "towing":
			var left: float = float(ShipMarket.on_the_way()[0].left_s)
			if left > 9.0:
				a.run.depart = float(a.run.depart) - (left - 9.0) * Orbits.DAYS_PER_S
	sm._sig_key = ""
	sm._fill()
	await _secs(2.0)
	while not ShipMarket.on_the_way().is_empty():
		await _secs(0.1)

	# ---- 6: docked
	_beat(6, "到港：这一行闪一下", "上方提示“已到港 · 去船坞开工”")
	await _secs(3.5)
	print("RECORD STARMAP DONE")
	quit()
