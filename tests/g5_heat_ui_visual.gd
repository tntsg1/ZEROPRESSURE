extends "res://tests/g5_industrial_cycle_check.gd"
const Cap = preload("res://tests/cap.gd")
func mouse_click(button: Button) -> void:
	var ancestor = button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
	await frames(4)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	root.push_input(down,true)
	await frames(1)
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up,true)
	await frames(3)
func find_button(text: String) -> Button:
	for node in g.console_ui.find_children("*","Button",true,false):
		if node.text == text: return node
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	Cap.save(root,"res://proofs/"+name+".png")
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g5_heat_ui_career.json"
	SaveGame.path = "user://zp_test_g5_heat_ui_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1,"power":1} # 34 号: the furnace needs the power district for its 24 MW
	Txt.zh = true
	await spawn()
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	g.cam_override = Vector2(Dock.metal_home,Dock.FLOOR_Y+4.5)*Geom.M
	g.zoom_override = 1.0
	await frames(90)
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		g.open_heat()
		await frames(8)
		check(g.console_ui != null and not paused,"site panel stays live at "+str(size))
		check(g.console_ui.next_step.text.contains("仓库炉料送到炉口"),"furnace explicitly tells the player how to bring purchased warehouse feed over")
		var reserve := find_button("把仓库炉料送到炉口")
		check(reserve != null and reserve.get_global_rect().end.x <= size.x,"native production controls fit the viewport width")
		await mouse_click(reserve)
		check((g.console_ui.message.text.contains("炉料不足") or g.console_ui.message.text.contains("没有钢锭")) and not Career.production_busy(),"real viewport mouse press/release hits the native reserve control and reports actual unavailable stock (%s)" % g.console_ui.message.text)
		await capture("g5_heat_ui_%dx%d" % [size.x,size.y])
		var close := find_button("关闭面板 [Esc]")
		await mouse_click(close)
		check(g.console_ui == null,"native scroll container exposes a clickable close control at "+str(size))
	# Actual invalid-state restore must show useful account context and let
	# the player leave the panel without overwriting its failed evidence.
	await release()
	Career.data.industrial_heat = {"id":"CORRUPT-UI-FIXTURE","state":"processing","quantity":1.0,"furnace":{},"energy_debt":1.5}
	var original := JSON.stringify(Career.data.industrial_heat)
	await spawn(false)
	g.drone.global_position = g.industrial_heat.site()
	g.drone.freeze = true
	g.open_heat()
	await frames(20)
	check(g.console_ui.readout.text.contains("CORRUPT-UI-FIXTURE") and g.console_ui.readout.text.contains("1.50"),"fault panel keeps the heat identity and owed bill visible beside the error")
	await mouse_click(find_button("关闭面板 [Esc]"))
	check(g.console_ui == null and JSON.stringify(Career.data.industrial_heat) == original,"fault panel can be closed by an actual mouse event without erasing its invalid source record")
	await release()
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G5 HEAT UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
