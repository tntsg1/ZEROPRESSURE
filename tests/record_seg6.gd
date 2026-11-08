extends "res://tests/collision_audit.gd"
# 128 号 第 6 段: about 30 s for the owner — F12 → 显示碰撞 on, one loop round the port, stopping at
# a few of the places on the mismatch list (design/…/128_seg6_碰撞不一致清单.md). The drone is put
# in each place so the district's inside is drawn as the player sees it. Own test saves only.
#   tools/run_test.sh tests/record_seg6.gd --write-movie recordings/zeropressure_seg6_collision.avi --fixed-fps 30

const FPS := 30.0
var cap: Control
var cap_n := 0
var cap_title := ""
var cap_sub := ""
var cap_t := 0.0
const N := 8


func _initialize() -> void:
	Career.path = "user://zp_test_recseg6_career.json"
	SaveGame.path = "user://zp_test_recseg6_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	var layer := CanvasLayer.new()
	layer.layer = 126
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	cap = Control.new()
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(_draw_caption)
	layer.add_child(cap)
	process_frame.connect(func():
		cap_t += 1.0 / FPS
		cap.queue_redraw())
	_run.call_deferred()


func _beat(n: int, title: String, sub: String) -> void:
	cap_n = n
	cap_title = title
	cap_sub = sub
	cap_t = 0.0


func _draw_caption() -> void:
	if cap_n <= 0:
		return
	var f: Font = Fonts.get_font("Medium")
	var fr: Font = Fonts.get_font("Regular")
	var k := Pal.ease_out(clampf(cap_t / 0.4, 0.0, 1.0))
	var x := lerpf(cap.size.x - 40.0, cap.size.x - 80.0, k)
	var y := cap.size.y - 150.0
	var w := maxf(f.get_string_size(cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x, fr.get_string_size(cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) + 64.0
	x -= w
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(w, 150.0)), Color(0.03, 0.035, 0.04, 0.86 * k))
	cap.draw_rect(Rect2(Vector2(x - 20.0, y - 46.0), Vector2(5.0, 150.0)), Color(UiSkin.ACCENT, k))
	cap.draw_string(fr, Vector2(x, y - 16.0), "零压拆船厂 · 碰撞对照 %d / %d" % [cap_n, N], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiSkin.ACCENT, 0.95 * k))
	cap.draw_string(f, Vector2(x, y + 28.0), cap_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(Pal.ink(0.97), k))
	cap.draw_string(fr, Vector2(x, y + 70.0), cap_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.ink(0.7), k))


func _hide_ui() -> void:
	for l in root.find_children("*", "CanvasLayer", true, false):
		if l.layer < 100 and str(l.get_parent().name) != "CollisionView" and l.name != "FeedOSD" and l.name != "Post":
			l.visible = false


# glide the camera from where it is to `to` / `zoom` over `secs`, the drone already there
func _glide(to: Vector2, zoom: float, secs: float, drone_at = null) -> void:
	if drone_at != null:
		g.drone.global_position = drone_at
		g.drone.linear_velocity = Vector2.ZERO
	var from: Vector2 = g.cam_pos
	var z0: float = g.zoom_now
	var n := int(secs * FPS)
	for i in n:
		var k := Pal.ease_out(float(i + 1) / n) if n > 0 else 1.0
		var zk := lerpf(z0, zoom, k)
		_put(from.lerp(to, k), zk)
		if drone_at != null:
			g.drone.linear_velocity = Vector2.ZERO
		_hide_ui()
		await _frames(1)


func _hold(secs: float) -> void:
	for i in int(secs * FPS):
		_hide_ui()
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)


func _z(zone: String, local: Vector2) -> Vector2:
	return PortStructure.box(zone).position + local * PortStructure.M()


func _inside(zone: String) -> Vector2:
	var dd: Array = PortStructure.door(zone)
	return (dd[0] as Vector2) + (dd[1] as Vector2) * 2.5 * PortStructure.M()


func _run() -> void:
	_career()
	await _spawn()
	await _frames(30)
	CV.ensure(g)
	var m := PortStructure.M()
	var c := PortStructure.centre()
	var home: Vector2 = g.drone.global_position
	var berth := _dock_rect()
	_put(berth.get_center(), _zoom_for(berth))
	_hide_ui()
	_beat(1, "F12 工作台 → 显示碰撞", "无人机能撞到的形状叠一层彩色：青=港区墙和设备，品红=只挡无人机的墙，琥珀=泊位的船")
	await _hold(1.0)
	CV.on = true
	await _hold(2.4)
	# berth: the truss right of the gate is drawn, nothing stops the drone there
	_beat(2, "船坞 B1：闸口右边的顶梁", "和左段一样画成亮桁架，左段有碰撞，右段能穿过")
	await _glide(berth.position + Vector2(berth.size.x * 0.72, berth.size.y * 0.2), _zoom_for(berth) * 1.6, 1.4, home)
	await _hold(2.0)
	# the corridor up to the ring and the ring
	_beat(3, "中央环 H1：外墙对得上", "内圈转盘和核心画得最亮，却整片能穿过")
	var hub := Rect2(c - Vector2.ONE * (PortArt.HUB_R + 4.0) * m, Vector2.ONE * (PortArt.HUB_R + 4.0) * 2.0 * m)
	await _glide(hub.get_center(), _zoom_for(hub), 2.0, c + Vector2(0, -20.0) * m)
	await _hold(1.6)
	# power: old machine blocks that the new art no longer draws, the lines before the battery berth
	_beat(4, "动力区：机器外壳基本对得上", "顶上白色蒸汽总管、竖管是管线，画得太亮（应调暗）")
	var pb := PortStructure.box("power").grow(4.0 * m)
	await _glide(pb.get_center(), _zoom_for(pb), 2.0, _inside("power"))
	await _hold(2.2)
	_beat(5, "动力区 P1/P2：电池泊位", "泊位框架亮实线却能穿过（应补）；下面的第二条灰线没有碰撞（应调暗）")
	await _glide(_z("power", Vector2(46.0, 1.0)), _zoom_for(pb) * 2.4, 1.2)
	await _hold(1.8)
	# tug
	_beat(6, "拖船站 T1/T2", "左边龙门架、甲板上停的拖船：亮实线都能穿过")
	var tb := PortStructure.box("tug").grow(4.0 * m)
	await _glide(tb.get_center(), _zoom_for(tb), 2.0, _inside("tug"))
	await _hold(2.0)
	# cargo
	_beat(7, "货运区 C1", "左货架的碰撞块盖住了火车轨道：画面上的通道其实是墙")
	var cb := PortStructure.box("cargo").grow(4.0 * m)
	await _glide(cb.get_center(), _zoom_for(cb), 2.0, _inside("cargo"))
	await _hold(2.0)
	# process, then home
	_beat(8, "加工区 X1/X2 → 回船坞", "观察廊（品红）对得上；电弧炉、轧机整台能穿过")
	var xb := PortStructure.box("process").grow(4.0 * m)
	await _glide(xb.get_center(), _zoom_for(xb), 2.0, _inside("process"))
	await _hold(1.8)
	await _glide(berth.get_center(), _zoom_for(berth), 1.6, home)
	await _hold(0.8)
	CV.on = false
	g.queue_free()
	await _frames(4)
	quit()
