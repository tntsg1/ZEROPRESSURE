extends SceneTree
# 87-1: hull materials. Every formal ship's structure has a material (data/materials.json); the
# real laser, held across bars of the same size at the same power, takes markedly longer through
# military armour and ceramic than plain plate (3-5x), titanium in between, aluminium a little
# slower, composite faster; more laser power closes the gap most for armour; the berth machine
# slows the same way. Heat: a titanium kerf glows longest and melts value away, ceramic cut
# without pause cracks (cut in short runs it does not), steel loses nothing. Price: a ship's scrap
# is shared out by material and adds up to what the ship file says. A save keeps it all; a save
# from before materials loads plain and pays as before. Own test saves only.
#   tools/run_test.sh tests/material_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const Batches = preload("res://scripts/material_batches.gd")
var g: Node
var fails := 0
var checks := 0
var report: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_material_career.json"
	SaveGame.path = "user://zp_test_material_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(ship: String, kit: Dictionary = {}) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	await _frames(8)
	scene.tutorial = null
	return scene


func _run() -> void:
	Txt.zh = true
	_data_checks()
	await _cut_checks()
	await _ship_checks()
	await _save_checks()
	print("--- 87-1 material report")
	for r in report:
		print(r)
	print("MATERIAL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- data

func _data_checks() -> void:
	var ships: Dictionary = Mat.data().ships
	var missing: Array = []
	for row in Market.POOL:
		if not ships.has(str(row[0])):
			missing.append(row[0])
	check(Market.POOL.size() == 42 and missing.is_empty(), "all 42 formal ships have a material map (missing %s)" % str(missing))
	var bad: Array = []
	for sid in ships:
		if not Mat.data().materials.has(str(ships[sid].get("default", ""))):
			bad.append(sid)
		for r in ships[sid].get("rules", []):
			if not Mat.data().materials.has(str(r.mat)):
				bad.append("%s:%s" % [sid, r.mat])
	check(bad.is_empty(), "every map names real materials (%s)" % str(bad))
	# every structural part of every formal ship comes out with a material, and every rule hits something
	var unset := 0
	var dead: Array = []
	var by_mat := {}
	for row in Market.POOL:
		var sid := str(row[0])
		var d: Dictionary = Ship.load_data(sid)
		var hit := {}
		for pd in d.get("pieces", []):
			var mr: Array = Mat.resolve(sid, pd)
			if str(pd.get("cls", "metal")) == "metal" and str(mr[0]) == "":
				unset += 1
			if str(mr[0]) != "":
				by_mat[mr[0]] = by_mat.get(mr[0], 0) + 1
			hit[mr[0]] = true
		for r in ships[sid].get("rules", []):
			if not hit.has(str(r.mat)):
				dead.append("%s:%s" % [sid, r.mat])
	check(unset == 0, "no structural part of the 42 ships is left without a material (%d)" % unset)
	check(dead.is_empty(), "every rule matches at least one part (%s)" % str(dead))
	report.append("parts by material over the 42 ships: %s" % str(by_mat))
	check(by_mat.get("armor", 0) > 40 and by_mat.get("ti", 0) > 0 and by_mat.get("ceramic", 0) > 0 and by_mat.get("al", 0) > 0 and by_mat.get("composite", 0) > 0 and by_mat.get("shield", 0) > 0, "armour, titanium, ceramic, aluminium, composite and heat shield all occur on real ships")
	# same geometry, same power: the material's own factor
	var st := Mat.k(Mat.def("steel"), 1.0)
	var ar := Mat.k(Mat.def("armor"), 1.0)
	check(is_equal_approx(st, 1.0) and is_equal_approx(Mat.k(Mat.def("steel"), 2.0), 2.0), "plain steel is exactly as before (speed x power)")
	var gap1 := st / ar
	var gap2 := Mat.k(Mat.def("steel"), 2.0) / Mat.k(Mat.def("armor"), 2.0)
	check(gap2 < gap1 - 0.5, "a stronger laser closes the gap to armour (%.2fx at power 1 -> %.2fx at power 2)" % [gap1, gap2])
	check(Mat.k(Mat.def("armor"), 0.15) > 0.0, "below its power threshold armour still cuts (no soft lock)")


# ---------------------------------------------------------------- the real beam

const BAR := Vector2(28, 96)      # px: a bar 0.6 m wide, 2 m tall, cut across its height

func _bar(at: Vector2, mat: String) -> Object:
	var h := BAR * 0.5
	var poly := PackedVector2Array([at + Vector2(-h.x, -h.y), at + Vector2(h.x, -h.y), at + Vector2(h.x, h.y), at + Vector2(-h.x, h.y)])
	# the same steel-equivalent section for all: 140 px/s through plain plate
	var p = g.world.add_piece("plate", poly, {"mat": mat, "cut_speed": 140.0 * Mat.k(Mat.def(mat), 1.0), "mass": 1.0})
	# welded to the berth on either side of the cut line, so both halves stay put
	g.world.add_joint(p, null, "weld", at + Vector2(-9, 0))
	g.world.add_joint(p, null, "weld", at + Vector2(9, 0))
	return p


# hold the beam across one bar until it falls in two; seconds of beam time
func _cut_time(mat: String, at: Vector2, pause := 0.0, run := 0.0, shot := "") -> Dictionary:
	var bar = _bar(at, mat)
	if shot != "":
		g.cam_override = at
		await _frames(20)
	g.drone.alive = true
	g.drone.global_position = at + Vector2(-110, 0)
	g.drone.linear_velocity = Vector2.ZERO
	var t := 0.0
	var beam := 0.0
	var top := at + Vector2(0, -BAR.y * 0.5 - 30)
	var bottom := at + Vector2(0, BAR.y * 0.5 + 30)
	g.bot.aim = top
	g.bot.lmb = true
	await _frames(1)
	g.bot.aim = bottom
	var dt := 1.0 / 60.0
	var on := true
	var since := 0.0
	var max_kdt := 0.0
	var resume_at := top
	while t < (8.0 if run <= 0.0 else 45.0) and _halves(mat, at).size() < 2:
		g.drone.global_position = at + Vector2(-110, 0)
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
		t += dt
		since += dt
		if on:
			beam += dt
		max_kdt = maxf(max_kdt, bar.kerf_dt)
		if shot != "" and beam >= 0.3:
			g.cam_override = at
			Cap.save(root, "res://tests/out/%s.png" % shot)
			g.cam_override = null
			shot = ""
		if run > 0.0:
			if on and since >= run:
				on = false
				since = 0.0
				resume_at = g.tools.front
				g.bot.lmb = false
			elif not on and since >= pause:
				on = true
				since = 0.0
				g.bot.lmb = true
				g.bot.aim = resume_at
				await _frames(1)
				g.bot.aim = bottom
	var parts: Array = _halves(mat, at)
	var split := parts.size() >= 2
	if OS.has_environment("MAT_DEBUG"):
		for id in g.world.order:
			var p = g.world.pieces[id]
			if Geom.centroid(g.world.world_poly(p)).distance_to(at) < 200.0:
				print("  dbg ", p.id, " ", p.mat, " gone=", p.gone, " area=", Geom.area(p.poly), " c=", Geom.centroid(g.world.world_poly(p)), " body=", p.body)
	g.bot.lmb = false
	await _frames(4)
	var loss := 0.0
	var cracks := 0
	for p in parts:
		loss = maxf(loss, p.loss)
		cracks = maxi(cracks, p.cracks)
	return {"t": beam, "split": split, "loss": loss, "cracks": cracks, "kdt": max_kdt, "parts": parts}


# the bar's two big parts (a kerf's entry nicks off crumbs; those do not count)
func _halves(mat: String, at: Vector2) -> Array:
	var out: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.mat != mat or Geom.area(p.poly) < BAR.x * BAR.y * 0.2:
			continue
		if Geom.centroid(g.world.world_poly(p)).distance_to(at) < 120.0:
			out.append(p)
	return out


func _cut_checks() -> void:
	g = await _game("tug")
	g.tools.tool = 2
	g.cam_override = Vector2(4000, 4000)
	await _frames(30)
	Cap.save(root, "res://tests/out/_material_warm.png")
	var res := {}
	var x := 4000.0
	for mat in ["steel", "al", "armor", "ti", "ceramic", "shield", "composite"]:
		res[mat] = await _cut_time(mat, Vector2(x, 4000), 0.0, 0.0, "material_cutting_%s" % mat)
		x += 260.0
		report.append("power 1  %-9s beam %.2f s  split %s  max +%.0f °C  loss %.0f%%  cracks %d" % [mat, res[mat].t, res[mat].split, res[mat].kdt, res[mat].loss * 100.0, res[mat].cracks])
	for mat in res:
		check(res[mat].split, "%s: the real beam cuts through the bar" % mat)
	var steel_t: float = res.steel.t
	var ra: float = res.armor.t / steel_t
	var rc: float = res.ceramic.t / steel_t
	var rt: float = res.ti.t / steel_t
	check(ra >= 3.0 and ra <= 5.0, "military armour takes 3-5x as long as plain plate at the same power (%.2fx)" % ra)
	check(rc >= 3.0 and rc <= 5.0, "ceramic composite armour takes 3-5x as long (%.2fx)" % rc)
	check(rt >= 1.5 and rt <= 2.5, "titanium takes about twice as long (%.2fx)" % rt)
	check(res.al.t > steel_t * 1.05 and res.al.t < steel_t * 1.5, "aluminium a little slower than steel (%.2fx)" % (res.al.t / steel_t))
	check(res.composite.t < steel_t, "composite faster than steel (%.2fx)" % (res.composite.t / steel_t))
	check(res.steel.loss == 0.0 and res.steel.cracks == 0, "plain steel loses nothing to the cut")
	check(res.ti.loss > 0.0 and res.ti.kdt > res.steel.kdt * 1.5, "titanium: hotter kerf (+%.0f vs +%.0f °C) and value melted off (%.1f%%)" % [res.ti.kdt, res.steel.kdt, res.ti.loss * 100.0])
	check(res.ceramic.cracks > 0 and res.ceramic.loss > 0.1, "ceramic cut straight through cracks (%d) and loses value" % res.ceramic.cracks)
	check(Mat.glow_t(res.ti.parts[0]) > Mat.glow_t(res.steel.parts[0]) * 2.0 and Mat.glow_t(res.al.parts[0]) < Mat.glow_t(res.steel.parts[0]), "the kerf glows longest in titanium, shortest in aluminium")
	Cap.save(root, "res://tests/out/material_bars_zh.png")
	# ceramic cut in short runs, letting it cool between them, does not crack
	var slow: Dictionary = await _cut_time("ceramic", Vector2(x, 4000), 6.0, 0.35)
	report.append("ceramic in 0.35 s runs, 6 s pauses: beam %.2f s, cracks %d, max +%.0f °C" % [slow.t, slow.cracks, slow.kdt])
	check(slow.split and slow.cracks < res.ceramic.cracks, "ceramic cut in short runs with pauses cracks less (%d < %d)" % [slow.cracks, res.ceramic.cracks])
	# heat cools off
	var tp = res.ti.parts[0]
	var hot: float = tp.kerf_dt
	await _frames(120)
	check(tp.kerf_dt < hot, "a warmed part cools (+%.0f -> +%.0f °C)" % [hot, tp.kerf_dt])
	# the inspection line names the material
	check(g._inspect_text(tp).contains("钛合金"), "the measuring tool names the material (%s)" % g._inspect_text(tp))
	# the berth's machine is slowed by the same material
	var cap := Geom.M / 1.2
	var ms = _bar(Vector2(x + 400, 4400), "steel")
	var ma = _bar(Vector2(x + 500, 4400), "armor")
	var mt = _bar(Vector2(x + 600, 4400), "ti")
	report.append("machine feed px/s: steel %.1f  armour %.1f  titanium %.1f" % [Mat.machine_feed(ms, cap), Mat.machine_feed(ma, cap), Mat.machine_feed(mt, cap)])
	check(is_equal_approx(Mat.machine_feed(ms, cap), cap), "the machine on steel: as before")
	check(Mat.machine_feed(ma, cap) < cap / 2.5 and Mat.machine_feed(mt, cap) < cap * 0.7, "the machine slows on armour and titanium")
	g.queue_free()
	await _frames(4)
	# more cutting power: the armour gap narrows on the real beam too
	g = await _game("tug", {"skill_laser_power": 3})
	g.tools.tool = 2
	var pw: float = g.skill_value("laser_power")
	var s2: Dictionary = await _cut_time("steel", Vector2(4000, 4000))
	var a2: Dictionary = await _cut_time("armor", Vector2(4260, 4000))
	report.append("power %.2f  steel %.2f s  armour %.2f s  (%.2fx)" % [pw, s2.t, a2.t, a2.t / s2.t])
	check(pw > 1.5 and a2.t / s2.t < ra - 0.5, "at power %.2f armour is %.2fx steel (was %.2fx at power 1)" % [pw, a2.t / s2.t, ra])
	g.queue_free()
	await _frames(4)


# ---------------------------------------------------------------- real ships

func _ship_checks() -> void:
	# on the real ships at power 1: a civil hull plate against the patrol ship's armour, a gas-sea
	# titanium tank, the patrol ship's ceramic shield
	var gr := _speed_of("gr7", "hull", "")
	var ar := _speed_of("pt34", "", "p_armor")
	var ce := _speed_of("pt34", "", "p_shield")
	var ti := _speed_of("hg170", "", "", "^T[A-D]")
	var civ := _speed_of("ro128", "hull", "")
	report.append("real ships, beam px/s at power 1: GR-7 hull %.0f, RO-128 hull %.0f, PT-34 armour %.0f, PT-34 ceramic %.0f, HG-170 titanium tank %.0f" % [gr, civ, ar, ce, ti])
	check(civ / ar >= 3.0 and civ / ar <= 5.0, "RO-128 civil hull vs PT-34 armour: %.1fx" % (civ / ar))
	check(civ / ce >= 3.0, "RO-128 hull vs PT-34 ceramic shield: %.1fx" % (civ / ce))
	# each formal ship's structure still adds up to its scrap value; titanium fetches more a tonne
	var off: Array = []
	for row in Market.POOL:
		var sid := str(row[0])
		var w = World.new()
		var d: Dictionary = Ship.load_data(sid)
		Ship.build(w, d)
		w.finalize(float(d.get("value", {}).get("metal", 0.0)))
		var sum := 0.0
		for id in w.order:
			if w.pieces[id].cls == "metal":
				sum += w.scrap_value(w.pieces[id])
		var want := float(d.get("value", {}).get("metal", 0.0))
		if absf(sum - want) > maxf(1.0, want * 0.001):
			off.append("%s %.0f/%.0f" % [sid, sum, want])
		if sid == "hg170":
			var per := {}
			for id in w.order:
				var p = w.pieces[id]
				if p.cls == "metal" and p.mass > 0.0:
					per[Mat.id_of(p)] = w.scrap_value(p) / p.mass
			report.append("HG-170 scrap $/t: %s" % str(per))
			check(per.has("ti") and per.has("steel") and per.ti > per.steel * 3.0, "a titanium tank fetches over 3x plain plate a tonne")
		if sid == "pt34":
			var tot := {}
			for id in w.order:
				var p = w.pieces[id]
				if p.cls == "metal":
					tot[Mat.id_of(p)] = tot.get(Mat.id_of(p), 0.0) + w.scrap_value(p)
			report.append("PT-34 scrap by material: %s" % str(tot))
		w.free()
	check(off.is_empty(), "every formal ship's structure adds up to its scrap value, no more (%s)" % str(off))
	# the sorting line: what is not magnetic
	g = await _game("hg170")
	var tank = null
	var plate = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.mat == "ti" and tank == null:
			tank = p
		if p.mat == "steel" and p.kind == "hull" and plate == null:
			plate = p
	check(tank != null and Batches.profile_of(tank).nonmagnetic_share >= 0.99 and Batches.profile_of(tank).get("sort", "") == "titanium", "the sorting line finds a titanium tank non-magnetic, for the titanium bin")
	check(plate != null and Batches.profile_of(plate).basis.begins_with("ship_structure_"), "plain plate is sorted as before")
	g.queue_free()
	await _frames(4)


func _speed_of(sid: String, kind: String, nk: String, re: String = "") -> float:
	var d: Dictionary = Ship.load_data(sid)
	var rx: RegEx = RegEx.create_from_string(re) if re != "" else null
	var best := 0.0
	var n := 0
	for pd in d.pieces:
		if kind != "" and str(pd.kind) != kind:
			continue
		if nk != "" and str(pd.get("name_key", "")) != nk:
			continue
		if rx != null and rx.search(str(pd.get("key", ""))) == null:
			continue
		var mr: Array = Mat.resolve(sid, pd)
		best += float(mr[1])
		n += 1
	return best / maxf(1.0, n)


# ---------------------------------------------------------------- saves

func _save_checks() -> void:
	SaveGame.clear()
	g = await _game("pt34")
	g.tools.tool = 2
	var armor = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.mat == "armor" and armor == null and not g.world.hidden(g.world.frame(p) * Geom.centroid(p.poly)):
			armor = p
	check(armor != null, "PT-34 comes in with its armour plates marked")
	var key: String = armor.key
	armor.kerf_dt = 150.0
	armor.loss = 0.05
	var price: float = g.world.metal_price
	var v0: float = g.world.scrap_value(armor)
	g.world.redraw_all(true)
	g.cam_override = g.world.frame(armor) * Geom.centroid(armor.poly)
	await _frames(10)
	Cap.save(root, "res://tests/out/material_pt34_armour_zh.png")
	g.cam_override = null
	SaveGame.save(g)
	g.queue_free()
	await _frames(3)
	SaveGame.load_requested = true
	g = await _game("pt34")
	await _frames(3)
	var back = g.world.by_key(key) if g.world.has_method("by_key") else null
	if back == null:
		for id in g.world.order:
			if g.world.pieces[id].key == key:
				back = g.world.pieces[id]
	check(back != null and back.mat == "armor" and is_equal_approx(back.loss, 0.05) and back.kerf_dt > 0.0, "a save keeps a part's material, heat and loss")
	check(g.world.mat_priced and is_equal_approx(g.world.metal_price, price) and absf(g.world.scrap_value(back) - v0) < 0.01, "and its scrap price")
	g.queue_free()
	await _frames(3)
	# a save from before materials: strip the fields and load it
	var d: Dictionary = SaveGame.read()
	d.world.erase("mat_priced")
	for pd in d.world.pieces:
		for k in ["mat", "kdt", "loss", "crk"]:
			pd.erase(k)
	SaveGame.write_file(SaveGame.path, d)
	SaveGame.load_requested = true
	g = await _game("pt34")
	await _frames(3)
	var old = null
	for id in g.world.order:
		if g.world.pieces[id].key == key:
			old = g.world.pieces[id]
	check(old != null and old.mat == "" and not g.world.mat_priced and is_equal_approx(g.world.scrap_value(old), old.mass * g.world.metal_price), "an old save loads plain and pays scrap as it always did")
	check(old != null and is_equal_approx(old.cut_speed, armor_speed_of(d, key)), "and keeps the cut speed it was saved with")
	g.queue_free()
	await _frames(3)
	SaveGame.clear()


func armor_speed_of(d: Dictionary, key: String) -> float:
	for pd in d.world.pieces:
		if str(pd.get("key", "")) == key:
			return float(pd.cs)
	return -1.0
