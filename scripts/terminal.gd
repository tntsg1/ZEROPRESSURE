class_name Terminal
extends Control
# The berth terminal between contracts (full screen): money, loan,
# installment and reputation always along the top; three tabs — the contract
# market (three offer cards, "take" under the chosen one), the equipment shop
# (the drone and the berth drawn in line, each upgrade on the part it
# replaces; consumables in a grid; the chosen thing's detail and its buy
# button on the right, with what is left after and what the next contract
# fee would borrow), berth management (the loan with a repay slider,
# training replay, what opens later in one line).
# Keys: 1 2 3 4 tabs, ← → pick, ↑ ↓ quantity / amount, Enter take/buy, Esc title.

const TABS := ["market", "shop", "berth", "skills"]
# what can be bought: [id, kind, price, Txt name key, Txt effect key]
# the first four are fitted (drawn on the drone and the berth), the rest are stock
const SHOP := [
	["scan_kit", "upgrade", 24000.0, "up_scan", "up_scan_d"],
	["grapple5", "upgrade", 38000.0, "up_grapple", "up_grapple_d"],
	["pump2", "upgrade", 22000.0, "up_pump", "up_pump_d"],
	# 2026-11-10 量子隧穿效应: late, dear (LATE), after the 5 t grapple; not on the drone drawing (DRONE_UPGRADES)
	["tunnel", "upgrade", 480000.0, "up_tunnel", "up_tunnel_d"],
	# 2026-11-11 量子隧穿·机体: the same stage, dearer, after the grapple's tunnelling (Jev: 120 万)
	["tunnel_body", "upgrade", 1200000.0, "up_tunnel_body", "up_tunnel_body_d"],
	["arm", "facility", 65000.0, "fa_arm", "fa_arm_d"],
	["repair", "item", 3000.0, "it_repair", "it_repair_d"],
	["ring", "item", 9000.0, "it_ring", "it_ring_d"],
	["spare", "item", 15000.0, "it_spare", "it_spare_d"],
	["intel", "item", 6000.0, "it_intel", "it_intel_d"],
]
const FITTED := 6
const DRONE_UPGRADES := 3
# now → after, per upgrade: [label key, now, after, now 0..1, after 0..1] ("sh_" values are Txt keys)
const STATS := {
	"scan_kit": [["sh_cond", "sh_none", "sh_shown", 0.0, 1.0], ["sh_hidden", "sh_unseen", "sh_found", 0.0, 1.0]],
	"grapple5": [["sh_grab", "3 t", "5 t", 0.6, 1.0]],
	"pump2": [["sh_gas", "1×", "2×", 0.5, 1.0], ["sh_fluid", "1×", "2×", 0.5, 1.0]],
	"arm": [["sh_auto", "sh_none", "≤ 1 t", 0.0, 0.5]],
}
const USE_KEY := {"repair": "6", "ring": "7", "spare": "", "intel": "I"}
const BERTH := [
	["repay", "loan", 20000.0, "tm_repay", "tm_repay_d", true],
	["training", "training", 0.0, "tm_training", "tm_training_d", true],
	["mouth_rail", "facility", 30000.0, "fa_rail", "fa_rail_d", true],
	["net05", "facility", 18000.0, "fa_net", "fa_net_d", true],
	["hauler", "facility", 45000.0, "fa_hauler", "fa_hauler_d", true],
	["berth88", "facility", 240000.0, "fa_berth", "fa_berth_d", true],
	["berth120", "facility", 520000.0, "fa_berth120", "fa_berth120_d", true],
	["berth200", "facility", 1200000.0, "fa_berth200", "fa_berth200_d", true],
	["berth620", "facility", 4500000.0, "fa_berth620", "fa_berth620_d", true],
	["hauler2", "facility", 60000.0, "fa_hauler2", "fa_hauler2_d", true],
	["crane", "facility", 150000.0, "fa_crane", "fa_crane_d", true],
	["port2", "facility", 50000.0, "fa_port2", "fa_port2_d", true],
	["buffer", "facility", 30000.0, "fa_buffer", "fa_buffer_d", true],
	["zones", "facility", 20000.0, "fa_zones", "fa_zones_d", true],
	["gas_line", "facility", 80000.0, "fa_gas_line", "fa_gas_line_d", true],
	["lox_tank", "facility", 60000.0, "fa_lox_tank", "fa_lox_tank_d", true],
]
# a facility that only makes sense with another one bought first
# late upgrades: [completed jobs, reputation] before they can be bought
const LATE := {"tunnel": [20, 30], "tunnel_body": [20, 30]}
const REQUIRES := {"tunnel": "grapple5", "tunnel_body": "tunnel", "hauler2": "hauler", "berth120": "berth88", "berth200": "berth120", "berth620": "berth200"}
# The terminal is one device (P.7 structure A, player 2026-10-18): a home screen
# of apps; on site the same device, opened by its key or at the berth's
# computer, with what can't be used there locked and the reason written on it.
const HOME := -1
const Back := preload("res://scripts/ui_back.gd")
const DRONE_PAGE := 8
# [the page it opens, its name] in tile order; keys 1–4 open them
# 53 号 (player 2026-10-25): radio, ledger, supplies and tools & techniques taken off, "no use"
# user 2026-10-26: "把训练舱先关掉…这是主线必练的" — no training page; the courses come with the ships
const APPS := [[0, "app_contracts"], [1, "app_equip"], [5, "app_route"], [DRONE_PAGE, "app_drone"]]
const ON_SITE := [3, 4, 5, 6]     # what works in the middle of a job
# what berth management will offer later, named in one line
const LATER := ["fa_scan"]
const REPAY_STEP := 5000.0

var font: Font
var font_l: Font
var font_b: Font
var font_s: Font
var t := 0.0
var tab := 0
var sel := 0
var focus_offer := ""      # opened from a hulk's arrival: its card selected
var hover := -1
var hover_tab := -1
var hover_go := false
var hover_next := false      # 61 号: the home's "take me" on the next step
var _next_action := false
var flash := 0.0
var msg := ""
var msg_t := 9.0
var leaving := -1.0
var radio := Radio.new()
var testing := false
var settings: SettingsPanel
var milestone := -1.0      # the loan-paid-off moment on screen (seconds), -1 when not
# motion: everything on springs and rollers, stepped once a frame
var tab_x := Motion.Spring.new(0.0, 320.0, 0.82)    # the tab underline slides
var tab_w := Motion.Spring.new(216.0, 320.0, 0.82)
var hover_k: Array = []    # per card / row: 0..1 lift
var sel_k: Array = []      # per card / row: 0..1 chosen
var deal_t := 0.0          # since the cards were dealt (re-dealt on every tab)
# the self-test each time the terminal comes up (P.7, ~2 s; any key or click skips it)
const BOOT_T := 2.0
var boot_t := 0.0
var money_roll := Motion.Roller.new(0.0, 9.0)
var loan_roll := Motion.Roller.new(0.0, 9.0)
var money_flash := 0.0     # >0 up (ink), <0 down (heat)
var loan_flash := 0.0
var sparks: Array = []     # [from, to, t, delay] little lights flying to the funds
var sweep := {}            # row index -> t: a bright pass across a row that was bought
var leave_from := Rect2()  # the card that grows into the screen when a contract is taken
var dust: Array = []
var intel_t := {}          # offer id -> seconds since its survey report came in
var qty := 1               # how many of a consumable
var repay_amt := 20000.0   # the repay slider
var dragging := false
var shake := 0.0           # the button jolts when it could not act
var install := {}          # upgrade id -> seconds since it was fitted (the part goes on)
var remote_box: HBoxContainer   # 108 号: the remote jobs along the foot
var go_x := Motion.Spring.new(0.0, 300.0, 0.8)   # the take button follows the chosen card
var hover_minus := false
var hover_plus := false
var thumbs := {}           # offer id -> what its cross-section shows (worked out once)
var leave_offer := {}      # the offer being taken (it leaves the market as it is signed)
# opened on site from one of the berth's two consoles (game.open_console): only the
# shop and berth pages, Esc closes it and play goes on; what is bought there
# counts from the next contract
var overlay := false
var keep_on_close := false   # 91 号: the game folds the screen away itself
var berth_view: BerthView = null   # 91 号: the home screen's live section of the berth and its ship
var on_close: Callable
var on_skill_changed: Callable
var book: SkillBook = null    # withdrawn (G3); kept null so the old page code stays inert
var tech_panel: Control = null  # techniques and consumable parts (scripts/tech_panel.gd)
var next_job := {}         # an opening contract still to play: the market shows it, alone
var loadout: Control = null   # the loadout page over the terminal (scripts/loadout_panel.gd), while it is open
var repair_panel: Control = null   # the run-down berth's damage list and parts shelf (scripts/repair_panel.gd): the equipment page
var loadout_in_tests := false  # a test that wants the page sets this
var show_trials := false       # the market page turned to the three trial contracts (T)
var _trial_cards: Array = []   # the trial offers as cards, drawn once per visit
var game_ref = null        # the contract in play, when opened over the berth
var between := false       # opened over the empty berth, between contracts: nothing is locked
var hover_home := false
var hover_cell := -1          # the home screen's overview (scripts/ops.gd): a cell under the pointer
var hover_dec := -1           # … or a decision row
var _ops_cells: Array = []
var _ops_decs: Array = []
var _ops_t := 9.0
var _page_off := Vector2.ZERO  # the page slide's offset while it is drawn
var _goals_cache: Array = []
var _goals_t := -1.0          # the goals worked out at most four times a second (1.7 ms each, 2026-10-24)
# page switches slide on a shared axis (player 2026-10-18: "the UI still isn't
# smooth"): the old page out one way, the new one in from the other
const SWITCH_OUT := 0.12
const SWITCH_IN := 0.22
const SWITCH_DELAY := 0.04
const SWITCH_SLIDE := 40.0
var prev_tab := -1
var prev_sel := 0
var switch_t := 9.0
var switch_dir := 1.0
# the selection frame glides from the chosen item to the next
var focus: Array = []
# gauges ease to their values; the push button's label crossfades
var _sm := {}
var _dt := 0.016
var _push_label := ""
var _push_old := ""
var _push_t := 9.0
# the pointer's pour on the push button and the way home (after Skyguard, 2026-10-18)
var pointer_override := Vector2.INF   # tests point here instead (the real mouse is never moved)
var pour_go: Pour
var pour_home: Pour
var _go_live := false
var _focus_tab := -99
var hover_goal := -1       # one of the header's two goals under the pointer
var _route_frame := -1
var _route_cache: Array = []
var route_panel: Control
var exchange_button: Button
var end_button: Button
var _wiping := false       # the transition out has been asked for
# a key's travel: the button or rocker last pressed sinks for a moment
var press_t := 0.0
var tab_press := -2         # the page whose key was just pressed (-2: none)
# the console's own sounds: keys, stamps, refusals, the self-test
var sfx: Sfx
var _last_sel := -1
var _boot_said := 0


# 2026-11-10 A-暗1 炭黑 (user picked it from four proposals): the home's keys press in, an orange
# lip slides to the chosen one, the header knob turns to it; the ground, header and foot keys of
# the whole terminal take the same look (scripts/ui_kit/charcoal.gd)
var lip_x := Motion.Spring.new(0.0, 520.0, 0.86)
var knob_f := Motion.Spring.new(0.0, 260.0, 0.62)
var _lip_on := false

var _note_key := ""
var _note_t := 0.0
var _note_at := Vector2.ZERO


# the plain words for each part of the terminal (人性化 规则 4)
func _note_text(k: String) -> String:
	match k:
		"home":
			return Ops.w("回到终端主屏（Esc）", "Back to the terminal's home screen (Esc)")
		"goal":
			return Ops.w("这一章要做的事：点开看怎么做、去哪做", "This chapter's goal: open it to see how and where")
		"next":
			return Ops.w("去下一步", "Takes you straight to where the next step is")
		"cell":
			return Ops.w("打开这一区的业务终端", "Opens this district's console")
		"dec":
			return Ops.w("去处理", "Deal with it: takes you to the right console or place")
		"app0":
			return Ops.w("找下一艘要拆的船：接单、派拖船、看二手船市", "Find the next ship: take a contract, send a tug, the hulk market")
		"app1":
			return Ops.w("船坞：报修坏了的设备、看扩建计划", "The berth: report what is broken, see the expansion plans")
		"app5":
			return Ops.w("学会新的拆法、规划港区建设", "Learn new ways to strip, plan the port's building")
		"app8":
			return Ops.w("查看和安装 R-02 的工具升级", "View and fit tool upgrades for R-02")
		"go0":
			if not next_job.is_empty():
				return Ops.w("去船坞开工已接下的这一单（Enter）", "Start the job already taken, at the berth (Enter)")
			var o: Dictionary = offers()[sel] if sel < offers().size() else {}
			if o.get("find", false):
				return Ops.w("立刻派拖船把这艘船拖回港，到港后开拆（Enter）", "Send a tug for this ship now; strip it when it is in (Enter)")
			if o.get("bought", false):
				return Ops.w("这艘船已经是你的了：进船坞开拆（Enter）", "This ship is yours: strip it at the berth (Enter)")
			return Ops.w("接下这份合同，立刻进船坞开工；钱不够时会先借款（Enter）", "Take this contract and start at the berth; a loan covers what you lack (Enter)")
		"go2":
			return Ops.w("立刻还这一笔借款，钱从资金里扣（Enter）", "Pay this much of the loan back now, from your cash (Enter)")
		"go4":
			return Ops.w("立刻买下选中的补给，钱当场扣，东西进库存（Enter）", "Buy the chosen supplies now: paid at once, into stock (Enter)")
		"go7":
			return Ops.w("开始这门训练（Enter）", "Start this course (Enter)")
		"minus":
			return Ops.w("少要一件", "One fewer")
		"plus":
			return Ops.w("多要一件", "One more")
		"item0":
			return Ops.w("点一下选中这艘船，看它的详情；再按下面的按钮", "Click to pick this ship and see it; then the key below")
		"item4":
			return Ops.w("点一下选中这样补给，再按下面的按钮买", "Click to pick this supply, then buy it with the key below")
		"item7":
			return Ops.w("点一下选中这门课，看它练什么", "Click to pick this course and see what it trains")
	return ""


