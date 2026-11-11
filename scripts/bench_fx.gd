class_name BenchFx
# 工作台通用动效（2026-11-04，用户：“其他的工作台界面不做成极其完美丝滑流畅的吗”；问答 Q1 C：
# 先做一套通用组件，所有面板换上后自动拥有，再给重点面板加专属动效）。水准对齐星图
# （scripts/star_map.gd）。全部用 Tween 或着色器，不每帧重建控件、不重画宽线。
# “减少动效”打开（或动画强度关闭）时，BenchFx.on() 为假：一切即时切换，只留颜色变化。
#
# 用法（面板 _ready 的最后）：
#   BenchFx.dress(self, [行所在的容器…], 滑入的节点)     入场 + 所有按钮的聚光/浮起/点击光
#   BenchFx.primary(按钮)                                 主操作缓慢呼吸
#   var f := BenchFx.fold(内容)  f.set_open(true)         展开折叠，下面的内容被平滑推开
#   BenchFx.Roll                                           自绘数字/条的滚动
#   BenchFx.roll_label(label, 值, 格式)                    Label 上的数字滚动
#   BenchFx.say(label, 文字)                               提示条滑入，倒计时线缩完后滑走
#   BenchFx.tab_line(页签按钮们, 当前序号的 Callable)       页签下划线带光晕滑过去
#   BenchFx.swap(内容)                                     页签内容推入
#   close() 里：if BenchFx.leave(self): …                 退场（反向）
#
# Motion Prompt #154 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#154
# Motion Prompt #081 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#081
# Motion Prompt #052 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#052
# Motion Prompt #057 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#057
# Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
# Motion Prompt #005 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#005
# Motion Prompt #056 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#056

const Fx := preload("res://scripts/star_map_fx.gd")

# ---------------------------------------------------------------- timings (秒) and curves
const ENTER_SLIDE := 70.0       # 面板从侧边滑入的距离
const ENTER_S := 0.55           # 滑入，五次缓出（quint out）
const ENTER_FADE_S := 0.35      # 淡入
const ROW_DELAY := 0.12         # 第一行开始错落出现
const ROW_STEP := 0.045         # 每行再晚这么多（总共不超过 ROW_MAX）
const ROW_MAX := 0.5
const ROW_RISE := 16.0          # 每行从下方升起的距离
const ROW_S := 0.5              # 每行升起，五次缓出；淡入 0.35 秒三次缓出
const LEAVE_S := 0.22           # 退场：三次缓入淡出，同时向侧边滑出 50 px
const LIFT := 3.0               # #081 悬停浮起（原版 10 px 对 128 px 卡片；这里的按钮 40–70 px 高）
const HOVER_K := 14.0           # 悬停过渡的阻尼：约 0.3 秒到位，等效三次缓出（#081 0.3 s）
const FOLD_OPEN_S := 0.35       # #052 展开 0.35 秒 easeInOutCubic
const FOLD_CLOSE_S := 0.32      # #052 收起 0.32 秒
const TAB_S := 0.25             # #057 下划线 0.25 秒 easeInOutCubic
const SWAP_S := 0.2             # #057 新内容 0.2 秒淡入并升起 8 px
const ROLL_S := 0.7             # #007 数字滚动：值 = 目标·(1 − (1 − p)^4)（原版 2.45 秒，界面里缩短）
const TOAST_IN := 0.35          # #056 提示条滑入 240 px，三次缓出
const TOAST_OUT := 0.35         # #056 滑走，easeInOutCubic
const NOTE_S := 0.4             # 人性化 规则 4：悬停 0.4 秒出白话说明


static var shot_mouse := Vector2.INF    # 截图专用：假指针位置（绝不移动真实鼠标）


static func on() -> bool:
	return UiSkin.motion()


# recording (--write-movie renders frame by frame, slower than real time): the clock is the frames
# drawn at the movie's rate, so the motion in the film runs at its true speed
static var _movie := -1
static var _movie_fps := 30.0


static func now() -> float:
	if _movie < 0:
		var args := OS.get_cmdline_args()
		_movie = 1 if "--write-movie" in args else 0
		var i := args.find("--fixed-fps")
		if i >= 0 and i + 1 < args.size():
			_movie_fps = maxf(1.0, float(args[i + 1]))
	if _movie == 1:
		return Engine.get_process_frames() / _movie_fps
	return Time.get_ticks_msec() / 1000.0


static func e_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func e_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func e_out4(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 4.0)


static func e_out5(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 5.0)


static func _sfx(panel: Node, name: String, vol := 1.0) -> void:
	var g = panel.get("game") if panel != null else null
	if g != null and is_instance_valid(g) and g.get("sfx") != null:
		g.sfx.play(name, Vector2.INF, vol)


# ---------------------------------------------------------------- Shift: a drawn offset that survives the container
# 容器每次排版都会把子节点放回原位；Shift 记住各路偏移（入场升起、悬停浮起、提示条滑动），
# 排版之后重新加上，所以偏移不会被排版吃掉，也不会把节点留在错位置。

