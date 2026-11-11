extends Node
# 背景音乐系统 (2026-11-11, 用户的 7 首 AI 生成 downtempo): 自动加载 "Bgm"。
# 两个 AudioStreamPlayer 在 "Music" 总线上交叉淡化，所以设置里的“音乐”音量照常生效。
#   title      标题画面
#   salvage    拆船现场（有合同的船、或泊位里的拆船区）
#   port       港区：飞行、港区面板、终端首页
#   starmap    星图 / 找船页
#   settle     结算（订单结算、回收物去向、合同结束的 ending 画面）
#   cold_open  冷开场电影，只播一次
#   danger     拆船时的明确危险，盖过 salvage（防抖：持续 2 s 才切入，解除 6 s 才切回）
# 全屏面板（终端、仓库、交易行……）不换曲，只压低 4 dB。
# 同一首曲子来回切时从断开处续播。sfx.gd 老的 main.ogg / ending.ogg 在这里被静音（sfx.gd 不改）。
# 测试：Bgm.step(dt, ctx) 可以脱离场景树直接推进；ctx 的写法见 _ctx()。

const GuideWayRef = preload("res://scripts/guide_way.gd")
const DIR := "res://assets/music/bgm/"
const NAMES := ["title", "salvage", "port", "danger", "settle", "cold_open", "starmap"]
const NO_LOOP := ["cold_open"]
const FADE := 2.5               # s 曲间交叉淡化
const DUCK_DB := -4.0           # 全屏面板压低
const DUCK_RATE := 2.0          # s 压低 / 回升用时
const DANGER_ON := 2.0          # s 危险持续这么久才切过去
const DANGER_OFF := 6.0         # s 解除后至少保持这么久才切回
const SEAM := 1.2               # s 循环接缝处的淡出淡入，免得首尾不顺时突兀
const POLL := 0.25              # s 危险判断的间隔
const TRIM := {}                # 各曲的音量微调 (dB)，需要时再填

var streams := {}
var players: Array[AudioStreamPlayer] = []
var tracks := ["", ""]          # 每个播放器在放哪首
var gain := [0.0, 0.0]          # 0..1 的淡化进度
var want := [0.0, 0.0]
var cur := 0                    # 正在淡入（或已满）的播放器
var cur_track := ""
var pos := {}                   # 曲名 -> 断开时的位置 (s)
var duck_now := 0.0
var danger_active := false
var _on_t := 0.0
var _off_t := 0.0
var _cold_done := false
var _poll_t := 0.0
var _danger_raw := false
var ctx_override = null         # 测试：给一个 Dictionary 就不读场景树
var last_ctx := {}
var last_want := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.apply_audio()
	var bus := "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
	for n in NAMES:
		var s = load(DIR + n + ".mp3")
		if s is AudioStreamMP3:
			s.loop = not n in NO_LOOP
		streams[n] = s
	# 老的音乐在 sfx.gd 里创建: 每个 Sfx 出生后把它们关掉
	get_tree().node_added.connect(_on_node)
	_hush_all(get_tree().root)


func _on_node(n: Node) -> void:
	if n is Sfx:
		_hush.call_deferred(n)


func _hush_all(n: Node) -> void:
	if n is Sfx:
		_hush(n)
	for c in n.get_children():
		_hush_all(c)


# sfx.gd 的 "ambience"（main.ogg）和 ending_player（ending.ogg）: 停掉并拿走流，它不会再启动
func _hush(s) -> void:
	if not is_instance_valid(s):
		return
	var a = s.loops.get("ambience")
	if a != null:
		a.stop()
		a.stream = null
	if s.ending_player != null:
		s.ending_player.stop()
		s.ending_player.stream = null


func _process(dt: float) -> void:
	if ctx_override != null:
		step(dt, ctx_override)
		return
	_poll_t += dt
	var ctx := _ctx(_poll_t >= POLL)
	if _poll_t >= POLL:
		_poll_t = 0.0
	step(dt, ctx)