func _ready() -> void:
	Back.arrive()
	testing = _is_test()
	if not testing:
		Txt.load_settings(false)
	Career.load_or_new()
	Career.ensure_offers(Market.make)
	# 96 号 (user 2026-10-28: a hulk towed home "不见了"): a contract taken whose loadout page was
	# closed stays in hand with the berth empty; over the empty berth it is shown to be started
	# (with the market on it was hidden, and no other card could be taken while it was in hand)
	next_job = Career.active() if (not overlay or between) and (not Career.data.get("market", false) or between) else {}
	# between contracts the home screen, the opening's first job straight on its card;
	# over the berth whatever the game asked for (the home screen)
	if not overlay or between:
		tab = 0 if not next_job.is_empty() else HOME
	# opened from a hulk's arrival: straight to its card under Find ships
	if focus_offer != "":
		for k in offers().size():
			if str(offers()[k].get("id", "")) == focus_offer:
				tab = 0
				sel = k
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
	money_roll.shown = float(Career.data.money)
	money_roll.set_to(float(Career.data.money))
	loan_roll.shown = float(Career.data.loan)
	loan_roll.set_to(float(Career.data.loan))
	# back from a settlement: the figures roll from what they were before it
	var rf: Dictionary = Career.data.get("roll_from", {})
	if not rf.is_empty():
		money_roll.shown = float(rf.get("money", Career.data.money))
		loan_roll.shown = float(rf.get("loan", Career.data.loan))
		money_roll.speed = 2.2
		loan_roll.speed = 2.2
		money_flash = 1.0 if float(Career.data.money) >= money_roll.shown else -1.0
		loan_flash = -1.0
		Career.data.erase("roll_from")
		Career.save()
	for i in 90:
		dust.append([Vector2(randf(), randf()), randf_range(0.002, 0.012), randf() * TAU, randf_range(0.6, 1.6)])
	for i in 4:
		focus.append(Motion.Spring.new(0.0, 560.0, 0.92))
	for i in 32:
		hover_k.append(Motion.Spring.new(0.0, 380.0, 0.7))
		sel_k.append(Motion.Spring.new(0.0, 300.0, 0.8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("terminal")
	Settings.apply(get_viewport())
	# the skill book is withdrawn (G3): its slot is the techniques-and-parts page
	tech_panel = TechPanel.new()
	tech_panel.terminal = self
	tech_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tech_panel.offset_top = 200
	tech_panel.offset_bottom = -60
	tech_panel.visible = tab == 3
	add_child(tech_panel)
	route_panel = preload("res://scripts/route_panel.gd").new()
	route_panel.terminal = self
	route_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route_panel.offset_top = 200
	route_panel.offset_bottom = -84
	route_panel.visible = tab == 5
	add_child(route_panel)
	repair_panel = RepairPanel.new()
	repair_panel.terminal = self
	repair_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	repair_panel.offset_top = 200
	repair_panel.offset_bottom = -60
	repair_panel.visible = tab == 1
	add_child(repair_panel)
	pour_go = Pour.make(self, Color(1.0, 0.82, 0.62))
	pour_home = Pour.make(self)
	settings = SettingsPanel.new()
	settings.testing = testing
	add_child(settings)
	exchange_button = Button.new()
	exchange_button.name = "IndustrialExchange"
	exchange_button.text = "交易行 · 买入 / 出售 [F8]" if Txt.zh else "EXCHANGE / BUY & SELL [F8]"
	BenchFx.note(exchange_button, Ops.w("打开交易行：买原料、卖产品（F8）", "Open the exchange: buy feed, sell products (F8)"))
	# Dedicated footer access: the old button covered the engineering goal
	# strip, making it look like a tiny clipped part of the build screen.
	exchange_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	exchange_button.offset_left = -400
	exchange_button.offset_right = -40
	exchange_button.offset_top = -64
	exchange_button.offset_bottom = -12
	exchange_button.visible = Career.data.get("market",false) and Onboarding.shown("market_ops")
	exchange_button.add_theme_font_override("font",Fonts.get_font("Medium"))
	exchange_button.add_theme_font_size_override("font_size",18)
	var xk := Charcoal.split_key(exchange_button.text)
	exchange_button.text = xk[0]
	Charcoal.style_button(exchange_button, xk[1])
	exchange_button.pressed.connect(open_exchange)
	add_child(exchange_button)
	# user 2026-10-26: a contract can be ended early here too, while its ship is being stripped
	end_button = Button.new()
	end_button.name = "EndContract"
	end_button.text = Txt.t("m_end")
	BenchFx.note(end_button, Ops.w("提前结束这一单：先按一次，再按一次确认；按已拆下的结算", "End this job early: press, then press again to confirm; settled on what is off"))
	end_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	end_button.offset_left = -820 if exchange_button.visible else -400
	end_button.offset_right = end_button.offset_left + 360
	end_button.offset_top = -64
	end_button.offset_bottom = -12
	end_button.visible = overlay and game_ref != null and game_ref.can_end_early()
	end_button.add_theme_font_override("font", Fonts.get_font("Medium"))
	end_button.add_theme_font_size_override("font_size", 18)
	Charcoal.style_button(end_button)
	end_button.pressed.connect(_end_contract)
	add_child(end_button)
	# 108 号 Q12: the three remote jobs along the foot, each with its key; locked ones say why
	remote_box = HBoxContainer.new()
	remote_box.name = "Remote"
	remote_box.add_theme_constant_override("separation", 10)
	# on the right, left of the exchange (and of "end the contract" when it shows): the left of the
	# foot is the pages' own (the contracts page's start button)
	remote_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	remote_box.offset_right = (end_button.offset_left if end_button.visible else exchange_button.offset_left if exchange_button.visible else -40.0) - 20.0
	remote_box.offset_left = remote_box.offset_right - 830.0
	remote_box.offset_top = -64
	remote_box.offset_bottom = -12
	remote_box.visible = overlay and game_ref != null
	for kind in RemoteOps.kinds():
		var rb := Button.new()
		rb.name = "Remote_" + kind
		rb.text = "%s [%s]" % [RemoteOps.name_of(kind), RemoteOps.key_label(kind)] if RemoteOps.key_label(kind) != "" else RemoteOps.name_of(kind)
		rb.custom_minimum_size = Vector2(200, 52)
		rb.add_theme_font_override("font", Fonts.get_font("Medium"))
		rb.add_theme_font_size_override("font_size", 16)
		var rk := Charcoal.split_key(rb.text)
		rb.text = rk[0]
		Charcoal.style_button(rb, rk[1])
		rb.set_meta("kind", kind)
		_remote_state(rb)
		rb.mouse_filter = Control.MOUSE_FILTER_STOP
		rb.pressed.connect(open_remote.bind(kind))
		remote_box.add_child(rb)
	add_child(remote_box)
	sfx = Sfx.new()
	add_child(sfx)
	# 2026-11-04 (BenchFx): the native pages inside (berth, methods and build) get the bench's light, notes
	# and Esc steps; the whole terminal takes the interface scale. Its own boot is its entrance.
	BenchFx.dress.call_deferred(self, [], null, 1.0, "terminal", false)

	# a new career's terminal opens up as it is needed (28 号): say what just opened
	var opened := Onboarding.refresh()
	if not opened.is_empty():
		say("；".join(opened) if Txt.zh else "; ".join(opened))
	exchange_button.visible = Career.data.get("market",false) and Onboarding.shown("market_ops")
	# on site (the left computers), with animation off, and under the tests' stills: up at once
	if overlay or not UiSkin.motion() or testing:
		boot_t = BOOT_T
	if overlay:
		process_mode = Node.PROCESS_MODE_ALWAYS
		if _locked(tab):
			tab = HOME
		if not between:
			say(Txt.t("tm_onsite_note"))
		return
	var dev := DevPanel.new()
	dev.terminal = self
	dev.where = "terminal"
	add_child(dev)
	# the first time the market opens (after the tug), the terminal says so; Liang's
	# lines for it wait for the opening to be through (written for after the Heron)
	var seen: Dictionary = Career.data.get("seen", {})
	if Career.data.get("market", false) and not seen.has("market"):
		seen["market"] = true
		Career.data.seen = seen
		Career.save()
		Copy.say(radio, "T_market_open", "term")
	if Career.data.get("market", false) and not seen.has("market_liang") and Career.story_job().is_empty() and Career.active().is_empty():
		seen["market_liang"] = true
		Career.data.seen = seen
		Career.save()
		for k in ["L_market_open_1", "L_market_open_2", "L_market_open_3"]:
			Copy.say(radio, k)
	_check_milestone()
	# the first unowned hulk on the market (26 号; the author's line, empty says nothing)
	var seen_d: Dictionary = Career.data.get("seen", {})
	if Career.data.get("market", false) and not seen_d.has("drift_first") and offers().any(func(o): return o.get("owner", "") == "salvage"):
		seen_d["drift_first"] = true
		Career.data.seen = seen_d
		Career.save()
		Copy.say(radio, "L_drift_first")
	if Game.loadout_after_course:
		Game.loadout_after_course = false
		_after_course_loadout.call_deferred()
	# a new reputation level since the terminal last opened
	var lv := Career.level()
	var seen_lv: Dictionary = Career.data.get("seen", {})
	if seen_lv.get("level", "trainee") != lv:
		seen_lv["level"] = lv
		Career.data.seen = seen_lv
		Career.save()
		var names := [Txt.S["rep_" + lv][0], Txt.S["rep_" + lv][1]]
		Copy.say(radio, "T_rep_up", "term", names)
		Copy.say(radio, "L_rep_" + lv)


# the first time a debt from a botched job is cleared (at a settlement, or paid off here), once
# straight to ready: the self-test cut short, the cards already dealt
func _skip_boot() -> void:
	boot_t = BOOT_T
	deal_t = maxf(deal_t, 2.0)


func _check_milestone() -> void:
	var seen: Dictionary = Career.data.get("seen", {})
	if not Career.data.get("paid_off", false) or seen.has("paid_off"):
		return
	seen["paid_off"] = true
	Career.data.seen = seen
	Career.save()
	milestone = 0.0
	Copy.say(radio, "T_loan_paid", "term")
	for k in ["L_loan_paid_1", "L_loan_paid_2", "L_loan_paid_3"]:
		Copy.say(radio, k)


func _is_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.find("tests/") >= 0:
			return true
	return false


# what the market shows: the pinned story contract first (when there is one),
# then the offers, three cards in all
func offers() -> Array:
	if show_trials and not overlay:
		return _trials()
	var os: Array = Career.data.get("offers", [])
	var sj: Dictionary = Career.story_job()
	if sj.is_empty() or overlay:
		return os
	var card := sj.duplicate(true)
	card.story_card = true
	return [card] + os.slice(0, 2)


# the three trial contracts (G1) as market cards: drawn from their fixed seeds once per visit
func _trials() -> Array:
	if _trial_cards.is_empty():
		for id in Career.TRIALS:
			var o: Dictionary = Career.trial_offer(str(id))
			if not o.is_empty():
				o.trial_card = true
				_trial_cards.append(o)
	return _trial_cards


func toggle_trials() -> void:
	if tab != 0 or overlay or not next_job.is_empty():
		return
	show_trials = not show_trials
	_trial_cards = []
	thumbs.clear()
	sel = 0
	deal_t = 0.0
	sfx.play("switch", Vector2.INF, 0.8)


# a shown card's place in the career's own offers (-1 for the story card)
func _offer_index(i: int) -> int:
	return i - 1 if not Career.story_job().is_empty() and not overlay else i


func items() -> Array:
	match tab:
		HOME: return APPS
		0: return offers()
		1: return [] # the repair panel's own controls
		2: return [BERTH[0]]
		4: return _supply_items()
		5: return [] # The growth desk uses native, clipped and focusable controls.
		7: return _training_rows()
		DRONE_PAGE: return SHOP.slice(0, DRONE_UPGRADES) + _skin_items() + [_tunnel_item(), _tunnel_item("tunnel_body")]
	return []


# 2026-11-11 用户：“这个量子隧穿是在哪个升级里面，我都没看到” — the late upgrade gets its own card
# on the drone page, after the airframes (its index: _tunnel_i())
func _tunnel_item(id: String = "tunnel") -> Array:
	for it in SHOP:
		if it[0] == id:
			return it
	return []


func _tunnel_i() -> int:
	return DRONE_UPGRADES + Skins.ORDER.size()


# 量子隧穿·机体: its card right under the tunnel's
func _tbody_i() -> int:
	return _tunnel_i() + 1


# why a late upgrade can't be bought yet ("" when it can): the part it needs first, then the work done
func _late_why(id: String) -> String:
	var d := Career.data
	if REQUIRES.has(id) and not d.get("upgrades", {}).has(REQUIRES[id]):
		return Ops.w("需要先装上%s", "FIT THE %s FIRST") % Txt.t(_facility_name(REQUIRES[id]))
	if LATE.has(id) and (int(d.get("done", 0)) < int(LATE[id][0]) or int(d.get("rep", 0)) < int(LATE[id][1])):
		return Growth.text(["需要完成 %d 单、声望 %d（现在 %d 单、声望 %d）", "Requires %d completed jobs, %d reputation (now %d, %d)"]) % [int(LATE[id][0]), int(LATE[id][1]), int(d.get("done", 0)), int(d.get("rep", 0))]
	return ""


# 2026-11-10 外观款式: the airframes after the three tool upgrades on the drone page
# [id, "skin", price, id, id] (names and lines from scripts/drone_skins.gd)
func _skin_items() -> Array:
	var out: Array = []
	for id in Skins.ORDER:
		out.append([id, "skin", Skins.price(id), id, id])
	return out


# the training page's rows (2026-10-20): the base course, the seven special courses
# (scripts/codex.gd), the codex
func _training_rows() -> Array:
	var out: Array = [["base"]]
	for id in Career.TRIALS:
		out.append(["trial", id])
	for cls in Codex.CLASSES:
		out.append(["sp", cls])
	out.append(["codex"])
	return out


# the route page's nodes, built once a frame
func _route_nodes() -> Array:
	var f := Engine.get_process_frames()
	if f != _route_frame:
		_route_frame = f
		_route_cache = Route.nodes()
	return _route_cache


# the equipment page: the four fitted upgrades, then the berth's facilities
func _equip_items() -> Array:
	return SHOP.slice(0, FITTED) + BERTH.slice(2)


func _supply_items() -> Array:
	return SHOP.slice(FITTED)


func _app_of(page: int) -> int:
	for i in APPS.size():
		if APPS[i][0] == page:
			return i
	return 0


func _locked(page: int) -> bool:
	if page == DRONE_PAGE and not Career.data.get("market", false):
		return true
	if page != HOME and Onboard.locks(page):
		return true
	return overlay and not between and page != HOME and not page in ON_SITE

# 108 号: a remote job from the terminal: the terminal folds away and its panel opens
# 2026-11-10 (user: "电网调度和仓库怎么按不了"): a foot key is never dead — a locked one stays
# clickable, looks locked (dim, its keycap greyed) and says why when pressed; the state is read
# again while the terminal is open, so a job unlocked meanwhile opens at once
func _remote_state(rb: Button) -> void:
	var kind := str(rb.get_meta("kind", ""))
	var locked := not RemoteOps.ok(kind)
	if rb.disabled or not rb.has_meta("locked") or bool(rb.get_meta("locked")) != locked:
		rb.disabled = false
		rb.set_meta("locked", locked)
		rb.add_theme_color_override("font_color", Charcoal.INK3 if locked else Charcoal.INK)
		rb.add_theme_color_override("font_hover_color", Charcoal.INK2 if locked else Color(1, 1, 1))
		rb.tooltip_text = RemoteOps.why(kind) if locked else Ops.w("远程办理，不用跑到现场", "Done from here: no need to go there")
		rb.set_meta("bfx_note", rb.tooltip_text)
		rb.queue_redraw()


var _remote_t := 0.0


func open_remote(kind: String) -> void:
	if game_ref == null or not RemoteOps.ok(kind):
		shake = 1.0
		say(RemoteOps.why(kind) if RemoteOps.why(kind) != "" else Ops.w("现在打不开", "NOT AVAILABLE NOW"))
		if sfx != null:
			sfx.play("deny")
		return
	var current_game = game_ref
	var e := _back_entry()
	if on_close.is_valid(): on_close.call()
	Back.go(e, "remote:" + kind, func(): RemoteOps.open(current_game, kind))


func open_exchange(page: String = "") -> void:
	if not Career.data.get("market",false): return
	# 128 号 返工: the old exchange page is shut till 第 2 段 builds the new one (the stores sell to recycling)
	if not StoreBook.exchange_usable() and not StoreBook.exchange_open():
		say(StoreBook.exchange_closed_text())
		return
	if game_ref != null:
		var current_game = game_ref
		var e := _back_entry()
		if on_close.is_valid(): on_close.call()
		Back.go(e, "exchange", func(): current_game.open_exchange(page))
	else:
		# Keep the real station and its freight service alive behind the market,
		# including when arriving from an old standalone terminal scene.
		Game.exchange_requested = true
		Game.play_career(get_tree())


# the pinned and next goals, worked out at most every quarter second (the header and the
# home screen ask every frame); a click or key press starts a fresh one
func _goals() -> Array:
	if _goals_t < 0.0 or t - _goals_t > 0.25:
		_goals_t = t
		# 61 号: only what the player pinned; the suggestions spoke in shorthand
		_goals_cache = Route.goals().filter(func(n): return n.get("pinned", false))
	return _goals_cache


# the main line's step, from the terminal (28 号 Q18): the contracts here; a guide on site
func _take_main() -> void:
	var ch := Mainline.chapter()
	var st := Mainline.waiting_step() if ch == "" else Mainline.step(ch)
	var go := str(st.get("go", "wait"))
	# nothing on the find-ships page to act on: straight to the star map's sweep (user 2026-10-26)
	if (go == "scan" or (go == "contracts" and Scan.ON and not Mainline._cards_waiting())) and game_ref != null:
		var gm = game_ref
		_go_page("star_map", func(): gm.open_star_map("find"))
	elif go == "contracts":
		set_tab(0)
	elif (go == "store" or go.begins_with("guide:")) and game_ref != null:
		var g = game_ref
		close()
		Mainline.take_me.call_deferred(g, go)
	else:
		say(str(st.get("text", "")))


# a cell or decision of the home screen's overview clicked: where it leads (scripts/ops.gd)
func ops_go(go: String) -> void:
	if go.begins_with("tab:"):
		set_tab(int(go.substr(4)))
	elif go.begins_with("route:"):
		var key := go.substr(6)
		set_tab(5)
		if tab != 5:
			return
		var n := Route.find(key)
		if not n.is_empty() and n.get("kind", "") == "tier":
			route_panel.select_category(0)
		else:
			route_panel.select_key(key)
	elif go == "starmap" or go == "scan" or (go == "contracts" and Scan.ON and game_ref != null and not Mainline._cards_waiting()):
		if go == "contracts":
			go = "scan"
		if game_ref == null:
			return
		var gm = game_ref
		_go_page("star_map", func(): gm.open_star_map("find" if go == "scan" else "ships"))
	elif go == "drill":
		# the training run: the tonne handed over at the first click, then the guide (30 号)
		if game_ref == null or game_ref.get("guide") == null:
			say(str(Drill.step().text))
			return
		var g = game_ref
		var st := Drill.step()
		if str(st.go) == "drill":
			var r := Drill.grant()
			if not r.ok:
				_refuse(str(r.get("reason", "")))
				return
		close()
		Mainline.take_me.call_deferred(g, str(Drill.step().go))
	elif game_ref != null and game_ref.get("guide") != null and Guide.task_for(go) != "":
		# a site job or a client's gap: the on-site guide takes the operator there (27 号)
		var t := Guide.task_for(go)
		var g = game_ref
		g.guide.begin(t)
		if t == "clients":
			_go_page("exchange", func(): g.open_exchange("clients"))
		elif t == "buy_feed":
			_go_page("exchange", func(): g.open_exchange("feed"))
		else:
			close()
	elif go == "exchange" or go == "clients":
		if Onboard.stage() == "find":
			_refuse(Onboard.lock_reason())
			return
		if not Career.data.get("market", false):
			_refuse(Ops.w("交易行在第一单完成后开放。", "The exchange opens after the first job."))
			return
		open_exchange("clients" if go == "clients" else "")
	elif go.begins_with("site:"):
		say(Ops.site_text(go))
		sfx.play("menu", Vector2.INF, 0.6)


func _lock_reason(page: int) -> String:
	if Onboard.locks(page):
		return Onboard.lock_reason()
	match page:
		0: return Txt.t("tm_lock_contracts")
		1: return Txt.t("tm_lock_equip")
		DRONE_PAGE:
			if not Career.data.get("market", false):
				return Ops.w("拆完第一艘船后开放", "OPENS AFTER YOUR FIRST SHIP")
	return Txt.t("tm_lock_between")


# where a page sits in the slide order: home first, then the tiles
func _order(page: int) -> int:
	return -1 if page == HOME else _app_of(page)


# 0..1: how far the page switch has brought the new page in
func _page_in() -> float:
	if not UiSkin.motion() or prev_tab == tab:
		return 1.0
	return Pal.ease_out(clampf((switch_t - SWITCH_DELAY) / SWITCH_IN, 0.0, 1.0))


# 0..1: how far the old page has gone
func _page_out() -> float:
	if not UiSkin.motion() or prev_tab == tab:
		return 1.0
	return Pal.ease_in(clampf(switch_t / SWITCH_OUT, 0.0, 1.0))


func _slide() -> float:
	return SWITCH_SLIDE if Txt.anim_level() >= 2 and UiSkin.motion() else 0.0


func _open_app(i: int) -> void:
	if i < 0 or i >= APPS.size():
		return
	if not Onboarding.page_shown(APPS[i][0]):
		_refuse(Ops.w("还没开放：用到时会自动出现", "NOT OPEN YET: IT APPEARS WHEN NEEDED"))
		return
	set_tab(APPS[i][0])


# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	if game_ref == null and not get_tree().paused and not settings.is_open:
		preload("res://scripts/industrial_exchange.gd").advance_career(dt)
		HallMarket.tick(dt)
	t += dt
	_dt = dt
	_push_t += dt
	msg_t += dt
	deal_t += dt
	switch_t += dt
	_step_book()
	_walk_pin()
	_remote_t += dt
	if _remote_t > 0.4 and remote_box != null:
		_remote_t = 0.0
		for rb in remote_box.get_children():
			_remote_state(rb)
	_step_focus(dt)
	press_t = maxf(0.0, press_t - dt)
	if press_t <= 0.0:
		tab_press = -2
	if sel != _last_sel:
		if _last_sel >= 0 and boot_t >= BOOT_T:
			sfx.play("menu", Vector2.INF, 0.45)
		_last_sel = sel
	# the self-test's two sounds: power on, ready
	if _boot_said == 0 and boot_t > 0.02 and boot_t < BOOT_T:
		_boot_said = 1
		sfx.play("term", Vector2.INF, 0.7)
	elif _boot_said == 1 and boot_t >= 1.5:
		_boot_said = 2
		sfx.play("ok", Vector2.INF, 0.6)
	# the self-test: it only runs once the transition has opened the screen,
	# and the cards are dealt as it brings the content up
	if not Wipe.busy() and boot_t < BOOT_T:
		boot_t += dt
	if boot_t < 0.85:
		deal_t = 0.0
	# the home's panels settle in ~0.6 s; with motion reduced they are simply there
	if tab == HOME and not UiSkin.motion():
		deal_t = maxf(deal_t, 10.0)
	if milestone >= 0.0:
		milestone += dt
	_step_motion(dt)
	flash = maxf(0.0, flash - dt * 3.0)
	radio.step(dt, false)
	var m := get_local_mouse_position() if pointer_override == Vector2.INF else pointer_override
	hover = -1
	hover_tab = -1
	for i in items().size():
		if _item_rect(i).has_point(m):
			hover = i
	hover_home = tab != HOME and _home_rect().has_point(m)
	hover_cell = -1
	hover_dec = -1
	if tab == HOME:
		_ops_t += dt
		if _ops_t > 0.5:
			_ops_t = 0.0
			_ops_cells = []
			_ops_decs = Ops.problems(game_ref)
		for i in _ops_cells.size():
			if _cell_rect(i).has_point(m):
				hover_cell = i
		for i in _ops_decs.size():
			if _dec_rect(i).has_point(m):
				hover_dec = i
		hover_next = _next_action and _next_go_rect().has_point(m) and not _walk_quiet()
	hover_goal = -1
	if boot_t >= BOOT_T:
		for i in (Route.MAX_PINS if Onboarding.shown("rep") and not _walk_quiet() else 0):
			if _goal_rect(i).has_point(m):
				hover_goal = i
	hover_go = _go_rect().has_point(m)
	var free := not settings.is_open and leaving < 0.0 and boot_t >= BOOT_T
	pour_go.place(_go_rect(), free and hover_go and _go_live, m)
	pour_home.place(_home_rect(), free and hover_home, m)
	hover_minus = _has_qty() and _qty_rect(-1).has_point(m)
	hover_plus = _has_qty() and _qty_rect(1).has_point(m)
	if dragging:
		_slide_to(m.x)
	# 人性化 规则 4: what is under the pointer, held 0.4 s, gets its plain note
	var nk := ""
	if hover_home:
		nk = "home"
	elif hover_goal >= 0:
		nk = "goal"
	elif tab == HOME and hover_next:
		nk = "next"
	elif tab == HOME and hover_cell >= 0:
		nk = "cell"
	elif tab == HOME and hover_dec >= 0:
		nk = "dec"
	elif tab == HOME and hover >= 0:
		nk = "app%d" % int(APPS[hover][0]) if hover < APPS.size() else ""
	elif hover_go and _go_live:
		nk = "go%d" % tab
	elif hover_minus:
		nk = "minus"
	elif hover_plus:
		nk = "plus"
	elif hover >= 0:
		nk = "item%d" % tab
	if nk != _note_key:
		_note_key = nk
		_note_t = 0.0
	elif nk != "":
		_note_t += dt
	_note_at = m
	shake = maxf(0.0, shake - dt * 2.2)
	for k in install.keys():
		install[k] += dt
		if install[k] > 1.6:
			install.erase(k)
	if leaving >= 0.0:
		leaving += dt
		# the card lifts, then the screen folds into a hairline through it and
		# the berth opens out of the line (player 2026-10-18)
		if leaving > 0.12 and not _wiping:
			_wiping = true
			var tree := get_tree()
			Wipe.go(tree, func():
				tree.paused = false
				tree.change_scene_to_file("res://scenes/main.tscn"), "fold", leave_from)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_goals_t = -1.0
	if tab == 2 and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _borrow_rect().has_point(get_local_mouse_position()) and not settings.is_open and leaving < 0.0:
		_borrow()
		accept_event()
		return
	if settings.is_open or leaving >= 0.0:
		return
	if boot_t < BOOT_T and ev is InputEventMouseButton and ev.pressed:
		_skip_boot()
		return
	if ev is InputEventMouseButton and ev.pressed and milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		dragging = false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and tab == 0 and _codex_page == null:
		for ci in _cx_link:
			if ci < offers().size() and _cx_link[ci].has_point(ev.position):
				var oc: Dictionary = offers()[ci]
				var ms := Codex.ship_entries(str(oc.ship))
				_codex_page = CodexPage.open(self, ms[0] if not ms.is_empty() else "", str(oc.ship), func(): _codex_page = null, true)
				get_viewport().set_input_as_handled()
				return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if hover_goal >= 0:
			_open_goal(hover_goal)
		elif hover_home:
			set_tab(HOME)
		elif tab == HOME and hover_next:
			_take_main()
		elif tab == 0 and next_job.is_empty() and Scan.ON and _scan_rect().has_point(get_local_mouse_position()):
			if game_ref != null:
				var gm = game_ref
				_go_page("star_map", func(): gm.open_star_map("find"))
		elif tab == 0 and next_job.is_empty() and _shipmkt_rect().has_point(get_local_mouse_position()) and ShipMarket.open():
			# 62 号: the hulk market from the find-ships page
			if game_ref != null:
				var gm = game_ref
				_go_page("ship_market", func(): gm.open_ship_market())
			else:
				say(Ops.w("回到船坞后再打开二手船市。", "Open the hulk market from the berth."))
		elif tab == HOME and hover_cell >= 0 and hover_cell < _ops_cells.size():
			ops_go(str(_ops_cells[hover_cell].go))
		elif tab == HOME and hover_dec >= 0 and hover_dec < _ops_decs.size():
			ops_go(str(_ops_decs[hover_dec].go))
		elif tab == HOME and hover >= 0:
			# a tile opens at a click
			sel = hover
			act()
		elif hover_go:
			act()
		elif hover_minus:
			_bump(-1)
		elif hover_plus:
			_bump(1)
		elif tab == 2 and _slider_rect().grow(12.0).has_point(ev.position):
			sel = 0
			dragging = true
			_slide_to(ev.position.x)
		elif hover >= 0:
			# a second click on a market card takes it; elsewhere a click only chooses.
			# A card whose ship needs a special course goes at the first click (25 号, Q4)
			if tab == 0 and next_job.is_empty() and _needs_course(hover):
				sel = hover
				act()
				return
			if sel == hover and (tab == 0 or tab == 5):
				act()
			if sel != hover:
				qty = 1
			sel = hover


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		_goals_t = -1.0
		# any key while the home's panels are still settling puts them in place (the key still acts)
		if tab == HOME and deal_t < 0.9:
			deal_t = 10.0
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F8 and Career.data.get("market",false):
		open_exchange()
		get_viewport().set_input_as_handled()
		return
	var rk := RemoteOps.kind_of_key(ev)
	if rk != "" and overlay and game_ref != null:
		open_remote(rk)
		get_viewport().set_input_as_handled()
		return
	if DevPanel.workbench_open and Txt.dev:
		return
	if _codex_page != null:
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or leaving >= 0.0:
		return
	if boot_t < BOOT_T and not overlay:
		_skip_boot()
		get_viewport().set_input_as_handled()
		return
	if overlay:
		get_viewport().set_input_as_handled()
	if loadout != null:
		if ev.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			loadout.go()
		elif ev.physical_keycode == KEY_ESCAPE:
			loadout.cancel()
		get_viewport().set_input_as_handled()
		return
	if milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
		return
	if tab in [1, 3, 5] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S, KEY_ENTER, KEY_SPACE]:
		return # Native growth / repair controls own navigation and confirmation.
	# the key that opens it on site closes it again
	if overlay and Keys.pressed(ev, "terminal"):
		close()
		return
	match ev.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			_open_app(ev.physical_keycode - KEY_1)
		KEY_LEFT, KEY_A:
			if tab == 5:
				pass
			else:
				sel = maxi(0, sel - 1)
			qty = 1
		KEY_RIGHT, KEY_D:
			if tab == 5:
				pass
			else:
				sel = mini(items().size() - 1, sel + 1)
			qty = 1
		KEY_UP, KEY_W, KEY_EQUAL, KEY_KP_ADD:
			if tab == 5:
				pass
			elif tab == HOME:
				pass # the home screen's keys are one row
			else:
				_bump(1)
		KEY_DOWN, KEY_S, KEY_MINUS, KEY_KP_SUBTRACT:
			if tab == 5:
				pass
			elif tab == HOME:
				pass
			else:
				_bump(-1)
		KEY_ENTER, KEY_SPACE:
			act()
		KEY_I:
			if tab == 0:
				use_intel(sel)
		KEY_T:
			toggle_trials()
		KEY_L:
			_borrow()
		KEY_ESCAPE:
			# out of an app to the home screen; from there, away
			if tab != HOME:
				set_tab(HOME)
			elif overlay:
				close()
				Back.back()
			elif not _wiping:
				_wiping = true
				var tree := get_tree()
				Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/title.tscn"))
		KEY_O:
			settings.open()
		KEY_G:
			# the loadout page between contracts (on site the gear is already on the ship)
			if (not overlay or between) and tab != 5:
				_open_loadout(Callable())


# the on-site console closes: back to the berth
# two clicks, as in the pause menu: the first says what is lost
var end_armed := false
func _end_contract() -> void:
	if not end_armed:
		end_armed = true
		end_button.text = Txt.t("m_confirm")
		say(Txt.t("end_warn"))
		return
	var g = game_ref
	close()
	g.finish_contract(true)


# 134 号: how to open the terminal again as it is now (the page it is on); and leaving for another
# page with that remembered, so Esc there comes back here (scripts/ui_back.gd)
func _back_entry() -> Dictionary:
	var g = game_ref
	var at := tab
	if at == 0 and _find_empty():
		at = HOME
	var lab := ["找船", "FIND SHIPS"] if at == 0 else ["船坞终端", "THE TERMINAL"]
	return Back.entry("terminal", lab, func():
		g.open_console("terminal")
		var t = g.console_ui
		if t != null and t.has_method("set_tab"):
			t._skip_boot()
			if t.tab != at:
				t.set_tab(at))


func _go_page(to: String, open: Callable) -> void:
	var e := _back_entry()
	close()
	Back.go(e, to, open)


func close() -> void:
	Career.save()
	if on_close.is_valid():
		on_close.call()
	# 91 号: over the berth the screen folds back into the drone (scripts/look.gd frees it)
	if keep_on_close:
		process_mode = Node.PROCESS_MODE_DISABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	queue_free()


func set_tab(i: int) -> void:
	i = clampi(i, HOME, DRONE_PAGE)
	if i == HOME:
		berth_view = null
	# 62 号: the finds' trip home is quoted again from today when their page opens (the planets move)
	if i == 0:
		for o in Career.data.get("offers", []):
			if o.get("find", false):
				var fq := ShipMarket.find_quote(o)
				if not fq.run.is_empty():
					o.tow_days = float(fq.run.tof)
	# on site what can't be used is locked: it says why and stays where it is
	if _locked(i):
		_refuse(_lock_reason(i))
		return
	# nothing on the find-ships page — no hulk found, no market to buy one at: straight to the star
	# map's sweep, whichever way the page was asked for (user 2026-10-28: "这个我都说多少次了")
	if i == 0 and _find_empty() and game_ref != null:
		var gm = game_ref
		_go_page("star_map", func(): gm.open_star_map("find"))
		return
	press_t = 0.16
	tab_press = i
	if i != tab:
		sfx.play("switch", Vector2.INF, 0.8)
		deal_t = 0.0
		prev_tab = tab
		prev_sel = sel
		switch_t = 0.0
		# the page's own gauges fill in again; the header's stay as they are
		for k in _sm.keys():
			if not (str(k) == "rep" or str(k).begins_with("goal:")):
				_sm.erase(k)
		var d := _order(i) - _order(tab)
		switch_dir = 1.0 if d >= 0 else -1.0
	var was := tab
	tab = i
	if book != null:
		book.visible = tab == 3
		if tab == 3:
			var goal := Growth.find_track(str(Career.data.get("growth_goal", "")))
			if not goal.is_empty():
				book.selected = goal[0]
			book.refresh()
	# back home: the tile it came from is the chosen one
	sel = _app_of(was) if tab == HOME and was != HOME else 0
	if tab == 5:
		_route_frame = -1
		sel = 0
	if route_panel != null:
		route_panel.visible = tab == 5
		if tab == 5:
			route_panel.refresh()
	if repair_panel != null:
		repair_panel.visible = tab == 1
		if tab == 1:
			repair_panel.refresh()
	if tech_panel != null:
		tech_panel.visible = tab == 3
		if tab == 3:
			tech_panel.refresh()
	qty = 1
	repay_amt = _repay_default()


# ↑ ↓: how many of a consumable, or how much to repay
func _bump(d: int) -> void:
	if _has_qty():
		qty = clampi(qty + d, 1, 9)
	elif tab == 2:
		repay_amt = clampf(snappedf(repay_amt + d * REPAY_STEP, REPAY_STEP), 0.0, _slider_max())


func _has_qty() -> bool:
	return tab == 4


func _repay_max() -> float:
	return maxf(0.0, minf(float(Career.data.money), float(Career.data.loan)))


# the finance slider sets one amount: paid back (up to what is owed and in hand) or
# borrowed (up to the credit left)
func _slider_max() -> float:
	return maxf(_repay_max(), Career.credit_left())


func _borrow_amt() -> float:
	return minf(repay_amt, Career.credit_left())


func _borrow_rect() -> Rect2:
	var f := _finance_rect()
	return Rect2(f.position.x + f.size.x * 0.5 + 10, f.end.y - 100, f.size.x * 0.5 - 46, 68)


func _borrow() -> void:
	if tab != 2 or (overlay and not between):
		return
	var got := Career.borrow(_borrow_amt())
	if got <= 0.0:
		_refuse(Txt.t("tm_borrow_none"))
		return
	flash = 1.0
	sfx.play("stamp", Vector2.INF, 0.9)
	say(Txt.t("tm_borrowed") % [Pal.money(got), Pal.money(float(Career.data.loan))])
	repay_amt = minf(repay_amt, _slider_max())
	if not Career.data.get("seen", {}).has("loan"):
		var seen: Dictionary = Career.data.get("seen", {})
		seen["loan"] = true
		Career.data.seen = seen
		Copy.say(radio, "L_loan_first")
	elif Career.credit_left() <= 0.5:
		Copy.say(radio, "L_loan_limit")


func _repay_default() -> float:
	return minf(20000.0, _repay_max())


func _slide_to(x: float) -> void:
	var r := _slider_rect()
	var k := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	var mx := _slider_max()
	repay_amt = mx if k > 0.995 else minf(mx, snappedf(mx * k, REPAY_STEP))


# new cards on the table: they come in again
func dealt() -> void:
	deal_t = 0.0
	sel = 0


func _step_motion(dt: float) -> void:
	var tr := _tab_rect(tab)
	tab_x.target = tr.position.x
	tab_w.target = tr.size.x
	tab_x.step(dt)
	tab_w.step(dt)
	var n := items().size()
	if tab == 0 and (not offers().is_empty() or not next_job.is_empty()):
		go_x.target = _item_rect(clampi(sel, 0, maxi(0, offers().size() - 1))).position.x
		if go_x.x == 0.0:
			go_x.snap(go_x.target)
	go_x.step(dt)
	for i in hover_k.size():
		hover_k[i].target = 1.0 if i == hover and i < n and leaving < 0.0 else 0.0
		sel_k[i].target = 1.0 if i == sel and i < n else 0.0
		hover_k[i].step(dt)
		sel_k[i].step(dt)
	var m := float(Career.data.money)
	var l := float(Career.data.loan)
	if absf(m - money_roll.target) > 0.5:
		money_flash = 1.0 if m > money_roll.target else -1.0
	if absf(l - loan_roll.target) > 0.5:
		loan_flash = -1.0 if l < loan_roll.target else 1.0
	if tab == HOME and sel >= 0 and sel < APPS.size():
		lip_x.target = _tile_rect(sel).position.x
		knob_f.target = float(sel)
		if not _lip_on or not UiSkin.motion():
			lip_x.snap(lip_x.target)
			knob_f.snap(knob_f.target)
		_lip_on = true
	else:
		_lip_on = false
	lip_x.step(dt)
	knob_f.step(dt)
	money_roll.set_to(m)
	loan_roll.set_to(l)
	money_roll.step(dt)
	loan_roll.step(dt)
	money_flash = move_toward(money_flash, 0.0, dt * 1.6)
	loan_flash = move_toward(loan_flash, 0.0, dt * 1.6)
	for sp in sparks:
		sp[2] += dt
	sparks = sparks.filter(func(sp): return sp[2] < sp[3] + 0.7)
	for k in intel_t.keys():
		intel_t[k] += dt
	for k in sweep.keys():
		sweep[k] += dt
		if sweep[k] > 0.8:
			sweep.erase(k)


# where the funds figure sits (the sparks fly there)
func _money_at() -> Vector2:
	return Vector2(size.x - 60 - 3 * 250 - 60, 84)


func say(text: String) -> void:
	msg = text
	msg_t = 0.0


# take the selected contract, or buy the selected thing
func act() -> void:
	if tab == 3 or tab == 6:
		return
	press_t = 0.16
	match tab:
		HOME:
			_open_app(sel)
		0:
			if not next_job.is_empty():
				start_next()
			else:
				take(sel)
		1:
			var eq := _equip_items()
			buy(eq[sel] if sel < eq.size() else [])
		2:
			buy(BERTH[0])
		4:
			var sp := _supply_items()
			buy(sp[sel] if sel < sp.size() else [], qty)
		5:
			route_panel.purchase()
		7:
			_training_act(sel)
		DRONE_PAGE:
			var upgrades := items()
			if sel >= 0 and sel < upgrades.size():
				buy(upgrades[sel])


# the training page: replay the base course, take a special course, open the codex
func _training_act(i: int) -> void:
	var rows := _training_rows()
	if i < 0 or i >= rows.size():
		return
	var row: Array = rows[i]
	match row[0]:
		"base":
			buy(BERTH[1])
		"sp":
			if overlay and not between:
				_refuse(Txt.t("tm_onsite_no"))
				return
			leave_from = _item_rect(i)
			Game.start_courses([row[1]], "terminal")
			Game.contract = {}
			SaveGame.load_requested = false
			sfx.play("stamp", Vector2.INF, 1.0)
			leaving = 0.0
		"codex":
			if _codex_page == null:
				_codex_page = CodexPage.open(self, "", "", func(): _codex_page = null)
		"trial":
			if overlay and not between:
				_refuse(Txt.t("tm_onsite_no"))
				return
			if not Career.active().is_empty():
				_refuse(Txt.t("trial_busy"))
				return
			leave_from = _item_rect(i)
			var o: Dictionary = Career.take_trial(str(row[1]))
			if o.is_empty():
				_refuse(Txt.t("tm_none"))
				return
			leave_offer = o.duplicate(true)
			_open_loadout(func():
				var a: Dictionary = Career.active()
				Game.start_ship = a.get("ship", "gr7")
				Game.contract = a
				Copy.say(radio, "T_contract_signed", "term")
				SaveGame.load_requested = false
				sfx.play("stamp", Vector2.INF, 1.0)
				leaving = 0.0)


# the loadout page over the terminal: Enter takes the configuration out and goes on
# with `go`; Esc keeps the choice and comes back (the contract in hand, if any, waits
# on the market as the next card)
func _open_loadout(go: Callable) -> void:
	if loadout != null:
		return
	# a test drives the terminal without the page (the saved loadout went out at signing)
	if _is_test() and not loadout_in_tests:
		if go.is_valid():
			go.call()
		return
	loadout = LoadoutPanel.open(self, go, func():
		if not Career.active().is_empty() and Career.data.get("market", false):
			next_job = Career.active()
		thumbs.clear()
		dealt())
	sfx.play("switch", Vector2.INF, 0.8)


var _codex_page = null
var _cx_link := {}          # offer card -> its "new on this ship" line (a click opens the codex)


func take_order(id: String, reward: String, whole: bool) -> void:
	var why: String = load("res://scripts/work_orders.gd").take(id,reward,whole)
	if why != "":
		_refuse(why)
		return
	_open_loadout(func():
		var job: Dictionary = Career.active()
		Game.start_ship = str(job.ship)
		Game.contract = job
		SaveGame.load_requested = false
		leaving = 0.0)


# 104 号: a borrow job from the methods page (the rigging order goes the order's way)
func take_borrow(id: String) -> void:
	var why: String = Methods.take(id)
	if why != "":
		_refuse(why)
		return
	_open_loadout(func():
		var job: Dictionary = Career.active()
		Game.start_ship = str(job.ship)
		Game.contract = job
		SaveGame.load_requested = false
		leaving = 0.0)


func take(i: int) -> void:
	if i < 0 or i >= offers().size():
		return
	# 128 号: a haul still waiting to be stored holds the next job back (a tug sent for a find is no job)
	if StoreBook.blocks_next_job() and not offers()[i].get("find", false) and not offers()[i].get("queued", false):
		if game_ref != null and is_instance_valid(game_ref) and on_close.is_valid():
			var gm = game_ref
			var waiting: Array = StoreBook.inbox()
			var pick := "i:" + str(waiting[0].uid)
			on_close.call()
			gm.open_store("all", pick)
		else:
			_refuse(StoreBook.blocked_text())
		return
	leave_from = _item_rect(i)
	leave_offer = offers()[i].duplicate(true)
	if offers()[i].get("trial_card", false):
		if not Career.active().is_empty():
			_refuse(Txt.t("trial_busy"))
			return
		var ot: Dictionary = Career.take_trial(str(offers()[i].trial))
		if ot.is_empty():
			_refuse(Txt.t("tm_none"))
			return
		show_trials = false
		_trial_cards = []
		_open_loadout(func():
			var a3: Dictionary = Career.active()
			Game.start_ship = a3.get("ship", "gr7")
			Game.contract = a3
			Copy.say(radio, "T_contract_signed", "term")
			SaveGame.load_requested = false
			sfx.play("stamp", Vector2.INF, 1.0)
			leaving = 0.0)
		return
	if offers()[i].get("story_card", false):
		# the story contract: played as the opening contract it is
		var a: Dictionary = Career.take_story()
		if a.is_empty():
			return
		_open_loadout(func():
			var a2: Dictionary = Career.active()
			Game.contract = a2
			Game.start_ship = a2.get("ship", "gr7")
			SaveGame.load_requested = false
			sfx.play("stamp", Vector2.INF, 1.0)
			leaving = 0.0)
		return
	if offers()[i].get("find", false):
		# 62 号: a belt find is sent for, not signed: the tug goes, the card leaves
		var oid := str(offers()[i].get("id", ""))
		var r := ShipMarket.tow_find(_offer_index(i))
		if not r.ok:
			_refuse(str(r.reason))
			return
		sfx.play("stamp", Vector2.INF, 1.0)
		var paid_how := Pal.money(float(r.fee))
		if r.get("free", false):
			paid_how = Ops.w("首趟免费", "the first is free")
		elif float(r.get("owe", 0.0)) > 0.0:
			paid_how = Ops.w("先赊着 %s，下次结算扣", "%s on credit till the next settlement") % Pal.money(float(r.owe))
		say(Ops.w("拖船出发了，拖运费：%s", "The tug is away (tow: %s)") % paid_how)
		sel = 0
		# user 2026-10-26: the star map opens on the tug, under way
		var gm = game_ref
		if gm != null and overlay:
			_go_page("star_map", func(): gm.watch_tow(oid))
		return
	if offers()[i].get("queued", false):
		if Career.hold(_offer_index(i)):
			sfx.play("stamp", Vector2.INF, 1.0)
			say(Txt.t("tm_held"))
		return
	var needs := _needs_course(i)
	var o: Dictionary = Career.accept(_offer_index(i))
	if o.is_empty():
		return
	# a family of ship never trained for: straight into its special courses; the loadout
	# page comes after them, then the job (25 号, player 2026-10-24)
	if needs:
		var miss := Codex.required(str(Career.active().get("ship", "")))
		if not miss.is_empty():
			Game.start_courses(miss, "contract_loadout")
			Game.contract = {}
			SaveGame.load_requested = false
			sfx.play("stamp", Vector2.INF, 1.0)
			leaving = 0.0
			return
	_open_loadout(func():
		var o2: Dictionary = Career.active()
		# a family of ship never trained for: its special courses first, then this contract
		# (design/新手教程与图鉴定案.md Q10/Q15: the contract is kept, the courses run back to back)
		var miss := Codex.required(str(o2.ship))
		if not miss.is_empty():
			Game.start_courses(miss, "contract")
			Game.contract = {}
			SaveGame.load_requested = false
			sfx.play("stamp", Vector2.INF, 1.0)
			leaving = 0.0
			return
		Game.start_ship = o2.ship
		Game.contract = o2
		Copy.say(radio, "T_contract_signed", "term")
		SaveGame.load_requested = false
		sfx.play("stamp", Vector2.INF, 1.0)
		leaving = 0.0)


# a market card whose ship needs a special course first (not the opening, trial or queued cards)
func _needs_course(i: int) -> bool:
	if i < 0 or i >= offers().size():
		return false
	var o: Dictionary = offers()[i]
	if o.get("trial_card", false) or o.get("story_card", false) or o.get("queued", false):
		return false
	return not Codex.required(str(o.get("ship", ""))).is_empty()


# back from the special courses a contract waited on: its loadout page, then the job
func _after_course_loadout() -> void:
	var a: Dictionary = Career.active()
	if a.is_empty():
		return
	_skip_boot()
	set_tab(0)
	_open_loadout(func():
		var a2: Dictionary = Career.active()
		Game.start_ship = a2.get("ship", "gr7")
		Game.contract = a2
		Copy.say(radio, "T_contract_signed", "term")
		SaveGame.load_requested = false
		sfx.play("stamp", Vector2.INF, 1.0)
		leave_from = Rect2(size * 0.5 - Vector2(200, 120), Vector2(400, 240))
		leaving = 0.0)


# the next opening contract: towed in from here, with what the berth owns now
func start_next() -> void:
	if next_job.is_empty() or leaving >= 0.0:
		return
	leave_from = _item_rect(0)
	leave_offer = {}
	Career.sign_active()
	# a job already under way (saved on site) goes straight back to it: its gear is on the ship
	var saved := SaveGame.read(SaveGame.path) if SaveGame.exists() else {}
	var resume: bool = not saved.is_empty() and saved.get("job", {}).get("id", "") == Career.active().get("id", "")
	var depart := func():
		var a: Dictionary = Career.active()
		Game.contract = a
		Game.start_ship = a.get("ship", "gr7")
		SaveGame.load_requested = resume
		sfx.play("stamp", Vector2.INF, 1.0)
		leaving = 0.0
	if resume:
		depart.call()
	else:
		_open_loadout(depart)


# a survey report on an offer: one hidden condition, read out before signing
func use_intel(i: int) -> void:
	if i < 0 or i >= offers().size():
		return
	var o: Dictionary = offers()[i]
	var d := Career.data
	if o.has("intel"):
		return
	if int(d.items.get("intel", 0)) <= 0:
		say(Txt.t("item_none") % Txt.t("it_intel"))
		return
	var ship := Variant.make(Ship.load_data(o.ship), o)
	var traps: Array = o.get("traps", [])
	o.intel = Traps.intel(ship, traps[0]) if not traps.is_empty() else ["in_none", []]
	d.items.intel = int(d.items.intel) - 1
	Career.save()
	intel_t[o.id] = 0.0
	flash = 1.0


func intel_text(o: Dictionary) -> String:
	var it: Array = o.get("intel", [])
	if it.is_empty():
		return ""
	var s := Txt.t(it[0])
	var args: Array = it[1]
	return s % args if not args.is_empty() else s


func buy(it: Array, n: int = 1) -> void:
	if it.is_empty():
		return
	var id: String = it[0]
	var price: float = it[2] * n
	var d := Career.data
	if it[1] == "skin":
		_buy_skin(id)
		return
	if overlay and not between and it[1] in ["training", "upgrade", "facility", "loan"]:
		_refuse(Txt.t("tm_onsite_no") if it[1] == "training" else Txt.t("tm_lock_equip"))
		return
	if it[1] == "training":
		# back to TS-1; finishing or leaving the course comes back here
		leave_from = _item_rect(sel)
		Game.start_ship = "ts1"
		Game.contract = {}
		SaveGame.load_requested = SaveGame.exists(SaveGame.train_path)
		leaving = 0.0
		return
	if it[1] == "loan":
		var paid := Career.repay(repay_amt if repay_amt > 0.0 else it[2])
		if paid <= 0.0:
			_refuse(Txt.t("tm_owned") if float(d.loan) <= 0.0 else Txt.t("tm_short") % Pal.money(repay_amt))
			return
		flash = 1.0
		_buy_fx(sel)
		say(Txt.t("tm_repaid") % [Pal.money(paid), Pal.money(float(d.loan))])
		repay_amt = minf(repay_amt, _repay_max())
		_check_milestone()
		return
	if it[1] == "facility":
		# the run-down berth (G2): a facility is repaired, with the parts on the shelf when they fit
		var with_parts: bool = Repair.parts_for(id).ok
		var why := Works.order_repair(id, with_parts)
		if why != "":
			_refuse(why)
			return
		install[id] = 0.0
		flash = 1.0
		_buy_fx(sel)
		say(Txt.t("rp_fixed") % Repair.name_of(id))
		if repair_panel != null:
			repair_panel.refresh()
		return
	if it[1] != "item" and d.upgrades.has(id):
		_refuse(Txt.t("tm_owned"))
		return
	if tab == DRONE_PAGE and LATE.has(id) and _late_why(id) != "":
		_refuse(_late_why(id))
		return
	if REQUIRES.has(id) and not d.upgrades.has(REQUIRES[id]):
		_refuse(Txt.t("tm_needs") % Txt.t(_facility_name(REQUIRES[id])))
		return
	if LATE.has(id) and (int(d.get("done", 0)) < int(LATE[id][0]) or int(d.get("rep", 0)) < int(LATE[id][1])):
		_refuse(Growth.text(["需要完成 %d 单、声望 %d", "Requires %d completed jobs, %d reputation"]) % [int(LATE[id][0]), int(LATE[id][1])])
		return
	if float(d.money) < price:
		_refuse(Txt.t("tm_short") % Pal.money(price - float(d.money)))
		return
	var before := d.duplicate(true)
	var before_install := install.duplicate()
	var before_job_items: Dictionary = game_ref.job.get("items", {}).duplicate() if game_ref != null else {}
	d.money = float(d.money) - price
	var desk: Dictionary = d.get("desk", {})
	desk["buy"] = int(desk.get("buy", 0)) + n
	d.desk = desk
	if it[1] == "item":
		d.items[id] = int(d.items.get(id, 0)) + n
		# bought on site: straight into the stock of the job in hand
		if overlay and not between and game_ref != null:
			var ji: Dictionary = game_ref.job.get("items", {})
			ji[id] = int(ji.get(id, 0)) + n
			game_ref.job.items = ji
	else:
		# a longer berth is built on site the next time the berth is in view (berth_build.gd):
		# remember how long it was before this
		if id.begins_with("berth") and not d.has("berth_seen"):
			d["berth_seen"] = Dock.owned(d.upgrades)
		d.upgrades[id] = 1
		install[id] = 0.0
	if not d.get("seen", {}).has("bought"):
		var seen: Dictionary = d.get("seen", {})
		seen["bought"] = true
		d.seen = seen
		Copy.say(radio, "L_first_upgrade")
	if not Career.save():
		Career.data = before
		install = before_install
		if game_ref != null:
			game_ref.job.items = before_job_items
		_refuse(Txt.t("gr_save_failed"))
		return
	flash = 1.0
	_buy_fx(sel)
	say(Txt.t("tm_bought") % (Txt.t(it[3]) + (" ×%d" % n if n > 1 else "")))


# it could not be done: the button jolts, the funds flash, and it says why
func _refuse(why: String) -> void:
	shake = 1.0
	sfx.play("deny", Vector2.INF, 0.8)
	money_flash = -1.0
	say(why)


# a purchase: a bright pass along the row, and lights leaving the funds for it
func _buy_fx(i: int) -> void:
	sfx.play("stamp", Vector2.INF, 0.9)
	sweep[i] = 0.0
	var r := _item_rect(i) if tab == 1 else _go_rect()
	for k in 14:
		sparks.append([_money_at() + Vector2(randf_range(-60, 20), randf_range(-8, 8)), Vector2(r.position.x + randf() * r.size.x, r.get_center().y + randf_range(-10, 10)), 0.0, k * 0.025])


# ---------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(60 + i * 244, 132, 230, 50)


func _item_rect(i: int) -> Rect2:
	var s := size
	match tab:
		HOME:
			return _tile_rect(i)
		0:
			# 62 号: room for a fourth card; the page's head line (on the way, the hulk market) above
			var n := float(_market_cols())
			var w := (s.x - 120 - (n - 1.0) * 30) / n
			return Rect2(60 + i * (w + 30), 236, w, s.y - 372)
		1:
			if i < FITTED:
				return _callout(i)
			return _facility_rect(i - FITTED)
		DRONE_PAGE:
			if i == _tunnel_i() or i == _tbody_i():
				var sr := _schematic_rect()
				return Rect2(sr.end.x - 294.0, sr.position.y + 150.0 + (76.0 if i == _tbody_i() else 0.0), 270.0, 66.0)
			return _callout(i) if i < DRONE_UPGRADES else _skin_rect(i - DRONE_UPGRADES)
		2:
			return _finance_rect()
		4:
			return _supply_rect(i)
		5:
			return Rect2(-100, -100, 1, 1)
		7:
			var tr := _training_page_rect()
			var pitch := _train_pitch()
			return Rect2(tr.position.x + 18, tr.position.y + 78 + i * pitch, tr.size.x - 36, pitch - 4.0)
	return Rect2(-100, -100, 1, 1)


# the home screen (2026-10-24, design/…/22_*): the port's four cells across the top, what
# waits on the operator under them, the eight pages as one row of keys along the bottom
func _home_area() -> Rect2:
	var s := size
	return Rect2(40, 200, s.x - 80, s.y - 200 - 76)


func _keys_h() -> float:
	return clampf(_home_area().size.y * 0.27, 110.0, 170.0)


func _cells_h() -> float:
	return clampf(_home_area().size.y * 0.30, 112.0, 200.0)


func _cell_rect(i: int) -> Rect2:
	var area := _home_area()
	var gap := 18.0
	# 51 号: as many cells as there are systems, filling the row
	var n := maxi(1, _ops_cells.size())
	var w := (area.size.x - gap * (n - 1)) / n
	return Rect2(area.position.x + i * (w + gap), area.position.y, w, _cells_h())


func _decs_box() -> Rect2:
	var area := _home_area()
	var y0 := area.position.y + (_next_h() if _ops_cells.is_empty() else _cells_h()) + 16.0
	return Rect2(area.position.x, y0, area.size.x, area.end.y - _keys_h() - 16.0 - y0)


func _bv_rect() -> Rect2:
	var b := _decs_box()
	if _ops_decs.is_empty():
		return b
	var lw := b.size.x * 0.34
	return Rect2(b.position.x + lw + 18.0, b.position.y, b.size.x - lw - 18.0, b.size.y)


func _dec_rect(i: int) -> Rect2:
	var b := _decs_box()
	var top := b.position.y + 34.0
	# 91 号: beside the berth's section, one column down the left
	if berth_view != null:
		var lw := b.size.x * 0.34
		var h1 := clampf((b.end.y - top - 8.0 * 4) / 5.0, 34.0, 76.0)
		return Rect2(b.position.x, top + i * (h1 + 8.0), lw, h1)
	var rows := 3
	var gap := 8.0
	var h := clampf((b.end.y - top - gap * (rows - 1)) / rows, 34.0, 76.0)
	var cw := (b.size.x - 18.0) / 2.0
	return Rect2(b.position.x + (i % 2) * (cw + 18.0), top + (i / 2) * (h + gap), cw, h)


# 61 号 (60 号 Q1/Q8): the home's one card — the next step in plain words, and "take me"
func _next_rect() -> Rect2:
	var area := _home_area()
	return Rect2(area.position.x, area.position.y, area.size.x, _next_h())


# 107 号 (user's screenshot: the card's lower half empty): as tall as its words, one line or two
var _next_two := false


func _next_h() -> float:
	return 152.0 if _next_two else 122.0


func _next_go_rect() -> Rect2:
	var r := _next_rect()
	return Rect2(r.end.x - 230, r.get_center().y - 30, 200, 60)


func _next_step_card(a: float) -> void:
	_next_action = false
	var raw := clampf((deal_t - 0.02) / 0.3, 0.0, 1.0)
	var k := Pal.ease_out(raw) * a
	if k <= 0.0:
		return
	var r := _next_rect()
	# 131 号 追加 (user: three voices on the terminal's home at once): while the port walk runs it
	# is the one voice — the main line folds to one grey line, no "take me"; back after the walk
	if _walk_quiet():
		var qc := Mainline.chapter()
		if qc != "":
			_text(Ops.w("主线 · 第 %d 章 · %s（导览结束后继续）", "MAIN LINE · CHAPTER %d · %s (AFTER THE TOUR)") % [Mainline.index(qc), Mainline.name_of(qc)], r.position + Vector2(34, 34), 15, Pal.ink(0.42 * k), font_b)
		return
	# 炭黑: a panel falling into place, a black tab with its lamp on the left
	r.position.y += Charcoal.settle(raw)
	r = Charcoal.panel(self, r, k)
	var tab_w := 150.0
	Charcoal.slab(self, Rect2(r.position, Vector2(tab_w, r.size.y)), Color(Charcoal.SCREEN, k))
	draw_rect(Rect2(r.position + Vector2(tab_w - 12, 0), Vector2(12, r.size.y)), Color(Charcoal.SCREEN, k))
	Charcoal.led(self, r.position + Vector2(28, r.size.y * 0.5), true, k, 5.0)
	_text(Ops.w("下一步", "NEXT"), r.position + Vector2(48, r.size.y * 0.5 + 7), 20, Pal.ink(k), font_s)
	var tx := tab_w + 32.0
	var ch := Mainline.chapter()
	var st := Mainline.waiting_step() if ch == "" else Mainline.step(ch)
	if st.is_empty():
		_text(Ops.w("眼下的事都做完了。", "Everything in hand is done."), r.position + Vector2(tx, r.size.y * 0.5 + 10), 26, Pal.ink(0.9 * k), font_s)
		return
	var head := str(st.get("title", "")) if ch == "" else Ops.w("第 %d 章 · %s", "CHAPTER %d · %s") % [Mainline.index(ch), Mainline.name_of(ch)]
	_text(head, r.position + Vector2(tx, 38), 15, Pal.ink(0.6 * k), font_b)
	var words := str(st.get("text", ""))
	var ww := r.size.x - tx - 280.0
	_next_two = font_s.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x > ww
	draw_multiline_string(font_s, r.position + Vector2(tx, 80), words, HORIZONTAL_ALIGNMENT_LEFT, ww, 26, 2, Pal.ink(0.97 * k), TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)
	_next_action = str(st.get("go", "")) not in ["", "wait"]
	if _next_action:
		var g := _next_go_rect()
		g.position.y += Charcoal.settle(raw)
		Hmi.push(self, font_s, g, Ops.w("带我去", "TAKE ME"), true, 1.0 if hover_next else 0.0, k, t, 0.0, "", "")




# ---------------------------------------------------------------- 131 号 追加: the port walk on the terminal
# (user 2026-11-05, a shot of the home: the walk's card "按 B 打开终端，点‘船坞’" lay over the third
# key, the orange frame sat on the first, the main line's "take me" up top — "这个引导也不是给我开船坞
# 的呀"). With the terminal open the walk's card is hidden (port_walk.gd); its step is shown on the
# key it means: the berth key lit, a small tag on it, Enter opens it; the home's own selection
# starts on it; the main line folds to one grey line while the walk runs.

# the walk's step while it runs over this terminal ("" none)
func _walk_kind() -> String:
	var g = game_ref
	if g == null or not is_instance_valid(g) or not g.has_method("walk_on") or not g.walk_on():
		return ""
	var wk = g.port_walk
	return str(wk.kind()) if wk.step < wk.steps.size() else ""


func _walk_quiet() -> bool:
	return _walk_kind() != ""


# on the home with the walk asking for the berth page
func walk_berth() -> bool:
	return tab == HOME and _walk_kind() == "repair" and _app_of(1) >= 0


var _walk_pinned := false


# the home's selection starts on the berth key once per visit to the home; the player may move it
func _walk_pin() -> void:
	if not walk_berth():
		if tab != HOME:
			_walk_pinned = false
		return
	if not _walk_pinned:
		_walk_pinned = true
		sel = _app_of(1)


# the berth key lit: a breathing ring round it and a small tag over it
func _walk_mark(a: float) -> void:
	if not walk_berth() or boot_t < BOOT_T:
		return
	var i := _app_of(1)
	var k := Pal.ease_out(clampf((deal_t - 0.35) / 0.3, 0.0, 1.0)) * a
	if k <= 0.0:
		return
	var r := _tile_rect(i)
	var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
	r.position.y -= hk * 5.0
	var breathe := 0.5 + 0.5 * sin(t * 3.4)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(18)
	ring.set_border_width_all(3)
	ring.anti_aliasing = true
	ring.border_color = Color(UiSkin.ACCENT, (0.75 + 0.25 * breathe) * k)
	ring.shadow_color = Color(UiSkin.ACCENT, (0.25 + 0.25 * breathe) * k)
	ring.shadow_size = int(8.0 + 8.0 * breathe)
	draw_style_box(ring, r.grow(8.0 + 2.0 * breathe))
	# the tag: on the key's top edge, inside the screen, never past it
	var tag := Ops.w("导览：看看船坞哪些设施坏了 · Enter 打开", "TOUR: SEE WHAT IN THE BERTH IS BROKEN · ENTER OPENS")
	var tw := font_b.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var tr := Rect2(Vector2(clampf(r.get_center().x - (tw + 26.0) * 0.5, 8.0, size.x - tw - 34.0), r.position.y - 40.0), Vector2(tw + 26.0, 28.0))
	draw_rect(tr, Color(0.03, 0.034, 0.042, 0.96 * k))
	draw_rect(Rect2(tr.position, Vector2(3.0, tr.size.y)), Color(UiSkin.ACCENT, k))
	draw_rect(tr, Color(UiSkin.ACCENT, 0.6 * k), false, 1.0)
	draw_line(Vector2(r.get_center().x, tr.end.y), Vector2(r.get_center().x, r.position.y - 8.0), Color(UiSkin.ACCENT, 0.7 * k), 1.5)
	_text(tag, tr.position + Vector2(14, 19), 14, Pal.ink(0.97 * k), font_b)


# a new career's home screen before the market opens (28 号): what to do first, plainly
func _onboard_welcome(s: Vector2, a: float) -> void:
	var r := Rect2(_cell_rect(0).position, Vector2(_home_area().size.x, _decs_box().end.y - _cell_rect(0).position.y))
	var k := Pal.ease_out(clampf((deal_t - 0.05) / 0.3, 0.0, 1.0)) * a
	Hmi.sunk(self, r, k)
	var y := r.position.y + 70.0
	_text(Ops.w("七号坞 · 回收权使用中", "BERTH 07 · UNDER SALVAGE CLAIM"), Vector2(r.position.x + 40, y), 30, Pal.ink(0.95 * k), font_s)
	var lines := [
		Ops.w("你的拖船从小行星带拖回了漂流船。拆下来的东西换成钱，钱用来把七号坞修起来。", "Your tug has towed drifting hulks in from the belt. What you strip becomes money; the money mends Berth 07."),
		Ops.w("第一步：按 1 打开合同，接下等着进坞的那艘船。", "First: press 1 for the contracts and take the hulk that is waiting."),
		Ops.w("终端里其他的东西，用到时会一样一样亮起来。", "The rest of this terminal lights up as you need it."),
	]
	for i in lines.size():
		_text(lines[i], Vector2(r.position.x + 40, y + 56 + i * 34), 18, Pal.ink((0.85 if i != 1 else 1.0) * k), font_b if i == 1 else font)


# the home screen's apps share one row
func _tile_rect(i: int) -> Rect2:
	var area := _home_area()
	var gap := 14.0
	var n := float(APPS.size())
	var w := (area.size.x - gap * (n - 1.0)) / n
	var h := _keys_h()
	return Rect2(area.position.x + i * (w + gap), area.end.y - h, w, h)


# the consumables page: four tiles, two by two, left of the detail
func _supply_rect(i: int) -> Rect2:
	var l := _left_rect()
	var gap := 22.0
	var w := (l.size.x - gap) / 2.0
	var h := (l.size.y - gap) / 2.0
	return Rect2(l.position.x + (i % 2) * (w + gap), l.position.y + (i / 2) * (h + gap), w, h)


func _training_page_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.5 - 520, 200, 1040, s.y - 270)


