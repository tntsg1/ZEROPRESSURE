extends RefCounted
# A sample ship's core asset, read the same way in three places (design/…/93_样板船_SA-200,
# 94_样板船_OB-90; the user's review 2026-10-27 "这一单是我赚出来的", Q3: one chain — the contract
# card, the status board on the job, the review at the settlement). 2026-10-28 answers: the card
# gives each way of taking the ship apart its money, its time and its risks; the board is on the
# HUD and on site both; the review says what was kept and what was lost, why, where it went and
# one thing to do better (keeping or selling comes later, with the business).
# Each ship listed here works its asset out from its own machinery — SA-200's sail (scripts/
# sail.gd), OB-90's primary mirror (scripts/optics.gd) — into one shape the HUD draws:
#   card    {name, units, full, methods: [{key, name, lo, hi, minutes, risks, need}]}
#   board   {name, worth, full, warn: [text], rows: [{name, text, right, grade, alert}], recent: [{text, money}]}
#   review  {name, full, rolled, got, units: [{text, value, sub}], lost: [{k, text, money, n}], reasons, advice}

const SHIPS := {
	"sa200": {
		"name": ["光帆", "LIGHT SAIL"],
		"units": ["4 卷帆材，四个角各一卷", "4 ROLLS, ONE A CORNER"],
		"methods": [
			{"key": "furl", "name": ["整帆收卷", "FURL IT WHOLE"], "minutes": [22, 35], "lo": 0.7, "hi": 1.0,
				"risks": ["带张力切断会撕裂，裂口顺着帆面蔓延；没接地，收卷时静电会击穿帆膜", "Cut while taut it tears, and the tear runs; unearthed, static pinholes the film as it winds"]},
			{"key": "scrap", "name": ["切碎当废料", "CUT IT TO SCRAP"], "minutes": [10, 16],
				"risks": ["快，几乎没风险，但光帆只剩废料价", "Quick and nearly safe, but the sail fetches scrap money only"]},
		],
	},
	# 98 号 (user 2026-10-28: the small ship alone; out whole against broken up; the way out by real
	# geometry; the locks numbered by the cradle; the ship rolling out for real)
	"lc140": {
		"name": ["内载小船", "THE SHIP IN THE HOLD"],
		"units": ["整船溢价 $900,000 + 船上设备和船壳", "$900,000 WHOLE + ITS EQUIPMENT AND HULL"],
		"nested": true,
		"methods": [
			{"key": "careful", "name": ["整船拖出", "OUT WHOLE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["小船断电、抽空燃料、舱室和货舱泄压；托架锁从船尾往船首依次解（CL-1→CL-4），先解船头侧会撬起撞门、溢价砍半；开船首门、出口路线清空、绞盘通电，整船拖出按一件结算；小船船壳一刀都别碰", "Battery off, fuel out, cabin and hold vented; the cradle locks from the stern forward (CL-1→CL-4), a bow lock first and it lurches into the door, half the premium gone; bow door open, the way out clear, winch powered: out whole, paid as one; never cut its hull"]},
			{"key": "demolish", "name": ["拆碎当零件", "BREAK IT UP"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不管顺序直接切：小船的设备照样能卖，但船壳一开，$900,000 的整船溢价就没了", "Cut it as it comes: its equipment still sells, but once its hull is open the $900,000 premium is gone"]},
		],
	},
	# 97 号 (user 2026-10-28: all 26 containers, by bay on the board; ends inwards against props
	# first; a bending bar over each bay)
	"cf90": {
		"name": ["货柜墙", "THE CONTAINER WALL"],
		"units": ["7 列 26 箱，含居住舱、低温箱、危险品箱", "26 CONTAINERS IN 7 BAYS, A HAB, A CRYO BOX AND A DG BOX AMONG THEM"],
		"boxes": true,
		"methods": [
			{"key": "careful", "name": ["两端往中间逐层卸", "ENDS INWARDS"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先松四根拉杆的花篮螺丝；每箱 6–9 t 要吊车；从两端往中间、每列从上往下，看着每列上方的弯曲读数走：外侧还满就卸空里侧，那一列会折弯，外侧的箱全被砸坏", "Slacken the four rods' turnbuckles first; each box is 6–9 t, crane it; from the ends inwards, each bay from the top, by the bending bar over it: empty an inner bay with the outer ones full and it kinks, every box beyond it damaged"]},
			{"key": "props", "name": ["撑杆抢里侧", "PROPS, INNER BAYS FIRST"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["两根临时撑杆顶住外侧的列，里侧的箱就能先卸：撑杆额定 60 t（约两列满箱），撑得太靠里会超载、弯了再折；撤撑杆之前外侧要先卸掉，不然空掉的列当场折弯", "Two temporary props under the outer bays and the inner bays can come off first: a prop is rated 60 t (about two full bays), set too far in it bows and buckles; clear the outer bays before you take a prop away, or the empty bay kinks at once"]},
		],
	},
	# 96 号 (user 2026-10-28: the ore and the crushing line together; the gates slowly against
	# prising the hopper open; the hopper's state by the hopper too)
	"m14": {
		"name": ["矿料与破碎筛分总成", "ORE AND CRUSHING LINE"],
		"units": ["细矿 34 t + 矿块；破碎头、筛选机、振动驱动、皮带、皮带电机", "34 t OF FINES + CHUNKS; CRUSHER, SCREENER, VIBRATOR, BELT, BELT MOTOR"],
		"ore": true,
		"groups": [
			{"name": ["破碎筛分", "CRUSHING LINE"], "tags": ["CRUSH-H", "SCR", "VIB-D", "BELT", "CONV-M"]},
		],
		"methods": [
			{"key": "careful", "name": ["慢开闸排料", "THROUGH THE GATES"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["两扇放料门用开关打开，矿从门里流出边流边收钱；门口搭拱就挪开矿块；破碎头 6 t 超过抓钩，整件要吊车，切开就成废料；皮带先松张紧再拆，直接切会弹回打坏筛选机", "Open both gates by their switches, the ore pays as it runs; an arch over a gate, move its chunks; the 6 t crusher is past the grapple, crane it whole; slacken the belt before you take it off"]},
			{"key": "demolish", "name": ["拆舱板取料", "PRISE THE HOPPER OPEN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["切开矿仓壁板，直接掏矿块，不用等放料：但料位线以下的破口会让细矿洒光、一分不算；矿还剩一半以上就撬门会撕裂矿仓、罚 $8,000", "Cut the hopper's walls and take the chunks, no waiting on the gates: but a hole below the heap pours the fines out unpaid; a gate forced with it half full tears the hopper, $8,000"]},
		],
	},
	# 95 号 (user 2026-10-28: the propulsion set and the hold's cargo together; careful against
	# demolition; the money and time of each from the salvage bot run both ways, not guessed)
	"gr7": {
		"name": ["推进总成与货舱货物", "PROPULSION AND CARGO"],
		"units": ["7 件：主、辅发动机，燃料箱，三件货", "7 UNITS: TWO ENGINES, THE FUEL TANK, THREE CRATES"],
		"groups": [
			{"name": ["推进总成", "PROPULSION"], "tags": ["ENG-C", "ENG-F", "T-F01"]},
			{"name": ["货舱货物", "CARGO"], "tags": ["C-01", "C-02", "C-03"]},
		],
		"methods": [
			{"key": "careful", "name": ["保全拆", "TAKE IT APART"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先断电、泄压、抽空燃料再动刀；切管带油会起火，切到设备就成废料，搬运时撞到会掉价", "Power off, vent, drain the fuel before any cut; a pipe cut wet burns, equipment cut is scrap, knocks on the way cost"]},
			{"key": "demolish", "name": ["暴力快拆", "BREAK IT UP"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["大刀切开船体，整块往熔炉里送：快、痛快，但设备大多切坏、撞坏，按废料算", "Cut the hull into big sections and feed them to the furnace: quick and satisfying, but most equipment is cut or knocked to scrap"]},
		],
	},
	# 114 号 (user 2026-10-30 "全按推荐"): the last six (the rest of the 200 m berth and ARK-01)
	"mt140": {
		"name": ["货罐", "THE CARGO TANKS"],
		"units": ["燃料罐 T-2、水罐 T-5 + 罐里的燃料和水", "THE FUEL TANK T-2, THE WATER TANK T-5 + WHAT IS IN THEM"],
		"groups": [
			{"name": ["货罐", "TANKS"], "tags": ["T-2", "T-5"]},
		],
		"fluid": {"f": ["fuel", "water"], "name": ["罐里的货", "WHAT THE TANKS HOLD"]},
		"dv": {"dv_train_spring": "train_spring"},
		"methods": [
			{"key": "careful", "name": ["抽空罐、从尾往前拆", "DRAIN, THEN FROM THE TAIL"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["总线还通着先从 PT-2、PT-5 把罐抽空（泵要有电）；从车尾往前拆，K-4 后面的拆完再动 K-4；罐 9 t 要吊车", "Drain both tanks at PT-2 and PT-5 while the bus is live (the pumps need it); strip from the tail, K-4 last; a tank is 9 t, crane it"]},
			{"key": "demolish", "name": ["先拆 K-4", "K-4 FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["K-4 车钩卡死承着整列的弯矩：先拆它，后半列弹开，撕坏两边；先断总线罐就抽不出来了", "K-4 holds the train's bend: undo it first and the aft train springs off, tearing both sides; cut the bus first and the tanks can't be drained"]},
		],
	},
	"dr150": {
		"name": ["钻探核心设备", "THE DRILLING CORE"],
		"units": ["防喷器、岩芯盒、底部钻具、顶驱", "THE BOP, THE CORE BOX, THE BHA, THE TOP DRIVE"],
		"groups": [
			{"name": ["钻探核心", "DRILLING"], "tags": ["BOP", "CORE", "BHA", "TD"]},
		],
		"dv": {"dv_drill_whip": "drill_whip", "dv_mud_fouled": "mud_fouled", "dv_drill_drop": "drill_drop"},
		"methods": [
			{"key": "careful", "name": ["泄扭放浆、逐节卸", "BLEED, DRAIN, STAND BY STAND"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先拨 TQB 泄掉残余扭矩，接 PMUD 放掉泥浆，再从上往下逐节卸钻杆，每卸一节先卡上它下面的卡瓦 SLIP", "Bleed the torque (TQB), let the mud out at PMUD, then break the stands out from the top, each with the slips (SLIP) set under it"]},
			{"key": "demolish", "name": ["带扭带压直接卸", "AS IT STANDS"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["带着扭矩卸钻杆会甩打砸坏钻台，带着泥浆压力会喷出污染设备，顺序错了上面的钻杆会掉下来", "Broken out with torque it whips and smashes the floor, with the mud in it blows out, out of order the stands above drop"]},
		],
	},
	"md160": {
		"name": ["飞轮与托架", "THE FLYWHEELS AND THE CRADLE"],
		"units": ["3 个飞轮 + 发射托架", "3 FLYWHEELS + THE LAUNCH CRADLE"],
		"groups": [
			{"name": ["飞轮与托架", "FLYWHEELS"], "tags": ["FW-1", "FW-2", "FW-3", "CRADLE"]},
		],
		"dv": {"dv_wheel_loose": "wheel_loose", "dv_rail_lurch": "rail_lurch", "dv_rail_whip": "rail_whip", "dv_brake_burn": "brake_burn"},
		"methods": [
			{"key": "careful", "name": ["冷却刹停、尾往头松", "COOLED BRAKES, TAIL FIRST"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["每个飞轮先开刹车冷却 CV 再拨刹车 BR，降到 300 rpm 以下才拆；导轨张紧器从尾往头逐个松；托架 6 t 要吊车", "Each wheel's brake cooling (CV) on, then its brake (BR), under 300 rpm before it comes off; the rail tensioners from the tail to the head; the cradle is 6 t, crane it"]},
			{"key": "demolish", "name": ["转着就拆", "STILL SPINNING"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["飞轮还在转就拆：甩飞砸坏旁边；干刹会烧坏卡钳；张紧器先松头部，导轨会窜动甩打", "Taken still spinning it is thrown off; braked dry the caliper burns; a head tensioner first and the rail lurches"]},
		],
	},
	"hg170": {
		"name": ["低温货与制冷机", "THE CRYO CARGO AND COOLERS"],
		"units": ["4 罐低温货 + 两台制冷机", "4 TANKS OF CRYO CARGO + TWO CRYOCOOLERS"],
		"groups": [
			{"name": ["制冷机", "CRYOCOOLERS"], "tags": ["CRY-1", "CRY-2"]},
		],
		"fluid": {"f": "coolant", "name": ["低温货", "CRYO CARGO"]},
		"dv": {"dv_tank_burst": "tank_burst"},
		"methods": [
			{"key": "careful", "name": ["冷着逐罐抽走", "COLD, TANK BY TANK"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["制冷机一直开着，先拨 RVH-3 给 TK3 冻住的泄压阀化冻，再逐罐接 PT 口抽走，最后才断电", "Keep the cryocoolers running, thaw TK3's frozen relief valve (RVH-3), draw each tank at its PT port, power off last"]},
			{"key": "demolish", "name": ["先断电", "POWER OFF FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["先断电：罐压一路升到泄压阀放空，货没了；TK3 的阀冻着，那一罐会爆", "Power off first: the tanks climb to their reliefs and vent the cargo; TK3's valve is frozen, and that one bursts"]},
		],
	},
	"tb180": {
		"name": ["吊舱设备", "THE PODS' EQUIPMENT"],
		"units": ["系绳两端两个吊舱里的设备", "WHAT THE TWO PODS ON THE TETHER CARRY"],
		"groups": [
			{"name": ["吊舱设备", "PODS"], "tags": ["CON-A", "AV-A", "LOG-A", "COMMS-A", "TEN-MON", "ECS-A", "GALLEY-A", "BAT-A", "DIST-A", "WATER-A", "O2-A", "TANK-1", "TANK-2", "HE-B", "RCSC-B", "GEN-B", "BAT-B", "RAD-B", "PWR-B", "INV-B", "PUMP-B", "ENG-B"]},
		],
		"dv": {"dv_pods_thrown": "pods_thrown", "dv_tether_snap": "tether_snap", "dv_tether_whip": "tether_whip", "dv_brake_slip": "brake_slip"},
		"methods": [
			{"key": "careful", "name": ["冷却刹停、松张力再切", "BRAKE, SLACKEN, THEN CUT"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["开船坞刹车的冷却 BRK-C 再拨刹车 BRK，等它停转；拨 TEN 松掉残余张力，再切系绳；干刹打滑了就只能用 B 舱的 RCS 停", "The berth brake's cooling (BRK-C) on, then the brake (BRK), till it stops; let the residual pull off (TEN), then cut the tether; braked dry the rollers slip and only B's RCS can stop it"]},
			{"key": "demolish", "name": ["转着切绳", "CUT IT TURNING"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["还在转就切系绳：两个吊舱被甩飞，里面的设备撞坏", "Cut the tether still turning: both pods are thrown, and what they carry is smashed"]},
		],
	},
	"ark01": {
		"name": ["两座反应堆", "THE TWO REACTORS"],
		"units": ["主反应堆 + 副反应堆", "THE MAIN REACTOR + THE SECONDARY"],
		"groups": [
			{"name": ["反应堆", "REACTORS"], "tags": ["CORE-M", "SEC-R"]},
		],
		"dv": {"dv_drum_slip": "drum_slip"},
		"methods": [
			{"key": "careful", "name": ["锁鼓、冷却、躲辐射", "LOCK, COOL, SHADOW"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["和 NR-95 一样：四个控制鼓先拨 RL 锁住，冷到 60°C 以下，在屏蔽板的阴影里干活，激光绝不碰堆芯；整船只许人工拆", "As on NR-95: the four drum locks (RL) thrown, cooled under 60 °C, worked in the shield's shadow, the beam never on the core; the whole ship by hand only"]},
			{"key": "demolish", "name": ["硬干", "IGNORE IT"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不锁鼓不躲辐射：无人机剂量超限、控制鼓滑出；激光切坏堆芯会核爆", "Locks off, no shadow: the drone's dose runs over, a drum slips; cut a core and it detonates"]},
		],
	},
	# 113 号 (user 2026-10-30 "ok"): the third ten, by when they turn up (the rest of the 120 m berth and
	# the first six of the 200 m one)
	"ps12": {
		"name": ["逃生舱", "THE ESCAPE PODS"],
		"units": ["4 个逃生舱", "4 ESCAPE PODS"],
		"groups": [
			{"name": ["逃生舱", "ESCAPE PODS"], "tags": ["POD-1", "POD-2", "POD-3", "POD-4"]},
		],
		"dv": {"dv_pod_fired": "pod_fired"},
		"methods": [
			{"key": "careful", "name": ["先断点火再松夹", "DISARM, THEN UNCLAMP"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["每个舱的点火电容先拨 ARM 断开（或拔掉引线），再松发射夹；观察厅先泄压，玻璃才不会吹出", "Each pod's firing circuit off at its ARM switch (or its lead pulled) before its launch clamps; vent the observation hall before its glass"]},
			{"key": "demolish", "name": ["直接切夹", "CUT THE CLAMPS"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["点火电路还活着就切发射夹：火工螺栓点火，逃生舱被弹射出去摔坏", "Cut a launch clamp with its circuit live: the bolts fire and the pod is thrown off and smashed"]},
		],
	},
	"ch110": {
		"name": ["居住舱", "THE HABITAT MODULE"],
		"units": ["夹在两船体之间的预制居住舱里的 19 件设备", "THE 19 UNITS IN THE HABITAT CLAMPED BETWEEN THE HULLS"],
		"groups": [
			{"name": ["居住舱设备", "HABITAT"], "tags": ["DESK-C", "ECS-C", "LIFE-C", "AHU-C", "FIRE-C", "DATA-C", "O2-C", "FILT-C", "SPARE-C", "COMMS-C", "GALLEY-C", "MESS-C", "MED-C", "WATER-C", "BAT-C", "PWR-C", "CON-C", "STORES-C", "REC-C"]},
		],
		"dv": {"dv_cargo_spring": "cargo_spring", "dv_clamp_spring": "cargo_spring", "dv_cargo_twist": "cargo_twist", "dv_hull_torn": "hull_torn"},
		"methods": [
			{"key": "careful", "name": ["泄压、对角交替松夹", "VENT, THEN THE CLAMPS CROSSWISE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["居住舱先抽到 20 kPa 以下，8 个液压夹按对角顺序交替松（HC-U1、HC-L4、HC-U4、HC-L1……）", "Pump the habitat below 20 kPa, then let the eight clamps go crosswise (HC-U1, HC-L4, HC-U4, HC-L1…)"]},
			{"key": "demolish", "name": ["一边先全松", "ONE SIDE FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["有压就松夹舱体会弹出；一边先松光舱体扭转、砸坏舱里的设备，裂了的 2 号梁会断开", "Let go with air in it and it springs; one side first and it twists into its fittings, and the cracked beam 2 tears out"]},
		],
	},
	"es112": {
		"name": ["金库货", "THE VAULT CARGO"],
		"units": ["8 个保险箱 + 托管件", "8 SAFE BOXES + THE CUSTODY CASE"],
		"groups": [
			{"name": ["金库货", "VAULT CARGO"], "tags": ["SAFE-11", "SAFE-12", "SAFE-13", "SAFE-14", "SAFE-21", "SAFE-22", "SAFE-23", "SAFE-24", "CUSTODY"]},
		],
		"methods": [
			{"key": "careful", "name": ["断锁开金库", "KILL THE LOCKS, OPEN THE VAULTS"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["两路电锁都要断：主电 K-M 和锁的备用电 K-LB；再在维修柜拨机械释放 MR，金库门就能打开，保险箱整件取出", "Both lock circuits dead, the main bus (K-M) and the locks' backup (K-LB); throw the release (MR) in the maintenance cabinet, open the vault, take the boxes whole"]},
			{"key": "demolish", "name": ["切开金库墙", "CUT THROUGH THE VAULT"], "minutes": [0, 0], "lo": 0.0, "hi": 0.3,
				"risks": ["不开门直接切金库墙：快，但刀口贴着保险箱，切到或撞到就掉价", "Cut through the vault wall: quick, but the cuts run beside the boxes and a cut or a knock costs"]},
		],
	},
	"fl116": {
		"name": ["三种介质", "THE THREE MEDIA"],
		"units": ["酸、乙二醇、溶剂 + 总管 + 三个工艺罐", "ACID, GLYCOL, SOLVENT + THE MANIFOLD + THREE PROCESS TANKS"],
		"groups": [
			{"name": ["管路与罐", "PIPES AND TANKS"], "tags": ["MANIFOLD", "TK-1", "TK-2", "TK-3"]},
		],
		"fluid": {"f": ["acid", "glycol", "solvent"], "name": ["介质货", "THE MEDIA"]},
		"methods": [
			{"key": "careful", "name": ["取样分开抽", "SAMPLE, THEN ONE AT A TIME"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["接口编号对不上介质：先在 SP 点取样认清；抽哪一支就只开它的阀 V，其他支路阀全关", "The port numbers say nothing of the medium: sample at SP first; open only the branch you draw, every other valve shut"]},
			{"key": "demolish", "name": ["全开一起抽", "ALL AT ONCE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["几支路阀都开着就抽：介质在总管里混成废液，不值钱还要付处理费；带介质切总管会洒", "Draw with several valves open: they mix in the manifold into waste, worthless and charged for; cut the manifold full and it spills"]},
		],
	},
	"ic120": {
		"name": ["冰与水泵", "THE ICE AND THE PUMPS"],
		"units": ["冰（融水按水价）+ 两台水泵", "THE ICE (PAID AS WATER) + TWO PUMPS"],
		"groups": [
			{"name": ["水泵", "PUMPS"], "tags": ["MP-1", "MP-2"]},
		],
		"fluid": {"f": "water", "ice": true, "name": ["冰（融水）", "THE ICE (WATER)"]},
		"dv": {"dv_melt_short": "melt_short", "dv_ice_drop": "ice_drop", "dv_crack_run": "crack_run"},
		"methods": [
			{"key": "careful", "name": ["加热融冰、及时泵水", "MELT IT, PUMP IT"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["逐区开加热器 HT 融冰，融水积到 3 m³ 就会短路，及时从 PW 泵走；冰化到一半以下才松鞍座 PH", "Heaters (HT) zone by zone; past 3 m³ standing the meltwater shorts things, pump it at PW as it comes; no saddle seat (PH) lets go till half the ice is gone"]},
			{"key": "demolish", "name": ["直接切冰", "CUT THE ICE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["直接切冰块：裂缝顺着冰跑，冰块砸坏设备；冰没化就松鞍座，冰整块掉下来", "Cut the ice: the crack runs and the split ice hits the units; a seat let go with the ice still on drops it"]},
		],
	},
	"sv122": {
		"name": ["测绘仪器", "THE SURVEY INSTRUMENTS"],
		"units": ["阵列 + 摇篮上的 3 台光学仪", "THE ARRAY + 3 OPTICS ON THE CRADLE"],
		"groups": [
			{"name": ["测绘仪器", "INSTRUMENTS"], "tags": ["ARRAY", "OPT-1", "OPT-2", "OPT-3"]},
		],
		"dv": {"dv_rail": "rail_cut", "dv_drop": "rail_drop"},
		"methods": [
			{"key": "careful", "name": ["先解摇篮锁", "THE CRADLE LOCKS FIRST"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["仪器摇篮挂在主梁上：先拨 DL 解开三台光学仪的摇篮锁，再动吊挂和主梁", "The cradle hangs from the main beam: release the three optics (DL) before the hangers or the beam"]},
			{"key": "demolish", "name": ["直接切吊挂", "CUT THE HANGERS"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["锁还没解就切吊挂或主梁：整组仪器砸下来", "Cut a hanger or the beam with them still locked on: the whole set comes down"]},
		],
	},
	"mf126": {
		"name": ["炉芯与钢锭", "THE FURNACE CORE AND THE INGOTS"],
		"units": ["炉芯 + 两个钢锭架 + 光谱仪", "THE CORE + TWO INGOT RACKS + THE SPECTROMETER"],
		"groups": [
			{"name": ["冶炼", "SMELTING"], "tags": ["CORE", "INGOT-1", "INGOT-2", "SPECTRO"]},
		],
		"dv": {"loss_core": "furnace_crack", "dv_preload": "feed_snap"},
		"methods": [
			{"key": "careful", "name": ["保持换热冷下来", "KEEP IT COOLING"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["换热泵 HX 一直有电，炉芯冷到 150°C 以下再吊；进料臂先给 ACC-F 泄压、拔销；炉芯 9 t 要吊车", "Keep the heat-exchange pumps (HX) powered till the core is under 150 °C; bleed the feed arm (ACC-F) and pull its pins; the core is 9 t, crane it"]},
			{"key": "demolish", "name": ["先断电", "POWER OFF FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["350°C 以上断了冷却，炉芯热震开裂；带压拆进料臂会弹出砸坏分选机", "Cooling lost over 350 °C and the core cracks; the feed arm taken under pressure springs into the sorter"]},
		],
	},
	"ro128": {
		"name": ["滚装货", "THE RO-RO CARGO"],
		"units": ["4 件大货", "4 CARGO UNITS"],
		"groups": [
			{"name": ["大货", "CARGO"], "tags": ["CARGO-1", "CARGO-2", "CARGO-3", "CARGO-4"]},
		],
		"dv": {"dv_rail": "rail_cut", "dv_drop": "rail_drop", "dv_preload": "visor_snap"},
		"methods": [
			{"key": "careful", "name": ["开首门、解锁滚出", "BOW OPEN, ROLL THEM OUT"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["船首门的蓄能器 ACC-D 先泄压、拔销，再开门罩和首门；然后逐条拨 LR 解轨道锁，货自己滚出来；每件 4.8 t 要吊车", "Bleed the bow door's accumulator (ACC-D) and pull its pins, open the visor and the door; then each rail lock (LR) and the cargo rolls out; 4.8 t each, crane them"]},
			{"key": "demolish", "name": ["切开甲板直接抓", "CUT IN AND GRAB"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["轨道锁扳手拧不开，只能连轨道切：货被扯伤", "The wrench can't undo a rail lock: cut the rail with the cargo on it and it is wrenched"]},
		],
	},
	"pt34": {
		"name": ["舰载设备", "THE WARSHIP'S EQUIPMENT"],
		"units": ["反应堆、炮塔、火控、加密机", "THE REACTOR, THE TURRET, THE FIRE CONTROL, THE CRYPTO"],
		"groups": [
			{"name": ["舰载设备", "SHIPBORNE"], "tags": ["REACT", "TURRET", "FCS", "CRYPTO"]},
		],
		"dv": {"dv_blast": "cook_off", "dv_actuator": "actuator"},
		"methods": [
			{"key": "careful", "name": ["注水湿弹、锁作动器", "FLOOD, LOCK, THEN TAKE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先开注水阀 FLV 把弹库全打湿（弹药就不会殉爆，但也不值钱了），拨 LK-T 锁住推力矢量作动器，放掉电容再拆；反应堆 12 t 要吊车", "Open the flood valve (FLV) and wet the magazine (no cook-off, and no value in the rounds), lock the thrust-vector rams (LK-T), drain the capacitors, then take; the reactor is 12 t, crane it"]},
			{"key": "demolish", "name": ["带弹快拆", "WITH THE ROUNDS LIVE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["弹药还活着就在附近切：殉爆，一发带一发连锁，设备被炸坏；作动器没锁切线会猛甩", "Cut close with the rounds live: they cook off, one setting off the next, and the units are blown apart; an unlocked ram jerks when its line is cut"]},
		],
	},
	"cv138": {
		"name": ["无人机", "THE DRONES"],
		"units": ["6 架舱位无人机 + 回收无人机", "6 BAY DRONES + THE RECOVERY DRONE"],
		"groups": [
			{"name": ["无人机", "DRONES"], "tags": ["DR-1", "DR-2", "DR-3", "DR-4", "DR-5", "DR-6", "DR-7"]},
		],
		"dv": {"dv_drone_woke": "drone_woke", "dv_preload": "lift_snap"},
		"methods": [
			{"key": "careful", "name": ["断电池再拆", "PACKS OFF, THEN TAKE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["每架无人机先拨 PK 断开电池隔离开关（或先摘电池），升降机给 ACC-G 泄压、拔销，再从托架上拆", "Each drone's pack isolator off (PK), or the pack off first; bleed the lift (ACC-G) and pull its pins; then off the cradles"]},
			{"key": "demolish", "name": ["带电直接拆", "PACKS LIVE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["电池还通着就拆托架：无人机醒来，旋翼一转把自己甩出去撞坏", "Free a drone with its pack live: it wakes, spins up and throws itself into whatever is near"]},
		],
	},
	# 112 号 (user 2026-10-30 "按你说的"): the second ten, by when they turn up (the 88 m berth and the
	# first four of the 120 m one)
	"fx70": {
		"name": ["超导线圈", "THE SUPERCONDUCTING COILS"],
		"units": ["8 个环向线圈 + 2 个中心螺线管", "8 TOROIDAL COILS + 2 CENTRAL SOLENOIDS"],
		"groups": [
			{"name": ["线圈", "COILS"], "tags": ["TF-1", "TF-2", "TF-3", "TF-4", "TF-5", "TF-6", "TF-7", "TF-8", "CS-1", "CS-2"]},
		],
		"dv": {"dv_magnet_quench": "quench"},
		"methods": [
			{"key": "careful", "name": ["按序泄能", "DUMP IT IN ORDER"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["开泄能开关 DUMP、保持制冷（冷箱要有电、液氦要够），等储能降到 5% 以下再动线圈支架", "Close the dump (DUMP) with the cooling kept on (the cold box powered, helium in it), and touch no coil support till the energy is under 5%"]},
			{"key": "demolish", "name": ["带场快拆", "WITH THE FIELD UP"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不泄能就断电或切支架：线圈失超，能量瞬间放出，连锁到旁边的线圈", "Power off or cut a support with the field up: the coil quenches, the energy comes out at once and runs into the coils beside it"]},
		],
	},
	"tw64": {
		"name": ["引擎舱与绞车", "THE ENGINE PODS AND THE WINCH"],
		"units": ["上下两台引擎舱 + 拖曳绞车", "TWO ENGINE PODS + THE TOW WINCH"],
		"groups": [
			{"name": ["引擎舱", "ENGINE PODS"], "tags": ["ENG-U", "ENG-L"]},
			{"name": ["绞车", "WINCH"], "tags": ["WINCH"]},
		],
		"dv": {"dv_twist": "twist", "dv_preload": "winch_snap"},
		"methods": [
			{"key": "careful", "name": ["撑住船体、泄压拔销", "PROP IT, BLEED, UNPIN"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先拨 SUP 撑住船体（或者两台引擎舱一起拆），蓄能器泄压、拔掉绞车和拖钳的销子再拆；引擎舱 4.2 t 要吊车", "Set the support (SUP) first, or take both pods together; bleed the accumulators and pull the winch and jaw pins; a pod is 4.2 t, crane it"]},
			{"key": "demolish", "name": ["先拆一边", "ONE SIDE FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不撑船体先拆一边：重量全压在剩下那台上，船体扭曲，引擎舱和吊架受损；带压拆绞车会弹出", "One pod off with nothing set: the hull twists under the other, it and its mounts damaged; the winch taken under load springs"]},
		],
	},
	"fr26": {
		"name": ["LNG 货与罐", "THE LNG AND ITS TANKS"],
		"units": ["三罐 LNG 货 + 三个低温罐", "THREE TANKS OF LNG + THE TANKS"],
		"groups": [
			{"name": ["低温罐", "CRYO TANKS"], "tags": ["T-1", "T-2", "T-3"]},
		],
		"fluid": {"f": "lng", "name": ["LNG 货", "LNG"]},
		"dv": {"dv_rupture": "rupture"},
		"methods": [
			{"key": "careful", "name": ["冷着抽走 LNG", "DRAW IT OFF COLD"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["冷机一直开着，从每个罐的 LP 口把 LNG 抽走，最后才断电拆罐；罐 7 t 要吊车", "Keep the chillers running, draw each tank off at its LP port, power off last; a tank is 7 t, crane it"]},
			{"key": "demolish", "name": ["放空切罐", "VENT AND CUT"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["先断电直接切：LNG 升温沸散，货没了；泄压阀冻住的罐会爆", "Power off and cut: the LNG warms and boils away, and a tank with its relief valve frozen ruptures"]},
		],
	},
	"med47": {
		"name": ["医疗设备", "THE MEDICAL EQUIPMENT"],
		"units": ["3 张手术台、3 个冷冻柜、空气再生器、制氧机", "3 OPERATING TABLES, 3 FREEZERS, THE AIR REGENERATOR, THE OXYGEN PLANT"],
		"groups": [
			{"name": ["医疗设备", "MEDICAL"], "tags": ["OPT-U2", "OPT-L1", "OPT-L5", "FRZ-U4", "FRZ-L2", "FRZ-L6", "AIR-REGEN", "O2-GEN"]},
		],
		"dv": {"dv_bio": "bio"},
		"methods": [
			{"key": "careful", "name": ["封存、滤网抽气再开门", "SEAL, FILTER, THEN OPEN"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["隔离舱先用回收软管（带滤网）抽走空气，生物危险品逐个封存再搬，干净舱的门最后才开", "Pump the isolation rooms out through the hose's filter, seal every biohazard before it moves, open the clean rooms last"]},
			{"key": "demolish", "name": ["直接切开", "CUT STRAIGHT IN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.75,
				"risks": ["隔离舱带着污染空气就开门或切开：污染扩散到干净舱，里面的设备每件掉 1/4", "Open or cut an isolation room with its air still dirty: it spreads, and every unit in a clean room it reaches loses a quarter"]},
		],
	},
	"dc84": {
		"name": ["浸没机柜", "THE IMMERSED RACKS"],
		"units": ["12 个机柜（另有 8 块客户硬盘要托管）", "12 RACKS (AND 8 CLIENT DRIVES IN CUSTODY)"],
		"groups": [
			{"name": ["机柜", "RACKS"], "tags": ["RA-1", "RA-2", "RA-3", "RA-4", "RA-5", "RA-6", "RB-1", "RB-2", "RB-3", "RB-4", "RB-5", "RB-6"]},
		],
		"dv": {"dv_immersion_spill": "spill", "dv_immersion_short": "short"},
		"methods": [
			{"key": "careful", "name": ["抽干再吊、硬盘先上锁", "DRAIN, LATCH, THEN LIFT"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["8 块硬盘先拨 CUST 锁进屏蔽舱；每个机柜先从 PT 口抽干冷却液罐，再拧下吊走", "Latch the 8 drives into custody (CUST) first; drain each rack's tank at its PT port before you unbolt it"]},
			{"key": "demolish", "name": ["带液直接吊", "LIFT THEM WET"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["罐里还有液就吊：冷却液洒出来，旁边一排机柜短路；没上锁的硬盘取出按违约罚款", "Lift a rack wet: the fluid spills and shorts the racks beside it; a drive taken unlatched is a breach, fined"]},
		],
	},
	"bl88": {
		"name": ["生态货", "THE LIVING CARGO"],
		"units": ["鱼缸、鱼苗箱、种子库", "THE FISH TANK, THE FRY TANK, THE SEED VAULT"],
		"groups": [
			{"name": ["生态货", "LIVING CARGO"], "tags": ["FISH-T", "FRY", "SEED"]},
		],
		"dv": {"dv_fish_lost": "fish", "dv_water_soak": "soak", "dv_water_short": "soak"},
		"methods": [
			{"key": "careful", "name": ["抽水缩球、穹顶泄压", "PUMP IT DOWN, VENT THE DOME"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先从 PW 口抽水，水球缩到 12% 以下才能动网罩和支架；穹顶先泄压，玻璃才不会吹出", "Pump the ball down at PW below 12% before the net or its frame; vent the dome before the glass"]},
			{"key": "demolish", "name": ["直接切网", "CUT THE NET"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["水球还大就切网：水球炸散，鱼全死，舱里的电气被泡坏", "Cut the net with the ball still up: it bursts, the fish die, the room's electrics are soaked"]},
		],
	},
	"hb86": {
		"name": ["培养舱", "THE CULTURE HALLS"],
		"units": ["种子库、6 个培养架、6 块观察玻璃、培养控制台", "THE SEED VAULT, 6 CULTURE RACKS, 6 VIEWING PANES, THE CONSOLE"],
		"groups": [
			{"name": ["培养舱", "CULTURE HALLS"], "tags": ["SEED", "CR-1a", "CR-1b", "CR-2a", "CR-2b", "CR-3a", "CR-3b", "GL-1", "GL-2", "GL-3", "GL-4", "GL-5", "GL-6", "CON"]},
		],
		"dv": {"dv_fire": "o2_flash", "dv_glass": "glass_craze"},
		"methods": [
			{"key": "careful", "name": ["逐舱抽走富氧空气", "THE RICH AIR OUT, HALL BY HALL"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["三间培养舱逐个接 G-U 口抽空，富氧空气走了再动刀；观察玻璃拧螺栓拆", "Pump each culture hall out at its G-U port before any cut; unbolt the panes"]},
			{"key": "demolish", "name": ["带气快拆", "STRAIGHT IN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["富氧空气还在就切：闪燃烧遍培养舱，观察玻璃也会龟裂", "Cut with the rich air in: a flash fire through the halls, and the panes craze"]},
		],
	},
	"nr95": {
		"name": ["核热推进", "THE NUCLEAR DRIVE"],
		"units": ["堆芯、液氢罐、喷管、屏蔽板", "THE CORE, THE HYDROGEN TANK, THE NOZZLE, THE SHIELD"],
		"groups": [
			{"name": ["核热推进", "NUCLEAR DRIVE"], "tags": ["CORE", "LH2-T", "NOZ", "SHIELD"]},
		],
		"dv": {"loss_core": "core_crack", "dv_drum_slip": "drum_slip"},
		"methods": [
			{"key": "careful", "name": ["躲辐射、锁鼓、冷却", "SHADOW, LOCK, COOL"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["四个控制鼓先拨 DL 锁住，冷却泵有电让堆芯冷到 60°C 以下；先吊起屏蔽板，在它的阴影里干活；激光绝不碰堆芯", "Lock the four drums (DL), keep the coolant pumps powered till the core is under 60 °C; lift the shield and work in its shadow; never let the beam touch the core"]},
			{"key": "demolish", "name": ["硬干", "IGNORE IT"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不躲辐射硬干：无人机剂量超限、电子件故障；控制鼓没锁就吊堆芯会滑出；激光切坏堆芯会核爆", "Work in the open: the drone's dose runs over and its electronics fault; lift the core with a drum unlocked and it slips; cut the core and it detonates"]},
		],
	},
	"vt80": {
		"name": ["推进剂系统", "THE PROPELLANT SYSTEM"],
		"units": ["三个推进剂罐 + 主泵 + 罐里的推进剂", "THREE PROPELLANT TANKS + THE MAIN PUMP + THE PROPELLANT"],
		"groups": [
			{"name": ["推进剂系统", "PROPELLANT SYSTEM"], "tags": ["T-1", "T-2", "T-3", "PUMP-M"]},
		],
		"fluid": {"f": "fuel", "name": ["推进剂货", "PROPELLANT"]},
		"dv": {"dv_buckle": "buckle", "dv_pump_dry": "pump_dry"},
		"methods": [
			{"key": "careful", "name": ["按序关阀抽走", "VALVES IN ORDER, PUMP IT OFF"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["主泵有电时打开 MMH 罐的交叉阀，从 PR 口抽走总管；N2O4 罐单独从 LD-2 抽；增压阀 PV 一直开着、TV 和 NP 口别放空，否则罐会抽瘪", "With the pump powered open the MMH tanks' cross valves and draw the manifold at PR; the N2O4 tank on its own at LD-2; keep the pressurisation (PV) open and never vent TV or NP, or a tank buckles"]},
			{"key": "demolish", "name": ["直接切管", "CUT THE LINES"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["推进剂还在就切管：MMH 和 N2O4 碰上自燃，罐和泵烧坏", "Cut the lines with propellant in them: the MMH and N2O4 meet and ignite, burning the tanks and the pump"]},
		],
	},
	"cl104": {
		"name": ["疫苗货", "THE VACCINES"],
		"units": ["三间冷舱的 18 个托盘 + 6 个疫苗箱", "18 PALLETS + 6 VACCINE BOXES IN THREE COLD HOLDS"],
		"groups": [
			{"name": ["疫苗货", "VACCINES"], "tags": ["PAL-11", "PAL-12", "PAL-13", "PAL-14", "PAL-15", "PAL-16", "PAL-21", "PAL-22", "PAL-23", "PAL-24", "PAL-25", "PAL-26", "PAL-31", "PAL-32", "PAL-33", "PAL-34", "PAL-35", "PAL-36", "VAX-11", "VAX-12", "VAX-21", "VAX-22", "VAX-31", "VAX-32"]},
		],
		"dv_any": ["loss_thaw"],
		"dv": {"loss_thaw": "thaw"},
		"methods": [
			{"key": "careful", "name": ["保冷卸货", "KEEP IT COLD"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先接船坞临时制冷 COLD-X（或让冷机一直有电），货全部卸完再断电", "Plug in the berth's cooling (COLD-X), or keep the chillers powered, till every pallet is out; power off last"]},
			{"key": "demolish", "name": ["先断电再卸", "POWER OFF FIRST"], "minutes": [0, 0], "lo": 0.0, "hi": 0.45,
				"risks": ["先断电：冷舱升到 −5°C 以上，疫苗解冻，只剩 45% 价值", "Power off first: the holds warm past −5 °C and the vaccines thaw, 45% of their worth left"]},
		],
	},
	# 111 号 (user 2026-10-30 "按你推荐": the ten ships a new hand meets first, each with its
	# core asset and two ways, both measured by the salvage bot)
	"tug": {
		"name": ["推进与拖曳设备", "PROPULSION AND TOW GEAR"],
		"units": ["拖缆绞车、主机、导航", "THE TOW WINCH, THE ENGINE, THE NAV"],
		"groups": [{"name": ["推进与拖曳", "PROPULSION AND TOW"], "tags": ["WINCH-T", "ENG-T", "NAV-T"]}],
		"methods": [
			{"key": "careful", "name": ["保全拆", "TAKE IT APART"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先泄压、断电、抽空燃料；设备用维护工具拧下固定件整件取，切到就成废料", "Vent, power off, drain the fuel; unbolt each unit whole with the wrench, a cut makes it scrap"]},
			{"key": "demolish", "name": ["大块切进熔炉", "BIG SECTIONS TO THE FURNACE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["船体切成大块整块送熔炉：快，但设备跟着一起熔了", "Cut the hull into big sections for the furnace: quick, but the units melt with it"]},
		],
	},
	"pod": {
		"name": ["货柜", "THE CONTAINERS"],
		"units": ["5 个货柜", "5 CONTAINERS"],
		"groups": [{"name": ["货柜", "CONTAINERS"], "tags": ["CG-1", "CG-2", "CG-3", "CG-4", "CG-5"]}],
		"methods": [
			{"key": "careful", "name": ["开舱门逐个取", "THROUGH THE DOOR, ONE BY ONE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["开货舱门，拧开每个货柜的固定件，逐个抓出来；最大的 CG-3 有 3.8 t，超过抓钩要吊车", "Open the hold, unbolt each container and take it out one by one; CG-3 is 3.8 t, past the grapple: crane it"]},
			{"key": "demolish", "name": ["切开舱壁整排拖出", "CUT THE WALL, DRAG THE ROW"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["切开货舱壁，连着舱板整排拖出来：快，但刀口贴着货柜，切到就成废料", "Cut the hold's wall and drag the row out on its deck: quick, but the cuts run along the boxes and a cut box is scrap"]},
		],
	},
	"s09": {
		"name": ["作业设备", "THE WORK GEAR"],
		"units": ["机械臂、燃料电池、主机", "THE ARM, THE FUEL CELL, THE ENGINE"],
		"groups": [{"name": ["作业设备", "WORK GEAR"], "tags": ["ARM-01", "FC-01", "MAIN-E"]}],
		"methods": [
			{"key": "careful", "name": ["保全拆", "TAKE IT APART"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["燃料电池先停机、放掉电容、抽空氢氧再拆；机械臂是强制回收件，整件拧下送设备口", "Stop the fuel cell, drain the capacitor, take the hydrogen and oxygen out first; the arm is a named piece: unbolt it whole"]},
			{"key": "demolish", "name": ["大块切进熔炉", "BIG SECTIONS TO THE FURNACE"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["船体切成大块送熔炉：快，但氢氧还在就切会爆燃，设备跟着熔掉", "Big sections to the furnace: quick, but cut with the gas still in it flares, and the units melt"]},
		],
	},
	"qc30": {
		"name": ["量子芯片与制冷机", "THE QUANTUM CHIP AND ITS FRIDGE"],
		"units": ["量子芯片 QPU + 稀释制冷机五级冷台", "THE QPU + THE FRIDGE'S FIVE STAGES"],
		"groups": [
			{"name": ["量子芯片", "QUANTUM CHIP"], "tags": ["QPU"]},
			{"name": ["制冷机冷台", "FRIDGE STAGES"], "tags": ["STG-50K", "STG-4K", "STG-STILL", "STG-CP", "STG-MXC"]},
		],
		"dv": {"dv_qpu_shock": "qpu_shock", "dv_qpu_brittle": "qpu_brittle", "dv_qpu_vibration": "qpu_vibration", "dv_mix_boil": "mix_boil"},
		"methods": [
			{"key": "careful", "name": ["慢等自然回温", "LET IT WARM BY ITSELF"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先锁隔振台、停循环、回收混合气，再停脉管，等它自己回到 250 K 以上才拆冷台：安全，但要等很久", "Lock the isolation table, stop the circulation, recover the mixture, then stop the pulse tube and wait till it is past 250 K before the stack: safe, and slow"]},
			{"key": "demolish", "name": ["开加热器快速回温", "HEATERS ON"], "minutes": [0, 0], "lo": 0.0, "hi": 1.0,
				"risks": ["同样的顺序，停脉管后开加热器，回温快几倍；混合室还没过 30 K 就开，芯片当场裂", "The same order, heaters on once the pulse tube stops: several times quicker; on before the mixing chamber is past 30 K and the chip cracks"]},
		],
	},
	"jd38": {
		"name": ["快递箱", "THE EXPRESS BOXES"],
		"units": ["两个快递箱 + 邮袋", "TWO EXPRESS BOXES + THE MAIL"],
		"groups": [{"name": ["快递", "EXPRESS"], "tags": ["BOX-1", "BOX-2", "MAIL"]}],
		"dv": {"dv_rail": "rail_cut", "dv_drop": "rail_drop"},
		"methods": [
			{"key": "careful", "name": ["解锁沿轨道滑出", "RELEASE THEM DOWN THE RAILS"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先开货舱门和船尾门，再拨轨道锁 LK-U、LK-L：箱子顺着轨道自己滑出来；门没开就解锁，箱子撞门受伤", "Open the hold door and the stern door, then the rail locks LK-U, LK-L: the boxes run out on their rails; released into a shut door they dent"]},
			{"key": "demolish", "name": ["切开舱壁直接抓", "CUT IN AND GRAB"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["扳手拧不开轨道锁，只能连轨道一起切下来：快，但箱子被扯伤", "The wrench can't undo a rail lock: you cut the rail with the box on it, quick, but the box is wrenched"]},
		],
	},
	"h22": {
		"name": ["拖头与液压站", "THE TOW HEADS AND THE HYDRAULICS"],
		"units": ["上下两个拖头 + 液压站", "TWO TOW HEADS + THE HPU"],
		"groups": [
			{"name": ["拖头", "TOW HEADS"], "tags": ["TH-U", "TH-L"]},
			{"name": ["液压站", "HYDRAULICS"], "tags": ["HPU"]},
		],
		"dv": {"dv_preload": "arm_snap"},
		"methods": [
			{"key": "careful", "name": ["消磁泄压再拆", "DEGAUSS, BLEED, THEN TAKE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先断线圈电源再消磁，蓄能器泄压、拔掉拖臂的销子，最后拧下拖头；拖头 2.2 t 要吊车", "Kill the coil supply and degauss, bleed the accumulator, pull the arm pins, then unbolt the heads; 2.2 t each, crane them"]},
			{"key": "demolish", "name": ["带磁带压快拆", "STRAIGHT IN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["不消磁不泄压直接切：残磁把无人机和碎件吸过去，拖臂带压弹出，砸坏拖头", "Cut it as it is: the residual field drags the drone and loose pieces in, the arms spring out under pressure into the heads"]},
		],
	},
	"st40": {
		"name": ["主机与电子件", "THE ENGINE AND THE ELECTRONICS"],
		"units": ["主机、电池 + 驾驶舱和电子舱的电子件", "THE ENGINE, THE BATTERY + THE COCKPIT AND AVIONICS ELECTRONICS"],
		"groups": [
			{"name": ["动力", "POWER"], "tags": ["ENG", "BAT-R"]},
			{"name": ["电子件", "ELECTRONICS"], "tags": ["CON-P", "RDR", "TLM", "AV-P", "INV", "GYRO", "DAQ", "NOSE-S"]},
		],
		"dv": {"dv_fume": "fume", "dv_glass_fog": "fume"},
		"methods": [
			{"key": "careful", "name": ["抽空或拧螺栓拆壳", "VACUUM OR UNBOLT"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先把舱室抽到真空再切碳纤维壳，或者用维护工具拧下壳板：都不冒烟", "Pump a room down before you cut its carbon skin, or unbolt the panels: no smoke either way"]},
			{"key": "demolish", "name": ["带气直接切壳", "CUT THE SKIN WITH AIR IN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["舱里还有空气就切碳纤维壳：快，但毒烟把电子件熏得掉价，玻璃也会起雾", "Cut the carbon skin with air in the room: quick, but the smoke spoils the electronics and fogs the glass"]},
		],
	},
	"my48": {
		"name": ["主人的收藏", "THE OWNER'S THINGS"],
		"units": ["保险箱、钢琴、酒墙、水疗、吧台、艺术品", "THE SAFE, THE PIANO, THE WINE WALL, THE SPA, THE BAR, THE ART"],
		"groups": [{"name": ["收藏", "COLLECTION"], "tags": ["SAFE", "PIANO", "WINE", "SPA", "BAR", "ART"]}],
		"dv": {"dv_fire": "o2_flash", "dv_glass": "glass_craze"},
		"methods": [
			{"key": "careful", "name": ["先抽走富氧空气", "THE RICH AIR OUT FIRST"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["先撬开卡死的气口 G-S，把主舱的富氧空气抽走再动刀；玻璃拧螺栓拆，别在旁边切", "Free the jammed port G-S and pump the oxygen-rich air out before any cut; unbolt the glass, never cut beside it"]},
			{"key": "demolish", "name": ["带气快拆", "STRAIGHT IN"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["富氧空气还在就切：闪燃烧遍主舱，收藏被烧坏，玻璃也会龟裂", "Cut with the rich air in: a flash fire through the saloon scorches the collection and crazes the glass"]},
		],
	},
	"ev55": {
		"name": ["观测仪器", "THE INSTRUMENTS"],
		"units": ["日冕仪、两台光谱仪、仪器计算机", "THE CORONAGRAPH, TWO SPECTROMETERS, THE INSTRUMENT COMPUTER"],
		"groups": [{"name": ["观测仪器", "INSTRUMENTS"], "tags": ["CORO", "SPEC-1", "SPEC-2", "ICP"]}],
		"dv": {"dv_heat_spoil": "heat_spoil"},
		"methods": [
			{"key": "careful", "name": ["接冷却回路等降温", "COOLING LOOP, THEN TAKE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["接上船坞冷却回路 COOL-S，等仪器舱降到 150°C 以下再取：仪器完好，要等", "Plug in the berth's cooling loop (COOL-S) and wait for the instrument room below 150 °C: whole, and a wait"]},
			{"key": "demolish", "name": ["边等边拆", "WORK WHILE IT COOLS"], "minutes": [0, 0], "lo": 0.0, "hi": 0.6,
				"risks": ["先拆已经冷下来的区，热区边等边拆：快，但从 150°C 以上的区取出的设备热损，热瓦切开会碎", "Strip the cool zones first and the hot ones as they come: quick, but units out of a zone over 150 °C are heat-damaged, hot tiles shatter"]},
		],
	},
	"ih55": {
		"name": ["气囊下的设备", "WHAT THE BAGS COVER"],
		"units": ["环控、气泵、控制台、电池、电容、配电板、两个储物柜", "ENV CONTROL, BAG PUMP, CONSOLE, BATTERY, CAPACITOR, PANEL, TWO LOCKERS"],
		"groups": [{"name": ["气囊下的设备", "UNDER THE BAGS"], "tags": ["ENV-1", "GAS-P", "CON-S", "BAT-S", "CAP-S", "PNL-1", "STORE-1", "STORE-2"]}],
		"dv": {"dv_bag_rip": "bag_rip", "dv_strap_whip": "strap_whip"},
		"methods": [
			{"key": "careful", "name": ["放气松带再拆", "LET THEM DOWN, SLACKEN, TAKE"], "minutes": [0, 0], "lo": 0.9, "hi": 1.0,
				"risks": ["四个气囊各自接 BV 口放气，折叠贴到脊梁上，再拨 TN 松开张紧器，最后拆设备", "Let each bag down at its BV port till it folds onto the spine, the tensioners (TN) off, then the units"]},
			{"key": "demolish", "name": ["直接割破气囊", "SLASH THE BAGS"], "minutes": [0, 0], "lo": 0.0, "hi": 0.0,
				"risks": ["带气割气囊：快，但气囊当场撕开塌下来砸坏下面的设备，绷着的绑带也会甩", "Cut a bag with gas in it: quick, but it rips and comes down on the units, and a taut strap whips"]},
		],
	},
	# 94 号 (user 2026-10-28: segment by segment against the whole mirror; the whole is 32.6 t, the
	# crane takes 12 t: a backplane at a time instead; the segments' state in words, no letters)
	"ob90": {
		"name": ["主镜镜片", "PRIMARY MIRROR"],
		"units": ["18 片，三圈，装在 6 块背板上", "18 SEGMENTS, THREE RINGS, ON 6 BACKPLANES"],
		"methods": [
			{"key": "pieces", "name": ["逐片取", "SEGMENT BY SEGMENT"], "minutes": [30, 45], "lo": 0.85, "hi": 1.0,
				"risks": ["没放防尘罩就在附近切，镜面会被粉尘污染；支撑器没锁就取，镜片会摔裂；不从外圈往里取，外圈会崩边", "Cut near it uncovered and dust spoils the coating; taken off unlocked a segment drops and cracks; not outer ring first and the outer edges chip"]},
			{"key": "blocks", "name": ["按背板分块吊", "A BACKPLANE AT A TIME"], "minutes": [15, 25], "lo": 0.8, "hi": 1.0, "need": "crane",
				"risks": ["先把镜筒外壳拆掉，吊车才有路把块吊出去；每块约 5.4 t；同样要放防尘罩、锁支撑器、从外圈往里切；整块磕一下，3 片一起受伤", "Strip the tube's casing first, or the crane has no way out with a block; about 5.4 t each; cover, locks and outer ring first all the same; one knock hurts three segments"]},
		],
	},
}

# what a loss was, short (on site) and long (on the board and in the review), and what to do next time
const CAUSES := {
	"cut_taut": [["带张力切断", "CUT TAUT"], ["那一角还绷着就切了帆片", "a panel cut with its corner still taut"], ["切帆片之前，先松开那一角的绞盘刹车", "Let off that corner's winch brake before you cut its film"]],
	"cut": [["切开帆片", "FILM CUT"], ["帆片被切开，成了废料", "a panel cut through, now scrap"], ["要整帆的钱就别切帆面：用收帆电机卷", "To keep the sail's worth, don't cut the film: wind it in"]],
	"spread": [["撕裂蔓延", "TEAR RAN"], ["裂口顺着绷紧的帆面跑进了旁边的帆片", "a tear ran across taut film into the next panel"], ["一看到裂口，马上松开那一角的刹车，裂口就停住", "The moment a tear starts, let off that corner's brake: it stops"]],
	"freed_taut": [["张紧时扯下", "TORN OFF TAUT"], ["帆片在张紧时被扯离帆架", "a panel pulled off while its corner was taut"], ["先松刹车再动帆片", "Slacken the corner before you move its film"]],
	"snap": [["拉索弹断", "STAY SNAPPED"], ["拉索带着张力被切断，弹断撕坏了帆片", "a stay cut under load snapped and tore its panels"], ["切拉索之前先松那一角的刹车", "Let off that corner's brake before you cut its stays"]],
	"overload": [["收卷过载", "FURL OVERLOAD"], ["那一角还绷着就开了收帆电机，卷筒过载", "the furling motor run with the corner still taut"], ["先松刹车，再开收帆电机", "Brake off first, then the furling motor"]],
	"static": [["静电击穿", "STATIC PINHOLES"], ["没接地就收卷，静电击穿了帆膜", "wound unearthed: static pinholed the film"], ["收卷前先接上左下角的接地线 GND", "Earth it at GND (bottom left) before you wind"]],
	"holes": [["碎件打孔", "HOLED"], ["飘浮的碎件打穿了帆膜", "loose pieces holed the film"], ["收卷前把帆前面飘着的碎件清走", "Clear the loose pieces off the film before you wind"]],
	"soot": [["熔渣熏黑", "SOOTED"], ["在帆附近切割，熔渣熏黑了帆膜", "cutting close by blackened the film"], ["先收帆，再切帆附近的结构", "Furl first, then cut the structure near the film"]],
	# 114 号: the last six
	"train_spring": [["后半列弹开", "TRAIN SPRANG"], ["K-4 车钩卡着弯矩就拆了，后半列弹开撕坏两边", "K-4 undone with the bend on it: the aft train sprang and tore both sides"], ["从车尾往前拆，K-4 后面的拆完再动 K-4", "Strip from the tail; K-4 only once what is aft of it is off"]],
	"drill_whip": [["钻杆甩打", "STRING WHIPPED"], ["钻杆还带着扭矩就卸，甩打砸坏了钻台", "a stand broken out with torque on: it whipped and smashed the floor"], ["先拨 TQB 把扭矩泄到 5% 以下", "Bleed the torque (TQB) under 5% first"]],
	"mud_fouled": [["泥浆喷污", "MUD BLOWOUT"], ["泥浆还有压就卸钻杆，泥浆喷出污了设备", "broken out with the mud in: it blew out and fouled the units"], ["先接 PMUD 把泥浆放掉", "Let the mud out at PMUD first"]],
	"drill_drop": [["钻杆掉落", "STANDS DROPPED"], ["顺序错了或卡瓦没卡，上面的钻杆掉了下来", "out of order or the slips open: the stands above dropped"], ["从上往下逐节卸，每节先卡上它下面的 SLIP", "From the top, each with its slips (SLIP) set under it"]],
	"wheel_loose": [["飞轮甩飞", "WHEEL THROWN"], ["飞轮还在高速转就拆，甩飞砸坏了旁边", "a wheel taken still spinning: it was thrown into what was near"], ["开冷却刹车，降到 300 rpm 以下再拆", "Cooled brakes till it is under 300 rpm"]],
	"rail_lurch": [["导轨窜动", "RAIL LURCHED"], ["张紧器没从尾往头松，导轨窜动撞坏东西", "a tensioner let off ahead of one aft of it: the rail lurched"], ["导轨张紧器从尾往头逐个松", "The tensioners from the tail to the head"]],
	"rail_whip": [["导轨甩打", "RAIL WHIPPED"], ["导轨带着 180 kN 张力被切，甩打砸坏东西", "a rail cut at 180 kN whipped"], ["先松完张紧器再切导轨", "Every tensioner off before the rail"]],
	"brake_burn": [["卡钳烧坏", "BRAKE BURNT"], ["没开冷却就刹车，卡钳烧坏了", "braked dry: the caliper burnt out"], ["先开 CV 冷却，再拨 BR 刹车", "Cooling (CV) on before the brake (BR)"]],
	"tank_burst": [["罐体爆裂", "TANK BURST"], ["低温罐压力升到爆裂（泄压阀冻住或没制冷）", "a cryo tank climbed till it burst (its valve frozen, or no cooling)"], ["制冷机一直开着，先给冻阀化冻，再抽货", "Keep the coolers on, thaw the frozen valve, then draw it"]],
	"pods_thrown": [["吊舱甩飞", "PODS THROWN"], ["还在转就切了系绳，两个吊舱被甩飞", "the tether cut still turning: both pods were thrown"], ["开冷却刹车停转，松掉 TEN 再切", "Cooled brake till it stops, TEN off, then cut"]],
	"tether_snap": [["系绳崩断", "TETHER SNAPPED"], ["系绳带着张力断开，崩伤了设备", "the tether parted under load and hurt the units"], ["停转并松掉残余张力再切系绳", "Stopped and slackened before you cut it"]],
	"tether_whip": [["系绳甩打", "TETHER WHIPPED"], ["系绳断头甩打砸坏了旁边", "a parted end whipped into what was near"], ["停转、松 TEN 后再切", "Stop it and TEN off before the cut"]],
	"brake_slip": [["刹车打滑", "BRAKE SLIPPED"], ["没开冷却就刹车，滚轮过热打滑", "braked dry: the rollers overheated and slipped"], ["先开 BRK-C 冷却再刹车", "BRK-C on before the brake"]],
	# 113 号: the third ten
	"pod_fired": [["逃生舱弹射", "POD FIRED"], ["点火电路还活着就松了发射夹，火工螺栓点火，逃生舱被弹射出去摔坏", "a launch clamp undone with the firing circuit live: the bolts fired and the pod was thrown off"], ["松夹之前先拨 ARM 断开点火电容，或拔掉引线", "Firing circuit off (ARM) or its lead pulled before the clamps"]],
	"cargo_spring": [["舱体弹出", "MODULE SPRANG"], ["居住舱还有压就松了夹，舱体弹出砸坏里面的设备", "the clamps let go with air still in the habitat: it sprang and knocked its fittings"], ["松夹之前先把居住舱抽到 20 kPa 以下", "Pump the habitat below 20 kPa before the clamps"]],
	"cargo_twist": [["舱体扭转", "MODULE TWISTED"], ["一边的夹先松多了，居住舱扭转，砸坏里面的设备", "one side's clamps let go first: the habitat twisted into its fittings"], ["按对角顺序交替松夹：HC-U1、HC-L4、HC-U4、HC-L1……", "Crosswise, one each side in turn: HC-U1, HC-L4, HC-U4, HC-L1…"]],
	"hull_torn": [["梁断船体撕开", "HULL TORN"], ["裂了的 2 号梁旁边的夹还夹着就拆了梁，船体被撕开", "the cracked beam taken with a clamp beside it still holding: it tore the hull"], ["先松 2 号梁旁边的 HC-U1、HC-L1，再拆梁", "HC-U1 and HC-L1 off before the cracked beam"]],
	"melt_short": [["融水短路", "MELTWATER SHORT"], ["融水积太多，带电的设备泡水短路", "too much meltwater stood about and shorted the live units"], ["融水积到 3 m³ 之前就从 PW 泵走", "Pump it at PW before it stands over 3 m³"]],
	"ice_drop": [["冰块掉落", "ICE DROPPED"], ["冰还没化到一半就松了鞍座，冰整块掉下来", "a saddle seat let go with most of the ice still on: it dropped"], ["冰化到一半以下再松鞍座 PH", "Melt it below half before any seat (PH) lets go"]],
	"crack_run": [["冰裂开", "ICE SPLIT"], ["裂缝两侧的鞍座还夹着就动了裂缝上的冰块，冰沿裂缝裂开", "a block on the crack moved with the seats beside it still holding: the crack ran"], ["裂缝上的冰用加热器融，别切", "Melt the blocks on the crack; never cut them"]],
	"furnace_crack": [["炉芯热裂", "CORE CRACKED"], ["炉芯还在 350°C 以上就断了冷却（或 150°C 以上吊出），热震开裂", "cooling lost over 350 °C (or lifted out over 150 °C): the core cracked"], ["换热泵 HX 一直有电，炉芯冷到 150°C 以下再动", "Keep the heat-exchange pumps (HX) powered till the core is under 150 °C"]],
	"feed_snap": [["进料臂弹出", "FEED ARM SPRANG"], ["进料臂带压上着销就拆了，弹出砸坏分选机", "the feed arm taken pinned and under pressure: it sprang into the sorter"], ["先给 ACC-F 泄压、拔销", "Bleed ACC-F and pull the pins first"]],
	"visor_snap": [["门罩弹开", "VISOR SPRANG"], ["船首门罩带压上着销就拆了，弹开砸东西", "the bow visor taken pinned and under pressure: it sprang"], ["先给 ACC-D 泄压、拔销", "Bleed ACC-D and pull the pins first"]],
	"cook_off": [["殉爆", "COOK-OFF"], ["弹药被激光烤热或撞击引爆，一发带一发连锁，设备被炸坏", "rounds heated by the beam or knocked went off, setting off the rest, and blew the units apart"], ["动刀之前先开 FLV 注水，把弹库全打湿", "Open the flood valve (FLV) and wet the magazine before any cut"]],
	"actuator": [["作动器猛甩", "RAM JERKED"], ["作动器没锁就切了控制线，猛甩砸坏东西", "a ram's line cut with it unlocked: it jerked and hit what was near"], ["切线之前先拨 LK-T 锁住作动器", "Lock the rams (LK-T) before their lines"]],
	"drone_woke": [["无人机醒来甩飞", "DRONE WOKE"], ["电池还通着就从托架上拆，无人机醒来把自己甩出去撞坏", "freed with its pack live: it woke, spun up and threw itself into things"], ["拆之前先拨 PK 断开电池隔离开关", "Pack isolator off (PK) before you free it"]],
	"lift_snap": [["升降机弹出", "LIFT SPRANG"], ["升降机带压上着销就拆了，弹出砸坏回收无人机", "the lift taken pinned and under pressure: it sprang into the recovery drone"], ["先给 ACC-G 泄压、拔销", "Bleed ACC-G and pull the pins first"]],
	# 112 号: the second ten
	"quench": [["线圈失超", "QUENCHED"], ["线圈带着储能失去冷却或动了支架，失超，能量瞬间放出，连锁到旁边的线圈", "a coil lost its cooling or a support with its energy still in: it quenched, and it ran into the coils beside it"], ["先开 DUMP 泄能、保持制冷，储能降到 5% 以下再断电、动支架", "Close the dump (DUMP) with the cooling kept on; power off and touch the supports only under 5%"]],
	"twist": [["船体扭曲", "HULL TWISTED"], ["没撑船体就先拆了一边的引擎舱，重量压在另一边，船体扭曲", "one pod off with the support not set: the hull twisted under the other"], ["先拨 SUP 撑住船体，或者两台引擎舱一起拆", "Set the support (SUP) first, or take both pods together"]],
	"winch_snap": [["绞车弹出", "WINCH SPRANG"], ["绞车和拖钳还带压上着销就拆了，弹出砸坏东西", "the winch and the jaws taken pinned and under pressure: they sprang"], ["先给蓄能器泄压、拔掉 WB 和 JL 销子", "Bleed the accumulators and pull the WB and JL pins first"]],
	"rupture": [["罐体爆裂", "TANK RUPTURED"], ["低温罐升压到泄压阀放不掉，罐体爆裂", "a cryo tank rose past what its relief valve could let go and burst"], ["冷机一直开着，先把 LNG 抽走再断电", "Keep the chillers running and draw the LNG off before the power"]],
	"bio": [["生物污染", "CONTAMINATED"], ["隔离舱的污染空气扩散到干净舱，里面的设备要消毒，掉 1/4", "the isolation rooms' air reached a clean room: its equipment needs decontaminating, a quarter off"], ["隔离舱先用带滤网的回收软管抽空，生物危险品先封存，再开门", "Pump the isolation rooms out through the filter and seal the biohazards before any door opens"]],
	"spill": [["冷却液洒出", "SPILT"], ["机柜带着冷却液被吊出，液体洒了一地", "a rack lifted out with its tank still full: the fluid spilt"], ["吊机柜之前，先从它的 PT 口把罐抽干", "Drain a rack's tank at its PT port before you lift it"]],
	"short": [["短路", "SHORTED"], ["旁边机柜洒出的冷却液让这一排短路", "fluid spilt from the next rack shorted this one"], ["每个机柜都先抽干再吊", "Drain every rack before you lift any"]],
	"fish": [["鱼死了", "FISH LOST"], ["水球炸散，鱼缸里的鱼全死了", "the ball burst and the fish died"], ["先从 PW 口抽水，水球缩到 12% 以下再动网罩", "Pump the ball down at PW below 12% before the net"]],
	"soak": [["泡水", "SOAKED"], ["水球炸散，舱里的电气被泡坏", "the ball burst and soaked the room's electrics"], ["先抽水，再动网罩和支架", "Pump it down before the net or its frame"]],
	"core_crack": [["堆芯热裂", "CORE CRACKED"], ["堆芯还没冷下来就断了冷却或吊出，热震开裂", "the core lost its cooling or came out still hot: it cracked"], ["冷却泵一直有电，堆芯冷到 60°C 以下再动", "Keep the coolant pumps powered till the core is under 60 °C"]],
	"drum_slip": [["控制鼓滑出", "DRUM SLIPPED"], ["控制鼓没锁就吊堆芯，控制鼓滑出，一阵辐射", "the core lifted with a drum unlocked: the drum slipped, a burst of dose"], ["吊堆芯之前，四个 DL 锁全部拨上", "Throw all four drum locks (DL) before the core"]],
	"buckle": [["罐体抽瘪", "TANK BUCKLED"], ["关了增压又放空了气垫，抽液时罐里成了真空，罐体被压瘪", "pressurisation shut and the ullage vented: drawing it pulled a vacuum and it buckled"], ["抽推进剂时增压阀 PV 一直开着，TV 和 NP 口别放空", "Keep the pressurisation (PV) open while drawing; never vent TV or NP"]],
	"pump_dry": [["泵干转", "PUMP RAN DRY"], ["总管抽空了主泵还在抽，干转受损", "the pump kept drawing a dry manifold and was damaged"], ["总管抽空就拔掉 PR 的软管", "Take the hose off PR once the manifold is dry"]],
	"thaw": [["疫苗解冻", "THAWED"], ["冷舱断冷升到 −5°C 以上，疫苗解冻，只剩 45% 价值", "a cold hold warmed past −5 °C: the vaccines thawed, 45% of their worth left"], ["先接 COLD-X 临时制冷，或者让冷机一直有电，货卸完再断电", "Plug in COLD-X or keep the chillers powered till the cargo is out"]],
	# 111 号: the ten small ships
	"qpu_shock": [["加热过早，芯片裂", "HEATED TOO SOON"], ["混合室还没过 30 K 就开了加热器，量子芯片热震开裂", "the heaters on before the mixing chamber passed 30 K: the chip cracked"], ["停脉管后先等混合室回到 30 K 以上，再开加热器 HEAT", "After the pulse tube stops, wait for the mixing chamber past 30 K before HEAT"]],
	"qpu_brittle": [["低温时动了冷台", "STACK TOUCHED COLD"], ["混合室还在 250 K 以下就切开或拆下冷台，芯片脆裂", "the stack cut or freed under 250 K: the chip cracked"], ["混合室回到 250 K 以上再拆冷台", "Wait for the mixing chamber past 250 K before the stack"]],
	"qpu_vibration": [["震伤芯片", "SHAKEN"], ["隔振台没锁，附近切割的震动传到芯片", "the isolation table floating, a cut close by shook the chip"], ["切制冷机附近之前，先拨 VI-LOCK 锁住隔振台", "Lock the isolation table (VI-LOCK) before you cut near the fridge"]],
	"mix_boil": [["混合气沸散", "MIXTURE BOILED OFF"], ["混合气没回收就停了脉管，混合气沸散，冷台受损", "the pulse tube stopped with the mixture still in: it boiled off and hurt the stages"], ["先停循环 CIRC，接 G-MIX 把混合气抽到 20 kPa 以下，再停脉管 PT", "Circulation (CIRC) off, recover the mixture at G-MIX below 20 kPa, then the pulse tube (PT)"]],
	"rail_cut": [["连轨道切下", "CUT OFF ITS RAIL"], ["箱子还锁在轨道上就把轨道切了，箱子被扯伤", "a rail cut with its box still locked on: the box was wrenched"], ["开门、拨轨道锁，让箱子自己沿轨道滑出", "Open the doors and throw the rail lock: the box runs out on its own"]],
	"rail_drop": [["整组砸落", "DROPPED"], ["箱子还锁着就动了吊挂，整组砸下来", "the hangers taken with the boxes still locked: the set came down"], ["先解轨道锁，再动吊挂", "Release the rails before the hangers"]],
	"arm_snap": [["拖臂弹出", "ARM SPRANG"], ["拖臂还带着液压和销子就拆了枢轴，臂弹出砸坏拖头", "a pivot taken with the arm still pinned and under pressure: it sprang into the head"], ["先给蓄能器泄压、拔掉 PIN 销子，再拆拖臂", "Bleed the accumulator and pull the pins before the arm"]],
	"fume": [["毒烟熏坏", "SMOKED"], ["舱里有空气时切碳纤维壳，毒烟把电子件熏得掉价", "the carbon skin cut with air in the room: the smoke spoiled the electronics"], ["切壳之前先把舱室抽到真空，或者用维护工具拧下壳板", "Pump the room down before you cut the skin, or unbolt the panels"]],
	"o2_flash": [["富氧闪燃", "FLASH FIRE"], ["主舱的富氧空气还在就切，闪燃把收藏烧坏", "cut with the oxygen-rich air still in: a flash fire scorched the collection"], ["先撬开 G-S，把主舱的富氧空气抽走再动刀", "Free G-S and pump the rich air out before any cut"]],
	"glass_craze": [["玻璃龟裂", "GLASS CRAZED"], ["在精密玻璃旁边切割，玻璃被烤裂", "cutting beside the glazing crazed it"], ["玻璃用维护工具拧下来，别在旁边切", "Unbolt the glass; never cut beside it"]],
	"heat_spoil": [["热损", "HEAT-DAMAGED"], ["从 150°C 以上的区取出设备，热损掉价", "a unit taken out of a zone over 150 °C was heat-damaged"], ["接上冷却回路 COOL-S，等那一区降到 150°C 以下再取", "Plug in the cooling loop (COOL-S) and wait for the zone below 150 °C"]],
	"bag_rip": [["气囊塌下", "BAG CAME DOWN"], ["带气割破气囊，气囊撕开塌下来砸坏了设备", "a bag cut with gas in it ripped and came down on the units"], ["先接 BV 口把气囊放瘪，再切", "Let the bag down at its BV port before you cut"]],
	"strap_whip": [["绑带甩伤", "STRAP WHIPPED"], ["张紧器还绷着就切了绑带，甩伤了设备", "a strap cut with its tensioner taut whipped into the units"], ["先拨 TN 松开张紧器，再切绑带", "Tensioner (TN) off before you cut its straps"]],
	# OB-90's mirror
	"dust": [["粉尘污染", "DUSTED"], ["在镜子附近切割，金属粉尘落在没盖住的镜面上", "cutting close by dusted the uncovered coating"], ["切主镜附近的结构之前，先放下防尘罩 CVR", "Run the dust cover (CVR) down before you cut near the mirror"]],
	"drop": [["摔裂", "DROPPED"], ["支撑器没锁就取下镜片，镜片掉出镜座摔裂", "taken off unlocked, the segment dropped out of its seat and cracked"], ["取镜片之前，先给控制柜 MCC 供电，合上三圈支撑器锁", "Power the mirror cabinet (MCC) and lock all three rings before you take a segment"]],
	"edge": [["崩边", "CHIPPED"], ["里圈先取走了，外圈镜片的边没了支撑，崩了", "an inner segment taken first: the outer one's edge lost its support and chipped"], ["从外圈往里取：先取外圈", "Outer ring first, then inwards"]],
	# LC-140's small ship
	"lurch": [["撬起撞门", "LURCHED"], ["船头侧的锁先开了、船尾还锁着：小船撬起撞上船首门，溢价砍半、设备磕坏", "a bow-side lock let go with one aft still holding: it lurched into the bow door, half the premium gone, its fittings knocked"], ["托架锁从船尾往船首依次解：CL-1 → CL-4", "The cradle locks from the stern forward: CL-1 → CL-4"]],
	"not_whole": [["船壳切开", "HULL CUT"], ["切到或拆下了小船的船壳，整船溢价没了", "its hull cut or taken off: no longer whole, the premium gone"], ["小船的船壳一刀都别碰：只切载舰的结构", "Never touch its hull: cut only the carrier's structure"]],
	# CF-90's wall
	"kink": [["箱梁折弯", "WALL KINKED"], ["外侧还满着就卸空了里侧一列，箱梁折弯，外侧的箱被砸坏", "an inner bay emptied with the bays beyond it full: the wall kinked, the boxes beyond it damaged"], ["从两端往中间卸；要先卸里侧，先用撑杆顶住外侧", "From the ends inwards; to take an inner bay first, prop the outer bays"]],
	"sag": [["塌箱", "STACK SAGGED"], ["从一列下面先抽了箱，上面的箱压下来受损", "a box taken from under others: the stack above sagged onto it"], ["每列从上往下卸", "Each bay from the top down"]],
	"rod_snap": [["拉杆弹断", "ROD WHIPPED"], ["拉杆还绷着就切了，弹开砸坏了箱子", "a rod cut still tight whipped into the boxes"], ["切拉杆之前先松它的花篮螺丝", "Slacken a rod's turnbuckle before you cut it"]],
	# M-14's hopper and line
	"ore_spill": [["细矿洒落", "FINES LOST"], ["矿仓在料位线下开了口，细矿洒了出去，一分不算", "the hopper opened below the heap: the fines poured out, unpaid"], ["切矿仓壁之前，先开放料门把矿放到破口以下", "Before you cut a hopper wall, run the ore out through the gates below it"]],
	"hopper_tear": [["矿仓撕裂", "HOPPER TORN"], ["矿还剩一半以上就撬开放料门，一边倾泻撕裂了矿仓焊缝", "a gate forced with the hopper half full: it all went one way and tore the welds"], ["放料门用开关正常打开；要撬门，先把矿放到一半以下", "Open the gates by their switches; to force one, run the ore below half first"]],
	"belt_snap": [["皮带弹回", "BELT WHIPPED"], ["带着张力切断皮带，皮带弹回打坏了设备", "the belt cut under tension whipped back into the line"], ["先断皮带电机、松张紧螺栓 TEN-1，再拆皮带", "Stop the belt motor and slacken TEN-1 before you take the belt off"]],
	# GR-7's units
	"eq_cut": [["切坏", "CUT UP"], ["设备被激光切穿，成了废料", "the beam went through a unit: scrap now"], ["看清设备在哪：沿它四周的焊点和螺栓切，别穿过设备本体", "See where the unit sits: cut round it at its welds and bolts, never through it"]],
	"eq_impact": [["撞伤", "KNOCKED"], ["设备在搬运中撞上了东西", "a unit knocked into something on the way"], ["搬设备时放慢，绕开船体和别的碎件", "Go slow with a unit and keep it clear of the hull and loose pieces"]],
	"burst": [["气瓶爆裂", "VESSEL BURST"], ["带压的气瓶被切开，爆裂波及了旁边的设备", "a vessel under pressure cut open: its burst hit the units round it"], ["切之前先把气瓶泄压放空", "Vent the vessels before you cut near them"]],
	"blast": [["爆燃波及", "BLAST"], ["危险品爆燃，波及了旁边的设备", "dangerous goods went up and hit the units round them"], ["推进剂舱先放空、通风，再动刀", "Drain and vent the propellant before you cut"]],
	"fire": [["起火烧坏", "FIRE"], ["切开带油的管子起火，烧坏了设备", "a pipe cut wet caught fire and burnt the units"], ["切燃料管之前先关阀、抽空", "Shut and drain a fuel line before you cut it"]],
	"impact": [["磕伤", "KNOCKED"], ["镜片在搬运中撞上了东西", "a segment knocked into something on the way"], ["镜片很脆：抓着走时放慢，绕开船体", "The glass is brittle: go slow with it and keep clear of the hull"]],
}

# GR-7 and the like: the game's own losses on a unit, by what they were
# 112 号: a loss that is this asset's: on one of its units, or a code the ship books elsewhere (CL-104's
# thaw against the hold) and counts for its asset all the same
static func _mine(g, tags: Array, d) -> bool:
	if _dv(g, str(d[0])) == "":
		return false
	return tags.has(str(d[1])) or (spec(g).get("dv_any", []) as Array).has(str(d[0]))


# 112 号: a cargo that is a fluid (FR-26's LNG, VT-80's propellant): what it is worth whole, now
# (what is aboard or came in), and in hand (what the hoses took in, as the books pay it)
static func _fluid(g) -> Dictionary:
	var fd: Dictionary = spec(g).get("fluid", {})
	if fd.is_empty() or g.sys == null:
		return {}
	# 113 号: one kind or several (FL-116's three media), each at its own price
	var kinds: Array = fd.f if fd.f is Array else [fd.f]
	var val := 0.0
	var now := 0.0
	var got := 0.0
	var left_v := 0.0
	var rec_v := 0.0
	for f in kinds:
		var fv: float = float(g.sys.cfg.get("fluids", {}).get("value", {}).get(str(f), 0.0))
		var f0: float = float(g.sys.fluid0.get(str(f), 0.0))
		if f0 <= 0.0:
			continue
		var left := 0.0
		for k in g.sys.fvol:
			if str(g.sys.fvol[k].fluid) == str(f):
				left += float(g.sys.fvol[k].amount)
		# IC-120: the ice not yet melted is the water still aboard
		if fd.get("ice", false) and g.get("ice") != null and g.ice.active():
			left += g.ice.left_fraction() * f0
		var rec: float = float(g.sys.fluid_rec.get(str(f), 0.0))
		val += fv
		now += fv * clampf((left + rec) / f0, 0.0, 1.0)
		got += fv * clampf(rec / f0, 0.0, 1.0)
		left_v += fv * clampf(left / f0, 0.0, 1.0)
		rec_v += fv * clampf(rec / f0, 0.0, 1.0)
	if val <= 0.0:
		return {}
	return {"name": _t(fd.name), "full": val, "now": now, "got": got, "left": left_v / val, "rec": rec_v / val}


# 111 号: a ship's own reading of a loss code (H-22's arm springing is not M-14's belt), else the common one
static func _dv(g, code: String) -> String:
	return str(spec(g).get("dv", {}).get(code, EQUIP_DV.get(code, "")))


const EQUIP_DV := {"dv_cut": "eq_cut", "dv_impact": "eq_impact", "dv_fall": "eq_impact", "dv_snap": "eq_impact", "dv_tear": "eq_impact", "dv_burst": "burst", "dv_blowout": "burst", "dv_blast": "blast", "dv_fire": "fire", "dv_ore_spill": "ore_spill", "dv_preload": "belt_snap", "dv_kink": "kink", "dv_sag": "sag", "dv_rod_snap": "rod_snap"}
const MIRROR_DV := {"dv_mirror_dust": "dust", "dv_mirror_drop": "drop", "dv_mirror_edge": "edge", "dv_impact": "impact"}
const RING_NAMES := {3: ["外圈", "OUTER"], 2: ["中圈", "MIDDLE"], 1: ["内圈", "INNER"]}


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


static func _t(pair) -> String:
	return str(pair[0] if Txt.zh else pair[1])


static func cause_short(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k]])[0])


static func cause_long(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k], [k, k]])[1])


static func advice(k: String) -> String:
	return _t(CAUSES.get(k, [[k, k], [k, k], ["", ""]])[2])


static func ship_key(g) -> String:
	return str(g.ship.get("id", g.ship_id)) if g != null else ""


static func has(g) -> bool:
	match ship_key(g):
		"sa200":
			return g.sail != null and g.sail.active()
		"ob90":
			return g.optics != null and g.optics.active()
		"m14":
			return g.ore != null and g.ore.active()
		"cf90":
			return g.boxbeam != null and g.boxbeam.active()
		"lc140":
			return g.nested != null and g.nested.active()
		"gr7":
			for gr in SHIPS.gr7.groups:
				for t in gr.tags:
					if _unit(g, str(t)) != null:
						return true
		_:
			# 111 号: a ship of units only — it has its asset while any of them is aboard
			for gr in spec(g).get("groups", []):
				for t in gr.tags:
					if _unit(g, str(t)) != null:
						return true
	return false


static func spec(g) -> Dictionary:
	return SHIPS.get(ship_key(g), {})


# ---------------------------------------------------------------- the contract card

static func card(g) -> Dictionary:
	if not has(g):
		return {}
	var sp := spec(g)
	var f := full(g)
	var methods: Array = []
	for m in sp.methods:
		var lo := f * float(m.get("lo", 0.0))
		var hi := f * float(m.get("hi", 0.0))
		var mins: Array = m.minutes
		if m.key == "scrap":
			lo = scrap_worth(g)
			hi = lo
		# measured: what the salvage bot really got and took, both ways (95 号)
		var run: Dictionary = BOT_RUNS.get(ship_key(g), {}).get(str(m.key), {})
		if not run.is_empty():
			lo = float(run.lo)
			hi = float(run.hi)
			mins = run.minutes
		var need := ""
		if str(m.get("need", "")) == "crane":
			need = w("船坞已有吊车", "THE BERTH HAS ITS CRANE") if g.has_upgrade("crane") else w("需要吊车：船坞还没修好吊车", "NEEDS THE CRANE: NOT BUILT YET")
		var risks := _t(m.risks)
		if run.has("note"):
			risks += w("；", "; ") + _t(run.note)
		var method_name := _t(m.name)
		if Txt.zh and str(g.job.get("reg", "")) == "H-38" and ship_key(g) == "h22":
			if str(m.key) == "careful":
				method_name = "方案 A · 消磁泄压后拆解"
				risks = "先断开供电线路并消磁，给液压系统泄压，再拆下拖臂销轴。最后拆下拖头进行回收。每个拖头约 2.2 吨，需要吊车。未彻底断电或泄压可能发生意外。"
			elif str(m.key) == "demolish":
				method_name = "方案 B · 带磁带压快拆"
				risks = "跳过消磁和泄压，直接拆除连接结构。残留磁力可能吸走附近的无人机和碎件；液压系统仍有压力，拖臂可能突然弹出，损坏拖头。"
				if run.has("note"):
					risks += "；" + _t(run.note)
		methods.append({"key": m.key, "name": method_name, "lo": lo, "hi": hi, "minutes": mins, "risks": risks, "need": need})
	return {"name": _t(sp.name), "units": _t(sp.units), "full": f, "methods": methods}


static func full(g) -> float:
	match ship_key(g):
		"sa200":
			return g.sail.asset_full(g.ship)
		"lc140":
			return float(g.nested.cfg.get("bonus", 0.0)) + _small_parts(g, false)
		"cf90":
			var sum := 0.0
			for t in _units(g):
				var p = _unit(g, str(t))
				if p != null:
					sum += float(p.value)
			return sum
		"gr7", "m14", "tug", "pod", "s09", "qc30", "jd38", "h22", "st40", "my48", "ev55", "ih55":
			var sum := ore_full(g) if spec(g).get("ore", false) else 0.0
			for t in _units(g):
				var p = _unit(g, str(t))
				if p != null:
					sum += float(p.value)
			return sum
		"ob90":
			var sum := 0.0
			for pd in g.ship.get("pieces", []):
				if g.optics.cfg.get("segments", {}).has(str(pd.get("tag", ""))):
					sum += float(pd.get("value", 0.0)) * clampf(float(pd.get("cond", 1.0)), 0.0, 1.0)
			return sum
		_:
			# 112 号: a ship of units (and maybe a fluid cargo)
			var sum2: float = float(_fluid(g).get("full", 0.0))
			for t in _units(g):
				var p = _unit(g, str(t))
				if p != null:
					sum2 += float(p.value)
			return sum2
	return 0.0


static func scrap_worth(g) -> float:
	var sum := 0.0
	if ship_key(g) == "sa200":
		for t in g.sail.cfg.get("panels", {}):
			var p = g.world.tag(str(t))
			if p != null and not p.gone:
				sum += g.world.scrap_value(p)
	return sum


# ---------------------------------------------------------------- the board on the job

static func board(g) -> Dictionary:
	if not has(g):
		return {}
	match ship_key(g):
		"sa200":
			return _sail_board(g)
		"ob90":
			return _mirror_board(g)
		"gr7", "m14", "tug", "pod", "s09", "qc30", "jd38", "h22", "st40", "my48", "ev55", "ih55":
			return _equip_board(g)
		"cf90":
			return _box_board(g)
		"lc140":
			return _small_board(g)
		_:
			if spec(g).has("groups"):
				return _equip_board(g)
	return {}


static func _sail_board(g) -> Dictionary:
	var s = g.sail
	var rows: Array = []
	for q in s.cfg.get("quads", {}):
		var st: Dictionary = s.corner_state(q)
		var bits: Array = []
		if st.done:
			bits.append(w("已成卷", "ROLLED"))
		else:
			bits.append(w("绷紧", "TAUT") if st.taut else w("已松", "SLACK"))
			if st.winding:
				bits.append(w("收卷中 %d/%d", "WINDING %d/%d") % [st.k, st.n])
			elif st.k > 0:
				bits.append(w("已卷 %d/%d", "WOUND %d/%d") % [st.k, st.n])
		if st.torn > 0:
			bits.append(w("撕裂 %d 片", "%d TORN") % st.torn)
		rows.append({"name": s.quad_name(q), "text": " · ".join(bits), "right": "%s %s" % [s.grade_letter(st.grade), Pal.money(st.worth)],
			"grade": st.grade, "alert": st.taut and not st.done, "done": st.done,
			"fix": w("拨 %s 松开绞盘刹车再收卷", "%s off to slacken it before winding") % str(s.cfg.get("quads", {}).get(q, ""))})
	var recent: Array = []
	for i in range(s.events.size() - 1, maxi(-1, s.events.size() - 4), -1):
		var e: Dictionary = s.events[i]
		recent.append({"text": "%s · %s" % [s.quad_name(str(e.q)), cause_short(str(e.k))], "money": float(e.money)})
	var warn: Array = []
	if not s.grounded():
		warn.append(w("未接地：拨 %s 接地，否则收卷会被静电击穿", "NOT EARTHED: %s ON, OR WINDING PINHOLES") % str(s.cfg.get("ground", "")))
	return {"name": _t(spec(g).name), "worth": s.worth_now(), "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# a segment's state in a word: the worst that happened to it
static func mirror_state(g, tag: String) -> String:
	var p = g.world.tag(tag)
	var worst := ""
	var rank := {"drop": 4, "edge": 3, "impact": 2, "dust": 1}
	for d in g.devalued:
		if str(d[1]) == tag and MIRROR_DV.has(str(d[0])):
			var k: String = MIRROR_DV[str(d[0])]
			if worst == "" or int(rank[k]) > int(rank[worst]):
				worst = k
	if worst == "" or (p != null and p.cond >= 0.995):
		return w("完好", "WHOLE")
	return cause_short(worst)


static func _seg_worth(p) -> float:
	return float(p.value) * clampf(float(p.cond), 0.0, 1.0) if p != null else 0.0


static func _mirror_board(g) -> Dictionary:
	var op = g.optics
	var segs: Dictionary = op.cfg.get("segments", {})
	var warn: Array = []
	var left := false
	for t in segs:
		if op.on_mirror(str(t)):
			left = true
	if left and op.cover_down() < 0.5:
		warn.append(w("防尘罩没放下：拨 %s 放下，附近切割会污染镜面", "COVER UP: %s TO LOWER IT; CUTTING CLOSE BY DUSTS THE MIRROR") % str(op.cfg.get("cover", {}).get("switch", "")))
	var rows: Array = []
	# the locks, one row
	var lk: Array = []
	var any_open := false
	var sws: Array = []
	for r in [1, 2, 3]:
		var ok: bool = op.ring_locked(r)
		lk.append("%s%s" % [_t(RING_NAMES[r]), "✓" if ok else "✗"])
		if not ok and op._ring_left(r):
			any_open = true
			sws.append(str(op.cfg.get("locks", {}).get(str(r), "")))
	var live: bool = op._powered(str(op.cfg.get("mcc", "")))
	rows.append({"name": w("锁", "LOCKS"), "text": " ".join(lk), "right": w("控制柜有电", "MCC LIVE") if live else w("控制柜没电", "MCC DEAD"), "grade": 0.0 if any_open else 1.0, "alert": any_open, "done": false,
		"fix": (w("拨 %s 合锁（控制柜 %s 上）", "%s to lock (on the cabinet %s)") % ["/".join(sws), str(op.cfg.get("mcc", ""))]) if live else w("先给控制柜接电，再拨 %s 合锁", "power the cabinet, then %s to lock") % "/".join(sws)})
	var worth := 0.0
	for r in [3, 2, 1]:
		var on := 0
		var off := 0
		var hurt := 0
		var rw := 0.0
		var rf := 0.0
		for t in segs:
			if int(segs[t].ring) != r:
				continue
			var p = g.world.tag(str(t))
			if p == null:
				continue
			rf += float(p.value)
			rw += _seg_worth(p)
			if op.on_mirror(str(t)):
				on += 1
			else:
				off += 1
			if p.cond < 0.995:
				hurt += 1
		worth += rw
		var bits: Array = [w("镜上 %d", "ON %d") % on]
		if off > 0:
			bits.append(w("已取 %d", "OFF %d") % off)
		if hurt > 0:
			bits.append(w("受损 %d", "HURT %d") % hurt)
		rows.append({"name": _t(RING_NAMES[r]), "text": " · ".join(bits), "right": Pal.money(rw), "grade": rw / maxf(rf, 1.0), "alert": false, "done": on == 0})
	var recent: Array = []
	var segd: Array = g.devalued.filter(func(d): return segs.has(str(d[1])) and MIRROR_DV.has(str(d[0])))
	for i in range(segd.size() - 1, maxi(-1, segd.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(segd[i][1]), cause_short(MIRROR_DV[str(segd[i][0])])], "money": float(segd[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# ---------------------------------------------------------------- the review at the settlement

static func review(g) -> Dictionary:
	if not has(g):
		return {}
	match ship_key(g):
		"sa200":
			return _sail_review(g)
		"ob90":
			return _mirror_review(g)
		"gr7", "m14", "tug", "pod", "s09", "qc30", "jd38", "h22", "st40", "my48", "ev55", "ih55":
			return _equip_review(g)
		"cf90":
			return _box_review(g)
		"lc140":
			return _small_review(g)
		_:
			if spec(g).has("groups"):
				return _equip_review(g)
	return {}


static func _finish_review(g, f: float, rolled: float, got: float, units: Array, by: Dictionary, first: String, none_tip: String, clean_tip: String) -> Dictionary:
	var keys := by.keys()
	keys.sort_custom(func(a, b): return float(by[a].money) > float(by[b].money))
	var lost: Array = []
	for k in keys:
		lost.append({"k": k, "text": cause_long(k), "money": float(by[k].money), "n": int(by[k].n)})
	var reasons: Array = [first]
	for k in keys.slice(0, 2):
		reasons.append(w("%s：少赚 %s（%d 次）", "%s: %s less (%d times)") % [cause_long(k), Pal.money(float(by[k].money)), int(by[k].n)])
	var tip := advice(str(keys[0])) if not keys.is_empty() else (none_tip if units.is_empty() else clean_tip)
	return {"name": _t(spec(g).name), "full": f, "rolled": rolled, "got": got, "units": units, "lost": lost, "reasons": reasons.slice(0, 3), "advice": tip}


static func _sail_review(g) -> Dictionary:
	var s = g.sail
	var f := full(g)
	var units: Array = []
	var got := 0.0
	var rolled := 0.0
	var done_n := 0
	for q in s.cfg.get("quads", {}):
		var st: Dictionary = s.corner_state(q)
		if not st.done:
			continue
		done_n += 1
		var roll = g.world.tag("ROLL-" + q)
		var sent: bool = roll == null or roll.gone
		var val: float = float(st.full) * float(st.grade)
		rolled += val
		if sent:
			got += val
		units.append({"text": "%s  %s %d%%" % [s.quad_name(q), s.grade_letter(st.grade), int(round(float(st.grade) * 100.0))], "value": val,
			"sub": w("已送设备口，放上零件架", "TO THE EQUIPMENT MOUTH, ON THE PARTS RACK") if sent else w("还挂在绞盘上，按废料算", "STILL ON ITS WINCH: SCRAP")})
	var by := {}
	for e in s.events:
		var k := str(e.k)
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(e.money)
		by[k].n = int(by[k].n) + 1
	var first := ""
	if units.is_empty():
		first = w("光帆没有收卷，按废料只值约 %s；整帆收回最多值 %s", "The sail was not furled: as scrap it fetched about %s; whole, up to %s") % [Pal.money(scrap_worth(g)), Pal.money(f)]
	elif got + 1.0 >= rolled:
		first = w("收成 %d 卷帆材，值 %s（满价 %s），都已送走", "%d rolls made, worth %s (whole sail %s), all sent") % [units.size(), Pal.money(rolled), Pal.money(f)]
	else:
		first = w("收成 %d 卷帆材，值 %s（满价 %s）；只送走了 %s，挂在绞盘上的按废料算", "%d rolls made, worth %s (whole sail %s); only %s sent, the rest on the winches counts as scrap") % [units.size(), Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("还有角没收：四个角都收完，光帆才值满价", "Corners left unfurled: all four rolled is the full price") if done_n < s.cfg.get("quads", {}).size() else w("干净利落。下次可以同时开两个角的收帆电机，省时间", "Clean work. Next time run two corners' motors at once to save time")
	return _finish_review(g, f, rolled, got, units, by, first, w("下次试试整帆收卷：先接地，松开四个角的刹车，再开收帆电机", "Next time furl it: earth it, let the four brakes off, then the furling motors"), clean)


static func _mirror_review(g) -> Dictionary:
	var op = g.optics
	var segs: Dictionary = op.cfg.get("segments", {})
	var f := full(g)
	# the segments by their state: how many, what they are worth, how many sent
	var groups := {}
	var order: Array = []
	var rolled := 0.0
	var got := 0.0
	for t in segs:
		var p = g.world.tag(str(t))
		if p == null:
			continue
		var word := mirror_state(g, str(t))
		if not groups.has(word):
			groups[word] = {"n": 0, "value": 0.0, "sent": 0}
			order.append(word)
		var v := _seg_worth(p)
		groups[word].n = int(groups[word].n) + 1
		groups[word].value = float(groups[word].value) + v
		rolled += v
		# gone from the berth: into a mouth
		if p.gone:
			groups[word].sent = int(groups[word].sent) + 1
			got += v
	var units: Array = []
	for word in order:
		var gr: Dictionary = groups[word]
		units.append({"text": w("%s %d 片", "%s · %d") % [word, gr.n], "value": float(gr.value),
			"sub": w("已送走 %d 片，船上 %d 片", "%d SENT, %d ABOARD") % [gr.sent, int(gr.n) - int(gr.sent)]})
	var by := {}
	for d in g.devalued:
		if not segs.has(str(d[1])) or not MIRROR_DV.has(str(d[0])):
			continue
		var k: String = MIRROR_DV[str(d[0])]
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	var first := w("镜片现值 %s（满价 %s）；已送走 %s", "The segments are worth %s (whole %s); %s sent") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("干净利落。下次可以试试按背板分块吊，省时间", "Clean work. Next time try a backplane at a time: quicker") if got > 0.0 else w("镜片还在船上：取下来送设备口才算钱", "The segments are still aboard: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# ---------------------------------------------------------------- 95 号: a set of units (GR-7)

# the asset's units, all groups
static func _units(g) -> Array:
	var out: Array = []
	for gr in spec(g).get("groups", []):
		out.append_array(gr.tags)
	if spec(g).get("ore", false):
		out.append("ORE")
	if spec(g).get("boxes", false):
		for bay in g.boxbeam.cfg.bays:
			out.append_array(bay)
	if spec(g).get("nested", false):
		out.append_array(g.nested.cfg.get("pieces", []))
	return out


# a unit by its tag, still found once a mouth has taken it (the world forgets gone pieces)
static func _unit(g, t: String):
	var live = g.world.tag(t)
	if not g.has_meta("ca_units"):
		g.set_meta("ca_units", {})
	var memo: Dictionary = g.get_meta("ca_units")
	if live != null:
		memo[t] = live
		return live
	return memo.get(t)


# what a unit is worth now: nothing once cut, or once it went into the furnace
static func _unit_worth(p) -> float:
	if p == null or not p.intact or (p.gone and p.into != "equip"):
		return 0.0
	return float(p.value) * clampf(float(p.cond), 0.0, 1.0)


# a unit's state in a word: gone into a mouth, cut up, hurt (and how much), whole
static func unit_state(g, p) -> String:
	if p == null:
		return ""
	if not p.intact:
		return cause_short("eq_cut")
	if p.gone:
		return w("已送设备口", "SENT") if p.into == "equip" else w("进了熔炉", "IN THE FURNACE")
	if p.cond >= 0.995:
		return w("完好", "WHOLE")
	return w("受损 %d%%", "HURT %d%%") % int(round((1.0 - float(p.cond)) * 100.0))


static func _equip_board(g) -> Dictionary:
	var rows: Array = []
	var worth := 0.0
	var warn: Array = []
	if spec(g).get("ore", false):
		worth += _ore_board(g, rows, warn)
	var fl := _fluid(g)
	if not fl.is_empty():
		worth += float(fl.now)
		var lost: float = 1.0 - float(fl.left) - float(fl.rec)
		rows.append({"name": str(fl.name), "text": w("已抽 %d%% · 船上 %d%%", "%d%% IN · %d%% ABOARD") % [int(round(float(fl.rec) * 100.0)), int(round(float(fl.left) * 100.0))] + (w(" · 损失 %d%%", " · %d%% LOST") % int(round(lost * 100.0)) if lost > 0.02 else ""),
			"right": Pal.money(float(fl.now)), "grade": float(fl.now) / maxf(float(fl.full), 1.0), "alert": lost > 0.02, "done": float(fl.left) <= 0.01})
	for gr in spec(g).groups:
		for t in gr.tags:
			var p = _unit(g, str(t))
			if p == null:
				continue
			var v := _unit_worth(p)
			worth += v
			rows.append({"name": str(t), "text": "%s · %s" % [_t(gr.name), unit_state(g, p)], "right": Pal.money(v),
				"grade": v / maxf(float(p.value), 1.0), "alert": not p.intact or p.cond < 0.9, "done": p.gone})
	var tags := _units(g)
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return _mine(g, tags, d))
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short(_dv(g, str(mine[i][0])))], "money": float(mine[i][2])})
	_ship_warn(g, warn)
	if _ship_live(g):
		if ship_key(g) in POWER_LAST:
			warn.append(w("船还没安全：先泄压、放空再动刀；电要留到最后断", "NOT SAFE YET: VENT AND DRAIN BEFORE YOU CUT; THE POWER GOES LAST"))
		else:
			warn.append(w("船还没安全：先断电、泄压、放空再动刀", "NOT SAFE YET: POWER OFF, VENT, DRAIN BEFORE YOU CUT"))
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


const LIVE_KPA := 5.0
# 112 号: ships whose power must stay on till their asset is safe (the coils' cooling, the chillers,
# the cold holds, the propellant pump, the core's coolant pumps)
const POWER_LAST := ["fx70", "fr26", "cl104", "vt80", "nr95", "mf126", "ic120", "mt140", "md160", "hg170", "tb180", "ark01"]

# 111 号: what on each small ship still bites, said with what to do about it (Q3 A)
static func _ship_warn(g, warn: Array) -> void:
	var s = g.sys
	match ship_key(g):
		"qc30":
			var d = g.dilution
			if d == null or not d.active():
				return
			if not d.locked():
				warn.append(w("隔振台没锁：附近切割会震伤芯片（拨 VI-LOCK）", "ISOLATION TABLE FLOATING: A CUT CLOSE BY SHAKES THE CHIP (VI-LOCK)"))
			var t: float = d.mxc_temp()
			if t < float(d.cfg.get("brittle_T", 250.0)):
				var tt := ("%.0f mK" % (t * 1000.0)) if t < 1.0 else ("%.0f K" % t)
				warn.append(w("混合室 %s：回到 250 K 以上才能拆冷台", "MIXING CHAMBER %s: NOT THE STACK TILL PAST 250 K") % tt)
		"h22":
			var m = g.mech
			if m == null:
				return
			var mt := 0.0
			for t in ["TH-U", "TH-L"]:
				mt = maxf(mt, m.field(t))
			if mt > 1.0:
				warn.append(w("拖头残磁：%.0f mT。断开 K-H 后再消磁。残磁可能吸走无人机和附近碎件。", "TOW HEADS AT %.0f mT: THEY PULL THE DRONE IN (K-H OFF, THEN DEGAUSS)") % mt)
			for l in m.loads:
				if l.alive and not l.fired:
					warn.append(w("拆除拖臂销轴前，先给 ACC 泄压，再拔出 PIN，防止拖臂突然弹出。", "ARMS PINNED UNDER PRESSURE: BLEED ACC, PULL THE PINS FIRST"))
					break
		"st40":
			var c = g.composite
			if c == null or not c.active():
				return
			for r in g.world.rooms:
				if c.level(r) > 0.05:
					warn.append(w("%s 有毒烟：电子件在掉价（接气口抽走空气）", "SMOKE IN %s: THE ELECTRONICS ARE SPOILING (PUMP IT OUT)") % g.room_name(r))
			for r in g.world.rooms:
				if s.P(r) > 20.0:
					warn.append(w("舱里还有空气：切碳纤维壳会冒毒烟（先抽真空，或拧螺栓拆壳板）", "AIR ABOARD: CUTTING THE CARBON SKIN SMOKES (PUMP DOWN, OR UNBOLT THE PANELS)"))
					break
		"my48":
			var a = g.atmos
			if a == null:
				return
			for r in g.world.rooms:
				if s.P(r) > 20.0 and s.o2_frac(r) > a.fire_o2():
					warn.append(w("%s 富氧 %d%%：附近切割会闪燃（撬开 G-S，抽走空气）", "%s AT %d%% OXYGEN: A CUT CLOSE BY FLASHES OVER (FREE G-S, PUMP IT OUT)") % [g.room_name(r), int(round(s.o2_frac(r) * 100.0))])
		"ev55":
			var th = g.thermal
			if th == null or not th.active():
				return
			var hot := -1.0
			var zn := ""
			for gr in spec(g).groups:
				for t in gr.tags:
					var p = _unit(g, str(t))
					if p == null or p.gone:
						continue
					var z: String = th.zone_of(p)
					if z != "" and th.zone_temp(z) > hot:
						hot = th.zone_temp(z)
						zn = z
			if hot > float(th.cfg.get("spoil_T", 150.0)):
				warn.append(w("仪器所在区 %.0f°C：150°C 以下再取（接 COOL-S 降得快）", "THE INSTRUMENTS' ZONE AT %.0f °C: TAKE THEM BELOW 150 (COOL-S COOLS IT FASTER)") % hot)
		"ih55":
			var sh = g.softshell
			if sh == null or not sh.active():
				return
			var up := 0
			var tight := 0
			for b in sh.cfg.get("bags", {}):
				if sh.inflated(str(b)):
					up += 1
				if sh.taut(str(b)):
					tight += 1
			if up > 0:
				warn.append(w("%d 个气囊还鼓着：带气切会塌下砸设备（接 BV 口放气）", "%d BAGS STILL UP: CUT ONE AND IT COMES DOWN ON THE UNITS (LET IT DOWN AT ITS BV)") % up)
			if tight > 0:
				warn.append(w("%d 个张紧器还绷着：切绑带会甩（先拨 TN 松开）", "%d TENSIONERS TAUT: A STRAP CUT WHIPS (TN OFF FIRST)") % tight)
		"fx70":
			var mg = g.magnets
			if mg == null or not mg.active():
				return
			if mg.any_energised():
				var hot := false
				for c in mg.energy:
					if mg.energised(str(c)) and not mg.cooled(str(c)):
						hot = true
				warn.append(w("线圈还储着 %d%% 的能：开 DUMP 泄能、保持制冷，降到 5%% 以下再断电动支架", "THE COILS HOLD %d%% OF THEIR ENERGY: DUMP IT WITH THE COOLING ON, UNDER 5%% BEFORE POWER OR SUPPORTS") % int(round(mg.field())))
				if hot:
					warn.append(w("有线圈断了冷却：%.1f K，过 %.0f K 就失超（冷箱要有电、液氦要够）", "A COIL HAS LOST ITS COOLING: %.1f K, IT QUENCHES PAST %.0f K (THE COLD BOX POWERED, HELIUM IN IT)") % [mg.max_temp(), float(mg.cfg.get("Tc", 9.0))])
		"tw64":
			var m2 = g.mech
			if m2 == null:
				return
			var sup := str(m2.balance.get("support", ""))
			if sup != "" and not s.on(sup) and m2.twisted.is_empty():
				warn.append(w("船体没撑住：先拨 %s，或者两台引擎舱一起拆，否则先拆一边船体会扭", "THE HULL ISN'T PROPPED: SET %s, OR TAKE BOTH PODS TOGETHER, OR IT TWISTS") % sup)
			for l in m2.loads:
				if l.alive and not l.fired:
					warn.append(w("绞车和拖钳还带压上着销：先给蓄能器泄压、拔销再拆", "WINCH AND JAWS PINNED UNDER PRESSURE: BLEED, UNPIN, THEN TAKE"))
					break
		"fr26":
			var cr = g.cryo
			if cr == null or not cr.active():
				return
			var any_ch := false
			for ch in cr.chillers:
				var cp = g.world.tag(str(ch))
				if cp != null and not cp.gone and s.piece_volts(cp) > 1.0:
					any_ch = true
			for tg in cr.tanks:
				var e: Dictionary = cr.tanks[tg]
				if s.fluid(str(e.get("liquid", ""))) > 0.02:
					var kpa: float = s.P(str(e.get("vessel", "")))
					if kpa > float(e.get("psv_kpa", 300.0)) * 0.8:
						warn.append(w("%s 压力 %.0f kPa：快到泄压线了（先抽 LNG）", "%s AT %.0f kPa: NEAR ITS RELIEF (DRAW THE LNG OFF)") % [tg, kpa])
			if not any_ch:
				warn.append(w("冷机没电：LNG 在升温沸散（冷机要一直开到抽完）", "THE CHILLERS ARE DEAD: THE LNG IS WARMING (KEEP THEM RUNNING TILL IT IS OFF)"))
		"med47":
			var bi = g.bio
			if bi == null or not bi.active():
				return
			var open_n := 0
			for tg in bi.items:
				var bp = g.world.tag(str(tg))
				if bp != null and not bp.gone and not bi.is_sealed(str(tg)):
					open_n += 1
			if open_n > 0:
				warn.append(w("%d 件生物危险品没封存：动之前先拨它的 SB / SF / SL 封存", "%d BIOHAZARDS UNSEALED: SEAL EACH (SB / SF / SL) BEFORE IT MOVES") % open_n)
			for r in bi.dirty_from_start:
				if s.vols.has(r) and s.P(r) > LIVE_KPA:
					warn.append(w("隔离舱 %s 还有污染空气：开门前用回收软管（带滤网）抽空", "ISOLATION ROOM %s STILL HOLDS ITS AIR: PUMP IT OUT THROUGH THE FILTER BEFORE ANY DOOR") % r)
		"dc84":
			var im = g.immersion
			if im == null or not im.active():
				return
			var wet := 0
			for rk in im.cfg.get("tanks", {}):
				var rp = g.world.tag(str(rk))
				if rp != null and not rp.gone and rp.body == null and im.full(str(rk)):
					wet += 1
			if wet > 0:
				warn.append(w("%d 个机柜罐里还有冷却液：带液吊会洒、短路旁边的机柜（先从 PT 口抽干）", "%d RACKS STILL IN FLUID: LIFTED WET THEY SPILL AND SHORT THE NEXT (DRAIN AT PT)") % wet)
			var loose := 0
			for dr in im.cfg.get("drives", {}):
				var dp = g.world.tag(str(dr))
				if dp != null and not dp.gone and dp.body == null and not im.cased(str(dr)):
					loose += 1
			if loose > 0:
				warn.append(w("%d 块客户硬盘没上锁：先拨 CUST 锁进屏蔽舱，否则按违约罚款", "%d CLIENT DRIVES NOT LATCHED: CUST FIRST, OR IT IS A FINED BREACH") % loose)
		"bl88":
			var wb = g.waterball
			if wb == null or not wb.active() or wb.burst:
				return
			if wb.level() > float(wb.cfg.get("safe", 0.12)):
				warn.append(w("水球还有 %d%%：切网罩或拆支架会炸散（先从 PW 口抽到 12%% 以下）", "THE BALL IS AT %d%%: CUT ITS NET OR FRAME AND IT BURSTS (PUMP IT BELOW 12%% AT PW)") % int(round(wb.level() * 100.0)))
		"hb86":
			var a2 = g.atmos
			if a2 == null:
				return
			for r in g.world.rooms:
				if s.P(r) > 20.0 and s.o2_frac(r) > a2.fire_o2():
					warn.append(w("%s 富氧 %d%%：附近切割会闪燃（接 G-%s 抽空）", "%s AT %d%% OXYGEN: A CUT CLOSE BY FLASHES OVER (PUMP IT OUT AT G-%s)") % [g.room_name(r), int(round(s.o2_frac(r) * 100.0)), r])
		"nr95", "ark01":
			var rc = g.reactor
			var fn = g.furnace
			if rc == null:
				return
			var free := 0
			for d in rc.cfg.get("drums", {}):
				if not s.on(str(rc.cfg.drums[d])):
					free += 1
			if free > 0:
				warn.append(w("%d 个控制鼓没锁：吊堆芯会滑出（拨 DL 锁上）", "%d DRUMS UNLOCKED: THE CORE LIFTED, ONE SLIPS (THROW THE DL LOCKS)") % free)
			if fn != null and fn.active() and fn.core_temp() > float(fn.cfg.get("safe", 60.0)):
				warn.append(w("堆芯 %.0f°C：冷却泵要一直有电，60°C 以下才能动它和散热片", "THE CORE AT %.0f °C: KEEP THE COOLANT PUMPS POWERED, NOTHING MOVES TILL UNDER 60") % fn.core_temp())
			warn.append(w("无人机剂量 %.0f / %.0f mSv：在屏蔽板的阴影里干活；激光绝不碰堆芯", "DRONE DOSE %.0f / %.0f mSv: WORK IN THE SHIELD'S SHADOW; NEVER LET THE BEAM TOUCH THE CORE") % [rc.dose, float(rc.cfg.get("limit", 150.0))])
		"vt80":
			var tn = g.tanknet
			if tn == null or not tn.active():
				return
			if tn.fuel_left() > 0.02:
				warn.append(w("推进剂还有 %.1f：先抽走（主泵经 PR，N2O4 单独走 LD-2）；切管 MMH 和 N2O4 会自燃", "%.1f OF PROPELLANT ABOARD: DRAW IT OFF (THE PUMP AT PR, THE N2O4 ALONE AT LD-2); CUT A LINE AND THEY IGNITE") % tn.fuel_left())
				warn.append(w("增压阀 PV 一直开着，TV 和 NP 口别放空：否则罐会抽瘪", "KEEP THE PV VALVES OPEN AND NEVER VENT TV OR NP: A TANK BUCKLES"))
		"cl104":
			var cc = g.coldchain
			if cc == null or not cc.active():
				return
			for r in cc.cfg.get("rooms", {}):
				if not cc.thawed.has(r) and not cc.held(str(r)):
					warn.append(w("冷舱 %s 在升温：%.0f°C，−5°C 以上就解冻（接 COLD-X，或让冷机有电）", "HOLD %s IS WARMING: %.0f °C, THAWS PAST −5 (COLD-X, OR KEEP THE CHILLERS POWERED)") % [r, cc.room_temp(str(r))])
		"ps12":
			var ln = g.liner
			if ln == null or not ln.active():
				return
			var armed := 0
			for pod in ln.cfg.get("pods", {}):
				if not ln.fired.has(pod) and ln.armed(str(pod)):
					armed += 1
			if armed > 0:
				warn.append(w("%d 个逃生舱点火电路还活着：松夹前先拨 ARM 断开（或拔引线）", "%d PODS STILL ARMED: ARM OFF (OR THE LEAD PULLED) BEFORE THE CLAMPS") % armed)
		"ch110":
			var sw = g.sandwich
			if sw == null or not sw.active() or sw.sprung:
				return
			if sw.cargo_kpa() > float(sw.cfg.get("spring_kpa", 20.0)):
				warn.append(w("居住舱还有 %.0f kPa：先抽到 20 kPa 以下再松夹，否则会弹出", "THE HABITAT HOLDS %.0f kPa: BELOW 20 BEFORE THE CLAMPS, OR IT SPRINGS") % sw.cargo_kpa())
			warn.append(w("液压夹按对角顺序交替松：HC-U1 → HC-L4 → HC-U4 → HC-L1 → …", "THE CLAMPS CROSSWISE: HC-U1 → HC-L4 → HC-U4 → HC-L1 → …"))
		"ic120":
			var ic = g.ice
			if ic == null or not ic.active():
				return
			var mw: float = s.fluid(str(ic.cfg.get("volume", "")))
			var lim := float(ic.cfg.get("short", {}).get("limit", 3.0))
			if mw > lim * 0.6:
				warn.append(w("融水积了 %.1f m³：到 %.0f m³ 带电就短路（接 PW 泵走）", "%.1f m³ OF MELTWATER STANDING: PAST %.0f m³ IT SHORTS (PUMP IT AT PW)") % [mw, lim])
			if ic.left_fraction() > float(ic.cfg.get("pads", {}).get("keep", 0.5)):
				warn.append(w("冰还剩 %d%%：化到一半以下再松鞍座 PH，裂缝上的冰别切", "%d%% OF THE ICE LEFT: NO SEAT (PH) TILL UNDER HALF, NEVER CUT THE BLOCKS ON THE CRACK") % int(round(ic.left_fraction() * 100.0)))
		"mf126":
			var fu = g.furnace
			if fu != null and fu.active() and fu.core_temp() > float(fu.cfg.get("safe", 150.0)):
				warn.append(w("炉芯 %.0f°C：换热泵要一直有电，150°C 以下才能吊", "THE CORE AT %.0f °C: KEEP THE PUMPS POWERED, NOT OUT TILL UNDER 150") % fu.core_temp())
			var m3 = g.mech
			if m3 != null:
				for l in m3.loads:
					if l.alive and not l.fired:
						warn.append(w("进料臂还带压上着销：先给 ACC-F 泄压、拔销", "THE FEED ARM IS PINNED UNDER PRESSURE: BLEED ACC-F, UNPIN"))
						break
		"pt34":
			var mu = g.munitions
			if mu == null or not mu.active():
				return
			var live := 0
			for id in g.world.order:
				var q = g.world.pieces[id]
				if mu.live(q):
					live += 1
			if live > 0:
				warn.append(w("%d 发弹药还活着：激光靠近会烤到殉爆、撞击会爆（开 FLV 注水打湿弹库）", "%d ROUNDS LIVE: THE BEAM COOKS THEM OFF, A KNOCK SETS THEM OFF (OPEN FLV, WET THE MAGAZINE)") % live)
		"cv138":
			var dr = g.drones
			if dr == null or not dr.active():
				return
			var hot := 0
			for t in dr.cfg:
				var dp = g.world.tag(str(t))
				if dp != null and not dp.gone and dp.body == null and dr.live_pack(str(t)):
					hot += 1
			if hot > 0:
				warn.append(w("%d 架无人机电池还通着：拆之前先拨 PK 断开，否则会醒来甩飞", "%d DRONES ON LIVE PACKS: PK OFF FIRST, OR THEY WAKE AND THROW THEMSELVES") % hot)
		"sv122", "ro128":
			var rl2 = g.rails
			if rl2 == null or not rl2.active():
				return
			for sid in rl2.cfg:
				if not rl2.released.has(sid):
					warn.append(w("货还锁在轨道上：先解锁再动吊挂、轨道和甲板", "THE CARGO IS LOCKED ON ITS RAILS: RELEASE IT BEFORE THE HANGERS, RAILS OR DECK"))
					break
		"mt140":
			var tr = g.train
			if tr == null or not tr.active():
				return
			if tr.fluid_left() > 0.02:
				warn.append(w("两个货罐还有货：总线断开前先从 PT-2、PT-5 抽空（泵要有电）", "CARGO IN THE TANKS: DRAIN AT PT-2 AND PT-5 BEFORE THE BUS GOES (THE PUMPS NEED IT)"))
			if not tr.sprang and tr.aft_mass() > float(tr.cfg.get("jam", {}).get("keep", 75.0)):
				warn.append(w("K-4 车钩卡死承着弯：后面 %.0f t 拆完前别动 K-4 和它的销子", "K-4 HOLDS THE BEND: %.0f t AFT OF IT, LEAVE K-4 AND ITS PINS TILL THAT IS OFF") % tr.aft_mass())
		"dr150":
			var ds = g.drillstring
			if ds == null or not ds.active():
				return
			if ds.torque_pct() > 5.0:
				warn.append(w("钻杆还有 %d%% 扭矩：先拨 TQB 泄扭", "%d%% TORQUE IN THE STRING: BLEED IT AT TQB") % int(round(ds.torque_pct())))
			if ds.mud_level() > float(ds.cfg.get("mud_safe", 0.05)):
				warn.append(w("泥浆还有 %d%%（%.0f kPa）：接 PMUD 放掉", "MUD AT %d%% (%.0f kPa): LET IT OUT AT PMUD") % [int(round(ds.mud_level() * 100.0)), ds.mud_kpa()])
		"md160":
			var fw = g.flywheel
			if fw == null or not fw.active():
				return
			if fw.max_rpm() > float(fw.cfg.get("safe", 300.0)):
				warn.append(w("飞轮还在转 %.0f rpm：开 CV 冷却再拨 BR 刹车，降到 300 以下再拆", "A WHEEL AT %.0f rpm: COOLING (CV), THEN THE BRAKE (BR), UNDER 300 BEFORE IT COMES OFF") % fw.max_rpm())
			for r in fw.cfg.get("rails", {}):
				if fw.rail_pull(str(r)) > 0.0:
					warn.append(w("导轨还绷着：张紧器从尾往头逐个松", "THE RAILS ARE TENSIONED: LET THE TENSIONERS OFF TAIL FIRST"))
					break
		"hg170":
			var bo = g.boiloff
			if bo == null or not bo.active():
				return
			if not bo.refrigerating():
				warn.append(w("制冷机没电：罐压在升，升到泄压线就放空掉货", "THE COOLERS ARE DEAD: THE TANKS ARE CLIMBING TO THEIR RELIEFS"))
			for t in bo.cfg.get("tanks", {}):
				if bo.frozen(str(t)) and not bo.burst.has(t):
					warn.append(w("%s 的泄压阀冻住了：拨 %s 化冻，否则会爆罐", "%s's RELIEF IS FROZEN: THAW IT (%s) OR IT BURSTS") % [t, str(bo.cfg.tanks[t].get("heater", ""))])
		"tb180":
			var te = g.tether
			if te == null or not te.active():
				return
			if te.spinning():
				warn.append(w("还在转 %.2f rpm：开 BRK-C 冷却再拨 BRK 刹车，转着切绳吊舱会甩飞", "STILL TURNING AT %.2f rpm: COOLING (BRK-C), THEN THE BRAKE (BRK); CUT TURNING AND THE PODS ARE THROWN") % te.rpm)
			elif s.on(str(te.cfg.get("release", ""))):
				warn.append(w("系绳还有残余张力：拨 TEN 松开再切", "THE TETHER STILL PULLS: TEN OFF BEFORE THE CUT"))
		"jd38":
			var rl = g.rails
			if rl == null or not rl.active():
				return
			for sid in rl.cfg:
				if not rl.released.has(sid):
					warn.append(w("快递箱锁在轨道上：开货舱门和船尾门，再拨 LK-U、LK-L 让箱子滑出", "THE BOXES ARE LOCKED ON THEIR RAILS: OPEN THE DOORS, THEN LK-U AND LK-L"))
					break


static func _equip_review(g) -> Dictionary:
	var f := full(g)
	var units: Array = []
	var rolled := 0.0
	var got := 0.0
	if spec(g).get("ore", false):
		var oc := _ore_counts(g)
		var ow := ore_worth(g)
		rolled += ow
		got += ore_got(g)
		units.append({"text": w("矿料：收 %s / %s", "ORE: %s OF %s") % [Pal.money(ore_got(g)), Pal.money(ore_full(g))], "value": ow,
			"sub": w("细矿放出 %.1f t，洒落 %.1f t；矿块运走 %d / %d 块", "%.1f t OF FINES OUT, %.1f t LOST; %d OF %d CHUNKS HAULED") % [g.ore.fines0 - g.ore.fines - g.ore.spilled, g.ore.spilled, oc.x, oc.y]})
	var fl := _fluid(g)
	if not fl.is_empty():
		rolled += float(fl.now)
		got += float(fl.got)
		units.append({"text": w("%s：收 %s / %s", "%s: %s OF %s") % [str(fl.name), Pal.money(float(fl.got)), Pal.money(float(fl.full))], "value": float(fl.now),
			"sub": w("抽进来 %d%%，还在船上 %d%%", "%d%% DRAWN OFF, %d%% STILL ABOARD") % [int(round(float(fl.rec) * 100.0)), int(round(float(fl.left) * 100.0))]})
	for gr in spec(g).groups:
		var n := 0
		var kept := 0
		var sent := 0
		var v := 0.0
		for t in gr.tags:
			var p = _unit(g, str(t))
			if p == null:
				continue
			n += 1
			var uv := _unit_worth(p)
			if _unit_worth(p) > 0.0:
				kept += 1
			v += uv
			if p.gone and p.intact and p.into == "equip":
				sent += 1
				got += uv
		rolled += v
		units.append({"text": w("%s：保住 %d / %d 件", "%s: %d OF %d KEPT") % [_t(gr.name), kept, n], "value": v,
			"sub": w("已送设备口 %d 件，船上 %d 件", "%d TO THE EQUIPMENT MOUTH, %d ABOARD") % [sent, kept - sent]})
	var tags := _units(g)
	var by := {}
	for d in g.devalued:
		if not _mine(g, tags, d):
			continue
		var k: String = _dv(g, str(d[0]))
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	if spec(g).get("ore", false) and g.ore.torn:
		by["hopper_tear"] = {"money": 8000.0, "n": 1}
	var first := (w("保住的矿料和设备值 %s（满价 %s）；已到手 %s", "The ore and units kept are worth %s (whole %s); %s in hand") if spec(g).get("ore", false) else w("保住的设备值 %s（满价 %s）；已送走 %s", "The units kept are worth %s (whole %s); %s sent")) % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("干净利落。下次想快一点，可以试试暴力快拆：船体按大块切，整块送熔炉", "Clean work. For speed next time, break it up: big sections to the furnace") if got > 0.0 else w("设备还在船上：送进设备口才算钱", "The units are still aboard: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# what the salvage bot really got and took on each way, measured (tests/bot_run.gd, paced): the
# card's money and time for these ships come from here, not from a guess
# 2026-10-28, GR-001 as built, one run each way: careful got all six units to the equipment mouth,
# all its money in by 18.6 min (17.3 min of work; two loose harnesses it never placed aside);
# careless (straight to cutting, all to the furnace) none of them, 13.6 min, four blowouts, both
# named pieces lost, $14,774 in and $15,000 in fines
# 2026-10-28, M-14 as built, chunks at the ore price ($900/t, user "按矿价算"), one run each way
# (no crane at the bot's berth): careful ran the ore out through the gates and got all of it and
# the line but the crusher (6 t, past the grapple: cut down, scrap) and the 11 m belt (its last
# load, never placed), $134,169 of $164,169, 23.2 min of work; careless cut its way in, the fines
# all out through the holes, only the chunks, $77,569, 27.2 min, three blowouts, both named pieces lost
# 2026-10-28, CF-90 as built with the heavy crane, one run each way: ends inwards $104,500 of the
# boxes, props first $98,000, both about 46-47 min of work, no kink, no buckle; each left five
# boxes drifting that the bot never got into a mouth (its handling, not the way)
# 2026-10-28, LC-140 as built, one run each way: careful made the courier safe, the locks from the
# stern, the door, and winched it out whole by 2.7 min of sim time ($1,038,837), the whole
# carrier stripped in 51.5 min of work (99.99 %, no incident); careless cut into its hull at
# 12.5 min (the premium gone) and fed it all to the furnace: none of it, 47 min, $12,000 in fines
const BOT_RUNS := {
	# 114 号, 2026-10-30: the last six as built, with the heavy crane, one run each way (ARK-01 is by
	# hand only: not run)
	"mt140": {
		"careful": {"lo": 39081.0, "hi": 39081.0, "minutes": [49, 50], "note": ["实测（有吊车）：整船收入 $331,140，0 事故", "measured (crane): $331,140 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [29, 30], "note": ["实测：后半列弹开、罐没抽；整船收入 $51,791，罚款 $18,000，15 次事故", "measured: the aft train sprang, the tanks never drained; $51,791 in, $18,000 in fines, 15 incidents"]},
	},
	"dr150": {
		"careful": {"lo": 152000.0, "hi": 152000.0, "minutes": [66, 67], "note": ["实测：0 事故，66 分钟时还在收尾（只拿到一半）；整船收入 $1,203,527", "measured: no incidents, still finishing at 66 minutes (half of it in); $1,203,527 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [64, 65], "note": ["实测：钻杆甩打、泥浆喷出；整船收入 $67,956，罚款 $12,000，19 次事故", "measured: the string whipped, the mud blew out; $67,956 in, $12,000 in fines, 19 incidents"]},
	},
	"md160": {
		"careful": {"lo": 106000.0, "hi": 106000.0, "minutes": [65, 66], "note": ["实测（有吊车）：整船收入 $430,232，0 事故", "measured (crane): $430,232 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [57, 58], "note": ["实测：飞轮甩飞；整船收入 $125,306，罚款 $3,000，10 次事故", "measured: the wheels were thrown; $125,306 in, $3,000 in fines, 10 incidents"]},
	},
	"hg170": {
		"careful": {"lo": 680000.0, "hi": 680000.0, "minutes": [62, 63], "note": ["实测：整船收入 $1,587,862，0 事故，大半时间在抽低温货", "measured: $1,587,862 in, no incidents, most of it drawing the cargo"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [46, 47], "note": ["实测：低温货放空、罐爆；整船收入 $94,805，罚款 $9,000，11 次事故", "measured: the cargo vented, a tank burst; $94,805 in, $9,000 in fines, 11 incidents"]},
	},
	"tb180": {
		"careful": {"lo": 135700.0, "hi": 135700.0, "minutes": [26, 27], "note": ["实测：整船收入 $238,808，0 事故", "measured: $238,808 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [16, 17], "note": ["实测：吊舱甩飞；整船收入 $17,088，罚款 $15,000，10 次事故", "measured: the pods were thrown; $17,088 in, $15,000 in fines, 10 incidents"]},
	},
	"ark01": {
		"careful": {"lo": 306000.0, "hi": 340000.0, "minutes": [0, 0], "note": ["ARK-01 只许人工拆，机器人不能跑；价钱按满价估", "ARK-01 is by hand only, the bot can't run it; the money is the whole worth, estimated"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [0, 0], "note": ["只许人工拆，没实测", "by hand only, not measured"]},
	},
	# 113 号, 2026-10-30: the third ten as built, with the heavy crane, one run each way; minutes to the
	# last money in (on four careful runs it was still coming at the 66-minute limit)
	"ps12": {
		"careful": {"lo": 36000.0, "hi": 36000.0, "minutes": [42, 43], "note": ["实测：4 个舱的点火电路都断了，0 事故；两个 3.5 m 宽的逃生舱机器人没塞进回收口，人手可以全拿；整船收入 $329,801", "measured: all four circuits off, no incidents; two 3.5 m pods the bot never fitted into a mouth, a hand gets them all; $329,801 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [33, 34], "note": ["实测：逃生舱弹射摔坏；整船收入 $66,886，罚款 $18,000，15 次事故", "measured: the pods fired and smashed; $66,886 in, $18,000 in fines, 15 incidents"]},
	},
	"ch110": {
		"careful": {"lo": 79500.0, "hi": 79500.0, "minutes": [66, 67], "note": ["实测：0 事故，66 分钟时还在收尾；整船收入 $479,269", "measured: no incidents, still finishing at 66 minutes; $479,269 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [58, 59], "note": ["实测：舱体扭转、裂梁断开；整船收入 $79,155，罚款 $15,000，19 次事故", "measured: the module twisted, the cracked beam tore; $79,155 in, $15,000 in fines, 19 incidents"]},
	},
	"es112": {
		"careful": {"lo": 87300.0, "hi": 97000.0, "minutes": [0, 0], "note": ["机器人不会开金库门，这条没实测，价钱按满价估", "the bot can't open a vault, so this way wasn't measured; the money is the whole worth, estimated"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [66, 67], "note": ["实测：保险箱一个没拿到；整船收入 $93,753，5 次事故", "measured: not one safe box out; $93,753 in, 5 incidents"]},
	},
	"fl116": {
		"careful": {"lo": 30405.0, "hi": 30405.0, "minutes": [46, 47], "note": ["实测：0 事故，介质没全抽回；整船收入 $304,987", "measured: no incidents, not all the media drawn; $304,987 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [38, 39], "note": ["实测：混成废液、罚处理费；整船收入 $62,152，罚款 $20,250，14 次事故", "measured: mixed into waste and charged; $62,152 in, $20,250 in fines, 14 incidents"]},
	},
	"ic120": {
		"careful": {"lo": 94000.0, "hi": 94000.0, "minutes": [17, 18], "note": ["实测：融水积多了短路一次；整船收入 $319,427", "measured: the meltwater stood too long once and shorted; $319,427 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [13, 14], "note": ["实测：冰裂开砸坏设备、融水流失；整船收入 $79,488，罚款 $6,000，6 次事故", "measured: the ice split onto the units, the water lost; $79,488 in, $6,000 in fines, 6 incidents"]},
	},
	"sv122": {
		"careful": {"lo": 78000.0, "hi": 78000.0, "minutes": [57, 58], "note": ["实测：整船收入 $459,388，0 事故", "measured: $459,388 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [48, 49], "note": ["实测：仪器整组砸落；整船收入 $76,611，罚款 $12,000，15 次事故", "measured: the instruments came down together; $76,611 in, $12,000 in fines, 15 incidents"]},
	},
	"mf126": {
		"careful": {"lo": 58000.0, "hi": 58000.0, "minutes": [64, 65], "note": ["实测（有吊车）：0 事故，64 分钟时还在收尾；整船收入 $293,585", "measured (crane): no incidents, still finishing at 64 minutes; $293,585 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [66, 67], "note": ["实测：炉芯热裂；整船收入 $68,115，罚款 $15,000，8 次事故", "measured: the core cracked; $68,115 in, $15,000 in fines, 8 incidents"]},
	},
	"ro128": {
		"careful": {"lo": 60000.0, "hi": 60000.0, "minutes": [58, 59], "note": ["实测（有吊车）：整船收入 $331,532，0 事故", "measured (crane): $331,532 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [57, 58], "note": ["实测：货被扯伤；整船收入 $87,236，罚款 $12,000，12 次事故", "measured: the cargo wrenched; $87,236 in, $12,000 in fines, 12 incidents"]},
	},
	"pt34": {
		"careful": {"lo": 194000.0, "hi": 194000.0, "minutes": [66, 67], "note": ["实测（有吊车）：0 事故，66 分钟时还在收尾；整船收入 $482,968", "measured (crane): no incidents, still finishing at 66 minutes; $482,968 in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [66, 67], "note": ["实测：殉爆连锁，设备全毁；整船收入 $118,349，罚款 $176,000，63 次事故", "measured: they cooked off one after another, every unit gone; $118,349 in, $176,000 in fines, 63 incidents"]},
	},
	"cv138": {
		"careful": {"lo": 82000.0, "hi": 82000.0, "minutes": [46, 47], "note": ["实测：整船收入 $339,915，0 事故", "measured: $339,915 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [37, 38], "note": ["实测：无人机醒来甩飞；整船收入 $52,745，罚款 $6,000，8 次事故", "measured: the drones woke and threw themselves; $52,745 in, $6,000 in fines, 8 incidents"]},
	},
	# 112 号, 2026-10-30: the second ten as built, with the heavy crane (the 88 m berth and on), one run
	# each way; minutes to the last money in
	"fx70": {
		"careful": {"lo": 540000.0, "hi": 540000.0, "minutes": [37, 38], "note": ["实测（有吊车）：整船收入 $1,709,284，0 事故；两个线圈机器人没收回", "measured (crane): $1,709,284 in, no incidents; two coils the bot never got in"]},
		"demolish": {"lo": 15895.0, "hi": 15895.0, "minutes": [29, 30], "note": ["实测：线圈失超连锁，只剩 $15,895；整船收入 $62,339，罚款 $9,000，15 次事故", "measured: the coils quenched one into the next, $15,895 left; $62,339 in, $9,000 in fines, 15 incidents"]},
	},
	"tw64": {
		"careful": {"lo": 56000.0, "hi": 56000.0, "minutes": [25, 26], "note": ["实测（有吊车）：整船收入 $205,560，0 事故", "measured (crane): $205,560 in, no incidents"]},
		"demolish": {"lo": 13200.0, "hi": 13200.0, "minutes": [21, 22], "note": ["实测：船体扭曲、绞车弹出，只剩 $13,200；整船收入 $64,937，罚款 $33,500，18 次事故", "measured: the hull twisted, the winch sprang, $13,200 left; $64,937 in, $33,500 in fines, 18 incidents"]},
	},
	"fr26": {
		"careful": {"lo": 68986.0, "hi": 68986.0, "minutes": [26, 27], "note": ["实测（有吊车）：整船收入 $257,118，0 事故；LNG 和罐没全收回（机器人搬运）", "measured (crane): $257,118 in, no incidents; not all the LNG and tanks came in (the bot's handling)"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [17, 18], "note": ["实测：LNG 全损，罐也切了；整船收入 $24,410，罚款 $12,000，9 次事故", "measured: the LNG all lost, the tanks cut; $24,410 in, $12,000 in fines, 9 incidents"]},
	},
	"med47": {
		"careful": {"lo": 85000.0, "hi": 85000.0, "minutes": [32, 33], "note": ["实测：整船收入 $265,354，0 事故", "measured: $265,354 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [25, 26], "note": ["实测：污染扩散，设备全毁；整船收入 $33,105，罚款 $103,000，42 次事故", "measured: the contamination spread, every unit lost; $33,105 in, $103,000 in fines, 42 incidents"]},
	},
	"dc84": {
		"careful": {"lo": 540000.0, "hi": 540000.0, "minutes": [46, 47], "note": ["实测：整船收入 $1,340,686，0 事故", "measured: $1,340,686 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [36, 37], "note": ["实测：洒液短路、硬盘违约；整船收入 $47,451，罚款 $166,000，28 次事故", "measured: spills, shorts, drives breached; $47,451 in, $166,000 in fines, 28 incidents"]},
	},
	"bl88": {
		"careful": {"lo": 107000.0, "hi": 107000.0, "minutes": [41, 42], "note": ["实测：整船收入 $590,039，0 事故", "measured: $590,039 in, no incidents"]},
		"demolish": {"lo": 31583.0, "hi": 31583.0, "minutes": [29, 30], "note": ["实测：水球炸散，只剩 $31,583；整船收入 $65,017，罚款 $12,000，10 次事故", "measured: the ball burst, $31,583 left; $65,017 in, $12,000 in fines, 10 incidents"]},
	},
	"hb86": {
		"careful": {"lo": 60400.0, "hi": 60400.0, "minutes": [30, 31], "note": ["实测：整船收入 $249,243，0 事故；两件机器人没收回", "measured: $249,243 in, no incidents; two pieces the bot never got in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [32, 33], "note": ["实测：闪燃烧坏培养舱；整船收入 $47,814，罚款 $6,000，11 次事故", "measured: flash fires through the halls; $47,814 in, $6,000 in fines, 11 incidents"]},
	},
	"nr95": {
		"careful": {"lo": 90000.0, "hi": 90000.0, "minutes": [18, 19], "note": ["实测（12 t 吊车）：液氢罐当时是 28 t，被切成废料；现在液氢罐 16 t，抽空后用升级的 16 t 吊车可以整件吊走（+$90,000）；整船收入 $258,122，1 次碰撞", "measured (12 t crane): the hydrogen tank, 28 t then, was cut to scrap; it is 16 t now, drained it lifts whole with the upgraded 16 t crane (+$90,000); $258,122 in, 1 knock"]},
		"demolish": {"lo": 70000.0, "hi": 70000.0, "minutes": [17, 18], "note": ["实测：整船收入 $114,784，罚款 $6,000，8 次事故（机器人没碰堆芯，没有核爆）", "measured: $114,784 in, $6,000 in fines, 8 incidents (the bot never cut the core, no detonation)"]},
	},
	"vt80": {
		"careful": {"lo": 113872.0, "hi": 113872.0, "minutes": [49, 50], "note": ["实测（有吊车）：整船收入 $256,232，0 事故", "measured (crane): $256,232 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [21, 22], "note": ["实测：自燃起火，罐和泵烧坏；整船收入 $31,436，罚款 $39,000，15 次事故", "measured: they ignited, tanks and pump burnt; $31,436 in, $39,000 in fines, 15 incidents"]},
	},
	"cl104": {
		"careful": {"lo": 97900.0, "hi": 97900.0, "minutes": [44, 45], "note": ["实测：整船收入 $280,976，0 事故；部分托盘机器人没收回", "measured: $280,976 in, no incidents; some pallets the bot never got in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [37, 38], "note": ["实测：疫苗解冻、货全进了熔炉；整船收入 $63,193，罚款 $3,000，10 次事故", "measured: thawed, and all of it to the furnace; $63,193 in, $3,000 in fines, 10 incidents"]},
	},
	# 111 号, 2026-10-30: the ten small ships as built, no crane, one run each way (tests/bot_run.gd
	# paced; careless = straight to cutting, all to the furnace). Minutes: the work until the last money
	# came in (on the runs the bot never finished, it circled one or two long pieces at the end)
	"tug": {
		"careful": {"lo": 18000.0, "hi": 18000.0, "minutes": [8, 9], "note": ["实测整船收入 $36,738，0 事故", "measured, whole ship: $36,738 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [7, 8], "note": ["实测整船收入 $6,856，罚款 $6,000，6 次事故", "measured, whole ship: $6,856 in, $6,000 in fines, 6 incidents"]},
	},
	"pod": {
		"careful": {"lo": 22798.0, "hi": 22798.0, "minutes": [6, 6], "note": ["实测（船坞无吊车）：最重的货柜 CG-3 超过抓钩，被切成废料；整船收入 $51,746，0 事故；有吊车可以全拿", "measured (no crane): the heaviest box, CG-3, past the grapple, was cut to scrap; $51,746 in, no incidents; with a crane, all of them"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [4, 5], "note": ["实测整船收入 $8,034，罚款 $9,000，4 次事故", "measured, whole ship: $8,034 in, $9,000 in fines, 4 incidents"]},
	},
	"s09": {
		"careful": {"lo": 30000.0, "hi": 30000.0, "minutes": [11, 12], "note": ["实测整船收入 $83,984，0 事故", "measured, whole ship: $83,984 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [9, 10], "note": ["实测整船收入 $9,605，罚款 $18,000，10 次事故", "measured, whole ship: $9,605 in, $18,000 in fines, 10 incidents"]},
	},
	"qc30": {
		"careful": {"lo": 425000.0, "hi": 425000.0, "minutes": [16, 17], "note": ["实测：芯片完好，一级冷台机器人没送进去；整船收入 $842,009，0 事故，大半时间在等回温", "measured: the chip whole, one stage the bot never got in; $842,009 in, no incidents, most of it waiting for the warm-up"]},
		"demolish": {"lo": 0.0, "hi": 425000.0, "minutes": [8, 10], "note": ["机器人不会用加热器，没实跑这条路；用时按回温速率算（加热器快 4 倍）。机器人直接切的结果：芯片和冷台全毁，$0", "the bot can't run the heaters, so this way wasn't measured; the time is worked out from the warming rate (the heaters are 4 times quicker). The bot cutting straight in: chip and stack gone, $0"]},
	},
	"jd38": {
		"careful": {"lo": 40000.0, "hi": 40000.0, "minutes": [10, 11], "note": ["实测整船收入 $110,409，0 事故", "measured, whole ship: $110,409 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [9, 9], "note": ["实测整船收入 $17,188，罚款 $6,000，7 次事故", "measured, whole ship: $17,188 in, $6,000 in fines, 7 incidents"]},
	},
	"h22": {
		"careful": {"lo": 41000.0, "hi": 41000.0, "minutes": [14, 15], "note": ["实测整船收入 $149,372，0 事故", "measured, whole ship: $149,372 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [12, 13], "note": ["实测整船收入 $19,389，罚款 $21,000，9 次事故", "measured, whole ship: $19,389 in, $21,000 in fines, 9 incidents"]},
	},
	"st40": {
		"careful": {"lo": 254000.0, "hi": 254000.0, "minutes": [11, 12], "note": ["实测整船收入 $463,603，0 事故", "measured, whole ship: $463,603 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [9, 10], "note": ["实测整船收入 $11,352，罚款 $12,000，6 次事故", "measured, whole ship: $11,352 in, $12,000 in fines, 6 incidents"]},
	},
	"my48": {
		"careful": {"lo": 56883.0, "hi": 56883.0, "minutes": [13, 14], "note": ["实测整船收入 $194,413，0 事故", "measured, whole ship: $194,413 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [12, 12], "note": ["实测整船收入 $7,499，罚款 $3,000，5 次事故", "measured, whole ship: $7,499 in, $3,000 in fines, 5 incidents"]},
	},
	"ev55": {
		"careful": {"lo": 166000.0, "hi": 166000.0, "minutes": [34, 35], "note": ["实测整船收入 $597,780，0 事故，大半时间在等降温", "measured, whole ship: $597,780 in, no incidents, most of it waiting for it to cool"]},
		"demolish": {"lo": 0.0, "hi": 99600.0, "minutes": [29, 30], "note": ["机器人只会直接切，没实跑'边等边拆'：它直接切的结果是仪器全毁，$0，整船收入 $32,699，罚款 $9,000", "the bot only cuts straight in, it didn't run this way: cutting straight in it lost every instrument, $0; $32,699 in, $9,000 in fines"]},
	},
	"ih55": {
		"careful": {"lo": 33500.0, "hi": 33500.0, "minutes": [33, 34], "note": ["实测整船收入 $109,274，0 事故；一件储物柜机器人没送进去", "measured, whole ship: $109,274 in, no incidents; one locker the bot never got in"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [30, 31], "note": ["实测整船收入 $25,836，16 次事故", "measured, whole ship: $25,836 in, 16 incidents"]},
	},
	"lc140": {
		"careful": {"lo": 1038837.0, "hi": 1038837.0, "minutes": [51, 53],
			"note": ["实测：小船在开工 3 分钟内整船拖出，整船（含拆完载舰）收入 $1,726,874，0 事故", "measured: the courier out whole within 3 minutes; the whole job, carrier stripped too, $1,726,874, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [47, 48],
			"note": ["实测：12 分钟时切开了小船船壳，溢价没了，设备也一起进了熔炉；整船收入 $36,182，罚款 $12,000", "measured: its hull cut at 12 minutes, the premium gone, its equipment into the furnace with it; $36,182 in, $12,000 in fines"]},
	},
	"cf90": {
		"careful": {"lo": 104500.0, "hi": 104500.0, "minutes": [46, 47],
			"note": ["实测（有吊车）：整船收入 $163,355，0 事故；机器人有 5 箱飘走没送进接收口，人手可以全拿", "measured (crane): $163,355 in, no incidents; the bot let five boxes drift off, a hand gets them all"]},
		"props": {"lo": 98000.0, "hi": 98000.0, "minutes": [47, 47],
			"note": ["实测（有吊车，撑杆在第 2、6 列下）：整船收入 $166,852，0 事故，撑杆没超载；用时和逐层卸差不多，好处是可以先拿里侧的箱", "measured (crane, props under bays 2 and 6): $166,852 in, no incidents, no prop overloaded; about as long as ends-inwards, the gain is taking the inner bays first"]},
	},
	"m14": {
		"careful": {"lo": 134169.0, "hi": 134169.0, "minutes": [23, 24],
			"note": ["实测（船坞无吊车，破碎头被切成废料）：整船收入 $295,092，0 事故；有吊车整件吊走破碎头可再多 $24,000", "measured (no crane: the crusher cut down to scrap): $295,092 in, no incidents; a crane lifting the crusher whole adds $24,000"]},
		"demolish": {"lo": 77569.0, "hi": 77569.0, "minutes": [27, 28],
			"note": ["实测：细矿全部从破口洒光，只收回矿块；整船收入 $108,548，罚款 $18,000，3 次舱室爆泄，并不比慢开闸快", "measured: the fines all poured out of the holes, only the chunks in; $108,548 in, $18,000 in fines, 3 blowouts, and no quicker than the gates"]},
	},
	"gr7": {
		"careful": {"lo": 46500.0, "hi": 46500.0, "minutes": [17, 19],
			"note": ["实测整船收入 $123,758，0 事故", "measured, whole ship: $123,758 in, no incidents"]},
		"demolish": {"lo": 0.0, "hi": 0.0, "minutes": [13, 14],
			"note": ["实测整船收入 $14,774，罚款 $15,000，4 次舱室爆泄", "measured, whole ship: $14,774 in, $15,000 in fines, 4 blowouts"]},
	},
}


# the ship still holds something that bites: a pressurised room or vessel, fuel in a line, a
# charged bank, a generator turning
static func _ship_live(g) -> bool:
	var s = g.sys
	if s == null:
		return false
	for n in g.world.rooms:
		if s.P(n) > 5.0:
			return true
	for k in s.vessel_cfg:
		if s.P(k) > 50.0 and not s.vessel_cfg[k].has("dead_leg"):
			return true
	for k in s.fvol:
		if s.fvol[k].amount > 0.02:
			return true
	for tg in s.src_order:
		var src: Dictionary = s.src[tg]
		if (src.kind == "cap" and src.charge > 0.05) or (src.kind == "gen" and src.running):
			return true
	return false


# ---------------------------------------------------------------- 96 号: a hopper of ore (M-14)

# the ore whole: the fines at their price, every chunk as the furnace pays for it (once, at the start)
static func ore_full(g) -> float:
	if g.has_meta("ca_ore_full"):
		return float(g.get_meta("ca_ore_full"))
	var chunks: Array = []
	var sum: float = float(g.ore.fines0) * float(g.ore.cfg.get("price", 0.0))
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.kind == "ore" and not q.gone:
			chunks.append(q)
			sum += g.world.scrap_value(q)
	g.set_meta("ca_ore_chunks", chunks)
	g.set_meta("ca_ore_full", sum)
	return sum


# chunks hauled into a mouth / all
static func _ore_counts(g) -> Vector2i:
	ore_full(g)
	var n := 0
	var out := 0
	for q in g.get_meta("ca_ore_chunks", []):
		n += 1
		if q.gone and q.into != "":
			out += 1
	return Vector2i(out, n)


# in hand: the fines paid as they ran, the chunks a mouth took
static func ore_got(g) -> float:
	ore_full(g)
	var sum: float = float(g.ore.paid)
	for q in g.get_meta("ca_ore_chunks", []):
		if q.gone and q.into != "":
			sum += g.world.scrap_value(q)
	return sum


# still to be had or had: all of it but what poured out of a hole
static func ore_worth(g) -> float:
	return maxf(0.0, ore_full(g) - float(g.ore.spilled) * float(g.ore.cfg.get("price", 0.0)))


# the hopper's rows on the board: the heap, the chunks, each gate; its warnings
static func _ore_board(g, rows: Array, warn: Array) -> float:
	var o = g.ore
	var f := ore_full(g)
	var ow := ore_worth(g)
	var oc := _ore_counts(g)
	rows.append({"name": w("矿仓", "HOPPER"), "text": w("细矿剩 %.1f t · 已收 %s", "%.1f t LEFT · %s IN") % [o.fines, Pal.money(ore_got(g))], "right": Pal.money(ow),
		"grade": ow / maxf(f, 1.0), "alert": o.spilled > 0.05 or o.torn, "done": o.fines <= 0.0})
	rows.append({"name": w("矿块", "CHUNKS"), "text": w("运走 %d / %d 块", "%d OF %d HAULED") % [oc.x, oc.y], "right": "", "grade": 1.0, "alert": false, "done": oc.x >= oc.y})
	for gt in o.cfg.get("gates", []):
		rows.append({"name": str(gt), "text": w("放料门 · %s", "GATE · %s") % o.gate_state(str(gt)), "right": "", "grade": 1.0, "alert": o.jammed(str(gt)), "done": false,
			"fix": w("磁力抓钩挪开门口的矿块", "grapple the chunks off the gate")})
	if o.open_holes() > 0:
		warn.append(w("矿仓破口在料位线下：细矿正在洒落", "A HOLE BELOW THE HEAP: THE FINES ARE POURING OUT"))
	if o.torn:
		warn.append(w("矿仓已撕裂", "THE HOPPER IS TORN"))
	return ow


# ---------------------------------------------------------------- 97 号: a container wall (CF-90)

# a row a bay: its boxes on the wall, its bending (or its prop, or its kink), what its boxes are worth
static func _box_board(g) -> Dictionary:
	var bx = g.boxbeam
	var sup := int(bx.cfg.get("support", 0))
	var rows: Array = []
	var warn: Array = []
	var worth := 0.0
	var pr: Array = bx._propped()
	for b in bx.cfg.bays.size():
		var bay: Array = bx.cfg.bays[b]
		var v := 0.0
		var whole := 0.0
		for t in bay:
			var p = _unit(g, str(t))
			if p != null:
				v += _unit_worth(p)
				whole += float(p.value)
		worth += v
		var side := "fwd" if b < sup else "aft"
		var bent: bool = bx.kinked.has(side) and int(bx.kink_bay.get(side, -1)) == b
		var bd: float = bx.bend(b)
		var state := ""
		if b == sup:
			state = w("船坞夹持", "HELD BY THE BERTH")
		elif bent:
			state = w("已折弯", "KINKED")
		elif pr.has(b):
			state = w("撑杆 %.0f t", "PROP %.0f t") % bx.prop_load(b)
		else:
			state = w("弯曲 %d%%", "BEND %d%%") % int(round(bd * 100.0))
		rows.append({"name": w("第 %d 列", "BAY %d") % (b + 1), "text": w("%d/%d 箱 · %s", "%d/%d · %s") % [bx.fill(b), bay.size(), state],
			"right": Pal.money(v), "grade": v / maxf(whole, 1.0), "alert": bent or bd > 0.85, "done": bx.fill(b) == 0,
			"fix": "" if bent else w("先卸它外侧的箱，或在这一列下放撑杆", "clear the bays outside it first, or prop this one")})
		if not bent and bd > 0.85 and b != sup:
			warn.append(w("第 %d 列弯曲 %d%%：再卸它里侧的箱就会折", "BAY %d AT %d%%: TAKE MORE FROM INSIDE IT AND IT KINKS") % [b + 1, int(round(bd * 100.0))])
	if not bx.unsafe().is_empty():
		warn.append(w("拉杆还绷着：先松花篮螺丝再切", "RODS STILL TIGHT: SLACKEN THE TURNBUCKLES BEFORE YOU CUT"))
	if g.gear != null:
		for u in g.gear.props():
			if float(u.get("over", 0.0)) > 0.0:
				warn.append(w("第 %d 列下的撑杆超载 %.0f t：要折了", "THE PROP UNDER BAY %d IS AT %.0f t: IT WILL BUCKLE") % [int(u.bay) + 1, float(u.load)])
	var tags := _units(g)
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return tags.has(str(d[1])) and EQUIP_DV.has(str(d[0])))
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 4), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short(EQUIP_DV[str(mine[i][0])])], "money": float(mine[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


# the boxes by their state, the losses by cause
static func _box_review(g) -> Dictionary:
	var f := full(g)
	var groups := {"whole": [0, 0.0, 0], "hurt": [0, 0.0, 0], "lost": [0, 0.0, 0]}
	var rolled := 0.0
	var got := 0.0
	for t in _units(g):
		var p = _unit(g, str(t))
		if p == null:
			continue
		var v := _unit_worth(p)
		var k := "lost" if v <= 0.0 else ("whole" if float(p.cond) >= 0.995 else "hurt")
		groups[k][0] += 1
		groups[k][1] += v
		rolled += v
		if p.gone and p.into == "equip" and v > 0.0:
			groups[k][2] += 1
			got += v
	var units: Array = []
	var names := {"whole": ["完好", "WHOLE"], "hurt": ["受损", "DAMAGED"], "lost": ["切坏或进了熔炉", "CUT OR IN THE FURNACE"]}
	for k in ["whole", "hurt", "lost"]:
		if int(groups[k][0]) == 0:
			continue
		units.append({"text": w("%s %d 箱", "%s %d") % [_t(names[k]), int(groups[k][0])], "value": float(groups[k][1]),
			"sub": w("已送设备口 %d 箱", "%d AT THE EQUIPMENT MOUTH") % int(groups[k][2]) if k != "lost" else ""})
	var tags := _units(g)
	var by := {}
	for d in g.devalued:
		if not tags.has(str(d[1])) or not EQUIP_DV.has(str(d[0])):
			continue
		var c: String = EQUIP_DV[str(d[0])]
		if not by.has(c):
			by[c] = {"money": 0.0, "n": 0}
		by[c].money = float(by[c].money) + float(d[2])
		by[c].n = int(by[c].n) + 1
	var first := w("保住的货柜值 %s（满价 %s）；已送走 %s", "The boxes kept are worth %s (whole %s); %s sent") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("一箱没坏。下次可以试试撑杆：顶住外侧，先抢里侧的箱", "Not a box damaged. Next time try the props: hold the outer bays, take the inner ones first") if got > 0.0 else w("货柜还在墙上：送进设备口才算钱", "The boxes are still on the wall: they pay only once in a mouth")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)


# ---------------------------------------------------------------- 98 号: a ship in the hold (LC-140)

# the small ship's equipment: as it is now (worth), or whole as built
static func _small_parts(g, now: bool) -> float:
	var sum := 0.0
	for t in g.nested.cfg.get("pieces", []):
		var p = _unit(g, str(t))
		if p == null:
			continue
		# (its hull and fittings go out with it at the scrap price)
		if p.cls != "equip":
			sum += 0.0 if now and p.gone else g.world.scrap_value(p)
			continue
		sum += _unit_worth(p) if now else float(p.value)
	return sum


# its worth now: the premium as it stands and its equipment, or what it paid once out
static func _small_worth(g) -> float:
	var n = g.nested
	if n.out:
		return _small_got(g)
	return n.bonus_now() + _small_parts(g, true)


static func _small_got(g) -> float:
	for l in g.ledger:
		if str(l[0]) == g.txt("nested_whole") or str(l[0]) == g.txt("nested_parts"):
			return float(l[2])
	return 0.0


static func _small_board(g) -> Dictionary:
	var n = g.nested
	var s = g.sys
	var rows: Array = []
	var warn: Array = []
	var on := func(id): return s.on(str(id))
	var bat := str(n.cfg.get("battery", ""))
	rows.append({"name": w("电池", "BATTERY"), "text": w("小船电池 %s · %s", "%s · %s") % [bat, w("通着", "ON") if on.call(bat) else w("已断", "OFF")], "right": "", "grade": 1.0, "alert": on.call(bat), "done": not on.call(bat),
		"fix": w("拨 %s 断开（在小船舱里）", "%s off (in the small ship's cabin)") % bat})
	var fuel: float = s.fluid(str(n.cfg.get("fuel", "")))
	rows.append({"name": w("燃料", "FUEL"), "text": w("小船燃料 %s", "%s ABOARD") % (w("已抽空", "EMPTY") if fuel <= 0.02 else "%.2f" % fuel), "right": "", "grade": 1.0, "alert": fuel > 0.02, "done": fuel <= 0.02,
		"fix": w("气液回收（5）接小船的燃料口", "hose (5) on the small ship's fuel port")})
	var pr: float = s.P(str(n.cfg.get("room", "")))
	var ph: float = s.P(str(n.cfg.get("hold", ""))) if str(n.cfg.get("hold", "")) != "" else 0.0
	rows.append({"name": w("气压", "AIR"), "text": w("小船舱 %.0f kPa · 货舱 %.0f kPa", "CABIN %.0f kPa · HOLD %.0f kPa") % [pr, ph], "right": "", "grade": 1.0, "alert": pr > 5.0 or ph > 5.0, "done": pr <= 5.0 and ph <= 5.0,
		"fix": w("气液回收（5）接舱室的气口，抽到 5 kPa 以下", "hose (5) on each room's gas port, below 5 kPa")})
	var locks: Array = n.cfg.get("locks", [])
	var held: Array = n.locks_held()
	var next := ""
	for l in locks:
		if held.has(l):
			next = str(l)
			break
	rows.append({"name": w("托架锁", "LOCKS"), "text": w("已解 %d / %d", "%d OF %d OFF") % [locks.size() - held.size(), locks.size()] + (w(" · 下一个 %s", " · NEXT %s") % next if next != "" else ""), "right": "", "grade": 1.0, "alert": false, "done": held.is_empty()})
	rows.append({"name": w("船首门", "BOW DOOR"), "text": w("开", "OPEN") if n.door_open() else w("关", "SHUT"), "right": "", "grade": 1.0, "alert": false, "done": n.door_open()})
	var blk: Array = n.exit_block()
	rows.append({"name": w("出口", "WAY OUT"), "text": w("净空", "CLEAR") if blk.is_empty() else w("%d 件挡路（现场标红）", "%d IN THE WAY (RED)") % blk.size(), "right": "", "grade": 1.0, "alert": not blk.is_empty(), "done": blk.is_empty(),
		"fix": w("切开或拖走标红的件", "cut or haul off the pieces marked red")})
	var state := w("完整", "WHOLE")
	if n.out:
		state = w("已拖出", "OUT")
	elif not n.whole:
		state = w("船壳已开，不再完整", "HULL OPEN: NOT WHOLE")
	elif n.lurched:
		state = w("撬起撞过门，溢价减半", "LURCHED: HALF THE PREMIUM")
	var worth := _small_worth(g)
	rows.append({"name": w("整船", "WHOLE"), "text": state + w(" · 溢价 %s", " · PREMIUM %s") % Pal.money(n.bonus_now()), "right": Pal.money(worth), "grade": worth / maxf(full(g), 1.0), "alert": not n.whole or n.lurched, "done": n.out})
	if not n.out:
		var why: Array = n.blockers()
		if not why.is_empty() and why.size() <= 3:
			warn.append(w("绞盘还拖不了：", "THE WINCH CAN'T YET: ") + "、".join(why.map(func(k): return g.txt("nb_" + k))))
	var recent: Array = []
	var mine: Array = g.devalued.filter(func(d): return str(d[0]) in ["loss_nested_lurch", "loss_nested_whole"])
	for i in range(mine.size() - 1, maxi(-1, mine.size() - 3), -1):
		recent.append({"text": "%s · %s" % [str(mine[i][1]), cause_short("lurch" if str(mine[i][0]) == "loss_nested_lurch" else "not_whole")], "money": float(mine[i][2])})
	return {"name": _t(spec(g).name), "worth": worth, "full": full(g), "warn": warn, "rows": rows, "recent": recent}


static func _small_review(g) -> Dictionary:
	var n = g.nested
	var f := full(g)
	var got := _small_got(g) if n.out else 0.0
	var rolled := _small_worth(g)
	var units: Array = []
	var head := w("整船拖出", "OUT WHOLE") if n.out and n.whole else (w("拖出，但已不完整", "OUT, NOT WHOLE") if n.out else w("还在货舱里", "STILL IN THE HOLD"))
	units.append({"text": "%s" % head, "value": rolled, "sub": w("溢价 %s · 设备 %s", "PREMIUM %s · EQUIPMENT %s") % [Pal.money(n.bonus_now()), Pal.money(_small_parts(g, true) if not n.out else maxf(0.0, got - n.bonus_now()))]})
	var by := {}
	for d in g.devalued:
		var k := ""
		if str(d[0]) == "loss_nested_lurch":
			k = "lurch"
		elif str(d[0]) == "loss_nested_whole":
			k = "not_whole"
		elif n.cfg.get("pieces", []).has(str(d[1])) and EQUIP_DV.has(str(d[0])):
			k = EQUIP_DV[str(d[0])]
		if k == "":
			continue
		if not by.has(k):
			by[k] = {"money": 0.0, "n": 0}
		by[k].money = float(by[k].money) + float(d[2])
		by[k].n = int(by[k].n) + 1
	var first := w("小船值 %s（满价 %s）；已到手 %s", "The ship is worth %s (whole %s); %s in hand") % [Pal.money(rolled), Pal.money(f), Pal.money(got)]
	var clean := w("整船完好拖出，一分溢价没丢", "Out whole, not a dollar of the premium lost") if n.out and n.whole and not n.lurched else w("小船还没拖出来：安全化、按序解锁、开门、清出口，再开绞盘", "Not out yet: make it safe, the locks in order, the door, the way out, then the winch")
	return _finish_review(g, f, rolled, got, units, by, first, clean, clean)
