class_name Playtest
extends Node
# 108 号 (user 2026-10-29, Q16–Q19 "按你说的做"; "最好是实时的……自动截个屏，把它当前的状态列出来"):
# the playtest recorder. Off unless the settings switch is on or the game is started with
# --playtest; it writes only to the player's own folder (user://playtest/<start time>/), never to
# the net. The person playing sees nothing: the moment something worth a note happens — stuck on
# a step, help opened, the same thing refused again and again, an accident, a step far over its
# time, F7 pressed ("I don't get this here") — it takes a screenshot there and then and writes
# what the game was doing beside it; the report (report.html) is rewritten after every entry, so
# it can be opened while the game goes on. Milestones (first cut, first money, first repair,
# first method) go on the same timeline without a picture.
# The game's own code calls the static hooks (cut, incident, deny, help, hint); each is a no-op
# while the recorder is off.

const STUCK_1 := 20.0             # s on one guide step with no progress: the first note
const STUCK_2 := 40.0             # and the second
const STEP_EXPECT := 45.0         # s a guide step is expected to take; past twice that, a note
const DENY_N := 3                 # refusals …
const DENY_S := 10.0              # … inside this many seconds
const SAME_S := 30.0              # one kind of note (with its step) at most once in this time
const SHOT_W := 1280              # screenshots are scaled to this width
const NOTE_KEY := KEY_F7

static var I: Playtest = null     # the recorder, while it runs
static var force := false         # tests switch it on without the setting
static var root := "user://playtest"   # tests write to their own folder

var game = null                   # the running game (scripts/game.gd), when there is one
var dir := ""                     # user://playtest/<start>/
var entries: Array = []           # [{t, kind, title, why, shot, state}] in order
var t0 := 0
var actions: Array = []           # the last inputs: [t, text]
var hints: Array = []             # the last lines the game said: [t, text]
var denies: Array = []            # times of the last refusals
var last_deny := ""
var last_kind := {}               # kind|step -> t of its last note
var step_key := ""                # the guide step being watched
var step_since := 0.0
var step_flags := 0               # 1 stuck once, 2 stuck twice, 4 over time
var last_input := 0.0
var page_key := ""
var page_since := 0.0
var page_clicks := 0
var money_seen := INF
var repairs_seen := -1
var methods_seen := -1
var jobs_seen := -1
var firsts := {}
var poll_t := 0.0
var shots := 0
var shot_us := 0                  # the last screenshot's time on the main thread (tests read it)
var note_box: LineEdit = null
var note_layer: CanvasLayer = null
var note_shot := ""
var note_state := {}
var note_paused := false


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func wanted() -> bool:
	if force:
		return true
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--playtest":
			return true
	return Txt.playtest


# the game calls this when it starts (a reload starts a new game but keeps the same recorder)
static func attach(g) -> void:
	if not wanted():
		return
	if g != null and g.get("testing") == true and not force:
		return
	if I == null or not is_instance_valid(I):
		I = Playtest.new()
		I.name = "Playtest"
		g.get_tree().root.add_child.call_deferred(I)
	I.game = g


static func folder() -> String:
	return ProjectSettings.globalize_path(root)