class Shift extends RefCounted:
	var c: Control
	var offs := {}
	var base := Vector2.ZERO
	var set_pos := Vector2.INF
	var hooked: Container = null

	func _init(ctrl: Control) -> void:
		c = ctrl
		base = ctrl.position
		var p := ctrl.get_parent()
		if p is Container:
			hooked = p
			hooked.sort_children.connect(_resorted)

	func _resorted() -> void:
		if not is_instance_valid(c):
			return
		base = c.position
		set_pos = Vector2.INF
		apply()

	func put(key: String, v: Vector2) -> void:
		if v.length_squared() < 0.0001:
			offs.erase(key)
		else:
			offs[key] = v
		apply()

	func apply() -> void:
		if not is_instance_valid(c):
			return
		if set_pos.is_finite() and not c.position.is_equal_approx(set_pos):
			base = c.position      # something else moved it (a resize, a re-anchor): that is the new rest
		var tot := Vector2.ZERO
		for v in offs.values():
			tot += v
		c.position = base + tot
		set_pos = c.position


static func shift(c: Control) -> Shift:
	if not c.has_meta("bfx_shift"):
		c.set_meta("bfx_shift", Shift.new(c))
	return c.get_meta("bfx_shift")


static func offset(c: Control, key: String, v: Vector2) -> void:
	if not is_instance_valid(c):
		return
	if v.length_squared() < 0.0001 and not c.has_meta("bfx_shift"):
		return
	shift(c).put(key, v)


# ---------------------------------------------------------------- hover lift styles (#081)
# 普通态到悬停态的颜色平滑过渡（6 档缓存），悬停时阴影从无到 16 px、下移 6 px（原版模糊 6→22、
# 偏移 2→12、不透明度 0.08→0.22；暗色界面上阴影要更浓：0→0.45）

static var _lift_boxes := {}


static func lift_box(n: StyleBox, h: StyleBox, q: float) -> StyleBox:
	var step := int(round(clampf(q, 0.0, 1.0) * 6.0))
	if step == 0:
		return n
	if step == 6 and not (h is StyleBoxFlat):
		return h
	if not (n is StyleBoxFlat) or not (h is StyleBoxFlat):
		return h
	var key := "%d/%d/%d" % [n.get_instance_id(), h.get_instance_id(), step]
	if _lift_boxes.has(key):
		return _lift_boxes[key]
	var k := step / 6.0
	var a: StyleBoxFlat = n
	var b: StyleBoxFlat = h
	var o := b.duplicate() as StyleBoxFlat
	o.bg_color = a.bg_color.lerp(b.bg_color, k)
	o.border_color = a.border_color.lerp(b.border_color, k)
	for side in ["left", "right", "top", "bottom"]:
		o.set("content_margin_" + side, a.get("content_margin_" + side))
	o.shadow_color = Color(0, 0, 0, 0.45 * k).lerp(b.shadow_color, 0.3 if b.shadow_size > 0 else 0.0)
	o.shadow_size = maxi(b.shadow_size, int(round(16.0 * k)))
	o.shadow_offset = Vector2(0, 6.0 * k)
	_lift_boxes[key] = o
	return o


# ---------------------------------------------------------------- the rig: one per open panel

