extends "res://tests/guide_check.gd"
# Video (2026-11-10): the gas line's plant (scripts/gas_plant.gd) — idle, a batch coming in and
# separated, its oxygen liquefied into the LOX tank, the cryo tug filling at the roof stand.
# Test career only; the jobs' lengths are shortened here so it all fits in about 30 s.
#   tools/run_test.sh tests/record_1110_gasplant.gd --write-movie G:/temp/zp_rec_20261110/gasplant.avi --fixed-fps 60

var kit: Node


func _initialize() -> void:
	Career.path = "user://zp_test_rec1110_gas_career.json"
	SaveGame.path = "user://zp_test_rec1110_gas_save.json"
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


# the camera eased from where it is to (at, zoom) over n frames
func _move(at: Vector2, zoom: float, n: int) -> void:
	var a0: Vector2 = g.cam_pos
	var z0: float = g.zoom_now
	for i in n:
		var u := Pal.ease_io(float(i + 1) / n)
		_put(a0.lerp(at, u), lerpf(z0, zoom, u))
		await process_frame


func _box(v: Vector2) -> Vector2:
	return PortStructure.box("process").position + v * PortStructure.M()


func _fit(r: Rect2) -> float:
	return minf(1920.0 / r.size.x, 1080.0 / r.size.y)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
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
	d.lh2 = {"kg": 2600.0}
	Career.save()
	await _spawn()
	await _frames(30)
	var M := PortStructure.M()
	var box := PortStructure.box("process")
	g.drone.global_position = box.get_center() + Vector2(0.0, -2.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	var bay := Rect2(_box(Vector2(-38.4, -9.6)), Vector2(42.4, 38.0) * M)
	var whole := box.merge(bay)
	_put(whole.get_center(), _fit(whole.grow(4.0 * M)))
	await _frames(60)
	# 1. the hall and its gas plant, idle
	kit.keep(true, "加工区 · 气体处理线（待机）")
	await _frames(150)
	kit.keep(false)
	# 2. a batch comes in at the coupling; the plant starts separating it
	await _move(bay.get_center(), _fit(bay.grow(1.0 * M)), 1)
	kit.keep(true, "混合气进厂 → 压缩、纯化、旋转床分离")
	var b := GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "TEST")
	b.certified = true
	await _frames(70)
	GasLine.separate(str(b.id))
	var j: Dictionary = GasLine.data().job
	j.total = 9.0
	j.left = 9.0
	await _frames(60)
	await _move(_box(Vector2(-14.0, 14.0)), _fit(Rect2(Vector2.ZERO, Vector2(22.0, 26.0) * M)), 150)
	await _frames(200)
	kit.keep(false)
	# 3. the oxygen liquefied into the LOX tank
	if not GasLine.data().job.is_empty():
		GasLine.data().job.left = 0.01
		await _frames(5)
	GasLine.liquefy(1000.0)
	var lj: Dictionary = GasLine.data().liq
	lj.total = 7.0
	lj.left = 7.0
	await _move(_box(Vector2(-8.0, 14.0)), _fit(Rect2(Vector2.ZERO, Vector2(20.0, 25.0) * M)), 1)
	kit.keep(true, "液化：冷箱结霜，液氧进真空夹套储罐")
	await _frames(420)
	kit.keep(false)
	# 4. the cryo tug filling at the roof stand: both risers running
	var PS = preload("res://scripts/power_supply.gd")
	PS.d().fc_fuel = 0.0
	PS.start_cryo()
	await _move(_box(Vector2(1.0, -3.0)), _fit(Rect2(Vector2.ZERO, Vector2(36.0, 24.0) * M)), 1)
	kit.keep(true, "出货：拖船在屋顶灌装台装液氢、液氧")
	await _frames(360)
	# 5. back out to the whole district
	await _move(whole.get_center(), _fit(whole.grow(4.0 * M)), 120)
	await _frames(40)
	kit.keep(false)
	await _frames(5)
	g.queue_free()
	quit(0)
