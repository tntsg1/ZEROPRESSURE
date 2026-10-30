extends SceneTree
const Line = preload("res://scripts/scrapline.gd")
const Smelt = preload("res://scripts/smelter.gd")
class Receiver extends RefCounted:
	var mass := 0.0
	func charge(amount: float, _x: float, _dirty: float = 0, arrived: bool = false) -> void:
		assert(arrived)
		mass += amount
var fails := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: fails += 1
func mass_in(line) -> float:
	var total: float = line.waiting_mass()
	if line.press != null and not line.press.sent: total += line.press.mass
	if line.shred != null: total += line.shred.mass * (1.0 - line.shred.made / 26.0)
	for f in line.frags: total += f[7]
	for f in line.fines: total += f[5]
	for puck in line.pucks: total += puck[1]
	return total
func _run() -> void:
	seed(72021)
	var line = Line.new()
	var sink := Receiver.new()
	line.smelter = sink
	var plate := PackedVector2Array([Vector2(-3,-0.9),Vector2(3,-0.9),Vector2(3,0.9),Vector2(-3,0.9)])
	var part := PackedVector2Array([Vector2(-0.7,-0.5),Vector2(0.7,-0.5),Vector2(0.7,0.5),Vector2(-0.7,0.5)])
	line.take([plate],1.0,["hull"],line.X)
	line.take([part],0.6,["equip"],line.X)
	var poses := Vector3(line.lid_y,line.side_x,line.out_gate)
	var max_pose_speed := 0.0
	var max_bit_speed := 0.0
	var worst_mass := 0.0
	var last := {}
	var stages := {}
	var probe_stages := {}
	var rotor0: float = line.rotor_angle
	for frame in 7200:
		line.step(1.0 / 120)
		var now := Vector3(line.lid_y,line.side_x,line.out_gate)
		max_pose_speed = maxf(max_pose_speed,now.distance_to(poses) * 120)
		poses = now
		worst_mass = maxf(worst_mass,absf(mass_in(line) + sink.mass + line.nonferrous / 1000.0 - 1.6))
		for f in line.frags:
			var id := "c%d" % f[11]
			if last.has(id): max_bit_speed = maxf(max_bit_speed,last[id].distance_to(f[0]) * 120)
			last[id] = f[0]
		for f in line.fines:
			var id := "f%d" % f[9]
			if last.has(id): max_bit_speed = maxf(max_bit_speed,last[id].distance_to(f[0]) * 120)
			last[id] = f[0]
			stages[f[3]] = true
	check(worst_mass < 0.00001,"mass conserved through input, press, fragments, separation and furnace delivery")
	check(absf(sink.mass - 1.564) < 0.00001 and absf(line.nonferrous - 36) < 0.001,"ferrous and nonferrous streams arrive with the correct measured mass")
	check(line.frags.is_empty() and line.fines.is_empty() and line.pucks.is_empty(),"all material physically completes its transport path")
	check(stages.size() == 4,"powder passes the screen, separator, iron outlet and nonferrous outlet")
	check(max_bit_speed < 10,"particle stage changes have no orbit or chute teleport (%.2f m/s max)" % max_bit_speed)
	check(max_pose_speed < 15,"press strokes and returns are continuous (%.2f m/s max)" % max_pose_speed)
	check(is_equal_approx(line.lid_y,Line.PRESS_Y0) and is_equal_approx(line.side_x,Line.PRESS_X0) and is_zero_approx(line.out_gate),"press fully returns and closes after ejection")
	check(line.rotor_angle > rotor0 and line.rotor_speed < 3,"rotor orientation integrates through load changes")
	var coarse = Line.new()
	var coarse_sink := Receiver.new()
	coarse.smelter = coarse_sink
	for i in 3: coarse.take([part],0.2,["equip"],coarse.X + 3)
	for i in 2: coarse.take([plate],1.0,["hull"],coarse.X)
	for i in 1800: coarse.step(0.1)
	check(absf(coarse_sink.mass + coarse.nonferrous / 1000.0 - 2.6) < 0.00001 and coarse.busy() == 0 and coarse.frags.is_empty() and coarse.fines.is_empty(),"slow-frame/backlog processing preserves material and completes every job")
	var sm = Smelt.new()
	sm.m_l = 8
	sm.T = 1600
	sm.bunker = 0
	sm.lance_t = 39.9
	var last_dip: float = sm.dip
	var max_probe := 0.0
	var immersed := false
	for frame in 1000:
		sm.step(1.0 / 120)
		probe_stages[sm.lance_phase] = true
		max_probe = maxf(max_probe,absf(sm.dip - last_dip) * 120)
		last_dip = sm.dip
		if sm.lance_phase == "dwell":
			var tip: Vector2 = sm.lance_tip()
			immersed = absf(tip.x) > Smelt.R_IN - sm.layer(sm.m_l) and absf(tip.x) < Smelt.R_IN
	check(probe_stages.size() == 4 and sm.sample_count == 1,"probe lowers, dwells, samples once and retracts")
	check(immersed,"sampling tip enters the actual rotating steel annulus")
	check(max_probe < 2.3 and sm.dip == 0,"probe starts and stops smoothly and returns to its guide")
	check(sm.lance_tip().y < 3.36,"retracted probe tip fully clears the moving furnace hood")
	sm.lance_t = 40
	for frame in 130: sm.step(1.0 / 120)
	var samples_before: int = sm.sample_count
	sm.phase = "tilt"
	var hood_open_early := false
	for frame in 250:
		sm.step(1.0 / 120)
		if sm.dip > 0.001 and sm.hood > 0.001: hood_open_early = true
	check(not hood_open_early and sm.dip == 0,"hood opening waits for the interrupted probe to retract")
	check(sm.sample_count == samples_before,"an interrupted immersion never produces a false sample")
	print("PLANT MOTION %s (%d failures)" % ["PASS" if fails == 0 else "FAIL",fails])
	quit(0 if fails == 0 else 1)