func _init() -> void:
	t0 = Time.get_ticks_msec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	dir = "%s/%s" % [root, stamp]
	if not SaveGame.forbidden(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	_write()


func now() -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0


func _g():
	return game if game != null and is_instance_valid(game) else null


# ---------------------------------------------------------------- hooks the game calls

static func cut(separated: bool) -> void:
	if I != null and separated:
		I._first("cut", w("首次成功切割并分离部件", "FIRST SUCCESSFUL CUT AND PART SEPARATION"))
		I._progress()


static func incident(kind: String, detail: String) -> void:
	if I == null:
		return
	var bad := ["blowout", "fire", "arc", "burst", "blast", "prop_blast", "o2_fire", "tank_burst", "tank_rupture", "drone_lost", "mandatory_lost", "nuke", "collapse", "tear", "quench"]
	if kind in bad:
		I.note("accident", w("出事：%s", "ACCIDENT: %s") % (kind + (" " + detail if detail != "" else "")), "")


static func deny(why: String = "") -> void:
	if I == null:
		return
	var t := I.now()
	# the refusal's sound and its words come together: one refusal
	if not I.denies.is_empty() and t - float(I.denies[-1]) < 0.3:
		if why != "":
			I.last_deny = why
		return
	I.denies.append(t)
	if why != "":
		I.last_deny = why
	I.denies = I.denies.filter(func(x): return t - float(x) <= DENY_S)
	if I.denies.size() >= DENY_N:
		I.denies.clear()
		I.note("deny", w("10 秒内操作被系统拒绝 %d 次", "ACTION BLOCKED %d TIMES WITHIN 10 SECONDS") % DENY_N, "")


static func help(what: String) -> void:
	if I != null:
		I.note("help", w("玩家查看了帮助说明：%s", "PLAYER OPENED HELP SECTION: %s") % what, "")


static func hint(text: String) -> void:
	if I == null or text.strip_edges() == "":
		return
	if not I.hints.is_empty() and str(I.hints[-1][1]) == text:
		return
	I.hints.append([I.now(), text])
	while I.hints.size() > 5:
		I.hints.remove_at(0)


func _progress() -> void:
	step_since = now()
	step_flags &= ~3


func _first(key: String, title: String) -> void:
	if firsts.has(key):
		return
	firsts[key] = true
	_add({"t": now(), "kind": "milestone", "title": title, "why": "", "shot": "", "state": {}})


# ---------------------------------------------------------------- what the game is doing

# the guide on screen, as [name, step id, title, seconds on it]
func guide() -> Array:
	var g = _g()
	if g == null:
		return []
	for pair in [["prologue", w("序章", "PROLOGUE")], ["coach", w("第一艘船", "FIRST SHIP")], ["port_walk", w("港区导览", "PORT WALK")]]:
		var n = g.get(pair[0])
		if n != null and is_instance_valid(n) and not n.get("done"):
			var title := ""
			for lab in [n.get("title"), n.get("body")]:
				if lab is Label and lab.text != "":
					title += ("  " if title != "" else "") + lab.text
			return [pair[1], str(n.get("step")), title, float(n.get("step_t")) if n.get("step_t") != null else 0.0]
	var tu = g.get("tutorial")
	if tu != null and is_instance_valid(tu) and not tu.done:
		var st: Dictionary = tu.step()
		return [w("训练", "TRAINING"), "%d.%d" % [tu.lesson_i, tu.step_i], tu.text(st.get("text", "")) if st.has("text") else str(st.get("id", "")), float(tu.step_t)]
	var gd = g.get("guide")
	if gd != null and is_instance_valid(gd) and gd.active():
		var s: Dictionary = gd.step
		return [w("现场引导", "GUIDE"), "%s/%s" % [str(s.get("task", "")), str(s.get("n", ""))], "%s  %s" % [str(s.get("title", "")), str(s.get("text", ""))], -1.0]
	return []


func page() -> String:
	var g = _g()
	if g == null:
		return ""
	var ui = g.get("console_ui")
	if ui == null or not is_instance_valid(ui):
		return ""
	var sc = ui.get_script()
	var nm: String = sc.resource_path.get_file().get_basename() if sc != null else ui.get_class()
	var tab = ui.get("page")
	return nm + (" / %s" % str(tab) if tab != null else "")


func state() -> Dictionary:
	var g = _g()
	var s := {"time": _clock(now())}
	if not Career.data.is_empty():
		s["money"] = Pal.money(float(Career.data.get("money", 0.0)))
		s["jobs"] = Career.data.get("history", []).size()
	var gu := guide()
	if not gu.is_empty():
		s["guide"] = "%s · %s：%s" % [gu[0], gu[1], gu[2]]
		s["on_step"] = "%d s" % int(now() - step_since)
	if g != null:
		s["scene"] = "%s · %s" % [str(g.get("state")), str(g.get("ship_id"))]
		var p := page()
		if p != "":
			s["page"] = p
		if g.drone != null and is_instance_valid(g.drone):
			s["drone"] = "(%d, %d) m" % [int(g.drone.position.x / 32.0), int(g.drone.position.y / 32.0)]
		if g.tools != null and is_instance_valid(g.tools):
			s["tool"] = Txt.t("tool_%d" % int(g.tools.tool))
	s["actions"] = actions.map(func(a): return "%s  %s" % [_clock(float(a[0])), str(a[1])])
	s["hints"] = hints.map(func(a): return "%s  %s" % [_clock(float(a[0])), str(a[1])])
	return s


# the likely reason behind a note, from what the recorder has seen
func guess(kind: String) -> Array:
	var out: Array = []
	var t := now()
	if t - last_input > 15.0:
		out.append(w("玩家已超过 15 秒没有操作，可能正在阅读说明，或不清楚下一步该做什么。", "NO PLAYER INPUT FOR OVER 15 SECONDS. PLAYER MAY BE READING INSTRUCTIONS OR UNSURE WHAT TO DO NEXT."))
	if last_deny != "" and not denies.is_empty():
		out.append(w("最近一次被系统拒绝的操作：%s", "MOST RECENT BLOCKED ACTION: %s") % last_deny)
	elif kind == "deny" and last_deny != "":
		out.append(w("玩家多次尝试同一项无效操作：%s，可能尚未理解操作限制。", "PLAYER REPEATEDLY ATTEMPTED THE SAME BLOCKED ACTION: %s. POSSIBLE CONFUSION ABOUT ACTION RESTRICTIONS.") % last_deny)
	if page_key != "" and t - page_since > 20.0 and page_clicks == 0:
		out.append(w("玩家在“%s”页面停留了 %d 秒，期间没有点击操作，可能未找到需要的功能或看不懂页面内容。", "On %s for %d s without a click: the page may be unclear") % [page_key, int(t - page_since)])
	var helps := entries.filter(func(e): return e.kind == "help" and t - float(e.t) < 60.0).size()
	if helps >= 2:
		out.append(w("玩家在一分钟内打开了 %d 次帮助说明，可能需要更明确的操作引导。", "PLAYER OPENED HELP %d TIMES WITHIN ONE MINUTE. ADDITIONAL GUIDANCE MAY BE NEEDED.") % helps)
	var g = _g()
	if g != null and g.get("console_ui") == null and kind == "stuck":
		var gd = g.get("guide")
		if gd != null and is_instance_valid(gd) and gd.active():
			out.append(w("当前引导任务仍未完成，请检查目标是否清晰可见，以及引导箭头是否指向了屏幕外。", "CURRENT TUTORIAL OBJECTIVE REMAINS INCOMPLETE. CHECK WHETHER THE TARGET IS VISIBLE AND IF THE GUIDANCE ARROW POINTS OFF-SCREEN."))
	return out


# ---------------------------------------------------------------- the notes

func note(kind: String, title: String, why: String) -> void:
	var key := kind + "|" + step_key
	var t := now()
	# stuck and slow are held to once a step by their own flags; the rest to once in SAME_S
	if kind in ["deny", "help", "accident"] and t - float(last_kind.get(key, -INF)) < SAME_S:
		return
	last_kind[key] = t
	var reasons := guess(kind)
	if why != "":
		reasons.push_front(why)
	_add({"t": t, "kind": kind, "title": title, "why": reasons, "shot": _shoot(), "state": state()})


func _add(e: Dictionary) -> void:
	entries.append(e)
	_write()


# the picture now. With the RenderingDevice the frame is read back asynchronously (the main thread
# only asks for it) and scaled, converted and written on a worker; otherwise read back at once
func _shoot() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var t_us := Time.get_ticks_usec()
	var tex := get_viewport().get_texture()
	if tex == null:
		return ""
	shots += 1
	var file := "shot_%03d.jpg" % shots
	var path := dir + "/" + file
	var rd := RenderingServer.get_rendering_device()
	var rid := RenderingServer.texture_get_rd_texture(tex.get_rid()) if rd != null else RID()
	if rd != null and rid.is_valid():
		var fmt: RDTextureFormat = rd.texture_get_format(rid)
		var w_px := fmt.width
		var h_px := fmt.height
		var half := fmt.format == RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		var rgba8 := fmt.format in [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]
		if half or rgba8:
			rd.texture_get_data_async(rid, 0, func(data: PackedByteArray):
				var img := Image.create_from_data(w_px, h_px, false, Image.FORMAT_RGBAH if half else Image.FORMAT_RGBA8, data)
				WorkerThreadPool.add_task(_save_shot.bind(img, path)))
			shot_us = Time.get_ticks_usec() - t_us
			return file
	var img := tex.get_image()
	if img == null or img.is_empty():
		return ""
	WorkerThreadPool.add_task(_save_shot.bind(img, path))
	shot_us = Time.get_ticks_usec() - t_us
	return file


static func _save_shot(img: Image, path: String) -> void:
	var h := int(round(float(img.get_height()) * SHOT_W / float(img.get_width())))
	img.resize(SHOT_W, h, Image.INTERPOLATE_BILINEAR)
	var out := _srgb8(img)
	if SaveGame.forbidden(path):
		return
	out.save_jpg(path, 0.85)


static var _lut := PackedByteArray()


# the root buffer is linear half-float (hdr_2d): each half straight to an sRGB byte through a
# table, so the darks keep their steps (tests/cap.gd does the same for the test shots)
static func _srgb8(img: Image) -> Image:
	if img.get_format() != Image.FORMAT_RGBAH:
		img.convert(Image.FORMAT_RGBA8)
		return img
	if _lut.is_empty():
		var lut := PackedByteArray()
		lut.resize(65536)
		for hv in 65536:
			var e := (hv >> 10) & 31
			var m := hv & 1023
			var v: float
			if e == 0:
				v = m / 1024.0 / 16384.0
			elif e == 31:
				v = 65504.0
			else:
				v = (1.0 + m / 1024.0) * pow(2.0, e - 15)
			if hv & 0x8000:
				v = 0.0
			var c := clampf(v, 0.0, 1.0)
			var s := c * 12.92 if c < 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055
			lut[hv] = int(clampf(s, 0.0, 1.0) * 255.0 + 0.5)
		_lut = lut
	var src := img.get_data()
	var n := src.size() / 8
	var dst := PackedByteArray()
	dst.resize(n * 3)
	var o := 0
	var d := 0
	for i in n:
		dst[d] = _lut[src.decode_u16(o)]
		dst[d + 1] = _lut[src.decode_u16(o + 2)]
		dst[d + 2] = _lut[src.decode_u16(o + 4)]
		o += 8
		d += 3
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, dst)