# the training page's rows fit between its plate and its button, however many there are
func _train_pitch() -> float:
	var tr := _training_page_rect()
	var area := tr.size.y - 78.0 - 96.0
	return clampf(area / maxf(1.0, _training_rows().size()), 34.0, 56.0)


# the header's way home
func _home_rect() -> Rect2:
	return Rect2(600, 134, 220, 46)


# the facilities in two columns under the training panel
# the facilities on the equipment page: under the drawing, five to a row
func _facility_rect(j: int) -> Rect2:
	var g := _grid_rect()
	var gap := 12.0
	# two rows, as many to a row as the facilities need
	var cols := maxi(5, ceili((BERTH.size() - 2) / 2.0))
	var w := (g.size.x - gap * (cols - 1)) / cols
	var h := (g.size.y - 40.0 - gap) / 2.0
	return Rect2(g.position.x + (j % cols) * (w + gap), g.position.y + 40.0 + (j / cols) * (h + gap), w, h)


func _facility_name(id: String) -> String:
	for b in BERTH:
		if b[0] == id:
			return b[3]
	# an upgrade (the tunnel needs the 5 t grapple): its shop name, not its id
	for it in SHOP:
		if it[0] == id:
			return it[3]
	return id


# the shop: the drawing on the left (upgrades called out on it), stock below it, detail on the right
func _left_rect() -> Rect2:
	return Rect2(60, 200, size.x * 0.58 - 60, size.y - 336)


