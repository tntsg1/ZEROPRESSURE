extends SceneTree
# 公测反馈 #13 ("窗口化模式下…按键设置最下面的设置显示不完全，建议弄出无边框窗口化"): at several window
# sizes (and a screen made short on purpose, so the strip must scroll) the last key and the last
# settings row can be reached — by the wheel, by End, by the arrow keys — and stand inside the strip;
# the bottom button ("reset the keys", "back") and its help line stay on the screen. The display mode
# goes window → borderless → full and back, saved and read again (a test settings file only; the
# player's own file is compared byte for byte before and after). The window stays off-screen; the
# test never moves the mouse and never changes the real window mode.
#   tools/run_test.sh tests/settings_scroll_check.gd
const Cap = preload("res://tests/cap.gd")
const TEST_CFG := "user://zp_test_display_settings.cfg"
var fails := 0
var checks := 0
var p: SettingsPanel


func _initialize() -> void:
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


func _key(code: Key, n := 1) -> void:
	for i in n:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = true
		root.push_input(e, true)
		var u := e.duplicate()
		u.pressed = false
		root.push_input(u, true)
		await process_frame


func _wheel(down: bool, n: int) -> void:
	for i in n:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		e.factor = 1.0
		e.position = p.c.size * 0.5
		root.push_input(e, true)
		await process_frame


func _inside(r: Rect2, b: Dictionary) -> bool:
	return r.position.y >= b.top - 0.5 and r.end.y <= b.bot + 0.5


func _page_checks(tag: String) -> void:
	var h: float = p._view().y
	# ---- the key list
	p.keys_open = true
	p.ksel = 0
	await _key(KEY_HOME)
	await _frames(4)
	var b: Dictionary = p._keys_box()
	var last: int = Keys.ORDER.size() - 1
	Cap.save(root, "res://tests/out/settings_%s_keys_top.png" % tag)
	await _wheel(true, 40)
	await _frames(4)
	check(absf(p.kscroll - b.max) < 0.5 and _inside(p._key_rect(last), b), "%s keys: the wheel reaches the last key (scroll %.0f of %.0f)" % [tag, p.kscroll, b.max])
	Cap.save(root, "res://tests/out/settings_%s_keys_bottom.png" % tag)
	await _key(KEY_HOME)
	check(p.kscroll == 0.0, "%s keys: Home goes back to the top" % tag)
	await _key(KEY_END)
	check(absf(p.kscroll - b.max) < 0.5 and _inside(p._key_rect(last), b), "%s keys: End reaches the last key" % tag)
	await _key(KEY_HOME)
	await _key(KEY_DOWN, ceili(Keys.ORDER.size() / 2.0) - 1)
	await _frames(2)
	check(p.ksel >= Keys.ORDER.size() - 2 and _inside(p._key_rect(p.ksel), b), "%s keys: the arrows walk to the last row and it follows into view (key %d)" % [tag, p.ksel])
	var rr: Rect2 = p._key_rect(Keys.ORDER.size())
	check(rr.end.y <= h and b.bot + 12 + 42 + 30 <= h, "%s keys: reset and the help line stay on the screen (%.0f / %.0f of %.0f)" % [tag, rr.end.y, b.bot + 84, h])
	# ---- the settings
	p.keys_open = false
	p.sel = 0
	p.scroll = 0.0
	await _frames(4)
	var m: Dictionary = p._main_box()
	await _key(KEY_DOWN, SettingsPanel.ROWS.size() - 2)
	await _frames(2)
	check(p.sel == SettingsPanel.ROWS.size() - 2 and _inside(p._row_rect(p.sel), m), "%s settings: the arrows walk to the last row (%s) and it is in view" % [tag, SettingsPanel.ROWS[p.sel]])
	var back: Rect2 = p._row_rect(SettingsPanel.ROWS.size() - 1)
	check(back.end.y + 4 <= h and m.bot + RH_HINT <= h, "%s settings: the back button and its help line stay on the screen (%.0f of %.0f)" % [tag, back.end.y + 4, h])
	Cap.save(root, "res://tests/out/settings_%s_main.png" % tag)


const RH_HINT := 46.0 + 44.0


func _run() -> void:
	Txt.zh = true
	p = SettingsPanel.new()
	p.testing = true
	root.add_child(p)
	await _frames(4)
	p.open()
	await _frames(30)
	# ---- the window sizes the report names, then a screen too short for either page
	for sz in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(1280, 1024)]:
		root.size = sz
		await _frames(10)
		print("window %s → the page is %s" % [sz, p.c.size])
		await _page_checks("%dx%d" % [sz.x, sz.y])
	root.size = Vector2i(1280, 720)
	p.view_h = 640.0
	await _frames(6)
	check(p._keys_box().max > 0.0 and p._main_box().max > 0.0, "a short screen: both pages scroll (keys %.0f px, settings %.0f px)" % [p._keys_box().max, p._main_box().max])
	await _page_checks("short640")
	p.view_h = 0.0
	# ---- the display mode: three steps, saved and read again; the player's own file untouched
	var real := FileAccess.get_file_as_bytes(Txt.CFG)
	var was_path := Txt.cfg_path
	var was_mode := Txt.win_mode
	Txt.cfg_path = TEST_CFG
	p.testing = false
	Txt.win_mode = "window"
	var seen: Array = []
	for i in 3:
		p.change("window", 1)
		var shown := p.value("window")
		var mode := Txt.win_mode
		Txt.win_mode = "?"
		Txt.load_settings(false)
		seen.append("%s=%s" % [mode, shown])
		check(Txt.win_mode == mode and Txt.fullscreen == (mode == "full"), "the mode %s (%s) is saved and read back" % [mode, shown])
	check(seen.size() == 3 and str(seen).contains("borderless") and str(seen).contains("full=") and str(seen).contains("window="), "the three modes in turn: %s" % [seen])
	check(p.value("window").contains("无边框") or Txt.win_mode != "borderless", "the borderless mode has its own label")
	# an old settings file (only "fullscreen") still reads as full screen
	var cf := ConfigFile.new()
	cf.set_value("video", "fullscreen", true)
	cf.save(TEST_CFG)
	Txt.load_settings(false)
	check(Txt.win_mode == "full", "an old file with fullscreen on reads as full screen (%s)" % Txt.win_mode)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	Txt.cfg_path = was_path
	Txt.win_mode = was_mode
	p.testing = true
	check(FileAccess.get_file_as_bytes(Txt.CFG) == real, "the player's own settings file is byte for byte as it was")
	print("SETTINGS SCROLL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