# ---------------------------------------------------------------- watching

func _input(ev: InputEvent) -> void:
	if note_box != null:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		last_input = now()
		if ev.keycode == NOTE_KEY:
			_open_note()
			get_viewport().set_input_as_handled()
			return
		_act(OS.get_keycode_string(ev.get_keycode_with_modifiers()))
	elif ev is InputEventMouseButton and ev.pressed:
		last_input = now()
		if ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
		var c := get_viewport().gui_get_hovered_control()
		var what := ""
		if c != null:
			what = str(c.get("text")) if c.get("text") != null and str(c.get("text")) != "" else str(c.name)
		page_clicks += 1
		_act(w("点击 %s", "click %s") % (what if what != "" else w("画面", "the view")) + ("" if ev.button_index == MOUSE_BUTTON_LEFT else w("（右键）", " (right)")))
	elif ev is InputEventMouseMotion:
		if ev.relative.length() > 2.0:
			last_input = now()


func _act(text: String) -> void:
	if not actions.is_empty() and str(actions[-1][1]) == text and now() - float(actions[-1][0]) < 0.6:
		return
	actions.append([now(), text])
	while actions.size() > 10:
		actions.remove_at(0)


func _process(dt: float) -> void:
	poll_t -= dt
	if poll_t > 0.0:
		return
	poll_t = 0.25
	var t := now()
	# the guide step: stuck at 20 s and 40 s, over time at twice its expected length
	var gu := guide()
	var key := "" if gu.is_empty() else "%s|%s" % [gu[0], gu[1]]
	if key != step_key:
		step_key = key
		step_since = t
		step_flags = 0
	if key != "":
		var on := t - step_since
		if on >= STUCK_1 and not step_flags & 1:
			step_flags |= 1
			note("stuck", w("“%s”第 %s 步已经 20 秒没进展", "NO PROGRESS FOR 20 s: %s, STEP %s") % [gu[0], gu[1]], "")
		if on >= STUCK_2 and not step_flags & 2:
			step_flags |= 2
			note("stuck", w("“%s”第 %s 步已经 40 秒没进展", "NO PROGRESS FOR 40 s: %s, STEP %s") % [gu[0], gu[1]], "")
		if on >= STEP_EXPECT * 2.0 and not step_flags & 4:
			step_flags |= 4
			note("slow", w("“%s”第 %s 步耗时超过预估的两倍（%d 秒）", "%s, STEP %s: OVER 2× ESTIMATED TIME (%d s)") % [gu[0], gu[1], int(on)], "")
	var p := page()
	if p != page_key:
		page_key = p
		page_since = t
		page_clicks = 0
	if Career.data.is_empty():
		return
	# money, repairs, methods, settled jobs: the milestones and the money going under
	var money := float(Career.data.get("money", 0.0))
	if money_seen != INF and money > money_seen + 0.5:
		_first("money", w("第一笔收入：+%s", "FIRST EARNINGS: +%s") % Pal.money(money - money_seen))
		_progress()
	if money < 0.0 and money_seen >= 0.0 and money_seen != INF:
		note("accident", w("余额已为负数：%s", "NEGATIVE BALANCE: %s") % Pal.money(money), "")
	money_seen = money
	var reps := 0
	for it in Repair.ITEMS:
		if Repair.done(str(it[0])):
			reps += 1
	if repairs_seen >= 0 and reps > repairs_seen:
		_first("repair", w("第一处设施修好了", "FIRST REPAIR FINISHED"))
		_progress()
	repairs_seen = reps
	var meth: int = Career.data.get("methods", {}).size()
	if methods_seen >= 0 and meth > methods_seen:
		_first("method", w("学会了第一种拆法", "LEARNED A NEW WAY TO DISMANTLE"))
	methods_seen = meth
	var jobs: int = Career.data.get("history", []).size()
	if jobs_seen >= 0 and jobs > jobs_seen:
		var last: Dictionary = Career.data.history[-1] if Career.data.history[-1] is Dictionary else {}
		_add({"t": t, "kind": "milestone", "title": w("第 %d 单结算完了：%s", "JOB %d SETTLED: %s") % [jobs, str(last.get("ship", ""))], "why": "", "shot": "", "state": {}})
		_progress()
	jobs_seen = jobs