func _schematic_rect() -> Rect2:
	var l := _left_rect()
	if tab == DRONE_PAGE:
		return l
	return Rect2(l.position, Vector2(l.size.x, l.size.y - 196))


func _grid_rect() -> Rect2:
	var l := _left_rect()
	return Rect2(l.position.x, l.end.y - 176, l.size.x, 176)


func _detail_rect() -> Rect2:
	var x := size.x * 0.58 + 30
	return Rect2(x, 200, size.x - 60 - x, size.y - 336)


# where each upgrade is called out on the drawing: a label box, joined to its part
func _callout(i: int) -> Rect2:
	var r := _schematic_rect()
	var w := 270.0
	var h := 66.0
	match i:
		0: return Rect2(r.position.x + 24, r.position.y + 24, w, h)
		1: return Rect2(r.position.x + 24, r.end.y - h - 24, w, h)
		2: return Rect2(r.end.x - w - 24, r.end.y - h - 24, w, h)
	return Rect2(r.end.x - w - 24, r.position.y + 24, w, h)


# the drone sits left of centre, the berth's boom and hose mast to its right
func _drone_c() -> Vector2:
	var r := _schematic_rect()
	return r.position + Vector2(r.size.x * 0.34, r.size.y * 0.54)


const DK := 4.0      # the drone drawn at four times its size on site
const DArt = preload("res://scripts/drone_art.gd")
const Skins = preload("res://scripts/drone_skins.gd")


# the airframes' strip along the top of the drawing, right of the first callout
func _skin_rect(i: int) -> Rect2:
	var r := _schematic_rect()
	var x0 := r.position.x + 318.0
	var n := float(Skins.ORDER.size())
	var tw := (r.end.x - 24.0 - x0 - (n - 1.0) * 8.0) / n
	return Rect2(x0 + i * (tw + 8.0), r.position.y + 52.0, tw, 80.0)


# the airframe the drawing shows: the one picked in the strip, else the one flown
func _shown_skin() -> String:
	if tab == DRONE_PAGE and sel >= DRONE_UPGRADES and sel < DRONE_UPGRADES + Skins.ORDER.size():
		return Skins.ORDER[sel - DRONE_UPGRADES]
	return Skins.current()


func _anchor(i: int) -> Vector2:
	var r := _schematic_rect()
	var c := _drone_c()
	match i:
		0: return c + Vector2(0, -Drone.R * DK - 40)
		1: return c + Vector2(-13.0 * DK, 13.0 * DK) * 0.72
		2: return Vector2(r.position.x + r.size.x * 0.8, r.position.y + r.size.y * 0.5)
	if i == _tunnel_i():
		# the grapple's head at the drone's nose: what it holds is what tunnels
		return c + Vector2(30.0, 0).rotated(-0.2) * DK
	if i == _tbody_i():
		# the drone's own hull: it is what tunnels
		return c + Vector2(Drone.R * DK * 0.7, Drone.R * DK * 0.55)
	return Vector2(r.position.x + r.size.x * 0.72, r.position.y + r.size.y * 0.3)


func _finance_rect() -> Rect2:
	return Rect2(60, 200, size.x * 0.58 - 60, size.y - 336)


func _training_rect() -> Rect2:
	var x := size.x * 0.58 + 30
	return Rect2(x, 200, size.x - 60 - x, 220)


func _slider_rect() -> Rect2:
	var f := _finance_rect()
	return Rect2(f.position.x + 36, f.position.y + 150, f.size.x - 72, 8)


func _qty_rect(d: int) -> Rect2:
	var r := _detail_rect()
	return Rect2(r.position.x + 32 + (0.0 if d < 0 else 150.0), r.end.y - 176, 48, 48)


func _go_rect() -> Rect2:
	var s := size
	match tab:
		0:
			var n := float(_market_cols())
			var w := (s.x - 120 - (n - 1.0) * 30) / n
			return Rect2(go_x.x, s.y - 122, w, 62)
		1, 4, DRONE_PAGE:
			var r := _detail_rect()
			return Rect2(r.position.x + 32, r.end.y - 100, r.size.x - 64, 68)
		2:
			var f := _finance_rect()
			return Rect2(f.position.x + 36, f.end.y - 100, f.size.x * 0.5 - 46, 68)
		5:
			return Rect2(s.x * 0.5 - 320, s.y - 118, 640, 60)
		7:
			var tr := _training_page_rect()
			return Rect2(tr.position.x + 40, tr.end.y - 84, tr.size.x - 80, 68)
	return Rect2(-100, -100, 1, 1)


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


# s cut to fit w px, with an ellipsis when it had to be cut
func _fit(s: String, f: Font, size_px: int, w: float) -> String:
	if w <= 0.0 or f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= w:
		return s
	var lo := 0
	var hi := s.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if f.get_string_size(s.substr(0, mid) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= w:
			lo = mid
		else:
			hi = mid - 1
	return s.substr(0, lo) + "…"


func _wrap(s: String, pos: Vector2, w: float, size_px: int, col: Color, lines: int = 2) -> void:
	draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, w, size_px, lines, col)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var s := size
	var lv := clampf(leaving / 0.45, 0.0, 1.0) if leaving >= 0.0 else 0.0
	# 50 号: the ground of the new look, its warm glow drifting and a light under the pointer
	Charcoal.ground(self, s)
	# the self-test: the power line first, then each part as it comes up
	Hmi.lamp_test = boot_t > 0.55 and boot_t < 0.95
	if boot_t < 0.3:
		var e := Pal.ease_out(clampf(boot_t / 0.28, 0.0, 1.0))
		draw_rect(Rect2(s.x * 0.5 * (1.0 - e), s.y * 0.5 - 1, s.x * e, 2), Pal.heat(1.0, 2.6))
		_self_test(s)
		return
	_backdrop(s, 1.0)
	var ua := 1.0 - Pal.ease_in(lv)
	_top(s, ua)
	_crumb(ua)
	var pin := _page_in()
	if pin < 1.0:
		var po := _page_out()
		if po < 1.0 and prev_tab not in [3, 5]:
			var keep := [tab, sel, deal_t]
			tab = prev_tab
			sel = prev_sel
			deal_t = 10.0
			_page_off = Vector2(-switch_dir * _slide() * po, 0.0)
			draw_set_transform(_page_off)
			_page(s, ua * (1.0 - po), false)
			tab = keep[0]
			sel = keep[1]
			deal_t = keep[2]
		_page_off = Vector2(switch_dir * _slide() * (1.0 - pin), 0.0)
		draw_set_transform(_page_off)
		_page(s, ua * pin, true)
		_page_off = Vector2.ZERO
		draw_set_transform(Vector2.ZERO)
	else:
		_page(s, ua, true)
	_bottom(s, ua * _bk(1.45, 1.8))
	_sparks()
	_radio(s, ua)
	if leaving >= 0.0:
		_leave(s, lv)
	if milestone >= 0.0:
		_milestone(s)
	_self_test(s)
	Hmi.lamp_test = false
	# 人性化 规则 4: the plain note for what is under the pointer (0.4 s)
	if _note_t >= BenchFx.NOTE_S and not settings.is_open and leaving < 0.0:
		var nt := _note_text(_note_key)
		if nt != "":
			BenchFx.draw_note(self, nt, _note_at, size)


func _page(s: Vector2, a: float, with_focus: bool) -> void:
	match tab:
		HOME:
			_home(s, a)
		0:
			_market(s, a)
		1:
			pass # Native RepairPanel draws this page.
		2:
			_berth(s, a)
		4:
			_supplies(s, a)
		5:
			pass # Native RoutePanel draws this page.
		6:
			_radio_page(s, a)
		7:
			_training_page(s, a)
		DRONE_PAGE:
			_shop(s, a)
	if with_focus:
		_focus_frame(a)
	_walk_mark(a)


# the pages whose items take the gliding frame
func _has_focus() -> bool:
	if leaving >= 0.0:
		return false
	match tab:
		HOME, 1, 4, 5, DRONE_PAGE:
			return not items().is_empty()
		0:
			return next_job.is_empty() and not offers().is_empty()
	return false


func _focus_target() -> Rect2:
	var n := items().size()
	var i := clampi(sel, 0, maxi(0, n - 1))
	var r := _item_rect(i)
	var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
	var lift := 0.0
	match tab:
		HOME:
			lift = 0.0 if _locked(APPS[i][0]) else 5.0
		0:
			lift = 6.0
		4:
			lift = 4.0
		5:
			lift = 4.0 if _route_nodes()[i].kind == "ship" else 3.0
	r.position.y -= hk * lift
	return r.grow(4.0 if tab in [HOME, 0] else 3.0)


# a gauge's shown value easing to v (from empty the first time a page shows it)
func _smooth(key: String, v: float) -> float:
	var lvl := Txt.anim_level()
	if lvl == 0:
		return v
	var cur: float = _sm.get(key, 0.0)
	cur = lerpf(cur, v, 1.0 - exp(-_dt / (0.09 if lvl >= 2 else 0.05)))
	if absf(cur - v) < 0.002:
		cur = v
	_sm[key] = cur
	return cur


func _step_focus(dt: float) -> void:
	if not _has_focus():
		_focus_tab = -99
		return
	var r := _focus_target()
	var v := [r.position.x, r.position.y, r.size.x, r.size.y]
	# a new page: the frame starts on its item, it doesn't fly across from the last page
	var snap := _focus_tab != tab or Txt.anim_level() == 0
	_focus_tab = tab
	for k in 4:
		focus[k].target = v[k]
		if snap:
			focus[k].snap(v[k])
		else:
			focus[k].step(dt)


func _focus_frame(a: float) -> void:
	if not _has_focus() or _focus_tab != tab or tab == HOME:
		return
	var r := Rect2(focus[0].x, focus[1].x, focus[2].x, focus[3].x)
	var k := Pal.ease_out(clampf((deal_t - 0.08) / 0.3, 0.0, 1.0)) * a
	var dim := tab == HOME and _locked(APPS[clampi(sel, 0, APPS.size() - 1)][0])
	# 炭黑 (2026-11-10): no glow — a thin orange edge round the chosen item and the orange lip
	# along its bottom, gliding from item to item
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(14)
	ring.set_border_width_all(1)
	ring.anti_aliasing = true
	ring.border_color = Color(Charcoal.ACCENT, 0.75 * k * (0.5 if dim else 1.0))
	draw_style_box(ring, r)
	Charcoal.lip(self, Rect2(r.position.x + 22.0, r.end.y - 6.0, r.size.x - 44.0, 3.0), k * (0.5 if dim else 1.0))


# the skill book is a control of its own: it slides with the pages
func _step_book() -> void:
	if book == null:
		return
	var off := 0.0
	if tab == 3:
		var e := _page_in()
		book.visible = true
		book.modulate.a = e
		off = switch_dir * _slide() * (1.0 - e)
	elif prev_tab == 3 and _page_out() < 1.0:
		var e2 := _page_out()
		book.visible = true
		book.modulate.a = 1.0 - e2
		off = -switch_dir * _slide() * e2
	else:
		book.visible = false
	book.offset_left = off
	book.offset_right = off


# how far one part of the self-test has come (0 dark, 1 up), between two moments of it
func _bk(a0: float, a1: float) -> float:
	return Pal.ease_out(clampf((boot_t - a0) / maxf(a1 - a0, 0.001), 0.0, 1.0))


# the self-test's log, typed in at the lower left while the terminal comes up
func _self_test(s: Vector2) -> void:
	if boot_t >= BOOT_T:
		return
	# typed while the frame comes up, gone as the cards are dealt
	var fade := clampf((1.05 - boot_t) / 0.2, 0.0, 1.0)
	if fade <= 0.0:
		return
	var lines := [Txt.t("tm_st_0"), Txt.t("tm_st_1"), Txt.t("tm_st_2"), Txt.t("tm_st_3"), Txt.t("tm_st_4"), Txt.t("tm_st_5")]
	var y0 := s.y * 0.5 + 40.0 if boot_t < 0.3 else s.y - 300.0
	for i in lines.size():
		var start := 0.05 + i * 0.13
		var n := int(clampf((boot_t - start) / 0.12, 0.0, 1.0) * lines[i].length())
		if n <= 0:
			continue
		var col := Pal.tint(UiSkin.FIGURE, 0.9 * fade, 1.4) if i < lines.size() - 1 else Pal.tint(UiSkin.FIGURE, fade, 1.8)
		_text(lines[i].substr(0, n), Vector2(60, y0 + i * 24), 16, col, font_b)


# the room the terminal sits in: a faint dot field drifting, a slow scan, dark corners
# the console the terminal sits in: plate seams, a slow scan
func _backdrop(s: Vector2, a: float) -> void:
	# 50 号: the ground is UiSkin's now; only a faint rule under the header
	Charcoal.groove(self, 40, s.x - 40, 122, a)


func _crumb(a: float) -> void:
	var ka := a * _bk(0.55, 0.85)
	if ka <= 0.0:
		return
	var pr := Rect2(40, 134, 540, 46)
	var pin := _page_in()
	draw_rect(Rect2(pr.position.x, pr.position.y + 12, 3, 22), Charcoal.accent(ka))
	var tp := pr.position + Vector2(12, pr.size.y * 0.5 + 20 * 0.36)
	if pin < 1.0:
		draw_string(font_s, tp + Vector2(-switch_dir * 16.0 * _page_out(), 0), _where(prev_tab), HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24, 20, Color(0.95, 0.96, 1.0, ka * (1.0 - _page_out())))
	draw_string(font_s, tp + Vector2(switch_dir * 16.0 * (1.0 - pin), 0), _where(tab), HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24, 20, Color(0.95, 0.96, 1.0, ka * pin))
	# the way home fades in and out with the pages that have it
	var hka := ka
	if pin < 1.0 and (tab == HOME) != (prev_tab == HOME):
		hka = ka * (pin if tab != HOME else 1.0 - _page_out())
	if tab != HOME or (pin < 1.0 and prev_tab != HOME and hka > 0.01):
		var hr := _home_rect()
		var down := 1.0 if tab_press == HOME and press_t > 0.0 else 0.0
		var hr2 := Charcoal.key(self, hr, hka, down, Charcoal.FACE_HI if hover_home else Charcoal.FACE, 8)
		_text(Txt.t("tm_home_btn"), hr2.position + Vector2(18, 30), 18, Pal.ink(0.95 * hka), font_s)
		Charcoal.keycap(self, font_s, Rect2(hr2.end.x - 58, hr2.position.y + 10, 46, 26), "ESC", hka, down)
	if Onboarding.shown("rep") and tab != HOME:
		_goal_strip(ka)


# the right of the breadcrumb row: the one or two goals, on every page
func _where(page: int) -> String:
	return Txt.t("tm_home") if page == HOME else Txt.t("tm_home") + "   ›   " + Txt.t(APPS[_app_of(page)][1])


func _goal_box() -> Rect2:
	return Rect2(840, 134, size.x - 880, 46)


func _goal_rect(i: int) -> Rect2:
	var r := _goal_box()
	var x := r.position.x + 132
	var gw := (r.end.x - x) / float(Route.MAX_PINS)
	return Rect2(x + i * gw, r.position.y, gw, r.size.y)


