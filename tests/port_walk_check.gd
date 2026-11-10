extends "res://tests/guide_check.gd"
# 84 号: the port on foot. Due once the first ship is stripped; forced (no way to end it, tools
# locked); each step moves on only on the real thing — the drone out of the gate, in the ring, at
# the stop; E at each desk and console opens its page and closing it counts; the shuttle ridden to
# every district; back in the berth; done, it is not due again. Replayed from the menu it can be
# ended. Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/port_walk_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_port_walk_career.json"
	SaveGame.path = "user://zp_test_port_walk_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _put(p: Vector2) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(6)


func _e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(6)


func _callouts() -> void:
	var wk = g.port_walk
	var n := 0
	while wk != null and not wk.done and wk.page_open() and not wk.callouts_done() and n < 20:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		ev.pressed = true
		wk._input(ev)
		n += 1
		await _frames(2)


func _close() -> void:
	await _callouts()
	var ui = g.console_ui
	if ui == null:
		return
	if ui.has_method("close"):
		ui.close()
	elif ui.get("on_close") != null and ui.on_close.is_valid():
		ui.on_close.call()
	await _frames(6)


# every step of a walk, by the player's own moves; the number done
func _walk(wk) -> int:
	var n: int = wk.steps.size()
	var ok_steps := 0
	while not wk.done and wk.step < n:
		var at: int = wk.step
		var legs: int = wk.back.size()
		var k: String = wk.kind()
		var z: String = wk.zone()
		match k:
			"desk":
				await _put(g.port_access.spot(z))
				await _e()
				check(wk.page_open(), "%s desk: E opens its works page" % z)
				if z == "power":
					await _shot("desk_open")
				await _frames(10)
				check(wk.step == at, "  and it holds while the page is open")
				await _close()
			"console":
				await _put(preload("res://scripts/port_structure.gd").console_spot(z))
				await _e()
				check(wk.page_open() or wk.step > at, "%s console: E opens it" % z)
				if z == "cargo":
					await _frames(20)
					await _shot("console_open")
				if z in ["power", "trade"]:
					await _callouts()
					await _frames(4)
				if wk.step == at:
					await _close()
			"screen":
				# user 2026-10-28: the save keeps the very step reached (a quit goes on from it)
				check(Career.guide_at("port_walk") == wk.step, "the save keeps the step reached (%d, want %d)" % [Career.guide_at("port_walk"), wk.step])
				await _callouts()
				check(_press("动力区控制屏"), "the console's power screen button")
				await _frames(10)
				check(wk.page_open(), "the power screen open")
				await _close()
			"exchange":
				if g.console_ui == null:
					await _put(preload("res://scripts/port_structure.gd").console_spot(z))
					await _e()
				await _callouts()
				check(_press("打开交易行"), "the console's exchange button")
				await _frames(10)
				check(wk.page_open(), "the exchange open")
				await _close()
			# 128 号 第 4 段 收尾: the processing walk is its first heat (tests/seg4_finish_check.gd flies it)
			"gallery":
				await _put(wk.target())
				check(wk.step > at, "process: up onto the gallery")
			"furnace":
				await _put(wk.target() + Vector2(0, -0.6) * Geom.M)
				await _e()
				check(wk.step > at, "process: E at the furnace console opens the queue (%s)" % wk._page())
			"queue":
				if g.console_ui != null and g.console_ui.has_method("queue_one"):
					g.console_ui.queue_one()
				await _frames(10)
				check(wk.step > at, "process: a heat queued (%d batches)" % ProcessQueue.open_entries().size())
				await _close()
			"watch":
				await _close()
				var wf := 0
				while wk.step == at and wf < 60 * 60:
					await _frames(1)
					wf += 1
				check(wk.step > at, "process: watched (%.1f s, %s)" % [wf / 60.0, str(g.industrial_heat.info().title)])
			"shelf", "mill":
				await _put(wk.target())
				await _e()
				check(wk.page_open(), "%s: E opens it" % k)
				if k == "mill":
					await _frames(10)
					await _shot("mill_open")
				await _close()
			"gate":
				check(wk.step == at, "the gate waits for the drone")
				await _put(wk.target())
			"hub":
				await _put(Backdrop.port_centre_px())
			"station":
				# 131 号: the berth's own stop first (the step's own stop)
				await _put(wk.target())
			"ride":
				await _put(Tram.station_at(wk._board_at()))
				await _e()
				check(wk._page() == "transit", "ride to %s: E at the stop opens the stops" % z)
				check(_press(Port.name_of(z)), "  and %s is clicked" % z)
				var f := 0
				var rode := false
				while wk.step == at and f < 60 * 50:
					await _frames(1)
					f += 1
					if g.tram.riding and not rode:
						rode = true
						if z == "tug":
							for i in 120:
								await process_frame
							await _shot("riding")
				check(rode and wk.step > at, "  ridden to %s (%.1f s)" % [z, f / 60.0])
			"home":
				await _put(wk.target())
			"repair":
				# 108 号: the berth page of the terminal, looked at, then closed
				g.open_console("terminal")
				await _frames(20)
				g.console_ui._open_app(1)
				await _frames(20)
				check(wk.page_open(), "repair: the terminal's berth page counts")
				# 131 号 追加: the walk's card never lies over a full-screen page; the terminal shows the step itself
				check(not wk.layer.visible, "  and the walk's card is hidden over the terminal")
				await _shot("repair")
				await _frames(200)
				check(wk.step == at, "  it holds while the page is open")
				await _close()
			"end":
				await _frames(int(wk.END_S * 60.0) + 10)
		await _frames(4)
		if wk.step > at or wk.done:
			# (a step whose condition already holds passes with the one before: the processing walk's queue
			# step when batches are queued already)
			ok_steps += maxi(1, wk.step - at) if not wk.done else 1
		elif legs > 0 and wk.back.size() < legs:
			# a leg out to where the walk starts: on, not counted
			pass
		else:
			check(false, "step %d (%s %s) did not move on" % [at + 1, k, z])
			break
	return ok_steps