class Rig extends Node:
	var panel: Control
	var slide: Control
	var side := 1.0
	var boxes: Array = []
	var t_start := 0.0
	var entries: Array = []        # Btn
	var rises: Array = []
	var _seen := {}
	var _left := false
	var key := ""                  # 人性化 规则 3: remembered under Career.data.bench_ui[key]
	var layers: Array = []         # 规则 1: the page's own back steps, [is_open: Callable, close: Callable]
	var _saved := false
	var _note: PanelContainer
	var _note_l: Label
	var _note_b: Button = null
	var _note_t := 0.0

	func _ready() -> void:
		if t_start <= 0.0:
			t_start = BenchFx.now()
		if not get_tree().node_added.is_connected(_added):
			get_tree().node_added.connect(_added)
		for b in panel.find_children("*", "BaseButton", true, false):
			_track(b)

	func _exit_tree() -> void:
		save_state()
		if get_tree() != null and get_tree().node_added.is_connected(_added):
			get_tree().node_added.disconnect(_added)

	# ---- 规则 1: Esc steps back one layer at a time; only the outermost closes the page
	func _input(ev: InputEvent) -> void:
		if _left or not ev is InputEventKey or not ev.pressed or ev.echo:
			return
		if ev.physical_keycode == KEY_ESCAPE and back():
			get_viewport().set_input_as_handled()

	func back() -> bool:
		for i in range(layers.size() - 1, -1, -1):
			var l: Array = layers[i]
			if l[0].is_valid() and bool(l[0].call()):
				l[1].call()
				return true
		var best: Fold = null
		for f in panel.find_children("Fold_*", "Container", true, false):
			if f is Fold and f.open and f.is_visible_in_tree() and (best == null or f.opened_at > best.opened_at):
				best = f
		if best != null:
			best.set_open(false)
			return true
		return false

	# ---- 规则 6: Enter presses the page's one action (labelled on it)
	func _unhandled_input(ev: InputEvent) -> void:
		if _left or not ev is InputEventKey or not ev.pressed or ev.echo:
			return
		if ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			for e in entries:
				if e.primary and is_instance_valid(e.b) and e.b.is_visible_in_tree() and not e.b.disabled:
					e.press_t = BenchFx.now()
					e.press_at = e.b.size * 0.5
					e.b.pressed.emit()
					get_viewport().set_input_as_handled()
					return

	# ---- 规则 3: what the page looked like, kept with the save
	func save_state() -> void:
		if _saved or key == "" or not is_instance_valid(panel) or Career.data.is_empty():
			return
		_saved = true
		# by their order on the page (the nodes' own names are made up afresh each time it is built)
		var st := {"scroll": [], "folds": []}
		for sc in panel.find_children("*", "ScrollContainer", true, false):
			st.scroll.append(sc.scroll_vertical)
		for f in panel.find_children("Fold_*", "Container", true, false):
			if f is Fold:
				st.folds.append(f.open)
		if panel.has_method("bench_state"):
			st["own"] = panel.bench_state()
		var all: Dictionary = Career.data.get("bench_ui", {})
		all[key] = st
		Career.data["bench_ui"] = all

	func restore_state() -> void:
		var st: Dictionary = BenchFx.state_of(key)
		if st.is_empty():
			return
		if panel.has_method("bench_restore") and st.has("own"):
			panel.bench_restore(st.own)
		var folds: Array = st.get("folds", []) if st.get("folds", []) is Array else []
		var i := 0
		for f in panel.find_children("Fold_*", "Container", true, false):
			if f is Fold:
				if i < folds.size():
					f.snap_open(bool(folds[i]))
				i += 1
		# the scroll once the page has its height
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return
		var sv: Array = st.get("scroll", []) if st.get("scroll", []) is Array else []
		i = 0
		for sc in panel.find_children("*", "ScrollContainer", true, false):
			if i < sv.size():
				sc.scroll_vertical = int(sv[i])
			i += 1


	# ---- 规则 4: a plain note after 0.4 s on a key; a shut key says why
	func _show_note(b: Button, text: String) -> void:
		if _note == null:
			_note = PanelContainer.new()
			_note.name = "BfxNote"
			_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_note.set_meta("bfx_skip", true)
			var box := UiSkin.solid(Color(0.06, 0.07, 0.08, 0.97), 8, 0.0)
			box.content_margin_left = 12
			box.content_margin_right = 12
			box.content_margin_top = 8
			box.content_margin_bottom = 8
			box.border_color = Color(1, 1, 1, 0.12)
			box.set_border_width_all(1)
			box.shadow_color = Color(0, 0, 0, 0.5)
			box.shadow_size = 12
			_note.add_theme_stylebox_override("panel", box)
			_note_l = Label.new()
			_note_l.add_theme_font_size_override("font_size", 14)
			_note_l.add_theme_color_override("font_color", Pal.ink(0.92))
			_note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_note.add_child(_note_l)
			panel.add_child(_note)
		_note_l.text = text
		var w := minf(380.0, Fonts.get_font("Regular").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 4.0)
		_note_l.custom_minimum_size.x = w
		_note.reset_size()
		var inv := panel.get_global_transform().affine_inverse()
		var r := b.get_global_rect()
		var ps: Vector2 = panel.size
		var at: Vector2 = inv * Vector2(r.position.x, r.end.y + 8.0)
		var sz := _note.get_combined_minimum_size()
		if at.y + sz.y > ps.y - 8.0:
			at = inv * Vector2(r.position.x, r.position.y - 8.0) - Vector2(0, sz.y)
		at.x = clampf(at.x, 8.0, ps.x - sz.x - 8.0)
		_note.position = at
		_note.move_to_front()
		if not _note.visible or _note.modulate.a < 0.01:
			_note.visible = true
			if BenchFx.on():
				_note.modulate.a = 0.0
				_note.create_tween().tween_property(_note, "modulate:a", 1.0, 0.12)
			else:
				_note.modulate.a = 1.0

	func _notes(dt: float) -> void:
		var over: Button = null
		for e in entries:
			if is_instance_valid(e.b) and e.over():
				over = e.b
		if over != _note_b:
			_note_b = over
			_note_t = 0.0
			if _note != null:
				_note.visible = false
		if over == null:
			return
		_note_t += dt
		if _note_t >= BenchFx.NOTE_S:
			var why := str(over.get_meta("bfx_why", ""))
			var tx := why if over.disabled and why != "" else str(over.get_meta("bfx_note", ""))
			if tx != "":
				_show_note(over, tx)
			elif _note != null:
				_note.visible = false

	func age() -> float:
		return BenchFx.now() - t_start

	func _added(n: Node) -> void:
		if _left or not n is BaseButton or not is_instance_valid(panel) or not panel.is_ancestor_of(n):
			return
		_track.call_deferred(n)

	func _track(b: BaseButton) -> void:
		if not is_instance_valid(b) or _seen.has(b.get_instance_id()) or b.has_meta("bfx_skip") or not b is Button:
			return
		_seen[b.get_instance_id()] = true
		entries.append(Btn.new(b, self))

	func _process(dt: float) -> void:
		var keep: Array = []
		var mo := BenchFx.on()
		var t := BenchFx.now()
		for e in entries:
			if not is_instance_valid(e.b) or e.b.is_queued_for_deletion():
				continue
			keep.append(e)
			e.tick(dt, t, mo)
		entries = keep
		if not _left:
			_notes(dt)

	# the rows fade up and rise one after another, in the order they sit on the screen
	func enter_rows(rows: Array) -> void:
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return
		var live: Array = rows.filter(func(r): return is_instance_valid(r) and r.is_visible_in_tree())
		live.sort_custom(func(a, b): return a.global_position.y < b.global_position.y - 1.0 or (absf(a.global_position.y - b.global_position.y) <= 1.0 and a.global_position.x < b.global_position.x))
		var t0 := BenchFx.now()
		for i in live.size():
			var r: Control = live[i]
			var delay := minf(BenchFx.ROW_DELAY + i * BenchFx.ROW_STEP, BenchFx.ROW_MAX)
			var tw := r.create_tween().set_parallel(true)
			tw.tween_property(r, "modulate:a", 1.0, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(v: float): BenchFx.offset(r, "enter", Vector2(0, v)), BenchFx.ROW_RISE, 0.0, BenchFx.ROW_S).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			for e in entries:
				if is_instance_valid(e.b) and (e.b == r or r.is_ancestor_of(e.b)):
					e.born = t0 + delay
		# the titles rise from behind their line with the rows (#005)
		for rt in rises:
			if is_instance_valid(rt):
				rt.start(t0 + clampf(rt.global_position.y / 1080.0, 0.0, 1.0) * 0.4 + 0.05)


