extends Control
# 2026-11-12 (user: "至少得提示大一点吧，完全没看到"): when the plan run waits on the player (plan.gd
# player_alert: "等待露出", a sealed room, a cut beside a room under pressure…) a bar comes down
# top-centre — a size up from the plan's line among the function keys, the accent outline — saying the
# run is paused and what to do; its place in the scene is ringed. It goes up again once the run goes on.
# Placed under the top OSD strip, between the task panel (left) and the function keys (right); not
# while the big centre card is up. Text 【占位】.
const H := 66.0
const W_MAX := 720.0
const TOP := 100.0               # under the top strip (CAM · REC · the compass)
const IN_S := 0.22
var hud
var _k := 0.0                    # 0 gone .. 1 down
var _al := {}
var _t := 0.0
var _hold := 0.0                 # s it stays up after the wait flickers off (a step retried each 1.6 s)
var _at_i := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _game():
	return hud.game if hud != null else null

func _process(dt: float) -> void:
	var g = _game()
	var al: Dictionary = {}
	if g != null and is_instance_valid(g) and g.get("plan") != null and g.state == "play" and g.plan.has_method("player_alert"):
		al = g.plan.player_alert()
	if not al.is_empty():
		_al = al
		_hold = 1.2
		_at_i = int(g.plan.i)
	elif g != null and is_instance_valid(g) and g.get("plan") != null and g.plan.running and int(g.plan.i) == _at_i and _hold > 0.0:
		_hold -= dt
		al = _al
	else:
		_hold = 0.0
	var goal := 0.0 if al.is_empty() else 1.0
	_k = goal if Txt.anim_level() == 0 else move_toward(_k, goal, dt / IN_S)
	_t += dt
	if _k > 0.0 or goal > 0.0:
		queue_redraw()

# the bar's place this frame (Rect2() when it has no room)
func bar_rect() -> Rect2:
	var s := get_viewport_rect().size
	var left := 0.0
	var right := s.x
	if hud != null:
		if hud.has_method("_contract_rect"):
			left = maxf(left, (hud._contract_rect() as Rect2).end.x + 16.0)
		if hud.keys_band != null:
			var b: Rect2 = hud.keys_band.band_rect()
			if b.has_area() and b.position.y < TOP + H:
				right = minf(right, b.position.x - 16.0)
	var w := minf(W_MAX, right - left)
	if w < 320.0:
		return Rect2()
	var x := clampf(s.x * 0.5 - w * 0.5, left, right - w)
	return Rect2(x, TOP, w, H)

func _draw() -> void:
	if _k <= 0.0 or _al.is_empty():
		return
	var g = _game()
	if g == null or not is_instance_valid(g):
		return
	# the big centre card has the screen
	if hud != null and float(hud.card_k.x) > 0.05:
		return
	var r := bar_rect()
	if not r.has_area():
		return
	var e: float = Pal.ease_out(_k)
	r.position.y -= (1.0 - e) * 24.0
	var acc: Color = Charcoal.ACCENT
	draw_rect(r, Color(0.035, 0.037, 0.043, 0.9 * e))
	var pulse := 0.75 + 0.25 * sin(_t * 5.0) if Txt.anim_level() > 0 else 1.0
	draw_rect(r, Color(acc, e * pulse), false, 2.0)
	draw_rect(Rect2(r.position, Vector2(6.0, r.size.y)), Color(acc, e))
	var fb: Font = Fonts.get_font("Medium")
	var fr: Font = Fonts.get_font("Regular")
	var title := "【占位】自动拆解暂停 · 需要你处理" if Txt.zh else "[PLACEHOLDER] AUTO-STRIP PAUSED · YOUR MOVE"
	draw_string(fb, r.position + Vector2(20.0, 26.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 18, Color(acc, e))
	draw_string(fr, r.position + Vector2(20.0, 52.0), str(_al.get("line", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 16, Pal.ink(0.92 * e))
	# its place in the scene: ringed (the 下一步 mark points there too)
	var at: Vector2 = _al.get("at", Vector2.INF)
	if at.is_finite():
		var sp: Vector2 = g.get_viewport().get_canvas_transform() * at
		var vr := get_viewport_rect().grow(-24.0)
		if vr.has_point(sp):
			var rr := 26.0 + 6.0 * sin(_t * 4.0) if Txt.anim_level() > 0 else 28.0
			draw_arc(sp, rr, 0.0, TAU, 40, Color(acc, 0.9 * e), 2.5, true)
			draw_arc(sp, rr + 9.0, 0.0, TAU, 40, Color(acc, 0.35 * e), 1.5, true)
