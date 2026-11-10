extends SceneTree
# IC-120's ice melting is seen going (scripts/ice_fx.gd; user 2026-11-10 "怎么突然消失"): a block
# a heater works on is drawn shrinking every frame, its drawn area following the ice left in it
# (1 - melt), never jumping to nothing; the melt itself (ice.gd) is untouched: the same 24 s a
# block, the same water in the main; meltwater beads, runs to the main, pulses along it.
# godot --headless --path . --fixed-fps 60 -s tests/ice_melt_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_icemelt_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	print("IC-120: the ice seen melting")
	Game.contract = {}
	Game.start_ship = "ic120"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var ic = g.ice
	var fx = ic.fx
	check(fx != null, "the ice has its drawing")
	var blk = g.world.tag("ICE-3T")
	var a0 := Geom.area(blk.poly)
	g.do_wrench(_ctrl(g, "HT-3"))
	var areas: Array = []
	var melts: Array = []
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var worst_us := 0
	while frames < 60 * 30:
		var f0 := Time.get_ticks_usec()
		await process_frame
		worst_us = maxi(worst_us, Time.get_ticks_usec() - f0)
		frames += 1
		if frames % 300 == 0:
			print("  .. frame %d melt %.3f area %.0f  %d ms" % [frames, float(ic.melt["ICE-3T"]), fx.visible_area("ICE-3T"), Time.get_ticks_msec() - t0])
		var gone: bool = blk.gone
		var a: float = fx.visible_area("ICE-3T")
		if gone:
			areas.append(0.0)
			break
		if a >= 0.0:
			areas.append(a)
			melts.append(float(ic.melt["ICE-3T"]))
	print("  frames %d, %.1f s game time, real %d ms" % [frames, frames / 60.0, Time.get_ticks_msec() - t0])
	check(blk.gone, "the block melts through")
	check(absf(frames / 60.0 - 24.0) < 1.0, "in the same 24 s it always took (%.1f s)" % (frames / 60.0))
	await _frames(2)
	check(g.world.live.has(blk.id) == false, "and is out of the live drawing once gone")
	var up := 0
	var big := 0.0
	for i in range(1, areas.size() - 1):
		if areas[i] > areas[i - 1] + a0 * 0.002:
			up += 1
		big = maxf(big, (areas[i - 1] - areas[i]) / a0)
	check(areas.size() > 1000, "drawn every frame of it (%d frames)" % areas.size())
	check(up == 0, "its drawn area never grows back (%d frames)" % up)
	check(big < 0.01, "and never drops more than 1%% in a frame (largest %.2f%%)" % (big * 100.0))
	var last: float = areas[areas.size() - 2] / a0
	check(last < 0.02, "the last frame before it is gone shows almost nothing left (%.2f%%), not a whole block" % (last * 100.0))
	var worst_dev := 0.0
	for i in melts.size():
		if melts[i] < 0.94:
			worst_dev = maxf(worst_dev, absf(areas[i] / a0 - (1.0 - melts[i])))
	check(worst_dev < 0.06, "what is drawn is the ice left (worst %.1f%% off 1 - melt)" % (worst_dev * 100.0))
	var half := -1.0
	for i in melts.size():
		if melts[i] >= 0.5:
			half = areas[i] / a0
			break
	check(absf(half - 0.5) < 0.06, "half melted, half drawn (%.2f)" % half)
	check(g.sys.fvol["melt"].amount > 0.5, "the same water in the main (%.2f m³)" % g.sys.fvol["melt"].amount)
	await _frames(60)
	
	check(fx.drops.size() > 0 or fx._pulses.size() > 0, "meltwater about (%d globules, %d pulses in the main)" % [fx.drops.size(), fx._pulses.size()])
	var seen_pulse: bool = fx._pulses.size() > 0
	for i in 600:
		await process_frame
		if fx._pulses.size() > 0:
			seen_pulse = true
	check(seen_pulse, "meltwater reaches the main and runs along it")
	print("  worst frame %.1f ms (headless)" % (worst_us / 1000.0))
	# the autosave (every 25 s of play) writes on a worker: let it finish before the game goes
	if SaveGame._writing >= 0:
		WorkerThreadPool.wait_for_task_completion(SaveGame._writing)
		SaveGame._writing = -1
	g.queue_free()
	await _frames(2)
	print("ICE MELT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
