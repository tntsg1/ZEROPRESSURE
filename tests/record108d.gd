extends "res://tests/record108.gd"
# 108 号 (user 2026-10-30: the walk's card lay on the telemetry): the district walk's card top right in
# the field, top left over a district console — never on the drone's telemetry. About 12 s.
#   tools/run_test.sh tests/record108d.gd --write-movie recordings/record108d.avi --fixed-fps 30


func _run() -> void:
	Txt.zh = true
	cap_total = 2
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.history = [{"id": "TUG-001", "ship": "tug"}]
	Career.save()
	await _scene("berth", {}, {})
	g.drone.global_position = Dock.centre() * Geom.M
	g.start_port_walk(true, "trade")
	_beat(1, "导览卡片：港区里在右上角", "左下的无人机遥测读数不再被挡")
	await _secs(5.5)
	g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot("trade")
	await _secs(0.3)
	g.open_district("trade")
	_beat(2, "开着区终端时移到左上角", "终端在右，读数在左下，卡片放在主线卡下面")
	await _secs(6.0)
	print("RECORD108D DONE")
	quit()
