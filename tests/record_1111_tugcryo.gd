extends "res://tests/guide_check.gd"
# Video (2026-11-11): the tug station's cryo collection tanks filling from a hulk, the LH2 / LOX
# piped down to the processing district's gas bay. Test career only; the pipe time is shortened
# here (GasLine.CRYO_S) so it fits in about 20 s.
#   tools/run_test.sh tests/record_1111_tugcryo.gd --write-movie G:/temp/zp_rec_20261110/tugcryo.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1111_tugcryo_career.json"
	SaveGame.path = "user://zp_test_rec1111_tugcryo_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	kit = preload("res://tests/rec_kit_1110.gd").new()
	root.add_child(kit)
	_run.call_deferred()


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true, "gas_flow_film": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	if not Career.data.has("upgrades"):
		Career.data.upgrades = {}
	Career.data.upgrades["gas_line"] = true
	Career.data.upgrades["lox_tank"] = true
	var d := GasLine.data()
	d.made = 3
	# the line's tanks full for now, so nothing is sent while the tug's tanks fill (test only)
	d.lox.kg = GasLine.TANK_CAP
	d.lh2 = {"kg": GasLine.LH2_CAP}
	Career.save()
	GasLine.CRYO_S = 8.0
	await _spawn()
	await _frames(30)
	var M := PortStructure.M()
	var c := PortStructure.centre()
	# 1. the hulk's leftovers drawn into the tug station's tanks
	_put(c + Vector2(-106.0, -21.0) * M, 24.0 / M)
	await _frames(30)
	kit.keep(true, "拖船站：从拖回的废船抽回残留的液氢、液氧")
	for i in 240:
		var k := float(i + 1) / 240.0
		TugYard.set_cryo("lh2", 1100.0 * k)
		TugYard.set_cryo("lox", 3800.0 * k)
		await process_frame
	kit.keep(false)
	# 2. piped down to the gas bay (the line's tanks have room again)
	d.lox.kg = 1200.0
	d.lh2.kg = 300.0
	await _frames(2)
	kit.keep(true, "经低温管线送到加工区：液氧淡蓝，液氢近乎无色")
	var gp = g.gas_works.pipes
	for i in 480:
		var sl: Array = gp.cryo_transits()
		var at := Vector2(-128.0, -14.0)
		for t in sl:
			if str(t[0]) == "lh2":
				at = gp._along(gp.L_PATH, float(t[1]) * gp._len_l)
		_put(g.cam_pos.lerp(c + at * M, 0.08) if i > 0 else c + Vector2(-112.0, -20.0) * M, 17.0 / M)
		await process_frame
	kit.keep(false)
	# 3. in the gas bay's LH2 and LOX tanks
	_put(c + Vector2(-140.0, 2.0) * M, 30.0 / M)
	await _frames(5)
	kit.keep(true, "到达加工区的液氢罐、液氧罐，再由拖船送燃料电池")
	await _frames(300)
	kit.keep(false)
	await _frames(5)
	g.queue_free()
	quit(0)
