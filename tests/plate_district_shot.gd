extends "res://tests/guide_check.gd"
# 2026-11-10 用户：“要玩家操作才有显示屏”，推广到港区全部终端。每个区一张拼图：
# 左 = 无人机不在跟前（只有终端本体，没名牌），右 = 无人机在跟前（名牌 + 按键提示，14 px）。
# 同时检查：不在跟前时一块名牌都不画，在跟前时画了。测试存档。
#   tools/run_test.sh tests/plate_district_shot.gd --fixed-fps 60

const ConsoleArt = preload("res://scripts/console_art.gd")
const PS = preload("res://scripts/port_structure.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_plate_district_career.json"
	SaveGame.path = "user://zp_test_plate_district_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _hold(at: Vector2, n: int) -> void:
	for i in n:
		g.drone.alive = true
		g.drone.global_position = at
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame


func _crop() -> Image:
	var img := Cap.to_srgb8(root.get_texture().get_image())
	var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
	return img.get_region(Rect2i(c - Vector2i(450, 330), Vector2i(900, 600)))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(10)
	var spots := []
	for z in ["power", "process", "tug", "trade", "cargo", "ring"]:
		spots.append([z, PS.console_spot(z)])
	spots.append(["cargo_mouth", preload("res://scripts/cargo_floor.gd").mouth("A")])
	var gal = preload("res://scripts/process_gallery.gd")
	if gal.on():
		spots.append(["gallery_cast", gal.term("cast")])
	for sp in spots:
		var id: String = sp[0]
		var at: Vector2 = sp[1]
		g.cam_override = at + Vector2(0.0, -1.0) * Geom.M
		g.cam_pos = g.cam_override
		g.zoom_override = 1.3
		# away: 7 m above (9 m to the side in the gallery is the next terminal)
		await _hold(at + Vector2(0.0, -7.0) * Geom.M, 40)
		ConsoleArt.plates.clear()
		await _hold(at + Vector2(0.0, -7.0) * Geom.M, 6)
		check(ConsoleArt.plates.is_empty(), "%s: no plate with the drone away (%s)" % [id, str(ConsoleArt.plates.keys())])
		var a := _crop()
		await _hold(at, 40)
		ConsoleArt.plates.clear()
		await _hold(at, 6)
		check(not ConsoleArt.plates.is_empty(), "%s: the plate with the drone at it" % id)
		var b := _crop()
		var out := Image.create(1810, 600, false, a.get_format())
		out.fill(Color(0.3, 0.3, 0.3))
		out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, 0))
		out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(910, 0))
		out.save_png("res://tests/out/plate_district_%s.png" % id)
		print("SHOT plate_district_%s" % id)
	print("PLATE_DISTRICT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
