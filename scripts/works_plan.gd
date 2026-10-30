class_name WorksPlan
# A berth repair built step by step (design/…/82_施工工序, user 2026-10-26: "做通用施工工序系统，新手
# 会碰到的照明/碎屑网/熔炉三项并进新手引导先做，其余放 P2"). A repair with a plan is a fixed run of
# the seven steps a real job takes — isolate, take the broken part off, bring the new one, lift it
# in, fasten, connect, test — each with the machine that does it and how long it takes; the job's
# time is the steps added up, not its price. Drawn by works_site.gd; the broken look (dock.gd)
# goes once the old part is off. Repairs without a plan keep the old time and the plain crew (P2).

const STEPS := ["isolate", "remove", "bring", "lift", "fasten", "connect", "test"]
const NAMES := {
	"isolate": ["隔离", "ISOLATE"], "remove": ["拆坏件", "TAKE THE OLD OFF"], "bring": ["运来新件", "BRING THE NEW"],
	"lift": ["吊装定位", "LIFT IN"], "fasten": ["紧固", "FASTEN"], "connect": ["接线 / 接管", "CONNECT"], "test": ["试运行", "TEST RUN"],
}
# id -> [[step, s, what is done (zh, en)], ...]; parts: the new part's art and size (m)
const PLANS := {
	"lights": {"part": ["lamp", Vector2(1.4, 0.8)], "extra": ["battery", Vector2(1.0, 0.7)], "steps": [
		["isolate", 6.0, "断开照明配电回路，挂上检修牌", "The lighting circuit off and tagged"],
		["remove", 8.0, "切下裂开的灯头和垂下的电缆", "The cracked lamp head and the hanging cable cut away"],
		["bring", 10.0, "施工艇吊来新灯头和电池组", "The work boat brings a new lamp head and a battery pack"],
		["lift", 8.0, "灯头对上吊臂上的灯座", "The lamp head lowered onto its seat on the boom"],
		["fasten", 6.0, "四颗螺栓拧紧", "Four bolts torqued"],
		["connect", 6.0, "电缆接进配电箱", "The cable run into the distribution box"],
		["test", 6.0, "灯头点亮，读数正常", "The lamp lights; the readings are steady"]]},
	"net_fix": {"part": ["reel", Vector2(1.6, 1.0)], "extra": ["crate", Vector2(1.0, 0.7)], "steps": [
		["isolate", 5.0, "松开张紧器，网面放松", "The tensioners slacked off"],
		["remove", 8.0, "切掉撕破的网片", "The torn mesh cut out"],
		["bring", 10.0, "施工艇吊来一卷新网", "The work boat brings a roll of new mesh"],
		["lift", 8.0, "展开新网片，挂上网框", "The new mesh unrolled onto the frame"],
		["fasten", 6.0, "边缘一圈卡扣扣上", "The edge clips closed all round"],
		["test", 6.0, "张紧器拉紧，落一块试重", "Tensioned; a test weight dropped in"]]},
	"furnace_main": {"part": ["nozzle", Vector2(1.2, 1.0)], "extra": ["hx", Vector2(1.2, 0.8)], "steps": [
		["isolate", 6.0, "关燃料阀，炉膛放空", "The fuel valve shut, the hearth vented"],
		["remove", 8.0, "拆下烧裂的主燃烧器", "The cracked main burner taken out"],
		["bring", 10.0, "施工艇吊来新燃烧器和热工件", "The work boat brings a new burner and its heat parts"],
		["lift", 8.0, "燃烧器对准炉口装进去", "The burner set into the furnace throat"],
		["fasten", 6.0, "法兰螺栓拧紧", "The flange bolts torqued"],
		["connect", 6.0, "接上燃料管和氧气管", "The fuel and oxygen lines on"],
		["test", 8.0, "点主火，炉口由暗变橙", "The main fire lit; the throat goes from dark to orange"]]},
}