# ---------------------------------------------------------------- F7: the player's own note

func _open_note() -> void:
	note_shot = _shoot()
	note_state = state()
	note_paused = get_tree().paused
	get_tree().paused = true
	note_layer = CanvasLayer.new()
	note_layer.layer = 128
	note_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(note_layer)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.position = Vector2((get_viewport().get_visible_rect().size.x - 720.0) * 0.5, 120.0)
	note_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var lab := Label.new()
	lab.text = w("有什么没看懂的？写一句就行，也可以不写。Enter 保存，Esc 取消", "Something confusing here? Leave a note if you want. Enter to save, Esc to cancel.")
	box.add_child(lab)
	note_box = LineEdit.new()
	note_box.custom_minimum_size = Vector2(700, 40)
	note_box.text_submitted.connect(func(s): _close_note(true, s))
	note_box.gui_input.connect(func(e):
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_close_note(false, "")
			get_viewport().set_input_as_handled())
	box.add_child(note_box)
	note_box.grab_focus.call_deferred()


func _close_note(keep: bool, text: String) -> void:
	if note_layer == null:
		return
	note_layer.queue_free()
	note_layer = null
	note_box = null
	get_tree().paused = note_paused
	if keep:
		_add({"t": now(), "kind": "own", "title": w("玩家标记：这里没看懂", "PLAYER NOTE: I DIDN'T GET THIS"), "why": [text] if text.strip_edges() != "" else [], "shot": note_shot, "state": note_state})