func _goal_strip(ka: float) -> void:
	var r := _goal_box()
	Hmi.sunk(self, r, ka)
	# 131 号 追加: while the port walk runs it is the one voice here — its line in the strip, the main
	# line under it in small grey, no goals to click
	if _walk_quiet():
		var wk = game_ref.port_walk
		var line := str(wk.body.text) if wk.body.visible and str(wk.body.text) != "" else str(wk.title.text)
		draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(UiSkin.ACCENT, ka))
		_text(Ops.w("导览", "TOUR"), Vector2(r.position.x + 18, r.position.y + 22), 14, Color(UiSkin.ACCENT, 0.95 * ka), font_b)
		draw_string(font_b, Vector2(r.position.x + 70, r.position.y + 22), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 90, 14, Pal.ink(0.95 * ka))
		var mc := Mainline.chapter()
		if mc != "":
			draw_string(font_b, Vector2(r.position.x + 70, r.position.y + 39), Ops.w("主线 · 第 %d 章 · %s（导览结束后继续）", "MAIN LINE · CHAPTER %d · %s (AFTER THE TOUR)") % [Mainline.index(mc), Mainline.name_of(mc)], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 90, 12, Pal.ink(0.42 * ka))
		return
	_text(Txt.t("rt_goals"), Vector2(r.position.x + 18, r.position.y + 29), 14, Pal.ink(0.55 * ka), font_b)
	var gs := _goals()
	# the main line takes the first place (28 号 Q17); the career's own goals follow
	var main := Mainline.chapter()
	var st := Mainline.waiting_step() if main == "" else Mainline.step(main)
	var off := 0
	if not st.is_empty():
		off = 1
		var g0 := _goal_rect(0)
		if hover_goal == 0:
			draw_rect(g0.grow(-3), Pal.ink(0.05 * ka))
		Hmi.lamp(self, Vector2(g0.position.x + 8, g0.get_center().y), Pal.heat(ka, 1.5), true, ka, 5.0)
		var nm := str(st.get("title", "")) if main == "" else Ops.w("主线 %d · %s", "MAIN %d · %s") % [Mainline.index(main), Mainline.name_of(main)]
		draw_string(font_s, Vector2(g0.position.x + 22, g0.position.y + 22), nm, HORIZONTAL_ALIGNMENT_LEFT, g0.size.x - 40, 15, Pal.ink(0.95 * ka))
		draw_string(font_b, Vector2(g0.position.x + 22, g0.position.y + 39), str(st.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, g0.size.x - 40, 12, Pal.heat(0.9 * ka, 1.2))
	if gs.is_empty():
		if off == 0:
			_text(Txt.t("rt_all_done"), Vector2(r.position.x + 132, r.position.y + 29), 15, Pal.tint(UiSkin.FIGURE, 0.9 * ka, 1.1), font_b)
		return
	for i in mini(gs.size(), Route.MAX_PINS - off):
		var n: Dictionary = gs[i]
		var g := _goal_rect(i + off)
		var hk := 1.0 if i + off == hover_goal else 0.0
		if hk > 0.0:
			draw_rect(g.grow(-3), Pal.ink(0.05 * ka))
		var pin: bool = n.get("pinned", false)
		var ready: bool = n.ready
		var col := Pal.tint(UiSkin.FIGURE, 0.9 * ka, 1.1) if ready else Pal.heat(ka, 1.3)
		Hmi.lamp(self, Vector2(g.position.x + 8, g.get_center().y), col if pin else Pal.ink(0.4 * ka), pin, ka, 5.0)
		var name: String = ("★ " if pin else "") + str(n.name).split(" · ")[0]
		var miss := Route.missing(n)
		if n.ready and not n.done:
			miss = Growth.text(["可升级", "UPGRADE"]) if n.kind == "skill" or n.get("purchase_kind", "") == "upgrade" else Growth.text(["可建设", "BUILD"])
		# a narrow strip (1280): the name and its gauge only
		if g.size.x < 240.0:
			miss = ""
		var mw := font_b.get_string_size(miss, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		# no room for every want: the first one
		if mw > g.size.x * 0.5:
			miss = miss.split(" · ")[0]
			mw = font_b.get_string_size(miss, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font_s, Vector2(g.position.x + 22, g.position.y + 22), name, HORIZONTAL_ALIGNMENT_LEFT, maxf(40.0, g.size.x - mw - 54), 15, Pal.ink((0.95 if pin else 0.7) * ka))
		_text(miss, Vector2(g.end.x - 18, g.position.y + 22), 13, col if pin or ready else Pal.ink(0.55 * ka), font_b, 1)
		Hmi.gauge(self, Rect2(g.position.x + 22, g.position.y + 31, g.size.x - 40, 7), _smooth("goal:" + str(n.key), Route.progress(n)), col if pin else Pal.ink(0.5 * ka), ka, 20)


# a goal in the header clicked: its node on the route page (a skill: the skill book)
func _open_goal(i: int) -> void:
	var gs := _goals()
	if Mainline.chapter() != "" or not Mainline.waiting_step().is_empty():
		if i == 0:
			_take_main()
			return
		i -= 1
	if i < 0 or i >= gs.size():
		return
	var n: Dictionary = gs[i]
	if tab != 5:
		set_tab(5)
	if n.kind == "tier":
		route_panel.select_category(0)
	else:
		route_panel.select_key(str(n.key))


func _top(s: Vector2, a: float) -> void:
	var d := Career.data
	var ka := a * _bk(0.25, 0.6)
	# 炭黑: the title engraved on the ground, the station and its lamp under it; the figures in
	# black windows on the right; on the home the selector knob between them
	var company: String = str(Career.data.get("company", ""))
	var title := Txt.t("tm_title")
	_text(title, Vector2(40, 76), 42, Pal.ink(0.97 * ka), font_s)
	var onsite := overlay and not between
	Charcoal.led(self, Vector2(46, 104), true, ka, 4.5, Charcoal.ACCENT if onsite else Color(0.86, 0.88, 0.86))
	var ol := Txt.t("tm_onsite_short") if onsite else Txt.t("tm_online")
	_text(ol, Vector2(60, 110), 16, Charcoal.accent(0.95 * ka) if onsite else Pal.ink(0.85 * ka), font_b)
	if s.x >= 1600.0:
		var ow := font_b.get_string_size(ol, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_text((company if company != "" else "BERTH 07") + "  ·  CHARON-DISPATCH", Vector2(60 + ow + 18, 110), 15, Pal.ink(0.55 * ka), font_b)
	var mc := Pal.ink(0.98).lerp(Pal.ink(1.0, 1.5) if money_flash > 0.0 else Pal.heat(1.0, 1.4), absf(money_flash))
	var loan_c := Pal.heat(1.0, 1.3) if float(d.loan) > 0.0 else Pal.ink(0.98)
	var cols := [[Txt.t("tm_money"), Pal.money(money_roll.shown), mc]]
	# a new career's header grows with it (28 号): the loan once it matters, the reputation once earned
	if float(d.get("loan", 0.0)) > 0.0:
		cols.append([Txt.t("tm_loan"), Pal.money(loan_roll.shown), loan_c.lerp(Pal.ink(1.0, 1.5), maxf(0.0, -loan_flash))])
		cols.append([Txt.t("tm_due"), Pal.money(minf(Career.INSTALLMENT, float(d.loan)) + snappedf(float(d.loan) * Career.INTEREST, 1.0)), Pal.ink(0.9)])
	var rep_on := Onboarding.shown("rep")
	if rep_on:
		cols.append([Txt.t("tm_rep"), Txt.t("rep_" + Career.level()), Pal.ink(0.98)])
	# narrow screens (1280): the windows give way so the title stays clear
	var rw := clampf((s.x - 520.0 - 64.0) / cols.size(), 170.0, 400.0)
	var x0 := s.x - 40 - cols.size() * rw + 16
	for i in cols.size():
		var r := Rect2(x0 + i * rw, 16, rw - 16, 96)
		var ck := a * _bk(0.35 + i * 0.08, 0.7 + i * 0.08)
		if ck <= 0.0:
			continue
		Charcoal.display(self, r, ck)
		_text(cols[i][0], r.position + Vector2(16, 26), 14, Pal.ink(0.55 * ck), font_b)
		var is_rep := rep_on and i == cols.size() - 1
		if not is_rep:
			var vs := 46 if rw >= 300.0 else 36
			_text(cols[i][1], Vector2(r.end.x - 18, r.end.y - 20), vs, Color(cols[i][2], cols[i][2].a * ck), font_l, 1)
			continue
		_text(cols[i][1], Vector2(r.end.x - 18, r.position.y + 46), 30, Color(cols[i][2], cols[i][2].a * ck), font_b, 1)
		# how far to the next level: one segment a point
		var nx := Career.to_next()
		if nx > 0:
			var lo := 0
			var hi := 0
			for l in Career.LEVELS:
				if int(d.rep) >= int(l[1]):
					lo = int(l[1])
				elif hi == 0:
					hi = int(l[1])
			var n := clampi(hi - lo, 1, 24)
			var have := _smooth("rep", clampf(float(int(d.rep) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)) * n
			var gk := a * _bk(0.7, 1.0)
			Charcoal.segments(self, Rect2(r.position.x + 16, r.end.y - 34, r.size.x - 32, 9), have, n, gk)
			_text(Txt.t("tm_rep_next") % nx, Vector2(r.end.x - 16, r.end.y - 9), 12, Pal.ink(0.5 * gk), font, 1)
	# the selector knob: on the home, turned to the chosen key
	if tab == HOME and x0 > 900.0:
		var kk := ka * _page_in()
		Charcoal.knob(self, font_b, Vector2(x0 - 120.0, 70.0), knob_f.x, APPS.size(), kk, "", 0.72)




# risk stars pop in one after another
func _stars(n: int, p: Vector2, a: float, delay: float) -> void:
	for i in 3:
		var c := p + Vector2(i * 18, 0)
		var pk := Pal.back(clampf((deal_t - delay - i * 0.08) / 0.25, 0.0, 1.0), 3.0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := (7.0 if k % 2 == 0 else 3.0) * (pk if i < n else 1.0)
			pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5 + (1.0 - pk) * 0.8) * r)
		if i < n:
			if pk > 0.02:
				draw_colored_polygon(pts, Pal.heat(0.9 * a, 1.0 + 0.6 * (1.0 - clampf((deal_t - delay - i * 0.08 - 0.25) / 0.4, 0.0, 1.0))))
		else:
			pts.append(pts[0])
			draw_polyline(pts, Pal.ink(0.25 * a), 1.0, true)


# 62 号: three or four cards across the find-ships page
func _market_cols() -> int:
	return clampi(offers().size(), 3, 4)


func _shipmkt_rect() -> Rect2:
	return Rect2(306, 186, 230, 42) if Scan.ON else Rect2(60, 186, 230, 42)


# the find-ships page would only say "sweep the belt": no card, no next job, nothing on the way
# (user 2026-11-04: "没找到船的话，应该直接跳到星图扫描的界面" — the hulk market open or not; the star
# map's find page has its own key to the hulk market)
func _find_empty() -> bool:
	return Scan.ON and next_job.is_empty() and not show_trials and offers().is_empty() and ShipMarket.on_the_way().is_empty()


# 68 号: the star map's sweep, the way to new hulks
func _scan_rect() -> Rect2:
	return Rect2(60, 186, 230, 42)


# the find-ships page's head: the hulk market's key, and the hulks on their way home
func _find_head(a: float) -> void:
	var r := _shipmkt_rect()
	var open := ShipMarket.open()
	if Scan.ON:
		var sr := _scan_rect()
		Hmi.push(self, font_s, sr, Ops.w("星图扫描找船", "SWEEP THE BELT"), true, 1.0 if sr.has_point(get_local_mouse_position()) else 0.0, a, t, 0.0, "", Keys.label("starmap"))
	Hmi.push(self, font_s, r, Ops.w("二手船市", "HULK MARKET"), open, 1.0 if open and r.has_point(get_local_mouse_position()) else 0.0, a, t, 0.0, "", "")
	var way := ShipMarket.on_the_way()
	var line := Ops.w("贸易区修好后才能去二手船市买船。", "The hulk market opens once the trade district is mended.") if not open else ""
	if not way.is_empty():
		line = Ops.w("在路上 %d 艘，最快的约 %d 秒后到港。", "%d on the way; the first in about %d s.") % [way.size(), int(float(way[0].left_s))]
	if line != "":
		_text(line, Vector2(r.end.x + 24, r.position.y + 18), 16, Pal.ink(0.75 * a), font_b)
	# 72 号: the tug yard and the tugs
	_text(TugYard.status(), Vector2(r.end.x + 24, r.position.y + 40), 14, Pal.ink(0.6 * a), font)


func _market(s: Vector2, a: float) -> void:
	if not next_job.is_empty():
		_next_card(s, a)
		return
	if not (overlay and not between):
		_find_head(a)
	var os := offers()
	if os.is_empty():
		_text(Ops.w("还没找到船。点上面“星图扫描找船”，去小行星带扫一扫。", "No hulks found yet. Sweep the belt on the star map.") if Scan.ON else Txt.t("tm_none"), Vector2(s.x * 0.5, s.y * 0.45), 18, Pal.ink(0.6 * a), font, 0)
		return
	# what the cards are compared by: the net, and the net per minute of standard time
	var best_net := -1
	var best_rate := -1
	for i in os.size():
		if os[i].get("story_card", false):
			continue
		if best_net < 0 or _net(os[i]) > _net(os[best_net]):
			best_net = i
		if best_rate < 0 or _rate(os[i]) > _rate(os[best_rate]):
			best_rate = i
	# the way to the trial contracts and back (G1): a line over the cards
	if not overlay:
		_text(Txt.t("tm_trials_back" if show_trials else "tm_trials_hint"), Vector2(s.x - 60, 190), 14, Pal.heat(0.85 * a, 1.1) if show_trials else Pal.ink(0.55 * a), font_b, 1)
	for i in os.size():
		var o: Dictionary = os[i]
		var r := _item_rect(i)
		var on := i == sel
		var hk: float = hover_k[i].x
		var sk: float = sel_k[i].x
		var k := Pal.ease_out(clampf((deal_t - 0.06 - i * 0.07) / 0.35, 0.0, 1.0)) * a
		if leaving >= 0.0 and on:
			continue
		if o.get("story_card", false):
			_story_card(o, r, k, hk, sk)
			continue
		if o.get("trial_card", false):
			_trial_card(o, r, k, hk, sk)
			continue
		# dealt from below, lifted on hover; the chosen one framed in heat
		r.position.y += (1.0 - k) * 36.0 - hk * 6.0
		Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
		var x := r.position.x + 28
		var w := r.size.x - 56
		var y := r.position.y
		var row_k := func(n: int) -> float: return Pal.ease_out(clampf((deal_t - 0.15 - i * 0.07 - n * 0.035) / 0.3, 0.0, 1.0)) * a
		var ty: Dictionary = Market.type_of(o.ship)
		var scope: String = o.get("scope", "full")
		# 1 · the plate: what kind of job; its lamp heat for a part job
		var pl := Rect2(r.position.x + 18, y + 18, r.size.x - 36, 46)
		var drift: bool = o.get("owner", "") == "salvage"
		var bought: bool = o.get("bought", false)
		Hmi.plate(self, font_s, pl, Txt.t(("sc_found" if o.get("found", false) else "sc_bought") if bought else ("sc_drift" if drift else "sc_" + scope)), 21, k)
		Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col() if scope != "full" else Hmi.ok_col(), true, k, 7.0)
		_text(Txt.t("tm_contract_n") % o.id, Vector2(pl.end.x - 44, pl.get_center().y + 6), 13, Pal.ink(0.5 * k), font, 1)
		# 炭黑 v2: the card's number, large (orange on the chosen one), the ship's name after it
		_text("%02d" % (i + 1), Vector2(x - 2, y + 103), 32, Color(Charcoal.ACCENT, row_k.call(0)) if on else Pal.ink(0.55 * row_k.call(0)), font_l)
		_text(_fit("%s  ·  %s  ·  %d m" % [o.reg, (ty.name[0] if Txt.zh else ty.name[1]), int(ty.get("length", 0))], font_s, 18, w - 52.0), Vector2(x + 52, y + 98), 18, Pal.ink(0.9 * row_k.call(0)), font_s)
		# 2 · the screen: the number to choose by, and the ship
		var sc := Rect2(r.position.x + 18, y + 116, r.size.x - 36, 248)
		var hk2: float = row_k.call(1)
		Hmi.screen(self, sc, hk2)
		var net := _net(o)
		var cnt := Pal.ease_out(clampf((deal_t - 0.2 - i * 0.07) / 0.7, 0.0, 1.0))
		_text(Txt.t("tm_net"), sc.position + Vector2(16, 30), 15, Pal.ink(0.6 * hk2), font_b)
		_text(Pal.money(snappedf(net * cnt, 100.0)), sc.position + Vector2(12, 104), 64, Pal.tint(UiSkin.FIGURE, hk2, 1.35) if net >= 0.0 else Pal.heat(0.95 * hk2, 1.3), font_l)
		_text(Txt.t("tm_per_min") % Pal.money(snappedf(_rate(o), 10.0)), Vector2(sc.end.x - 16, sc.position.y + 32), 17, Pal.ink(0.9 * hk2), font_s, 1)
		_text(Txt.t("tm_minutes") % int(float(o.time) / 60.0), Vector2(sc.end.x - 16, sc.position.y + 56), 14, Pal.ink(0.6 * hk2), font, 1)
		_thumb(o, Rect2(sc.position.x + 16, sc.position.y + 126, sc.size.x - 32, 108), row_k.call(2))
		# what is new on this ship (scripts/codex.gd), on the screen under the rate: a click opens the codex on it
		var mechs := Codex.ship_entries(str(o.ship))
		_cx_link.erase(i)
		if not mechs.is_empty():
			var ln := Txt.t("cxu_brief") + "  " + Codex.title(mechs[0]) + ("  +%d" % (mechs.size() - 1) if mechs.size() > 1 else "")
			# never over the big figure (English runs long): cut to what is left of the screen's width
			var nw := font_l.get_string_size(Pal.money(snappedf(net, 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			var lw: float = minf(font_b.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, minf(sc.size.x * 0.55, sc.size.x - nw - 70.0))
			ln = _fit(ln, font_b, 13, lw)
			var lr := Rect2(sc.end.x - 22 - lw, sc.position.y + 70, lw + 12, 24)
			_cx_link[i] = lr
			var hot := lr.has_point(get_local_mouse_position())
			if hot:
				draw_rect(lr, Pal.ink(0.08 * hk2))
			draw_string(font_b, Vector2(lr.position.x + 6, lr.position.y + 17), ln, HORIZONTAL_ALIGNMENT_LEFT, lw, 13, Pal.heat((0.95 if hot else 0.8) * hk2, 1.05))
		# 3 · risk as a three-step gauge, and the best of the three said plainly
		var rk2: float = row_k.call(3)
		_text(Txt.t("tm_risk_h"), Vector2(x, y + 398), 15, Pal.ink(0.6 * rk2), font_b)
		Hmi.gauge(self, Rect2(x + 56, y + 382, 150, 22), float(o.stars) / 3.0, Pal.heat(1.0, 1.3), rk2, 3)
		_text(Txt.t("tm_risk_" + str(int(o.stars))), Vector2(x + 218, y + 399), 15, Pal.ink(0.8 * rk2), font_b)
		var badges: Array = []
		if i == best_net and os.size() > 1:
			badges.append(Txt.t("tm_best_net"))
		if i == best_rate and os.size() > 1:
			badges.append(Txt.t("tm_best_rate"))
		if o.get("held", false):
			badges.append(Txt.t("tm_held_badge"))
		var bx := x + w
		for bdg in badges:
			var bw := font_s.get_string_size(bdg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
			bx -= bw
			draw_rect(Rect2(bx, y + 380, bw, 26), Pal.tint(UiSkin.FIGURE, 0.9 * rk2, 1.0))
			_text(bdg, Vector2(bx + 9, y + 398), 14, Color(0.03, 0.05, 0.03, rk2), font_s)
			bx -= 8.0
		# 4 · what the job is, on the ship
		var task := Market.scope_text(o) if scope != "full" else Txt.t("tm_task_drift" if drift else "tm_task_full")
		c_wrap(task, Vector2(x, y + 440), w, 15, Pal.ink(0.88 * row_k.call(3)))
		if Market.goal_text(o) != "":
			_text(Market.goal_text(o), Vector2(x, y + 486), 13, Pal.tint(UiSkin.FIGURE, 0.9 * row_k.call(3), 1.1), font_b)
		# 5 · the money, line by line
		var due := Career.due_for(o)
		var lines := [
			[Txt.t("tm_value"), Pal.money(float(o.value))],
			[Txt.t("tm_fee_bought" if bought else ("tm_fee_drift" if drift else "tm_fee")), ("−" + Pal.money(float(o.get("paid", 0.0)))) if bought else "−" + Pal.money(float(o.fee))],
			[Txt.t("tm_due_c"), "−" + Pal.money(due)],
		]
		# 炭黑 v2: the money in a black window of its own
		Charcoal.display(self, Rect2(x - 12, y + 494, w + 24, 80), row_k.call(4), 8)
		for jx in lines.size():
			var yy := y + 515 + jx * 25
			var jk: float = row_k.call(4 + jx)
			_text(lines[jx][0], Vector2(x, yy), 14, Pal.ink(0.6 * jk), font)
			_text(lines[jx][1], Vector2(r.end.x - 28, yy), 16, Pal.ink(0.92 * jk), font_s, 1)
		if o.get("queued", false):
			_text(Txt.t("tm_queued"), Vector2(x, y + 588), 13, Pal.heat(0.9 * k, 1.1), font_b)
		elif float(Career.data.money) < float(o.fee):
			_text(Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(Career.data.money)), Vector2(x, y + 588), 13, Pal.heat(0.9 * k, 1.1), font)
		# 6 · the paperwork: why it was scrapped, what the logs say, what is declared
		var pk: float = row_k.call(8)
		draw_line(Vector2(x, y + 596), Vector2(x + w, y + 596), Color(0, 0, 0, 0.5 * pk), 2.0)
		# the labels' column as wide as its longest label (the English ones ran under the text)
		var lab_w := maxf(96.0, maxf(font.get_string_size(Txt.t("tm_origin" if drift else "tm_reason"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, font.get_string_size(Txt.t("tm_logs"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 14.0)
		_text(Txt.t("tm_origin" if drift else "tm_reason"), Vector2(x, y + 620), 13, Pal.ink(0.55 * pk), font)
		_text(_fit((Txt.t("tm_found_v" if o.get("found", false) else "tm_bought_v") % Pal.money(float(o.get("paid", 0.0)))) if bought else (Txt.t("tm_drift_v") % int(o.get("drift_years", 0)) if drift else Copy.slot(o.reason)), font, 14, w - lab_w), Vector2(x + lab_w, y + 620), 14, Pal.ink(0.8 * pk), font)
		_text(Txt.t("tm_logs"), Vector2(x, y + 646), 13, Pal.ink(0.55 * pk), font)
		var ly := y + 646.0
		# 2026-11-10: every line kept inside the card (long logs ran into the next card)
		for li in mini(2, o.logs.size()):
			_text(_fit("› " + Copy.slot(o.logs[li]), font, 14, w - lab_w), Vector2(x + lab_w, ly), 14, Pal.tint(UiSkin.FIGURE, 0.85 * pk, 1.0), font)
			ly += 21.0
		var parts: Array = []
		for cg in o.get("cargo", []):
			parts.append("%s %s" % [cg[0], Txt.cargo(cg[1])])
		_text(_fit(Txt.t("tm_cargo") + "  " + ("  ·  ".join(parts) if not parts.is_empty() else Txt.t("tm_no_cargo")), font, 13, w), Vector2(x, ly + 10), 13, Pal.ink(0.7 * pk), font)

		# a survey report bought for this offer: typed in behind a scan line, on its own screen
		if o.has("intel"):
			var it_t := intel_t.get(o.id, 9.0) as float
			var shown := intel_text(o).substr(0, int(it_t * 40.0))
			var ir := Rect2(r.position.x + 18, r.end.y - 70, r.size.x - 36, 52)
			Hmi.screen(self, ir, k)
			_text(Txt.t("tm_intel"), ir.position + Vector2(12, 20), 13, Pal.tint(UiSkin.FIGURE, 0.85 * k, 1.0), font)
			_text(shown, ir.position + Vector2(12, 42), 14, Pal.tint(UiSkin.FIGURE, 0.95 * k, 1.2), font)
			if it_t < 1.0:
				draw_rect(Rect2(ir.position.x + ir.size.x * it_t, ir.position.y, 2, ir.size.y), Pal.tint(UiSkin.FIGURE, (1.0 - it_t) * k, 2.0))
		else:
			# the caveat sits right of the paperwork's rule, clear of the cargo line
			_text(_fit(Txt.t("tm_logs_note"), font, 12, w * 0.6), Vector2(x + w, y + 588), 12, Pal.ink(0.45 * pk), font, 1)



func _net(o: Dictionary) -> float:
	return float(o.value) - float(o.fee) - Career.due_for(o)


func _rate(o: Dictionary) -> float:
	return _net(o) / maxf(1.0, float(o.time) / 60.0)


func c_wrap(s: String, pos: Vector2, w: float, size_px: int, col: Color) -> void:
	draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, w, size_px, 2, col)


# a cross-section of the ship on the card: only what the paperwork mentions —
# the declared containers, the named pieces of a rescue, the part a contract buys
func _thumb(o: Dictionary, r: Rect2, a: float) -> void:
	if not thumbs.has(o.id):
		var d := Variant.make(Ship.load_data(o.ship), o)
		var marks: Array = []
		var want: Array = []
		for cg in o.get("cargo", []):
			want.append(cg[0])
		for tg in o.get("scope_tags", []):
			want.append(tg)
		for pd in d.pieces:
			if pd.get("tag", "") in want:
				marks.append([Variant._cx(pd), _cy(pd), pd.tag, pd.tag in o.get("scope_tags", [])])
		# the ship's own outline: its structure, as the file draws it
		var outline: Array = []
		var y0 := 0.0
		var y1 := 0.0
		for pd in d.pieces:
			if pd.kind in ["hull", "hatch", "keel", "beam", "strut", "rail", "deck", "bulkhead"]:
				var pts := PackedVector2Array()
				for q in pd.poly:
					pts.append(Vector2(q[0], q[1]))
					y0 = minf(y0, q[1])
					y1 = maxf(y1, q[1])
				pts.append(pts[0])
				outline.append(pts)
		thumbs[o.id] = {"marks": marks, "len": float(d.get("length", 42.0)), "outline": outline, "h": maxf(8.0, y1 - y0 + 1.0), "mid": (y0 + y1) * 0.5,
			"sx": Variant.section_x(d)}
	var th: Dictionary = thumbs[o.id]
	var L: float = th.len
	var sc := minf(r.size.x / L, r.size.y / th.h)
	var org := Vector2(r.position.x + (r.size.x - L * sc) * 0.5, r.get_center().y - th.mid * sc)
	var SX: float = th.sx
	var P := func(v: Vector2) -> Vector2: return org + v * sc
	draw_rect(r, Color(0, 0, 0, 0.25 * a))
	# the part the contract buys, shaded
	match o.get("scope", "full"):
		"section":
			var hh: float = th.h * 0.5
			draw_rect(Rect2(P.call(Vector2(SX, th.mid - hh)), Vector2((L - SX) * sc, th.h * sc)), Pal.heat(0.16 * a, 1.0))
			draw_dashed_line(P.call(Vector2(SX, th.mid - hh)), P.call(Vector2(SX, th.mid + hh)), Pal.heat(0.9 * a, 1.2), 1.4, 5.0)
	for pts in th.outline:
		var sp := PackedVector2Array()
		for v in pts:
			sp.append(P.call(v))
		draw_polyline(sp, Pal.ink(0.45 * a), 1.0, true)
	for m in th.marks:
		var p: Vector2 = P.call(Vector2(m[0], m[1]))
		var hot: bool = m[3]
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Pal.heat(0.9 * a, 1.2) if hot else Pal.tint(UiSkin.FIGURE, 0.85 * a, 1.0), false, 1.4)
		_text(m[2], p + Vector2(-14, -10), 12, Pal.heat(0.85 * a, 1.1) if hot else Pal.tint(UiSkin.FIGURE, 0.75 * a, 1.0), font)


func _cy(pd: Dictionary) -> float:
	var yv := 0.0
	for q in pd.poly:
		yv += float(q[1])
	return yv / maxf(1.0, pd.poly.size())


# ---------------------------------------------------------------- the shop

func _shop(_s: Vector2, a: float) -> void:
	var sr := _schematic_rect()
	var ka := Pal.ease_out(clampf(deal_t / 0.4, 0.0, 1.0)) * a
	# the drawing on its own screen, set in a panel with its plate
	var pr := Rect2(sr.position.x - 8, sr.position.y - 8, sr.size.x + 16, sr.size.y + 16)
	Hmi.raised(self, pr, ka)
	Hmi.screen(self, sr, ka, true)
	_schematic(sr, ka)
	for i in DRONE_UPGRADES:
		_callout_box(i, ka)
	for i in Skins.ORDER.size():
		_skin_tile(DRONE_UPGRADES + i, ka)
	_tunnel_box(_tunnel_i(), ka)
	_tunnel_box(_tbody_i(), ka, "tunnel_body")
	# how to read the lamps
	var ly := sr.position.y + 30
	var keys := [[Hmi.ok_col(), Txt.t("tm_lamp_have")], [Hmi.can_col(), Txt.t("tm_lamp_can")], [Hmi.warn_col(), Txt.t("tm_lamp_short")]]
	var lx := sr.get_center().x - 160
	for kk in keys:
		Hmi.lamp(self, Vector2(lx, ly - 5), kk[0], true, ka, 6.0)
		_text(kk[1], Vector2(lx + 16, ly), 14, Pal.ink(0.7 * ka), font_b)
		lx += 120
	_detail(a)


# the drone and the berth in line, each upgrade on the part it changes:
# fitted parts solid, the ones not bought as a faint dashed outline
func _schematic(sr: Rect2, a: float) -> void:
	var d := Career.data
	var c := _drone_c()
	var R := Drone.R * DK
	# the berth: floor, tower, boom (in the right part of the drawing)
	var bx0 := sr.position.x + sr.size.x * 0.52
	var by := sr.position.y + sr.size.y * 0.24
	var fy := sr.end.y - 40.0
	var tx := sr.end.x - 40.0
	draw_line(Vector2(bx0, fy), Vector2(sr.end.x - 16, fy), Pal.tint(UiSkin.FIGURE, 0.5 * a), 1.6)
	draw_line(Vector2(tx, fy), Vector2(tx, by - 20), Pal.tint(UiSkin.FIGURE, 0.5 * a), 1.6)
	draw_line(Vector2(tx - 12, fy), Vector2(tx - 12, by - 20), Pal.tint(UiSkin.FIGURE, 0.3 * a), 1.0)
	draw_line(Vector2(bx0, by), Vector2(tx, by), Pal.tint(UiSkin.FIGURE, 0.5 * a), 1.6)
	draw_line(Vector2(bx0, by - 12), Vector2(tx, by - 12), Pal.tint(UiSkin.FIGURE, 0.3 * a), 1.0)
	var zx := bx0
	while zx < tx - 12:
		draw_line(Vector2(zx, by), Vector2(zx + 12, by - 12), Pal.tint(UiSkin.FIGURE, 0.22 * a), 1.0)
		zx += 24.0
	_text("BERTH 07", Vector2(bx0, by - 22), 14, Pal.tint(UiSkin.FIGURE, 0.7 * a), font_b)
	# the hose mast from the floor
	var pa := _anchor(2)
	draw_line(Vector2(pa.x, fy), Vector2(pa.x, pa.y + 14), Pal.tint(UiSkin.FIGURE, 0.5 * a), 1.6)
	draw_rect(Rect2(pa + Vector2(-16, -10), Vector2(30, 26)), Pal.tint(UiSkin.FIGURE, 0.6 * a), false, 1.4)
	# the drone: the airframe as it flies, drawn four times over in blueprint blue
	var xf := Transform2D(0.0, Vector2(DK, DK), 0.0, c)
	draw_set_transform_matrix(xf)
	DArt.tint = Color(UiSkin.FIGURE.r * 1.1 * a, UiSkin.FIGURE.g * 1.1 * a, UiSkin.FIGURE.b * 1.1 * a)
	Skins.draw(self, _shown_skin(), {"heading": -0.2, "tool": 1, "open": 1.0, "t": t, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
	DArt.tint = Color(1, 1, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_text("R-02", c + Vector2(-22, R + 40), 18, Pal.tint(UiSkin.FIGURE, 0.85 * a, 1.2), font_s)
	# The three tool upgrades on the drone page.
	for i in DRONE_UPGRADES:
		var id: String = SHOP[i][0]
		var have: bool = d.upgrades.has(id)
		var it: float = install.get(id, -1.0)
		var k := 1.0
		var off := Vector2.ZERO
		if it >= 0.0:
			# being fitted: it comes down onto its mount and settles
			var e := Pal.back(clampf((it - 0.15) / 0.5, 0.0, 1.0), 2.2)
			off = Vector2(0, -46.0 * (1.0 - e))
			k = clampf((it - 0.15) / 0.2, 0.0, 1.0)
			if it > 0.55 and it < 1.3:
				var re := Pal.ease_out((it - 0.55) / 0.75)
				draw_arc(_anchor(i), 14.0 + 70.0 * re, 0.0, TAU, 40, Pal.heat((1.0 - re) * a, 2.0), 2.0, true)
		_part(i, have, k * a, off)
		# the chosen one breathes
		if i == sel:
			var p := _anchor(i)
			draw_arc(p, 22.0 + 3.0 * sin(t * 4.0), 0.0, TAU, 32, Pal.heat(0.75 * a, 1.3), 1.6, true)
	# 量子隧穿: a phase ring round the grapple's head — dashed until fitted, then turning and lit
	var tp := _anchor(_tunnel_i())
	var t_have: bool = d.upgrades.has("tunnel")
	var tcol := Pal.tint(UiSkin.FIGURE, (0.95 if t_have else 0.4) * a, 1.3 if t_have else 1.0)
	for k2 in 12:
		var a0 := TAU * k2 / 12.0 + (t * 0.8 if t_have else 0.0)
		draw_arc(tp, 30.0, a0, a0 + TAU / 12.0 * (0.8 if t_have else 0.45), 6, tcol, 1.6 if t_have else 1.1, true)
	if t_have:
		draw_arc(tp, 30.0 + 5.0 * fposmod(t * 0.7, 1.0), 0.0, TAU, 40, Pal.tint(UiSkin.FIGURE, 0.35 * a * (1.0 - fposmod(t * 0.7, 1.0)), 1.3), 1.0, true)
	if sel == _tunnel_i():
		draw_arc(tp, 38.0 + 3.0 * sin(t * 4.0), 0.0, TAU, 32, Pal.heat(0.75 * a, 1.3), 1.6, true)


func _part(i: int, have: bool, a: float, off: Vector2) -> void:
	var col := Pal.tint(UiSkin.FIGURE, 0.95 * a, 1.3) if have else Pal.tint(UiSkin.FIGURE, 0.4 * a)
	var w := 2.0 if have else 1.2
	var c := _drone_c()
	match i:
		0:
			# the inspection head: a dish on a mast above the drone
			var top := c + Vector2(0, -Drone.R * DK) + off
			_line(top, top + Vector2(0, -28), col, w, have)
			_arc(top + Vector2(0, -32), 20.0, PI * 1.1, PI * 1.9, col, w, have)
			draw_circle(top + Vector2(0, -44), 5.0, Pal.tint(UiSkin.FIGURE, (0.9 if have else 0.3) * a, 1.3))
		1:
			# the tractor emitter: a heavy ring round the lens and two coil blocks
			var cc := c + off
			_arc(cc, 12.5 * DK, 0.0, TAU, col, w + 1.0, have)
			for sd in [-1.0, 1.0]:
				var q: Vector2 = cc + Vector2.from_angle(PI * 0.75 + sd * 0.9) * 13.0 * DK
				_rect(Rect2(q - Vector2(12, 12), Vector2(24, 24)), col, w, have)
		2:
			# the high-flow pump: a second, bigger housing with an impeller ring
			var p := _anchor(2) + Vector2(30, 0) + off
			_rect(Rect2(p + Vector2(-6, -18), Vector2(44, 44)), col, w, have)
			_arc(p + Vector2(16, 4), 14.0, 0.0, TAU, col, w, have)
		3:
			# the recovery arm: a trolley on the boom, a cable and a claw
			var p2 := _anchor(3) + off
			_rect(Rect2(p2 + Vector2(-40, -14), Vector2(80, 26)), col, w, have)
			_line(p2 + Vector2(0, 12), p2 + Vector2(0, 110), col, w, have)
			for sd in [-1.0, 1.0]:
				_line(p2 + Vector2(0, 110), p2 + Vector2(sd * 16, 128), col, w, have)
				_line(p2 + Vector2(sd * 16, 128), p2 + Vector2(sd * 8, 144), col, w, have)


func _line(a0: Vector2, b0: Vector2, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_line(a0, b0, col, w, true)
	else:
		draw_dashed_line(a0, b0, col, w, 6.0)


func _arc(c: Vector2, r: float, from: float, to: float, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_arc(c, r, from, to, 40, col, w, true)
		return
	var n := maxi(6, int(r * absf(to - from) / 10.0))
	for i in n:
		if i % 2 == 0:
			draw_arc(c, r, lerpf(from, to, float(i) / n), lerpf(from, to, float(i + 1) / n), 4, col, w, true)


func _rect(r: Rect2, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_rect(r, col, false, w)
		return
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(p[i], p[(i + 1) % 4], col, w, 6.0)


# an upgrade's label on the drawing, joined to its part
# an upgrade's plate on the drawing, joined to its part: its lamp says fitted,
# can be had, or short of money
func _callout_box(i: int, a: float) -> void:
	var it: Array = SHOP[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var have: bool = Career.data.upgrades.has(it[0])
	var short: bool = not have and float(Career.data.money) < float(it[2])
	var k := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.x += (1.0 - k) * (-30.0 if r.position.x < size.x * 0.3 else 30.0)
	var p := _anchor(i)
	var edge := Vector2(r.end.x if p.x > r.end.x else r.position.x, r.get_center().y)
	draw_line(edge, p, Pal.tint(UiSkin.FIGURE, (0.35 + 0.45 * maxf(hk, sk)) * k), 1.2, true)
	draw_circle(p, 4.0, Pal.heat(k, 1.3) if sk > 0.5 else Pal.tint(UiSkin.FIGURE, 0.9 * k, 1.3))
	Hmi.raised(self, r, k, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	Hmi.lamp(self, r.position + Vector2(22, r.size.y * 0.5), Hmi.ok_col() if have else (Hmi.warn_col() if short else Hmi.can_col()), true, k)
	_text(Txt.t(it[3]), r.position + Vector2(42, 28), 17, Pal.ink(0.96 * k), font_s)
	if have:
		_text(Txt.t("tm_installed"), r.position + Vector2(42, 54), 16, Pal.tint(UiSkin.FIGURE, 0.95 * k, 1.1), font_s)
	else:
		_text(Pal.money(it[2]), r.position + Vector2(42, 54), 16, Pal.ink((0.9 if not short else 0.55) * k), font_s)
	if short:
		_text(Txt.t("tm_short_n") % Pal.money(float(it[2]) - float(Career.data.money)), Vector2(r.end.x - 12, r.position.y + 54), 13, Pal.heat(0.9 * k, 1.2), font_b, 1)


# a consumable: a cell with its mark, how many are in stock, and the price
# a facility on the equipment page: lamp, name, price or fitted
func _fac_cell(i: int, it: Array, a: float) -> void:
	var r := _item_rect(i)
	var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
	var sk: float = sel_k[i].x if i < sel_k.size() else 0.0
	var k := Pal.ease_out(clampf((deal_t - 0.18 - (i - FITTED) * 0.03) / 0.3, 0.0, 1.0)) * a
	var d := Career.data
	var have: bool = d.upgrades.has(it[0])
	var locked: bool = not have and REQUIRES.has(it[0]) and not d.upgrades.has(REQUIRES[it[0]])
	var short: bool = not have and float(d.money) < float(it[2])
	Hmi.raised(self, r, k, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	Hmi.lamp(self, r.position + Vector2(16, 20), Hmi.ok_col() if have else (Hmi.warn_col() if locked or short else Hmi.can_col()), true, k, 5.0)
	_text(Txt.t(it[3]), r.position + Vector2(30, 26), 14, Pal.ink(0.95 * k), font_s)
	_text(Txt.t("tm_installed") if have else Pal.money(it[2]), r.position + Vector2(30, r.size.y - 12), 13, Pal.tint(UiSkin.FIGURE, 0.95 * k, 1.1) if have else Pal.ink((0.85 if not short and not locked else 0.45) * k), font_b)


# a consumable: a tile with its mark, its stock window, the price
func _cell(i: int, a: float) -> void:
	var it: Array = _supply_items()[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var k := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.y += (1.0 - k) * 24.0 - hk * 4.0
	Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	var n := int(Career.data.items.get(it[0], 0))
	var sc := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, r.size.y * 0.5)
	Hmi.screen(self, sc, k)
	draw_set_transform(sc.get_center(), 0.0, Vector2(2.0, 2.0))
	_icon(it[0], Vector2.ZERO, k)
	draw_set_transform(Vector2.ZERO)
	var sw := Rect2(r.end.x - 110, sc.end.y + 16, 92, 60)
	Hmi.screen(self, sw, k)
	_text("×%d" % n, sw.get_center() + Vector2(0, 13), 34, Pal.tint(UiSkin.FIGURE, 0.95 * k, 1.4) if n > 0 else Pal.ink(0.35 * k), font_s, 0)
	_text(Txt.t(it[3]), Vector2(r.position.x + 22, sc.end.y + 46), 24, Pal.ink(0.96 * k), font_s)
	var afford := float(Career.data.money) >= float(it[2])
	_text(Pal.money(it[2]), Vector2(r.position.x + 22, sc.end.y + 78), 18, Pal.ink((0.85 if afford else 0.4) * k), font_b)
	var how: String = Txt.t("tm_use_auto") if it[0] == "spare" else (Txt.t("tm_use_intel_at") if it[0] == "intel" else Txt.t("tm_use") % USE_KEY[it[0]])
	_text(how, Vector2(r.position.x + 22, r.end.y - 18), 14, Pal.tint(UiSkin.FIGURE, 0.85 * k, 1.1), font_b)
	if sweep.has(i):
		_sweep(r, sweep[i])


func _icon(id: String, p: Vector2, a: float) -> void:
	var col := Pal.ink(0.85 * a)
	match id:
		"repair":
			draw_rect(Rect2(p + Vector2(-16, -5), Vector2(32, 10)), col, false, 1.6)
			draw_rect(Rect2(p + Vector2(-5, -16), Vector2(10, 32)), col, false, 1.6)
		"ring":
			draw_arc(p, 15.0, 0.0, TAU, 32, col, 1.8, true)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				draw_line(p + d * 15.0, p + d * 21.0, Pal.heat(0.9 * a, 1.2), 2.0)
		"spare":
			# a spare airframe: the drone's own outline
			var pts := PackedVector2Array()
			for v in Skins.hull(Skins.current()):
				pts.append(p + (v as Vector2) * 0.8)
			pts.append(pts[0])
			draw_polyline(pts, col, 1.8, true)
			draw_circle(p + Vector2(-1.5, 0), 4.0, col)
		"intel":
			draw_rect(Rect2(p + Vector2(-13, -18), Vector2(26, 36)), col, false, 1.6)
			for k in 4:
				draw_line(p + Vector2(-8, -10 + k * 7), p + Vector2(8 - (k % 2) * 6, -10 + k * 7), Pal.tint(UiSkin.FIGURE, 0.9 * a, 1.1), 1.4)


func _sweep(r: Rect2, sw: float) -> void:
	var sx := r.position.x + r.size.x * Pal.ease_out(clampf(sw / 0.5, 0.0, 1.0))
	var fade := 1.0 - clampf((sw - 0.3) / 0.5, 0.0, 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, sx - r.position.x, r.size.y), Color(1, 1, 1, 0.05 * fade))
	draw_rect(Rect2(sx - 2, r.position.y, 2, r.size.y), Pal.heat(fade, 2.0))


# the late tunnel upgrade's card: lamp, name, a "late upgrade" tag, then installed (N toggles it),
# why it is locked, or its price
func _tunnel_box(i: int, a: float, id: String = "tunnel") -> void:
	var it := _tunnel_item(id)
	if it.is_empty():
		return
	var r := _item_rect(i)
	var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
	var sk: float = sel_k[i].x if i < sel_k.size() else 0.0
	var d := Career.data
	var have: bool = d.upgrades.has(it[0])
	var why := "" if have else _late_why(str(it[0]))
	var short: bool = not have and why == "" and float(d.money) < float(it[2])
	var k := Pal.ease_out(clampf((deal_t - (0.25 if id == "tunnel" else 0.31)) / 0.3, 0.0, 1.0)) * a
	r.position.x += (1.0 - k) * 30.0
	var p := _anchor(i)
	draw_line(Vector2(r.position.x, r.get_center().y), p, Pal.tint(UiSkin.FIGURE, (0.35 + 0.45 * maxf(hk, sk)) * k), 1.2, true)
	draw_circle(p, 4.0, Pal.heat(k, 1.3) if sk > 0.5 else Pal.tint(UiSkin.FIGURE, 0.9 * k, 1.3))
	Hmi.raised(self, r, k, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	Hmi.lamp(self, r.position + Vector2(22, r.size.y * 0.5), Hmi.ok_col() if have else (Hmi.warn_col() if why != "" or short else Hmi.can_col()), true, k)
	_text(Txt.t(it[3]), r.position + Vector2(42, 28), 17, Pal.ink(0.96 * k), font_s)
	_text(Ops.w("后期升级", "LATE"), Vector2(r.end.x - 10, r.position.y + 13), 10, Pal.heat(0.85 * k, 1.1), font_b, 1)
	if have:
		_text(Ops.w("已安装 · 按 %s 开关", "FITTED · %s ON/OFF") % _tunnel_key(id), r.position + Vector2(42, 54), 15, Pal.tint(Pal.FLUID, 0.95 * k, 1.1), font_s)
	elif why != "":
		_text(Pal.money(it[2]) + Ops.w(" · 未解锁", " · LOCKED"), r.position + Vector2(42, 54), 15, Pal.ink(0.5 * k), font_s)
	else:
		_text(Pal.money(it[2]), r.position + Vector2(42, 54), 16, Pal.ink((0.9 if not short else 0.55) * k), font_s)
		if short:
			_text(Txt.t("tm_short_n") % Pal.money(float(it[2]) - float(d.money)), Vector2(r.end.x - 12, r.position.y + 54), 13, Pal.heat(0.9 * k, 1.1), font_b, 1)


# the key that switches it: N for the grapple's, U for the drone's own (or its button on the key strip)
func _tunnel_key(id: String) -> String:
	return Keys.label(id)


# an airframe in the strip: the craft itself, its name, in use / owned / the price
func _skin_tile(i: int, a: float) -> void:
	var id: String = Skins.ORDER[i - DRONE_UPGRADES]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
	var sk: float = sel_k[i].x if i < sel_k.size() else 0.0
	var k := Pal.ease_out(clampf((deal_t - 0.14 - (i - DRONE_UPGRADES) * 0.04) / 0.3, 0.0, 1.0)) * a
	r.position.y += (1.0 - k) * -18.0
	var flown := Skins.current() == id
	var have := Skins.owns(id)
	var short := not have and float(Career.data.money) < Skins.price(id)
	Hmi.raised(self, r, k, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	Hmi.lamp(self, r.position + Vector2(12, 12), Hmi.ok_col() if have else (Hmi.warn_col() if short else Hmi.can_col()), true, k, 4.0)
	var c := r.position + Vector2(r.size.x * 0.5, 27.0)
	var s := 0.74 + 0.08 * maxf(hk, sk)
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	draw_set_transform_matrix(xf)
	DArt.set_scale(s)
	Skins.draw(self, id, {"heading": 0.0, "tool": 0, "open": 0.0, "t": t + i, "thrust": Vector2(0.6 * maxf(hk, sk), 0.0), "dash": false, "base_xf": xf})
	DArt.lite = false
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_text(Skins.name_of(id), Vector2(c.x, r.end.y - 22), 13, Pal.ink(0.95 * k), font_s, 0)
	var st := Ops.w("使用中", "IN USE") if flown else (Ops.w("已拥有", "OWNED") if have else Pal.money(Skins.price(id)))
	var sc := Pal.tint(UiSkin.FIGURE, 0.95 * k, 1.1) if flown else (Pal.ink(0.7 * k) if have else Pal.ink((0.9 if not short else 0.45) * k))
	_text(st, Vector2(c.x, r.end.y - 7), 12, sc, font_b, 0)
	if flown:
		draw_rect(r.grow(2.0), Pal.tint(UiSkin.FIGURE, 0.5 * k, 1.1), false, 1.2)


# the chosen airframe on the right: three moving previews (flight, braking, grabbing), what it is,
# and the money, or that it is owned / in use
func _skin_detail(id: String, ka: float) -> void:
	var r := _detail_rect()
	var d := Career.data
	Hmi.raised(self, r, ka)
	var x := r.position.x + 32
	var w := r.size.x - 64
	var pl := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 44)
	Hmi.plate(self, font_s, pl, Ops.w("机体外观", "AIRFRAME"), 18, ka, Pal.tint(UiSkin.FIGURE, 0.95, 1.2))
	var have := Skins.owns(id)
	var flown := Skins.current() == id
	var cost := Skins.price(id)
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.ok_col() if have else (Hmi.warn_col() if float(d.money) < cost else Hmi.can_col()), true, ka)
	_text(Skins.name_of(id), Vector2(x, r.position.y + 112), 34, Pal.ink(0.98 * ka), font_s)
	_wrap(Skins.blurb(id), Vector2(x, r.position.y + 146), w, 15, Pal.ink(0.75 * ka))
	var sc := Rect2(x - 10, r.position.y + 210, w + 20, 170)
	Hmi.screen(self, sc, ka)
	skin_preview(self, id, sc, t, ka, font)
	_text(Ops.w("外观不同，数值和手感完全相同", "LOOKS ONLY: SAME NUMBERS, SAME HANDLING"), Vector2(x, sc.end.y + 26), 14, Pal.ink(0.55 * ka), font)
	if flown:
		Hmi.lamp(self, Vector2(x + 10, r.end.y - 136), Hmi.ok_col(), true, ka, 9.0)
		_text(Ops.w("使用中", "IN USE"), Vector2(x + 30, r.end.y - 128), 22, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.1), font_s)
		return
	if have:
		Hmi.lamp(self, Vector2(x + 10, r.end.y - 136), Hmi.ok_col(), true, ka, 9.0)
		_text(Ops.w("已拥有 · 按 Enter 换上，出发前在配装页也能换", "OWNED · ENTER TO FLY IT, OR CHANGE IT ON THE LOADOUT PAGE"), Vector2(x + 30, r.end.y - 128), 16, Pal.ink(0.85 * ka), font_s)
		return
	var my := r.end.y - 236.0
	var after := float(d.money) - cost
	draw_line(Vector2(x, my - 22), Vector2(x + w, my - 22), Color(0, 0, 0, 0.5 * ka), 2.0)
	_text(Txt.t("tm_price"), Vector2(x, my), 15, Pal.ink(0.6 * ka), font)
	_text(Pal.money(cost), Vector2(x + w, my), 18, Pal.ink(0.95 * ka), font_b, 1)
	_text(Txt.t("tm_after"), Vector2(x, my + 30), 15, Pal.ink(0.6 * ka), font)
	_text(Pal.money(after), Vector2(x + w, my + 30), 18, (Pal.heat(0.95 * ka, 1.2) if after < 0.0 else Pal.ink(0.95 * ka)), font_b, 1)


# four moving previews in a rect: flying (thrust ahead), braking (reverse thrust), grabbing
# (claws out, the tether to a plate), cutting (the beam in the airframe's own colour); also used
# by the loadout page
static func skin_preview(ci: CanvasItem, id: String, rc: Rect2, tt: float, a: float, f: Font) -> void:
	var labels := [Ops.w("飞行", "FLYING"), Ops.w("刹车", "BRAKING"), Ops.w("抓取", "GRABBING"), Ops.w("切割", "CUTTING")]
	var n := 4
	var cw := rc.size.x / n
	var s := clampf(minf(cw / 100.0, rc.size.y / 62.0), 0.7, 2.4)
	for k in n:
		var c := Vector2(rc.position.x + cw * (k + 0.5) + [12.0, 0.0, -16.0, -22.0][k] * s, rc.position.y + rc.size.y * 0.46)
		var th: Vector2 = [Vector2(1, 0), Vector2(-1, 0), Vector2(-0.3, 0), Vector2.ZERO][k]
		var bob := Vector2(0, sin(tt * 1.3 + k) * 1.5 * s)
		if k >= 2:
			# a plate held ahead
			var b := c + Vector2((40.0 if k == 2 else 58.0) * s, 0) + bob
			var plate := PackedVector2Array()
			for v in [Vector2(-5, -9), Vector2(6, -7), Vector2(8, 7), Vector2(-4, 9), Vector2(-7, 1)]:
				plate.append(b + (v as Vector2) * s)
			ci.draw_colored_polygon(plate, Color(0.06, 0.064, 0.072, a))
			var pc := plate.duplicate()
			pc.append(plate[0])
			ci.draw_polyline(pc, Pal.ink(0.6 * a), 1.2, true)
			var m := c + Vector2(28.0 * s, 0) + bob
			if k == 2:
				# the tether's three strands
				for j in 3:
					var mid := (m + b) * 0.5 + Vector2(0, (j - 1) * 2.0 + sin(tt * (30.0 + j * 7.0)) * 1.2)
					ci.draw_polyline(PackedVector2Array([m, mid, b - Vector2(6.0 * s, 0)]), Pal.ink((0.75 - j * 0.15) * a, 1.4), 1.2, true)
			else:
				# the beam into the plate's face: halo, core, the hit glowing, a few sparks thrown back
				var hit := b - Vector2(6.0 * s, 0)
				m = c + Vector2(38.0 * s, 0) + bob
				var flick := 0.85 + 0.15 * sin(tt * 90.0)
				ci.draw_line(m, hit, Skins.lheat(0.5 * a, 1.5, id), 4.5 * flick, true)
				ci.draw_line(m, hit, Skins.lcore(Color(2.0, 1.7, 1.4, 0.9 * a), id), 1.4, true)
				Skins.FastDraw.circle(ci, hit, 4.0 * flick, Skins.lheat(0.55 * a, 2.2, id))
				Skins.FastDraw.circle(ci, hit, 1.6, Skins.lcore(Color(2.0, 1.8, 1.6, a), id))
				for j in 5:
					var u := fposmod(tt * 2.3 + j * 0.37, 1.0)
					var dir := Vector2.from_angle(PI + (j - 2) * 0.45 + sin(j * 7.1) * 0.2)
					var p0 := hit + dir * (3.0 + 16.0 * u) * s * 0.5
					ci.draw_line(p0, p0 + dir * 3.0 * s * 0.5, Skins.lheat((1.0 - u) * a, 3.0, id), 1.2, true)
		var xf := Transform2D(0.0, Vector2(s, s), 0.0, c + bob)
		ci.draw_set_transform_matrix(xf)
		DArt.set_scale(s)
		Skins.draw(ci, id, {"heading": 0.0, "tool": [0, 0, 3, 2][k], "open": 1.0, "t": tt + k * 0.7, "thrust": th, "dash": false, "base_xf": xf})
		DArt.lite = false
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		ci.draw_string(f, Vector2(rc.position.x + cw * k, rc.end.y - 10), labels[k], HORIZONTAL_ALIGNMENT_CENTER, cw, 13, Pal.ink(0.55 * a))


# buy an airframe (and fly it), or fly one already owned
func _buy_skin(id: String) -> void:
	if Skins.current() == id:
		_refuse(Ops.w("正在使用这一款", "ALREADY FLYING THIS ONE"))
		return
	if Skins.owns(id):
		Skins.equip(id)
		flash = 1.0
		_buy_fx(sel)
		say(Ops.w("已换上 %s", "NOW FLYING %s") % Skins.name_of(id))
		return
	var why := Skins.buy(id)
	if why != "":
		_refuse(why)
		return
	var desk: Dictionary = Career.data.get("desk", {})
	desk["buy"] = int(desk.get("buy", 0)) + 1
	Career.data.desk = desk
	if Career.usable():
		Career.save()
	flash = 1.0
	_buy_fx(sel)
	say(Txt.t("tm_bought") % Skins.name_of(id))


# the chosen thing: what it changes, now → after, how you would play differently,
# and the money: price, what is left after, and what the next contract fee would borrow
func _detail(a: float) -> void:
	var r := _detail_rect()
	var list := items()
	if sel < 0 or sel >= list.size():
		return
	var it: Array = list[sel]
	var id: String = it[0]
	var d := Career.data
	var ka := Pal.ease_out(clampf((deal_t - 0.12) / 0.35, 0.0, 1.0)) * a
	if it[1] == "skin":
		_skin_detail(id, ka)
		return
	Hmi.raised(self, r, ka)
	var x := r.position.x + 32
	var w := r.size.x - 64
	var kind := "tm_kind_it" if it[1] == "item" else ("tm_kind_fa" if it[1] == "facility" else "tm_kind_up")
	var pl := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 44)
	Hmi.plate(self, font_s, pl, Txt.t(kind), 18, ka, Pal.tint(UiSkin.FIGURE, 0.95, 1.2))
	var have0: bool = it[1] != "item" and Career.data.upgrades.has(id)
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.ok_col() if have0 else (Hmi.warn_col() if float(Career.data.money) < float(it[2]) else Hmi.can_col()), true, ka)
	var y := r.position.y + 62
	_text(Txt.t(it[3]), Vector2(x, y + 56), 36, Pal.ink(0.98 * ka), font_s)
	_wrap(Txt.t(it[4]), Vector2(x, y + 92), w, 16, Pal.ink(0.78 * ka))
	y += 140
	var have: bool = it[1] != "item" and d.upgrades.has(id)
	if it[1] != "item":
		var rows: Array = STATS.get(id, [])
		var grow := Pal.ease_out(clampf((deal_t - 0.3) / 0.6, 0.0, 1.0))
		for row in rows:
			var nv: String = Txt.t(row[1]) if str(row[1]).begins_with("sh_") else row[1]
			var av: String = Txt.t(row[2]) if str(row[2]).begins_with("sh_") else row[2]
			_text(Txt.t(row[0]), Vector2(x, y + 14), 16, Pal.ink(0.7 * ka), font_b)
			_text(nv + "  →  " + av, Vector2(x + w, y + 14), 17, Pal.ink(0.95 * ka), font_s, 1)
			var nowk: float = row[3]
			var aftk: float = row[4]
			if have:
				Hmi.gauge(self, Rect2(x, y + 24, w, 22), aftk, Pal.tint(UiSkin.FIGURE, 1.0, 1.1), ka)
			else:
				Hmi.gauge(self, Rect2(x, y + 24, w, 22), nowk, Pal.ink(0.75), ka, 10, lerpf(nowk, aftk, grow))
			y += 66
		y += 6
		var sc := Rect2(x - 10, y, w + 20, 96)
		Hmi.screen(self, sc, ka)
		if Txt.has("st_" + id):
			_text(Txt.t("tm_strategy"), sc.position + Vector2(14, 26), 14, Pal.ink(0.6 * ka), font)
			_wrap(Txt.t("st_" + id), sc.position + Vector2(14, 56), w - 8, 19, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.2))
		elif REQUIRES.has(id) and not d.upgrades.has(REQUIRES[id]):
			_text(Txt.t("tm_needs") % Txt.t(_facility_name(REQUIRES[id])), sc.position + Vector2(14, 56), 18, Pal.heat(0.95 * ka, 1.2), font_s)
		if tab == DRONE_PAGE and id == "tunnel_body" and not Txt.has("st_" + id):
			_text(Txt.t("tm_strategy"), sc.position + Vector2(14, 26), 14, Pal.ink(0.6 * ka), font)
			_wrap(Ops.w("先装量子隧穿，再装这个。装上后默认开启，按 %s 或右上角「机体」按钮开关。开着时，无人机自己能穿过墙壁、船体、设施和散件；还没泄压的舱室和港区边界仍然挡得住。", "Fit quantum tunnelling first. On once fitted; %s or the BODY button top right switches it. While on, the drone itself passes walls, hulls, facilities and loose pieces; rooms still under pressure and the berth's edge still stop it.") % _tunnel_key(id), sc.position + Vector2(14, 56), w - 8, 17, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.2))
		if tab == DRONE_PAGE and id == "tunnel" and not Txt.has("st_" + id):
			_text(Txt.t("tm_strategy"), sc.position + Vector2(14, 26), 14, Pal.ink(0.6 * ka), font)
			_wrap(Ops.w("装上后默认开启，按 %s 开关。开着时，抓钩抓着的件能直接穿过墙壁和船体拖出来，不用先开路。", "On once fitted; %s switches it. While on, a held piece is dragged straight through walls and hulls: no path to cut first.") % Keys.label("tunnel"), sc.position + Vector2(14, 56), w - 8, 17, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.2))
		if tab == DRONE_PAGE and LATE.has(id) and not d.upgrades.has(id):
			var lw := _late_why(id)
			Hmi.lamp(self, Vector2(x + 8, sc.end.y + 24), Hmi.warn_col() if lw != "" else Hmi.ok_col(), true, ka, 6.0)
			_text(lw if lw != "" else (Ops.w("条件已满足：%d 单、声望 %d、量子隧穿", "UNLOCKED: %d JOBS, REPUTATION %d, QUANTUM TUNNELLING") if id == "tunnel_body" else Ops.w("条件已满足：%d 单、声望 %d、5 吨牵引抓钩", "UNLOCKED: %d JOBS, REPUTATION %d, THE 5 t GRAPPLE")) % [int(LATE[id][0]), int(LATE[id][1])], Vector2(x + 22, sc.end.y + 30), 15, Pal.heat(0.95 * ka, 1.2) if lw != "" else Pal.tint(Pal.FLUID, 0.9 * ka, 1.1), font_b)
	else:
		var n := int(d.items.get(id, 0))
		_text(Txt.t("tm_stock_n") % n, Vector2(x, y + 4), 18, Pal.ink(0.9 * ka), font_b)
		var how: String = Txt.t("tm_use_auto") if id == "spare" else (Txt.t("tm_use_intel_at") if id == "intel" else Txt.t("tm_use") % USE_KEY[id])
		_text(how, Vector2(x, y + 34), 15, Pal.ink(0.65 * ka), font)
	# the money
	if have:
		Hmi.lamp(self, Vector2(x + 10, r.end.y - 136), Hmi.ok_col(), true, ka, 9.0)
		_text(Txt.t("tm_installed"), Vector2(x + 30, r.end.y - 128), 22, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.1), font_s)
		return
	var n2 := qty if it[1] == "item" else 1
	var price: float = float(it[2]) * n2
	var after := float(d.money) - price
	var my := r.end.y - (300.0 if it[1] == "item" else 236.0)
	if it[1] == "item":
		_text(Txt.t("tm_qty"), Vector2(x, r.end.y - 186), 14, Pal.ink(0.55 * ka), font)
		for sgn in [-1, 1]:
			var qr := _qty_rect(sgn)
			var hv: bool = hover_minus if sgn < 0 else hover_plus
			Hmi.raised(self, qr, ka, Hmi.PANEL_HI if hv else Hmi.PANEL)
			_text("−" if sgn < 0 else "+", qr.get_center() + Vector2(0, 9), 26, Pal.ink(0.95 * ka), font_s, 0)
		var qw := Rect2(_qty_rect(-1).end.x + 14, _qty_rect(-1).position.y, 74, 48)
		Hmi.screen(self, qw, ka)
		_text(str(qty), qw.get_center() + Vector2(0, 11), 30, Pal.tint(UiSkin.FIGURE, 0.95 * ka, 1.3), font_s, 0)
	# 炭黑 v2: the price and what is left after it in one black window, large, the cash after as a scale
	var pwin := Rect2(x - 10, my - 34, w + 20, 74)
	Charcoal.display(self, pwin, ka)
	var half := pwin.size.x * 0.5
	draw_line(Vector2(pwin.position.x + half, pwin.position.y + 12), Vector2(pwin.position.x + half, pwin.end.y - 12), Color(1, 1, 1, 0.07 * ka), 1.0)
	_text(Txt.t("tm_price"), pwin.position + Vector2(14, 22), 12, Pal.ink(0.5 * ka), font_b)
	_text(Pal.money(price), pwin.position + Vector2(12, 52), 28, Color(Charcoal.ACCENT, ka), font_l)
	_text(Txt.t("tm_after"), pwin.position + Vector2(half + 14, 22), 12, Pal.ink(0.5 * ka), font_b)
	_text(Pal.money(after), pwin.position + Vector2(half + 12, 52), 28, (Pal.heat(0.95 * ka, 1.2) if after < 0.0 else Pal.ink(0.95 * ka)), font_l)
	Charcoal.segments(self, Rect2(pwin.position.x + half + 14, pwin.end.y - 11, half - 28, 4), clampf(after / maxf(float(d.money), 1.0), 0.0, 1.0) * 12.0, 12, ka)
	if after >= 0.0:
		var fee := _cheapest_fee()
		if fee > 0.0:
			if after < fee:
				_wrap(Txt.t("tm_next_fee") % [Pal.money(fee), Pal.money(fee - after)], Vector2(x, my + 58), w, 14, Pal.heat(0.9 * ka, 1.1))
			else:
				_text(Txt.t("tm_next_ok") % Pal.money(fee), Vector2(x, my + 60), 14, Pal.ink(0.5 * ka), font)


func _cheapest_fee() -> float:
	var f := 0.0
	for o in offers():
		if f == 0.0 or float(o.fee) < f:
			f = float(o.fee)
	return f


# ---------------------------------------------------------------- berth management

func _berth(s: Vector2, a: float) -> void:
	var d := Career.data
	var fr := _finance_rect()
	var k0 := Pal.ease_out(clampf((deal_t - 0.04) / 0.35, 0.0, 1.0)) * a
	Hmi.raised(self, fr, k0, Hmi.PANEL.lerp(Hmi.PANEL_HI, sel_k[0].x * 0.6))
	if sel_k[0].x > 0.02:
		draw_rect(fr.grow(4.0), Pal.heat(sel_k[0].x * k0, 1.4), false, 4.0)
	var x := fr.position.x + 36
	var w := fr.size.x - 72
	Hmi.plate(self, font_s, Rect2(fr.position.x + 18, fr.position.y + 18, fr.size.x - 36, 46), Txt.t("tm_fin"), 21, k0)
	Hmi.lamp(self, Vector2(fr.end.x - 40, fr.position.y + 41), Hmi.warn_col() if float(d.loan) > 0.0 else Hmi.ok_col(), true, k0)
	var loan := float(d.loan)
	var amt := minf(repay_amt, _repay_max())
	var loan2 := loan - amt
	var rows := [
		[Txt.t("tm_fin_loan"), loan, loan2],
		[Txt.t("tm_fin_inst"), minf(Career.INSTALLMENT, loan), minf(Career.INSTALLMENT, loan2)],
		[Txt.t("tm_fin_int"), snappedf(loan * Career.rate(), 1.0), snappedf(loan2 * Career.rate(), 1.0)],
		[Txt.t("tm_fin_due"), minf(Career.INSTALLMENT, loan) + snappedf(loan * Career.rate(), 1.0), minf(Career.INSTALLMENT, loan2) + snappedf(loan2 * Career.rate(), 1.0)],
		[Txt.t("tm_fin_funds"), float(d.money), float(d.money) - amt],
		[Txt.t("tm_fin_credit"), Career.credit_left(), Career.credit_left() + amt],
	]
	# the slider: how much to pay now
	var sl := _slider_rect()
	_text(Txt.t("tm_fin_amt"), Vector2(x, sl.position.y - 26), 15, Pal.ink(0.6 * k0), font)
	_text(Pal.money(repay_amt), Vector2(sl.end.x, sl.position.y - 22), 26, Pal.ink(0.96 * k0), font_b, 1)
	var mx := _slider_max()
	var f := repay_amt / mx if mx > 0.0 else 0.0
	_text(Txt.t("tm_fin_rate") % (Career.rate() * 100.0), Vector2(x + w * 0.5, sl.position.y - 22), 14, Pal.ink(0.55 * k0), font, 0)
	Hmi.gauge(self, Rect2(sl.position.x, sl.position.y - 8, sl.size.x, 24), f, Pal.heat(1.0, 1.3), k0, 20)
	var kn := Vector2(sl.position.x + sl.size.x * f, sl.get_center().y)
	var kr := Rect2(kn - Vector2(12, 20), Vector2(24, 40))
	if dragging:
		Hmi.sunk(self, kr, k0, Hmi.PANEL_HI)
	else:
		Hmi.raised(self, kr, k0, Hmi.PANEL_HI)
	draw_line(kn + Vector2(0, -12), kn + Vector2(0, 12), Pal.heat(k0, 1.5), 2.0)
	_text("$0", Vector2(sl.position.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font)
	_text(Pal.money(mx), Vector2(sl.end.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font, 1)
	# now → after the payment
	var y := sl.end.y + 120
	Hmi.screen(self, Rect2(x - 16, y - 66, w + 32, rows.size() * 36 + 76), k0)
	_text(Txt.t("tm_fin_after"), Vector2(x + w, y - 40), 13, Pal.ink(0.55 * k0), font, 1)
	for i in rows.size():
		var yy := y + i * 36
		var rk := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.04) / 0.3, 0.0, 1.0)) * k0
		_text(rows[i][0], Vector2(x, yy), 16, Pal.ink(0.65 * rk), font)
		var changed: bool = absf(float(rows[i][1]) - float(rows[i][2])) > 0.5
		_text(Pal.money(rows[i][1]), Vector2(x + w - 230, yy), 17, Pal.ink((0.55 if changed else 0.9) * rk), font_b, 1)
		if changed:
			_text("→", Vector2(x + w - 200, yy), 16, Pal.ink(0.45 * rk), font)
			_text(Pal.money(rows[i][2]), Vector2(x + w, yy), 17, Pal.tint(UiSkin.FIGURE, 0.95 * rk, 1.3) if i != 4 else Pal.heat(0.95 * rk, 1.2), font_s, 1)
		draw_line(Vector2(x, yy + 12), Vector2(x + w, yy + 12), Pal.ink(0.06 * rk), 1.0)
	if loan <= 0.0:
		Hmi.lamp(self, Vector2(x + 8, fr.end.y - 136), Hmi.ok_col(), true, k0, 8.0)
		_text(Txt.t("tm_paid_off"), Vector2(x + 26, fr.end.y - 130), 18, Pal.tint(UiSkin.FIGURE, 0.95 * k0, 1.1), font_s)
	# the credit (G2): the same amount drawn onto the loan, with its own button
	var br := _borrow_rect()
	var can_b: bool = _borrow_amt() > 0.0 and not (overlay and not between)
	Hmi.push(self, font_s, br, Txt.t("tm_borrow_n") % Pal.money(_borrow_amt()), can_b, 1.0 if br.has_point(get_local_mouse_position()) else 0.0, k0, t, 0.0, Txt.t("tm_borrow_note") % Pal.money(Career.credit_limit()), "L")
	# the books: the contracts done, newest first
	var hr := _training_rect()
	hr.size.y = fr.size.y
	var k1 := Pal.ease_out(clampf((deal_t - 0.1) / 0.35, 0.0, 1.0)) * a
	Hmi.raised(self, hr, k1)
	Hmi.plate(self, font_s, Rect2(hr.position.x + 18, hr.position.y + 18, hr.size.x - 36, 46), Txt.t("tm_history"), 21, k1)
	var hist: Array = Career.data.get("history", [])
	var sc := Rect2(hr.position.x + 18, hr.position.y + 80, hr.size.x - 36, hr.size.y - 98)
	Hmi.screen(self, sc, k1)
	if hist.is_empty():
		_text(Txt.t("tm_history_none"), sc.position + Vector2(16, 40), 16, Pal.ink(0.55 * k1), font)
	var hy := sc.position.y + 40
	for n in mini(hist.size(), 14):
		var h: Dictionary = hist[hist.size() - 1 - n]
		var net := float(h.get("net", 0.0))
		_text(str(h.get("id", "?")), Vector2(sc.position.x + 16, hy), 16, Pal.ink(0.9 * k1), font_s)
		_text("%d%%" % int(round(float(h.get("rate", 0.0)) * 100.0)), Vector2(sc.position.x + sc.size.x * 0.55, hy), 15, Pal.ink(0.7 * k1), font_b, 1)
		_text(("+" if net >= 0.0 else "") + Pal.money(net), Vector2(sc.end.x - 16, hy), 17, Pal.tint(UiSkin.FIGURE, 0.95 * k1, 1.3) if net >= 0.0 else Pal.heat(0.95 * k1, 1.3), font_s, 1)
		hy += 32

# ---------------------------------------------------------------- the button, the keys, the messages

func _bottom(s: Vector2, a: float) -> void:
	_go_live = false
	if tab in [3, 5]:
		return
	var r := _go_rect()
	var label := ""
	var note := ""
	var ok := true
	var d := Career.data
	match tab:
		0:
			label = Txt.t("tm_take") + "   Enter"
			var o0: Dictionary = offers()[sel] if sel < offers().size() else {}
			if o0.get("find", false):
				label = Ops.w("派拖船去拖 · %s · 约 %d 秒", "SEND A TUG · %s · ~%d s") % [str(ShipMarket.tow_terms(o0).text), ShipMarket.quote_s(o0)] + "   Enter"
			elif o0.get("bought", false):
				label = Ops.w("开工拆", "START STRIPPING") + "   Enter"
			if not next_job.is_empty():
				Hmi.push(self, font_s, _go_rect(), Txt.t("tm_next_go"), true, 1.0 if hover_go else 0.0, a, t, 0.0, "", "ENTER")
				_go_live = true
				return
			var o: Dictionary = offers()[sel] if sel < offers().size() else {}
			if o.is_empty():
				return
			if o.get("queued", false):
				label = Txt.t("tm_hold") + "   Enter"
				note = Txt.t("tm_queued")
			if not o.has("intel") and int(d.items.get("intel", 0)) > 0:
				_text(Txt.t("tm_use_intel") % int(d.items.intel), Vector2(60, s.y - 84), 14, Pal.tint(UiSkin.FIGURE, 0.85 * a, 1.0), font)
			if float(d.money) < float(o.fee) and not o.get("find", false):
				note = Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(d.money))
			# a family of ship never trained for: the special course first (the contract waits)
			# 61 号: a ship with something not trained for is taken all the same; a plain note says so
			if not Codex.missing(str(o.ship)).is_empty():
				note = Ops.w("这艘船有%s，没练过。点“开工拆”会先带你去练这几门专项（必练），练完直接回来拆它。", "This ship has %s, not trained for: start stripping takes you through those courses first (required), then straight back to it.") % Codex.untrained_text(str(o.ship))
			if StoreBook.blocks_next_job() and not o.get("find", false) and not o.get("queued", false) and game_ref != null:
				label = Ops.w("先处理待入库", "HANDLE WAITING GOODS") + "   Enter"
				note = Ops.w("点这里打开仓库并选中待入库货物；可以出售，或腾出位置后入库。", "OPEN THE STORES AND SELECT THE WAITING GOODS; SELL THEM OR MAKE ROOM TO STORE THEM.")
			# user 2026-10-26: the button lit while the yard was full, the refusal flashed by — "I can't
			# tow it, what's going on?": greyed, with the reason and what to do next on it
			if o.get("find", false):
				var yb := TugYard.block(str(o.ship))
				var tt := ShipMarket.tow_terms(o)
				if yb != "" or not tt.ok:
					ok = false
					label = Ops.w("现在派不了拖船", "NO TUG CAN GO NOW")
					note = yb if yb != "" else str(tt.text)
					var way := ShipMarket.on_the_way()
					if TugYard.full() and not way.is_empty():
						note += Ops.w("。路上那艘约 %d 秒到港，到了在这里点“开工拆”。", ". The one on its way docks in ~%d s; then start stripping it here.") % int(float(way[0].left_s))
		1, 4, DRONE_PAGE:
			var list := items()
			var it: Array = list[sel] if sel < list.size() else []
			if it.is_empty():
				return
			var price: float = float(it[2]) * (qty if it[1] == "item" else 1)
			if it[1] == "skin":
				if Skins.current() == str(it[0]):
					label = "✓ " + Ops.w("使用中", "IN USE")
					ok = false
				elif Skins.owns(str(it[0])):
					label = Ops.w("换上", "FLY THIS ONE") + "   Enter"
				elif float(d.money) < price:
					label = Txt.t("tm_buy_n") % Pal.money(price)
					note = Txt.t("tm_short_n") % Pal.money(price - float(d.money))
					ok = false
				else:
					label = Txt.t("tm_buy_n") % Pal.money(price) + "   Enter"
			elif it[1] != "item" and d.upgrades.has(it[0]):
				label = "✓ " + Txt.t("tm_installed")
				if tab == DRONE_PAGE and str(it[0]) in ["tunnel", "tunnel_body"]:
					label = "✓ " + Ops.w("已安装 · 按 %s 开关", "FITTED · %s ON/OFF") % _tunnel_key(str(it[0]))
				ok = false
			elif tab == DRONE_PAGE and LATE.has(it[0]) and _late_why(str(it[0])) != "":
				label = Pal.money(price)
				note = _late_why(str(it[0]))
				ok = false
			elif REQUIRES.has(it[0]) and not d.upgrades.has(REQUIRES[it[0]]):
				label = Pal.money(price)
				note = Txt.t("tm_needs") % Txt.t(_facility_name(REQUIRES[it[0]]))
				ok = false
			elif float(d.money) < price:
				label = Txt.t("tm_buy_n") % Pal.money(price)
				note = Txt.t("tm_short_n") % Pal.money(price - float(d.money))
				ok = false
			else:
				label = Txt.t("tm_buy_n") % Pal.money(price) + "   Enter"
		2:
			var amt := minf(repay_amt, _repay_max())
			ok = amt > 0.0
			label = Txt.t("tm_repay_n") % Pal.money(amt) + ("   Enter" if ok else "")
			if not ok:
				note = Txt.t("tm_repay_none")
		7:
			var rows := _training_rows()
			var row: Array = rows[clampi(sel, 0, rows.size() - 1)]
			match row[0]:
				"base":
					label = Txt.t("tm_training_btn") + "   Enter"
				"sp":
					label = Txt.t("cxu_sp_go") + "   Enter"
					if not Codex.certified(row[1]):
						note = Txt.t("cxu_sp_bonus") % Pal.money(Codex.BONUS)
				"codex":
					label = Txt.t("cxu_open_book") + "   Enter"
				"trial":
					label = Txt.t("tm_take") + "   Enter"
					var spec: Dictionary = Career.TRIALS.get(str(row[1]), {})
					var lend: Dictionary = spec.get("lend", {})
					if not Career.active().is_empty():
						ok = false
						note = Txt.t("trial_busy")
					elif not lend.is_empty():
						var ls: Array = []
						for lt in lend:
							ls.append(Gear.name_of(str(lt)))
						note = Txt.t("trial_lend") % ", ".join(ls)
			if overlay and not between and row[0] != "codex":
				ok = false
				note = Txt.t("tm_onsite_no")
	if label != "":
		var shown := label.replace("   Enter", "")
		if shown != _push_label:
			# a new page brings its own button in; on the same page the label crossfades
			_push_old = _push_label if _page_in() >= 1.0 else ""
			_push_label = shown
			_push_t = 0.0
		var swap := 1.0 if Txt.anim_level() == 0 else Pal.ease_out(clampf(_push_t / 0.16, 0.0, 1.0))
		_go_live = ok
		Hmi.push(self, font_s, r, shown, ok, 1.0 if hover_go else 0.0, a * _page_in(), t, shake, note, "ENTER" if label.ends_with("Enter") else "", 1.0 if press_t > 0.0 and tab_press == -2 else 0.0, _push_old, swap)
	_text(Txt.t("tm_keys_berth") if between else (Txt.t("tm_keys_onsite") if overlay else Txt.t("tm_keys")), Vector2(60, s.y - 34), 13, Pal.ink(0.45 * a), font)
	if msg != "" and msg_t < 3.0:
		var mk := clampf((3.0 - msg_t) / 0.4, 0.0, 1.0) * Pal.ease_out(clampf(msg_t / 0.2, 0.0, 1.0))
		# user 2026-10-26: it sat on the button's own note — over the button now, on its own plate
		var mx := 60.0 + (1.0 - Pal.ease_out(clampf(msg_t / 0.25, 0.0, 1.0))) * 20.0
		var mw := font_b.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28.0
		var mr := Rect2(mx - 14.0, r.position.y - 50.0, minf(mw, s.x - 100.0), 36.0)
		draw_rect(mr, Color(0.07, 0.08, 0.09, 0.96 * mk * a))
		draw_rect(Rect2(mr.position, Vector2(3, mr.size.y)), Color(UiSkin.ACCENT, mk * a))
		_text(msg, Vector2(mx, mr.position.y + 24.0), 17, Pal.ink(0.95 * a * mk), font_b)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.05 * flash))


# lights leaving the funds for what was just bought
func _sparks() -> void:
	for sp in sparks:
		var e: float = clampf((sp[2] - sp[3]) / 0.55, 0.0, 1.0)
		if e <= 0.0:
			continue
		var p: Vector2 = (sp[0] as Vector2).lerp(sp[1], Pal.ease_io(e)) + Vector2(0, -sin(e * PI) * 60.0)
		draw_circle(p, 2.2 * (1.0 - e * 0.6), Pal.heat(1.0 - e * 0.5, 2.0))


# taking a contract: the chosen card grows to fill the screen, then a line closes it
func _leave(s: Vector2, lv: float) -> void:
	var g := Pal.ease_io(clampf(leaving / 0.4, 0.0, 1.0))
	var full := Rect2(Vector2.ZERO, s)
	var r := Rect2(leave_from.position.lerp(full.position, g), leave_from.size.lerp(full.size, g))
	Hmi.raised(self, r, 1.0, Hmi.PANEL_HI)
	draw_rect(r.grow(4.0 * (1.0 - g)), Pal.heat(1.0 - g, 1.4), false, 4.0)
	if not leave_offer.is_empty():
		var tw := r.size.x * 0.8
		_thumb(leave_offer, Rect2(r.get_center() - Vector2(tw * 0.5, tw * 0.11), Vector2(tw, tw * 0.22)), clampf(leaving / 0.15, 0.0, 1.0))
	var c := clampf((leaving - 0.52) / 0.24, 0.0, 1.0)
	if c > 0.0:
		var h := s.y * 0.5 * Pal.ease_in(c)
		draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y * 0.5 - 1, s.x, 2), Pal.heat(c, 2.0))


# the opening contract waiting in the berth: one card, what it is and that the market opens after
# the pinned story contract among the offers: the opening's next job, taken
# whenever the player likes (its story plays when it is)
func _story_card(o: Dictionary, r: Rect2, k: float, hk: float, sk: float) -> void:
	r.position.y += (1.0 - k) * 36.0 - hk * 6.0
	Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	var x := r.position.x + 28
	var y := r.position.y
	var ty: Dictionary = Market.type_of(str(o.get("ship", "gr7")))
	var d := Ship.load_data(str(o.get("ship", "gr7")))
	var pl := Rect2(r.position.x + 18, y + 18, r.size.x - 36, 46)
	Hmi.plate(self, font_s, pl, Txt.t("tm_next_h"), 21, k, Pal.heat(1.0, 1.3))
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col(), true, k, 7.0)
	var sc := Rect2(r.position.x + 18, y + 80, r.size.x - 36, 300)
	Hmi.screen(self, sc, k)
	var nm: String = ((ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else str(d.get("name", "")))
	_text(str(o.get("id", "")), sc.position + Vector2(16, 70), 50, Pal.ink(0.98 * k), font_l)
	_text(nm, sc.position + Vector2(16, 106), 19, Pal.ink(0.82 * k), font_s)
	_thumb(o, Rect2(sc.position.x + 16, sc.position.y + 140, sc.size.x - 32, 140), k)
	var rows := [
		[Txt.t("mf_length"), "%d m" % int(float(d.get("length", 0.0)))],
		[Txt.t("tm_value"), Pal.money(float(d.get("value", {}).get("total", 0.0)))],
		[Txt.t("tm_fee_story"), Pal.money(float(o.get("fee", 0.0)))],
		[Txt.t("tm_minutes_h"), Txt.t("tm_min_n") % int(float(o.get("time", 0.0)) / 60.0) if float(o.get("time", 0.0)) > 0.0 else Txt.t("tm_no_limit")],
	]
	# an opening hulk (26 号): where it came from
	if o.get("owner", "") == "salvage":
		rows.insert(0, [Txt.t("tm_origin"), Txt.t("tm_drift_open")])
	var pitch := 44.0 if rows.size() <= 4 else 36.0
	for i in rows.size():
		_text(rows[i][0], Vector2(x, y + 430 + i * pitch), 15, Pal.ink(0.6 * k), font)
		_text(rows[i][1], Vector2(r.end.x - 28, y + 430 + i * pitch), 16 if rows[i][0] == Txt.t("tm_origin") else 20, Pal.ink(0.95 * k), font_s, 1)
	_wrap(Txt.t("tm_next_d"), Vector2(x, y + 620), r.size.x - 56, 15, Pal.heat(0.9 * k, 1.1), 3)


# a trial contract (G1) as a card: what it is for, what the berth lends, how often it was done
func _trial_card(o: Dictionary, r: Rect2, k: float, hk: float, sk: float) -> void:
	r.position.y += (1.0 - k) * 36.0 - hk * 6.0
	Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	var x := r.position.x + 28
	var y := r.position.y
	var tid := str(o.get("trial", ""))
	var spec: Dictionary = Career.TRIALS.get(tid, {})
	var ty: Dictionary = Market.type_of(str(o.get("ship", "gr7")))
	var pl := Rect2(r.position.x + 18, y + 18, r.size.x - 36, 46)
	Hmi.plate(self, font_s, pl, Txt.t("tm_trial_h"), 21, k, Pal.tint(UiSkin.FIGURE, 1.0, 1.2))
	var done_n: int = int(Career.data.get("trials", {}).get(tid, 0))
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.ok_col() if done_n > 0 else Hmi.can_col(), true, k, 7.0)
	var sc := Rect2(r.position.x + 18, y + 80, r.size.x - 36, 300)
	Hmi.screen(self, sc, k)
	_text(Txt.t("trial_" + tid).split(" · ")[0], sc.position + Vector2(16, 44), 26, Pal.ink(0.98 * k), font_s)
	_text(Txt.t("trial_" + tid).split(" · ")[-1], sc.position + Vector2(16, 84), 30, Pal.ink(0.95 * k), font_l)
	_text("%s  ·  %s  ·  %d m" % [o.get("reg", ""), (ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else "", int(ty.get("length", 0))], sc.position + Vector2(16, 118), 15, Pal.ink(0.7 * k), font)
	_thumb(o, Rect2(sc.position.x + 16, sc.position.y + 150, sc.size.x - 32, 130), k)
	var lend: Dictionary = spec.get("lend", {})
	var ls: Array = []
	for lt in lend:
		ls.append(Gear.name_of(str(lt)) + " ×%d" % int(lend[lt]))
	var rows := [
		[Txt.t("rp_task_target"), Repair.name_of(str(spec.get("repair", "")))],
		[Txt.t("tm_value"), Pal.money(float(o.get("value", 0.0)))],
		[Txt.t("tm_fee"), Pal.money(float(o.get("fee", 0.0)))],
		[Txt.t("tm_minutes_h"), Txt.t("tm_min_n") % int(float(o.get("time", 0.0)) / 60.0)],
		[Txt.t("ld_lent"), ", ".join(ls) if not ls.is_empty() else Txt.t("e_gear_none")],
		[Txt.t("tm_trial_done"), str(done_n)],
	]
	for i in rows.size():
		_text(rows[i][0], Vector2(x, y + 420 + i * 40), 15, Pal.ink(0.6 * k), font)
		_text(rows[i][1], Vector2(r.end.x - 28, y + 420 + i * 40), 18, Pal.ink(0.95 * k), font_s, 1)
	_wrap(Txt.t("trial_" + tid + "_d"), Vector2(x, y + 640), r.size.x - 56, 15, Pal.tint(UiSkin.FIGURE, 0.9 * k, 1.1), 3)


func _next_card(s: Vector2, a: float) -> void:
	var r := _item_rect(0)
	var k := Pal.ease_out(clampf((deal_t - 0.06) / 0.35, 0.0, 1.0)) * a
	if leaving >= 0.0:
		return
	r.position.y += (1.0 - k) * 36.0
	Hmi.raised(self, r, k, Hmi.PANEL_HI)
	draw_rect(r.grow(4.0), Pal.heat(k, 1.4), false, 4.0)
	var x := r.position.x + 28
	var y := r.position.y + 50
	var ty: Dictionary = Market.type_of(str(next_job.get("ship", "gr7")))
	var d := Ship.load_data(str(next_job.get("ship", "gr7")))
	var pl := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 46)
	# 96 号: with the market open this is a contract taken whose start was left (its loadout page closed)
	var taken: bool = Career.data.get("market", false)
	Hmi.plate(self, font_s, pl, Ops.w("已接的合同 · 还没开工", "TAKEN · NOT STARTED") if taken else Txt.t("tm_next_first"), 21, k, Pal.heat(1.0, 1.3))
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col(), true, k, 7.0)
	y += 50
	var nm: String = ((ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else str(d.get("name", "")))
	_text(str(next_job.get("id", "")), Vector2(x, y + 44), 30, Pal.ink(0.96 * k), font_l)
	_text(nm, Vector2(x, y + 76), 17, Pal.ink(0.8 * k), font_b)
	var rows := [
		[Txt.t("mf_length"), "%d m" % int(float(d.get("length", 0.0)))],
		[Txt.t("tm_value"), Pal.money(float(d.get("value", {}).get("total", 0.0)))],
		[Txt.t("tm_fee"), Pal.money(float(next_job.get("fee", 0.0)))],
	]
	for i in rows.size():
		_text(rows[i][0], Vector2(x, y + 130 + i * 40), 14, Pal.ink(0.55 * k), font)
		_text(rows[i][1], Vector2(r.end.x - 28, y + 130 + i * 40), 18, Pal.ink(0.92 * k), font_b, 1)
	_wrap(Ops.w("这艘船你已经接下了，但装备页被关掉，所以还没开工：它停在拖船站的船坞口（太高的船停在外面泊位）。点“开始下一单”配好装备，就把它推进船坞开拆。", "You took this hulk but closed its loadout page, so it is not started: it lies in the tug station's mouth (a tall one in the yard outside). Start it, fit out, and it is pushed into the berth.") if taken else Txt.t("tm_next_first_d"), Vector2(x, y + 270), r.size.x - 56, 15, Pal.ink(0.7 * k), 4)
	# beside it: what the money is for, and what comes later
	var hx := _item_rect(1).position.x
	var hw := _item_rect(2).end.x - hx
	_wrap(Txt.t("tm_next_side"), Vector2(hx, r.position.y + 30), hw, 15, Pal.ink(0.55 * a), 2)
	# user 2026-11-04: "赚了钱能买的" and "以后能接的船" taken off this page ("画饼的…没意义")



# the loan paid off: the berth's name stamped across the terminal
func _milestone(s: Vector2) -> void:
	var e := milestone
	var a := clampf(e / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.82 * a))
	var k := Pal.back(clampf((e - 0.3) / 0.35, 0.0, 1.0), 2.4)
	if k > 0.02:
		_text("BERTH 07", Vector2(s.x * 0.5, s.y * 0.42), int(120 * k), Pal.ink(0.96), font_l, 0)
	var sa := clampf((e - 0.8) / 0.4, 0.0, 1.0)
	draw_rect(Rect2(s.x * 0.5 - 140 * sa, s.y * 0.42 + 30, 280 * sa, 3), Pal.heat(sa, 1.4))
	_text(Txt.t("tm_paid_off"), Vector2(s.x * 0.5, s.y * 0.42 + 76), 22, Pal.ink(0.8 * sa), font_b, 0)
	_text(Txt.t("tm_paid_off_d") % int(Career.data.get("paid_off_at", 0)), Vector2(s.x * 0.5, s.y * 0.42 + 110), 14, Pal.ink(0.45 * sa), font, 0)
	if e > 1.5:
		_text(Txt.t("tm_any_key"), Vector2(s.x * 0.5, s.y - 80), 14, Pal.ink(0.3 + 0.2 * sin(t * 3.0)), font, 0)
	if e < 0.5:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.25 * (1.0 - e / 0.5)))