# ---------------------------------------------------------------- 读场景
# ctx: {"scene": "title|salvage|port|starmap|settle|none|keep", "duck": bool, "cold": bool, "danger": bool}
func _ctx(poll: bool) -> Dictionary:
	var cs := get_tree().current_scene
	if cs == null:
		return {"scene": "keep"}          # 换场景的空档: 维持现状
	var sc = cs.get_script()
	var path: String = sc.resource_path if sc != null else ""
	if path.ends_with("title_terminal.gd") or path.ends_with("/title.gd"):
		return {"scene": "title"}
	if path.ends_with("/terminal.gd"):
		return {"scene": "port"}
	if cs is Game:
		return _game_ctx(cs, poll)
	return {"scene": "none"}


func _game_ctx(g: Game, poll: bool) -> Dictionary:
	var c := {"scene": "salvage", "duck": false, "cold": false, "danger": _danger_raw}
	var settle: bool = g.state == "ending" or _alive(g.order_review) or _alive(g.get("disposal_ui"))
	var ui = g.console_ui
	if not settle and _alive(ui):
		var p: String = ui.get_script().resource_path if ui.get_script() != null else ""
		match panel_kind(p, ui.get("settle") == true):
			"starmap":
				c.scene = "starmap"
				return c
			"settle":
				settle = true
			_:
				c.duck = true
	if settle:
		c.scene = "settle"
		return c
	c.scene = _world_scene(g)
	var pr = g.get("prologue")
	if pr != null and is_instance_valid(pr):
		var cold = pr.get("cold")
		if cold != null and is_instance_valid(cold) and cold.phase == "film":
			c.cold = true
	if poll:
		_danger_raw = c.scene == "salvage" and _danger(g)
		c.danger = _danger_raw
	return c


# 全屏面板按脚本路径分: 星图→换星图曲，结算类→结算曲，其余只压低
static func panel_kind(path: String, settle_flag := false) -> String:
	if path.ends_with("star_map.gd"):
		return "starmap"
	if settle_flag or path.ends_with("order_settlement.gd") or path.ends_with("disposal_panel.gd"):
		return "settle"
	return "duck"


func _alive(o) -> bool:
	return o != null and is_instance_valid(o)


# 泊位里：无人机在拆船区就是拆船，出了闸门就是港区；有合同的船一律是拆船
func _world_scene(g: Game) -> String:
	if not g.in_berth():
		return "salvage"
	if g.drone == null or not is_instance_valid(g.drone):
		return "port"
	return "salvage" if GuideWayRef._where(g.drone.global_position)[0] == "berth" else "port"


# 明确的危险: 舱压未泄就在切墙、射束靠近堆芯、射束在推进剂云里、电力严重不足时在切、核爆过场
func _danger(g: Game) -> bool:
	if g.state == "nuke":
		return true
	if g.state != "play" or g.tools == null:
		return false
	var tl = g.tools
	var r = g.reactor
	if r != null and is_instance_valid(r) and float(r._warn_k) > 0.05:
		return true
	if not tl.cutting:
		return false
	var at: Vector2 = tl.front
	var w = g.world
	if w != null and g.sys != null:
		for q in w.pieces_at(at):
			if q.body == null and q.barrier and g.assist != null:
				for room in g.assist._rooms_beside(q):
					if g.sys.P(room) > Systems.SAFE_KPA:
						return true
				break
	if g.sys != null:
		for cl in g.sys.clouds:
			if cl.pos.distance_to(at) < cl.r + 2.0 * Geom.M:
				return true
	if Grid.applies(g) and (not g.career() or Mainline.power_open()):
		var gn: Dictionary = Grid.groups_now(g).get("salvage", {})
		var need := float(gn.get("want", 0.0))
		var got := float(gn.get("own", 0.0)) + float(gn.get("shore", 0.0))
		if need > 0.0 and got < need * 0.5:
			return true
	return false


