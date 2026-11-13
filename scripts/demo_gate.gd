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
var net_log: Array = []      # one line per failed try: host + what went wrong (shown on the offline page)
var try_n := 0


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
	http.timeout = Gt.net_timeout
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
	if state == "offline":
		var p := _offline_plan(s)
		box.position = Vector2(s.x * 0.5 - 210.0, p.buttons_y)
	else:
		box.position = Vector2(s.x * 0.5 - 210.0, s.y * 0.5 + 40.0)
	box.size = Vector2(420, 120)


# the offline page: heading, error line, the steps (wrapped to the window), then the buttons; the whole
# block is centred and starts no higher than the top edge, so a small window still shows all of it
func _offline_plan(s: Vector2) -> Dictionary:
	var wd := minf(s.x - 48.0, 760.0)
	var steps := steps_text()
	var detail := detail_text()
	var sh := font.get_multiline_string_size(steps, HORIZONTAL_ALIGNMENT_LEFT, wd, 16).y + 8.0
	var dh := font.get_multiline_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, wd, 15).y + 8.0
	var total := 44.0 + 40.0 + 34.0 + sh + 14.0 + dh + 16.0 + 48.0
	var top := maxf(20.0, (s.y - total) * 0.5)
	return {"top": top, "wd": wd, "steps": steps, "detail": detail, "sh": sh, "dh": dh, "buttons_y": top + total - 48.0}


func _show(st: String, m: String) -> void:
	state = st
	msg = m
	code_in.visible = Gt.CODES and (st == "code" or st == "busy" or st == "refused")
	go_b.visible = code_in.visible or (not Gt.CODES and st in ["offline", "refused"])
	go_b.disabled = st == "busy"
	_layout()
	if code_in.visible:
		code_in.grab_focus()
	queue_redraw()


# one request, with a timeout, up to Gt.net_tries rounds (main address, then the fallback), a longer pause
# before each round; every failed try is kept in net_log. Only network failures retry: a reply from the
# server (even "closed") is returned at once.
func _post(path: String, body: Dictionary) -> Dictionary:
	net_log.clear()
	try_n = 0
	var urls: Array = [Gt.base_url]
	if Gt.fallback_url != "" and Gt.fallback_url != Gt.base_url:
		urls.append(Gt.fallback_url)
	http.timeout = Gt.net_timeout
	for round in Gt.net_tries:
		if round > 0:
			await get_tree().create_timer(float(Gt.net_waits[mini(round - 1, Gt.net_waits.size() - 1)])).timeout
		for u in urls:
			try_n += 1
			_progress()
			var res := await _once(str(u) + path, body)
			if res.has("reply"):
				return res.reply
			net_log.append("%s: %s (%d)" % [Gt.host_of(str(u)), Gt.net_kind(int(res.kind)), int(res.code)])
	return {"ok": false, "error": "offline"}


func _once(url: String, body: Dictionary) -> Dictionary:
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {"kind": -2, "code": err}
	var r: Array = await http.request_completed
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"kind": int(r[0]), "code": int(r[0])}
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if d is Dictionary:
		return {"reply": d}
	return {"kind": -1, "code": int(r[1])}


func _progress() -> void:
	if state in ["checking", "busy"]:
		msg = Gt.w("正在联网登记……（第 %d 次）", "Checking in… (try %d)") % try_n
		queue_redraw()


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


func steps_text() -> String:
	return "
".join([
		Gt.w("【占位】请依次试试（第一次启动必须联网登记）：", "[PLACEHOLDER] Please try these in order (the first start must check in online):"),
		Gt.w("【占位】① 关掉 VPN / 加速器，再回到这里", "[PLACEHOLDER] 1. Turn off any VPN or accelerator"),
		Gt.w("② 按 Win+R，输入 cmd 回车，运行：ipconfig /flushdns", "2. Press Win+R, type cmd, Enter, then run: ipconfig /flushdns"),
		Gt.w("③ 检查 hosts 文件里有没有 stellarascensiongame.com 的条目，有就删掉", "3. Check the hosts file for a stellarascensiongame.com entry and remove it"),
		Gt.w("④ 点“重试”（或按 Enter）。还不行，请截图这个页面发给我们", "4. Press Retry (or Enter). Still no luck? Send us a screenshot of this page"),
	])


func detail_text() -> String:
	var parts: Array = []
	for l in net_log:
		parts.append(str(l))
	return Gt.w("【占位】错误详情：", "[PLACEHOLDER] Details: ") + Gt.w("；", "; ").join(parts)


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
	if state == "offline":
		_draw_offline(s)
		return
	var y := s.y * 0.5 - 210.0
	_t(Gt.w("零压拆船厂 · 公测版", "ZERO PRESSURE · PUBLIC TEST"), Vector2(cx, y), 34, Color(1, 1, 1, 0.95), font_b)
	y += 44.0
	_t(Gt.w("公测版 · 需要联网 · %s", "PUBLIC TEST · ONLINE · %s") % Gt.VERSION, Vector2(cx, y), 15, Color(1, 1, 1, 0.5), font)
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


func _draw_offline(s: Vector2) -> void:
	var p := _offline_plan(s)
	var cx := s.x * 0.5
	var y: float = p.top + 30.0
	_t(Gt.w("零压拆船厂 · 公测版", "ZERO PRESSURE · PUBLIC TEST"), Vector2(cx, y), 30, Color(1, 1, 1, 0.95), font_b)
	y += 34.0
	_t(Gt.w("公测版 · 需要联网 · %s", "PUBLIC TEST · ONLINE · %s") % Gt.VERSION, Vector2(cx, y), 14, Color(1, 1, 1, 0.5), font)
	y += 40.0
	_t(msg, Vector2(cx, y), 18, Color(1.0, 0.55, 0.35, 0.95), font_b)
	y += 14.0
	var x: float = cx - p.wd * 0.5
	draw_multiline_string(font, Vector2(x, y + 16.0), p.steps, HORIZONTAL_ALIGNMENT_LEFT, p.wd, 16, -1, Color(1, 1, 1, 0.85))
	y += p.sh + 14.0
	draw_multiline_string(font, Vector2(x, y + 15.0), p.detail, HORIZONTAL_ALIGNMENT_LEFT, p.wd, 15, -1, Color(1, 1, 1, 0.5))
