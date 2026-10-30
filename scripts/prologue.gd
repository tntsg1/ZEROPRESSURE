extends Node2D
# The asteroid-belt prologue (design/…/28 Q5 C, 32 号; player 2026-10-24: "I started out
# recovering hulks from the asteroid belt and selling the material"). A new career begins
# here, not in the TS-1 course: the company's tug has found TUG-001 adrift, and the drone does
# what a recovery needs, each basic taught as it is needed — fly over, brake, read the hulk,
# cut the bent mast jammed over the tow eye, grapple it clear, hook the tow cable on. Then the
# tow home (scripts/belt_prelude.gd) and Berth 07. TS-1 stays at the terminal as an option.

const GuideMark = preload("res://scripts/guide_mark.gd")
const STEPS := ["fly", "brake", "measure", "cut", "clear", "tow"]
const EYE := Vector2(15.5, 1.3)       # m, ship-local: the tow eye on the stern frame
const NEAR := 9.0                     # m: "at the hulk"
var game
var step := 0
var done := false

# 80 号 Q2: the prologue locks the tools too — flying first, then one tool a step
const TOOLS := {"fly": [], "brake": [], "measure": [1], "cut": [2], "clear": [3], "tow": []}


func tool_allowed(n: int) -> bool:
	if done or step >= STEPS.size():
		return true
	return (TOOLS.get(STEPS[step], [1, 2, 3, 4, 5, 6]) as Array).has(n)
var card: PanelContainer
var title: Label
var body: Label
var count: Label
var t := 0.0
var _hold := 0.0
var _use := false
var _placed := false
var step_t := 0.0               # 80 号: time on this step — 20 s adds where to go, 40 s the ring swells
const STUCK_1 := 20.0
const STUCK_2 := 40.0
# where the company tug lies, the drone's launch point off its bow (Backdrop draws the tug)
static func tug_at() -> Vector2:
	return Dock.centre() * Geom.M + Vector2(-62.0, -6.0) * Geom.M


static func launch_at() -> Vector2:
	return tug_at() + Vector2(14.0, 0.0) * Geom.M


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	card = PanelContainer.new()
	card.position = Vector2(22, 22)
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", GuideMark.card_box(Pal.tint(Pal.AIR, 1.0, 1.3)))
	var col := VBoxContainer.new()
	card.add_child(col)
	count = _label(13, Pal.tint(Pal.AIR, 0.85, 1.3))
	title = _label(20, Pal.ink(0.96))
	body = _label(15, Pal.ink(0.7))
	for n in [count, title, body]:
		col.add_child(n)
	layer.add_child(card)
	_show()


