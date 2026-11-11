extends VBoxContainer
# 136 号 (user 2026-11-10: "想输入价格或者上下调价格都很难调啊"): a price you set, in the A-暗1 charcoal
# look (scripts/ui_kit/charcoal.gd). The figure in a black window — click it and type; it reads
# with thousands separators as you type; Enter submits, Esc only leaves the editing (the page
# under it stays). Big − / + keys step by a share of the reference price (held: they repeat and
# speed up; Shift: five steps at a time); the wheel over it steps it too (the list behind does
# not scroll); a row of quick stops fills a figure at one press; one live line under it says
# where the figure stands (hint: a Callable(value) -> [text, hot]). Nothing is refused here: a
# figure the other side will not take is said, not stopped.
#   var p = PriceInput.new(); p.setup(ref, start, stops, hint); p.submitted.connect(...)

signal changed(value: float)
signal submitted(value: float)

var value := 0.0
var max_value := INF           # a hard ceiling (an offer over the ask is the ask)
var min_value := 0.0
var ref := 0.0                 # the price the steps are a share of
var field: LineEdit
var minus: Button
var plus: Button
var hint: Label
var stops: Array = []          # the quick-stop keys (meta "to": the figure)
var _hint_fn: Callable
var _shown := 0.0              # the figure as it was before an edit (Esc puts it back)
var _hold_dir := 0
var _hold_t := 0.0
var _hold_n := 0


func setup(reference: float, start: float, quick: Array = [], hint_fn: Callable = Callable()) -> void:
	ref = reference
	_hint_fn = hint_fn
	add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	minus = _key("−", -1)
	row.add_child(minus)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", Charcoal.well_box(6.0))
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(well)
	field = LineEdit.new()
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 24)
	field.add_theme_color_override("font_color", Charcoal.INK)
	field.add_theme_color_override("caret_color", Charcoal.ACCENT)
	field.add_theme_color_override("selection_color", Color(Charcoal.ACCENT, 0.35))
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(st, clear)
	field.custom_minimum_size = Vector2(170, 40)
	field.select_all_on_focus = true
	field.context_menu_enabled = false
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	field.text_changed.connect(_typed)
	field.text_submitted.connect(func(_t): _commit(true))
	field.focus_exited.connect(func(): _commit(false))
	field.gui_input.connect(_field_input)
	well.add_child(field)
	plus = _key("+", 1)
	row.add_child(plus)
	if not quick.is_empty():
		var qrow := HBoxContainer.new()
		qrow.add_theme_constant_override("separation", 6)
		add_child(qrow)
		for q in quick:
			var b := Button.new()
			b.text = str(q[0])
			b.custom_minimum_size = Vector2(0, 34)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 13)
			Charcoal.style_button(b)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.set_meta("to", float(q[1]))
			b.tooltip_text = Pal.money(float(q[1]))
			b.pressed.connect(func(): set_value(float(q[1])); field.release_focus())
			qrow.add_child(b)
			stops.append(b)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	set_value(start)
	set_meta("price_input", true)


func _key(t: String, dir: int) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(52, 48)
	b.add_theme_font_size_override("font_size", 26)
	Charcoal.style_button(b)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		b.add_theme_stylebox_override(st, sb)
	b.tooltip_text = "按住连续调 · Shift 五倍" if Txt.zh else "HOLD TO REPEAT · SHIFT ×5"
	b.button_down.connect(func(): _step(dir); _hold_dir = dir; _hold_t = 0.0; _hold_n = 0)
	b.button_up.connect(func(): _hold_dir = 0)
	b.gui_input.connect(_wheel_input)
	return b


# one step: about 1 % of the reference, rounded to $500 (or $1,000 past $500k, $100 under $20k)
func step_of(shift: bool) -> float:
	var unit := 100.0 if ref < 20000.0 else (500.0 if ref < 500000.0 else 1000.0)
	var s := maxf(unit, snappedf(ref * 0.01, unit))
	return s * (5.0 if shift else 1.0)


func _step(dir: int) -> void:
	_commit(false)
	set_value(value + dir * step_of(Input.is_key_pressed(KEY_SHIFT)))


func _process(dt: float) -> void:
	if _hold_dir == 0:
		return
	if not (minus.button_pressed or plus.button_pressed):
		_hold_dir = 0
		return
	_hold_t += dt
	# after a short pause it repeats, faster the longer it is held
	var gap := 0.06 if _hold_n > 8 else 0.11
	if _hold_t >= (0.35 if _hold_n == 0 else gap):
		_hold_t = 0.0
		_hold_n += 1
		_step(_hold_dir)


func set_value(v: float, quiet := false) -> void:
	value = clampf(snappedf(v, 100.0 if ref >= 20000.0 else 10.0), min_value, max_value)
	_shown = value
	if field != null:
		field.text = _fmt(value)
		field.caret_column = field.text.length()
	_say()
	if not quiet:
		changed.emit(value)


static func _fmt(v: float) -> String:
	return Pal.money(v)


# digits only; the separators put back as it is typed, the caret kept at the end
func _typed(t: String) -> void:
	var digits := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		value = 0.0
		if t != "" and t != "$":
			field.text = ""
		_say()
		return
	value = float(digits.left(12))
	var shown := _fmt(value)
	if shown != t:
		field.text = shown
		field.caret_column = shown.length()
	_say()


func _commit(submit: bool) -> void:
	if field == null:
		return
	var over := value > max_value
	set_value(value, true)
	changed.emit(value)
	if over:
		hint.text = ("最高就是要价 %s" if Txt.zh else "THE MOST IS THE ASK, %s") % Pal.money(max_value)
		hint.add_theme_color_override("font_color", Charcoal.ACCENT)
	if submit:
		field.release_focus()
		submitted.emit(value)


func _field_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE:
		# leave the editing, the figure as it was; the page under it stays open
		set_value(_shown, true)
		field.release_focus()
		field.accept_event()
		return
	if ev is InputEventKey and ev.pressed and ev.physical_keycode in [KEY_UP, KEY_DOWN]:
		_step(1 if ev.physical_keycode == KEY_UP else -1)
		field.accept_event()
		return
	_wheel_input(ev)
	if ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		field.accept_event()


func _wheel_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_step(1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()


func _gui_input(ev: InputEvent) -> void:
	_wheel_input(ev)


func _say() -> void:
	if hint == null:
		return
	var t := ""
	var hot := false
	if _hint_fn.is_valid():
		var r: Array = _hint_fn.call(value)
		t = str(r[0])
		hot = bool(r[1])
	elif ref > 0.0:
		t = ("比参考价低 %d%%" if Txt.zh else "%d%% UNDER") % int(round((1.0 - value / ref) * 100.0))
	hint.text = t
	hint.add_theme_color_override("font_color", Charcoal.ACCENT if hot else Charcoal.INK2)