func _radio(s: Vector2, a: float) -> void:
	var ln: Dictionary = radio.now
	if ln.is_empty():
		return
	var line: Dictionary = ln.line
	var full: String = radio.text(line)
	var shown := full.substr(0, int(ln.t * 30.0))
	var k := clampf(ln.t / 0.2, 0.0, 1.0) * clampf((ln.dur - ln.t) / 0.3, 0.0, 1.0) * a
	var r := Rect2(s.x * 0.5 - 410, s.y - 230, 820, 64)
	draw_rect(r, Color(0.02, 0.022, 0.026, 0.9 * k))
	var term: bool = line.get("who", "liang") == "term"
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.tint(UiSkin.FIGURE, k, 1.0) if term else Pal.heat(k, 1.0))
	_text(Txt.t("tut_term") if term else Txt.t("tut_liang"), r.position + Vector2(18, 22), 12, Pal.ink(0.5 * k), font)
	draw_multiline_string(font, r.position + Vector2(90, 30), shown, HORIZONTAL_ALIGNMENT_LEFT, 700, 18, 2, Pal.ink(0.95 * k))


# ---------------------------------------------------------------- the home screen and its new pages

func _home(s: Vector2, a: float) -> void:
	var d := Career.data
	var sj := Career.story_job()
	if _ops_decs.is_empty():
		_ops_decs = Ops.problems(game_ref)
	if not Onboarding.shown("market_ops"):
		_onboard_welcome(s, a)
	else:
		_next_step_card(a)
	var f := [font, font_b, font_s]
	var compact := s.y < 900.0
	# the port now: four cells
	for i in _ops_cells.size():
		var k := Pal.ease_out(clampf((deal_t - 0.02 - i * 0.05) / 0.3, 0.0, 1.0)) * a
		if k <= 0.0:
			continue
		var r := _cell_rect(i)
		r.position.y += (1.0 - k) * 24.0
		OpsSkin.draw_cell(self, f, r, _ops_cells[i], k, 1.0 if i == hover_cell else 0.0, compact)
	# 91 号 (user 2026-10-27: "船坞与当前船"): the berth and the ship in it, live
	if berth_view == null:
		berth_view = BerthView.new()
		berth_view.build(game_ref, next_job if not next_job.is_empty() else Career.active())
	var bv_raw := clampf((deal_t - 0.1) / 0.32, 0.0, 1.0)
	var bvk := Pal.ease_out(bv_raw) * a
	if bvk > 0.0:
		var bvr := _bv_rect()
		bvr.position.y += Charcoal.settle(bv_raw)
		# 炭黑: a raised panel, the drawing in a black window inside it
		bvr = Charcoal.panel(self, bvr, bvk)
		berth_view.bare = true
		Charcoal.display(self, berth_view.screen_rect(bvr), bvk)
		berth_view.draw(self, bvr, t, bvk, get_local_mouse_position(), font, font_b, font_s)
	# what waits on the operator
	var b := _decs_box()
	var bx_end: float = b.position.x + b.size.x * 0.34 if berth_view != null else b.end.x
	var hk0 := Pal.ease_out(clampf((deal_t - 0.2) / 0.3, 0.0, 1.0)) * a
	if hk0 > 0.0 and Onboarding.shown("market_ops") and not _ops_decs.is_empty():
		var title := Ops.w("出问题了", "SOMETHING IS WRONG")
		_text(title, b.position + Vector2(0, 22), 18, Pal.ink(0.9 * hk0), font_s)
		var tw := font_s.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_line(b.position + Vector2(tw + 16, 15), Vector2(bx_end, b.position.y + 15), Pal.ink(0.12 * hk0), 1.0)
		var counts := Ops.w("%d 项", "%d") % _ops_decs.size()
		_text(counts, Vector2(bx_end, b.position.y + 22), 14, Pal.ink(0.5 * hk0), font_b, 1)

	for i in _ops_decs.size():
		var k := Pal.ease_out(clampf((deal_t - 0.24 - i * 0.04) / 0.3, 0.0, 1.0)) * a
		if k <= 0.0:
			continue
		var r := _dec_rect(i)
		r.position.x += (1.0 - k) * 18.0
		OpsSkin.draw_decision(self, f, r, _ops_decs[i], k, 1.0 if i == hover_dec else 0.0, r.size.y < 54.0)
	# the home apps: one row of keys (炭黑: numbered keys that press in when chosen, the page's
	# live view in a black window on each, an orange lip sliding to the chosen one)
	var lip_k := 0.0
	var lip_y := 0.0
	var lip_w := 0.0
	for i in APPS.size():
		var page: int = APPS[i][0]
		var r := _tile_rect(i)
		var raw := clampf((deal_t - 0.26 - i * 0.05) / 0.3, 0.0, 1.0)
		var k := Pal.ease_out(raw) * a
		if k <= 0.0:
			continue
		r.position.y += Charcoal.settle(raw)
		if not Onboarding.page_shown(page):
			# not opened yet (28 号): an empty slot
			Charcoal.display(self, r.grow(-4), k * 0.6)
			continue
		var locked := _locked(page)
		var hk: float = hover_k[i].x if i < hover_k.size() else 0.0
		var press: float = clampf(sel_k[i].x, 0.0, 1.0) if i < sel_k.size() and not locked else 0.0
		r.position.y -= hk * 3.0 * (1.0 - press) if not locked else 0.0
		var ka := k * (0.62 if locked else 1.0)
		var fr := Charcoal.key(self, r, ka, press, Charcoal.FACE.lerp(Charcoal.FACE_HI, hk * 0.7))
		if i == sel:
			lip_k = ka * (0.5 if locked else 1.0)
			lip_y = fr.end.y - 9.0
			lip_w = fr.size.x - 48.0
		# 107 号 Q4 A: each key's screen shows its page live; a locked one keeps its icon
		var sc := Rect2(fr.end.x - 230.0, fr.position.y + 18.0, 206.0, maxf(40.0, fr.size.y - 36.0 - 40.0))
		Charcoal.display(self, sc, ka)
		if locked or not _tile_live(page, sc, k):
			_app_icon(page, sc.get_center(), (1.0 if not locked else 0.35) * k, clampf(sc.size.y / 150.0, 0.25, 0.55))
		var line := ""
		var lamp := 0      # 0 dark, 1 lit (all is well), 2 lit in the accent (wants you)
		match page:
			0:
				line = (Txt.t("tm_tile_first") % str(next_job.get("id", ""))) if not next_job.is_empty() else (Txt.t("tm_tile_offers") % offers().size() + ((Txt.t("tm_tile_pinned") % str(sj.get("id", ""))) if not sj.is_empty() else ""))
				lamp = 2 if not sj.is_empty() or not next_job.is_empty() else 1
			1:
				var fixed := 0
				for it in Repair.ITEMS:
					if d.upgrades.has(it[0]):
						fixed += 1
				line = Txt.t("rp_tile") % [Repair.ITEMS.size() - fixed, fixed, d.get("parts", []).size()]
				lamp = 2 if fixed < Repair.ITEMS.size() else 1
			3:
				var fparts: Array = []
				for tool in (Consum.TOOLS if Consum.ENABLED else []):
					var ft: Dictionary = Consum.fitted(tool)
					fparts.append("%s %s" % [Consum.name_of(tool), (Consum.tier_name(int(ft.tier)) + " %d%%" % int(round(100.0 * float(ft.left) / Consum.capacity(tool, int(ft.tier))))) if not ft.is_empty() else Txt.t("cs_out_short")])
				line = Txt.t("cs_tile") % [d.get("feats", {}).size(), Gear.FEATS.size()] + "  ·  " + "  ·  ".join(fparts)
				lamp = 1
			4:
				var parts: Array = []
				for it in _supply_items():
					parts.append("%s ×%d" % [Txt.t(it[3]), int(d.items.get(it[0], 0))])
				line = "  ·  ".join(parts)
			2:
				line = Txt.t("tm_tile_ledger") % [Pal.money(float(d.loan)), Pal.money(minf(Career.INSTALLMENT, float(d.loan)) + snappedf(float(d.loan) * Career.rate(), 1.0))]
				lamp = 2 if float(d.loan) > 0.0 else 1
			5:
				var gs := _goals()
				line = Txt.t("tm_tile_route") if gs.is_empty() else ("★ " if gs[0].get("pinned", false) else "") + str(gs[0].name).split(" · ")[0] + " · " + Route.missing(gs[0])
			6:
				line = Txt.t("tm_tile_radio") % _radio_lines().size()
				lamp = 1
			7:
				line = Txt.t("tm_tile_training")
			DRONE_PAGE:
				var fitted := SHOP.slice(0, DRONE_UPGRADES).filter(func(it): return d.upgrades.has(it[0])).size()
				line = Ops.w("工具升级已安装 %d/%d", "TOOL UPGRADES FITTED %d/%d") % [fitted, DRONE_UPGRADES]
		# the big number turns orange as the key goes down; the name beside the window
		var num_c := Pal.ink(0.98).lerp(Charcoal.ACCENT, press) if not locked else Pal.ink(0.4)
		_text(str(i + 1), fr.position + Vector2(22, 64), 56, Color(num_c, num_c.a * k), font_l)
		var name_w := sc.position.x - fr.position.x - 40.0
		var nm := Txt.t(APPS[i][1])
		# the largest size that fits beside the window (English names run long)
		var ns := 18
		for fs in [28, 24, 21]:
			if font_s.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= name_w:
				ns = fs
				break
		draw_string(font_s, fr.position + Vector2(24, 106), nm, HORIZONTAL_ALIGNMENT_LEFT, name_w, ns, Pal.ink((0.98 if not locked else 0.45) * k))
		# the English name engraved under it (Chinese only), and the page's lamp
		var cx := fr.position.x + 24.0
		if Txt.zh and Txt.S.has(APPS[i][1]):
			var en := str(Txt.S[APPS[i][1]][1]).to_upper()
			draw_string(font_b, Vector2(cx, fr.position.y + 130), en, HORIZONTAL_ALIGNMENT_LEFT, name_w, 11, Pal.ink(0.42 * k))
			cx += minf(name_w, font_b.get_string_size(en, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 14.0
		if not locked:
			Charcoal.led(self, Vector2(cx + 4, fr.position.y + 126), lamp > 0, k, 3.5, Charcoal.ACCENT if lamp == 2 else Color(0.82, 0.84, 0.82))
		# the chosen key's own lamp, lit as it goes down
		if press > 0.02:
			Charcoal.led(self, Vector2(sc.position.x - 18.0, fr.position.y + 30.0), true, press * k, 4.5)
		var foot := (Txt.t("tm_locked") + _lock_reason(page)) if locked else line
		draw_string(font_b, Vector2(fr.position.x + 24, fr.end.y - 18), foot, HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 48, 14, Pal.heat(0.9 * k, 1.2) if locked else Pal.ink(0.6 * k))
	# the orange lip slides along under the keys to the chosen one
	if lip_k > 0.0:
		Charcoal.lip(self, Rect2(lip_x.x + 24.0, lip_y + 2.0, lip_w, 4.0), lip_k)


# 107 号 Q4 A (user 2026-10-29: the home's three keys were big screens with a small icon in each):
# what each page holds, live — the find page a radar sweep with the signals swept so far and the
# tugs out; the berth its section with the floodlights and the facilities fixed and broken; the
# methods page the ones learned and the next one's silhouette. false: nothing to show, use the icon
func _tile_live(page: int, sc: Rect2, a: float) -> bool:
	var r := sc.grow(-8.0)
	if r.size.y < 40.0:
		return false
	var data_c := Color(0.86, 0.88, 0.88)
	match page:
		0:
			# the radar: rings, a sweeping beam, every signal swept (hulks in the accent), the tugs out
			var c := Vector2(r.position.x + r.size.y * 0.5 + 6.0, r.get_center().y)
			var rad := r.size.y * 0.5 - 2.0
			for k in 3:
				draw_arc(c, rad * (k + 1) / 3.0, 0.0, TAU, 40, Color(data_c, 0.18 * a), 1.0, true)
			draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), Color(data_c, 0.1 * a), 1.0)
			draw_line(c - Vector2(0, rad), c + Vector2(0, rad), Color(data_c, 0.1 * a), 1.0)
			var ang := fmod(t * 1.4, TAU)
			var fan := PackedVector2Array([c])
			for q in 9:
				fan.append(c + Vector2.from_angle(ang - 0.6 * q / 8.0) * rad)
			draw_colored_polygon(fan, Color(data_c, 0.1 * a))
			draw_line(c, c + Vector2.from_angle(ang) * rad, Color(data_c, 0.7 * a), 1.5, true)
			var sigs := 0
			var hulks := 0
			for i in Scan.order():
				for sg in Scan.signals(i):
					sigs += 1
					var h := hash(str(sg.id))
					var p := c + Vector2.from_angle(float(h % 628) / 100.0) * rad * (0.25 + 0.7 * float((h / 628) % 100) / 100.0)
					var ship: bool = sg.get("known", false) and str(sg.get("kind", "")) == "ship"
					hulks += 1 if ship else 0
					# a blip brightens as the beam passes it
					var since := fposmod(ang - (p - c).angle(), TAU)
					var glow := clampf(1.0 - since / 2.5, 0.25, 1.0)
					draw_circle(p, 3.0 if ship else 2.0, Color(UiSkin.ACCENT if ship else data_c, glow * a))
			var tx := c.x + rad + 18.0
			var way := ShipMarket.on_the_way().size()
			_text(Ops.w("信号 %d", "SIGNALS %d") % sigs, Vector2(tx, r.position.y + 22), 15, Pal.ink(0.85 * a), font_b)
			_text(Ops.w("是船 %d", "HULKS %d") % hulks, Vector2(tx, r.position.y + 42), 13, Color(UiSkin.ACCENT, 0.9 * a), font_b)
			if way > 0:
				_text(Ops.w("拖运途中 %d", "UNDER TOW %d") % way, Vector2(tx, r.position.y + 60), 13, Pal.ink(0.6 * a), font_b)
			return true
		1:
			# the berth in section: tower, boom, floodlights (lit when mended), the floor; a dot per facility
			var fy := r.end.y - 16.0
			var x0 := r.position.x + 18.0
			var x1 := r.end.x - 12.0
			var by := r.position.y + 8.0
			draw_line(Vector2(x0, by), Vector2(x0, fy), Pal.ink(0.6 * a), 2.0)
			draw_line(Vector2(x0, by), Vector2(x1, by), Pal.ink(0.55 * a), 1.5)
			draw_line(Vector2(x0, by + 5.0), Vector2(x1, by + 5.0), Pal.ink(0.35 * a), 1.0)
			var zx := x0
			var up := false
			while zx < x1 - 6.0:
				draw_line(Vector2(zx, by + (5.0 if up else 0.0)), Vector2(zx + 6.0, by + (0.0 if up else 5.0)), Pal.ink(0.2 * a), 1.0)
				up = not up
				zx += 6.0
			draw_line(Vector2(x0 - 6.0, fy), Vector2(x1, fy), Pal.ink(0.6 * a), 2.0)
			var lit := Repair.done("lights")
			for q in 2:
				var hx := lerpf(x0, x1, 0.32 + 0.36 * q)
				var on := lit or q == 0
				var kk := 1.0 if lit else (0.4 + 0.2 * sin(t * 23.0)) * (1.0 if q == 0 else 0.0)
				if on:
					draw_colored_polygon(PackedVector2Array([Vector2(hx - 3, by + 6), Vector2(hx + 3, by + 6), Vector2(hx + 22, fy), Vector2(hx - 22, fy)]), Pal.ink(0.08 * kk * a))
				draw_rect(Rect2(hx - 4, by + 5, 8, 3), Pal.ink((0.3 + 0.6 * kk) * a))
			# the ship in it, when there is one: its hull as a slab on the floor
			if berth_view != null and berth_view.mode == "live":
				var hull := Rect2(lerpf(x0, x1, 0.18), fy - (fy - by) * 0.38, (x1 - x0) * 0.62, (fy - by) * 0.38 - 2.0)
				draw_rect(hull, Pal.ink(0.12 * a))
				draw_rect(hull, Pal.ink(0.5 * a), false, 1.0)
				draw_rect(Rect2(hull.position, Vector2(hull.size.x * clampf(berth_view.rate, 0.0, 1.0), hull.size.y)), Color(UiSkin.ACCENT, 0.18 * a))
			var n := 0
			var fixed := 0
			for it in Repair.ITEMS:
				if not str(it[0]).begins_with("berth") and not str(it[0]) in ["gas_line", "lox_tank"]:
					n += 1
			var dx := minf(12.0, (x1 - x0 - 10.0) / maxf(1.0, n))
			var k2 := 0
			for it in Repair.ITEMS:
				var id := str(it[0])
				if id.begins_with("berth") or id in ["gas_line", "lox_tank"]:
					continue
				var ok := Repair.done(id)
				fixed += 1 if ok else 0
				var dp := Vector2(x0 + 8.0 + k2 * dx, fy + 9.0)
				draw_circle(dp, 2.5, Pal.ink(0.8 * a) if ok else Color(UiSkin.ACCENT, (0.55 + 0.35 * sin(t * 3.0 + k2)) * a))
				k2 += 1
			_text("%d / %d" % [fixed, n], Vector2(x1, fy + 13.0), 12, Pal.ink(0.55 * a), font_b, 1)
			return true
		5:
			# the methods: a cell each — learned bright, the next one a dashed outline, the rest dim
			var ids: Array = Methods.ORDER
			var nxt := Methods.next_id()
			var cw := minf(r.size.y - 6.0, (r.size.x - 8.0 * (ids.size() - 1)) / ids.size())
			var x := r.get_center().x - (cw * ids.size() + 8.0 * (ids.size() - 1)) * 0.5
			var y := r.get_center().y - cw * 0.5
			for i in ids.size():
				var id: String = ids[i]
				var cr := Rect2(x + i * (cw + 8.0), y, cw, cw)
				if Methods.learned(id):
					draw_rect(cr, Color(UiSkin.ACCENT, 0.22 * a))
					draw_rect(cr, Color(UiSkin.ACCENT, 0.9 * a), false, 1.5)
					for lv in Methods.level(id):
						draw_rect(Rect2(cr.position.x + 3.0 + lv * 6.0, cr.end.y - 6.0, 4.0, 3.0), Color(UiSkin.ACCENT, a))
				elif id == nxt:
					var dash := 4.0
					var e := 0.0
					var per := cr.size.x * 4.0
					while e < per:
						var p0 := _perim(cr, e)
						var p1 := _perim(cr, minf(e + dash, per))
						draw_line(p0, p1, Pal.ink((0.5 + 0.3 * sin(t * 3.0)) * a), 1.2)
						e += dash * 2.0
					_text("?", cr.get_center() + Vector2(0, 6), 16, Pal.ink(0.6 * a), font_s, 0)
				else:
					draw_rect(cr, Pal.ink(0.12 * a), false, 1.0)
			return true
	return false