# ---------------------------------------------------------------- 推进
func step(dt: float, ctx: Dictionary) -> void:
	last_ctx = ctx
	var scene: String = ctx.get("scene", "none")
	if scene == "keep":
		_advance(dt, last_want, ctx)
		return
	var t := ""
	match scene:
		"title", "salvage", "port", "starmap", "settle":
			t = scene
	# 冷开场: 放一次，快放完时把位置让给下一首
	if ctx.get("cold", false):
		if not _cold_done and t != "":
			t = "cold_open"
	else:
		_cold_done = false
	if t == "cold_open" and cur_track == "cold_open" and _cold_left() <= FADE:
		_cold_done = true
		t = scene
	# 危险叠加的防抖
	if scene != "salvage":
		_on_t = 0.0
		_off_t = 0.0
		danger_active = false
	elif ctx.get("danger", false):
		_on_t += dt
		_off_t = 0.0
		if _on_t >= DANGER_ON:
			danger_active = true
	else:
		_off_t += dt
		_on_t = 0.0
		if _off_t >= DANGER_OFF:
			danger_active = false
	if danger_active and t == "salvage":
		t = "danger"
	last_want = t
	_advance(dt, t, ctx)


func _advance(dt: float, t: String, ctx: Dictionary) -> void:
	if t != cur_track:
		# 上一次还没淡完的那首被占用着: 等它淡到接近静音再换，免得突然被切断
		var other := 1 - cur
		if tracks[other] == "" or gain[other] <= 0.2:
			_switch(t)
	elif t != "" and tracks[cur] == t:
		want[cur] = 1.0
	var duck_to := DUCK_DB if ctx.get("duck", false) else 0.0
	duck_now = move_toward(duck_now, duck_to, absf(DUCK_DB) / DUCK_RATE * dt)
	for i in 2:
		gain[i] = move_toward(gain[i], want[i], dt / FADE)
		var p := players[i]
		if tracks[i] == "":
			continue
		if gain[i] <= 0.0 and want[i] <= 0.0:
			_release(i)
			continue
		if not p.playing:
			# 冷开场放完了，或者非循环曲目结束
			if tracks[i] == "cold_open":
				_cold_done = true
			_release(i)
			continue
		p.volume_db = _db(i)


func _db(i: int) -> float:
	var amp := sin(clampf(gain[i], 0.0, 1.0) * PI * 0.5)      # 等功率: 一首的淡出和另一首的淡入合起来响度平稳
	var s: AudioStream = streams.get(tracks[i])
	var seam := 1.0
	if s != null and s.get_length() > SEAM * 4.0 and not tracks[i] in NO_LOOP:
		var pp := players[i].get_playback_position()
		var d := minf(pp, s.get_length() - pp)
		seam = smoothstep(0.0, 1.0, clampf(d / SEAM, 0.0, 1.0))
	return linear_to_db(maxf(amp * seam, 0.0001)) + duck_now + float(TRIM.get(tracks[i], 0.0))


func _switch(t: String) -> void:
	var other := 1 - cur
	_release(other)
	want[cur] = 0.0
	cur = other
	cur_track = t
	if t == "" or streams.get(t) == null:
		cur_track = t
		return
	tracks[cur] = t
	gain[cur] = 0.0
	want[cur] = 1.0
	var p := players[cur]
	p.stream = streams[t]
	var at: float = pos.get(t, 0.0)
	var len: float = streams[t].get_length()
	if t in NO_LOOP or at >= len - FADE:
		at = 0.0
	p.volume_db = -80.0
	p.play(at)


# 淡完了: 记下位置，停掉
func _release(i: int) -> void:
	if tracks[i] == "":
		return
	var p := players[i]
	if p.playing:
		pos[tracks[i]] = p.get_playback_position()
	p.stop()
	p.stream = null
	tracks[i] = ""
	gain[i] = 0.0
	want[i] = 0.0


func _cold_left() -> float:
	if tracks[cur] != "cold_open" or not players[cur].playing:
		return 0.0
	return streams["cold_open"].get_length() - players[cur].get_playback_position()


func playing_track() -> String:
	return cur_track
