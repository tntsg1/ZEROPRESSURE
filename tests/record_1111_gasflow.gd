extends "res://tests/guide_check.gd"
# Video (2026-11-11): where the port's gas and cryogens go (scripts/gas_pipes.gd) — a ship's batch
# along the pipe rack, the first-time film, the cryo run while the tug fills. Test career only.
#   tools/run_test.sh tests/record_1111_gasflow.gd --write-movie G:/temp/zp_rec_20261110/gasflow.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1111_flow_career.json"
	SaveGame.path = "user://zp_test_rec1111_flow_save.json"
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


func _move(at: Vector2, zoom: float, n: int) -> void:
	var a0: Vector2 = g.cam_pos
	var z0: float = g.zoom_now
	for i in n:
		var u := Pal.ease_io(float(i + 1) / n)
		_put(a0.lerp(at, u), lerpf(z0, zoom, u))
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 1}
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
	d.o2.ind = 1500.0
	d.lox.kg = 5200.0
	d.lh2 = {"kg": 1800.0}
	Career.save()
	await _spawn()
	await _frames(30)
	var M := PortStructure.M()
	var c := PortStructure.centre()
	var gp = g.gas_works.pipes
	var b := PortArt.bounds()
	var vs: Vector2 = root.get_visible_rect().size
	var port_z := minf(vs.x / (b.size.x * M), vs.y / (b.size.y * M)) * 1.25
	var port_at := c + Vector2(-50.0, 30.0) * M
	# 1. a ship's gas on its way across the port
	var bt := GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "TEST")
	bt.certified = true
	_put(port_at, port_z)
	await _frames(40)
	kit.keep(true, "拆船回收的气体，经港区管廊送往加工区")
	await _frames(240)
	kit.keep(false)
	# 2. close on the slug, following it along the rack
	kit.keep(true, "管内这一团就是这批混合气，流量随它移动")
	for i in 300:
		var at: Vector2 = gp._along(gp.g_path, (1.0 - float(bt.t_left) / float(bt.t_total)) * gp._len_g)
		_put(c + at * M, 13.0 / M)
		await process_frame
	kit.keep(false)
	# 3. the film, as the player sees it the first time
	g.cam_override = null
	g.zoom_override = -1.0
	gp.play_film()
	await _frames(2)
	kit.keep(true, "film")
	while gp.film >= 0.0:
		await process_frame
	kit.keep(false)
	# 4. the cryo run while the tug fills at the roof stand
	var PS = preload("res://scripts/power_supply.gd")
	PS.d().fc_fuel = 0.0
	PS.start_cryo()
	_put(c + Vector2(-140.0, 10.0) * M, 7.5 / M)
	await _frames(10)
	kit.keep(true, "拖船灌装：仓库里的液氢、液氧罐经低温管线送到屋顶灌装台")
	await _frames(150)
	await _move(c + Vector2(-128.0, -18.0) * M, 16.0 / M, 120)
	await _frames(120)
	kit.keep(false)
	await _frames(5)
	g.queue_free()
	quit(0)