# one button's light and lift
class Btn extends RefCounted:
	var b: Button
	var rig
	var rect: ColorRect = null    # made the first time it has something to show (keeps the opening frame light)
	var q := 0.0                 # hover, eased
	var primary := false
	var press_t := -9.0
	var press_at := Vector2.ZERO
	var born := -9.0
	var n0: StyleBox             # its own normal / hover boxes, as the page set them
	var h0: StyleBox
	var had_n := false
	var had_h := false
	var set_n: StyleBox = null
	var was_hover := false

	func _init(btn: Button, r) -> void:
		b = btn
		rig = r
		primary = bool(b.get_meta("bfx_primary", false))
		_capture()
		b.button_down.connect(func():
			press_t = BenchFx.now()
			press_at = (BenchFx.shot_mouse - b.global_position) if BenchFx.shot_mouse.is_finite() else b.get_local_mouse_position()
			BenchFx._sfx(rig.panel, "bench_click", 0.6))

	func _make_rect() -> void:
		rect = ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.material = BenchFx.Fx.material("sheen")
		rect.set_meta("bfx_skip", true)
		b.add_child(rect)

	func lit() -> bool:
		return rect != null and rect.visible

	func _capture() -> void:
		had_n = b.has_theme_stylebox_override("normal")
		had_h = b.has_theme_stylebox_override("hover")
		n0 = b.get_theme_stylebox("normal")
		h0 = b.get_theme_stylebox("hover")

	var _why: Label = null

	# the pointer on it, shut or not (for the note)
	func over() -> bool:
		if not b.is_visible_in_tree():
			return false
		if BenchFx.shot_mouse.is_finite():
			return b.get_global_rect().has_point(BenchFx.shot_mouse)
		return b.get_global_rect().has_point(b.get_global_mouse_position()) and (b.disabled or b.is_hovered())

	# 规则 4 / 6: a shut key says why on it; the page's action carries its key; both at its right end when
	# there is room beside the label (else the why is in the note only)
	func _tags() -> void:
		var why := str(b.get_meta("bfx_why", "")) if b.disabled else ""
		var key_on: bool = primary and not b.disabled
		var tag := why if why != "" else ("Enter" if key_on else "")
		if tag == "":
			if _why != null:
				_why.visible = false
			return
		var f := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var text_w := 0.0
		for line in b.text.split("\n"):
			text_w = maxf(text_w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var tw := Fonts.get_font("Regular").get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4.0
		var room := b.size.x - text_w - 40.0
		if b.alignment == HORIZONTAL_ALIGNMENT_CENTER:
			room = (b.size.x - text_w) * 0.5 - 22.0
		if room < tw:
			if why == "":
				# the page's action always shows its key: it widens to make room (once)
				var want := text_w + (2.0 * tw + 50.0 if b.alignment == HORIZONTAL_ALIGNMENT_CENTER else tw + 64.0)
				if b.custom_minimum_size.x < want:
					b.custom_minimum_size.x = want
			if _why != null:
				_why.visible = false
			return
		if _why == null:

			_why = Label.new()
			_why.name = "BfxTag"
			_why.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_why.set_meta("bfx_skip", true)
			_why.add_theme_font_size_override("font_size", 12)
			_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(_why)
		_why.text = tag
		_why.add_theme_color_override("font_color", UiSkin.ACCENT.lightened(0.2) if why != "" else Pal.ink(0.5))
		_why.visible = true
		_why.position = Vector2(b.size.x - tw - 14.0, 0)
		_why.size = Vector2(tw, b.size.y)

	func hovered() -> bool:
		if b.disabled or not b.is_visible_in_tree():
			return false
		if BenchFx.shot_mouse.is_finite():
			return b.get_global_rect().has_point(BenchFx.shot_mouse)
		return b.is_hovered()

	var _tag_sig := ""

	func tick(dt: float, t: float, mo: bool) -> void:
		if not b.is_visible_in_tree():
			return
		# 规则 4: the page's tooltips become the plain notes (one look for every key, 0.4 s)
		if b.tooltip_text != "":
			b.set_meta("bfx_note", b.tooltip_text)
			b.tooltip_text = ""
		var sig := "%s|%s|%s|%s|%s" % [b.disabled, primary, b.get_meta("bfx_why", ""), b.size, b.text]
		if sig != _tag_sig:
			_tag_sig = sig
			_tags()
		# the page re-styled it (a tab chosen, an accent set): those are its new rest boxes
		var cur := b.get_theme_stylebox("normal")
		if cur != set_n and cur != n0:
			_capture()
			set_n = null
		var hv := hovered()
		if hv and not was_hover:
			BenchFx._sfx(rig.panel, "bench_hover", 0.35)
		was_hover = hv
		# 2026-11-11 用户选定 A+B: a key KeyFx moves (scripts/ui_kit/key_fx.gd) has no lift and no pointer
		# light of its own here (they would double); the main key's slow breathing stays
		if b.has_meta("kfx"):
			if q != 0.0 or set_n != null:
				q = 0.0
				_style(0.0)
				BenchFx.offset(b, "lift", Vector2.ZERO)
			hv = false
			press_t = -9.0
		if not mo:
			if q != 0.0 or set_n != null:
				q = 0.0
				_style(0.0)
				BenchFx.offset(b, "lift", Vector2.ZERO)
			if rect != null:
				rect.visible = false
			return
		var goal := 1.0 if hv else 0.0
		var nq := lerpf(q, goal, 1.0 - exp(-BenchFx.HOVER_K * dt))
		if absf(nq - goal) < 0.004:
			nq = goal
		var down := 1.5 if b.is_pressed() and not b.toggle_mode and hv else 0.0
		if nq != q or down != 0.0 or b.has_meta("bfx_shift"):
			q = nq
			_style(q)
			BenchFx.offset(b, "lift", Vector2(0, -BenchFx.LIFT * q + down))
		# the light: only while it has something to show (the rest of the time it costs nothing)
		var press_age := t - press_t
		var born_age := t - born
		var show := hv or press_age < 0.45 or (primary and not b.disabled) or (born_age > -0.05 and born_age < 0.9)
		if not show:
			if rect != null:
				rect.visible = false
			return
		if rect == null:
			_make_rect()
		rect.visible = true
		var m: ShaderMaterial = rect.material
		var lm := (BenchFx.shot_mouse - b.global_position) if BenchFx.shot_mouse.is_finite() else b.get_local_mouse_position()
		m.set_shader_parameter("size", b.size)
		m.set_shader_parameter("mouse", lm if hv else Vector2(-9999, -9999))
		m.set_shader_parameter("amt", 0.22 if primary else 0.35)
		m.set_shader_parameter("press", press_age)
		m.set_shader_parameter("press_at", press_at)
		m.set_shader_parameter("breathe", 2.5 if primary and not b.disabled else 0.0)   # brighter than the star map: the band is busy
		m.set_shader_parameter("born", born_age if born_age > -0.05 else 9.0)
		m.set_shader_parameter("t", t)

	func _style(k: float) -> void:
		if k <= 0.0:
			if set_n != null:
				if had_n:
					b.add_theme_stylebox_override("normal", n0)
				else:
					b.remove_theme_stylebox_override("normal")
				if had_h:
					b.add_theme_stylebox_override("hover", h0)
				else:
					b.remove_theme_stylebox_override("hover")
				set_n = null
			return
		var box := BenchFx.lift_box(n0, h0, k)
		if box == set_n:
			return
		set_n = box
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)


