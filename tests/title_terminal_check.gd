extends SceneTree
const Cap = preload("res://tests/cap.gd")

class TestTitle extends "res://scripts/title_terminal.gd":
	var fixture: Array = [{}, {}, {}]
	var entered := -1
	func _refresh_home() -> void:
		select_home(fixture, [10, 30, 20])
	func _open_slots() -> void:
		super._open_slots()
		slots = fixture.duplicate(true)
	func _enter(i: int) -> void:
		if slots[i].is_empty(): super._enter(i)
		else: entered = i  # Never switch to or write the player's actual slots.

var title: TestTitle
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int = 3) -> void:
	for i in n: await process_frame

func check(ok: bool, what: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])
	if not ok: fails += 1

func key(code: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	root.push_input(ev)
	await frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	root.push_input(ev)
	await frames(1)

func click_item(i: int) -> void:
	var pos := title._item_rect(i).get_center()
	title.pointer_override = pos
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	await frames()
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	root.push_input(ev, true)
	await frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	root.push_input(ev, true)
	await frames()
	title.pointer_override = Vector2(-100, -100)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(10)
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/" + name + ".png")

func _run() -> void:
	Txt.cfg_path = "user://zp_test_title_terminal.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Txt.cfg_path))
	Txt.test_zh = true
	Txt.zh = true
	Txt.dev = false
	root.add_child(preload("res://tests/test_window.gd").new())
	title = TestTitle.new()
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.pointer_override = Vector2(-100, -100)
	await frames()
	Txt.zh = true
	var actual: Control = load("res://scenes/title.tscn").instantiate()
	check(actual.get_script().resource_path.ends_with("title_terminal.gd"), "the actual title scene uses the terminal screen")
	actual.free()
	check(title._items()[0][0] == "new" and title._items().size() == 4, "empty saves emphasize a new company without a dead Continue action")
	check(title.sheet_id == "ark01" and title.sheet_mesh != null and title.sheet_mesh.get_surface_count() == 1, "the fleet preview is a cached real ARK-01 engineering mesh")
	await shot("title_terminal_empty_zh")
	await click_item(0)
	check(title._in_slots() and title.naming == 0 and title.name_edit.visible and title.name_edit.has_focus(), "mouse selection of New Company focuses the first empty slot name")
	await key(KEY_ESCAPE)
	check(title.naming == -1 and not title.name_edit.visible, "Escape cancels naming")
	await key(KEY_ESCAPE)
	check(not title._in_slots(), "Escape returns from save selection")
	title.pointer_override = title._item_rect(0).get_center()
	await frames()
	await key(KEY_DOWN)
	await frames()
	check(title.kb_sel == 1, "a stationary pointer does not steal keyboard selection")
	await key(KEY_TAB)
	check(title.kb_sel == 2, "Tab advances through the main actions")
	await key(KEY_TAB, true)
	check(title.kb_sel == 1, "Shift-Tab navigates backward")
	title.pointer_override = Vector2(-100,-100)
	title.fixture = [
		{"company": "旧港回收", "certified": false, "money": 0, "loan": 0, "done": 0, "rep": 0, "time": 300, "active": {}},
		{"company": "远航回收", "certified": true, "money": 185000, "loan": 0, "done": 12, "rep": 30, "time": 31000, "active": {"id": "DEV-ARK", "ship": "ark01"}}, {}]
	title._refresh_home()
	title._load_sheet()
	await frames(60)
	check(title.recent_slot == 1 and title._items()[0][0] == "resume" and title._items().size() == 5, "the newest valid save becomes the primary Continue action")
	await shot("title_terminal_home_zh")
	await key(KEY_ENTER)
	check(title.entered == 1 and not title._in_slots(), "Enter continues the newest slot through the existing resume route")
	title.entered = -1
	await click_item(1)
	check(title._in_slots() and title.slots.size() == 3, "Choose Save opens the existing three-slot screen")
	await key(KEY_1)
	await key(KEY_ENTER)
	check(title.entered == 0, "another training save remains selectable with keyboard input")
	await shot("title_terminal_slots_zh")
	await key(KEY_ESCAPE)
	await click_item(2)
	check(title.naming == 2 and title.name_edit.has_focus(), "New Company chooses the empty slot without replacing existing saves")
	title.name_edit.text = "零压回收"
	await shot("title_terminal_naming_zh")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	title.fixture[2] = title.fixture[0].duplicate(true)
	title._refresh_home()
	title._pick("new")
	check(title.full_slots and title.naming == -1 and title._in_slots(), "full saves go to management without overwriting or opening a name field")
	await key(KEY_ESCAPE)
	title.pointer_override = Vector2(-100, -100)
	await frames(60)
	title.kb_sel = 0
	for i in 3: await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(title.settings.is_open, "keyboard navigation opens the real settings panel")
	await key(KEY_ESCAPE)
	check(not title.settings.is_open and not title._in_slots(), "closing settings returns to the terminal title")
	await frames(90)
	# Actual resizing and localization, with screen-space hit rectangles checked.
	for dims in [Vector2i(1920,1080), Vector2i(1280,720)]:
		root.content_scale_size = dims
		root.size = dims
		await frames(5)
		for chinese in [true, false]:
			Txt.zh = chinese
			title.kb_sel = 0
			await frames(10)
			var inside := true
			for i in title._items().size():
				inside = inside and Rect2(Vector2.ZERO,title.size).encloses(title._item_rect(i))
			check(inside, "%s %s: all menu hit targets remain inside the viewport" % [str(dims), "ZH" if chinese else "EN"])
			await shot("title_terminal_%d_%s" % [dims.x, "zh" if chinese else "en"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await frames(30)
	var stamp := Time.get_ticks_usec()
	await frames(80)
	print("TITLE FRAME: %.2f ms average, cached real hull mesh" % [(Time.get_ticks_usec() - stamp) / 80000.0])
	# the sheet: a company with a save sees its port first; the head toggles to ARK-01 and back
	title.fixture = [{"company": "T", "money": 1.0, "port": {"power": 1}}, {}, {}]
	title.mode_chosen = false
	title._refresh_home()
	await frames(5)
	check(title.sheet_mode == "port" and title.recent_slot == 0, "a returning company's title shows its own port")
	var head := title._origin_ui() + Vector2(700, 128) * title._scale_ui()
	for i in 2:
		var ev := InputEventMouseButton.new()
		ev.position = head
		ev.global_position = head
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		title._gui_input(ev)
		await frames(3)
		check(title.sheet_mode == ("ship" if i == 0 else "port"), "clicking the sheet's head switches to %s" % ("ARK-01" if i == 0 else "the port"))
	title.fixture = [{}, {}, {}]
	title.mode_chosen = false
	title._refresh_home()
	await frames(3)
	check(title.sheet_mode == "ship", "with no save the title shows the ship sheet")
	await key(KEY_F12)
	check(Txt.dev and DevPanel.workbench_open, "F12 developer workbench remains reachable on the new title")
	await key(KEY_ESCAPE)
	check(not DevPanel.workbench_open, "Escape closes the developer workbench")
	title.queue_free()
	await frames()
	print("TERMINAL TITLE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)
