extends SceneTree
# 专属画法预览 (2026-11-11, E002–E016 off the shared "aux" valve): for each name_key, the old
# shared drawing and the new one at the 零件图鉴 cell scale, the new one at the game's own pixel
# size (1x) and 2x, the same drawing inside a rect that does not start at the origin, and two
# other sizes/aspects. Reads ships/*.json only; touches no save.
# tools/run_test.sh tests/art_named_aux_check.gd -- <out_dir> [cells] [perf] [b2]   (b2: the battery batch)
#   cells: also writes one 480x360 catalog cell per key (old_<nk>.png / new_<nk>.png)

const M := 48.0
const CW := 480
const CH := 360
const K1 := ["p_ark_amp", "p_aux", "p_ax_gamma_monitor", "p_bl_feeder", "p_bl_humidifier", "p_bl_mister",
	"p_comms", "p_dc_firewall", "p_dr_welder", "p_e07", "p_ev_shunt", "p_fx_gas_injector", "p_hg_ioniser",
	"p_qc_clock", "p_st_daq"]
# second batch (E018–E028): the batteries
const K2 := ["p_ark_aux_battery", "p_ark_battery_cart", "p_ark_emerg_light", "p_ark_ring_battery", "p_ark_shuttle_battery",
	"p_aux_battery", "p_battery", "p_drone_pack", "p_lc_courier_battery", "p_lock_ups", "p_pod_bat",
	"p_st_battery", "p_standby_battery", "p_ups"]
# third batch (the shared double-door cabinet), first part
const C1 := ["p_ark_brake_ctrl", "p_ark_chem_dosing", "p_ark_material", "p_ark_process", "p_ark_transmitter", "p_ark_turbine_ctrl",
	"p_drill", "p_tool_cart", "p_pack_rack", "p_dispatch_log", "p_bms", "p_cal_bench", "p_survey_log", "p_crd", "p_crypto",
	"p_hv_cabinet", "p_gas_det"]
const C2 := ["p_bl_herbarium", "p_bl_tool_shed", "p_dr_chem_store", "p_dr_sample_cab", "p_dr_tool_cab", "p_dr_well_logs", "p_ev_calib",
	"p_ev_dcdc", "p_fx_cdb", "p_fx_cryo_spares", "p_fx_shot_archive", "p_fx_spare_leads", "p_hg_sample_cyl", "p_ob_cal",
	"p_ob_plate_archive", "p_ob_spare_cells", "p_dc_spares"]
const C3 := ["p_batch_log", "p_cabinet", "p_cargo_log", "p_custody", "p_evidence", "p_flow_ctrl", "p_lc_courier_mail", "p_manifest",
	"p_pharmacy", "p_samples", "p_seed_vault", "p_smelt_log", "p_st_spares", "p_stores", "p_svc_cabinet", "p_table", "p_towlog"]
const D4 := ["p_bl_electrolyser", "p_fuel_cell", "p_fuelcell", "p_ark_backup_gen", "p_backup_gen", "p_standby_gen", "p_co2_gen",
	"p_dr_generator", "p_gen", "p_generator", "p_ts_power"]
var KEYS: Array = K1

var out := "E:/godot/zeropower/proofs/零件专属画法_E002-E016"
var cells := false
var node: Node2D
var font: Font
var picks := {}      # nk -> [pd, ship]
var sizes := {}      # nk -> {"w x h": [w, h]} every size it comes in across the fleet
var mode := ""       # "sheet" | "cell"
var cur := ""
var cur_old := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	cells = "cells" in a
	if "b2" in a:
		KEYS = K2
	if "c1" in a:
		KEYS = C1
	if "c2" in a:
		KEYS = C2
	if "c3" in a:
		KEYS = C3
	if "d4" in a:
		KEYS = D4
	perf = "perf" in a
	root.add_child(preload("res://tests/test_window.gd").new())
	font = Fonts.get_font("Regular")
	Art.EQ.ext = Art.SH
	Art.EQ.detail = Art.DT
	_collect()
	node = Node2D.new()
	node.draw.connect(_paint)
	root.add_child(node)
	_run()