var shots := {}


func _shot(name: String) -> void:
	if shots.has(name):
		return
	shots[name] = true
	await _frames(4)
	Cap.save(root, "res://tests/out/port_walk_%s_zh.png" % name)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true}
	Career.data.money = 20000.0
	Career.save()
	var PW = preload("res://scripts/port_walk.gd")
	check(not PW.due(), "not before the first ship")
	Career.data.history = [{"id": "TUG-001"}]
	check(PW.due(), "due once the first ship is stripped (even after the old card tour)")
	await _spawn()
	await _frames(20)
	g.start_port_walk(true)
	await _frames(10)
	var wk = g.port_walk
	check(wk != null and g.walk_on(), "it starts")
	check(not wk.close_b.visible, "forced: no way to end it the first time")
	check(not g.tool_ok(2) and not g.tool_ok(3), "tools locked: flying only")
	await _shot("1")
	var n: int = wk.steps.size()
	var ok_steps: int = await _walk(wk)
	check(ok_steps == n, "every step done (%d of %d)" % [ok_steps, n])
	check(wk.done and not g.walk_on() and Career.data.seen.get("port_walk", false) and not PW.due(), "done: not due again")
	check(g.tool_ok(2), "tools open again")
	check(n == 7, "108/131 号: the first walk is the core only, by shuttle (%d steps)" % n)
	check(str(wk.steps[0]) == str(["station", "salvage"]) and str(wk.steps[1]) == str(["ride", "ring"]), "131 号: first the berth's stop, then the shuttle to the ring (no flying the corridor)")
	check(PW.due_part(g) == "", "no district is of use yet: nothing more due")
	# replayed from the menu: it can be ended
	g.start_port_walk(false)
	await _frames(4)
	check(g.walk_on() and g.port_walk.close_b.visible, "replayed from the menu: it can be ended")
	g.port_walk.stop()
	await _frames(2)
	check(not g.walk_on(), "and ending it ends it")
	# 108 号 Q13: ingots kept for the processing district — its walk, the next time the berth is free
	ProcessQueue.add("ferrous_scrap:1", "gr7", "T-1", 4.0)
	Career.data.history.append({"id": "GR-7"})
	check(PW.due_part(g) == "process", "ingots kept for processing: the processing walk is due (%s)" % PW.due_part(g))
	g.drone.global_position = Dock.centre() * Geom.M
	g.start_port_walk(true, "process")
	await _frames(6)
	var pw = g.port_walk
	check(pw.part == "process" and not pw.back.is_empty() and pw.kind() == "station" and pw.zone() == "salvage", "it starts from the berth: to the berth's stop first")
	check(pw.count.text.begins_with("加工区现场导览"), "its card names the district (%s)" % pw.count.text)
	await _shot("process_start")
	var pn: int = pw.steps.size()
	var pok: int = await _walk(pw)
	check(pok == pn and pw.done and Career.data.seen.get("walk_process", false), "the processing walk done (%d of %d steps)" % [pok, pn])
	# one district a settled job: another of use waits for the next job
	Career.data.parts = [{"uid": "x1", "cls": "sail", "tag": "SL-1", "cond": 0.95, "value": 9000.0}]
	var two := PW.due_part(g)
	check(two == "", "another district of use waits for the next settled job (%s)" % two)
	Career.data.history.append({"id": "TW-64"})
	check(PW.due_part(g) != "", "and is due after it (%s)" % PW.due_part(g))
	# a walk cut short at the shuttle home (user 2026-10-28: back at the very step)
	var at_ride: int = wk.steps.find(["ride", "salvage"])
	Career.data.guide_at = {"port_walk": at_ride}
	Career.data.seen.erase("port_walk")
	g.drone.global_position = Dock.centre() * Geom.M
	g.start_port_walk(true)
	await _frames(4)
	var rw = g.port_walk
	check(rw.back.is_empty() and rw.step >= at_ride + 1 and rw.kind() != "station", "resumed inside the berth: no detour out to the salvage stop (%d)" % rw.step)
	rw.stop()
	await _frames(2)
	# a walk cut short under the old 21-step round: its number is dropped, the core starts over
	Career.data.walk_v = 1
	Career.data.guide_at = {"port_walk": 14}
	Career.data.seen.erase("port_walk")
	g.start_port_walk(true)
	await _frames(4)
	check(g.port_walk.step == 0 and int(Career.data.walk_v) == 3, "an old save's step 14 of 21: the core starts at its first step")
	g.port_walk.stop()
	await _frames(2)
	# 131 号: a walk cut short in the 8-step core (at its ride home, step 5 of 8) goes on at the same place
	Career.data.walk_v = 2
	Career.data.guide_at = {"port_walk": 4}
	Career.data.seen.erase("port_walk")
	g.start_port_walk(true)
	await _frames(4)
	check(g.port_walk.step >= 3 and str(g.port_walk.steps[3]) == str(["ride", "salvage"]) and g.port_walk.back.is_empty() and int(Career.data.walk_v) == 3, "an 8-step save migrates to the ride home, then advances when already in the berth (%d)" % g.port_walk.step)
	g.port_walk.stop()
	await _frames(2)
	print("PORT WALK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
