extends Control
# 128 号 第 3 段 §八: the one "修" button's confirmation — money is about to be spent, so this is
# the one place a confirmation stays (人性化: sales are not confirmed; a buy is). It lists what the
# stage takes, each line saying what the warehouse already has and what will be bought at market,
# then the one line "自有 X 件 · 要买 Y 件 $… · 合计 $… · 约 N 秒完工". Enter mends, Esc backs out.
# The thumbnails are the machines' own line art (StoreBook.look_any), as on the warehouse grid.

const W := 780.0
const RepairBill = preload("res://scripts/repair_bill.gd")
var zone := "trade"
var bill := {}
var on_done: Callable            # (ok: bool)
var font: Font
var font_b: Font
var ok_b: Button
var no_b: Button
var t := 0.0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = OpsSkin.theme()
	font = Fonts.get_font("Medium")
	font_b = Fonts.get_font("SemiBold")
	bill = RepairBill.of(zone)
	ok_b = Button.new()
	ok_b.text = w("修  [Enter]", "MEND  [Enter]")
	ok_b.focus_mode = Control.FOCUS_NONE
	ok_b.custom_minimum_size = Vector2(220, 46)
	ok_b.pressed.connect(func(): _end(true))
	add_child(ok_b)
	no_b = Button.new()
	no_b.text = w("取消  [Esc]", "BACK  [Esc]")
	no_b.focus_mode = Control.FOCUS_NONE
	no_b.custom_minimum_size = Vector2(160, 46)
	no_b.pressed.connect(func(): _end(false))
	add_child(no_b)
	BenchFx.primary(ok_b)
	if not bool(bill.get("cash_ok", true)):
		ok_b.disabled = true
		BenchFx.note(ok_b, w("修到下一期", "Mend the next stage"), w("现金不够：还差 %s", "NOT ENOUGH CASH: %s SHORT") % Pal.money(float(bill.buy_cash) - float(Career.data.get("money", 0.0))))


func _rows() -> Array:
	var out: Array = bill.get("rows", []).duplicate()
	return out


func _card() -> Rect2:
	var n := _rows().size() + 1
	var h := 150.0 + 64.0 * n + 150.0
	var s := size
	return Rect2(Vector2((s.x - W) * 0.5, (s.y - h) * 0.5), Vector2(W, h))


