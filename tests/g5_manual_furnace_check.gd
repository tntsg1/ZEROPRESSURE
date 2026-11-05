extends SceneTree
# Actual existing Smelter heat/actuator simulation with declared cold material.
# Not physical warehouse delivery, commercial product credit or human pacing QA.
const Furnace = preload("res://scripts/smelter.gd")
var checks := 0
var fails := 0
var worst_mass := 0.0
var worst_energy := 0.0
func _initialize() -> void:
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func step(furnace, seconds: float) -> void:
	for frame in int(round(seconds*120.0)):
		furnace.step(1.0/120.0)
		if furnace.manual:
			worst_mass = maxf(worst_mass,absf(furnace.manual_mass()-furnace.input_t))
			worst_energy = maxf(worst_energy,absf(furnace.manual_enthalpy()+furnace.heat_loss_j+furnace.tapped_j-furnace.energy_j))
func run() -> void:
	seed(52203)
	var old = Furnace.new()
	var heel: float = old.m_l
	step(old,1.0)
	check(not old.manual and heel > 0.0 and old.power > 0.0,"legacy automatic furnace stays active with its original decorative hot heel")
	var f = Furnace.new()
	f.begin_manual()
	check(f.manual_mass() == 0.0 and f.T == 20.0 and f.ingots.is_empty(),"manual takeover cannot credit the decorative heel, bunker or old moulds")
	check(not f.manual_charge(-1.0) and not f.manual_charge(INF) and not f.manual_charge(13.0),"negative, nonfinite and overcapacity cold charges are rejected")
	check(f.manual_charge(3.0),"declared three-tonne cold feed enters the real furnace bunker")
	f.charge(50.0,0.0,0.0,true)
	check(f.bunker == 3.0 and f.input_t == 3.0,"already paid legacy scrap cannot contaminate the commercial-mode material")
	step(f,3.0)
	check(f.T == 20.0 and f.m_l == 0.0 and f.bunker == 3.0 and f.energy_j == 0.0,"unpowered furnace neither heats, feeds nor creates molten metal on a timer")
	check(not f.manual_command("tap").ok and not f.manual_command("sample").ok,"cold furnace rejects pouring and probe insertion")
	check(not f.manual_command("power",NAN).ok and not f.manual_command("power",1.1).ok,"invalid power inputs leave the physical process unchanged")
	f.manual_command("feed",1.0)
	f.manual_command("power",1.0)
	step(f,30.0/Furnace.MELT_K)   # 2026-11-05: melting is time-compressed (smelter.gd MELT_K)
	check(f.bunker > 2.2 and f.m_l == 0.0 and f.T > 20.0 and f.T < Furnace.T_LIQ,"real feeder meters cold material while sensible heating precedes melting")
	var power_before: float = f.energy_j
	f.manual_supply_mw = 0.0
	step(f,10.0)
	check(f.power == 0.0 and f.energy_j == power_before,"loss of supplied station power cannot produce free heat")
	f.manual_supply_mw = Furnace.P_RATED
	for second in 600:
		step(f,1.0)
		if f.T >= 1680.0 and f.m_s <= 0.000001 and f.bunker <= 0.000001: break
	check(f.m_l > 2.99999 and f.m_s <= 0.000001 and f.bunker <= 0.000001 and f.T >= 1680.0,"metered cold charge reaches a completely melted bath using integrated real energy")
	check(not f.manual_command("tap").ok and f.sample_count == 0,"hot bath still requires an actual completed immersion sample before tapping")
	var fresh = Furnace.new()
	var state: Dictionary = f.manual_snapshot()
	var path := "user://zp_test_g5_manual_furnace.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(fresh.restore_manual(decoded) and absf(fresh.T-f.T) < 0.000001 and absf(fresh.manual_mass()-f.manual_mass()) < 0.000001 and absf(fresh.energy_j-f.energy_j) < 1.0,"actual JSON disk roundtrip restores furnace energy, masses and control positions")
	var corrupt := decoded.duplicate(true)
	corrupt.m_l = float(corrupt.m_l)+1.0
	var original := JSON.stringify(fresh.manual_snapshot())
	check(not fresh.restore_manual(corrupt) and JSON.stringify(fresh.manual_snapshot()) == original,"corrupt extra metal is rejected atomically without overwriting the running furnace")
	corrupt = decoded.duplicate(true)
	corrupt.energy_j = float(corrupt.energy_j)*0.5
	check(not fresh.restore_manual(corrupt) and JSON.stringify(fresh.manual_snapshot()) == original,"forged missing energy is rejected instead of granting a hot bath on load")
	f = fresh
	check(f.manual_command("sample").ok,"manual sample command starts the existing immersion mechanism")
	step(f,2.0)
	check(f.dip == 1.0 and f.sample_count == 0 and f.power == 0.0,"probe physically lowers and interlocks inverter before measurement exists")
	step(f,1.5)
	check(f.sample_count == 1 and f.lance_phase == "lift" and not f.manual_command("tap").ok,"completed immersed dwell yields a sample while the extended probe still blocks tilt")
	step(f,1.5)
	var stale = Furnace.new(false)
	check(stale.restore_manual(f.manual_snapshot()),"a fully sampled machine restores its actual probe and sample age")
	step(stale,61.0)
	check(stale.manual_command("tap").get("reason","") == "fresh_sample_required","outdated sample cannot silently authorize a later pour")
	check(f.dip == 0.0 and f.lance_phase == "idle" and f.manual_command("tap").ok,"fresh sampled melt can tilt only after the probe retracts")
	var tilt_before: float = f.tilt
	step(f,1.0)
	check(f.tilt == tilt_before and f.hood > 0.0 and f.m_l > 2.99999,"hood slides clear first without premature tilt or instantaneous product creation")
	step(f,10.0)
	check(f.phase == "pour" and f.tilt > 0.0 and f.m_l < 3.0 and f.m_l > 0.0,"existing trunnion and slide gate pour the actual liquid gradually")
	check(not f.manual_command("feed",1.0).ok and not f.manual_command("sample").ok,"moving hot body rejects feeding and probe insertion")
	# 121 号 (user "为什么只到一个钢坯"): once the pour is over every billet of the heat stays in sight
	# on the line (the oldest at its end), none pushed past it out of the picture
	var seen_most := 0
	var out_of_sight := 0
	for second in 180:
		step(f,1.0)
		if f.phase in ["back","hold"] and f.m_l <= 0.000001:
			var vis := 0
			for ig in f.ingots:
				var ix: float = Furnace.FILL_X+f.line_off-float(ig[0])
				if ix >= Furnace.LINE_X0 and ix <= Furnace.LINE_X1+0.001: vis += 1
				else: out_of_sight += 1
			seen_most = maxi(seen_most,vis)
	check(seen_most == 3 and out_of_sight == 0,"after the pour all three billets are on the line in sight (most %d, out of sight %d)" % [seen_most,out_of_sight])
	check(f.phase == "hold" and f.tilt == 0.0 and f.hood == 0.0 and is_equal_approx(f.shipped_t,3.0) and f.ingots.is_empty(),"all original metal cools and passes through the actual casting line including the final partial mould")
	check(worst_mass < 0.000001,"material conserved across bunker, bath, moulds and discharged billets")
	check(worst_energy < 1.0,"sensible heat, latent fusion, lining, losses and tapped enthalpy conserve energy to under one joule")
	var partial = Furnace.new(false)
	partial.begin_manual()
	partial.manual_charge(0.25)
	partial.manual_command("feed",1.0)
	partial.manual_command("power",1.0)
	for second in 240:
		step(partial,1.0)
		if partial.T >= 1690.0 and partial.m_l >= 0.249999: break
	partial.manual_command("sample")
	step(partial,5.0)
	check(partial.manual_command("tap").ok,"sub-ingot batch uses the same real sample and thermal interlocks")
	step(partial,1.0)
	check(partial.manual_command("stop").ok and partial.manual_power == 0.0 and not partial.manual_feed,"operator stop removes power/feed and commands mechanical return")
	step(partial,5.0)
	check(partial.phase == "hold" and partial.tilt == 0.0 and partial.m_l > 0.249999 and partial.shipped_t == 0.0,"interrupted tilt returns safely without losing metal or crediting an unpoured product")
	partial.manual_command("power",1.0)
	for second in 120:
		step(partial,1.0)
		if partial.T >= 1690.0: break
	partial.manual_command("sample")
	step(partial,5.0)
	check(partial.manual_command("tap").ok,"interrupted batch can be rechecked and legitimately resumed")
	step(partial,180.0)
	check(is_equal_approx(partial.shipped_t,0.25) and partial.ingots.is_empty() and absf(partial.manual_mass()-0.25) < 0.000001,"final quarter-tonne mould really exits the casting line without rounding up to one tonne")
	var standard = Furnace.new(false)
	standard.begin_manual()
	standard.manual_charge(1.0)
	standard.manual_command("feed",1.0)
	standard.manual_command("power",1.0)
	for second in 600:
		step(standard,1.0)
		if standard.T >= 1680.0 and standard.m_l > 0.999999: break
	standard.manual_command("sample")
	step(standard,5.0)
	check(standard.manual_command("tap").ok,"reference one-tonne heat requires the same completed sample and real operator tap command")
	for second in 600:
		step(standard,1.0)
		if standard.shipped_t > 0.999999: break
	check(standard.shipped_t > 0.999999 and standard.electrical_j > standard.energy_j and absf(standard.energy_j-standard.electrical_j*Furnace.ETA) < 1.0,"inverter input and absorbed heat are metered separately so future production costs cannot ignore coil losses")
	print("BENCHMARK one_tonne_seconds=%.3f electrical_MWh=%.6f absorbed_MWh=%.6f (model only, not human playtesting)" % [standard.t,standard.electrical_j/3.6e9,standard.energy_j/3.6e9])
	var certificate: Dictionary = standard.quality_certificate()
	check(certificate.ready and certificate.grade == 1 and not certificate.laboratory_assay and certificate.trace.sample_valid and certificate.trace.poured_t > 0.999999,"ordinary certified-feed recipe earns its process grade from actual saved probe and tap measurements, not invented laboratory results")
	var legacy_state: Dictionary = standard.manual_snapshot()
	legacy_state.erase("process_record")
	var legacy = Furnace.new(false)
	check(legacy.restore_manual(legacy_state) and legacy.quality_certificate().grade == 0 and legacy.input_t == standard.input_t,"legacy snapshots keep their physical material but missing quality history is explicitly unverified rather than promoted")
	var empty = Furnace.new(false)
	empty.begin_manual()
	var empty_state: Dictionary = empty.manual_snapshot()
	empty_state.erase("process_record")
	check(empty.restore_manual(empty_state) and not empty.process_record.legacy_unverified,"legacy empty chamber is not falsely penalized for metal processing that never happened")
	empty.manual_charge(0.25)
	empty.manual_command("feed",1.0)
	empty.manual_command("power",1.0)
	for second in 240:
		step(empty,1.0)
		if empty.T >= 1680.0 and empty.m_l > 0.249999: break
	empty.manual_command("sample")
	step(empty,5.0)
	empty.manual_command("tap")
	step(empty,180.0)
	check(empty.quality_certificate().ready and empty.quality_certificate().grade == 1,"new measured production after an old empty snapshot can legitimately earn the qualified process grade")
	var retained_T: float = standard.T
	check(standard.next_manual_batch() and standard.T == retained_T and standard.initial_heat_j > 0.0 and standard.electrical_j == 0.0,"next batch preserves previously paid refractory heat without inventing another hot heel or erasing its energy")
	var next = Furnace.new(false)
	check(next.restore_manual(standard.manual_snapshot()) and absf(next.manual_enthalpy()-next.initial_heat_j) < 1.0,"retained-heat batch snapshot accounts for its initial energy and restores without free metal")
	var bad = Furnace.new(false)
	bad.begin_manual()
	bad.manual_charge(0.25)
	bad.manual_command("feed",1.0)
	bad.manual_command("power",1.0)
	for second in 300:
		step(bad,1.0)
		if bad.T >= 1715.0: break
	bad.manual_command("power",0.0)
	for second in 300:
		step(bad,1.0)
		if bad.T <= 1685.0: break
	bad.manual_command("sample")
	step(bad,5.0)
	check(bad.manual_command("tap").ok,"overheated material can still be rechecked and physically poured instead of disappearing")
	step(bad,180.0)
	var rejected: Dictionary = bad.quality_certificate()
	check(rejected.ready and rejected.grade == 0 and rejected.trace.peak_c > 1710.0 and is_equal_approx(bad.shipped_t,0.25),"actual overheating downgrades the same preserved quarter-tonne output to off-spec material")
	var review = Furnace.new(false)
	check(review.restore_manual(bad.manual_snapshot()) and review.quality_certificate() == rejected,"measured quality trace and downgrade survive complete furnace snapshot restoration")
	print("MEASURE furnace_seconds=%.3f energy_MWh=%.6f worst_mass=%.12f worst_energy_J=%.6f" % [f.t,f.energy_j/3.6e9,worst_mass,worst_energy])
	print("G5 MANUAL FURNACE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
