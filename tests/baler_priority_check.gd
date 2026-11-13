extends "res://tests/seg4_sketch.gd"
# 压块优先 (2026-11-12, user): a crate for the baler is the next thing a freight train takes at its next free
# moment, so the press starts in about 30 s even when the trains are busy; but a run of press crates lets the
# other freight through (FW.PRESS_STREAK). The same busy port twice — press crates in the queue's order (the
# before, FW.PRESS_FIRST off) and first — then four press jobs at once with other freight waiting.
#   tools/run_test.sh tests/baler_priority_check.gd --fixed-fps 60 --headless

const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_baler_prio_career.json"
	SaveGame.path = "user://zp_test_baler_prio_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _career() -> void:
	super._career()
	var gs: Array = Career.data.goods
	for i in 6:
		gs.append({"uid": "p%d" % i, "cat": "equip", "tag": "WINCH-T", "nk": "p_winch", "cond": 0.5, "value": 300.0, "mass": 0.6, "ship": "tug"})
	Career.data.goods = gs
	Career.save()


# other freight waiting: n crates from the cargo district to the trade port
func _busy(n: int, tag: String) -> void:
	for i in n:
		FW.queue.append({"from": "cargo", "to": "trade", "key": "equip", "use": "equip", "name": "%s-%d" % [tag, i], "look": {}, "filler": tag})


func _filler_queued(tag: String) -> int:
	var n := 0
	for it in FW.queue:
		if str(it.get("filler", "")) == tag:
			n += 1
	return n


func _filler_left(tag: String) -> int:
	var n := 0
	for it in FW.queue:
		if str(it.get("filler", "")) == tag:
			n += 1
	for tr in FW.trains:
		for i in 2:
			if tr.wag[i] is Dictionary and str(tr.wag[i].get("filler", "")) == tag:
				n += 1
	return n


# send uid to the press with the port busy; -> [seconds it waited for its crate, by train]
func _press_wait(uid: String) -> Array:
	var r := ProcessLine.send_to_press(uid)
	if not bool(r.ok):
		return [-1.0, false]
	var t := 0.0
	var jid := ""
	var by_train := false
	while t < 200.0:
		await process_frame
		t += 1.0 / 60.0
		var cur: Dictionary = ProcessLine.press().get("cur", {})
		if jid == "" and not cur.is_empty():
			jid = str(cur.id)
		if cur.is_empty() or str(cur.get("id", "")) != jid:
			continue
		if not preload("res://scripts/bale_press.gd").hand_now(cur).is_empty():
			by_train = true
		if str(ProcessLine.press_phase()[0]) != "wait":
			return [t, by_train]
	return [t, by_train]


func _settle() -> void:
	# the press empty, the queue empty, the trains standing by
	var t := 0.0
	while t < 240.0:
		await process_frame
		t += 1.0 / 60.0
		var pr := ProcessLine.press()
		if pr.get("cur", {}).is_empty() and (pr.get("jobs", []) as Array).is_empty() and FW.queue.is_empty():
			var idle := true
			for tr in FW.trains:
				if not FW._cargo(tr).is_empty():
					idle = false
			if idle:
				return


func _run() -> void:
	_career()
	await _spawn()
	await _frames(30)
	var w0 := 0
	while not ProcessLine.press_by_train() and w0 < 600:
		await process_frame
		w0 += 1
	check(ProcessLine.press_by_train(), "trains run (%d, the ring %s)" % [FW.trains.size(), "running" if FW.ring_alive() else "dead"])
	# ---- the trains free: about 30 s
	var free := await _press_wait("g:p5")
	check(bool(free[1]) and float(free[0]) <= 40.0, "the trains free: its crate comes by train in about 30 s (%.1f s)" % float(free[0]))
	await _settle()
	# how long the train really takes (the press's own fallback set far off while measuring)
	ProcessLine.PRESS_WAIT_MAX = 400.0
	# ---- busy, in the queue's order (the before)
	FW.PRESS_FIRST = false
	_busy(8, "A")
	await _frames(90)
	var before := await _press_wait("g:p0")
	await _settle()
	# ---- busy, the press first
	FW.PRESS_FIRST = true
	var del0 := FW.delivered
	_busy(8, "B")
	await _frames(90)
	var after := await _press_wait("g:p1")
	print("  waited: queue order %.1f s (by train %s), press first %.1f s (by train %s)" % [float(before[0]), str(before[1]), float(after[0]), str(after[1])])
	ProcessLine.PRESS_WAIT_MAX = 60.0
	check(bool(after[1]) and float(after[0]) <= 90.0, "busy, press first: by train once the train is through what it was doing (%.1f s)" % float(after[0]))
	check(float(after[0]) < float(before[0]) * 0.7, "much sooner than in the queue's order (%.1f s against %.1f s)" % [float(after[0]), float(before[0])])
	# the rest still gets there
	var t := 0.0
	while _filler_left("B") > 0 and t < 300.0:
		await process_frame
		t += 1.0 / 60.0
	check(_filler_left("B") == 0, "and the other freight still all goes (%d left after %.0f s, %d crates delivered)" % [_filler_left("B"), t, FW.delivered - del0])
	await _settle()
	# ---- four press jobs at once with other freight waiting: it is let through between them
	FW.press_yields = 0
	_busy(4, "C")
	await _frames(30)
	for i in [2, 3, 4]:
		ProcessLine.send_to_press("g:p%d" % i)
	var c_done_at := -1.0
	var press_done_at := -1.0
	t = 0.0
	while t < 400.0:
		await process_frame
		t += 1.0 / 60.0
		if c_done_at < 0.0 and _filler_queued("C") < 4:
			c_done_at = t
		var pr := ProcessLine.press()
		if press_done_at < 0.0 and pr.get("cur", {}).is_empty() and (pr.get("jobs", []) as Array).is_empty():
			press_done_at = t
		if c_done_at >= 0.0 and press_done_at >= 0.0:
			break
	print("  three press jobs: the first other crate went aboard at %.0f s, the press done at %.0f s, %d yields" % [c_done_at, press_done_at, FW.press_yields])
	check(FW.press_yields >= 1 and c_done_at >= 0.0 and (press_done_at < 0.0 or c_done_at < press_done_at), "other freight is not starved by a run of press jobs: after %d press crates in a row a train took other freight first (%d yields; it went aboard at %.0f s, the press finished at %.0f s)" % [FW.PRESS_STREAK, FW.press_yields, c_done_at, press_done_at])
	check(press_done_at >= 0.0, "and all three pressed")
	FW.PRESS_FIRST = true
	print("BALER PRIORITY %s (%d of %d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	quit(1 if fails > 0 else 0)