# 87-5: every other facility is built by its trade too, not by three robots and a timer. A family
# per kind of facility: its machines (the bot tags out, the cutter takes the old off, the work boat
# or the barge brings, the crawler crane lifts, the welding robots weld, the hydraulic wrench
# torques, the cable layer pulls cable, the laser aligns, the test rig proves it), its steps (a
# share of the job's time each: the job still takes what its price says, Works.duration), the parts
# it puts up (drawn as the real equipment) and how many go up one by one (plates, jib sections,
# track lengths). Each step: [key, share, zh, en, machine, MW its machines draw].
const MACHINE_MW := {"bot": 0.05, "cutter": 0.3, "boat": 0.2, "crane": 0.6, "welder": 0.4, "torque": 0.1, "cable": 0.2, "survey": 0.02, "tester": 0.3, "purge": 0.08}
const FAMILY := {
	"structure": {"part": ["crate", Vector2(2.4, 0.6)], "extra": ["container", Vector2(2.0, 1.0)], "units": 5, "steps": [
		["isolate", 1.0, "拉起警戒线，船坞这一段停用", "The bay cordoned off and taken out of use", "bot"],
		["remove", 2.0, "切掉锈穿的旧甲板，拖走", "The rusted-through deck cut out and towed off", "cutter"],
		["bring", 2.0, "驳船运来整垛钢板", "The barge brings a stack of plate", "boat"],
		["lift", 3.0, "履带吊一块块吊上钢板、对位", "The crawler crane sets the plates one by one", "crane"],
		["fasten", 3.0, "焊接机器人沿缝焊满", "The welding robots run the seams", "welder"],
		["test", 1.0, "压上试重，看下挠", "A test load on; the deflection read", "tester"]]},
	"crane": {"part": ["hook", Vector2(1.0, 1.2)], "extra": ["drum", Vector2(1.4, 1.0)], "units": 4, "steps": [
		["isolate", 1.0, "划出吊装禁区，旧吊机断电挂牌", "The lift zone marked off; the old crane locked out", "bot"],
		["remove", 2.0, "放下烂掉的旧吊臂段", "The rotten jib sections let down", "cutter"],
		["bring", 2.0, "驳船运来新吊臂段和配重", "The barge brings jib sections and the counterweight", "boat"],
		["lift", 3.0, "辅助吊车一节节立起吊臂", "The assist crane stands the jib up section by section", "crane"],
		["fasten", 2.0, "销轴装上，液压扳手拉紧螺栓", "Pins in; the bolts tensioned by the hydraulic wrench", "torque"],
		["connect", 2.0, "穿钢丝绳，接起升电缆", "The hoist rope reeved, the hoist cable on", "cable"],
		["test", 1.0, "吊 125% 试重", "A 125 % test load lifted", "tester"]]},
	"arm": {"part": ["arm", Vector2(2.2, 1.0)], "extra": ["actuator", Vector2(1.0, 0.8)], "units": 3, "steps": [
		["isolate", 1.0, "伺服电源断开挂牌", "The servo supply locked out", "bot"],
		["bring", 2.0, "施工艇运来机械臂段", "The work boat brings the arm sections", "boat"],
		["lift", 2.0, "吊车把臂段放上导轨", "The crane sets the sections on the rail", "crane"],
		["fasten", 1.0, "导轨夹紧器拧到力矩", "The rail clamps torqued", "torque"],
		["connect", 2.0, "接伺服电缆和编码器线", "Servo and encoder cables run", "cable"],
		["test", 2.0, "激光对中，空载走一遍", "Laser-aligned; one run empty", "survey"]]},
	"drones": {"part": ["charger", Vector2(1.4, 0.9)], "extra": ["battery", Vector2(1.0, 0.7)], "units": 2, "steps": [
		["isolate", 1.0, "充电位断电挂牌", "The charging bay locked out", "bot"],
		["bring", 2.0, "施工艇运来装箱的搬运无人机", "The work boat brings the crated haulers", "boat"],
		["lift", 1.0, "托架放到停机位", "The cradles set on their pads", "crane"],
		["fasten", 1.0, "托架螺栓拧紧", "The cradle bolts torqued", "torque"],
		["connect", 1.0, "接充电电缆", "The charging cables on", "cable"],
		["test", 2.0, "试飞一圈", "One test flight", "tester"]]},
	"mouth": {"part": ["hpu", Vector2(1.6, 1.0)], "extra": ["actuator", Vector2(1.0, 0.8)], "units": 2, "steps": [
		["isolate", 1.0, "回收口停机，闸门锁死", "The mouth stopped, its gate pinned", "bot"],
		["remove", 2.0, "切开卡死的旧闸门", "The seized old gate cut free", "cutter"],
		["bring", 2.0, "施工艇运来闸门框和液压站", "The work boat brings the gate frame and its power pack", "boat"],
		["lift", 2.0, "吊车把门框放进开口", "The crane sets the frame in the opening", "crane"],
		["fasten", 2.0, "门框四周焊死", "The frame welded all round", "welder"],
		["connect", 1.0, "接液压管", "The hydraulic lines on", "cable"],
		["test", 1.0, "开合十次", "Ten cycles of the gate", "tester"]]},
	"pipe": {"part": ["manifold", Vector2(1.8, 0.9)], "extra": ["pipe", Vector2(2.0, 0.4)], "units": 4, "steps": [
		["isolate", 2.0, "氮气吹扫，管线放空", "Purged with nitrogen, the line emptied", "purge"],
		["bring", 2.0, "施工艇运来管段和阀组", "The work boat brings the spools and the valve set", "boat"],
		["lift", 2.0, "吊车把管段放上管架", "The crane lays the spools on the rack", "crane"],
		["fasten", 1.0, "法兰螺栓按力矩拧紧", "The flange bolts torqued", "torque"],
		["connect", 2.0, "轨道焊机焊接接头", "The orbital welder closes the joints", "welder"],
		["test", 2.0, "打压试验，查漏", "Pressure test; leak check", "tester"]]},
	"power": {"part": ["transformer", Vector2(1.8, 1.4)], "extra": ["inverter", Vector2(1.2, 0.9)], "units": 3, "steps": [
		["isolate", 1.0, "高压侧断开、接地挂牌", "The high-voltage side opened, earthed and tagged", "bot"],
		["remove", 2.0, "拆出烧毁的开关柜", "The burnt switchgear taken out", "cutter"],
		["bring", 2.0, "驳船运来变压器", "The barge brings the transformer", "boat"],
		["lift", 2.0, "重型吊车把变压器放上基座", "The heavy crane sets the transformer on its plinth", "crane"],
		["fasten", 1.0, "地脚螺栓拧紧", "The anchor bolts torqued", "torque"],
		["connect", 3.0, "敷设高压电缆，接头熔接", "High-voltage cable laid, the joints made", "cable"],
		["test", 1.0, "送电：变压器嗡嗡作响", "Energised: the transformer hums", "tester"]]},
	"rail": {"part": ["brake", Vector2(2.4, 0.5)], "extra": ["junction", Vector2(0.9, 0.7)], "units": 4, "steps": [
		["isolate", 1.0, "牵引电断开，轨道封锁", "Traction power off, the track blocked", "bot"],
		["remove", 2.0, "切掉坏轨段", "The dead track cut out", "cutter"],
		["bring", 2.0, "施工艇运来轨段", "The work boat brings track lengths", "boat"],
		["lift", 2.0, "吊车放轨段", "The crane lays the lengths", "crane"],
		["fasten", 2.0, "扣件一个个上紧", "The clips fastened one by one", "torque"],
		["connect", 2.0, "架接触线", "The contact wire strung", "cable"],
		["test", 1.0, "接驳车试跑一圈", "The shuttle makes a test run", "tester"]]},
	"dockyard": {"part": ["container", Vector2(2.2, 1.1)], "extra": ["crate", Vector2(1.0, 0.7)], "units": 3, "steps": [
		["isolate", 1.0, "作业区封闭", "The work area closed", "bot"],
		["remove", 1.0, "拆走损坏的设施", "The damaged fittings taken away", "cutter"],
		["bring", 2.0, "驳船运来模块", "The barge brings the modules", "boat"],
		["lift", 2.0, "吊车逐个吊装模块", "The crane sets the modules one by one", "crane"],
		["fasten", 2.0, "模块焊上基座", "The modules welded to the base", "welder"],
		["connect", 1.0, "接电和数据线", "Power and data run in", "cable"],
		["test", 1.0, "整套试运行", "The whole set run through", "tester"]]},
}
const FAMILY_OF := {"hauler": "drones", "hauler2": "drones", "port2": "mouth", "mouth_rail": "mouth", "buffer": "structure",
	"zones": "structure", "net05": "structure", "arm": "arm", "crane": "crane", "berth88": "structure", "berth120": "structure",
	"berth200": "structure", "berth620": "structure", "gas_line": "pipe", "lox_tank": "pipe"}
