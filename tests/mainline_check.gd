extends "res://tests/guide_check.gd"
# 28 号 Q16–Q21: the main line — fixed chapters, the next step worked out from the state, shown
# in the empty berth's corner and first on the terminal's goal strip; "take me" starts the guide.
#   tools/run_test.sh tests/mainline_check.gd --fixed-fps 60


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.save()
	check(Mainline.chapter() == "opening" and Mainline.step().go == "contracts", "a new career: chapter 1, take the hulk waiting (%s)" % Mainline.step().text)
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 1000000.0
	Career.data.upgrades = {}
	# 128 号 第 1 段: the opening is done once the first haul is in the stores and the first sale made
	Career.data.seen = {"store_guide_done": true}
	Career.save()
	check(Mainline.chapter() == "lights" and Mainline.step().go == "guide:repair:lights" and str(Mainline.step().text).find("照明") >= 0, "the opening done: mend the lights (%s)" % Mainline.step().text)
	await _spawn()
	await _frames(20)
	Cap.save(root, "res://tests/out/mainline_hud_zh.png")
	# 128 号 第 3 段: one voice — the strip, and its one target mark on the fault not yet looked at
	check(g.hud.voice != null and g.hud.voice.visible and g.hud.need_mark.target.distance_to(RepairShow.spot("lights")) < 1.0, "the empty berth shows the main line and its one target mark")
	Mainline.take_me(g, str(Mainline.step().go))
	await _frames(10)
	check(g.guide.task == "repair" and str(g.guide.start.get("target", "")) == "lights", "take me: the repair guide, on the lights")
	g.guide.stop()
	# the terminal's goal strip: the main line first, a click on it starts the same
	g.open_console("terminal")
	await _frames(6)
	g.console_ui._skip_boot()
	await _frames(20)
	Cap.save(root, "res://tests/out/mainline_terminal_zh.png")
	g.console_ui._open_goal(0)
	await _frames(10)
	check(g.console_ui == null and g.guide.task == "repair", "the goal strip's first place is the main line; a click takes the operator there")
	g.guide.stop()
	# the chapters move on with the state
	Career.data.upgrades = {"lights": true, "furnace_main": true, "net_fix": true}
	Career.data.port = {}
	check(Mainline.chapter() == "trade" and Mainline.step().go == "guide:build:trade", "the berth mended: the trade port (128 号 第 3 段: no longer behind the salvage district) (%s)" % Mainline.step().text)
	# 128 号 第 3 段: each chapter starts when its need comes up (C: the first by number of those up)
	Career.data.port = {"salvage": 1, "trade": 1}
	check(Mainline.chapter() == "" and Mainline.next_open() == "process", "the trade port open: the processing district waits for 2 t of ingots")
	Career.data.need_hit = {"process": 1}
	check(Mainline.chapter() == "process" and Mainline.step().go == "guide:build:process", "ingots enough: the processing district (%s)" % Mainline.step().text)
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	# 64 号: with no ingots yet the next step is another ship (its scrap becomes ingots), not buying feed — 68 号: found by sweeping the belt on the star map
	check(Mainline.chapter() == "process" and (str(Mainline.step().go).begins_with("guide:") or str(Mainline.step().go) in ["contracts", "scan", "drill", ""]), "processing up: the first heat's step (%s)" % Mainline.step().go)
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(float(Career.data.money))
	Career.data.exchange.trades.append({"id": "T-FIX", "buyer": "merchant_01", "seller": "company", "state": "delivered", "item": "steel_billet", "grade": 1, "quantity": 1.0, "price": 1000.0})
	Career.data.need_hit = {"cargo": 1}
	check(Mainline.chapter() == "cargo" and Mainline.step().go == "guide:build:cargo", "billets made, the stores nearly full: the cargo district")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1}
	Career.data.need_hit = {"power": 1, "tug": 1}
	check(Mainline.chapter() == "power", "then power, the first slowdown")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1}
	check(Mainline.chapter() == "tug", "then the tug station, a hulk over 44 m")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1}
	Career.data.need_hit = {}
	Career.data.offers = []
	g.hud._main_c = {}
	var idle: Dictionary = g.hud._main()
	check(Mainline.next_open() == "berth88" and idle.chapter == "" and idle.step.go == "scan", "before a big ship is found, the HUD shows finding ships without a chapter number")
	Career.data.offers = [{"id": "LONG", "ship": "ev55", "find": true}]
	check(Mainline.chapter() == "berth88" and Mainline.step().go == "guide:repair:berth88", "then the berth to 88 m, a hulk too long for it")
	Career.data.upgrades["berth88"] = true
	check(Mainline.chapter() == "ring", "every district up: the transfer ring")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1, "ring": 2}
	check(Mainline.chapter() == "ark" and Mainline.step().go == "wait", "the ring restarted: the Ark waits for a later version")
	g.queue_free()
	await _frames(4)
	print("MAINLINE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
