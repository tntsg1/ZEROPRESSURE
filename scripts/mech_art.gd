class_name MechArt
extends RefCounted
# 91 号 Q5 a (用户 2026-10-27：“HUD 与机械动效”): the berth's overhead machines drawn as machines —
# a trolley on its rail with wheels that turn as it runs, a motor housing, an amber beacon that
# turns while it works; the cable reeved through a hook block's sheaves; and the swing: the
# trolley leads and the load hangs back when it starts, runs on past when it stops, and settles.
# Only the picture: the hook stays where the machine's logic puts it (what it carries goes where
# it did), the trolley above it is drawn where a real one would be.
const FastDraw = preload("res://scripts/fast_draw.gd")   # 60 FPS: the cheap circle / arc / polyline

const SWING_K := 22.0       # 1/s²: the pendulum's stiffness (a few metres of cable)
const SWING_C := 3.2        # 1/s: its damping
const SWING_MAX := 34.0     # px

var x := 0.0                # px: the trolley's lead over the hook
var v := 0.0
var wheel := 0.0            # rad
var _last := Vector2.INF
var _vel := 0.0
var acc := 0.0              # px/s² along the rail, smoothed
var moving := 0.0           # 0..1, eased


# hook: where the machine has its hook this frame
func step(hook: Vector2, dt: float) -> void:
	if dt <= 0.0:
		return
	if _last == Vector2.INF:
		_last = hook
	var vel := (hook.x - _last.x) / dt
	var a := (vel - _vel) / dt
	# a change of speed sets the load swinging: the trolley ahead of it starting, behind it stopping
	v += clampf(vel - _vel, -600.0, 600.0) * 0.24
	_vel = vel
	acc = lerpf(acc, a, 1.0 - exp(-10.0 * dt))
	wheel += (hook.x - _last.x) / 7.0
	_last = hook
	# the trolley runs ahead of a load that lags: driven by the hook's acceleration
	# in 1/120 s steps, at most 0.1 s a frame: one long frame (a load) must not set it ringing
	var left := minf(dt, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		left -= h
		v += (-SWING_K * x - SWING_C * v) * h
		x = clampf(x + v * h, -SWING_MAX, SWING_MAX)
	if not is_finite(x) or not is_finite(v):
		x = 0.0
		v = 0.0
	moving = lerpf(moving, 1.0 if absf(vel) > 8.0 else 0.0, 1.0 - exp(-6.0 * dt))


# true once when a fast run stops hard (dust off the rail)
func hard_stop() -> bool:
	return acc < -900.0 and absf(_vel) < 30.0 and moving > 0.3


static func wheel_at(ci: CanvasItem, c: Vector2, r: float, ang: float, a: float) -> void:
	FastDraw.circle(ci, c, r, Color(0.05, 0.053, 0.06, a))
	FastDraw.arc(ci, c, r, 0.0, TAU, 18, Pal.ink(0.7 * a), 1.4, true)
	for k in 3:
		var d := Vector2.from_angle(ang + TAU * k / 3.0) * (r - 1.5)
		ci.draw_line(c - d * 0.25, c + d, Pal.ink(0.45 * a), 1.0, true)
	FastDraw.circle(ci, c, 1.6, Pal.ink(0.8 * a))


# the trolley on its rail: c is the middle of its wheels on the rail line
func trolley(ci: CanvasItem, c: Vector2, w: float, busy: bool, t: float, a: float = 1.0) -> void:
	var h := 14.0
	var body := Rect2(c.x - w * 0.5, c.y + 2.0, w, h)
	# the frame hangs under the rail; the wheels ride on top of it
	ci.draw_rect(body, Color(0.075, 0.079, 0.09, a))
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, 3.0)), Color(0.13, 0.135, 0.15, a))
	ci.draw_rect(body, Pal.ink(0.72 * a), false, 1.3)
	# the motor and its gearbox on one end, the cable drum in the middle
	var mx := c.x + w * 0.5 - 12.0
	ci.draw_rect(Rect2(mx - 7.0, body.position.y + 3.0, 12.0, 9.0), Color(0.1, 0.105, 0.12, a))
	ci.draw_rect(Rect2(mx - 7.0, body.position.y + 3.0, 12.0, 9.0), Pal.ink(0.5 * a), false, 1.0)
	for k in 3:
		ci.draw_line(Vector2(mx - 5.0 + k * 3.5, body.position.y + 4.0), Vector2(mx - 5.0 + k * 3.5, body.position.y + 11.0), Pal.ink(0.25 * a), 1.0)
	var drum := Vector2(c.x - 4.0, body.position.y + 8.0)
	FastDraw.arc(ci, drum, 5.0, 0.0, TAU, 14, Pal.ink(0.55 * a), 1.2, true)
	ci.draw_line(drum + Vector2.from_angle(wheel * 2.0) * 5.0, drum - Vector2.from_angle(wheel * 2.0) * 5.0, Pal.ink(0.35 * a), 1.0)
	for s in [-1.0, 1.0]:
		wheel_at(ci, Vector2(c.x + s * (w * 0.5 - 7.0), c.y - 3.0), 5.0, wheel, a)
	# the beacon: amber, turning while it works (the light sweeps across its dome)
	var bc := Vector2(c.x - w * 0.5 + 9.0, body.position.y - 1.0)
	FastDraw.arc(ci, bc, 3.2, PI, TAU, 8, Pal.ink(0.5 * a), 1.0, true)
	if busy:
		var ph := fposmod(t * 2.2, 1.0)
		var on := 0.35 + 0.65 * pow(maxf(0.0, sin(ph * TAU)), 4.0)
		FastDraw.circle(ci, bc, 2.6, Color(1.0, 0.62, 0.2, on * a))
		FastDraw.circle(ci, bc, 9.0, Color(1.0, 0.55, 0.15, 0.12 * on * a))


