extends "res://tests/perf_probe.gd"
# 60 FPS bench (user 2026-10-27: a release blocker). Real frame intervals (vsync off, no frame cap,
# 1920x1080 window) in the situations that matter, each against 16.67 ms: average, P95, P99,
# worst, 1% low; with the script process, physics and the viewport's CPU and GPU render times; and
# the worst single frame while switching (loading a ship, the terminal, the star map, a save and a
# load). Writes tests/out/perf_bench.md. Own test saves only.
#   tools/run_test.sh tests/perf_bench.gd
var rows: Array = []
var stalls: Array = []


func _spawn(ship: String, kit: Dictionary = {}) -> void:
	Game.contract = {}
	Game.start_ship = ship
	var t0 := Time.get_ticks_usec()
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await process_frame
	var first := (Time.get_ticks_usec() - t0) / 1000.0
	var worst := await _worst(60)
	stalls.append(["load %s (first frame, then worst of 1 s)" % ship, first, worst])
	g.tutorial = null


func _worst(n: int) -> float:
	var w := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		w = maxf(w, (now - last) / 1000.0)
		last = now
	return w


func _row(name: String, m: Dictionary, stress := false) -> void:
	rows.append([name, m, stress])
	print(line(name, m))


func _done() -> void:
	g.queue_free()
	await _frames(4)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	SaveGame.clear()
	# -- look=0: without the picture pass (91 号 Look: lights, dark field, full-screen pass), to
	# tell its cost from the simulation's
	if "look=0" in OS.get_cmdline_user_args():
		Look.on = false
	# --- an empty-ish berth (TUG), the drone flying and stopping hard
	await _spawn("tug")
	await _frames(60)
	_row("TUG 船坞闲置", await measure(240))
	g.bot.move = Vector2(1, 0)
	g.bot.dash = true
	var a := await measure(60)
	g.bot.move = Vector2(-1, 0)
	var b := await measure(60)
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	g.bot.brake = true
	var c := await measure(60)
	g.bot.brake = false
	var fly := a.duplicate()
	for k in ["avg", "process", "physics", "render_cpu", "render_gpu", "draws", "low1"]:
		fly[k] = (a[k] + b[k] + c[k]) / 3.0
	for k in ["p95", "p99", "max"]:
		fly[k] = maxf(a[k], maxf(b[k], c[k]))
	_row("无人机冲刺、反向、急停", fly)
	# --- 100 and 250 loose pieces, then the field grapple hauling and 30 lines whipping
	var cc := Vector2(43.0 * Geom.M, -7.0 * Geom.M)
	var mats := ["steel", "al", "ti", "ceramic", "composite"]
	for n_target in [100, 250]:
		var have := 0
		for id in g.world.order:
			if g.world.pieces[id].mat in mats and g.world.pieces[id].body != null:
				have += 1
		for i in range(have, n_target):
			var at := cc + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
			var h := Vector2(14, 10)
			g.world.add_piece("plate", PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)]), {"mat": mats[i % 5], "mass": 0.2})
		g.world.dirty_links = true
		var spawn_worst := await _worst(120)
		stalls.append(["%d 件碎料同时生成（最慢一帧）" % (n_target - have), spawn_worst, spawn_worst])
		_row("%d 件散落碎料（稳定后）" % n_target, await measure(240), n_target > 100)
	g.queue_free()
	await _frames(4)
	await _spawn("tug", {"skill_grapple_multi": 3})
	await _frames(30)
	for i in 250:
		var at := cc + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
		var h := Vector2(14, 10)
		g.world.add_piece("plate", PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)]), {"mat": mats[i % 5], "mass": 0.2})
	g.world.dirty_links = true
	await _frames(180)
	g.tools.tool = 3
	g.tools.toggle_multi(false)
	g.drone.global_position = cc + Vector2(0, 7.0 * Geom.M)
	g.bot.aim = cc + Vector2(0, -1.0 * Geom.M)
	g.bot.lmb = true
	await _frames(3)
	for i in 30:
		var p := cc + Vector2(i * 0.8 * Geom.M - 12.0 * Geom.M, 9.0 * Geom.M)
		g.world.rope_fx.snap(PackedVector2Array([p, p + Vector2(0, 3.0 * Geom.M), p + Vector2(0, 6.0 * Geom.M)]), p + Vector2(0, 3.0 * Geom.M), 0.8)
	g.bot.move = Vector2(0.5, 0)
	_row("250 件 + 范围抓 11 件拖动 + 30 根缆甩动", await measure(180), true)
	g.bot.lmb = false
	g.bot.move = Vector2.ZERO
	await _done()
	# --- the laser cutting on and on through M-14's hull
	await _spawn("m14")
	await _frames(60)
	g.tools.tool = 2
	var hull = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not g.world.hidden(g.world.frame(p) * Geom.centroid(p.poly)):
			hull = p
			break
	var hc: Vector2 = g.world.frame(hull) * Geom.centroid(hull.poly)
	g.drone.global_position = hc + Vector2(0, -4.0 * Geom.M)
	g.bot.lmb = true
	var cut_m := {}
	for k in 4:
		g.bot.aim = hc + Vector2(-3.0 * Geom.M + k * 2.0 * Geom.M, 2.0 * Geom.M)
		var m := await measure(60)
		if cut_m.is_empty():
			cut_m = m
		else:
			for key in ["avg", "process", "physics", "render_cpu", "render_gpu", "draws", "low1"]:
				cut_m[key] = (cut_m[key] * k + m[key]) / (k + 1)
			for key in ["p95", "p99", "max"]:
				cut_m[key] = maxf(cut_m[key], m[key])
		g.drone.global_position = hc + Vector2(-3.0 * Geom.M + k * 2.0 * Geom.M, -4.0 * Geom.M)
	g.bot.lmb = false
	_row("M-14 连续激光切割", cut_m)
	# the terminal and the star map opened and closed
	var t0 := Time.get_ticks_usec()
	g.open_console("terminal")
	await process_frame
	stalls.append(["打开终端（首帧）", (Time.get_ticks_usec() - t0) / 1000.0, await _worst(30)])
	if g.console_ui != null and g.console_ui.has_method("close"):
		g.console_ui.close()
	await _frames(10)
	await _done()
	# --- SA-200 furling all four corners
	await _spawn("sa200")
	await _frames(60)
	for w in ["GND"]:
		g.sys.set_switch(w, true)
		g.world.ctrls[w].state = true
	for q in ["NW", "NE", "SE", "SW"]:
		g.sys.set_switch("W-" + q, false)
		g.world.ctrls["W-" + q].state = false
		g.sys.set_switch("F-" + q, true)
		g.world.ctrls["F-" + q].state = true
	await _frames(30)
	_row("SA-200 四角同时收卷", await measure(240))
	await _done()
	# --- ARK-01: close, then the whole ship in view
	await _spawn("ark01")
	await _frames(120)
	_row("ARK-01 近 2000 零件（跟随镜头）", await measure(240))
	g.zoom_override = 0.08
	g.cam_override = Vector2(300.0 * Geom.M, 0)
	await _frames(90)
	_row("ARK-01 全船拉远", await measure(240))
	g.zoom_override = -1.0
	g.cam_override = null
	# a save and a load of the biggest ship
	t0 = Time.get_ticks_usec()
	SaveGame.save(g)
	stalls.append(["ARK-01 存档", (Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 1000.0])
	# the 25 s autosave in play is written on a worker thread: what the frame still pays
	t0 = Time.get_ticks_usec()
	SaveGame.save_async(g)
	var async_ms := (Time.get_ticks_usec() - t0) / 1000.0
	SaveGame.settle()
	stalls.append(["ARK-01 自动存档（后台写，主线程部分）", async_ms, async_ms])
	await _done()
	SaveGame.load_requested = true
	await _spawn("ark01")
	await _done()
	SaveGame.clear()
	_report()
	quit()


func _report() -> void:
	var out := "# 60 FPS 基准（tests/perf_bench.gd）\n\n"
	out += "日期：%s。机器：%s；显卡：%s。窗口 1920×1080（%s），垂直同步关，帧率不设上限。帧时间是相邻两帧的真实间隔（含脚本、物理、渲染提交），目标是 16.67 ms（60 FPS）。\n\n" % [Time.get_datetime_string_from_system(), OS.get_processor_name(), RenderingServer.get_video_adapter_name(), "可见窗口" if _arg("visible", "0") == "1" else "测试窗口放在屏幕外，渲染照常进行"]
	out += "| 场景 | 平均 | P95 | P99 | 最长 | 1% low | ≈FPS | 脚本 | 物理 | 渲染 CPU | 渲染 GPU | 绘制调用 | 60 FPS |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r in rows:
		var m: Dictionary = r[1]
		var ok: bool = m.avg <= 16.67 and m.p99 <= 16.67
		out += "| %s%s | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f | %.2f | %.2f | %.2f | %.2f | %.0f | %s |\n" % [r[0], "（极端压力）" if r[2] else "", m.avg, m.p95, m.p99, m.max, m.low1, 1000.0 / maxf(m.avg, 0.01), m.process, m.physics, m.render_cpu, m.render_gpu, m.draws, "通过" if ok else "**未达标**"]
	out += "\n切换时的卡顿（ms）：\n\n| 切换 | 首帧 | 之后 1 s 内最慢一帧 |\n|---|---|---|\n"
	for s in stalls:
		out += "| %s | %.1f | %.1f |\n" % s
	out += "\n说明：“脚本”一栏用的是 Godot 的 TIME_PROCESS 统计，它把引擎空闲等待也算进去了，偏高，只能作参考；实际耗时以帧间隔为准。\n"
	# in the project tests/out; from the packed game (read-only res://) the user data folder too
	for path in ["res://tests/out/perf_bench.md", "user://perf_bench.md"]:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(out)
			f.close()
			print("report: ", ProjectSettings.globalize_path(path))
	print(out)
