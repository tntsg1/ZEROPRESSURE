extends "res://tests/g5_heat_ui_visual.gd"
# Native panel mouse hit-testing at two sizes; declared facility/operator
# fixtures, not physical transport, human operation or final visual quality.
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g5_sort_ui_career.json"
	SaveGame.path = "user://zp_test_g5_sort_ui_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1}
	Txt.zh = true
	await spawn()
	g.drone.global_position = g.industrial_sort.site()
	g.drone.freeze = true
	g.cam_override = Vector2(Dock.metal_home+3,Dock.FLOOR_Y+4)*Geom.M
	g.zoom_override = 1.0
	await frames(60)
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		g.open_sort()
		await frames(8)
		check(g.console_ui != null and not paused,"native sorting page stays live at "+str(size))
		var reserve := find_button("把仓库废料送到分选机")
		check(reserve.get_global_rect().end.x <= size.x,"sorting controls fit actual viewport width")
		await mouse_click(reserve)
		check(g.console_ui.message.text.contains("未分选金属不足") and not Career.production_busy(),"actual viewport mouse reservation reports absent stock without creating material or a batch")
		await capture("g5_sort_ui_%dx%d" % [size.x,size.y])
		await mouse_click(find_button("关闭面板 [Esc]"))
		check(g.console_ui == null and not paused,"native scrolling exposes a working sorting close control at "+str(size))
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 SORT UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