# ---------------------------------------------------------------- the report

static func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


const KIND_NAME := {"stuck": ["卡住", "STUCK"], "slow": ["超时", "SLOW STEP"], "deny": ["反复被拒", "REFUSED"], "help": ["查说明", "HELP"],
	"accident": ["出事", "ACCIDENT"], "own": ["试玩者标记", "PLAYER NOTE"], "milestone": ["里程碑", "MILESTONE"]}
const ROW_NAME := {"time": ["开局多久", "Time in"], "money": ["钱", "Money"], "jobs": ["已结单数", "Jobs settled"], "guide": ["当前引导", "Guide"],
	"on_step": ["这一步已用", "On this step"], "scene": ["场景", "Scene"], "page": ["打开的页", "Page open"], "drone": ["无人机位置", "Drone"], "tool": ["工具", "Tool"]}


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


func _write() -> void:
	if SaveGame.forbidden(dir + "/entries.json"):
		return
	var f := FileAccess.open(dir + "/entries.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries, "  "))
		f.close()
	var counts := {}
	for e in entries:
		counts[e.kind] = int(counts.get(e.kind, 0)) + 1
	var h := PackedStringArray()
	h.append("<!doctype html><html lang=\"zh\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>%s</title>" % w("零压试玩记录", "ZERO PRESSURE playtest"))
	h.append("<meta http-equiv=\"refresh\" content=\"10\">")
	h.append("<style>body{background:#0d0f10;color:#d8dcdc;font:14px/1.5 system-ui,'Microsoft YaHei',sans-serif;margin:0;padding:24px;max-width:1340px}h1{font-weight:500;margin:0 0 6px}.sum{color:#8a9292;margin-bottom:22px}.e{border-left:3px solid #3a4242;padding:6px 0 14px 16px;margin:0 0 10px}.e.stuck,.e.slow{border-color:#e0a030}.e.deny{border-color:#d06040}.e.accident{border-color:#e04040}.e.help{border-color:#40a0d0}.e.own{border-color:#c060e0}.e.milestone{border-color:#50b070;padding-bottom:4px}.t{color:#8a9292;font-variant-numeric:tabular-nums;margin-right:10px}.k{font-size:12px;padding:1px 6px;border:1px solid #3a4242;margin-right:8px}.ti{font-size:16px}.why{color:#f0c060;margin:4px 0}img{max-width:100%;border:1px solid #2a3030;margin:6px 0;display:block}table{border-collapse:collapse;margin:4px 0}td{padding:1px 12px 1px 0;vertical-align:top}td:first-child{color:#8a9292;white-space:nowrap}ol{margin:2px 0;padding-left:20px;color:#b0b8b8}</style></head><body>")
	h.append("<h1>%s</h1>" % w("零压拆船厂 · 试玩记录", "ZERO PRESSURE · PLAYTEST"))
	var parts := PackedStringArray()
	for k in KIND_NAME:
		if counts.has(k):
			parts.append("%s %d" % [KIND_NAME[k][0 if Txt.zh else 1], counts[k]])
	h.append("<div class=\"sum\">%s %s · %s · %s</div>" % [w("开始于", "Started"), dir.get_file(), w("已记 %d 条", "%d entries") % entries.size(), " · ".join(parts)])
	for e in entries:
		var kn: Array = KIND_NAME.get(e.kind, [e.kind, e.kind])
		h.append("<div class=\"e %s\"><span class=\"t\">%s</span><span class=\"k\">%s</span><span class=\"ti\">%s</span>" % [e.kind, _clock(float(e.t)), kn[0 if Txt.zh else 1], _esc(str(e.title))])
		if e.why is Array:
			for r in e.why:
				h.append("<div class=\"why\">→ %s</div>" % _esc(str(r)))
		if str(e.shot) != "":
			h.append("<img src=\"%s\" loading=\"lazy\">" % e.shot)
		var st: Dictionary = e.state
		if not st.is_empty():
			h.append("<table>")
			for k in ROW_NAME:
				if st.has(k):
					h.append("<tr><td>%s</td><td>%s</td></tr>" % [ROW_NAME[k][0 if Txt.zh else 1], _esc(str(st[k]))])
			for pair in [["actions", w("最近的操作", "Last inputs")], ["hints", w("最近的提示", "Last hints")]]:
				var arr: Array = st.get(pair[0], [])
				if not arr.is_empty():
					h.append("<tr><td>%s</td><td><ol>%s</ol></td></tr>" % [pair[1], "".join(arr.map(func(a): return "<li>%s</li>" % _esc(str(a))))])
			h.append("</table>")
		h.append("</div>")
	h.append("</body></html>")
	if SaveGame.forbidden(dir + "/report.html"):
		return
	var r := FileAccess.open(dir + "/report.html", FileAccess.WRITE)
	if r != null:
		r.store_string("\n".join(h))
		r.close()
