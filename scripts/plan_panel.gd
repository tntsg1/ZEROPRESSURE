extends Control
# Container layout and scrolling keep translated text usable. The paused ship
# stays intact underneath; opening is a preview, never an implicit start command.
var game
var on_close: Callable
var picked := ""
var checks := {}
var detail: VBoxContainer
var authorize_button: Button
var notice: Label
var order_sale_button: Button
var anchor_mode_button: Button

func words(zh: String, en: String) -> String:
	return zh if Txt.zh else en

func label(text: String, px: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(action)
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skin := Theme.new()
	skin.default_font = Fonts.get_font("Regular")
	skin.default_font_size = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		skin.set_stylebox(state, "Button", SkillBook._key_box(state))
	theme = skin
	var shade := ColorRect.new()
	# Opaque background keeps the HDR ship glow from bleeding through small text.
	shade.color = Color(0.012,0.014,0.016,1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	column.add_child(label(words("作业方案 / 授权预览", "WORK PLANS / AUTHORIZATION PREVIEW"),28))
	column.add_child(label(words("选择机器负责的工序，保留你要亲手处理的部分。授权前不会执行。", "Choose the work to delegate. Keep critical dismantling in your hands. Previewing never starts a job.")))
	if game.work_order != null and game.work_order.active():
		column.add_child(label(game.work_order.text(game.work_order.id)+" · "+game.work_order.status_line(),20))
		column.add_child(label(game.work_order.text(game.work_order.id,"goal"),16))
		if game.work_order.last_reason != "": column.add_child(label(Txt.t(game.work_order.last_reason),16))
		order_sale_button = button("",toggle_order_sale)
		column.add_child(order_sale_button)
		refresh_order_sale()
	if game.gear != null and (game.job.get("rigging_hold",false) or Career.data.get("work_orders",{}).get("methods",{}).get("locked_anchor",false)):
		anchor_mode_button = button("",toggle_anchor_mode)
		column.add_child(anchor_mode_button)
		refresh_anchor_mode()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24)
	column.add_child(body)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size.x = 260
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_stretch_ratio = 0.8
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	body.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	list_scroll.add_child(list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.3
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.follow_focus = true
	body.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",12)
	detail_scroll.add_child(detail)
	game.plan.packages.refresh()
	for d in game.plan.packages.catalogue:
		var cb := CheckBox.new()
		cb.text = str(d.label)
		cb.tooltip_text = words("%d 个工序" % d.steps.size(), "%d process steps" % d.steps.size())
		cb.custom_minimum_size.y = 50
		cb.button_pressed = game.plan.packages.selected.has(d.id)
		cb.toggled.connect(func(value): choose_with_dependencies(str(d.id),value))
		checks[str(d.id)] = cb
		list.add_child(cb)
		list.add_child(button(words("查看工序", "INSPECT PROCESS"), func(): picked = str(d.id); refresh_detail()))
		if picked == "": picked = str(d.id)
	notice = label("",16)
	column.add_child(notice)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)
	authorize_button = button(words("授权所选作业包", "AUTHORIZE SELECTED WORK"), authorize)
	authorize_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(authorize_button)
	footer.add_child(button(words("返回现场 [Esc]", "RETURN [Esc]"), close))
	if not checks.is_empty(): checks.values()[0].grab_focus()
	refresh_detail()

func refresh_detail() -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var book = game.plan.packages
	for d in book.catalogue:
		if str(d.id) != picked: continue
		detail.add_child(label(str(d.label),24))
		var kind: String = str(d.get("kind","legacy"))
		var origin := words("已验证局部工序", "VERIFIED LOCAL PROCESS")
		if kind == "legacy": origin = words("旧式操作记录：保留原有安全检查，尚未验证整体工程目的。", "Legacy recording: original safety checks apply; the overall engineering outcome is unverified.")
		elif kind == "preset": origin = words("预置安全处置：检测、阀门与开关；不包含整船切割。", "Authored preparation: readings, valves and switches; this is not whole-ship automatic dismantling.")
		detail.add_child(label(origin))
		var purpose: String = str(d.get("purpose_zh" if Txt.zh else "purpose_en",""))
		if purpose != "": detail.add_child(label(purpose))
		detail.add_child(label(words("适用船型：", "SHIP: ")+str(d.get("ship",game.ship_id))+"  /  v"+str(d.get("version",1)),16))
		detail.add_child(label(words("目标：", "TARGETS: ")+", ".join(d.get("targets",[]))))
		detail.add_child(label(words("保留对象：", "PRESERVE: ")+", ".join(book.protected+d.get("protected",[]))))
		var conflicts: Array = book.conflicts(d)
		if not conflicts.is_empty(): detail.add_child(label(words("禁止授权：切口与保留对象冲突：", "CANNOT AUTHORIZE: CUTS CONFLICT WITH PRESERVED OBJECTS: ")+", ".join(conflicts)))
		if not d.get("deps",[]).is_empty():
			var names: Array = []
			for dep in d.deps:
				var name := words("缺失的前置工序", "MISSING PREREQUISITE")
				for candidate in book.catalogue:
					if candidate.id == dep: name = str(candidate.label)
				names.append(name)
			detail.add_child(label(words("前置作业包：", "PREREQUISITES: ")+", ".join(names)))
		var targets: Array = d.get("targets",[])
		if not targets.is_empty():
			detail.add_child(button(words("定位到局部目标", "LOCATE LOCAL TARGET"), func(): locate(str(targets[0]))))
			var keep: String = str(targets[0])
			detail.add_child(button(words("取消保留目标" if book.protected.has(keep) else "保留目标，交由我处理", "RELEASE PRESERVATION" if book.protected.has(keep) else "PRESERVE TARGET FOR MANUAL WORK"), func():
				if book.protected.has(keep): book.protected.erase(keep)
				else: book.protected.append(keep)
				refresh_detail()))
		detail.add_child(HSeparator.new())
		var index := 1
		for st in d.steps:
			var action: String = str(st.get("do", st.get("op","")))
			var target := str(st.get("key",st.get("ctrl",",".join(st.get("keys",[])))))
			var desc: String = {"cut":words("验证后切割", "VERIFIED CUT"),"haul":words("运输并确认实际送达", "TRANSPORT AND CONFIRM ARRIVAL")}.get(action,words("安全处置", "SAFE PREPARATION"))
			detail.add_child(label("%02d  %s · %s" % [index,desc,target],16))
			index += 1
	var ids := chosen()
	authorize_button.disabled = ids.is_empty()
	for d in book.catalogue:
		if ids.has(d.id):
			if not book.conflicts(d).is_empty(): authorize_button.disabled = true
			for dep in d.get("deps",[]):
				if not ids.has(dep): authorize_button.disabled = true
	notice.text = words("授权后回到现场；P 停止方案，J 停止机器。缺少检测或结构不符时暂停。", "Authorization returns to the ship. P stops the plan; J stops machines. Missing evidence or changed structure pauses the affected job.")

func choose_with_dependencies(id: String, value: bool) -> void:
	picked = id
	var visited: Array = []
	var pending: Array = [id]
	while not pending.is_empty():
		var next_id: String = str(pending.pop_back())
		if visited.has(next_id): continue
		visited.append(next_id)
		if checks.has(next_id): checks[next_id].set_pressed_no_signal(value)
		for d in game.plan.packages.catalogue:
			if value and d.id == next_id:
				pending.append_array(d.get("deps",[]))
			elif not value and d.get("deps",[]).has(next_id):
				pending.append(d.id)
	refresh_detail()

func chosen() -> Array:
	var out: Array = []
	for id in checks:
		if checks[id].button_pressed: out.append(id)
	return out

func refresh_order_sale() -> void:
	order_sale_button.text = words("当前：出售回收物（不交付工程）· 点击改为预留" if game.work_order.sell else "当前：预留给工程 · 点击改为出售", "SELL RECOVERED GOODS (NO DELIVERY) · CLICK TO RESERVE" if game.work_order.sell else "RESERVED FOR ENGINEERING · CLICK TO SELL")

func toggle_order_sale() -> void:
	game.work_order.sell = not game.work_order.sell
	refresh_order_sale()

func refresh_anchor_mode() -> void:
	anchor_mode_button.text = words("新部署牵引锚：锁索支撑 · 点击切换收卷" if game.gear.hold_mode else "新部署牵引锚：收卷到废料槽 · 点击切换锁索", "NEW ANCHORS: LOCKED CABLE · SWITCH TO REEL" if game.gear.hold_mode else "NEW ANCHORS: REEL TO SCRAP TROUGH · SWITCH TO LOCK")

func toggle_anchor_mode() -> void:
	game.gear.hold_mode = not game.gear.hold_mode
	refresh_anchor_mode()

func authorize() -> void:
	if not game.plan.packages.authorize(chosen()): return
	game.plan.package_mode = true
	game.plan.running = true
	game.auto_paused = false
	close()

func locate(key: String) -> void:
	var p = game.world.key_piece(key)
	if p == null:
		notice.text = words("当前现场找不到目标：", "TARGET NOT PRESENT: ")+key
		return
	game.plan_focus = game.world.frame(p) * Geom.centroid(p.poly)
	game.plan_focus_t = 4.0
	close()

func close() -> void:
	if on_close.is_valid(): on_close.call()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ESCAPE,KEY_P]:
		get_viewport().set_input_as_handled()
		close()