func _collect() -> void:
	var dir := DirAccess.open("res://ships")
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.open("res://ships/" + f, FileAccess.READ).get_as_text())
		if typeof(d) != TYPE_DICTIONARY:
			continue
		for pd in d.get("pieces", []):
			var nk: String = str(pd.get("name_key", ""))
			if nk in KEYS and not picks.has(nk):
				picks[nk] = [pd, f.get_basename()]
			if nk in KEYS and pd.has("art_size") and (pd.art_size as Array).size() == 2:
				if not sizes.has(nk):
					sizes[nk] = {}
				sizes[nk]["%.2fx%.2f" % [float(pd.art_size[0]), float(pd.art_size[1])]] = [float(pd.art_size[0]), float(pd.art_size[1])]


func _piece(pd: Dictionary, old: bool, size_mul := Vector2.ONE):
	var p := Model.Piece.new()
	for k in ["density", "cut_speed", "tag", "name_key", "cls", "value", "cond", "art", "fragile", "room", "barrier", "kind", "label"]:
		if pd.has(k) and k in p:
			p.set(k, pd[k])
	if old:
		p.name_key = "zz_old_" + str(pd.get("name_key", ""))   # no BY_NAME entry: the piece's own art
		p.art = "aux"
	var sz: Array = pd.get("art_size", [1, 1])
	p.art_size = Vector2(float(sz[0]), float(sz[1])) * size_mul
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(p.art_size.x, 0), p.art_size, Vector2(0, p.art_size.y)])
	for i in poly.size():
		poly[i] *= M
	p.poly = poly
	return p


func _cell(org: Vector2, p, maxw: float, maxh: float, label: String) -> float:
	var ext: Vector2 = p.art_size * M
	var s := clampf(minf((maxw - 40.0) / ext.x, (maxh - 40.0) / ext.y), 0.35, 3.0)
	var at := org + Vector2(maxw, maxh) * 0.5 - ext * s * 0.5
	node.draw_rect(Rect2(org, Vector2(maxw, maxh)), Color(0.052, 0.055, 0.063))
	node.draw_set_transform(at, 0.0, Vector2(s, s))
	node.draw_rect(Rect2(Vector2.ZERO, ext), Pal.ink(0.5), false, 1.0 / s)
	Art.draw(node, p.art, ext, p, font)
	node.draw_set_transform(Vector2.ZERO)
	if label != "":
		node.draw_string(font, org + Vector2(8, 16), label, HORIZONTAL_ALIGNMENT_LEFT, maxw - 16, 12, Pal.ink(0.6))
	return s


