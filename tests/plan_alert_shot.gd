extends SceneTree
# 2026-11-12: the plan run's wait on the player, top-centre (scripts/plan_alert.gd), at the window size
# given (--resolution). POD's codex plan to its marked line behind the hull ("等待露出"): the bar is down,
# clear of the task panel, the function keys and the top strip, the 下一步 mark on the same hull piece;
# the hull taken off (as the player), the run goes on and the bar goes up again.
# Test careers only. Usage: tools/run_test.sh tests/plan_alert_shot.gd --resolution 1280x720 -- [--capture]
const Cap = preload("res://tests/cap.gd")
const NextStep = preload("res://scripts/next_step.gd")
const Bot = preload("res://tests/salvage_bot.gd")
var fails := 0
var checks := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_alert_career.json"
	SaveGame.path = "user://zp_test_plan_alert_save.json"
	SaveGame.train_path = "user://zp_test_plan_alert_train.json"
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	Career.data = Career.fresh()
	Career.data.money = 0.0
	Career.data.methods = {"cutter": 1}
	Career.data.plans = {}
	Career.data["plan_codex"] = true
	Career.save()
	Game.start_ship = "pod"
	Game.contract = {"id": "ALERT-T", "ship": "pod", "fee": 0, "time": 3600, "kit": {}}
	Career.data.active = {}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.autosave_t = -1000000.0
	var s: Vector2 = root.get_visible_rect().size
	# the project stretches canvas_items (expand): at 16:9 the HUD lays out in 1920x1080 units whatever the
	# window; the shot is named by the window's real size
	var ws: Vector2i = DisplayServer.window_get_size()
	var tag := "%dx%d" % [ws.x, ws.y]
	print("VIEW window ", tag, " layout ", s)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.keycode = KEY_P
	key.pressed = true
	g._unhandled_input(key)
	check(g.plan.running and g.plan.source == "codex", "%s: P runs POD's codex plan" % tag)
	var bar_seen := false
	var bar_ok := true
	var mark_ok := false
	var bot = Bot.new(g, {})
	for k in 9000:
		await process_frame
		if not g.plan.running: break
		# what the player took off goes to a mouth (as tests/plan_codex_check.gd)
		if k % 20 == 0:
			for body in g.world.bodies:
				if is_instance_valid(body) and body.capture == null and not bot.sent.has(body):
					bot._send(body)
					break
		var pa = g.hud.plan_alert
		if g.plan.wait == "as_plan_expose" and g.plan.expose_piece != null and not g.plan.expose_piece.gone and g.plan.expose_piece.body == null and bar_seen:
			for j in g.world.joints_of(g.plan.expose_piece):
				g.world.kill_joint(j)
			for l in g.world.lines_of(g.plan.expose_piece):
				g.world.kill_line(l)
			g.plan.expose_t = 0.0
			continue
		if g.plan.wait == "as_plan_expose" and g.plan.expose_piece != null and not g.plan.expose_piece.gone and g.plan.expose_piece.body == null:
			await frames(30)
			# the player has flown over to look
			g.drone.global_position = g.plan.expose_at + Vector2(-140, -40)
			g.drone.linear_velocity = Vector2.ZERO
			await frames(60)
			var r: Rect2 = pa.bar_rect()
			bar_seen = pa._k > 0.99 and r.has_area()
			var others := {"task": g.hud._contract_rect(), "keys": g.hud.keys_band.band_rect(), "top strip": Rect2(s.x * 0.5 - 340.0, 8.0, 680.0, 86.0)}
			for n in others:
				var o: Rect2 = others[n]
				if o.has_area() and o.intersects(r):
					bar_ok = false
					print("  bar ", r, " meets ", n, " ", o)
			var ns: Dictionary = NextStep.of(g)
			mark_ok = not ns.is_empty() and ns.at == g.plan.expose_at
			print("BAR %s rect=%s line=%s" % [tag, str(r), str(pa._al.get("line", ""))])
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				Cap.save(root, "res://proofs/plan_alert_%s.png" % tag)
			# the player takes the hull piece off
			for j in g.world.joints_of(g.plan.expose_piece):
				g.world.kill_joint(j)
			for l in g.world.lines_of(g.plan.expose_piece):
				g.world.kill_line(l)
			g.plan.expose_t = 0.0
	print("STATE i=%d/%d running=%s wait=%s %s" % [g.plan.i, g.plan.steps.size(), g.plan.running, g.plan.wait, g.plan.wait_arg])
	check(bar_seen, "%s: the marked line waits for its hull: the bar is down top-centre" % tag)
	check(bar_ok, "%s: clear of the task panel, the function keys and the top strip" % tag)
	check(mark_ok, "%s: the 下一步 mark is on the same hull piece" % tag)
	await frames(90)
	check(not g.plan.running and g.plan.i == g.plan.steps.size() and g.hud.plan_alert._k <= 0.0, "%s: the hull off, the run goes on to the end and the bar goes up" % tag)
	g.queue_free()
	await frames(4)
	Career.data = {}
	print("PLAN ALERT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
