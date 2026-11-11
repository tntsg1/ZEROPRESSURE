extends SceneTree
# 背景音乐系统 (scripts/music.gd，自动加载 Bgm): 场景→曲目、交叉淡化 3 s 内完成、危险叠加防抖、
# 音乐音量设置生效、同一首曲子续播、冷开场只放一次、老音乐被静音、真实游戏场景的读取。
# 只用测试文件: 设置文件指向 user://zp_test_music_settings.cfg（不写真实设置），存档用测试路径。
#   godot --headless --path . --fixed-fps 60 -s tests/music_check.gd
# 不碰鼠标、不抢焦点。

const TEST_CFG := "user://zp_test_music_settings.cfg"
var fails := 0
var bgm: Node


func _initialize() -> void:
	Txt.cfg_path = TEST_CFG
	Scan.ON = false
	Career.path = "user://zp_test_music_career.json"
	SaveGame.path = "user://zp_test_music_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


# 推进 secs 秒（1/60 一步）
func run(secs: float, ctx: Dictionary) -> void:
	var n := int(round(secs * 60.0))
	for i in n:
		bgm.step(1.0 / 60.0, ctx)


func settle_to(ctx: Dictionary) -> void:
	run(3.0, ctx)


func _run() -> void:
	bgm = root.get_node_or_null("Bgm")
	check(bgm != null, "自动加载 Bgm 存在")
	if bgm == null:
		quit(1)
		return
	bgm.set_process(false)       # 测试自己推进时间
	var S := {"scene": "salvage"}

	print("-- 循环设置")
	for n in ["title", "salvage", "port", "danger", "settle", "starmap"]:
		check(bgm.streams[n] != null and bgm.streams[n].loop, "%s 循环" % n)
	check(bgm.streams["cold_open"] != null and not bgm.streams["cold_open"].loop, "cold_open 不循环")
	check(bgm.players.size() == 2 and bgm.players[0].bus == &"Music" and bgm.players[1].bus == &"Music", "两个播放器都走 Music 总线")

	print("-- 场景→曲目")
	for pair in [["title", "title"], ["salvage", "salvage"], ["port", "port"], ["starmap", "starmap"], ["settle", "settle"]]:
		settle_to({"scene": pair[0]})
		check(bgm.playing_track() == pair[1] and bgm.players[bgm.cur].playing, "%s → %s" % pair)
	settle_to({"scene": "none"})
	check(bgm.playing_track() == "", "未知场景（测试场景）→ 无曲")

	print("-- 面板分类")
	check(Bgm_panel("res://scripts/star_map.gd", false) == "starmap", "星图面板 → starmap")
	check(Bgm_panel("res://scripts/order_settlement.gd", false) == "settle", "订单结算 → settle")
	check(Bgm_panel("res://scripts/disposal_panel.gd", false) == "settle", "回收物去向 → settle")
	check(Bgm_panel("res://scripts/warehouse_panel.gd", true) == "settle", "结算里的仓库 → settle")
	for p in ["res://scripts/terminal.gd", "res://scripts/store_panel.gd", "res://scripts/exchange_panel.gd", "res://scripts/hall_panel.gd"]:
		check(Bgm_panel(p, false) == "duck", "%s 只压低" % p.get_file())

	print("-- 交叉淡化 3 s 内完成")
	settle_to({"scene": "port"})
	var a: int = bgm.cur
	bgm.step(1.0 / 60.0, {"scene": "salvage"})
	check(bgm.playing_track() == "salvage" and bgm.cur != a, "切到 salvage: 用另一个播放器")
	check(bgm.players[a].playing and bgm.players[bgm.cur].playing, "淡化期间两个都在响")
	run(2.9, {"scene": "salvage"})
	check(is_equal_approx(bgm.gain[bgm.cur], 1.0), "2.9 s 内新曲淡到满")
	check(bgm.tracks[a] == "" and not bgm.players[a].playing, "2.9 s 内旧曲淡完并停掉")
	check(bgm.FADE >= 2.0 and bgm.FADE <= 3.0, "淡化时长 %.1f s 在 2–3 s 内" % bgm.FADE)

	print("-- 全屏面板只压低 4 dB，不换曲")
	settle_to(S)
	var base_db: float = bgm.players[bgm.cur].volume_db
	run(2.5, {"scene": "salvage", "duck": true})
	check(bgm.playing_track() == "salvage", "面板打开曲目不变")
	check(absf(bgm.players[bgm.cur].volume_db - (base_db - 4.0)) < 0.2, "压低约 4 dB（%.2f → %.2f）" % [base_db, bgm.players[bgm.cur].volume_db])
	run(2.5, S)
	check(absf(bgm.players[bgm.cur].volume_db - base_db) < 0.2, "面板关闭回升")

	print("-- 危险叠加防抖")
	settle_to(S)
	var D := {"scene": "salvage", "danger": true}
	run(1.5, D)
	run(0.5, S)
	check(bgm.playing_track() == "salvage" and not bgm.danger_active, "危险只持续 1.5 s 不切曲")
	run(1.9, D)
	check(bgm.playing_track() == "salvage", "持续 1.9 s 仍未切")
	run(0.3, D)
	check(bgm.playing_track() == "danger" and bgm.danger_active, "持续 2.2 s 切到 danger")
	run(3.0, D)
	check(is_equal_approx(bgm.gain[bgm.cur], 1.0), "danger 3 s 内淡满")
	run(5.0, S)
	check(bgm.playing_track() == "danger", "解除 5 s 仍保持 danger")
	run(0.5, D)          # 解除途中又来危险: 计时重来
	run(5.5, S)
	check(bgm.playing_track() == "danger", "危险复现后重新计 6 s")
	run(0.7, S)
	check(bgm.playing_track() == "salvage", "解除满 6 s 切回 salvage")
	run(3.0, S)
	check(is_equal_approx(bgm.gain[bgm.cur], 1.0), "salvage 回淡满")
	# 非拆船场景不叠危险
	settle_to({"scene": "port", "danger": true})
	run(5.0, {"scene": "port", "danger": true})
	check(bgm.playing_track() == "port", "港区里不会叠 danger")

	print("-- 同一首曲子续播")
	settle_to(S)
	await create_timer(0.8).timeout        # 真实时间过一会儿，播放位置才会往前走
	bgm.step(1.0 / 60.0, {"scene": "port"})
	var sal_player: AudioStreamPlayer = bgm.players[1 - bgm.cur]
	var left_at: float = sal_player.get_playback_position()
	run(3.0, {"scene": "port"})
	var saved: float = bgm.pos.get("salvage", -1.0)
	check(saved > 0.1, "断开时记下位置 %.2f s" % saved)
	bgm.step(1.0 / 60.0, S)
	var back: float = bgm.players[bgm.cur].get_playback_position()
	check(bgm.playing_track() == "salvage" and back >= saved - 0.05 and back < saved + 1.0, "切回从 %.2f s 续播（记录 %.2f s）" % [back, saved])
	settle_to(S)

	print("-- 音乐音量设置生效")
	var keep := [Txt.vol_master, Txt.vol_music, Txt.vol_sfx]
	Txt.vol_master = 1.0
	Txt.vol_music = 0.5
	Settings.apply_audio()
	var mi := AudioServer.get_bus_index("Music")
	check(mi >= 0 and absf(AudioServer.get_bus_volume_db(mi) - (Settings.MUSIC_DB + linear_to_db(0.5))) < 0.01, "音乐 50%% → Music 总线 %.2f dB" % AudioServer.get_bus_volume_db(mi))
	Txt.vol_music = 0.0
	Settings.apply_audio()
	check(AudioServer.is_bus_mute(mi), "音乐 0 → Music 总线静音")
	Txt.vol_music = 0.8
	Settings.apply_audio()
	check(not AudioServer.is_bus_mute(mi) and AudioServer.get_bus_send(mi) == &"Master", "音乐 80% → 总线恢复，仍送到 Master")
	Txt.vol_master = keep[0]
	Txt.vol_music = keep[1]
	Txt.vol_sfx = keep[2]
	Settings.apply_audio()

	print("-- 冷开场只播一次，接着淡入下一首")
	settle_to({"scene": "none"})
	var C := {"scene": "salvage", "cold": true}
	settle_to(C)
	check(bgm.playing_track() == "cold_open" and not bgm.streams["cold_open"].loop, "冷开场 → cold_open（不循环）")
	var cp: AudioStreamPlayer = bgm.players[bgm.cur]
	cp.seek(bgm.streams["cold_open"].get_length() - 1.5)
	bgm.step(1.0 / 60.0, C)
	check(bgm.playing_track() == "salvage", "放到尾声 → 淡入 salvage")
	run(3.0, C)
	check(bgm.playing_track() == "salvage", "冷开场没结束标记也不再重放")
	settle_to({"scene": "salvage"})
	settle_to(C)
	check(bgm.playing_track() == "cold_open", "下一次冷开场重新播（标记在退出后复位）")
	settle_to({"scene": "salvage"})

	print("-- 老音乐被静音（sfx.gd 不改）")
	var sfx := Sfx.new()
	root.add_child(sfx)
	await frames(2)
	var amb = sfx.loops.get("ambience")
	check(amb == null or (amb.stream == null and not amb.playing), "Sfx 的 ambience (main.ogg) 已停")
	check(sfx.ending_player == null or (sfx.ending_player.stream == null and not sfx.ending_player.playing), "Sfx 的 ending_player (ending.ogg) 已停")
	sfx.queue_free()

	print("-- 真实游戏场景")
	await _game_scene()

	Txt.cfg_path = Txt.CFG
	print("music_check: %s (%d fail)" % ["FAIL" if fails > 0 else "PASS", fails])
	quit(1 if fails > 0 else 0)