# the panel comes in: the slide node from the side as the panel fades up, the rows one by one.
# boxes: the containers whose children are the rows; slide: the node that slides (anchored)
static func dress(panel: Control, boxes: Array = [], slide: Control = null, side := 1.0, key := "", enter := true) -> Rig:
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return null
	if panel.has_meta("bfx_rig"):
		return panel.get_meta("bfx_rig")
	var rig := Rig.new()
	rig.name = "BenchFx"
	rig.panel = panel
	rig.slide = slide
	rig.side = side
	rig.boxes = boxes
	rig.key = key if key != "" else (panel.get_script().resource_path.get_file().get_basename() if panel.get_script() != null else "")
	panel.set_meta("bfx_rig", rig)
	panel.add_child(rig)
	_sfx(panel, "bench_open")
	apply_scale(panel)
	rig.restore_state()
	if not on() or not enter:
		return rig
	if slide != null:
		var l0 := slide.offset_left
		var r0 := slide.offset_right
		slide.offset_left = l0 + ENTER_SLIDE * side
		slide.offset_right = r0 + ENTER_SLIDE * side
		var tw := slide.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		tw.tween_property(slide, "offset_left", l0, ENTER_S)
		tw.tween_property(slide, "offset_right", r0, ENTER_S)
	# the page's ground is there from the first frame (no ghost of the scene or the HUD through it);
	# what slides in fades up
	var fade: Control = slide if slide != null else panel
	fade.modulate.a = 0.0
	fade.create_tween().tween_property(fade, "modulate:a", 1.0, ENTER_FADE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var rows: Array = []
	for bx in boxes:
		if bx == null:
			continue
		for c in bx.get_children():
			if c is Control and c.visible and not c.has_meta("bfx_skip"):
				c.modulate.a = 0.0
				rows.append(c)
	rig.enter_rows(rows)
	return rig


# 人性化 规则 5: the console at the interface scale of the settings (90–130 %): it lays out in a smaller
# (or larger) space and is drawn scaled to the screen, so every part, type and drawing grows together
static func apply_scale(panel: Control) -> void:
	var s := clampf(Txt.ui_scale, 0.9, 1.3)
	if absf(s - 1.0) < 0.001 or not panel.is_inside_tree():
		return
	var fit := func():
		if not is_instance_valid(panel):
			return
		var vp := panel.get_viewport_rect().size
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.position = Vector2.ZERO
		panel.size = vp / s
		panel.scale = Vector2(s, s)
	fit.call()
	panel.get_viewport().size_changed.connect(fit)


# what a page looked like when it was last closed (Career.data.bench_ui; travels with the save)
static func state_of(key: String) -> Dictionary:
	if key == "" or Career.data.is_empty():
		return {}
	return Career.data.get("bench_ui", {}).get(key, {})


# a back step of the page's own (a sub-page, a picked item): Esc undoes it before the page closes
static func back_step(panel: Node, is_open: Callable, close: Callable) -> void:
	var rig := rig_of(panel)
	if rig != null:
		rig.layers.append([is_open, close])


# a plain note for a key (shown after 0.4 s on it) and, while it is shut, why and how to open it
static func note(b: Control, text: String, why := "") -> void:
	b.set_meta("bfx_note", text)
	b.set_meta("bfx_why", why)


# the same plain note, drawn straight onto a hand-drawn page (the terminal) near the pointer
static func draw_note(ci: CanvasItem, text: String, at: Vector2, bounds: Vector2) -> void:
	var f := Fonts.get_font("Regular")
	var w := minf(380.0, f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 2.0)
	var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, 14).y
	var r := Rect2(at + Vector2(16, 22), Vector2(w + 24, h + 16))
	if r.end.x > bounds.x - 8.0:
		r.position.x = bounds.x - 8.0 - r.size.x
	if r.end.y > bounds.y - 8.0:
		r.position.y = at.y - 12.0 - r.size.y
	var box := UiSkin.solid(Color(0.06, 0.07, 0.08, 0.97), 8, 0.0)
	box.border_color = Color(1, 1, 1, 0.12)
	box.set_border_width_all(1)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	ci.draw_style_box(box, r)
	ci.draw_multiline_string(f, r.position + Vector2(12, 8 + 14), text, HORIZONTAL_ALIGNMENT_LEFT, w, 14, -1, Pal.ink(0.92))


