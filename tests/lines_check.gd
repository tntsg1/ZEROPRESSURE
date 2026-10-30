extends SceneTree
# data/台词.txt (player 2026-10-25: all the lines in one TXT to edit at once). As exported it
# changes nothing; edited, every kind of line follows it; an empty line is not spoken; a beat
# written as _1, _2 is said in order. Reads a test copy, never touches the real file.
#   godot --headless --path . -s tests/lines_check.gd
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Txt.zh = true
	var json = JSON.parse_string(FileAccess.get_file_as_string("res://data/copy.json"))
	# 1. as exported: the same words as before
	_reload(Lines.FILE)
	var same := true
	for k in json:
		if str(k).begins_with("_") or str(json[k][0]) == "":
			continue
		if Copy.pair(str(k)).is_empty() or Copy.pair(str(k))[0] != str(json[k][0]):
			same = false
			print("  differs: ", k)
	check(same, "every written line of copy.json reads the same through the TXT")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://ships/ts1_course.json"))
	check(Ship.load_data("ts1_course").lines.T00_1.zh == raw.lines.T00_1.zh, "a TS-1 course line reads the same")
	var gr = JSON.parse_string(FileAccess.get_file_as_string("res://ships/gr7.json"))
	check(Ship.load_data("gr7").story.arrive[0][0] == gr.story.arrive[0][0], "the GR-7 story reads the same")
	check(Txt.t("ex_l1") == Txt.S["ex_l1"][0], "the exam line reads the same")
	# 2. edited
	var text := FileAccess.get_file_as_string(Lines.FILE)
	text = text.replace("中：七号坞以前可不是这副样子。", "中：（测试改过）七号坞以前可不是这副样子。")
	text = _put(text, "course.ts1_course.T00_1", "测试：通信正常。")
	text = _put(text, "story.gr7.arrive.0", "测试：真家伙来了。")
	text = _put(text, "txt.ex_l1", "测试：最后一个练习。")
	text = _put(text, "L_tug_done", "测试：拖船拆完了。")
	var f := FileAccess.open("user://zp_test_lines.txt", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_reload("user://zp_test_lines.txt")
	check(Copy.pair("L_berth_broken_1")[0].begins_with("（测试改过）"), "an edited growth line is what the game says")
	check(Ship.load_data("ts1_course").lines.T00_1.zh == "测试：通信正常。", "an edited course line")
	check(Ship.load_data("gr7").story.arrive[0][0] == "测试：真家伙来了。", "an edited story line")
	check(Txt.t("ex_l1") == "测试：最后一个练习。", "an edited exam line")
	check(Copy.has("L_tug_done"), "a line written into an empty slot is spoken")
	check(not Copy.has("L_bonus") and Copy.slot("R_reason_01") != "", "an empty slot stays silent (a card shows its placeholder or text)")
	# 3. a beat in parts, said in order
	var radio := Radio.new()
	check(Copy.say(radio, "L_berth_broken") and radio.queue.size() == 2, "L_berth_broken says _1 then _2 (%d queued)" % radio.queue.size())
	_reload(Lines.FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://zp_test_lines.txt"))
	print("LINES %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func _reload(p: String) -> void:
	Copy._loaded = false
	Copy._t = {}
	Ship._cache.clear()
	Txt.ov = {}
	Lines.path = p
	Lines.read_again()


func _put(text: String, id: String, zh: String) -> String:
	var at := text.find("[%s]" % id)
	if at < 0:
		print("  no id ", id)
		return text
	var z := text.find("中：", at)
	var e := text.find("\n", z)
	return text.substr(0, z) + "中：" + zh + text.substr(e)