func _paint() -> void:
	if mode == "cell":
		var pk: Array = picks[cur]
		_cell(Vector2.ZERO, _piece(pk[0], cur_old), CW, CH, "")
		return
	# the sheet: one row per key
	var y := 0.0
	var rh := 300.0
	for nk in KEYS_now:
		if not picks.has(nk):
			continue
		var pk: Array = picks[nk]
		var pd: Dictionary = pk[0]
		_cell(Vector2(0, y), _piece(pd, true), 400, rh, "旧 · " + nk)
		_cell(Vector2(404, y), _piece(pd, false), 400, rh, "新 · %s · %s" % [Txt.t(nk), pk[1]])
		# the game's own pixels (1x) and 2x, on a dark plate
		var p1 = _piece(pd, false)
		var ext: Vector2 = p1.art_size * M
		node.draw_rect(Rect2(808, y, 380, rh), Color(0.04, 0.042, 0.048))
		node.draw_string(font, Vector2(816, y + 16), "1x / 2x（游戏像素）", HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Pal.ink(0.6))
		node.draw_set_transform(Vector2(820, y + 40))
		Art.draw(node, p1.art, ext, p1, font)
		node.draw_set_transform(Vector2(830 + ext.x, y + 40), 0.0, Vector2(2, 2))
		Art.draw(node, p1.art, ext, p1, font)
		node.draw_set_transform(Vector2.ZERO)
		# r.position: record straight into a rect at an offset, outline the rect it was given
		node.draw_rect(Rect2(1192, y, 300, rh), Color(0.052, 0.055, 0.063))
		node.draw_string(font, Vector2(1200, y + 16), "偏移原点 r.position", HORIZONTAL_ALIGNMENT_LEFT, 280, 12, Pal.ink(0.6))
		var s2 := clampf(minf(200.0 / ext.x, 200.0 / ext.y), 0.35, 3.0)
		var off := Rect2(Vector2(37, 23), ext)
		node.draw_set_transform(Vector2(1200, y + 40) - off.position * s2 + Vector2(20, 0), 0.0, Vector2(s2, s2))
		node.draw_rect(off, Pal.tint(Pal.HEAT, 0.7), false, 1.0 / s2)
		var art: String = Art.SH.BY_NAME.get(nk, "")
		if art != "" and art in Art.SH.DRAWN:
			var rec = Art.EQ._record_fn(func(): Art.SH._draw_art(node, art, off, p1, font))
			Art.EQ._replay(node, rec)
		node.draw_set_transform(Vector2.ZERO)
		# other sizes: 0.6x and a stretched aspect
		node.draw_rect(Rect2(1496, y, 424, rh), Color(0.04, 0.042, 0.048))
		node.draw_string(font, Vector2(1504, y + 16), "0.6x / 宽 1.6x / 高 1.6x（2x 放大）", HORIZONTAL_ALIGNMENT_LEFT, 400, 12, Pal.ink(0.6))
		var x := 1504.0
		var muls := [Vector2(0.6, 0.6), Vector2(1.6, 1.0), Vector2(1.0, 1.6)]
		var others := []
		var bs: Array = pd.get("art_size", [1, 1])
		for k in sizes.get(nk, {}):
			var v: Array = sizes[nk][k]
			if absf(v[0] - float(bs[0])) > 0.01 or absf(v[1] - float(bs[1])) > 0.01:
				others.append(Vector2(v[0] / float(bs[0]), v[1] / float(bs[1])))
		if not others.is_empty() and not nk in ["p_comms", "p_battery", "p_ups"]:   # the key's other real sizes
			muls = others.slice(0, 4)
		if nk == "p_comms":   # the console's real sizes on the other ships (base 1.0 x 0.7)
			muls = [Vector2(1.45, 3.6 / 0.7), Vector2(2.0, 2.96 / 0.7), Vector2(3.6, 1.48 / 0.7), Vector2(2.4, 0.8 / 0.7)]
		elif nk == "p_ups":   # the UPS on the other ships (base 1.8 x 2.0): DC-84's tower, SV-122's room, FL-116's tall one
			muls = [Vector2(0.8 / 1.8, 1.2 / 2.0), Vector2(8.0 / 1.8, 5.4 / 2.0), Vector2(2.4 / 1.8, 4.0 / 2.0), Vector2(3.0 / 1.8, 2.1 / 2.0)]
		elif nk == "p_battery":   # the main battery's real sizes across the fleet (base 1.8 x 1.6)
			muls = [Vector2(0.8 / 1.8, 0.8 / 1.6), Vector2(13.0 / 1.8, 2.55 / 1.6), Vector2(6.2 / 1.8, 6.0 / 1.6), Vector2(1.35 / 1.8, 3.0 / 1.6)]
		for mul in muls:
			var pv = _piece(pd, false, mul)
			var e2: Vector2 = pv.art_size * M
			var sc := minf(2.0, minf((100.0 if muls.size() > 3 else 130.0) / e2.x, 240.0 / e2.y))
			node.draw_set_transform(Vector2(x, y + 36), 0.0, Vector2(sc, sc))
			Art.draw(node, pv.art, e2, pv, font)
			node.draw_set_transform(Vector2.ZERO)
			x += e2.x * sc + 12.0
		y += rh + 4.0


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	if perf:
		_perf()
		quit()
		return
	var page := 3
	var all: Array = KEYS.duplicate()
	for i in range(0, all.size(), page):
		var chunk: Array = all.slice(i, i + page)
		mode = "sheet"
		KEYS_now = chunk
		node.queue_redraw()
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = load("res://tests/cap.gd").to_srgb8(root.get_texture().get_image())
		img.get_region(Rect2i(0, 0, 1920, int(chunk.size() * 304))).save_png("%s/预览_%d.png" % [out, i / page + 1])
	if cells:
		for nk in KEYS:
			if not picks.has(nk):
				continue
			for old in [true, false]:
				mode = "cell"
				cur = nk
				cur_old = old
				node.queue_redraw()
				for k in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				var img: Image = load("res://tests/cap.gd").to_srgb8(root.get_texture().get_image())
				img.get_region(Rect2i(0, 0, CW, CH)).save_png("%s/%s_%s.png" % [out, "old" if old else "new", nk])
	print("named aux preview done ", picks.size())
	quit()