static func rig_of(n: Node) -> Rig:

	while n != null:
		if n.has_meta("bfx_rig"):
			return n.get_meta("bfx_rig")
		n = n.get_parent()
	return null


static func leaving(panel: Node) -> bool:
	return panel.has_meta("bfx_left")


# the panel goes out the way it came: it fades and slides back to the side. The page closes at once
# (the game carries on, another console may open); only its picture lingers 0.22 s on a layer of its
# own, deaf to input. Returns true when the panel was handed over (the caller must not free it).
static func leave(panel: Control) -> bool:
	panel.set_meta("bfx_left", true)
	var rig := rig_of(panel)
	_sfx(panel, "bench_close")
	if rig != null:
		rig.save_state()
	if not on() or not panel.is_inside_tree():
		return false
	if rig != null:
		rig._left = true
		if rig._note != null:
			rig._note.visible = false
	var host := CanvasLayer.new()
	var src := panel.get_parent()
	host.layer = src.layer + 1 if src is CanvasLayer else 60
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.get_tree().root.add_child(host)
	panel.reparent(host, false)
	panel.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	panel.propagate_call("set_process", [false])
	panel.propagate_call("set_process_input", [false])
	panel.propagate_call("set_process_unhandled_input", [false])
	panel.propagate_call("set_process_unhandled_key_input", [false])
	panel.propagate_call("set_process_shortcut_input", [false])
	# 2026-11-10 (user: "电网调度和仓库按不了"): the next page usually pauses the tree as it opens
	# (the terminal does); a scene tween stops with it, so the leaving picture froze at full strength
	# on its own layer above that page, deaf to input — it must run its 0.22 s to the end regardless
	var tw := panel.get_tree().create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "modulate:a", 0.0, LEAVE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var slide: Control = rig.slide if rig != null else null
	if slide != null and is_instance_valid(slide):
		tw.tween_property(slide, "offset_left", slide.offset_left + 50.0 * rig.side, LEAVE_S).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tw.tween_property(slide, "offset_right", slide.offset_right + 50.0 * rig.side, LEAVE_S).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(host.queue_free)
	return true


# the page's one action breathes slowly (its edge glows and fades every 2.4 s)
static func primary(b: Button, on_ := true) -> void:
	b.set_meta("bfx_primary", on_)
	var rig := rig_of(b)
	if rig == null:
		return
	for e in rig.entries:
		if e.b == b:
			e.primary = on_
			return
	# not tracked yet (just built): once it is
	(func():
		for e in rig.entries:
			if e.b == b:
				e.primary = on_).call_deferred()


# ---------------------------------------------------------------- #052 fold: what is below is pushed down

