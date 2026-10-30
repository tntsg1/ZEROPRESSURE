extends SceneTree
const Cap = preload("res://tests/cap.gd")
const Title = preload("res://tests/title_terminal_check.gd").TestTitle
var title: Control
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func move(point: Vector2) -> void:
	var screen: Vector2 = title._origin_ui() + point * title._scale_ui()
	title.pointer_override = screen
	var ev := InputEventMouseMotion.new()
	ev.position = screen
	ev.global_position = screen
	root.push_input(ev, true)

func click(point: Vector2) -> void:
	move(point)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = title.pointer_override
		ev.global_position = ev.position
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		root.push_input(ev, true)

func button(point: Vector2, code: MouseButton, pressed: bool = true) -> void:
	move(point)
	var ev := InputEventMouseButton.new()
	ev.position = title.pointer_override
	ev.global_position = ev.position
	ev.button_index = code
	ev.pressed = pressed
	root.push_input(ev, true)

func _run() -> void:
	Txt.cfg_path = "user://zp_test_title_motion.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Txt.cfg_path))
	Txt.test_zh = true
	root.add_child(preload("res://tests/test_window.gd").new())
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	title = Title.new()
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Txt.anim = "full"
	await frames(80)
	move(Vector2(970,365))
	await frames(35)
	check(title.pointer_on_sheet and title.inspect_hot.x > 0.95, "real pointer input activates the engineering inspection")
	var first: Vector2 = title.inspect_at.x
	move(Vector2(1320,365))
	await frames(40)
	check(title.inspect_at.x.distance_to(first) > title.sheet_bounds.size.x * 0.1, "moving across the hull retargets the real structural close-up")
	check(title.drift.x.length() > 0.1, "full motion has bounded pointer-driven hull parallax")
	click(Vector2(1320,365))
	await frames(30)
	var locked: Vector2 = title.inspect_at.x
	move(Vector2(850,365))
	await frames(35)
	check(title.pinned and title.inspect_at.x.distance_to(locked) < 0.001, "click pins the inspected region while the pointer moves away")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	root.push_input(escape)
	await frames(3)
	check(not title.pinned, "Escape releases inspection without opening a menu")
	move(Vector2(200,530))
	await frames(2)
	check(title.rail_y.x > 324 and title.rail_y.x < title.rail_y.target, "menu focus rail travels between rows instead of teleporting")
	move(Vector2(200,460))
	await frames(45)
	check(absf(title.rail_y.x - title.rail_y.target) < 0.3, "rapid hover reversal settles on the newest menu row")
	Txt.anim = "lite"
	move(Vector2(1200,365))
	await frames(80)
	var stopped: float = title.live_time
	await frames(10)
	check(title.drift.x.length() < 0.01 and title.live_time == stopped and title.inspect_hot.x > 0.95, "reduced motion retains inspection but removes parallax and the ambient scan")
	Txt.anim = "off"
	move(Vector2(900,365))
	await frames(2)
	check(title.inspect_at.x == title.inspect_at.target and title._opening() == 1.0, "motion off updates inspection immediately without an entrance animation")
	move(Vector2(200,594))
	await frames(2)
	check(title.rail_y.x == title.rail_y.target, "motion off snaps menu focus to the selected row")
	title._open_slots()
	await frames(3)
	check(not title.hull_plot.visible and not title.detail_plot.visible, "engineering layers cannot draw over save management")
	title._close_slots()
	await frames(3)
	check(title.hull_plot.visible and title.detail_plot.visible, "engineering layers return after closing save management")
	Txt.anim = "full"
	move(Vector2(1080,365))
	await frames(90)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stamp := Time.get_ticks_usec()
	await frames(120)
	print("ACTIVE INSPECTION FRAME %.2f ms" % [(Time.get_ticks_usec() - stamp) / 120000.0])
	title.pinned = false
	move(Vector2(1400,560))
	await frames(45)
	check(title.zone_hover == "ruler" and title.inspect_at.x.x > title.sheet_bounds.get_center().x, "the full dimension ruler scrubs real hull positions")
	click(Vector2(1200,710))
	await frames(30)
	check(title.pinned and title.zone_hover == "map", "the port map locates and pins a real region")
	var before_drag: Vector2 = title.inspect_at.x
	button(Vector2(800,700),MOUSE_BUTTON_LEFT)
	move(Vector2(950,700))
	await frames(35)
	check(title.detail_drag and title.inspect_at.x.x < before_drag.x, "dragging the detail window pans real cached geometry")
	button(Vector2(950,700),MOUSE_BUTTON_LEFT,false)
	await frames(3)
	check(not title.detail_drag, "releasing the pointer ends detail dragging")
	button(Vector2(800,700),MOUSE_BUTTON_WHEEL_UP)
	await frames(45)
	check(title.detail_zoom.x > 1.2, "scrolling over the detail window increases magnification")
	var mesh_id: int = title.sheet_mesh.get_instance_id()
	click(Vector2(700,825))
	await frames(3)
	check(title.drawing_layer == 1 and title._visible_mesh() == title.structure_mesh, "drawing source switches to the real structure layer")
	click(Vector2(700,825))
	await frames(3)
	check(title.drawing_layer == 2 and title.service_mesh.get_surface_count() > 0, "a second click isolates authored service routes")
	click(Vector2(700,825))
	await frames(3)
	check(title.drawing_layer == 0 and title.sheet_mesh.get_instance_id() == mesh_id, "layer cycling reuses the original cached mesh")
	click(Vector2(1050,825))
	await frames(3)
	check(title.show_ports and title.ports_mesh.get_surface_count() > 0, "the control toggle reveals real authored access points")
	click(Vector2(1470,32))
	await frames(3)
	check(title.scan_time < 0.2, "the system status triggers a new engineering scan")
	click(Vector2(250,160))
	await frames(3)
	check(title.entry_time < 0.2, "the large title replays the arrival without blocking input")
	click(Vector2(1400,825))
	await frames(60)
	check(title._in_slots(), "work status opens the real save management screen")
	title._close_slots()
	await frames(60)
	for dims in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.content_scale_size = dims
		root.size = dims
		await frames(3)
		move(Vector2(1050,825))
		await frames(3)
		check(title.zone_hover == "ports", "scaled pointer reaches lower controls at %d" % dims.x)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		Cap.save(root, "res://proofs/title_motion_inspect.png")
	# Record real rendered states under synthetic mouse input; no player save is
	# read or written. A fixed 60 Hz step gives a reproducible 20 fps preview.
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/title_motion_frames"))
		title.entry_time = 0.0
		title.live_time = 0.0
		title.pinned = false
		title.show_ports = false
		title.detail_zoom.snap(1.0)
		for frame in 230:
			var point := Vector2(250,160)
			if frame >= 25 and frame < 45: point = Vector2(1470,32)
			elif frame >= 45 and frame < 85: point = Vector2(lerpf(650,1400,float(frame - 45) / 40),560)
			elif frame >= 85 and frame < 110: point = Vector2(lerpf(1180,1460,float(frame - 85) / 25),705)
			elif frame >= 110 and frame < 145: point = Vector2(lerpf(750,970,float(frame - 110) / 35),700)
			elif frame >= 145 and frame < 165: point = Vector2(800,700)
			elif frame >= 165 and frame < 190: point = Vector2(700,825)
			elif frame >= 190 and frame < 215: point = Vector2(1050,825)
			elif frame >= 215: point = Vector2(1400,825)
			move(point)
			if frame in [5,30,100,166,178,190,216]: click(point)
			if frame == 110: button(point,MOUSE_BUTTON_LEFT)
			if frame == 145: button(point,MOUSE_BUTTON_LEFT,false)
			if frame in [146,152]: button(point,MOUSE_BUTTON_WHEEL_UP)
			await frames(3)
			await RenderingServer.frame_post_draw
			Cap.save(root,"res://proofs/title_motion_frames/%03d.png" % frame)
	print("TITLE MOTION %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