var KEYS_now: Array = []
var perf := false


func _resolve(nk: String) -> String:
	if Pal.solid and Art.DT.BY_NAME.has(nk):
		return Art.DT.BY_NAME[nk]
	return Art.SH.BY_NAME.get(nk, "aux")


# per piece, old shared "aux" vs the new drawing: recording time (mean of 40), the
# triangle vertices it leaves to replay each frame, and the replay time (mean of 2000,
# batched the way a ship strip is)
func _perf() -> void:
	var lines := ["name_key,art,size,old_rec_us,new_rec_us,old_verts,new_verts,old_replay_us,new_replay_us"]
	print("PERF name_key | art | rec us old->new | verts old->new | replay us old->new")
	for nk in KEYS:
		if not picks.has(nk):
			print("PERF %s | not on any ship now" % nk)
			continue
		var base: Dictionary = picks[nk][0]
		var variants := [base]
		if nk == "p_battery":   # the biggest banks too
			for sz in [[13.0, 2.55], [6.2, 6.0]]:
				var v := base.duplicate()
				v["art_size"] = sz
				variants.append(v)
		for pd in variants:
			_perf_row(nk, pd, lines)
	var f := FileAccess.open(out + "/单件绘制开销.csv", FileAccess.WRITE)
	f.store_string("
".join(lines) + "
")
	f.close()


func _perf_row(nk: String, pd: Dictionary, lines: Array) -> void:
		var row := [nk, _resolve(nk), "%sx%s" % pd.get("art_size", [1, 1])]
		var res := {}
		for old in [true, false]:
			var p = _piece(pd, old)
			var art: String = "aux" if old else _resolve(nk)
			var rr := Rect2(Vector2.ZERO, p.art_size * M)
			var rec = null
			var t0 := Time.get_ticks_usec()
			for i in 40:
				rec = Art.EQ._record(node, art, rr, p, font)
			var t_rec := (Time.get_ticks_usec() - t0) / 40.0
			Art.EQ.batch_begin()
			t0 = Time.get_ticks_usec()
			for i in 2000:
				Art.EQ._replay(node, rec)
			var t_rep := (Time.get_ticks_usec() - t0) / 2000.0
			Art.EQ._batch = null
			res[old] = [t_rec, rec[0].size(), t_rep]
		row.append_array(["%.1f" % res[true][0], "%.1f" % res[false][0], str(res[true][1]), str(res[false][1]), "%.2f" % res[true][2], "%.2f" % res[false][2]])
		lines.append(",".join(row))
		print("PERF %s %s | %s | %.0f -> %.0f | %d -> %d | %.2f -> %.2f" % [nk, row[2], row[1], res[true][0], res[false][0], res[true][1], res[false][1], res[true][2], res[false][2]])
