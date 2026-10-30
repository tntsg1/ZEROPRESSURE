extends CanvasLayer
# The end of the playtest's first hour (scripts/demo.gd, Q7 C): the game stops, three questions are
# answered here and kept with the record, and the player chooses whether the record goes up to the
# server or stays on this computer (the folder opens so it can be sent by hand). Then the build quits.

const Gt = preload("res://scripts/demo.gd")

var root: Control
var liked: TextEdit
var lost: TextEdit
var score: HSlider
var score_l: Label
var note: Label
var up_b: Button
var keep_b: Button
var http: HTTPRequest
var font: Font
var font_b: Font


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	http = HTTPRequest.new()
	http.timeout = 120.0
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(_bg)
	add_child(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(640, 0)
	root.add_child(box)
	var s := root.get_viewport_rect().size
	box.position = Vector2(s.x * 0.5 - 320.0, s.y * 0.5 - 300.0)
	box.add_child(_label(Gt.w("试玩到这里就结束了，谢谢你！", "That's the end of the playtest. Thank you!"), 30, font_b, 1.0))
	box.add_child(_label(Gt.w("最后三个问题，答完就好（可以简短）：", "Three last questions (short answers are fine):"), 16, font, 0.7))
	box.add_child(_label(Gt.w("1. 哪一刻最喜欢？", "1. Which moment did you like most?"), 18, font_b, 0.9))
	liked = _text_box()
	box.add_child(liked)
	box.add_child(_label(Gt.w("2. 哪一刻最困惑、不知道该做什么？", "2. When were you most lost or unsure what to do?"), 18, font_b, 0.9))
	lost = _text_box()
	box.add_child(lost)
	box.add_child(_label(Gt.w("3. 给这一小时打几分（1–10）？", "3. How would you score this hour (1–10)?"), 18, font_b, 0.9))
	var srow := HBoxContainer.new()
	box.add_child(srow)
	score = HSlider.new()
	score.min_value = 1
	score.max_value = 10
	score.step = 1
	score.value = 7
	score.custom_minimum_size = Vector2(520, 32)
	srow.add_child(score)
	score_l = _label("7", 22, font_b, 1.0)
	srow.add_child(score_l)
	score.value_changed.connect(func(v): score_l.text = str(int(v)))
	box.add_child(_label(Gt.w("试玩记录（卡住的地方和截图）要上传给开发者吗？", "Send the playtest record (where you got stuck, with screenshots) to the developer?"), 16, font, 0.8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	up_b = _button(Gt.w("上传并退出", "UPLOAD AND QUIT"), _upload)
	row.add_child(up_b)
	keep_b = _button(Gt.w("不上传，打开记录文件夹", "DON'T UPLOAD: OPEN THE FOLDER"), _keep)
	row.add_child(keep_b)
	note = _label("", 16, font_b, 0.9)
	box.add_child(note)
	liked.grab_focus()


func _bg() -> void:
	root.draw_rect(Rect2(Vector2.ZERO, root.get_viewport_rect().size), Color(0.02, 0.022, 0.026, 0.94))


func _label(t: String, size: int, f: Font, a: float) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, a))
	return l


func _text_box() -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(640, 70)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.add_theme_font_override("font", font)
	t.add_theme_font_size_override("font_size", 16)
	return t


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b


# the answers beside the record, and the build marked done for this computer
func _save_answers() -> void:
	DirAccess.make_dir_recursive_absolute(Playtest.root)
	var f := FileAccess.open(Playtest.root.path_join("answers.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"liked": liked.text, "lost": lost.text, "score": int(score.value),
			"played_s": float(Career.data.get("time", 0.0)), "chapter": Mainline.chapter(),
			"code": Gt.code(), "lang": "zh" if Txt.zh else "en", "at": Time.get_datetime_string_from_system(),
		}, "  "))
		f.close()
	Gt.mark_finished()
	if Career.usable():
		Career.save()


func _upload() -> void:
	up_b.disabled = true
	keep_b.disabled = true
	_save_answers()
	note.text = Gt.w("正在上传……", "Uploading…")
	var bytes := Gt.zip_records()
	var url := "%s/report?code=%s&machine=%s" % [Gt.URL, Gt.code().uri_encode(), Gt.machine()]
	var err := http.request_raw(url, ["Content-Type: application/zip"], HTTPClient.METHOD_POST, bytes)
	var ok := false
	if err == OK:
		var r: Array = await http.request_completed
		ok = int(r[0]) == HTTPRequest.RESULT_SUCCESS and int(r[1]) == 200
	if ok:
		note.text = Gt.w("上传好了，谢谢！3 秒后退出。", "Uploaded. Thank you! Quitting in 3 seconds.")
		await get_tree().create_timer(3.0, true, false, true).timeout
		get_tree().quit()
	else:
		note.text = Gt.w("上传没成功。记录在打开的文件夹里，可以打包发给开发者。", "The upload failed. The record is in the folder that opened; zip it and send it over.")
		OS.shell_open(ProjectSettings.globalize_path(Playtest.root))
		keep_b.disabled = false
		keep_b.text = Gt.w("退出", "QUIT")
		keep_b.pressed.disconnect(_keep)
		keep_b.pressed.connect(func(): get_tree().quit())


func _keep() -> void:
	_save_answers()
	OS.shell_open(ProjectSettings.globalize_path(Playtest.root))
	note.text = Gt.w("记录在打开的文件夹里，打包发给开发者就好。谢谢！", "The record is in the folder that opened: zip it and send it over. Thank you!")
	up_b.disabled = true
	keep_b.text = Gt.w("退出", "QUIT")
	keep_b.pressed.disconnect(_keep)
	keep_b.pressed.connect(func(): get_tree().quit())
