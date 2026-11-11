extends "res://tests/guide_check.gd"
# 2026-11-10 用户：六处不能交互的屏保留，但要“一看就知道是背景”。每处两张图：近景 + 和旁边能按的终端同框。
#   before：存原图 + 帧时间；after：存新图、拼前后对比 tests/out/bg_<id>_cmp.png，并检查：
#   - 无人机停在旁边：不出铭牌/按键提示，各处的 E 判定都不认它（不是终端）
#   - 无人机靠近不变亮（屏幕区域亮度和无人机远离时一样）
#   - 悬停说明卡里没有“按 E”
#   - 帧时间不比 before 差（同一画面、同样帧数的平均）
# 测试存档。tools/run_test.sh tests/bg_screens_check.gd --fixed-fps 60 -- before|after

const ConsoleArt = preload("res://scripts/console_art.gd")
const PS = preload("res://scripts/port_structure.gd")
const PSA = preload("res://scripts/power_station_art.gd")
const TA = preload("res://scripts/trade_hall_art.gd")
const HW = preload("res://scripts/hub_works.gd")
const BP = preload("res://scripts/bale_press.gd")
var tag := "after"


func _initialize() -> void:
	Career.path = "user://zp_test_bg_screens_career.json"
	SaveGame.path = "user://zp_test_bg_screens_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _hold(at: Vector2, n: int) -> void:
	for i in n:
		g.drone.alive = true
		g.drone.global_position = at
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame


func _img() -> Image:
	return Cap.to_srgb8(root.get_texture().get_image())


# [id, the panel's centre (world px), its size (m), the interactive console to frame it with, where the
# drone parks out of the way — inside the same district (a district's inside is drawn only with the drone in it)]
func _spots() -> Array:
	var M := PS.M()
	var pw := PS.box("power").position
	var out := []
	out.append(["power_screen", pw + PSA.SCREEN.get_center() * M, PSA.SCREEN.size, PS.console_spot("power"), pw + Vector2(6.0, 24.0) * M])
	out.append(["power_bay3", pw + Vector2(float(PSA.BAY_X[2]) + 3.0, 9.9) * M, Vector2(7.0, 1.6), PS.console_spot("power"), pw + Vector2(6.0, 24.0) * M])
	var gp := float(HW.spokes().get("power", -PI * 0.5))
	out.append(["hub_cabinet", PS.centre() - Vector2.from_angle(gp) * 5.75 * M, Vector2(1.6, 2.8), PS.console_spot("ring"), PS.centre() + Vector2(0.0, 40.0) * M])
	out.append(["trade_board", PS.box("trade").position + TA.BOARD.get_center() * M, TA.BOARD.size, PS.console_spot("trade"), PS.box("trade").position + Vector2(30.0, 20.0) * M])
	out.append(["bale_probe", PS.box("process").position + (BP.PROBE + Vector2(0.55, -1.575)) * M, Vector2(2.2, 1.35), preload("res://scripts/process_gallery.gd").term("business"), PS.box("process").position + Vector2(8.0, 3.2) * M])
	var ln = g.consoles.line
	var raw: Array = ln._raw
	var bxs: Array = ln._boxes
	out.append(["store_box", raw[bxs[0]], Vector2(0.9, 0.64), preload("res://scripts/consoles.gd").kiosk_at(), raw[bxs[0]] + Vector2(0.0, 30.0) * M])
	return out


