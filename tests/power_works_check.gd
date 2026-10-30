extends SceneTree
# 100 号: the power district's plant run on its own (no scene). The governor holds 50 Hz and a load
# put on dips it before the valve catches up; the reactors' heat and rods follow the steam; each
# feeder's breaker closes when its district draws and opens a while after; the shore umbilical
# swings out and plugs in before the shore incomer closes, and stows after; stage 0 runs on the
# fuel cells, stage 2 on three units; a changeover is shown and put right with the grid untouched.
#   godot --headless --path . --fixed-fps 60 -s tests/power_works_check.gd
const PW = preload("res://scripts/power_works.gd")
var fails := 0
var checks := 0


func _initialize() -> void:
	Career.path = "user://zp_test_power100w_career.json"
	SaveGame.path = "user://zp_test_power100w_save.json"
	SaveGame.allow_test = true
	_run()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func rd(stage: int, own: float, shore := 0.0, process := 0.0) -> Dictionary:
	var cap: float = Grid.CAPACITY[stage]
	return {"stage": stage, "cap": cap, "own": own, "shore": shore, "groups": {"base": 2.0, "salvage": 0.0, "process": process, "cargo": 0.0, "tug": 0.0}}


func run(secs: float, r: Dictionary) -> Array:
	var ev: Array = []
	var t := 0.0
	while t < secs:
		PW.tick(1.0 / 30.0, r)
		t += 1.0 / 30.0
		ev.append_array(PW.events)
		PW.events.clear()
	return ev


func _run() -> void:
	Txt.zh = true
	PW.reset()
	PW._fault_in = 1e9
	run(40.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.units == 2 and absf(PW.hz - 50.0) < 0.05, "stage 1: two units, 50 Hz held (%.3f)" % PW.hz)
	check(absf(PW.valve - 20.0 / 30.0) < 0.02, "the governor valve stands at the load (%.2f)" % PW.valve)
	var q: float = PW.q_th[0] + PW.q_th[1]
	check(absf(q - 20.0 / PW.ETA) < 1.0 and PW.q_th[2] == 0.0, "the reactors make the heat for 20 MW at 33 %% (%.0f MWt)" % q)
	check(absf(PW.rods[0] - (0.5 + 0.42 * 2.0 / 3.0)) < 0.01, "the rods stand out as the load asks (%.2f)" % PW.rods[0])
	check(PW.t_hot[0] > PW.t_cold[0] + 15.0, "hot leg above cold leg (%.0f / %.0f °C)" % [PW.t_hot[0], PW.t_cold[0]])
	# a 9 MW load put on: the frequency dips, then the valve brings it back
	var low := 50.0
	var t := 0.0
	var back := -1.0
	while t < 20.0:
		PW.tick(1.0 / 30.0, rd(1, 29.0, 0.0, 27.0))
		t += 1.0 / 30.0
		low = minf(low, PW.hz)
		if back < 0.0 and low < 49.9 and absf(PW.hz - 50.0) < 0.05:
			back = t
	PW.events.clear()
	check(low < 49.8 and low > 47.0, "a load put on dips the frequency (to %.2f Hz)" % low)
	check(back > 0.0 and back < 15.0, "and the governor brings it back to 50 Hz (in %.1f s)" % back)
	# the breakers: the process feeder opens a while after it stops drawing, closes when it draws
	var ev := run(1.0, rd(1, 2.0, 0.0, 0.0))
	check(PW.breaker.process > 0.99, "a feeder stays closed just after its last draw")
	ev = run(PW.HOLD_S + 1.0, rd(1, 2.0, 0.0, 0.0))
	check(PW.breaker.process < 0.01 and ev.any(func(e): return str(e[0]) == "breaker"), "then opens, heard (%d events)" % ev.size())
	ev = run(1.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.breaker.process > 0.99 and ev.any(func(e): return str(e[0]) == "breaker"), "and closes again when it draws")
	check(PW.breaker.base > 0.99, "the base feeder is always closed")
	# the shore line: the umbilical first, then the incomer
	ev = run(4.0, rd(1, 30.0, 6.0, 34.0))
	check(PW.umb > 0.0 and PW.umb < 1.0 and PW.breaker.shore < 0.01, "shore power asked: the umbilical swings out, the incomer still open")
	ev = run(6.0, rd(1, 30.0, 6.0, 34.0))
	check(PW.umb >= 1.0 and PW.breaker.shore > 0.99 and ev.any(func(e): return str(e[0]) == "clamp"), "plugged in, then the shore incomer closes")
	ev = run(10.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.umb >= 1.0, "it stays plugged in a while after")
	ev = run(25.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.umb <= 0.0 and PW.breaker.shore < 0.01, "then stows (%.2f)" % PW.umb)
	# a changeover: shown, put right, the supply untouched
	var duty: Array = PW.fw_duty.duplicate()
	PW.start_fault("feed")
	var own0 := PW.own
	ev = run(6.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.fw_duty != duty and int(PW.fault.spare) in PW.fw_duty and PW.changeovers == 1 and PW.own == own0, "a feed pump changeover: the standby takes over, logged, the supply the same")
	ev = run(10.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.fault.is_empty(), "the changeover's plate goes after a while")
	PW.start_fault("valve")
	low = 50.0
	t = 0.0
	while t < 8.0:
		PW.tick(1.0 / 30.0, rd(1, 20.0, 0.0, 18.0))
		t += 1.0 / 30.0
		low = minf(low, PW.hz)
	PW.events.clear()
	check(low < 49.95 and absf(PW.hz - 50.0) < 0.05, "the governor valve sticks: the frequency dips (%.2f) and comes back" % low)
	# left running, the automatics change something over now and then
	PW.fault = {}
	PW._fault_in = 90.0
	var n0 := PW.changeovers
	run(400.0, rd(1, 20.0, 0.0, 18.0))
	check(PW.changeovers > n0 and PW.log.size() <= 3, "left running, a changeover comes along by itself")
	# stage 0: the fuel cells carry the port, the turbine stands
	PW.reset()
	run(10.0, rd(0, 2.0))
	check(PW.units == 0 and PW.hz == 0.0 and absf(PW.fc - 2.0) < 0.01 and PW.q_th[0] == 0.0, "stage 0: reactors cold, turbine still, the fuel cells give the %.1f MW" % PW.fc)
	# stage 2: three units share the load
	PW.reset()
	run(30.0, rd(2, 40.0, 0.0, 38.0))
	check(PW.units == 3 and PW.q_th[2] > 1.0 and absf(PW.q_th[0] - PW.q_th[2]) < 0.5, "stage 2: the third unit runs, the heat shared (%.0f MWt each)" % PW.q_th[2])
	# read from the grid, with no game: the base alone
	var r := PW.read(null)
	check(absf(float(r.own) - Grid.BASE_MW) < 0.001 and float(r.groups.base) > 0.0, "read: the grid's base load (%.1f MW)" % float(r.own))
	print("POWER WORKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
