extends "res://tests/record108.gd"
# 2026-11-05 图鉴卡“全息档案”，约 30 秒：现场弹出首次遇见卡（扫描刷出、标题升起），热管线、舱压、电缆三张
# 示意图在动；再打开图鉴书（I）翻几条。只用测试存档，真实鼠标不动。
#   tools/run_test.sh tests/record_codex_card.gd --write-movie recordings/record_codex_card.avi --fixed-fps 30


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_record_codex_career.json"
	SaveGame.path = "user://zp_test_record_codex_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _card(id: String) -> void:
	Codex.mark(id)
	g.codex.card = id
	g.codex.card_t = 0.0
	g.codex.last = id


func _run() -> void:
	cap_total = 4
	_caption_layer()
	Txt.reduce_motion = false
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.save()
	await _spawn()
	await _secs(1.0)
	# a few met already, so the book has pages to turn
	for id in ["s_heat", "s_fire", "s_gas", "s_power", "cable", "pipe_line", "valve", "bolt", "lock", "clamp", "m_hypergolic", "m_o2_flash"]:
		Codex.mark(id)
	_beat(1, "首次遇见：扫描光刷出全息档案", "标题从线后升起；左上角条目编号与分类；热管线发红，热浪把网格扭弯")
	_card("s_heat")
	await _secs(6.0)
	g.codex.card = ""
	await _secs(0.6)
	_beat(2, "危险 3 格：卡片边缘慢慢闪橙光", "舱压：气体一圈圈往外扩散；“危险”下面是等级条")
	_card("s_gas")
	await _secs(5.5)
	g.codex.card = ""
	await _secs(0.6)
	_beat(3, "电缆：电流光点沿线跑，接头冒火花", "关闭倒计时是一条流动的细光线")
	_card("cable")
	await _secs(5.0)
	g.codex.card = ""
	await _secs(0.5)
	_beat(4, "按 I 打开图鉴书：同一张图同样会动", "火灾换成了跳动的火焰图；真实设备线稿有呼吸和扫描光")
	g.codex_hud.open_book("s_heat")
	await _secs(1.8)
	var page = g.codex_hud.page
	if page != null:
		# only met entries (they are listed first): walk them from the top
		var met: int = page.rows().filter(func(x): return Codex.seen(x)).size()
		for i in 3:
			page._pick((page.sel + 1) % maxi(1, met))
			await _secs(1.6)
		page._set_cat(page.cat - 3)
		await _secs(1.6)
		page._pick(page.sel + 1)
		await _secs(1.6)
	print("RECORD CODEX CARD DONE")
	quit()
