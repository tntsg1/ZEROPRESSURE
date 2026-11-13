extends "res://tests/seg4_sketch.gd"
# The baler's whole run by the real freight train (2026-11-12, user: "压块机从火车上卸下来，然后再放到这个压块机
# 里面，这动画做得很糟糕"): a piece sent to the press waits for its crate; the train takes it from the cargo
# district to the processing district's stop, stands while the hatch under its wagon opens and the hoist takes
# it, and only then the press runs: land → feed → close → press → tie → eject, the bale back in the warehouse,
# nothing lost. Every frame of it: the piece never inside a wall, the gate (shut), the platen, the probe, the
# mill's reheat furnace; it rests on the belt and nowhere under it; the hoist's arms clear the probe. A charged
# vessel is turned back at the probe and goes back up the hatch into the warehouse. With a window: the frame
# time with the press idle and running (tests/out/baler_perf.txt), and a frame of the hand-over.
#   tools/run_test.sh tests/baler_flow_check.gd --fixed-fps 60 [--headless]

const BP = preload("res://scripts/bale_press.gd")
const FW = preload("res://scripts/freight_works.gd")
const REHEAT := Rect2(42.8, 19.6, 4.4, 3.8)   # process_art REHEAT + process_works MILL_OFF


func _initialize() -> void:
	Career.path = "user://zp_test_baler_flow_career.json"
	SaveGame.path = "user://zp_test_baler_flow_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


# what clips this frame ([] when nothing)
func _clips(cur: Dictionary, st: String, u: float) -> Array:
	var out: Array = []
	var pose: Dictionary = BP._pose(cur, st, u)
	var lk: Array = BP._look(cur)
	var psz: Vector2 = lk[0]
	var hs: Dictionary = BP.hoist(cur, st, u, psz.x, psz.y)
	var probe := Rect2(BP.PROBE - Vector2(0.25, 0.0), Vector2(0.5, 1.0))
	# the arms (each a strip from the trolley down to under its pad)
	for sd in [-1.0, 1.0]:
		var ax: float = float(hs.x) + sd * (float(hs.sp) * 0.5 + 0.18)
		var arm := Rect2(ax - 0.12, BP.TROLLEY_B, 0.24, float(hs.pad) + 0.35 - BP.TROLLEY_B)
		if arm.intersects(probe):
			out.append("arm×probe")
		if arm.intersects(REHEAT):
			out.append("arm×reheat")
	if not bool(pose.shown):
		return out
	var sz: Vector2 = pose.size
	var w := sz.x * float(pose.sx)
	var h := sz.y * float(pose.sy)
	var at: Vector2 = pose.at
	var r := Rect2(at.x - w * 0.5, at.y - h, w, h).grow(-0.02)
	var B := BP.BOX
	var walls := [Rect2(B.position.x - 0.18, B.position.y, 0.18, B.size.y), Rect2(B.end.x, BP.GATE_Y.y, 0.18, B.end.y - BP.GATE_Y.y), Rect2(B.end.x, B.position.y, 0.18, BP.GATE_Y.x - B.position.y)]
	var gate := BP.gate_at(st, u)
	var gh := BP.GATE_Y.y - BP.GATE_Y.x
	walls.append(Rect2(B.end.x + 0.02, BP.GATE_Y.x - gh * gate, 0.14, gh))
	if st != "eject":
		walls.append(Rect2(B.position.x, B.end.y, B.size.x, 0.4))   # the shut bottom doors
	for wr in walls:
		if r.intersects(wr):
			out.append("piece×wall/gate %s" % str(wr))
	var face := BP.face_at(cur, st, u)
	if r.intersects(Rect2(B.position.x + 0.04, face - BP.PLATEN_T, B.size.x - 0.08, BP.PLATEN_T)):
		out.append("piece×platen")
	if r.intersects(probe):
		out.append("piece×probe")
	if r.intersects(REHEAT):
		out.append("piece×reheat")
	# on the belt's stretch it lies on it, never in it
	if r.end.y > BP.BELT_TOP + 0.03 and r.position.y < BP.BELT_TOP + BP.BELT_T and r.end.x > BP.BELT.x + 0.05 and r.position.x < BP.BELT.y:
		out.append("piece×belt")
	return out


