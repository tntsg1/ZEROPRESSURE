extends CanvasLayer
# 公测版的反馈面板 (user 2026-11-08 Q4 A): "反馈" in the pause menu, at any time. A big-letter page —
# what happened in a box of several lines, a kind to pick (卡住了 / 有 bug / 建议 / 其他), Enter sends,
# Esc goes back. With it go the frame from before the menu came up (a JPG of 300 KB at most), the log's
# tail, the version, the time played, the chapter and the ship, and this machine's fingerprint. It goes
# up to the Worker's /feedback (server/playtest/worker.mjs); sent or not, the page says which, and what
# didn't go up waits in OUTBOX and goes up on the next start (demo_gate.gd → flush).
# The look follows the console rules (console_kit.gd): words 20 and up, one orange main key on Enter.

const Gt = preload("res://scripts/demo.gd")
const Kit = preload("res://scripts/console_kit.gd")

const OUTBOX := "user://playtest_feedback_outbox"
const MAX_TEXT := 2000
const MAX_SHOT := 300 * 1024
const LOG := "user://logs/godot.log"
const LOG_TAIL := 12000
const KINDS := [["stuck", "卡住了", "STUCK"], ["bug", "有 bug", "A BUG"], ["idea", "建议", "AN IDEA"], ["other", "其他", "OTHER"]]

static var shot: Image = null          # the frame before the pause menu came up (game.toggle_menu)
static var fail_in_tests := false      # tests: the send fails as if offline
static var url_override := ""          # tests: another address
static var outbox := OUTBOX            # tests: a folder of their own (never the player's outbox)
static var last_flush := {}            # {"sent": n, "left": n} after the last flush

var game = null
var kind := "other"
var root: Control
var text_in: TextEdit
var count_l: Label
var note_l: Label
var send_b: Button
var back_b: Button
var kind_b := {}
var http: HTTPRequest
var busy := false
var result := ""                      # "" | sent | saved (tests read it)


# ---------------------------------------------------------------- what goes with it

static func grab(vp: Viewport) -> void:
	if vp == null or vp.get_texture() == null:
		return
	shot = vp.get_texture().get_image()


# the picture as a JPG no bigger than MAX_SHOT: smaller and plainer until it fits
static func jpg(img: Image) -> PackedByteArray:
	if img == null or img.is_empty():
		return PackedByteArray()
	var im := img.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGB8)
	if im.get_width() > 1600:
		im.resize(1600, int(round(im.get_height() * 1600.0 / im.get_width())), Image.INTERPOLATE_BILINEAR)
	for i in 8:
		for q in [0.8, 0.65, 0.5, 0.38]:
			var b := im.save_jpg_to_buffer(q)
			if b.size() <= MAX_SHOT and b.size() > 0:
				return b
		im.resize(maxi(64, im.get_width() * 3 / 4), maxi(36, im.get_height() * 3 / 4), Image.INTERPOLATE_BILINEAR)
	return PackedByteArray()


static func log_tail() -> String:
	var f := FileAccess.open(LOG, FileAccess.READ)
	if f == null:
		return ""
	var n := f.get_length()
	f.seek(maxi(0, n - LOG_TAIL))
	var t := f.get_buffer(mini(n, LOG_TAIL)).get_string_from_utf8()
	f.close()
	return t


static func payload(g, k: String, text: String, img: Image) -> Dictionary:
	var ship := ""
	if g != null and is_instance_valid(g):
		ship = str(g.get("ship_id"))
		var sd = g.get("ship")
		if sd is Dictionary and str(sd.get("name", "")) != "":
			ship += " " + str(sd.get("name", ""))
	var b := jpg(img)
	return {
		"machine": Gt.machine(), "kind": k, "text": text.substr(0, MAX_TEXT), "version": Gt.VERSION,
		"played_s": float(Career.data.get("time", 0.0)) if not Career.data.is_empty() else 0.0,
		"chapter": Mainline.chapter() if not Career.data.is_empty() else "",
		"ship": ship.strip_edges(), "made_at": Time.get_datetime_string_from_system(true),
		"shot": Marshalls.raw_to_base64(b) if b.size() > 0 else "", "log": log_tail(),
	}


