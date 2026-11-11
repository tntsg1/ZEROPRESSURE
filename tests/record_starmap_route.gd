extends "res://tests/record_starmap.gd"
# 星图拖船回港航线（2026-11-10）：约 25 秒。派出拖船，航线从星站直接画向零压港在到港那一刻的位置，
# 拖船沿线飞、港口沿轨道走，到港时正好落在港口光圈上。只用测试存档，不动真实鼠标。
#   tools/run_test.sh tests/record_starmap_route.gd --write-movie recordings/record_starmap_route.avi --fixed-fps 30


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_route_career.json"
	SaveGame.path = "user://zp_test_record_route_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	cap_total = 3
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true, "tow_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	g.open_star_map("find")
	var sm = g.console_ui
	sm.mouse = Vector2(-99999, -99999)
	var ord: Array = Scan.order()
	var far: int = ord[mini(Scan.reach(), ord.size()) - 1]
	sm.sel_sector = far
	Scan.sweep(far)
	Scan.advance(Scan.SWEEP_S + 0.5)
	for sg in Scan.signals(far):
		Scan.analyze(str(sg.id))
		Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	sm._fill()
	await _secs(1.5)

	_beat(1, "派出拖船：航线直指零压港", "终点是零压港在到港那一刻的位置，不再停在空白处")
	var send: Button = null
	for b in sm.find_box.find_children("*", "Button", true, false):
		if not b.disabled and not b.is_queued_for_deletion() and "派拖船去拖" in b.text:
			send = b
			break
	if send != null:
		send.pressed.emit()
	await _secs(0.2)
	sm._follow_on = false
	sm.view_zt = 1.0
	sm.pan_t = Vector2.ZERO
	await _secs(4.0)

	_beat(2, "拖船沿线飞，港口沿轨道走", "两者在终点会合；倒计时一秒一秒减少")
	var n := 0
	while not ShipMarket.on_the_way().is_empty() and n < 900:
		n += 1
		if n == 150:
			# the last stretch close up: the tug coming onto the port's ring
			sm.view_zt = 3.2
			sm.pan_t = Orbits.pos(Orbits.PORT, Shipping.day() + 3.0 * Orbits.DAYS_PER_S)
		await _secs(1.0 / FPS)

	_beat(3, "到港：正好落在港口光圈上", "这一行闪一下，上方提示“已到港 · 去船坞开工”")
	await _secs(3.5)
	print("RECORD STARMAP ROUTE DONE")
	quit()
