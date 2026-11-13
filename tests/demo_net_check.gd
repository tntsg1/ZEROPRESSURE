extends SceneTree
# The public test gate's first-start connection (scripts/demo_gate.gd _post, demo.gd net_kind) against a
# local stand-in server only: main address dead -> retries and the fallback address carry it; both dead ->
# the steps page with the error kinds, laid out inside a small window; main address up -> straight in.
# No real server, no real code, no real saves (every file is zp_test_ or under a folder of this test's own).
#   godot --path . -s tests/demo_net_check.gd
const Gt = preload("res://scripts/demo.gd")
var fails := 0
var srv := TCPServer.new()
var hits := 0


func check(ok: bool, what: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# answers every request with {"ok":true}; polled from the test's own loop
func _serve() -> void:
	while srv.is_listening():
		await process_frame
		while srv.is_connection_available():
			var c := srv.take_connection()
			hits += 1
			var t := Time.get_ticks_msec() + 800
			while Time.get_ticks_msec() < t:
				c.poll()
				if c.get_available_bytes() > 0:
					for i in 4:
						await process_frame
						c.poll()
					c.get_data(c.get_available_bytes())
					break
				await process_frame
			var body := '{"ok":true}'
			c.put_data(("HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: %d
Connection: close

%s" % [body.length(), body]).to_utf8_buffer())
			for i in 10:
				await process_frame
			c.disconnect_from_host()


func _gate() -> Node:
	var g = preload("res://scripts/demo_gate.gd").new()
	root.add_child(g)
	return g


func _wait(g, secs := 30.0) -> String:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		if not is_instance_valid(g):
			return "passed"
		if g.state in ["offline", "refused", "closed", "done", "expired"]:
			return g.state
	return "timeout"


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]))
	var sc := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(sc.position + sc.size - Vector2i(24, 24))
	Gt.forced = true
	Gt.CFG = "user://zp_test_net_activation.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gt.CFG))
	var outbox := "user://zp_test_net_outbox"
	preload("res://scripts/demo_feedback.gd").outbox = outbox
	check(srv.listen(18461, "127.0.0.1") == OK, "stand-in server listening")
	_serve()
	var mock := "http://127.0.0.1:18461"
	var dead := "http://127.0.0.1:9"
	Gt.net_waits = [0.3, 0.3]
	Gt.net_timeout = 2.0
	# 1. main dead, fallback up: round 1 fails on the main address, the fallback answers
	Gt.base_url = dead
	Gt.fallback_url = mock
	var g1 := _gate()
	var r1 := await _wait(g1)
	check(r1 == "passed", "dead main address + live fallback: in (%s)" % r1)
	check(hits >= 1, "the fallback was asked (%d hits)" % hits)
	# 2. both dead: 3 rounds x 2 addresses, then the steps page
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gt.CFG))
	Gt.fallback_url = "http://127.0.0.1:8"
	var g2 := _gate()
	var r2 := await _wait(g2)
	check(r2 == "offline", "both dead: held on the offline page (%s)" % r2)
	if is_instance_valid(g2):
		check(g2.net_log.size() == 6, "6 failed tries kept (3 rounds x 2 addresses): %d" % g2.net_log.size())
		check(g2.try_n == 6, "tried 6 times: %d" % g2.try_n)
		var steps: String = g2.steps_text()
		check(steps.contains("ipconfig /flushdns") and steps.contains("hosts") and steps.contains("VPN"), "the steps name VPN, flushdns, hosts")
		var det: String = g2.detail_text()
		check(det.contains("127.0.0.1") and (det.contains("连接") or det.contains("timed out") or det.contains("connect")), "the error kind and host are shown: %s" % det)
		check(g2.go_b.visible and not g2.go_b.disabled, "a retry key")
		# small window: everything inside it
		for sz in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 480)]:
			var vs := Vector2(sz)
			var plan: Dictionary = g2._offline_plan(vs)
			check(plan.top >= 0.0 and plan.buttons_y + 48.0 <= vs.y + 0.5 and plan.wd <= vs.x, "layout fits %dx%d (top %.0f, buttons end %.0f of %.0f)" % [sz.x, sz.y, plan.top, plan.buttons_y + 48.0, vs.y])
		await _frames(8)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
			img.save_png(ProjectSettings.globalize_path("res://tests/out/demo_net_offline.png"))
		# 3. the retry key: main address now up -> in
		Gt.base_url = mock
		g2.go_b.pressed.emit()
		var until := Time.get_ticks_msec() + 15000
		while is_instance_valid(g2) and Time.get_ticks_msec() < until:
			await process_frame
		check(not is_instance_valid(g2), "retry with the main address up: in")
	# 4. main up from the start: in on the first try
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gt.CFG))
	Gt.fallback_url = ""
	var before := hits
	var g4 := _gate()
	var r4 := await _wait(g4)
	check(r4 == "passed" and hits == before + 1, "main up: in on the first try (%d hits)" % (hits - before))
	srv.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gt.CFG))
	print("DEMO NET CHECK ", "PASS" if fails == 0 else "FAIL", " fails=", fails)
	quit(0 if fails == 0 else 1)
