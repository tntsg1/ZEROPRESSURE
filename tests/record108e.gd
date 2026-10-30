extends "res://tests/record108.gd"
# 108 号 帧率 (user 2026-10-30: "精细化是精细化了，但是帧率还是太低了"): about 30 s through the port —
# the berth, the ring, the processing and cargo districts — with each place's measured frame time,
# before and after (tests/fps108_survey.gd at 1920x1080, vsync off). Recorded at a fixed 30 fps.
#   tools/run_test.sh tests/record108e.gd --write-movie recordings/record108e.avi --fixed-fps 30
const PortStructure = preload("res://scripts/port_structure.gd")


func _fly(to: Vector2, s: float) -> void:
	var from: Vector2 = g.drone.global_position
	var n := int(s * FPS)
	for i in n:
		var u := float(i + 1) / n
		g.drone.global_position = from.lerp(to, u * u * (3.0 - 2.0 * u))
		g.drone.linear_velocity = Vector2.ZERO
		await _secs(1.0 / FPS)


func _run() -> void:
	Txt.zh = true
	cap_total = 4
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 1, "cargo": 1, "ring": 1}
	Career.save()
	await _scene("berth", {}, {})
	g.drone.global_position = Dock.centre() * Geom.M
	_beat(1, "船坞：15.5 → 12.6 毫秒", "镜头外的区不再每帧重画；静止的部分只画一次")
	await _secs(5.5)
	_beat(2, "中央环：16.4 → 15.3 毫秒", "各区照常亮着、动着；看不见的区不再白白重画")
	await _fly(Backdrop.port_centre_px(), 3.0)
	await _secs(4.5)
	_beat(3, "加工区：15.9 → 13.3 毫秒", "电炉、轧机、化验台都在画面里，细节一点没少")
	await _fly(PortStructure.console_spot("process"), 3.0)
	await _secs(4.5)
	_beat(4, "货运区：15.4 → 13.4 毫秒；P95 都进了 60 帧", "改前改后同一镜头截图逐像素对比：中央环、加工区、货运区完全一样")
	await _fly(PortStructure.console_spot("cargo"), 3.0)
	await _secs(5.0)
	print("RECORD108E DONE")
	quit()
