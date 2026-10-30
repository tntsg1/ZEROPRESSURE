extends SceneTree
# Mechanical/parcel model checks with declared material fractions, not native
# cargo delivery, chemical certification, or a human production playthrough.
const Line = preload("res://scripts/scrapline.gd")
class LegacySink extends RefCounted:
	var mass := 0.0
	func charge(amount: float,_x: float,_dirty: float = 0.0,arrived: bool = false) -> void:
		assert(arrived)
		mass += amount
var checks := 0
var fails := 0
func _initialize() -> void:
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func run() -> void:
	var line = Line.new()
	var sink := LegacySink.new()
	line.smelter = sink
	var outline := PackedVector2Array([Vector2(-0.45,-0.4),Vector2(0.45,-0.4),Vector2(0.45,0.4),Vector2(-0.45,0.4)])
	check(not line.begin_company("BAD",[outline],1.0,-0.1,901) and not line.company_mode,"unknown/invalid negative source fraction cannot be accepted as the decorative default recipe")
	check(line.begin_company("SORT-REAL-MODEL",[outline],1.0,0.24,901),"company mode accepts one explicit measured-source fraction and the actual input outline")
	var start: Dictionary = line.company_snapshot()
	for i in 300: line.step(1.0/60.0)
	check(line.company_energy_j == 0.0 and line.company_snapshot() == start,"unpowered cold machinery holds its actual input and consumes no drive energy")
	line.company_powered = true
	var worst := 0.0
	var stages := {}
	var restore_count := 0
	var finished := false
	for i in 5000:
		line.step(1.0/120.0)
		worst = maxf(worst,absf(line.in_process_mass()+line.company_fe+line.company_nf-1.0))
		for fragment in line.frags: stages["mill_"+str(fragment[5])] = true
		for fine in line.fines: stages["fine_"+str(fine[3])] = true
		if i in [120,360,600,840,1080,1320]:
			var raw := JSON.stringify(line.company_snapshot())
			var restored = Line.new()
			if restored.restore_company(JSON.parse_string(raw)):
				line = restored
				line.smelter = sink
				restore_count += 1
		if line.company_complete(): finished = true; break
	check(finished and stages.has_all(["mill_0","mill_1","fine_0","fine_1","fine_2","fine_3"]),"actual shredder fragments visit the mill, magnetic drum and both output chutes before completion")
	check(restore_count >= 3,"JSON snapshots reconstruct a running batch at several actual mechanism/parcel stages")
	check(worst < 0.000001 and absf(line.company_fe-0.76)<0.000001 and absf(line.company_nf-0.24)<0.000001,"declared 76/24 source follows its own exact output masses, not the old decorative 94/6 split")
	check(sink.mass == 0.0,"company separation cannot silently charge the legacy furnace or receive its old salvage payout")
	check(line.company_energy_j > 0.0 and line.company_energy_j < 240000.0*40.0,"drive input energy integrates actual running time and stays within the finite process duration")
	var state: Dictionary = line.company_snapshot()
	var legacy := state.duplicate(true)
	legacy.version = 1
	legacy.erase("company_running_s")
	var legacy_line = Line.new()
	check(legacy_line.restore_company(legacy) and absf(legacy_line.company_energy_j-line.company_energy_j)<0.000001,"old v1 line snapshot derives missing drive time from its saved meter without changing paid energy or material")
	var missing := state.duplicate(true)
	missing.erase("company_running_s")
	check(not legacy_line.restore_company(missing),"new v2 snapshots cannot silently omit their required drive timer")
	var bad := state.duplicate(true)
	bad.company_fe = 2.0
	var before := JSON.stringify(line.company_snapshot())
	check(not line.restore_company(bad) and JSON.stringify(line.company_snapshot()) == before,"overcredited output snapshot is rejected without modifying the live valid line")
	bad = state.duplicate(true)
	bad.fines = [[1,2]]
	check(not line.restore_company(bad) and JSON.stringify(line.company_snapshot()) == before,"malformed particle snapshot is rejected atomically")
	bad = state.duplicate(true)
	bad.company_energy_j = float(bad.company_energy_j)+1000.0
	check(not line.restore_company(bad) and JSON.stringify(line.company_snapshot()) == before,"drive time and energy mismatch cannot become a fabricated power bill on restore")
	check(line.claim_company(true,0.76) and not line.claim_company(true,0.76) and line.company_fe == 0.0,"actual ferrous buffer can transfer its mass to custody only once")
	check(line.claim_company(false,0.24) and absf(line.company_released_fe+line.company_released_nf-1.0)<0.000001,"second output is separately transferred with total batch mass preserved")
	var restored = Line.new()
	check(restored.restore_company(JSON.parse_string(JSON.stringify(line.company_snapshot()))) and restored.company_fe+restored.company_nf == 0.0,"fully transferred output survives JSON restoration without regenerating warehouse inventory")
	# Mid-process private RNG reconstruction must preserve future parcel paths.
	var a = Line.new()
	a.begin_company("RNG",[outline],0.5,0.35,78)
	a.company_powered = true
	for i in 460: a.step(1.0/120.0)
	var b = Line.new()
	check(b.restore_company(JSON.parse_string(JSON.stringify(a.company_snapshot()))),"mid-shred material and private RNG state restore as one mechanism snapshot")
	for i in 400:
		a.step(1.0/120.0)
		b.step(1.0/120.0)
	check(JSON.stringify(a.company_snapshot()) == JSON.stringify(b.company_snapshot()),"restored private RNG reproduces the same later fragment paths without rerolling source or output")
	print("MEASURE company_sort_mass_error_t=",worst," electrical_kWh=",line.company_energy_j/3.6e6)
	print("G5 SORT MODEL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
