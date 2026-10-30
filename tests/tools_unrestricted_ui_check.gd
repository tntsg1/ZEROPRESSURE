extends "res://tests/g5_heat_ui_visual.gd"
# Native layout/navigation checks. Declared career fixture; no human play claim.
func run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_tools_unrestricted_ui_career.json"
	SaveGame.path = "user://zp_test_tools_unrestricted_ui_field.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.active = {"id":"NO-PARTS-UI","ship":"tug","kit":{},"items":{}}
	Career.data.market = true
	Career.data.money = 100000.0
	Career.data.port = {"trade":1,"process":1,"cargo":2}
	Txt.zh = true
	await spawn()
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.content_scale_size = size
		root.size = size
		g.open_console("terminal")
		await frames(4)
		var terminal = g.console_ui
		terminal.set_tab(3)
		await frames(50)
		check(Txt.t("app_skills") == "工具与技术" and terminal.tech_panel.visible,"permanent techniques page remains available without a parts-shop title")
		var panel := LoadoutPanel.open(terminal,func(): pass,func(): pass)
		await frames(8)
		var buttons: Array = panel.find_children("*","Button",true,false)
		check(not buttons.any(func(button):return button.text.contains("先锋型") or button.text.contains("工业型") or button.text.contains("精工型")),"loadout no longer presents recurring tool-part tier purchase/fitting buttons at "+str(size))
		var labels: Array = panel.find_children("*","Label",true,false)
		check(labels.any(func(label):return label.text.contains("基础工具持续可用")),"loadout clearly explains tools require no fitted consumables")
		await capture("tools_unrestricted_loadout_%dx%d" % [size.x,size.y])
		panel.queue_free()
		await frames(3)
		terminal.close()
		await frames(4)
	await release()
	print("TOOLS UNRESTRICTED UI %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
