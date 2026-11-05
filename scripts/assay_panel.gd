extends Control
# The assay bench's console (scripts/industrial_assay.gd): which lots it can read, the
# spectrometer's live reading, the certificate. Play goes on while it is open; Esc closes.
var service
var on_close: Callable
var plate: OpsSkin.Plate
var screen: OpsSkin.Readout
var lots_box: VBoxContainer
var message: Label
var cancel_button: Button
var _refresh := 0.0
var _stamp := ""


func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func button(value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	return node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent := Pal.tint(Pal.FLUID, 1.0, 1.2)
	var column := OpsSkin.pane(self, accent, 440.0)
	plate = OpsSkin.Plate.new("XRF-07", words("化验位 · 取样光谱", "ASSAY · SAMPLE SPECTROMETER"),
		words("整批锁在仓库，只读样品 · 每批 %s（试行）\n黑色炉料杂质 ≤ %d%% 升为等级 1", "THE LOT STAYS IN STOCK, A SAMPLE IS READ · %s A LOT (PROVISIONAL)\nFERROUS FEED ≤ %d%% IMPURITY BECOMES GRADE 1") % [(Pal.money(service.fee()) if service.fee() > 0.0 else words("训练单免费", "FREE ON THE TRAINING RUN")), int(round(service.LIMIT * 100.0))], accent)
	column.add_child(plate)
	screen = OpsSkin.Readout.new()
	column.add_child(screen)
	column.add_child(OpsSkin.Section.new(words("仓库里能化验的批次", "LOTS THE BENCH CAN READ")))
	lots_box = VBoxContainer.new()
	lots_box.add_theme_constant_override("separation", 8)
	column.add_child(lots_box)
	column.add_child(OpsSkin.Section.new(words("操作", "CONTROLS")))
	cancel_button = button(words("撤回正在化验的批次（化验费不退）", "WITHDRAW THE LOT BEING READ (FEE KEPT)"), func(): _show(service.cancel()))
	BenchFx.note(cancel_button, words("立刻停下这批的化验，货退回去，化验费不退", "Stop reading this lot now; it goes back, the fee is kept"))
	column.add_child(cancel_button)
	message = OpsSkin.label("", 15)
	column.add_child(message)
	column.add_child(button(words("关闭 [Esc]", "CLOSE [Esc]"), close))
	_fill()


func _name(key: String) -> String:
	return Ops.item_name(key)


func _origin(o: String) -> String:
	return {"receiver": words("自拆留料", "OWN SALVAGE"), "magnetic_separation": words("本公司分选", "OWN SORTING"), "external_opening_inventory": words("外购", "BOUGHT")}.get(o, o)


func _show(result: Dictionary) -> void:
	message.text = words("已执行", "Done") if result.ok else str(result.get("reason", ""))
	_stamp = ""
	_fill()


func _fill() -> void:
	var a: Dictionary = service.data()
	var r: Array = service.reading()
	var rows: Array = []
	if service.fault != "":
		rows.append([service.fault, "", OpsSkin.lamp_col("danger")])
		plate.set_lamp("danger")
	elif a.is_empty():
		rows.append([words("化验位空闲", "BENCH IDLE"), ""])
		plate.set_lamp("idle")
	else:
		var describe: bool = str(a.get("kind", "")) == "describe"
		rows.append([str(a.get("id", "")) + " · " + _name(str(a.get("key", ""))), "%.3f t" % float(a.get("quantity", 0.0))])
		if service.running():
			plate.set_lamp("ok")
			rows.append([words("读数稳定", "SETTLING"), "%d %%" % int(round(float(r[2]) * 100.0))])
		else:
			plate.set_lamp("ok" if str(a.get("result", "")) != "unrated" else "warn")
		if describe:
			rows.append([words("非磁性份额", "NON-MAGNETIC SHARE"), "%.1f %%" % (float(r[1]) * 100.0)])
		else:
			rows.append([words("铁 Fe", "IRON Fe"), "%.2f %%" % (float(r[0]) * 100.0)])
			rows.append([words("杂质（Cu、Al、Sn 等）", "IMPURITY (Cu, Al, Sn…)"), "%.2f %%" % (float(r[1]) * 100.0), Hmi.ok_col() if float(r[1]) <= service.LIMIT else Hmi.warn_col()])
		match str(a.get("result", "")):
			"grade_1":
				rows.append([words("合格：整批升为等级 1 黑色炉料，可以开炉。", "PASS: THE LOT IS NOW GRADE 1 FURNACE FEED."), "", Hmi.ok_col()])
			"unrated":
				rows.append([words("不合格：保持未评级，只能按未评级挂牌卖。", "FAIL: STAYS UNRATED; SELL IT AS SUCH."), "", Hmi.warn_col()])
			"described":
				rows.append([words("已记下材料描述：这批旧料现在能送分选台。", "RECORDED: THIS OLD LOT CAN NOW BE SORTED."), "", Hmi.ok_col()])
		if service.waiting != "":
			rows.append([service.waiting, "", Hmi.warn_col()])
	screen.set_rows(rows)
	cancel_button.disabled = not service.running()
	# the lot list only changes when the warehouse does
	var cands: Array = service.candidates()
	var stamp := JSON.stringify(cands) + str(service.running())
	if stamp == _stamp:
		return
	_stamp = stamp
	for ch in lots_box.get_children():
		lots_box.remove_child(ch)
		ch.queue_free()
	if cands.is_empty():
		lots_box.add_child(OpsSkin.label(words("仓库里没有要化验的料。未评级黑色炉料来自分选台；自拆留料先过分选台。", "Nothing to read. Unrated ferrous feed comes off the sorting line; own salvage goes through sorting first."), 15, 0.65))
	for c in cands:
		var what := words("定级", "GRADE") if c.kind == "grade" else words("测材料描述", "DESCRIBE")
		var b := button("%s · %s %.3f t · %s" % [what, _name(str(c.key)), float(c.quantity), _origin(str(c.origin))], func(): _show(service.begin(str(c.id))))
		BenchFx.note(b, words("立刻化验这一批：交化验费，查清它到底是什么成分", "Read this lot now: pay the fee and learn what it really is"))
		b.disabled = service.running()
		lots_box.add_child(b)


func _process(dt: float) -> void:
	_refresh += dt
	if _refresh < 0.2:
		return
	_refresh = 0.0
	_fill()


func close() -> void:
	service.checkpoint()
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