class Fold extends Container:
	var content: Control
	var k := 1.0
	var open := true
	var on_step: Callable          # (k) each step, e.g. to scroll along
	var on_toggle: Callable        # (open) when it is opened or closed (by its key, by Esc, restored)
	var opened_at := 0.0
	var _tw: Tween

	func _init(c: Control) -> void:
		content = c
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = c.size_flags_horizontal

	func _get_minimum_size() -> Vector2:
		if content == null or not is_instance_valid(content):
			return Vector2.ZERO
		var m := content.get_combined_minimum_size()
		return Vector2(m.x, m.y * k)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN and content != null and is_instance_valid(content):
			fit_child_in_rect(content, Rect2(0, 0, size.x, content.get_combined_minimum_size().y))

	func _set_k(v: float) -> void:
		k = v
		content.modulate.a = clampf(v * 1.4 - 0.2, 0.0, 1.0)
		update_minimum_size()
		if on_step.is_valid():
			on_step.call(v)

	func snap_open(on: bool) -> void:
		open = on
		if _tw != null and _tw.is_valid():
			_tw.kill()
		content.visible = on
		k = 1.0 if on else 0.0
		content.modulate.a = 1.0 if on else 0.0
		update_minimum_size()
		if on:
			opened_at = BenchFx.now()
		if on_toggle.is_valid():
			on_toggle.call(on)

	func set_open(on: bool) -> void:
		open = on
		if on:
			opened_at = BenchFx.now()
		if on_toggle.is_valid():
			on_toggle.call(on)
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if on:
			content.visible = true
		if not BenchFx.on():
			_set_k(1.0 if on else 0.0)
			content.visible = on
			return
		_tw = create_tween()
		if on:
			_tw.tween_method(func(x: float): _set_k(BenchFx.e_io(x)), clampf(k, 0.0, 1.0), 1.0, BenchFx.FOLD_OPEN_S * (1.0 - k) + 0.001)
		else:
			_tw.tween_method(func(x: float): _set_k(BenchFx.e_io(x)), clampf(k, 0.0, 1.0), 0.0, BenchFx.FOLD_CLOSE_S * k + 0.001)
			_tw.tween_callback(func(): content.visible = false)


# wraps content where it stands; it keeps its own visible flag (true while open)
static func fold(content: Control) -> Fold:
	var p := content.get_parent()
	var idx := content.get_index()
	var f := Fold.new(content)
	f.name = "Fold_" + content.name
	p.remove_child(content)
	f.add_child(content)
	p.add_child(f)
	p.move_child(f, idx)
	f.open = content.visible
	f.k = 1.0 if content.visible else 0.0
	f.update_minimum_size()
	return f


# ---------------------------------------------------------------- #007 roll: a figure races up and settles

class Roll extends RefCounted:
	var from := 0.0
	var to := 0.0
	var t0 := -99.0
	var dur := BenchFx.ROLL_S

	func _init(start := 0.0) -> void:
		from = start
		to = start

	func go(v: float) -> void:
		if is_equal_approx(v, to):
			return
		from = value()
		to = v
		t0 = BenchFx.now()

	func snap(v: float) -> void:
		from = v
		to = v
		t0 = -99.0

	func value() -> float:
		if not BenchFx.on():
			return to
		var p := (BenchFx.now() - t0) / dur
		if p >= 1.0:
			return to
		return lerpf(from, to, BenchFx.e_out4(p))

	func busy() -> bool:
		return BenchFx.on() and BenchFx.now() - t0 < dur


