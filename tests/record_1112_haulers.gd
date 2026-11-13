extends "res://tests/haulers5_check.gd"
# 2026-11-12 update video: all seven hauling drones at work at once on fourteen pieces of scrap (the
# check's part C), the camera on the work. Test saves only.
#   tools/run_test.sh tests/record_1112_haulers.gd --write-movie G:/temp/zp_upd1112/haulers.avi --fixed-fps 60
var tick: Node


func _initialize() -> void:
	super()
	tick = preload("res://tests/rec_tick_1112.gd").new()
	root.add_child(tick)


func _run() -> void:
	Txt.zh = true
	var M := Geom.M
	_career(3000000.0)
	var kit := {"skill_grapple_multi": 1}
	for id in IDS:
		kit[id] = 1
	await _game(kit)
	var hs: Array = g.haulers()
	print("HAULERS %d" % hs.size())
	var ex: float = Dock.zpos("equip").x / M
	g.cam_override = Vector2(ex - 9.0, -5.0) * M
	g.zoom_override = 0.55
	await _frames(60)
	var bodies := []
	for i in 14:
		bodies.append(_rect(Vector2(ex - 6.0 - (i % 7) * 2.2, -3.5 - (i / 7) * 2.0) * M, Vector2(0.6, 0.5) * M, "S5-%d" % i, 0.4).body)
	tick.keep(true, "haulers")
	for f in 60 * 30:
		await process_frame
		if bodies.all(func(b): return not is_instance_valid(b) or b.capture != null or b.pieces.is_empty()):
			break
	await _frames(90)
	tick.keep(false, "end")
	quit()
