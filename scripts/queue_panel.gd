extends Control
# 108 号 Q12 (remote business, the processing queue): the ingots kept for processing, in the order
# the furnace and the mill take them — each batch with its ship, its tonnes, what is melted and
# rolled — and the order changed from here: up, down, to the front. The furnace and the mill are
# still run where they stand; this only says which batch comes next. ↑ ↓ pick, W / S move the
# picked batch, Home puts it first, Esc closes.

var game
var on_close: Callable
var sel := 0
var list: VBoxContainer
var message: Label
var _sig := ""


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var accent := Pal.tint(Pal.AIR, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 720.0)
	column.add_child(OpsSkin.Plate.new("QUEUE", w("加工排队", "PROCESSING QUEUE"), w("远程 · 炉台和轧机照这个顺序取料", "REMOTE · THE FURNACE AND THE MILL TAKE THEM IN THIS ORDER"), accent))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	column.add_child(list)
	message = OpsSkin.label("", 14, 0.7)
	column.add_child(message)
	column.add_child(OpsSkin.label(w("↑ ↓ 选一批 · W / S 上下移 · Home 放到最前 · Esc 关闭", "↑ ↓ PICK · W / S MOVE · HOME TO THE FRONT · ESC CLOSE"), 13, 0.5))
	var close := Button.new()
	close.name = "Close"
	close.text = w("关闭 [Esc]", "CLOSE [Esc]")
	close.custom_minimum_size.y = 44
	close.pressed.connect(_close)
	column.add_child(close)
	_fill()


func _open() -> Array:
	return ProcessQueue.entries().filter(func(e): return not ProcessQueue.finished(e))


func _fill() -> void:
	for c in list.get_children():
		c.queue_free()
	var q := _open()
	sel = clampi(sel, 0, maxi(0, q.size() - 1))
	if q.is_empty():
		list.add_child(OpsSkin.label(w("没有排队的钢锭。结算时选“留着加工”的钢锭会排到这里。", "NOTHING QUEUED. INGOTS KEPT FOR PROCESSING AT A SETTLEMENT COME HERE."), 15, 0.7))
		return
	for i in q.size():
		var e: Dictionary = q[i]
		var row := HBoxContainer.new()
		row.name = "Row_%d" % i
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, ProcessQueue.line(e)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 42
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		if i == sel:
			b.add_theme_color_override("font_color", UiSkin.ACCENT)
		b.pressed.connect(func(): sel = i; _fill())
		row.add_child(b)
		for spec in [["↑", -1], ["↓", 1], [w("最前", "FIRST"), -99]]:
			var m := Button.new()
			m.text = str(spec[0])
			m.custom_minimum_size = Vector2(64, 42)
			m.focus_mode = Control.FOCUS_NONE
			m.disabled = (int(spec[1]) < 0 and i == 0) or (int(spec[1]) > 0 and i == q.size() - 1)
			m.pressed.connect(_move.bind(i, int(spec[1])))
			row.add_child(m)


func _move(i: int, dir: int) -> void:
	var q := _open()
	if i < 0 or i >= q.size():
		return
	var lot := str(q[i].lot)
	var to := ProcessQueue.move(lot, dir)
	if to < 0:
		return
	sel = _open().find(ProcessQueue.of_lot(lot))
	message.text = w("%s 排到第 %d 位", "%s IS NOW NUMBER %d") % [ProcessQueue.tag(ProcessQueue.of_lot(lot)), sel + 1]
	Career.save()
	if game != null and game.get("sfx") != null:
		game.sfx.play("switch")
	_fill()


func _process(_dt: float) -> void:
	# the furnace and the mill go on meanwhile: the rows follow them
	var sig := str(_open().map(func(e): return [e.lot, snappedf(float(e.melted), 0.1), snappedf(float(e.get("rolled", 0.0)), 0.1)]))
	if sig != _sig:
		_sig = sig
		_fill()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var n := _open().size()
	match ev.physical_keycode:
		KEY_ESCAPE:
			_close()
		KEY_UP:
			sel = maxi(0, sel - 1)
			_fill()
		KEY_DOWN:
			sel = mini(n - 1, sel + 1)
			_fill()
		KEY_W:
			_move(sel, -1)
		KEY_S:
			_move(sel, 1)
		KEY_HOME:
			_move(sel, -99)
		_:
			return
	get_viewport().set_input_as_handled()


func _close() -> void:
	if on_close.is_valid():
		on_close.call()