# a figure on a label: rolled from what it shows to v, a short ice-blue glint as it lands
static func roll_label(l: Label, v: float, fmt: Callable) -> void:
	var r: Roll = l.get_meta("bfx_roll") if l.has_meta("bfx_roll") else null
	if r == null:
		r = Roll.new(0.0)
		l.set_meta("bfx_roll", r)
	if not on():
		r.snap(v)
		l.text = fmt.call(v)
		return
	if is_equal_approx(r.to, v) and l.text == fmt.call(v):
		return
	r.go(v)
	if l.has_meta("bfx_roll_tw"):
		var old: Tween = l.get_meta("bfx_roll_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := l.create_tween()
	l.set_meta("bfx_roll_tw", tw)
	tw.tween_method(func(_x: float): l.text = fmt.call(r.value()), 0.0, 1.0, ROLL_S)
	tw.tween_callback(func(): l.text = fmt.call(v))


# ---------------------------------------------------------------- #056 toast: a note slides in, its time runs out, it slides away

class TimeLine extends Control:
	var life := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("bfx_skip", true)
	func _draw() -> void:
		if life <= 0.0:
			return
		draw_rect(Rect2(0, size.y - 2.0, size.x * life, 2.0), Color(UiSkin.DATA, 0.8))


static func say(l: Label, text: String) -> void:
	l.text = text
	var line: TimeLine = l.get_meta("bfx_line") if l.has_meta("bfx_line") else null
	if line == null:
		line = TimeLine.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.add_child(line)
		l.set_meta("bfx_line", line)
	if l.has_meta("bfx_say_tw"):
		var old: Tween = l.get_meta("bfx_say_tw")
		if old != null and old.is_valid():
			old.kill()
	var hold := clampf(1.8 + 0.05 * text.length(), 1.8, 6.0)
	var tw := l.create_tween()
	l.set_meta("bfx_say_tw", tw)
	l.modulate.a = 1.0
	if text == "":
		offset(l, "toast", Vector2.ZERO)
		line.life = 0.0
		line.queue_redraw()
		tw.kill()
		return
	if on():
		tw.tween_method(func(x: float):
			offset(l, "toast", Vector2(240.0 * (1.0 - e_out(x)), 0))
			l.modulate.a = x, 0.0, 1.0, TOAST_IN)
	else:
		offset(l, "toast", Vector2.ZERO)
	tw.tween_method(func(x: float):
		line.life = 1.0 - x
		line.queue_redraw(), 0.0, 1.0, hold)
	if on():
		tw.tween_method(func(x: float):
			offset(l, "toast", Vector2(240.0 * e_io(x), 0))
			l.modulate.a = 1.0 - e_io(x), 0.0, 1.0, TOAST_OUT)
	else:
		tw.tween_callback(func(): l.modulate.a = 0.0)


# ---------------------------------------------------------------- #057 tabs

class TabInk extends Control:
	var tabs: Array = []
	var current: Callable
	var from_x := 0.0
	var from_w := 0.0
	var to_x := -1.0
	var to_w := 0.0
	var t0 := -9.0
	var last := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("bfx_skip", true)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _geom(i: int) -> Vector2:
		var tb: Control = tabs[i]
		var host: Control = tabs[0]
		return Vector2(tb.global_position.x - host.global_position.x, tb.size.x)

	func _draw() -> void:
		if tabs.is_empty() or not current.is_valid():
			return
		var i: int = clampi(int(current.call()), 0, tabs.size() - 1)
		var g := _geom(i)
		if last < 0 or not BenchFx.on():
			from_x = g.x
			from_w = g.y
			t0 = -9.0
		elif i != last:
			var p := BenchFx.e_io((BenchFx.now() - t0) / BenchFx.TAB_S)
			from_x = lerpf(from_x, to_x, p)
			from_w = lerpf(from_w, to_w, p)
			t0 = BenchFx.now()
		last = i
		to_x = g.x
		to_w = g.y
		var k := BenchFx.e_io((BenchFx.now() - t0) / BenchFx.TAB_S)
		var x := lerpf(from_x, to_x, k)
		var wd := lerpf(from_w, to_w, k)
		var y: float = (tabs[0] as Control).size.y + 1.0
		draw_texture_rect(UiSkin.glow_tex(), Rect2(x - 20.0, y - 10.0, wd + 40.0, 20.0), false, Color(UiSkin.ACCENT, 0.25))
		draw_rect(Rect2(x + 10.0, y - 1.0, wd - 20.0, 2.0), UiSkin.ACCENT)


# the chosen tab's line, glowing, slides across to it; current() gives the chosen index. The tabs keep
# their own look minus their underline (the line is this one now)
static func tab_line(tabs: Array, current: Callable) -> TabInk:
	var ink := TabInk.new()
	ink.tabs = tabs
	ink.current = current
	(tabs[0] as Control).add_child(ink)
	return ink


# new content comes in: it fades up over 0.2 s while rising 8 px (#057)
static func swap(content: Control) -> void:
	if not on() or content == null:
		return
	content.modulate.a = 0.0
	var tw := content.create_tween().set_parallel(true)
	tw.tween_property(content, "modulate:a", 1.0, SWAP_S).set_delay(0.1)
	tw.tween_method(func(v: float): offset(content, "swap", Vector2(0, v)), 8.0, 0.0, SWAP_S).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- #005 rise: words rise from behind a line
# 线 0.1–0.5 秒从中间长出（三次缓入缓出）；文字只在线的上方可见，0.35–1.0 秒从下方升到位（五次缓出），
# 不改不透明度，只靠裁剪；线在 2.05–2.3 秒缩掉。只在面板入场时播一次，之后就是静止的字。

class RiseText extends Control:
	var text := ""
	var font: Font
	var px := 24
	var col := Color(1, 1, 1)
	var t0 := -99.0
	var ink: Control
	var underline := true   # the orange stroke drawn under it as it comes in (2026-11-10: off where it read as a squiggle)

	func _init(s := "", f: Font = null, size_px := 24, c := Color(1, 1, 1)) -> void:
		text = s
		font = f
		px = size_px
		col = c
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("bfx_skip", true)
		ink = Control.new()
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ink.draw.connect(_ink)
		add_child(ink)
		set_process(false)

	func _ready() -> void:
		if BenchFx.on():
			var rig := BenchFx.rig_of(self)
			if rig == null or rig.age() < 0.3:
				t0 = 1e9          # held until the rig starts it
				_register.call_deferred()

	func _register() -> void:
		var rig := BenchFx.rig_of(self)
		if rig == null or rig.age() > 0.5:
			t0 = -99.0
			ink.queue_redraw()
			return
		rig.rises.append(self)

	func start(at: float) -> void:
		t0 = at
		set_process(true)

	func set_text(s: String) -> void:
		if s != text:
			text = s
			ink.queue_redraw()

	func _process(_dt: float) -> void:
		ink.queue_redraw()
		queue_redraw()
		if BenchFx.now() - t0 > 2.4:
			set_process(false)

	func _ink() -> void:
		var s := BenchFx.now() - t0
		var drop := 1.0 - BenchFx.e_out5((s - 0.35) / 0.65)
		if t0 > 1e8:
			drop = 1.0
		var base := size.y - 4.0
		ink.draw_string(font, Vector2(0, base + drop * (px * 1.2)), text, HORIZONTAL_ALIGNMENT_LEFT, size.x, px, col)
		var lk := BenchFx.e_io((s - 0.1) / 0.4) * (1.0 - BenchFx.e_io((s - 2.05) / 0.25))
		if lk > 0.0 and t0 < 1e8 and underline:
			var tw := minf(size.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
			ink.draw_rect(Rect2(tw * 0.5 * (1.0 - lk), size.y - 2.0, tw * lk, 1.5), Color(UiSkin.ACCENT, 0.9))


# a key that has just changed what it does: a light sweeps across it (the light it comes in with)
static func flash(b: Button) -> void:
	var rig := rig_of(b)
	if rig == null or not on():
		return
	for e in rig.entries:
		if e.b == b:
			e.born = now()


# the same, handing the key back (for keys built inline)
static func noted(b: Control, text: String, why := "") -> Control:
	note(b, text, why)
	return b
