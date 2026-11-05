extends "res://tests/guide_check.gd"
# 2026-11-05 全息档案知识卡（scripts/codex_hud.gd、scripts/codex_fx.gd）样板：热管线与余热、舱压、电缆三张卡，
# 各取入场中途（扫描光刷到一半）和静止两帧；图鉴书里同一张图也会动。只用测试存档，不动真实鼠标。
#   tools/run_test.sh tests/codex_card_fx_shot.gd

const IDS := ["s_heat", "s_gas", "cable"]


func _initialize() -> void:
	Career.path = "user://zp_test_codex_fx_career.json"
	SaveGame.path = "user://zp_test_codex_fx_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


# per frame: the game's own CPU time (process + draw submission) and the GPU's render time, medians
func _avg(n: int) -> Array:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var cpu: Array = []
	var gpu: Array = []
	for i in n:
		await process_frame
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	cpu.sort()
	gpu.sort()
	return [cpu[n / 2] + gpu[n / 2], cpu[n / 2], gpu[n / 2]]


func _run() -> void:
	var was := Txt.reduce_motion
	Txt.reduce_motion = false
	Txt.zh = true
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.save()
	await _spawn()
	await _frames(30)
	var hud = g.codex_hud
	# frame time with no card, then with the heat card up (its shimmer on), vsync off
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# rounds of no card / the heat card up, alternating; the medians of each (other work on the machine
	# moves single runs by several ms)
	CodexFx.prof_off = OS.get_environment("CX_PROF")
	var offs: Array = []
	var ons: Array = []
	var parts_off: Array = []
	var parts_on: Array = []
	Codex.mark("s_heat")
	for round in 5:
		g.codex.card = ""
		await _wait_s(0.5)
		var o: Array = await _avg(120)
		offs.append(o[0])
		parts_off.append(o)
		g.codex.card = "s_heat"
		g.codex.card_t = 0.0
		await _wait_s(0.8)
		var o2: Array = await _avg(120)
		ons.append(o2[0])
		parts_on.append(o2)
	offs.sort()
	ons.sort()
	var d: Array = []
	for k in 5:
		d.append(ons[k] - offs[k])
	var dc: Array = []
	var dg: Array = []
	for k in 5:
		dc.append(parts_on[k][1] - parts_off[k][1])
		dg.append(parts_on[k][2] - parts_off[k][2])
	dc.sort()
	dg.sort()
	CodexHud.prof_us = 0
	CodexHud.prof_n = 0
	await _wait_s(2.0)
	print("CODEX FX PERF the card's own drawing: %.3f ms a frame (%d frames)" % [CodexHud.prof_us / 1000.0 / maxi(1, CodexHud.prof_n), CodexHud.prof_n])
	print("CODEX FX PERF card cost: cpu %+.3f ms, gpu %+.3f ms (median of 5 paired rounds)" % [dc[2], dg[2]])
	print("CODEX FX PERF median no card (cpu+gpu) %.2f ms · heat card up %.2f ms · difference %+.2f ms (rounds: off %s, on %s)" % [offs[2], ons[2], ons[2] - offs[2], str(offs.map(func(v): return snappedf(v, 0.01))), str(ons.map(func(v): return snappedf(v, 0.01)))])
	g.codex.card = ""
	await _wait_s(0.6)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	for id in IDS:
		Codex.mark(id)
		g.codex.card = id
		g.codex.card_t = 0.0
		g.codex.last = id
		await _wait_s(0.22)
		Cap.save(root, "res://tests/out/codex_fx_%s_enter.png" % id)
		check(hud.card_c != null and hud.card_c.size.y < hud.card_height(id) - 2.0, "%s: the scan is still wiping the card on (%.0f of %.0f)" % [id, hud.card_c.size.y, hud.card_height(id)])
		await _wait_s(1.6)
		Cap.save(root, "res://tests/out/codex_fx_%s.png" % id)
		check(is_equal_approx(hud.card_c.size.y, hud.card_height(id)), "%s: the whole card is up" % id)
		check(CodexFx.level(id) >= 1 and CodexFx.level(id) <= 3, "%s: its danger level %d" % [id, CodexFx.level(id)])
		g.codex.card = ""
		await _wait_s(0.6)
	check(CodexFx.LEVEL.size() == CodexData.E.size(), "every entry has a level (%d of %d)" % [CodexFx.LEVEL.size(), CodexData.E.size()])
	# the book: the same drawing, alive there too
	hud.open_book("s_heat")
	await _wait_s(0.8)
	Cap.save(root, "res://tests/out/codex_fx_book_s_heat.png")
	if hud.page != null and hud.page.has_method("close"):
		hud.page.close()
	await _wait_s(0.3)
	# reduced motion: the card is simply there
	Txt.reduce_motion = true
	g.codex.card = "s_gas"
	g.codex.card_t = 0.0
	await _frames(3)
	check(is_equal_approx(hud.card_c.size.y, hud.card_height("s_gas")), "reduced motion: the card is there at once")
	g.codex.card = ""
	Txt.reduce_motion = was
	print("CODEX FX %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