# the cable from the drum down to the hook block, reeved in `falls` parts; then the hook
static func cable_and_hook(ci: CanvasItem, top: Vector2, hook: Vector2, falls: int, loaded: bool, a: float = 1.0, with_hook: bool = true) -> void:
	var blk := hook + Vector2(0, -16.0)
	var spread := 3.0 * (falls - 1)
	for k in falls:
		var dx := -spread * 0.5 + k * 3.0
		ci.draw_line(top + Vector2(dx * 0.6, 0), blk + Vector2(dx, -6.0), Pal.ink((0.62 if loaded else 0.45) * a), 1.1, true)
	# the hook block: a plate with its sheaves, the hook under it
	var br := Rect2(blk.x - 9.0, blk.y - 7.0, 18.0, 14.0)
	ci.draw_rect(br, Color(0.08, 0.084, 0.095, a))
	ci.draw_rect(br, Pal.ink(0.75 * a), false, 1.2)
	FastDraw.arc(ci, blk + Vector2(0, -1), 4.0, 0.0, TAU, 12, Pal.ink(0.55 * a), 1.0, true)
	# the hazard stripes on the block's cheeks
	for s in [-1.0, 1.0]:
		ci.draw_line(Vector2(blk.x + s * 9.0, br.position.y + 2.0), Vector2(blk.x + s * 9.0, br.end.y - 2.0), Color(1.0, 0.6, 0.25, 0.7 * a), 2.0)
	if not with_hook:
		return
	var hp := hook + Vector2(0, -2.0)
	ci.draw_line(Vector2(blk.x, br.end.y), hp + Vector2(0, -2), Pal.ink(0.8 * a), 2.0)
	FastDraw.arc(ci, hp + Vector2(0, 5.0), 5.0, -0.5, PI * 0.95, 12, Pal.ink(0.9 * a), 2.2, true)
	ci.draw_line(hp + Vector2(-5.0 * cos(0.5) + 0.0, 5.0 - 5.0 * sin(0.5)), hp + Vector2(-4.6, 1.0), Pal.ink(0.9 * a), 2.0, true)