# one feedback up to the server: {"ok": true} or {"ok": false, "error": …}
static func post(host: Node, p: Dictionary) -> Dictionary:
	if fail_in_tests:
		await host.get_tree().process_frame
		return {"ok": false, "error": "offline"}
	var http := HTTPRequest.new()
	http.timeout = 25.0
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(http)
	var base := url_override if url_override != "" else Gt.URL
	var err := http.request(base + "/feedback", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(p))
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "offline"}
	var r: Array = await http.request_completed
	http.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "offline"}
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if not d is Dictionary:
		return {"ok": false, "error": "http_%d" % int(r[1])}
	return d


static func keep(p: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(outbox)
	var path := outbox.path_join("fb_%d_%d.json" % [int(Time.get_unix_time_from_system()), randi() % 100000])
	if SaveGame.forbidden(path):
		return ""
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(p))
	f.close()
	return path


static func waiting() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(outbox):
		return out
	for f in DirAccess.get_files_at(outbox):
		if f.ends_with(".json"):
			out.append(outbox.path_join(f))
	out.sort()
	return out


# on a start that got through: what waits goes up, oldest first; it stops at the first one that doesn't
static func flush(tree: SceneTree) -> void:
	var files := waiting()
	if files.is_empty():
		last_flush = {"sent": 0, "left": 0}
		return
	var host := Node.new()
	host.name = "DemoFeedbackFlush"
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(host)
	await tree.process_frame
	var sent := 0
	for path in files:
		var p = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not p is Dictionary:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		p.machine = Gt.machine()
		var d: Dictionary = await post(host, p)
		var e := str(d.get("error", ""))
		if d.get("ok", false) or e in ["empty", "too_long", "invalid_shot", "shot_too_large", "too_large"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			sent += 1 if d.get("ok", false) else 0
		else:
			break
	last_flush = {"sent": sent, "left": waiting().size()}
	print("feedback outbox: %d sent, %d left" % [sent, int(last_flush.left)])
	host.queue_free()


# ---------------------------------------------------------------- the page

func _init(g = null) -> void:
	game = g


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game != null:
		game.set_meta("feedback_open", true)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(func(): root.draw_rect(Rect2(Vector2.ZERO, root.get_viewport_rect().size), Color(Charcoal.BG, 0.92)))
	add_child(root)
	var pane := PanelContainer.new()
	# 2026-11-11 炭黑 v2: a charcoal plate; the kinds as choice keys with their lamps; the words in a black window
	pane.add_theme_stylebox_override("panel", Charcoal.side_box(30.0))
	pane.custom_minimum_size = Vector2(980, 0)
	pane.set_anchors_preset(Control.PRESET_CENTER)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(pane)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	pane.add_child(col)
	col.add_child(Kit.header(Gt.w("反馈", "FEEDBACK"), Gt.VERSION))
	col.add_child(Kit.text(Gt.w("遇到了什么？卡住、出错、想法都可以写。会自动附上打开菜单前的画面截图和运行日志。",
		"What happened? Stuck, broken, an idea: anything. A picture of the moment before the menu and the log go with it."), 20, 0.78))
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 12)
	col.add_child(krow)
	var grp := ButtonGroup.new()
	for k in KINDS:
		var b := Button.new()
		b.text = str(k[1]) if Txt.zh else str(k[2])
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 50)
		b.add_theme_font_size_override("font_size", 20)
		# the picked kind: lamp lit and the orange lip (the orange fill stays the send key's alone)
		var kk := str(k[0])
		Charcoal.style_choice(b, func(): return kind == kk)
		b.pressed.connect(_pick.bind(str(k[0])))
		krow.add_child(b)
		kind_b[str(k[0])] = b
	kind_b["other"].button_pressed = true
	text_in = TextEdit.new()
	text_in.custom_minimum_size = Vector2(0, 280)
	text_in.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_in.placeholder_text = Gt.w("写在这里……（Shift+Enter 换行）", "Write here… (Shift+Enter for a new line)")
	text_in.add_theme_font_size_override("font_size", 22)
	var tb := Charcoal.well_box(18.0)
	text_in.add_theme_stylebox_override("normal", tb)
	var tf := tb.duplicate()
	tf.border_width_bottom = 2
	tf.border_color = Charcoal.ACCENT
	text_in.add_theme_stylebox_override("focus", tf)
	text_in.text_changed.connect(_typed)
	col.add_child(text_in)
	count_l = Kit.text("0 / %d" % MAX_TEXT, 16, 0.45)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(count_l)
	note_l = Kit.text("", 20, 0.9)
	col.add_child(note_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	send_b = Button.new()
	send_b.text = Gt.w("发送（Enter）", "SEND (Enter)")
	send_b.custom_minimum_size = Vector2(300, 58)
	send_b.focus_mode = Control.FOCUS_NONE
	send_b.pressed.connect(send)
	Kit.orange(send_b)
	row.add_child(send_b)
	back_b = Kit.key(Gt.w("取消（Esc）", "CANCEL (Esc)"), close, 20)
	back_b.custom_minimum_size = Vector2(220, 58)
	Charcoal.style_button(back_b)
	back_b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_b.focus_mode = Control.FOCUS_NONE
	row.add_child(back_b)
	text_in.grab_focus.call_deferred()


func _exit_tree() -> void:
	if game != null and is_instance_valid(game):
		game.remove_meta("feedback_open")


func _pick(k: String) -> void:
	kind = k
	for b in kind_b.values():
		b.queue_redraw()


func _typed() -> void:
	if text_in.text.length() > MAX_TEXT:
		text_in.text = text_in.text.substr(0, MAX_TEXT)
		text_in.set_caret_line(text_in.get_line_count() - 1)
		text_in.set_caret_column(text_in.get_line(text_in.get_line_count() - 1).length())
	count_l.text = "%d / %d" % [text_in.text.length(), MAX_TEXT]


func _input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	if ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	elif ev.keycode in [KEY_ENTER, KEY_KP_ENTER] and not ev.shift_pressed:
		get_viewport().set_input_as_handled()
		send()


func close() -> void:
	if busy:
		return
	queue_free()


func send() -> void:
	if busy:
		return
	if result != "":
		close()
		return
	var words := text_in.text.strip_edges()
	if words == "":
		note_l.text = Gt.w("先写几句再发送。", "Write a few words first.")
		note_l.add_theme_color_override("font_color", Pal.heat(0.9, 1.0))
		return
	busy = true
	send_b.disabled = true
	back_b.disabled = true
	note_l.remove_theme_color_override("font_color")
	note_l.text = Gt.w("正在发送……", "Sending…")
	var p := payload(game, kind, words, shot)
	var d: Dictionary = await post(self, p)
	busy = false
	back_b.disabled = false
	send_b.disabled = false
	if d.get("ok", false):
		result = "sent"
		note_l.add_theme_color_override("font_color", Pal.ink(0.97))
		note_l.text = Gt.w("已发送，谢谢！按 Enter 或 Esc 回到菜单。", "Sent. Thank you! Enter or Esc goes back.")
		send_b.text = Gt.w("好的（Enter）", "OK (Enter)")
		text_in.editable = false
		shot = null
		get_tree().create_timer(2.5, true, false, true).timeout.connect(func(): if is_instance_valid(self): close())
	else:
		var e := str(d.get("error", ""))
		var why := Gt.w("连不上服务器", "can't reach the server")
		if e == "rate":
			why = Gt.w("发得太快了，每分钟最多 3 条", "too fast: 3 a minute at most")
		elif e != "offline":
			why = e
		keep(p)
		result = "saved"
		note_l.add_theme_color_override("font_color", Pal.heat(0.9, 1.0))
		note_l.text = Gt.w("没发出去（%s）。已经存在本机，下次启动游戏会自动补发。" % why, "Not sent (%s). It's kept on this computer and goes up on the next start." % why)
		send_b.text = Gt.w("好的（Enter）", "OK (Enter)")
		text_in.editable = false