func _process(dt: float) -> void:
	t += dt
	var r := _card()
	ok_b.position = Vector2(r.end.x - 24 - ok_b.size.x, r.end.y - 22 - ok_b.size.y)
	no_b.position = Vector2(ok_b.position.x - 12 - no_b.size.x, ok_b.position.y)
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	var r := _card()
	var k := BenchFx.e_out5(clampf(t / 0.45, 0.0, 1.0))
	var acc := UiSkin.ACCENT
	draw_rect(r, Color(0.025, 0.029, 0.036, 0.97 * k))
	draw_rect(Rect2(r.position, Vector2(r.size.x * k, 2)), acc)
	draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
	var x0 := r.position.x + 28
	var y := r.position.y + 44
	var st := int(bill.get("stage", 1))
	draw_string(font, Vector2(x0, y - 14), w("修缮 · %s · %s期", "MEND · %s · STAGE %d") % [Port.name_of(zone), Works.cn_num(st)] if Txt.zh else "MEND · %s · STAGE %d" % [Port.name_of(zone), st], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(acc, 0.9))
	draw_string(font, Vector2(x0, y + 16), w("修好后：交易行按市价卖货 · 订单板接客户订单", "Mended: the exchange sells at market · the order board takes client orders"), HORIZONTAL_ALIGNMENT_LEFT, W - 56, 22, Pal.ink(0.96))
	var lead_s := w("有的先用自己的，缺的去交易行买，比自己拆的贵。施工队不收工钱。", "What the warehouse has goes first; what is short is bought on the exchange in the same click (other companies' goods, dearer than your own). The crew is free.") if bool(bill.get("at_hall", false)) else w("有的先用自己的，缺的按市价买。施工队不收工钱。", "What the warehouse has goes first; what is short is bought at market in the same click. The crew is free.")
	draw_string(font, Vector2(x0, y + 44), lead_s, HORIZONTAL_ALIGNMENT_LEFT, W - 56, 14, Pal.ink(0.6))
	y += 74
	# the column heads
	var cx_need := r.position.x + 380
	var cx_own := r.position.x + 470
	var cx_buy := r.position.x + 590
	for h in [[w("材料", "MATERIAL"), x0 + 64], [w("要", "NEED"), cx_need], [w("自有", "OWN"), cx_own], [w("要买", "BUY"), cx_buy]]:
		draw_string(font, Vector2(h[1], y), str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
	y += 10
	draw_line(Vector2(x0, y), Vector2(r.end.x - 28, y), Color(1, 1, 1, 0.08), 1.0)
	var i := 0
	var lines: Array = _rows()
	lines.append({"steel": true})
	for row in lines:
		var rk := BenchFx.e_out5(clampf((t - 0.12 - 0.05 * i) / 0.5, 0.0, 1.0))
		var ry := y + 8 + 64.0 * i + (1.0 - rk) * 16.0
		var a := rk
		var thumb := Rect2(Vector2(x0, ry), Vector2(52, 52))
		draw_rect(thumb, Color(0.06, 0.066, 0.075, a))
		draw_rect(thumb, Color(1, 1, 1, 0.1 * a), false, 1.0)
		var name := ""
		var need := ""
		var own := 0.0
		var buy := 0.0
		var each := 0.0
		var unit := ""
		if row.get("steel", false):
			var sd: Dictionary = bill.get("steel", {})
			_bundle(thumb.grow(-8), a)
			name = w("修缮钢材", "REPAIR STEEL")
			need = "%.0f t" % float(sd.get("need", 0.0))
			own = float(sd.get("own", 0.0))
			buy = float(sd.get("buy", 0.0))
			each = float(sd.get("each", 0.0))
			unit = "t"
		else:
			_thumb(thumb.grow(-4), str(row.nk), a)
			name = str(row.name)
			need = w("%d 台", "%d") % int(row.need)
			own = float(row.own)
			buy = float(row.buy)
			each = float(row.each)
			unit = w("台", "")
		draw_string(font, Vector2(x0 + 64, ry + 32), name, HORIZONTAL_ALIGNMENT_LEFT, 290, 17, Pal.ink(0.92 * a))
		draw_string(font, Vector2(cx_need, ry + 32), need, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.8 * a))
		var own_s := ("%.1f t" % own) if unit == "t" else ("%d" % int(own))
		draw_string(font, Vector2(cx_own, ry + 32), ("✓ " if own > 0.0 else "– ") + own_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Hmi.ok_col(), a) if own > 0.0 else Pal.ink(0.35 * a))
		if buy > 0.001:
			var buy_s := ("%.1f t" % buy) if unit == "t" else ("%d" % int(buy))
			draw_string(font, Vector2(cx_buy, ry + 32), "%s × %s" % [buy_s, Pal.money(each)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(acc, a))
		else:
			draw_string(font, Vector2(cx_buy, ry + 32), w("不用买", "NONE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.35 * a))
		i += 1
	var yb := y + 8 + 64.0 * lines.size() + 14
	draw_line(Vector2(x0, yb), Vector2(r.end.x - 28, yb), Color(1, 1, 1, 0.08), 1.0)
	draw_string(font, Vector2(x0, yb + 34), RepairBill.line(bill), HORIZONTAL_ALIGNMENT_LEFT, W - 56, 18, Pal.ink(0.95))
	draw_string(font, Vector2(x0, yb + 60), w("现金 %s → 修完后 %s", "CASH %s → AFTER %s") % [Pal.money(float(Career.data.get("money", 0.0))), Pal.money(float(Career.data.get("money", 0.0)) - float(bill.get("buy_cash", 0.0)))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.55))


func _thumb(r: Rect2, nk: String, a: float) -> void:
	var lk := StoreBook.look_any("", "", nk)
	if lk.is_empty():
		draw_rect(r.grow(-10), Pal.ink(0.4 * a), false, 1.5)
		return
	var sz: Vector2 = lk.size * Geom.M
	var kk := minf(r.size.x / maxf(sz.x, 1.0), r.size.y / maxf(sz.y, 1.0)) * 0.9
	draw_set_transform(r.get_center() - sz * 0.5 * kk, 0.0, Vector2(kk, kk))
	var poly: PackedVector2Array = lk.poly
	if poly.size() >= 3:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(q * Geom.M)
		draw_colored_polygon(pts, Color(0.12, 0.13, 0.145, a))
	if str(lk.art) != "":
		Art.draw(self, str(lk.art), sz, null, font)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bundle(r: Rect2, a: float) -> void:
	# three plates stacked and strapped, as in the warehouse's repair-steel corner
	for j in 3:
		var pr := Rect2(r.position + Vector2(j * 2.0, r.size.y * (0.55 - 0.18 * j)), Vector2(r.size.x - 6.0, r.size.y * 0.16))
		draw_rect(pr, Color(0.2, 0.21, 0.23, a))
		draw_rect(pr, Pal.ink(0.7 * a), false, 1.0)
	draw_line(Vector2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.15), Vector2(r.position.x + r.size.x * 0.3, r.end.y - 2), Color(UiSkin.ACCENT, 0.8 * a), 2.0)
	draw_line(Vector2(r.position.x + r.size.x * 0.7, r.position.y + r.size.y * 0.15), Vector2(r.position.x + r.size.x * 0.7, r.end.y - 2), Color(UiSkin.ACCENT, 0.8 * a), 2.0)


func _end(ok: bool) -> void:
	if on_done.is_valid():
		on_done.call(ok)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_end(false)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not ok_b.disabled:
			_end(true)
			get_viewport().set_input_as_handled()