func _lum(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var n := 0
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var c := img.get_pixel(x, y)
			s += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			n += 1
	return s / maxf(1.0, n)


func _frame_ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		tag = OS.get_cmdline_user_args()[0]
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	var port: Dictionary = Career.data.get("port", {})
	for z in ["power", "process", "trade", "ring"]:
		port[z] = 1
	Career.data.port = port
	Career.save()
	await _spawn()
	await _frames(20)
	var M := PS.M()
	var ms_total := 0.0
	for sp in _spots():
		var id: String = sp[0]
		var at: Vector2 = sp[1]
		var size: Vector2 = sp[2]
		var con: Vector2 = sp[3]
		# the close-up, the drone parked well away
		var away: Vector2 = sp[4]
		g.cam_override = at
		g.cam_pos = at
		var zc := clampf(minf(1500.0 / ((size.x + 4.0) * M), 800.0 / ((size.y + 4.0) * M)), 0.3, 3.0)
		g.zoom_override = zc
		await _hold(away, 50)
		var close_far := _img()
		# the drone beside it (not over it): nothing lights up
		var half := Vector2i(size * M * zc * 0.5)
		var pr := Rect2i(Vector2i(960, 540) - half, half * 2)
		await _hold(at + Vector2(size.x * 0.5 + 2.0, size.y * 0.5 + 1.5) * M, 40)
		var close_near := _img()
		# with the console beside it: both in the picture
		var mid := (at + con) * 0.5
		var span := (at - con).abs() + Vector2(14.0, 10.0) * M
		g.cam_override = mid
		g.cam_pos = mid
		g.zoom_override = clampf(minf(1920.0 / span.x, 1080.0 / span.y), 0.2, 2.0)
		await _hold(away, 50)
		var pair := _img()
		ms_total += await _frame_ms(90)
		var crop := close_far.get_region(Rect2i(Vector2i(510, 240), Vector2i(900, 600)))
		var small := pair.duplicate()
		small.resize(900, 506, Image.INTERPOLATE_BILINEAR)
		if tag == "before":
			crop.save_png("res://tests/out/bg_%s_close_before.png" % id)
			small.save_png("res://tests/out/bg_%s_pair_before.png" % id)
			print("SHOT bg_%s before" % id)
			continue
		crop.save_png("res://tests/out/bg_%s_close_after.png" % id)
		small.save_png("res://tests/out/bg_%s_pair_after.png" % id)
		var cb := Image.load_from_file(ProjectSettings.globalize_path("res://tests/out/bg_%s_close_before.png" % id))
		var pb := Image.load_from_file(ProjectSettings.globalize_path("res://tests/out/bg_%s_pair_before.png" % id))
		if cb != null and pb != null:
			var cmp := Image.create(1810, 1116, false, crop.get_format())
			cmp.fill(Color(0.35, 0.35, 0.35))
			cb.convert(crop.get_format())
			pb.convert(crop.get_format())
			cmp.blit_rect(cb, Rect2i(Vector2i.ZERO, cb.get_size()), Vector2i(0, 0))
			cmp.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(910, 0))
			cmp.blit_rect(pb, Rect2i(Vector2i.ZERO, pb.get_size()), Vector2i(0, 610))
			cmp.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(910, 610))
			cmp.save_png("res://tests/out/bg_%s_cmp.png" % id)
			print("SHOT bg_%s_cmp" % id)
		var l0 := _lum(close_far, pr)
		var l1 := _lum(close_near, pr)
		check(l1 - l0 < 0.02, "%s: no brighter with the drone beside it (%.3f -> %.3f)" % [id, l0, l1])
		# the drone at it: no plate, no key hint, and no E check takes it for a console
		g.zoom_override = 1.0
		# beside it (the quote board: on it — the companies' counters are right under it, and those are for E)
		var by := at + Vector2(0.0, size.y * 0.5 + 1.0) * M if id != "trade_board" else at
		await _hold(by, 20)
		ConsoleArt.plates.clear()
		await _hold(by, 4)
		var district: String = g.port_structure.near_console()
		var gallery: String = g.process_gallery.near() if g.process_gallery != null else ""
		var berth: String = g.consoles.near()
		var counter: String = g.trade_hall.near_counter() if g.trade_hall != null else ""
		var mill: bool = g.mill_line.near() if g.mill_line != null else false
		var furnace: bool = g.industrial_heat.near() if g.industrial_heat != null else false
		# the stores' junction box sits by the stores terminal: being near that terminal is fine
		var quiet: bool = ConsoleArt.plates.is_empty() or (id == "store_box" and berth == "rack")
		quiet = quiet and district == "" and gallery == "" and counter == "" and not mill and not furnace and (berth == "" or id == "store_box")
		check(quiet, "%s: no plate, no key hint, no console's E (plates %s, district %s, gallery %s, berth %s, counter %s, mill %s, furnace %s)" % [id, str(ConsoleArt.plates.keys()), district, gallery, berth, counter, mill, furnace])
		# its hover card (if any) does not say to press E
		var said := ""
		var di = g.port_structure.get("interiors")
		if di != null and di.get("card") != null and di.card.items.is_valid():
			for it in di.card.items.call():
				if (it.rect as Rect2).has_point(at):
					said = str(it.get("use", "")) + str(it.get("can", ""))
					break
		var key := "[%s]" % Keys.label("use")
		check(not said.contains(key) and not said.contains("按 " + Keys.label("use")), "%s: its hover card does not say press %s (%s)" % [id, Keys.label("use"), said.substr(0, 60)])
	print("FRAME_MS %s %.2f" % [tag, ms_total / 6.0])
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://tests/out/bg_frame_ms_%s.txt" % tag), FileAccess.WRITE)
	fa.store_string("%.3f" % (ms_total / 6.0))
	fa.close()
	if tag == "after":
		var fb := FileAccess.open(ProjectSettings.globalize_path("res://tests/out/bg_frame_ms_before.txt"), FileAccess.READ)
		if fb != null:
			var before := float(fb.get_as_text())
			check(ms_total / 6.0 <= before * 1.1 + 0.5, "frame time not worse (%.2f ms before, %.2f after)" % [before, ms_total / 6.0])
	print("BG_SCREENS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
