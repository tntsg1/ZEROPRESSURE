extends Control
# The playtest build's gate over the title (scripts/demo.gd): past the end date it says so; a machine
# already activated is checked online (offline, it plays on if it checked in lately); otherwise it asks
# for a code. It also says what the recorder does. Nothing behind it can be reached until it lets go.
# 公测版 (2026-11-08 Q1 B, Gt.CODES off): no code field — the machine registers itself online (/hello)
# and goes straight in; offline it plays on for 3 days after the last check-in; the server's switch
# ("closed") holds everyone here with its words. Feedback left unsent last time goes up once it lets go.

const Gt = preload("res://scripts/demo.gd")

var font: Font
var font_b: Font
var state := "checking"       # checking | code | busy | expired | done | refused | closed | offline
var msg := ""
var box: VBoxContainer
var code_in: LineEdit
var go_b: Button
var quit_b: Button
var http: HTTPRequest


func _enter_tree() -> void:
	Gt.gate_open = true


func _exit_tree() -> void:
	Gt.gate_open = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	http = HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	code_in = LineEdit.new()
	code_in.placeholder_text = "ZP-XXXX-XXXX"
	code_in.max_length = 12
	code_in.custom_minimum_size = Vector2(420, 52)
	code_in.add_theme_font_override("font", font_b)
	code_in.add_theme_font_size_override("font_size", 26)
	code_in.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_in.text_submitted.connect(func(_t): _activate())
	box.add_child(code_in)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	go_b = _button(Gt.w("激活", "ACTIVATE") if Gt.CODES else Gt.w("重试", "RETRY"), _activate if Gt.CODES else _hello)
	row.add_child(go_b)
	quit_b = _button(Gt.w("退出", "QUIT"), func(): get_tree().quit())
	row.add_child(quit_b)
	_layout()
	get_viewport().size_changed.connect(_layout)
	if Gt.expired():
		_show("expired", Gt.error_text("expired"))
	elif Gt.finished():
		_show("done", Gt.w("这台电脑的试玩已经结束，谢谢你！", "This computer's playtest is over. Thank you!"))
	elif not Gt.CODES:
		_hello()
	elif Gt.code() != "":
		_check()
	else:
		_show("code", "")


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 48)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _layout() -> void:
	var s := get_viewport_rect().size
	box.position = Vector2(s.x * 0.5 - 210.0, s.y * 0.5 + 40.0)
	box.size = Vector2(420, 120)


func _show(st: String, m: String) -> void:
	state = st
	msg = m
	code_in.visible = Gt.CODES and (st == "code" or st == "busy" or st == "refused")
	go_b.visible = code_in.visible or (not Gt.CODES and st in ["offline", "refused"])
	go_b.disabled = st == "busy"
	if code_in.visible:
		code_in.grab_focus()
	queue_redraw()


func _post(path: String, body: Dictionary) -> Dictionary:
	var err := http.request(Gt.base_url + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {"ok": false, "error": "offline"}
	var r: Array = await http.request_completed
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "offline"}
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {"ok": false, "error": "offline"}


func _check() -> void:
	_show("checking", Gt.w("正在验证激活……", "Checking the activation…"))
	var d := await _post("/check", {"code": Gt.code(), "machine": Gt.machine()})
	if d.get("ok", false):
		Gt.touched()
		_pass()
	elif str(d.get("error", "")) == "offline" and Gt.within_grace():
		_pass()
	elif str(d.get("error", "")) == "expired":
		_show("expired", Gt.error_text("expired"))
	elif str(d.get("error", "")) == "offline":
		_show("refused", Gt.error_text("offline"))
	else:
		Gt.forget()
		_show("refused", Gt.error_text(str(d.get("error", ""))))


# 公测版: every start checks in; the first one registers this machine
func _hello() -> void:
	_show("checking", Gt.w("正在联网登记……", "Checking in…"))
	var d := await _post("/hello", {"machine": Gt.machine(), "version": Gt.VERSION})
	var e := str(d.get("error", ""))
	if d.get("ok", false):
		Gt.touched()
		_pass()
	elif e == "offline" and Gt.within_grace():
		_pass()
	elif e == "closed":
		_show("closed", str(d.get("message", "")) if str(d.get("message", "")) != "" else Gt.error_text("closed"))
	elif e == "offline":
		_show("offline", Gt.error_text("offline"))
	else:
		_show("refused", Gt.error_text(e))


func _activate() -> void:
	if state == "busy":
		return
	var c := code_in.text.strip_edges().to_upper()
	if not c.begins_with("ZP-") and c.length() == 8:
		c = "ZP-%s-%s" % [c.substr(0, 4), c.substr(4, 4)]
	_show("busy", Gt.w("正在激活……", "Activating…"))
	var d := await _post("/activate", {"code": c, "machine": Gt.machine()})
	if d.get("ok", false):
		Gt.remember(c)
		_pass()
	else:
		_show("refused", Gt.error_text(str(d.get("error", ""))))


func _pass() -> void:
	Gt.mark(get_tree())
	if not Gt.CODES:
		preload("res://scripts/demo_feedback.gd").flush(get_tree())
	queue_free()


func _input(ev: InputEvent) -> void:
	# everything behind waits, but the code field still types
	if ev is InputEventKey and not code_in.has_focus():
		get_viewport().set_input_as_handled()
		# Enter tries again (offline, refused): the page's one key
		if ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER] and go_b.visible and not go_b.disabled:
			go_b.pressed.emit()


func _draw() -> void:
	var s := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.022, 0.026, 1.0))
	var cx := s.x * 0.5
	var y := s.y * 0.5 - 210.0
	_t(Gt.w("零压拆船厂 · 公测版", "ZERO PRESSURE · PUBLIC TEST"), Vector2(cx, y), 34, Color(1, 1, 1, 0.95), font_b)
	y += 44.0
	_t(Gt.w("第一小时 · 需要联网 · %s", "THE FIRST HOUR · ONLINE · %s") % Gt.VERSION, Vector2(cx, y), 15, Color(1, 1, 1, 0.5), font)
	y += 46.0
	var lines: Array = []
	if not Gt.CODES:
		lines.append(Gt.w("有问题随时按 Esc，在菜单里点“反馈”告诉我们。", "Anything wrong? Press Esc and pick Feedback at any time."))
	elif state == "code" or state == "busy" or state == "refused":
		lines = [Gt.w("请输入你拿到的激活码。一个码只能在一台电脑上用。", "Enter the code you were given. A code works on one computer only.")]
	lines.append(Gt.w("这个试玩版会在你自己的电脑上记录你卡住、出事故的地方并截图；", "This build records, on your own computer, where you get stuck or have accidents, with screenshots;"))
	lines.append(Gt.w("结束时会问你要不要上传，不同意就只留在本机。设置里可以关掉记录。", "at the end it asks whether to upload them; say no and they stay here. The settings can turn it off."))
	for l in lines:
		_t(str(l), Vector2(cx, y), 15, Color(1, 1, 1, 0.72), font)
		y += 24.0
	if msg != "":
		var col := Color(1.0, 0.55, 0.35, 0.95) if state in ["refused", "expired", "offline"] else Color(1, 1, 1, 0.85)
		if state == "closed":
			_t(msg, Vector2(cx, s.y * 0.5 + 10.0), 28, Color(1, 1, 1, 0.95), font_b)
			return
		_t(msg, Vector2(cx, s.y * 0.5 + 10.0), 17, col, font_b)


func _t(text: String, at: Vector2, size: int, col: Color, f: Font) -> void:
	var wdt := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(at.x - wdt * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