func _label(size_px: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	return l


# ---------------------------------------------------------------- the hulk

func _piece(tag: String):
	for p in game.world.pieces.values():
		if not p.gone and str(p.tag) == tag:
			return p
	return null


func _keel():
	return _piece("KEEL")


# the hulk's main structure stays the world's own frame; what is cut loose gets a body
func hulk_centre() -> Vector2:
	var k = _keel()
	if k != null:
		return game.world.frame(k) * (Vector2(8.0, 0.0) * Geom.M)
	return Dock.centre() * Geom.M


# the eye in the world: the stern frame moves with the hulk
func eye() -> Vector2:
	var k = _keel()
	if k != null:
		return game.world.frame(k) * (EYE * Geom.M)
	return game.world.global_position + EYE * Geom.M


func mast_free() -> bool:
	var m = _piece("MAST")
	var k = _keel()
	return m != null and m.body != null and (k == null or m.body != k.body)


func mast_clear() -> bool:
	var m = _piece("MAST")
	if m == null:
		return true
	return mast_free() and m.body.global_position.distance_to(eye()) > 6.0 * Geom.M and game.tools.held_body != m.body


# ---------------------------------------------------------------- the steps

func _target() -> Vector2:
	match STEPS[step]:
		"fly", "brake", "measure":
			return hulk_centre()
		"cut", "clear":
			var m = _piece("MAST")
			return m.body.global_position if m != null and m.body != null else eye()
	return eye()


func _passed(dt: float) -> bool:
	var d = game.drone
	if d == null:
		return false
	match STEPS[step]:
		"fly":
			return d.global_position.distance_to(hulk_centre()) < NEAR * Geom.M
		"brake":
			_hold = _hold + dt if d.linear_velocity.length() < 0.35 * Geom.M else 0.0
			return _hold > 0.6
		"measure":
			return int(game.ops.get("measure", 0)) + int(game.ops.get("remeasure", 0)) > 0
		"cut":
			return mast_free()
		"clear":
			return mast_clear()
		"tow":
			var ok: bool = _use and d.global_position.distance_to(eye()) < 2.5 * Geom.M
			_use = false
			return ok
	return false


func _show() -> void:
	_fill()
	# shorter text: the card shrinks back to it
	if card != null:
		card.reset_size()


func _fill() -> void:
	count.text = w("序章 · 小行星带 · %d / %d", "PROLOGUE · THE BELT · %d / %d") % [step + 1, STEPS.size()]
	var k := Keys.label
	match STEPS[step]:
		"fly":
			var dm := 0.0
			if game.drone != null:
				dm = game.drone.global_position.distance_to(hulk_centre()) / Geom.M
			title.text = w("跟着箭头飞向漂流船 · 还有 %d m", "FOLLOW THE ARROW TO THE HULK · %d m TO GO") % int(dm)
			_body(w("%s 移动，%s 冲刺。跟着无人机旁的箭头。", "%s to move, %s to dash. Follow the arrow by the drone.") % [_keys_move(), k.call("dash")], w("%s 移动，%s 冲刺。漂流船在画面外，无人机旁边的箭头指着它，到了它会被亮圈圈住。这一趟只是把它带回港。" % [_keys_move(), k.call("dash")], "%s to move, %s to dash. The hulk is off screen: the arrow by the drone points at it, and a ring marks it when you are there. This trip only brings it home." % [_keys_move(), k.call("dash")]))
		"brake":
			title.text = w("按 %s 刹停" % k.call("brake"), "PRESS %s TO STOP" % k.call("brake"))
			_body(w("太空里没有摩擦，松手也会一直漂。", "Nothing slows you in space."), w("太空里没有摩擦，松开方向键也会一直漂。%s 开飞行稳定会自动帮你减速。" % k.call("assist"), "Nothing slows you in space. %s turns on flight assist." % k.call("assist")))
		"measure":
			title.text = w("按 1 拿测量仪，左键点残骸", "PRESS 1 FOR THE METER, CLICK THE HULK")
			body.text = w("先读数再动手：质量、材质、带不带电、有没有压力。", "Read before you touch: mass, material, charge, pressure.")
		"cut":
			title.text = w("按 2 激光切割：切断桅杆根部", "PRESS 2: CUT THE MAST AT ITS FOOT")
			_body(w("按住左键，沿闪烁的根部划过去。", "Hold the button, sweep across its flashing foot."), w("一根撞弯的天线桅杆焊死在船尾框架上，压住了拖缆眼。按住左键沿闪烁的根部划过去。", "A bent antenna mast is welded to the stern frame over the tow eye. Hold the button and sweep across its flashing foot."))
		"clear":
			title.text = w("按 3 磁力抓钩：把桅杆拖开", "PRESS 3: GRAPPLE THE MAST CLEAR")
			_body(w("抓住，拖开 6 m 以上再松开。", "Grab it, pull it 6 m clear, let go."), w("左键抓住，拖离拖缆眼 6 m 以上再松开；甩一下它会自己飘走。", "Grab it, pull it more than 6 m off the eye and let go; a flick sends it drifting."))
		"tow":
			title.text = w("飞到拖缆眼，按 %s 挂缆" % k.call("use"), "AT THE TOW EYE, PRESS %s" % k.call("use"))
			_body(w("挂上缆，拖船把它拖回七号坞。", "Hook on; the tug takes it home."), w("挂上缆，拖船把它拖回七号坞。到港以后它就是你的第一笔料。", "Hook it on and the tug takes it home to Berth 07: your first material."))


# 108 号 Q4/Q11: a short line on the card; the full one once the step has taken 20 s
func _body(short: String, long: String) -> void:
	body.text = long if step_t >= STUCK_1 else short


func _stuck_line() -> void:
	if step < STEPS.size() and step_t >= STUCK_1:
		body.text += w("\n还没找到？跟着无人机旁边的箭头飞到亮圈那里。", "\nCAN'T FIND IT? FOLLOW THE ARROW BY THE DRONE TO THE LIT RING.")


func _keys_move() -> String:
	return "WASD"


func _process(dt: float) -> void:
	if done or game == null or game.state != "play" or game.paused_sim or get_tree().paused:
		queue_redraw()
		return
	t += dt
	# the drone leaves from the tug's bow, a good way off the hulk
	if not _placed and game.drone != null and game.drone.alive:
		_placed = true
		game.drone.global_position = launch_at()
		game.drone.linear_velocity = Vector2.ZERO
		# user 2026-10-26: "刚进场时玩家还不知道要飞多远" — the camera shows the hulk for a moment first
		game.plan_focus = hulk_centre()
		game.plan_focus_t = 2.2
		_resume()
	var was := step_t
	step_t += dt
	# the distance on the fly card counts down as you go
	if step < STEPS.size() and STEPS[step] == "fly" and fmod(t, 0.25) < dt:
		_show()
		if step_t >= STUCK_1:
			_stuck_line()
	if was < STUCK_1 and step_t >= STUCK_1:
		_show()
		_stuck_line()
	if _passed(dt):
		game.sfx.play("menu", Vector2.INF, 0.8)
		step += 1
		Career.guide_keep("prologue", step)
		_hold = 0.0
		step_t = 0.0
		if step >= STEPS.size():
			_finish()
			return
		game.messages = game.messages.filter(func(m): return not str(m[0]) in ["tool_locked_use", "tool_locked"])
		# the step's tool goes in hand by itself
		var open: Array = TOOLS.get(STEPS[step], [])
		if not open.is_empty() and game.tools != null and not open.has(game.tools.tool):
			game.tools.set_tool(int(open[0]), true)
		_show()
	queue_redraw()


# user 2026-10-28 ("做完一半之后，重新进来还得重新再玩"): a prologue cut short goes on from the step it
# had reached — or from the last one the hulk as it is now allows (the mast is back on a fresh hulk)
func _resume() -> void:
	var r := mini(Career.guide_at("prologue"), STEPS.size() - 1)
	if r <= 0:
		return
	if STEPS[r] in ["clear", "tow"] and not mast_free():
		r = STEPS.find("cut")
	if STEPS[r] == "tow" and not mast_clear():
		r = STEPS.find("clear")
	step = r
	step_t = 0.0
	var open: Array = TOOLS.get(STEPS[step], [])
	if not open.is_empty() and game.tools != null and not open.has(game.tools.tool):
		game.tools.set_tool(int(open[0]), true)
	_show()


func _unhandled_input(ev: InputEvent) -> void:
	if not done and step < STEPS.size() and STEPS[step] == "tow" and Keys.pressed(ev, "use"):
		_use = true
		get_viewport().set_input_as_handled()


# the cable is on: the tow home, then Berth 07
func _finish() -> void:
	done = true
	card.visible = false
	Career.data.prologue_done = true
	Career.save()
	game.finish_prologue()


func _draw() -> void:
	if done or game == null:
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	var at := _target()
	var k := 0.6 + 0.4 * sin(t * 5.0)
	var big := 1.6 if step_t >= STUCK_2 else 1.0
	GuideMark.target(self, at, z, Pal.tint(Pal.AIR, 1.0, 1.4), t, "", 26.0, big)
	if STEPS[step] == "cut":
		var m = _piece("MAST")
		if m != null and m.body != null:
			var foot: Vector2 = game.world.frame(m) * (Vector2(15.05, -0.45) * Geom.M)
			draw_circle(foot, 0.35 * Geom.M, Pal.heat(k, 1.8))
	if STEPS[step] in ["clear", "tow"]:
		draw_arc(eye(), 6.0 * Geom.M if STEPS[step] == "clear" else 0.8 * Geom.M, 0.0, TAU, 64, Pal.heat(0.5 * k, 1.3), 1.5 / z, true)
	# an arrow from the drone when the target is far
	var d = game.drone
	if d != null:
		GuideMark.arrow(self, game.look.lamp_pos() if game.look != null else d.global_position, at, z, Pal.tint(Pal.AIR, 1.0, 1.4), t)