func Bgm_panel(path: String, flag: bool) -> String:
	return bgm.get_script().panel_kind(path, flag)


func _game_scene() -> void:
	Game.contract = {}
	Game.start_ship = "berth"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {}}
	root.add_child(g)
	current_scene = g
	await frames(10)
	var inside: Vector2 = Vector2(Dock.centre().x, Dock.RAIL_Y + 8.0) * Geom.M
	g.drone.global_position = inside
	var c: Dictionary = bgm._ctx(true)
	check(c.scene == "salvage" and not c.duck, "泊位里的拆船区 → salvage（%s）" % c.scene)
	g.drone.global_position = PortStructure.centre()
	c = bgm._ctx(true)
	check(c.scene == "port", "出了闸门，港区环 → port（%s）" % c.scene)
	g.drone.global_position = inside
	g.console_ui = Control.new()
	c = bgm._ctx(true)
	check(c.scene == "salvage" and c.duck, "全屏面板打开 → 不换曲、压低")
	g.console_ui.free()
	g.console_ui = null
	g.state = "ending"
	check(bgm._ctx(true).scene == "settle", "合同结束的 ending 画面 → settle")
	g.state = "play"
	check(not bgm._ctx(true).get("danger", true), "平静时没有危险")
	# 真实的实时循环: 自动加载自己读场景，几帧之后在响 salvage
	bgm.set_process(true)
	await create_timer(0.6).timeout
	check(bgm.playing_track() == "salvage", "自动加载自己读场景 → salvage（%s）" % bgm.playing_track())
	bgm.set_process(false)
	current_scene = null
	g.queue_free()
	await frames(3)
