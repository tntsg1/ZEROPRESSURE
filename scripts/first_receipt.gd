extends CanvasLayer
# 108 号 Q3 (the outside review: "看着它飞出去，再获得一次明显的回收收益"; user 2026-10-29 "b": the
# recovery station buys it on the spot): the career's first whole machine delivered gets a
# receipt of its own, once — top centre, out of the way of the guide's card: what it was, the
# cash rolling up to what was paid, a stamp, and the till's own recorded sound. It goes by itself
# after a few seconds, or at a key.

const SHOW_S := 5.2
const W := 520.0
const H := 150.0

var item := ""                  # its name and tag
var value := 0.0
var t := 0.0
var c: Control
var font: Font
var font_b: Font


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_card)
	add_child(c)


func _process(dt: float) -> void:
	t += dt
	if t >= SHOW_S:
		queue_free()
		return
	c.queue_redraw()


func _unhandled_input(ev: InputEvent) -> void:
	if t > 0.8 and ev is InputEventKey and ev.pressed and not ev.echo:
		t = maxf(t, SHOW_S - 0.35)


func _draw_card() -> void:
	var vs := c.size
	# in: a slide down and a settle; out: up and fade
	var k_in := Pal.ease_out(clampf(t / 0.45, 0.0, 1.0))
	var k_out := clampf((SHOW_S - t) / 0.35, 0.0, 1.0)
	var a := k_in * k_out
	var top := lerpf(-H, 132.0, k_in) - (1.0 - k_out) * 30.0
	var r := Rect2(Vector2((vs.x - W) * 0.5, top), Vector2(W, H))
	var acc := UiSkin.ACCENT
	var money := Pal.tint(Pal.AIR, 1.0, 1.2)
	# the slip: a dark body, a torn top edge, the accent rule down its left
	c.draw_rect(r.grow(10.0), Color(0, 0, 0, 0.35 * a))
	c.draw_rect(r, Color(0.055, 0.06, 0.065, 0.97 * a))
	var teeth := PackedVector2Array()
	var n := 26
	for i in n + 1:
		var x := r.position.x + W * float(i) / n
		teeth.append(Vector2(x, r.position.y - (4.0 if i % 2 == 1 else 0.0)))
	teeth.append(Vector2(r.end.x, r.position.y + 1.0))
	teeth.append(Vector2(r.position.x, r.position.y + 1.0))
	c.draw_colored_polygon(teeth, Color(0.055, 0.06, 0.065, 0.97 * a))
	c.draw_rect(Rect2(r.position, Vector2(4.0, H)), Color(acc, a))
	c.draw_rect(r, Color(Pal.ink(0.22), a), false, 1.0)
	# a sweep of light across it as it lands
	var sw := clampf((t - 0.3) / 0.7, 0.0, 1.0)
	if sw > 0.0 and sw < 1.0:
		var x := r.position.x + W * sw
		c.draw_rect(Rect2(Vector2(x - 40.0, r.position.y), Vector2(40.0, H)), Color(1, 1, 1, 0.05 * a * (1.0 - sw)))
	var x0 := r.position.x + 24.0
	c.draw_string(font, Vector2(x0, r.position.y + 30.0), w("第一件回收", "FIRST RECOVERY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(acc, 0.95 * a))
	c.draw_string(font, Vector2(r.end.x - 24.0 - 140.0, r.position.y + 30.0), "BERTH 07 · %s" % Time.get_time_string_from_system().substr(0, 5), HORIZONTAL_ALIGNMENT_RIGHT, 140.0, 12, Color(Pal.ink(0.45), a))
	c.draw_string(font_b, Vector2(x0, r.position.y + 62.0), item, HORIZONTAL_ALIGNMENT_LEFT, W - 48.0, 20, Color(Pal.ink(0.96), a))
	# the money rolls up to its value
	var roll := Pal.ease_out(clampf((t - 0.4) / 1.1, 0.0, 1.0))
	var shown := "+" + Pal.money(snappedf(value * roll, 1.0))
	c.draw_string(font_b, Vector2(x0, r.position.y + 112.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(money, a))
	var where := w("完好 · 回收站现场收购，现金已到账", "WHOLE · BOUGHT ON THE SPOT, CASH IN THE ACCOUNT")
	c.draw_string(font, Vector2(x0, r.position.y + 136.0), where, HORIZONTAL_ALIGNMENT_LEFT, W - 48.0, 13, Color(Pal.ink(0.6), a))
	# the stamp comes down once the money is in
	var st := clampf((t - 1.5) / 0.18, 0.0, 1.0)
	if st > 0.0:
		var sc := lerpf(1.6, 1.0, Pal.ease_out(st))
		var centre := Vector2(r.end.x - 86.0, r.position.y + 92.0)
		c.draw_set_transform(centre, -0.18, Vector2(sc, sc))
		var box := Rect2(Vector2(-62, -22), Vector2(124, 44))
		var sa := a * st
		c.draw_rect(box, Color(acc, 0.9 * sa), false, 2.5)
		c.draw_rect(box.grow(-5.0), Color(acc, 0.5 * sa), false, 1.0)
		c.draw_string(font_b, Vector2(-62, 8), w("已到账", "PAID"), HORIZONTAL_ALIGNMENT_CENTER, 124.0, 20, Color(acc, sa))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