# a point along a square's edge, clockwise from its top left
func _perim(r: Rect2, e: float) -> Vector2:
	var side := r.size.x
	if e < side:
		return r.position + Vector2(e, 0)
	if e < side * 2.0:
		return Vector2(r.end.x, r.position.y + e - side)
	if e < side * 3.0:
		return Vector2(r.end.x - (e - side * 2.0), r.end.y)
	return Vector2(r.position.x, r.end.y - (e - side * 3.0))


func _app_icon(page: int, c: Vector2, a: float, scale_k: float = 1.0) -> void:
	var col := Color(0.86, 0.88, 0.88, 0.95 * a)    # 炭黑: the black windows glow white, not blue
	# drawn smaller (the home screen's keys): the icon about its own centre
	if scale_k != 1.0:
		draw_set_transform(c + _page_off, 0.0, Vector2(scale_k, scale_k))
		c = Vector2.ZERO
	match page:
		0:
			for k in 3:
				draw_rect(Rect2(c + Vector2(-70 + k * 50, -36 + k * 6), Vector2(44, 64)), col, false, 2.0)
		1:
			# 86 号: the berth in a few lines — the tower, the boom, the floor, a fault marked
			draw_line(c + Vector2(-70, -46), c + Vector2(-70, 40), col, 3.0)
			draw_line(c + Vector2(-70, -30), c + Vector2(72, -30), col, 2.0)
			draw_line(c + Vector2(-70, -22), c + Vector2(72, -22), col, 2.0)
			draw_line(c + Vector2(72, -30), c + Vector2(72, 40), col, 2.0)
			draw_line(c + Vector2(-70, 40), c + Vector2(72, 40), col, 3.0)
			draw_rect(Rect2(c + Vector2(-8, 32), Vector2(30, 8)), col, false, 2.0)
			draw_arc(c + Vector2(30, 6), 11.0, 0.0, TAU, 20, Pal.heat(a, 1.3), 2.4, true)
		3:
			draw_rect(Rect2(c + Vector2(-40, -40), Vector2(80, 80)), col, false, 2.0)
			for k in 4:
				draw_line(c + Vector2(-26, -22 + k * 14), c + Vector2(26, -22 + k * 14), col, 1.6)
		4:
			draw_arc(c, 30.0, 0.0, TAU, 28, Pal.heat(a, 1.4), 3.0, true)
			draw_rect(Rect2(c + Vector2(-6, -20), Vector2(12, 40)), col)
			draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 12)), col)
		2:
			for k in 5:
				draw_rect(Rect2(c + Vector2(-60 + k * 26, 30 - k * 12), Vector2(18, 10 + k * 12)), col)
		5:
			var pts := PackedVector2Array([c + Vector2(-80, 20), c + Vector2(-30, -10), c + Vector2(20, 14), c + Vector2(80, -24)])
			draw_polyline(pts, col, 2.0, true)
			for q in pts:
				draw_circle(q, 6.0, col)
		6:
			for k in 3:
				draw_arc(c + Vector2(-30, 0), 16.0 + k * 16, -0.8, 0.8, 12, col, 2.0, true)
			draw_circle(c + Vector2(-30, 0), 6.0, col)
		7:
			draw_rect(Rect2(c + Vector2(-60, -30), Vector2(120, 60)), col, false, 2.0)
			draw_circle(c, 10.0, col)
		DRONE_PAGE:
			draw_polyline(PackedVector2Array([c + Vector2(-65, 0), c + Vector2(-28, -34), c + Vector2(48, -34), c + Vector2(65, 0), c + Vector2(48, 34), c + Vector2(-28, 34), c + Vector2(-65, 0)]), col, 3.0, true)
			draw_arc(c, 15.0, 0.0, TAU, 24, col, 2.0, true)
	draw_set_transform(_page_off)


