class_name OpCards
# First-use cards (68 号 §4): the first time a key is used in a career, a small card on the
# right says what it is for — the key and one line — for 6 s, once (Career.data.op_cards).
# The same lines make the pause menu's "操作说明" page, grouped and showing the keys as bound.

const SHOW_S := 6.0
const GROUPS := [
	["飞行", "FLYING", ["up", "dash", "brake", "assist", "hold", "overview", "warp"]],
	["工具", "TOOLS", ["tool1", "tool2", "tool3", "tool4", "tool5", "tool6", "repair", "ring"]],
	["船坞", "THE BERTH", ["blueprint", "contract", "use", "mouth", "mark", "zone", "auto", "port"]],
	["终端与信息", "TERMINAL AND INFORMATION", ["terminal", "starmap", "codex", "log", "hints"]],
]
const LINES := {
	"up": ["WASD 移动无人机。太空里没有摩擦，松开方向键也会一直漂。", "WASD moves the drone. Nothing slows you in space: it drifts on when you let go."],
	"dash": ["按住冲刺，推力更大，也更费电。", "Hold to dash: more thrust, more power."],
	"brake": ["反推刹停：按住直到停下。", "Fire against the drift until you stop."],
	"assist": ["飞行稳定：开着时松开方向键会自动减速。", "Flight assist: when on, letting go slows you down by itself."],
	"hold": ["按住锁定在原地，切割、对接时手不抖。", "Hold to stay put while cutting or docking."],
	"overview": ["按住拉远，看整艘船。", "Hold to pull back and see the whole ship."],
	"warp": ["按住让时间走快，等抽气、等施工时用。", "Hold to speed time up while pumping or waiting for the crew."],
	"tool1": ["测量仪：左键点零件或测试点，读质量、材质、电压和压力。动手前先读数。", "Meter: click a piece or a test point for its mass, material, voltage and pressure. Read before you touch."],
	"tool2": ["激光切割：按住左键沿着要切的地方划过去；固定件切开，零件就松了。", "Laser: hold the button and sweep along the cut; cut the fixings and the piece comes loose."],
	"tool3": ["磁力抓钩：左键抓住松开的零件拖着走，松开放下，甩一下能扔出去。", "Grapple: grab a loose piece and tow it; let go to drop it, flick to throw it."],
	"tool4": ["维护工具：拧螺栓、开关阀门和电闸、开舱门；指着它们时自动换上。", "Wrench: bolts, valves, switches and hatches. It comes to hand by itself when you point at one."],
	"tool5": ["气液回收：左键把软管接到气口或液口，把气体和液体抽回来，也能卖钱。", "Hose: put it on a gas or fluid port and pump it back; that sells too."],
	"tool6": ["部署：把带来的设备（支架、吊臂等）放到船上用。", "Deploy: set the gear you brought (stands, arms) on the ship."],
	"repair": ["维修包：补无人机的损伤。", "Repair kit: mend the drone's damage."],
	"ring": ["爆破切割环：贴在厚件上一次切开，要先清空周围。", "Breaching ring: fixed on a thick piece, it cuts through at once; clear the area first."],
	"blueprint": ["图纸：看整船的结构、设备和管线在哪。", "Drawing: the ship's structure, machines and lines."],
	"contract": ["合同：这一单要拆什么、回收率目标和时间。", "Contract: what this job wants, the recovery targets and the time."],
	"use": ["互动：用船坞电脑、上车、操作身边的面板。", "Use: berth computers, vehicles, the panel next to you."],
	"mouth": ["把回收口移到无人机下方，近一点好送件。", "Moves the mouth under the drone, so pieces have less way to go."],
	"mark": ["右键标记零件，让搬运无人机去搬。", "Right-click marks a piece for the hauler drone."],
	"zone": ["划一块禁入区，船坞机器不进去。", "Draws a keep-out zone the berth's machines stay out of."],
	"auto": ["停下 / 恢复船坞机器。", "Stops / resumes the berth's machines."],
	"port": ["在船坞里切换零压港全景。", "At the berth, toggles the whole port's view."],
	"terminal": ["终端：找船、修港区、交易、看下一步。", "Terminal: find ships, mend the port, trade, see the next step."],
	"starmap": ["星图：扫描小行星带找船，看拖船和货船在哪。", "Star map: sweep the belt for hulks, see the tugs and freighters."],
	"tow": ["在作业艇上：靠近漂浮舱段的拖眼挂上拖缆，拖到船坞外的交付区再摘缆。", "Aboard the work boat: hitch the line to a drifting section's tow eye, tow it to the delivery box off the berth, cast off."],
	"multi": ["抓钩在单体和范围模式间切换：范围模式一次抓起圈内多件散料。Shift+X 开关防护。", "Switches the grapple between one piece and its field: the field catches several loose pieces at once. Shift+X toggles its guard."],
	"tunnel": ["量子隧穿开关：开着时，抓钩抓着的件穿过墙壁、船体和设施；关掉或放手时卡在墙里，会等它完全出来再恢复碰撞。", "Quantum tunnelling: on, what the grapple holds passes through walls, hull and facilities; switched off or let go inside a wall, it touches again only once it is clear."],
	"codex": ["图鉴：见过的设备、危险和做法。", "Codex: the machines, hazards and methods you have met."],
	"log": ["无线电记录：之前说过的话。", "Radio log: what was said."],
	"hints": ["开关屏幕提示。", "Turns the on-screen hints on or off."],
}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func line(action: String) -> String:
	var l: Array = LINES.get(action, [])
	return "" if l.is_empty() else (str(l[0]) if Txt.zh else str(l[1]))


static func key_text(action: String) -> String:
	if action == "up":
		return "WASD"
	if action == "mark":
		return w("右键", "RMB")
	var l := Keys.label(action)
	return "=" if l == "Equal" else l


# the first use in this career: true once, and remembered
static func first(action: String) -> bool:
	if action in ["down", "left", "right"]:
		action = "up"
	if not LINES.has(action) or not Career.usable() or Career.data.is_empty():
		return false
	var seen: Dictionary = Career.data.get("op_cards", {})
	if seen.has(action):
		return false
	seen[action] = true
	Career.data.op_cards = seen
	return true


# the pause menu's page: every group, every key as bound now
static func page() -> String:
	var out: Array = []
	for g in GROUPS:
		out.append("【%s】" % (str(g[0]) if Txt.zh else str(g[1])))
		for a in g[2]:
			out.append("  %s  ·  %s" % [key_text(a), line(a)])
		out.append("")
	return "\n".join(out)
