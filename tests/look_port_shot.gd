extends SceneTree
# 91 号 外部（DECISIONS 2026-10-27 外部画面定案）：港区里飞的样子 —— 船坞外、转运环旁、动力区外、拖船区外。
#   tools/run_test.sh tests/look_port_shot.gd --fixed-fps 60 -- tag=before
const Cap = preload("res://tests/cap.gd")
var tag := "after"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	Career.path = "user://zp_test_lookport_career.json"
	SaveGame.path = "user://zp_test_lookport_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true}
	Career.data.money = 90000.0
	Career.data.history = [{"id": "TUG-001"}]
	if tag == "on":
		Career.data.port = {"power": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	var spots := {
		"0_out": Dock.centre() * Geom.M + Vector2(0, -26.0 * Geom.M),
		"1_ring": PortStructure.box("ring").get_center() + Vector2(0, PortStructure.box("ring").size.y * 0.5 + 6.0 * Geom.M),
		"2_power": PortStructure.box("power").get_center() + Vector2(0, PortStructure.box("power").size.y * 0.5 + 5.0 * Geom.M),
		"3_tug": PortStructure.box("tug").get_center() + Vector2(0, PortStructure.box("tug").size.y * 0.5 + 5.0 * Geom.M),
		"5_power_in": PortStructure.box("power").get_center() + Vector2(0, 4.0 * Geom.M),
		"6_process_in": PortStructure.box("process").get_center() + Vector2(0, 4.0 * Geom.M),
	}
	for k in spots:
		g.drone.global_position = spots[k]
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		g.zoom_target = 0.5
		g.zoom_now = 0.5
		g.cam_pos = spots[k]
		g.aim = spots[k] + Vector2(6.0 * Geom.M, 0)
		await _frames(50)
		Cap.save(root, "res://tests/out/look_port_%s_%s.png" % [tag, k])
		print("%s signal %.2f" % [k, g.look.signal_k])
	g.port_view = true
	await _frames(150)
	Cap.save(root, "res://tests/out/look_port_%s_4_pano.png" % tag)
	quit()