func _run() -> void:
	_career()
	await _spawn()
	await _frames(30)
	var shots := DisplayServer.get_name() != "headless"
	var box := PortStructure.box("process")
	var M := PortStructure.M()
	if shots:
		g.drone.global_position = box.position + Vector2(20.0, 24.0) * M
		g.drone.linear_velocity = Vector2.ZERO
		_put(box.position + Vector2(40.0, 22.3) * M, 1080.0 / (16.5 * M))
	# the trains running
	var w0 := 0
	while not ProcessLine.press_by_train() and w0 < 600:
		await process_frame
		w0 += 1
	check(ProcessLine.press_by_train(), "the freight trains run between the warehouse and the processing district (%d trains)" % FW.trains.size())
	# ---- perf: idle
	var perf := []
	if shots:
		await _frames(300)
		perf.append(await _frame_ms(300))
	# ---- the pod: by train, through the press
	var goods0: int = Career.data.get("goods", []).size()
	var r := ProcessLine.send_to_press("g:g1")
	check(bool(r.ok), "the pod sent to the press")
	var cur: Dictionary = ProcessLine.press().get("cur", {})
	if cur.is_empty():
		await _frames(2)
		cur = ProcessLine.press().get("cur", {})
	var jid := str(cur.get("id", ""))
	check(bool(cur.get("train", false)) and str(ProcessLine.press_phase()[0]) == "wait", "it waits for its train (%s)" % str(ProcessLine.press_phase()))
	var seen := {}
	var order: Array = []
	var crate_on := false
	var handed := false
	var hand_x := -1.0
	var clip_n := 0
	var clip_eg := []
	var shot_hand := false
	var active_ms := []
	var active_us := []
	var t := 0.0
	var last_us := Time.get_ticks_usec()
	while t < 260.0:
		await process_frame
		var now_us := Time.get_ticks_usec()
		var frame_ms := (now_us - last_us) / 1000.0
		last_us = now_us
		t += 1.0 / 60.0
		var c2: Dictionary = ProcessLine.press().get("cur", {})
		if c2.is_empty() or str(c2.get("id", "")) != jid:
			break
		var ph: Array = ProcessLine.press_phase()
		var st := str(ph[0])
		if order.is_empty() or order[-1] != st:
			order.append(st)
			print("  %.1f s: %s (trains: %s)" % [t, st, str(FW.trains.map(func(tr): return [tr.id, tr.place, str(tr.status)]))])
		seen[st] = true
		for tr in FW.trains:
			for i in 2:
				if tr.wag[i] is Dictionary and str(tr.wag[i].get("press", "")) == jid:
					crate_on = true
		var hn: Array = BP.hand_now(c2)
		if not hn.is_empty() and float(hn[2]) >= 0.0:
			handed = true
			hand_x = float(hn[3])
			if shots and not shot_hand and float(hn[2]) > 0.7:
				shot_hand = true
				_put(box.position + Vector2(BP.hatch_near(hand_x), 19.0) * M, 1080.0 / (10.0 * M))
				await _frames(2)
				Cap.save(root, "res://tests/out/baler_flow_hand.png")
				_put(box.position + Vector2(40.0, 22.3) * M, 1080.0 / (16.5 * M))
		var cl := _clips(c2, st, float(ph[1]))
		if not cl.is_empty():
			clip_n += 1
			if clip_eg.size() < 6:
				clip_eg.append("%s %.2f %s" % [st, float(ph[1]), str(cl)])
		if shots and st in ["land", "feed", "press", "eject"]:
			active_ms.append(frame_ms)
			active_us.append(BP.draw_us + BP.tick_us)
	check(crate_on, "its crate rode a freight train")
	check(handed and hand_x > 37.0 and hand_x < 51.0, "the train handed it down through the hatch under its wagon (wagon at %.1f m, hatch %.1f m)" % [hand_x, BP.hatch_near(hand_x)])
	var want := ["wait", "land", "feed", "close", "press", "tie", "eject"]
	check(order == want, "the press ran its steps in order only once it had it: %s" % str(order))
	check(clip_n == 0, "no frame where the piece or the hoist goes through anything (%d frames: %s)" % [clip_n, str(clip_eg)])
	await _frames(3)
	var bales := (Career.data.get("goods", []) as Array).filter(func(gd): return bool(gd.get("bale", false)) and str(gd.get("uid", "")) == "bale:" + jid)
	var inbox := (Career.data.get("inbox", []) as Array).filter(func(e): return str(e.get("uid", "")) == "bale:" + jid)
	var g1 := (Career.data.get("goods", []) as Array).filter(func(gd): return str(gd.get("uid", "")) == "g1")
	check(bales.size() + inbox.size() == 1 and g1.is_empty(), "nothing lost: the pod is gone, its bale is back in the warehouse (%d in store, %d waiting to go in)" % [bales.size(), inbox.size()])
	if shots and not active_ms.is_empty():
		active_ms.sort()
		perf.append({"mean": active_ms.reduce(func(a, b): return a + b, 0.0) / active_ms.size(), "p95": active_ms[int(active_ms.size() * 0.95)], "n": active_ms.size(), "press_us": active_us.reduce(func(a, b): return a + b, 0.0) / active_us.size()})
	# ---- a charged gas tank: stopped at the probe, back up the hatch, back in the warehouse
	var r2 := ProcessLine.send_to_press("g:g2")
	check(bool(r2.ok), "the charged O2 tank sent to the press")
	var j2 := ""
	var order2: Array = []
	var clip2 := 0
	t = 0.0
	while t < 260.0:
		await process_frame
		t += 1.0 / 60.0
		var c3: Dictionary = ProcessLine.press().get("cur", {})
		if j2 == "" and not c3.is_empty():
			j2 = str(c3.id)
		if c3.is_empty() or str(c3.get("id", "")) != j2:
			if j2 != "":
				break
			continue
		var ph2: Array = ProcessLine.press_phase()
		if order2.is_empty() or order2[-1] != str(ph2[0]):
			order2.append(str(ph2[0]))
		if not _clips(c3, str(ph2[0]), float(ph2[1])).is_empty():
			clip2 += 1
	check(order2 == ["wait", "land", "approach", "probe", "reject"] and clip2 == 0, "the charged one: %s, no clipping (%d)" % [str(order2), clip2])
	await _frames(3)
	var back := (Career.data.get("goods", []) as Array).filter(func(gd): return str(gd.get("uid", "")) == "g2")
	check(back.size() == 1, "and it is back in the warehouse")
	if shots:
		var f := FileAccess.open("res://tests/out/baler_perf.txt", FileAccess.WRITE)
		f.store_string("idle: %s\nrunning (land/feed/press/eject frames): %s\n" % [str(perf[0]) if perf.size() > 0 else "-", str(perf[1]) if perf.size() > 1 else "-"])
		f.close()
		print("PERF idle %s / running %s" % [str(perf[0]) if perf.size() > 0 else "-", str(perf[1]) if perf.size() > 1 else "-"])
	print("BALER FLOW %s (%d of %d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	quit(1 if fails > 0 else 0)


func _frame_ms(n: int) -> Dictionary:
	var a := []
	var bus := []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		a.append((now - last) / 1000.0)
		last = now
		bus.append(BP.draw_us + BP.tick_us)
	a.sort()
	return {"mean": a.reduce(func(x, y): return x + y, 0.0) / a.size(), "p95": a[int(a.size() * 0.95)], "n": a.size(), "press_us": bus.reduce(func(x, y): return x + y, 0.0) / bus.size()}
