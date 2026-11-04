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
	Career.save()
	check(Mainline.chapter() == "lights" and Mainline.step().go == "guide:repair:lights" and str(Mainline.step().text).find("照明") >= 0, "the opening done: mend the lights (%s)" % Mainline.step().text)
	await _spawn()
	await _frames(20)
	Cap.save(root, "res://tests/out/mainline_hud_zh.png")
	check(g.hud.main_go.visible, "the empty berth shows the main line and its 'take me' key")
	g.hud.main_go.pressed.emit()
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
	check(Mainline.chapter() == "trade" and Mainline.step().go == "guide:build:salvage", "the berth mended: the trade port, which waits on the salvage district first (%s)" % Mainline.step().text)
	Career.data.port = {"salvage": 1, "trade": 1}
	check(Mainline.chapter() == "steel" and Mainline.step().go == "guide:build:process", "the trade port open: steel, and the processing district first (%s)" % Mainline.step().text)
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	# 64 号: with no ingots yet the next step is another ship (its scrap becomes ingots), not buying feed — 68 号: found by sweeping the belt on the star map
	check(Mainline.chapter() == "steel" and (str(Mainline.step().go).begins_with("guide:") or str(Mainline.step().go) in ["contracts", "scan"]), "processing up: the steel guide's first step (%s)" % Mainline.step().go)
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(float(Career.data.money))
	Career.data.exchange.trades.append({"id": "T-FIX", "buyer": "merchant_01", "seller": "company", "state": "delivered", "item": "steel_billet", "grade": 1, "quantity": 1.0, "price": 1000.0})
	check(Mainline.chapter() == "industry" and Mainline.step().go == "guide:build:cargo", "billets sold: the cargo district next")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1}
	# 123 号 (user "先修拖船站"): power and the tug station before the 88 m berth
	check(Mainline.chapter() == "power_tug", "then power and the tug station")
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1}
	check(Mainline.chapter() == "berth88" and Mainline.step().go == "guide:repair:berth88", "then the berth to 88 m")
	Career.data.upgrades["berth88"] = true
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1, "ring": 2}
	check(Mainline.chapter() == "ark" and Mainline.step().go == "wait", "the ring restarted: the Ark waits for a later version")
	g.queue_free()
	await _frames(4)
	print("MAINLINE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