const ZONE_FAMILY := {"power": "power", "salvage": "structure", "process": "pipe", "tug": "dockyard", "trade": "dockyard", "cargo": "dockyard", "ring": "rail"}


# the family a job's facility is built by ("" for the three with their own plan)
static func family(id: String) -> String:
	if PLANS.has(id):
		return ""
	if id.begins_with("port:"):
		return str(ZONE_FAMILY.get(id.split(":")[1], "dockyard"))
	return str(FAMILY_OF.get(id, "structure"))


static func spec(id: String) -> Dictionary:
	return PLANS[id] if PLANS.has(id) else FAMILY.get(family(id), {})


# a family step's machine (the three own plans: by step)
static func machine(id: String, i: int) -> String:
	var st: Array = steps(id)
	if i < 0 or i >= st.size():
		return ""
	if st[i].size() > 4:
		return str(st[i][4])
	return {"isolate": "bot", "remove": "cutter", "bring": "boat", "lift": "boat", "fasten": "torque", "connect": "cable", "test": "tester"}.get(str(st[i][0]), "bot")


# what the crew's machines draw now (MW)
static func power(job: Dictionary) -> float:
	var a := at(job)
	if int(a[0]) < 0:
		return 0.0
	var m := machine(str(job.id), int(a[0]))
	var mw := float(MACHINE_MW.get(m, 0.1))
	if m == "tester" and family(str(job.id)) == "power":
		mw = 2.0
	return mw


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func has(id: String) -> bool:
	return PLANS.has(id) or family(id) != ""