# the consumables page: the four tiles, and the chosen one's detail with how many to buy
func _supplies(_s: Vector2, a: float) -> void:
	for i in _supply_items().size():
		_cell(i, a)
	_detail(a)


# what there is to work for, on its own page
# what was said over the radio: here, and on site what was said on the job
func _radio_lines() -> Array:
	var out: Array = radio.history.duplicate()
	if game_ref != null and game_ref.radio != null:
		out = game_ref.radio.history.duplicate() + out
	return out


func _radio_page(s: Vector2, a: float) -> void:
	var r := Rect2(40, 200, s.x - 80, s.y - 336)
	var k := Pal.ease_out(clampf(deal_t / 0.35, 0.0, 1.0)) * a
	Hmi.raised(self, r, k)
	Hmi.plate(self, font_s, Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 46), Txt.t("app_radio"), 21, k)
	var sc := Rect2(r.position.x + 18, r.position.y + 80, r.size.x - 36, r.size.y - 98)
	Hmi.screen(self, sc, k)
	var lines := _radio_lines()
	if lines.is_empty():
		_text(Txt.t("tm_radio_none"), sc.position + Vector2(20, 44), 17, Pal.ink(0.55 * k), font)
	var y := sc.position.y + 44
	for n in mini(lines.size(), 16):
		var ln: Array = lines[lines.size() - 1 - n]
		var who: String = str(ln[1])
		_text(Txt.t("who_" + who) if Txt.has("who_" + who) else who, Vector2(sc.position.x + 20, y), 15, Pal.tint(UiSkin.FIGURE, 0.9 * k, 1.2), font_s)
		draw_string(font, Vector2(sc.position.x + 180, y), str(ln[0]), HORIZONTAL_ALIGNMENT_LEFT, sc.size.x - 200, 16, Pal.ink(0.9 * k))
		y += 34


# training on its own page: what it is, and the button to go
func _training_page(s: Vector2, a: float) -> void:
	var r := _training_page_rect()
	var k := Pal.ease_out(clampf(deal_t / 0.35, 0.0, 1.0)) * a
	Hmi.raised(self, r, k)
	Hmi.plate(self, font_s, Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 46), Txt.t("tm_training"), 21, k)
	var rows := _training_rows()
	for i in rows.size():
		var row: Array = rows[i]
		var rr := _item_rect(i)
		var on := i == sel
		var hk := 1.0 if i == hover else 0.0
		draw_rect(rr, Color(0.07, 0.074, 0.084, 1.0) if on else (Color(0.05, 0.053, 0.06, 1.0) if hk > 0.0 else Color(0.03, 0.032, 0.037, 0.9)))
		if on:
			draw_rect(Rect2(rr.position, Vector2(4, rr.size.y)), Pal.heat(k, 1.1))
		var name := ""
		var info := ""
		var lamp := Hmi.ok_col()
		match row[0]:
			"base":
				name = Txt.t("cxu_row_base")
				info = Txt.t("cxu_row_base_d")
				lamp = Hmi.ok_col() if Career.data.get("certified", false) else Hmi.warn_col()
			"sp":
				name = Txt.t("cxu_cls_" + str(row[1]))
				var codes: Array = []
				for sid in Codex.CLASS_SHIPS[row[1]].slice(0, 6):
					codes.append(Codex.code(sid))
				info = ", ".join(codes)
				var kind: String = str(Codex._certs().get(row[1], ""))
				lamp = Hmi.ok_col() if kind != "" else Hmi.warn_col()
				_text(Txt.t("cxu_cert_" + (kind if kind != "" else "none")), Vector2(rr.end.x - 20, rr.get_center().y + 6), 15, Pal.tint(UiSkin.FIGURE, 0.9 * k, 1.0) if kind != "" else Pal.ink(0.5 * k), font_b, 1)
			"codex":
				name = Txt.t("cxu_book")
				var have := 0
				for c in Codex.CATS:
					have += Codex.count(c).x
				info = Txt.t("cxu_row_codex_d") % [have, CodexData.E.size()]
			"trial":
				var tid := str(row[1])
				name = Txt.t("trial_" + tid)
				var spec: Dictionary = Career.TRIALS.get(tid, {})
				var ty: Dictionary = Market.type_of(str(spec.get("ship", "gr7")))
				var parts: Array = [(ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else str(spec.get("ship", ""))]
				var lend: Dictionary = spec.get("lend", {})
				if not lend.is_empty():
					var ls: Array = []
					for lt in lend:
						ls.append(Gear.name_of(str(lt)) + " ×%d" % int(lend[lt]))
					parts.append(Txt.t("trial_lend") % ", ".join(ls))
				var done_n: int = int(Career.data.get("trials", {}).get(tid, 0))
				parts.append(Txt.t("trial_done") % done_n)
				info = "  ·  ".join(parts)
				lamp = Hmi.ok_col() if done_n > 0 else Hmi.can_col()
				_text(Txt.t("trial_" + tid + "_d"), Vector2(rr.end.x - 20, rr.get_center().y + 5), 12, Pal.ink(0.45 * k), font, 1)
		Hmi.lamp(self, Vector2(rr.position.x + 24, rr.get_center().y), lamp, true, k, 6.0)
		var tight: bool = rr.size.y < 46.0
		_text(name, Vector2(rr.position.x + 46, rr.position.y + (17 if tight else 22)), 16 if tight else 18, Pal.ink(0.95 * k), font_s)
		_text(info, Vector2(rr.position.x + 46, rr.position.y + (31 if tight else 42)), 12 if tight else 13, Pal.ink(0.55 * k), font)
