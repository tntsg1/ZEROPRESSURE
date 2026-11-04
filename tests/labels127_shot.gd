extends "res://tests/guide_check.gd"
# 127 号 (user 2026-11-04: the words on the machines are not needed): each district before / after
# Pal.labels, from its console spot. Own test saves only.
#   tools/run_test.sh tests/labels127_shot.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_labels127_career.json"
	SaveGame.path = "user://zp_test_labels127_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	# the still layers are drawn once, so each run sets the switch before the port is built
	var on := OS.get_cmdline_user_args().has("before")
	Pal.labels = on
	await _spawn()
	await _frames(10)
	for z in ["power", "process", "tug", "trade", "cargo", "ring"]:
		g.drone.global_position = preload("res://scripts/port_structure.gd").console_spot(z)
		await _frames(150)
		Cap.save(root, "res://tests/out/labels127_%s_%s.png" % [z, "before" if on else "after"])
	Pal.labels = false
	print("LABELS127 PASS (shots)")
	quit(0)
