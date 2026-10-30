extends "res://tests/record108.gd"
# 110 号 开局可读性 (user 2026-10-30, "先修开局可读性"): about 30 s. The OB-90 berth build seen from
# afar, where the two ships alongside and the furnace plant used to be empty boxes; the same far out
# in play and back in; the speed tape stepping out of the core asset board's way. Test saves only.
#   tools/run_test.sh tests/record_110_ships.gd --write-movie recordings/record_110_ships.avi --fixed-fps 30


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record110_career.json"
	SaveGame.path = "user://zp_test_record110_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Game.cine_in_tests = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(k: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = down
		Input.parse_input_event(ev)
		await process_frame


func _run() -> void:
	cap_total = 3
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.certified = true
	Career.data.prologue_done = true
	Career.save()
	var D = load("res://scripts/dev.gd")
	D.b_ship = "ob90"
	var r: Dictionary = D.build({"rep": 30, "done": 6})
	var o: Dictionary = r.offer.duplicate(true)
	o.dev = true
	o.dev_from = "title"
	o.fee = 0.0
	Game.contract = o
	Game.start_ship = "ob90"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await _secs(3.0)
	_beat(1, "远处的设施不再是空框", "船坞上方是设备货船 RT-07，下方是驳船 HB-03 和熔炉设备")
	await _secs(8.0)
	# past the build and the brief, into play
	for i in 40:
		if str(g.state) == "play":
			break
		await _key(KEY_SPACE)
		await _secs(0.5)
	# the brief over the first seconds of play: 开工
	await _secs(0.5)
	await _key(KEY_SPACE)
	await _secs(1.0)
	_beat(2, "开工后拉远也一样", "货舱、桶架、钢锭舱、航行灯和船名都在；拉近换回细节画法")
	g.zoom_target = 0.2
	await _secs(5.0)
	g.zoom_target = g.CAM_ZOOM
	await _secs(3.0)
	_beat(3, "速度刻度让开状态牌", "左上角核心资产牌变高时，HS 刻度移到它右边")
	await _secs(8.0)
	print("RECORD 110 DONE")
	quit()