# [[key, s, zh, en(, machine)], ...]: a family's shares become seconds of the job's total
static func steps(id: String, job_total: float = -1.0) -> Array:
	if PLANS.has(id):
		return PLANS[id].get("steps", [])
	var fam: Dictionary = FAMILY.get(family(id), {})
	var list: Array = fam.get("steps", [])
	if job_total <= 0.0:
		var j := Works.current()
		job_total = float(j.get("total", 60.0)) if str(j.get("id", "")) == id else 60.0
	var sum := 0.0
	for st in list:
		sum += float(st[1])
	var out: Array = []
	for st in list:
		out.append([st[0], float(st[1]) * job_total / maxf(sum, 0.001), st[2], st[3], st[4]])
	return out


static func total(id: String) -> float:
	var s := 0.0
	for st in PLANS.get(id, {}).get("steps", []):
		s += float(st[1])
	return s


static func step_name(key: String) -> String:
	return NAMES.get(key, [key, key])[0 if Txt.zh else 1]


# the step a job is on: [index, key, the fraction of it done]; [-1, "", 0] with no plan
static func at(job: Dictionary) -> Array:
	var id := str(job.get("id", ""))
	if not has(id):
		return [-1, "", 0.0]
	# 92 号: a job the crew builds for real is at the step its work has reached
	if job.has("step"):
		var st0 := steps(id, float(job.get("total", 60.0)))
		var k := clampi(int(job.step), 0, st0.size() - 1)
		return [k, str(st0[k][0]), float(job.get("step_f", 0.0))]
	var gone := float(job.get("total", 0.0)) - float(job.get("left", 0.0))
	var list := steps(id, float(job.get("total", 60.0)))
	for i in list.size():
		var s: float = list[i][1]
		if gone < s or i == list.size() - 1:
			return [i, str(list[i][0]), clampf(gone / s, 0.0, 1.0)]
		gone -= s
	return [-1, "", 0.0]


# the job building this facility is past the given step (its broken part is already off, …)
static func past(id: String, key: String) -> bool:
	var job := Works.current()
	if str(job.get("id", "")) != id:
		return false
	var a := at(job)
	var list := steps(id)
	for i in list.size():
		if str(list[i][0]) == key:
			return int(a[0]) > i
	return false


# the facility's broken look is gone: the old part is off — or, with the crew building it for real
# (92 号), its wreck is in the world in its place from the removal on
static func off(id: String) -> bool:
	if past(id, "remove"):
		return true
	var job := Works.current()
	if str(job.get("id", "")) != id or not job.get("crew", false):
		return false
	var list := steps(id)
	for i in list.size():
		if str(list[i][0]) == "remove":
			return int(job.get("step", 0)) >= i
	return false


# "第 3 / 7 道：运来新件"
static func line(job: Dictionary) -> String:
	var a := at(job)
	if int(a[0]) < 0:
		return ""
	return w("第 %d / %d 道：%s", "STEP %d OF %d: %s") % [int(a[0]) + 1, steps(str(job.id)).size(), step_name(str(a[1]))]


static func doing(job: Dictionary) -> String:
	var a := at(job)
	if int(a[0]) < 0:
		return ""
	var st: Array = steps(str(job.id))[int(a[0])]
	return str(st[2] if Txt.zh else st[3])
