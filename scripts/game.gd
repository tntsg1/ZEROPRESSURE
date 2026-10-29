class_name Game
extends Node2D
signal load_received(keys: Array, zone: String, value: float, job_id: String)
# A contract: the dock, the ship, the drone and everything that happens
# between them. Holds the camera, routes input, reacts to every event the
# systems raise (cuts, arcs, leaks, blowouts, recoveries) and keeps the books.
# A career contract (Game.contract) also settles with the career at the end.

const CONTRACT_FEE := 9000.0     # a contract that names no fee of its own
const DRONE_FEE := 2000.0
const CAM_ZOOM := 1.65
const SHIP_CENTER := Vector2(21.0 * 48.0, 0.0)

var world: World
var sys: Systems
var mech: Mech                # magnets and preloaded arms some ship types carry
var munitions: Munitions      # rounds that cook off, knock off and set each other off (PT-34)
var rails: Rails              # cargo held on lock rails (JD-38, RO-128)
var atmos                     # air that isn't plain air: oxygen-rich halls (HB-86), scripts/atmos.gd
var coldchain                 # cold holds that have to stay cold (CL-104), scripts/coldchain.gd
var vault                     # vault doors on two lock circuits and a release (ES-112), scripts/vault.gd
var media                     # look-alike media in crossed branches (FL-116), scripts/media.gd
var furnace                   # a furnace core shut down but not cool (MF-126), scripts/furnace.gd
var drones                    # drones parked live on their own packs (CV-138), scripts/drones.gd
var tanknet                   # a cross-connected propellant network (VT-80), scripts/tanknet.gd
var liner                     # a liner's escape pods and observation glass (PS-12), scripts/liner.gd
var boxbeam                   # a container wall that is the ship's beam (CF-90), scripts/boxbeam.gd
var sail                      # a light sail held flat by its stays (SA-200), scripts/sail.gd
var reactor                   # a shut-down reactor's dose field (NR-95), scripts/reactor.gd
var softshell                 # inflatable bags on a rigid spine (IH-55), scripts/softshell.gd
var train                     # a train of modules on couplers (MT-140), scripts/train.gd
var flywheel                  # a mass driver still spinning (MD-160), scripts/flywheel.gd
var rings                     # habitat rings still turning (ARK-01), scripts/rings.gd
var spine                     # a spine carrying the tail (ARK-01), scripts/spine.gd
var workday                   # a job of several working days (ARK-01), scripts/workday.gd
var boiloff                   # cryogenic tanks boiling off (HG-170), scripts/boiloff.gd
var liquids                   # liquid adrift in free fall (every leak and spill), scripts/liquids.gd
var combustion                # what burns, with what, and how hard, scripts/combustion.gd
var drillstring               # a drill string in its derrick (DR-150), scripts/drillstring.gd
var nested                    # a ship carried inside the ship (LC-140), scripts/nested.gd
var waterball                 # a water ball in its net (BL-88), scripts/waterball.gd
var magnets                   # superconducting magnets (FX-70), scripts/magnets.gd
var optics                    # a telescope's primary mirror (OB-90), scripts/optics.gd
var immersion                 # racks in dielectric fluid, drives under custody (DC-84), scripts/immersion.gd
var thermal                   # a hull still hot from the sun (EV-55), scripts/thermal.gd
var composite                 # a composite hull that smokes when cut in air (ST-40), scripts/composite.gd
var dilution                  # a dilution refrigerator still at millikelvin (QC-30), scripts/dilution.gd
var tether                    # a tethered pair still turning (TB-180), scripts/tether.gd
var sandwich                  # a cargo module clamped between two hulls (CH-110), scripts/sandwich.gd
var ice                       # a hull of ice (IC-120), scripts/ice.gd
var bio: Bio                  # biological contamination some ship types carry
var ore: Ore                  # a hopper of loose ore some ship types carry
var cryo: Cryo                # cryogenic tanks some ship types carry
var plan: WorkPlan            # the work plan of this ship type, recorded and replayed
var auto_paused := false      # the operator stopped the berth's machines (arm, hauler, plan)
var mouths := {}              # mouth zone -> the machine dropping into it now
var dock: Dock
var fx: Fx
var look: Look                # 91 号: the picture layer (scripts/look.gd)
var drone: Drone
var tools: Tools
var hud: Hud
var blueprint: Blueprint
var sfx: Sfx
var cam: Camera2D
var bot = null               # tests drive the game through this dict
var ship_id := "gr7"         # which ship file this contract is about
var ship: Dictionary = {}
static var start_ship := ""  # the title screen picks the next ship (training, exam, contract)
static var course_chain: Array = []   # special courses still to run, back to back (scripts/codex.gd)
static var course_then := ""          # after them: "contract" (the one waiting on them), "contract_loadout" (its loadout page first) or "terminal"
static var loadout_after_course := false   # the terminal opens the waiting contract's loadout page (25 号)
static var contract: Dictionary = {}   # the career's contract to play next (empty: a contract outside any career)
var job: Dictionary = {}     # the career contract this scene plays
var fee := CONTRACT_FEE
var career_result: Dictionary = {}     # the settlement with the career, once the contract is over
var used: Dictionary = {}    # consumables used up on this contract (the career's stock drops at settlement)
# what the operator checked with their own hands on this ship (factory names only):
# pieces inspected or handled, ports read, lines traced, controls worked. Goes to
# the career's engineering archive at the end; the next ship of the type shows it.
var verified := {"pieces": {}, "ports": {}, "lines": {}, "ctrls": {}}
var _factory := {}           # the type's factory names: what can go in the archive
# The operation log (roadmap 2.9): every action counted under what it is.
# Repetitive hand work: undoing bolts and locks, unplugging, doors, hauling
# ordinary scrap, measuring the same point again, patching the drone.
# Engineering decisions: the first reading of a point, isolating (switches,
# valves, stops), choosing to hose, cutting (whether to cut and where to
# segment), sending whole equipment or hazards to their mouth, firing a
# breaching ring, picking the contract, buying kit. The machine's work (the
# recovery arm) is counted apart and is nobody's hand work.
const OP_CAT := {
	"unfix": "manual", "unplug": "manual", "door": "manual", "haul_scrap": "manual", "remeasure": "manual", "repair": "manual",
	"measure": "decision", "isolate": "decision", "hose": "decision", "cut": "decision", "deliver_equip": "decision",
	"deliver_hazard": "decision", "ring": "decision", "pick_contract": "decision", "buy": "decision", "deploy": "decision",
	"arm_haul": "machine",     # the recovery arm, or a mouth pulling in what drifted close
	"plan": "machine",         # a step of a work plan the berth ran
}
var ops := {}                # kind -> count
var _measured := {}
var done_t := 0.0
var cam_pan := Vector2.ZERO
var rmb_down := false
var rmb_moved := 0.0
var overview := false
var port_view := false       # the whole of Zero Pressure Port in view (G6, key O at the berth)
var port_access
var port_structure          # the port's walls, doors and consoles (scripts/port_structure.gd)
var boat                    # the work boat outside the gate (scripts/workboat.gd)
var boat_tow = null         # 87-6: its tow line (scripts/boat_tow.gd)
var cargo_floor             # the cargo district's counter, crates and rack mouths (scripts/cargo_floor.gd, 85 号)
var mill_line               # the rolling mill in the processing district (scripts/mill_line.gd, 85 号)
var tram                    # the rail shuttle through the corridors (scripts/tram.gd)
var exchange_logistics
var industrial_heat
var plant                    # the processing district's own works (scripts/process_plant.gd, 30 号)
var freight_pier             # the freight pier and the shipping clock (scripts/freight_pier.gd, 31 号)
var gas_works = null         # 76 号: the gas line outside the processing district (scripts/gas_works.gd)
var trade_hall               # the three companies' counters and the quote board (scripts/trade_hall.gd, 38 号)
var industrial_sort
var prelude_on := false       # the belt prelude is on screen: the berth's clock waits (28 号)
var guide: Guide              # the on-site task guide (scripts/guide.gd, 27 号)
var backdrop: Backdrop        # the stars, the planet and the port behind the berth (scripts/backdrop.gd)
var industrial_assay          # the assay bench beside the sorting desk (scripts/industrial_assay.gd)
var training := false        # the ship file is a training course, not a contract
var belt := false            # the asteroid-belt prologue: no berth, no port (scripts/prologue.gd, 32 号)
var prologue
var tutorial: Tutorial
var assist: Assist
var codex: Codex              # first meetings and the book (scripts/codex.gd)
var codex_hud: CodexHud
var story: Story
var exam: Exam
var settings_panel: SettingsPanel
var arm: RecoveryArm
var hauler: Hauler
var hauler2: Hauler             # the second hauling drone (roadmap 4.4)
var crane: Crane                # the heavy crane (roadmap 4.4)
var keepout: Array = []         # Rect2 (px): keep-out zones the operator set; no machine goes in
var consoles: Consoles          # the berth's two computers: shop and berth management, on site
var gear: Gear                  # field gear out on this job: deployable tools, drone modules (scripts/gear.gd)
var parts_in: Array = []        # whole equipment shelved for the berth's repairs this job (scripts/repair.gd)
var parts_value := 0.0          # what it was worth (counted in the recovery, not paid in cash)
var material_receipts: Array = [] # actual G5 raw intake, pending atomic career settlement
var receiver_commits: Dictionary = {} # every piece of a G5 mixed receipt, including sold goods
var material_recovery_value := 0.0 # retained value counts as recovery, never cash
var structure_t := 0.0          # metal through the furnace this job, tonnes (structure for repairs)
var console_ui: Control = null  # the terminal page open over the berth
var order_review: Control = null
var order_review_deferred := false
var modal_release := false     # the click closing a preview must not fire a tool
var settlement_retry_required := false
var work_order = null
const KEEPOUT_MAX := 3
const KEEPOUT_SIZE := Vector2(8.0, 8.0)   # m
var radio := Radio.new()      # Liang and the berth terminal
var player_moved := false
var warp := false            # time runs x4 while the player holds =
const WARP := 4.0
const REST_SCRAP := 0.6       # an early end: what is left fetches this share of its scrap value
var testing := false

var state := "intro"         # intro play ending (… "towin": a hulk brought in, 63 号)
var tow_traffic = null
var state_t := 0.0
var paused_sim := false
var dev_overlay_open := false
var menu_open := false
var contract_open := false

# camera
var cam_pos := Vector2.ZERO
var cam_vel := Vector2.ZERO
var zoom_target := CAM_ZOOM
var zoom_now := 0.62
var trauma := 0.0
var punch := Vector2.ZERO
var cam_override = null      # Vector2 world point (intro / ending)
var works_site = null         # the crew at work (scripts/works_site.gd), in the dock's space
var crew = null               # 92 号: the crew's drones doing the work for real (scripts/crew.gd)
var port_tour = null          # the port, district by district (scripts/port_tour.gd, 83 号)
var arrival := {}             # a hulk just towed home: {id, name, held}, shown until the terminal is opened on it
var plan_focus = null        # temporary local inspection, cancelled by pilot input
var plan_focus_t := 0.0
var zoom_override := -1.0

# input edges
var prev_lmb := false
var ring_armed := false     # 7 readies the breaching ring: it snaps to the nearest member, a click fires it
var ring_aim: Dictionary = {}   # where it would go this frame (ring_target)
var ring_eat := false       # the press that fired (or cancelled) the ring never reaches the tools
var ring_wait := false      # readied by a click: that click has to end first
var prev_keys := {}
var aim := Vector2.ZERO

# economy
var income_equip := 0.0
var income_metal := 0.0
var income_hazard := 0.0
var losses := 0.0
var loss_lines: Array = []   # [text_key, amount]
var devalued: Array = []     # [reason key, tag, amount]: value knocked off what could have been sold
var mandatory_lost := {}     # tag -> reason key: a named piece that can no longer be delivered whole
var income_rest := 0.0       # an early end: what was left, taken as scrap at a discount
var mandatory_ok := {}     # tag -> recovered intact into the equipment bay
var time_by := {}           # where the contract's time went (V2 2.9): measure cut maintain haul fly wait menu
var changed := {}           # what has changed on site since the contract began: "l:q1", "c:K-G" (old notes on it are void)
var must_value := {}         # named pieces delivered whole: tag -> value (for the named-equipment bonus)
var incidents: Array = []  # [playtime, kind, detail]: what went wrong and when (the accident review reads it)
var _mand: Array = []
var _mand_zh := -1
var feed: Array = []         # [text, amount, t] recent income lines for the HUD
var drone_respawn := -1.0
var hurt_cd := {}
var hints_seen := {}
var hints_on := true
var messages: Array = []     # [key, world pos, t, text]
var reveal_count := 0
var ship_offset := 60.0 * 48.0
# between contracts the berth stands empty (player 2026-10-18: "after a job,
# don't go back to the menu, go back into the berth"): the finished ship is towed
# out, the empty berth (ships/berth.json) takes over with the drone where it was
static var carry := {}
static var exchange_requested := false
const TOW_T := 2.6
var ended := false
var slowmo := 0.0
var zoom_kick := 0.0           # 91 号: the view drawn in toward a big piece coming free
var kick_at := Vector2.INF
var hitstop_t := 0.0
var playtime := 0.0
var ledger: Array = []        # [label, zone, value]
var autosave_t := 0.0
var best := {}
var nuke = null               # the core's heart cut: the detonation and its cinematic (scripts/nuke.gd)
var nuked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# a scene left in a hit-stop or the slow motion would hand its clock on to this one (the clock
	# is the engine's, not the scene's): every game starts at full speed
	Look.time_k(1.0)
	testing = _is_test()
	Look.mark("start")
	Txt.load_settings(testing)
	hints_on = Txt.hints
	fx = Fx.new()
	fx.game = self
	var bg := Backdrop.new()
	bg.game = self
	add_child(bg)
	backdrop = bg
	world = World.new()
	world.game = self
	dock = Dock.new()
	dock.game = self
	dock.world = world
	add_child(dock)
	add_child(world)
	if start_ship != "":
		ship_id = start_ship
		start_ship = ""
	# the assessment draws one of its four problems
	if ship_id == "exam":
		ship_id = Exam.pick()
	job = contract
	contract = {}
	# a contract plays its own ship type
	if job.get("ship", "") != "" and not ship_id in ["exam"]:
		ship_id = job.ship
	var data := {}
	if SaveGame.load_requested and (not testing or SaveGame.allow_test):
		data = SaveGame.read(SaveGame.file_for_ship(Ship.load_data(ship_id)))
		# a save left over from another contract of the career is not this one
		if not job.is_empty() and data.has("job") and data.job.get("id", "") != job.get("id", ""):
			data = {}
		# nor a save of some other ship (the empty berth's, say) for a contract on this one
		if not job.is_empty() and not data.is_empty() and str(job.get("ship", "")) != "" and str(data.get("ship", "")) != str(job.ship):
			data = {}
	SaveGame.load_requested = false
	if not data.is_empty():
		ship_id = data.get("ship", "gr7")
		if data.has("job"):
			job = data.job
	fit_skills()
	ship = Ship.load_data(ship_id)
	training = ship.get("training", false)
	belt = ship.get("belt", false)
	if training or ship.has("exam"):
		job = {}
	if job.has("variant"):
		ship = Variant.make(ship, job)
	fee = float(job.get("fee", ship.get("fee", CONTRACT_FEE)))
	var base := Ship.load_data(ship_id)
	for pd in base.get("pieces", []):
		if pd.get("tag", "") != "":
			_factory["p:" + pd.tag] = true
	for c in base.get("ctrls", []):
		_factory["c:" + c.id] = true
	for l in base.get("lines", []):
		_factory["l:" + l.id] = true
	# the berth: extended once the career has paid for it, or for a ship too long for the standard one
	var ext := Ship.extent(ship)
	berth_ext = ext
	prev_shape = {"len": Dock.floor_end, "lift": Dock.LIFT, "drop": Dock.DROP}
	berth_len = Dock.length_for(float(ship.get("length", 0.0)), _upgrades_for_berth())
	Dock.configure(berth_len, ext.x, ext.y)
	if has_upgrade("port2"):
		Dock.add_port2()
	dock.set_ship(ship)
	if not data.is_empty() and SaveGame.apply(self, data):
		Ship.rooms(world, ship)
	else:
		data = {}
		Ship.build(world, ship)
	Look.mark("ship_build")
	sys = Systems.new()
	add_child(sys)
	world.ore_price = float(ship.get("ore", {}).get("price", 0.0))
	world.finalize(float(ship.get("value", {}).get("metal", 12000.0)))
	# 78 号 P0-1: what the whole ship can actually pay — every piece of equipment whole, all its
	# metal, gas and fluids. Some authored "total"s fall short of it (H-22: 140,000 against
	# 132,800 of equipment + 9,000 of metal), so a clean strip read over 100 %.
	full_value = float(ship.get("value", {}).get("metal", 12000.0)) + float(ship.get("gas", {}).get("value", 0.0))
	for fv in ship.get("fluids", {}).get("value", {}).values():
		full_value += float(fv)
	# 87-4: the sail furled whole, the most a light sail can pay
	full_value += preload("res://scripts/sail.gd").asset_full(ship)
	for id in world.order:
		if world.pieces[id].cls == "equip":
			full_value += float(world.pieces[id].value)
		# 96 号: the hopper's chunks at the ore price, and its fines (they were never counted)
		elif world.pieces[id].kind == "ore" and world.ore_price > 0.0:
			full_value += world.scrap_value(world.pieces[id])
	full_value += float(ship.get("ore", {}).get("fines", 0.0)) * world.ore_price
	Look.mark("finalize_value")
	sys.setup(self, world, ship)
	Look.mark("sys_setup")
	munitions = Munitions.new()
	munitions.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(munitions)
	munitions.setup(self, ship)
	rails = Rails.new()
	rails.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rails)
	rails.setup(self, ship)
	atmos = preload("res://scripts/atmos.gd").new()
	add_child(atmos)
	atmos.setup(self, ship)
	coldchain = preload("res://scripts/coldchain.gd").new()
	coldchain.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(coldchain)
	coldchain.setup(self, ship)
	vault = preload("res://scripts/vault.gd").new()
	add_child(vault)
	vault.setup(self, ship)
	media = preload("res://scripts/media.gd").new()
	media.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(media)
	media.setup(self, ship)
	furnace = preload("res://scripts/furnace.gd").new()
	furnace.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(furnace)
	furnace.setup(self, ship)
	drones = preload("res://scripts/drones.gd").new()
	drones.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(drones)
	drones.setup(self, ship)
	tanknet = preload("res://scripts/tanknet.gd").new()
	tanknet.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tanknet)
	tanknet.setup(self, ship)
	liner = preload("res://scripts/liner.gd").new()
	liner.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(liner)
	liner.setup(self, ship)
	boxbeam = preload("res://scripts/boxbeam.gd").new()
	boxbeam.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(boxbeam)
	boxbeam.setup(self, ship)
	sail = preload("res://scripts/sail.gd").new()
	sail.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sail)
	sail.setup(self, ship)
	reactor = preload("res://scripts/reactor.gd").new()
	reactor.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(reactor)
	reactor.setup(self, ship)
	softshell = preload("res://scripts/softshell.gd").new()
	softshell.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(softshell)
	softshell.setup(self, ship)
	train = preload("res://scripts/train.gd").new()
	train.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(train)
	train.setup(self, ship)
	flywheel = preload("res://scripts/flywheel.gd").new()
	flywheel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(flywheel)
	flywheel.setup(self, ship)
	rings = preload("res://scripts/rings.gd").new()
	rings.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(rings)
	rings.setup(self, ship)
	spine = preload("res://scripts/spine.gd").new()
	spine.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spine)
	spine.setup(self, ship)
	workday = preload("res://scripts/workday.gd").new()
	workday.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(workday)
	workday.setup(self, ship)
	liquids = preload("res://scripts/liquids.gd").new()
	world.add_child(liquids)
	liquids.setup(self)
	combustion = preload("res://scripts/combustion.gd").new()
	world.add_child(combustion)
	combustion.setup(self)
	boiloff = preload("res://scripts/boiloff.gd").new()
	boiloff.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(boiloff)
	boiloff.setup(self, ship)
	drillstring = preload("res://scripts/drillstring.gd").new()
	drillstring.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(drillstring)
	drillstring.setup(self, ship)
	nested = preload("res://scripts/nested.gd").new()
	nested.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(nested)
	nested.setup(self, ship)
	waterball = preload("res://scripts/waterball.gd").new()
	waterball.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(waterball)
	waterball.setup(self, ship)
	magnets = preload("res://scripts/magnets.gd").new()
	magnets.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(magnets)
	magnets.setup(self, ship)
	optics = preload("res://scripts/optics.gd").new()
	optics.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(optics)
	optics.setup(self, ship)
	immersion = preload("res://scripts/immersion.gd").new()
	immersion.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(immersion)
	immersion.setup(self, ship)
	thermal = preload("res://scripts/thermal.gd").new()
	thermal.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(thermal)
	thermal.setup(self, ship)
	composite = preload("res://scripts/composite.gd").new()
	composite.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(composite)
	composite.setup(self, ship)
	dilution = preload("res://scripts/dilution.gd").new()
	dilution.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(dilution)
	dilution.setup(self, ship)
	tether = preload("res://scripts/tether.gd").new()
	tether.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tether)
	tether.setup(self, ship)
	sandwich = preload("res://scripts/sandwich.gd").new()
	sandwich.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sandwich)
	sandwich.setup(self, ship)
	ice = preload("res://scripts/ice.gd").new()
	ice.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ice)
	ice.setup(self, ship)
	mech = Mech.new()
	add_child(mech)
	mech.setup(self, ship)
	bio = Bio.new()
	add_child(bio)
	bio.setup(self, ship)
	ore = Ore.new()
	world.add_child(ore)
	ore.setup(self, ship)
	cryo = Cryo.new()
	add_child(cryo)
	cryo.setup(self, ship)
	world.piece_freed.connect(on_body_freed)
	add_child(fx)
	Look.mark("sub_tether_ice_mech")
	blueprint = Blueprint.new()
	blueprint.game = self
	add_child(blueprint)
	drone = Drone.new()
	drone.game = self
	drone.assist = Txt.assist if bot == null else bot.get("assist", true)
	drone.alive = false
	add_child(drone)
	drone.global_position = Dock.BAY * Geom.M + Vector2(-40, 0)
	Look.mark("sub_blueprint_drone")
	tools = Tools.new()
	tools.game = self
	tools.world = world
	world.piece_reframed.connect(tools.on_piece_reframed)
	tools.sys = sys
	tools.drone = drone
	add_child(tools)
	# 87-3: the grapple's range mode
	tools.multi = preload("res://scripts/multi_grab.gd").new()
	tools.multi.setup(tools)
	Look.mark("sub_tools")
	gear = Gear.new()
	gear.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(gear)
	gear.setup(self)
	Look.mark("modules")
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 10
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	Settings.env = env
	for lv in 7:
		env.set_glow_level(lv, [0.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.0][lv])
	we.environment = env
	add_child(we)
	# 91 号: lights, the full-screen pass, the far belt, the notes near the cursor
	Look.mark("sub_env")
	look = Look.new()
	add_child(look)
	look.setup(self)
	Settings.look = look
	Look.mark("sub_look")
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)
	cam.make_current()
	Look.mark("sub_cam")
	sfx = Sfx.new()
	sfx.game = self
	add_child(sfx)
	radio.sfx = sfx
	Look.mark("env_cam_sfx")
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	Look.mark("hud")
	codex = Codex.new()
	codex.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(codex)
	codex.setup(self)
	codex_hud = CodexHud.new()
	codex_hud.game = self
	add_child(codex_hud)
	# the industrial recovery arm on the boom, once the berth has bought it
	if has_upgrade("hauler"):
		hauler = Hauler.new()
		hauler.game = self
		hauler.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hauler)
	if hauler != null and has_upgrade("hauler2"):
		hauler2 = Hauler.new()
		hauler2.game = self
		hauler2.who = "hauler2"
		hauler2.home_off = Vector2(2.2, -1.6)
		hauler2.queue = hauler.queue
		hauler2.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hauler2)
	if career() and Career.usable():
		consoles = Consoles.new()
		consoles.game = self
		add_child(consoles)
		# 65 号: the crew building a repair, seen where it works
		var site = preload("res://scripts/works_site.gd").new()
		site.game = self
		dock.add_child(site)
		works_site = site
		# 92 号: and the crew that builds it for real
		crew = preload("res://scripts/crew.gd").new()
		crew.game = self
		dock.add_child(crew)
		if in_berth():
			port_access = load("res://scripts/port_access.gd").new()
			port_access.game = self
			add_child(port_access)
			port_structure = PortStructure.new()
			port_structure.game = self
			add_child(port_structure)
			# 85 号: the rolling mill standing in the processing district
			mill_line = preload("res://scripts/mill_line.gd").new()
			mill_line.game = self
			add_child(mill_line)
			# 85 号: the cargo district's receiving counter, crates and rack mouths
			cargo_floor = preload("res://scripts/cargo_floor.gd").new()
			cargo_floor.game = self
			add_child(cargo_floor)
			boat = WorkBoat.new()
			boat.game = self
			add_child(boat)
			# 87-6: the boat's tow line and the derelict section it can clear
			boat_tow = preload("res://scripts/boat_tow.gd").new()
			boat_tow.game = self
			add_child(boat_tow)
			tram = Tram.new()
			tram.game = self
			add_child(tram)
			# 63 号: the tugs bringing hulks home, seen
			tow_traffic = preload("res://scripts/tow_traffic.gd").new()
			tow_traffic.game = self
			add_child(tow_traffic)
	if has_upgrade("crane"):
		crane = Crane.new()
		crane.game = self
		crane.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(crane)
	if has_upgrade("arm"):
		arm = RecoveryArm.new()
		arm.game = self
		arm.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(arm)
	Look.mark("port_props")
	plan = WorkPlan.new()
	plan.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(plan)
	plan.setup(self)
	work_order = load("res://scripts/work_orders.gd").new(self)
	if work_order.active(): plan.packages.protected = work_order.preserve_keys()
	if ship.has("exam"):
		exam = Exam.new()
		exam.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(exam)
		exam.setup(self)
		var eh := ExamHud.new()
		eh.game = self
		add_child(eh)
	if not training and exam == null:
		assist = Assist.new()
		assist.game = self
		assist.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(assist)
	if ship.has("story") and Story.ON:
		story = Story.new()
		story.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(story)
		story.setup(self)
		var sh := StoryHud.new()
		sh.game = self
		add_child(sh)
	if belt:
		# out in the belt: the berth is not here; the prologue teaches as it goes
		dock.visible = false
		dock.bounds_body.collision_layer = 0
		prologue = preload("res://scripts/prologue.gd").new()
		prologue.game = self
		add_child(prologue)
		# 68 号 §2: a new career sees the opening first, once
		if Career.usable() and not Career.data.is_empty() and not Career.data.get("seen", {}).has("intro") and (not testing or opening_in_tests):
			show_opening.call_deferred(true)
	elif training:
		tutorial = Tutorial.new()
		tutorial.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(tutorial)
		tutorial.setup(self, ship_id)
		var th := TutorialHud.new()
		th.game = self
		add_child(th)
	for n in [dock, world, sys, fx, blueprint, drone, tools]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	Look.mark("plan_story")
	var dev := DevPanel.new()
	dev.game = self
	dev.where = "game"
	add_child(dev)
	# last child: it sees input first while open
	settings_panel = SettingsPanel.new()
	settings_panel.testing = testing
	add_child(settings_panel)
	Settings.apply_video(get_viewport())
	world.position.x = ship_offset
	cam_pos = Vector2(21.0 * 48.0, -0.5 * 48.0)
	zoom_now = 0.62
	state = "intro"
	state_t = 0.0
	if data.is_empty():
		_belt_prelude.call_deferred()
	# 80 号 Q5: a TUG-001 job loaded part-way gets its guide back, at the step it is at
	_first_ship_coach.call_deferred()
	if belt:
		_end_intro.call_deferred()
		# the berth's machinery (field, mouths, suction) is not out here
		dock.process_mode = Node.PROCESS_MODE_DISABLED
	if not data.is_empty():
		SaveGame.apply_late(self, data)
		if data.has("munitions"):
			munitions.load_state(data.munitions)
		if data.has("rails"):
			rails.load_state(data.rails)
		if data.has("atmos") and not (data.atmos as Dictionary).is_empty():
			atmos.load_state(data.atmos)
		if data.has("cold"):
			coldchain.load_state(data.cold)
		if data.has("media"):
			media.load_state(data.media)
		if data.has("furnace"):
			furnace.load_state(data.furnace)
		if data.has("drones"):
			drones.load_state(data.drones)
		if data.has("tanknet"):
			tanknet.load_state(data.tanknet)
		if data.has("liner"):
			liner.load_state(data.liner)
		if data.has("boxbeam"):
			boxbeam.load_state(data.boxbeam)
		if data.has("sail"):
			sail.load_state(data.sail)
		if data.has("reactor"):
			reactor.load_state(data.reactor)
		if data.has("softshell"):
			softshell.load_state(data.softshell)
		if data.has("train"):
			train.load_state(data.train)
		if data.has("flywheel"):
			flywheel.load_state(data.flywheel)
		if data.has("rings"):
			rings.load_state(data.rings)
		if data.has("spine"):
			spine.load_state(data.spine)
		if data.has("workday") and workday.active():
			workday.load_state(data.workday)
		if data.has("boiloff"):
			boiloff.load_state(data.boiloff)
		if data.has("drillstring"):
			drillstring.load_state(data.drillstring)
		if data.has("nested"):
			nested.load_state(data.nested)
		if data.has("waterball"):
			waterball.load_state(data.waterball)
		if data.has("magnets"):
			magnets.load_state(data.magnets)
		if data.has("optics"):
			optics.load_state(data.optics)
		if data.has("immersion"):
			immersion.load_state(data.immersion)
		if data.has("thermal"):
			thermal.load_state(data.thermal)
		if data.has("composite"):
			composite.load_state(data.composite)
		if data.has("dilution"):
			dilution.load_state(data.dilution)
		if data.has("tether"):
			tether.load_state(data.tether)
		if data.has("sandwich"):
			sandwich.load_state(data.sandwich)
		if data.has("ice"):
			ice.load_state(data.ice)
		if data.has("mech"):
			mech.load_state(data.mech)
		if data.has("bio"):
			bio.load_state(data.bio)
		if data.has("ore"):
			ore.load_state(data.ore)
		if data.has("cryo"):
			cryo.load_state(data.cryo)
		if data.has("plan") and plan != null:
			plan.load_state(data.plan)
		if data.has("gear") and gear != null:
			gear.load_state(data.gear)
		if data.has("work_order") and work_order != null:
			work_order.load_state(data.work_order)
		for r in data.get("keepout", []):
			keepout.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		if tutorial != null and data.has("tutorial"):
			tutorial.load_state(data.tutorial)
		if story != null and data.has("story"):
			story.load_state(data.story)
		if SaveGame.recovered:
			hud.show_hint(txt("save_recovered"))
		world.position.x = 0.0
		state = "play"
		drone.alive = true
		drone.spawn_t = 0.0
		cam_pos = drone.global_position
		zoom_now = CAM_ZOOM
	else:
		# a career contract starts with the choices made at the terminal
		if job.has("reg"):
			log_op("pick_contract")
		for k in job.get("desk", {}):
			log_op(k, int(job.desk[k]))
		if story != null:
			story.on_arrive()
		if bot != null and bot.get("skip_intro", false):
			_end_intro()
	Look.mark("panels_save")
	if in_berth():
		_enter_berth()
	if data.is_empty():
		_maybe_build()
	if in_berth() and build == null:
		_maybe_show_repairs()
	Look.mark("enter_berth")
	if career() and Career.usable():
		exchange_logistics = preload("res://scripts/exchange_logistics.gd").new()
		exchange_logistics.game = self
		exchange_logistics.restore_field(data.get("exchange_cargo",{}))
		add_child(exchange_logistics)
		trade_hall = preload("res://scripts/trade_hall.gd").new()
		trade_hall.game = self
		add_child(trade_hall)
		# 76 号: the gas line's works and the supply berth
		gas_works = preload("res://scripts/gas_works.gd").new()
		gas_works.game = self
		add_child(gas_works)
		freight_pier = preload("res://scripts/freight_pier.gd").new()
		freight_pier.game = self
		freight_pier.yard = exchange_logistics
		add_child(freight_pier)
		# the company's works stand in the processing district; the services below run on them
		plant = preload("res://scripts/process_plant.gd").new()
		plant.game = self
		add_child(plant)
		industrial_heat = preload("res://scripts/industrial_heat.gd").new()
		industrial_heat.game = self
		industrial_heat.restore_field(data.get("industrial_cargo",{}))
		add_child(industrial_heat)
		industrial_sort = preload("res://scripts/industrial_sort.gd").new()
		industrial_sort.game = self
		industrial_sort.restore_field(data.get("sorting_cargo",{}))
		add_child(industrial_sort)
		industrial_assay = preload("res://scripts/industrial_assay.gd").new()
		industrial_assay.game = self
		add_child(industrial_assay)
		if in_berth():
			plant.catch_up.call_deferred()
		guide = Guide.new()
		guide.game = self
		add_child(guide)
	Look.mark("career_services")


# repairs made at the terminal since the berth was last in view: shown now (scripts/repair_show.gd)
func _maybe_show_repairs() -> void:
	if not career() or not Career.usable() or bot != null or (testing and not cine_in_tests):
		return
	var pend: Array = Career.data.get("repaired_pending", [])
	if pend.is_empty():
		return
	build = RepairShow.new()
	dock.add_child(build)
	build.setup(self, pend)
	Career.data.repaired_pending = []
	Career.save()
	_after_build = state
	state = "build"
	state_t = 0.0


func _is_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.begins_with("res://tests/") or a.find("tests/") >= 0:
			return true
	return bot != null


func txt(key: String) -> String:
	return Txt.t(key)


# the contract's named items: [tag, name text], in ship-file order
func mandatory_items() -> Array:
	if _mand_zh == int(Txt.zh):
		return _mand
	_mand = []
	_mand_zh = int(Txt.zh)
	for pd in ship.get("pieces", []):
		if pd.get("mandatory", false):
			_mand.append([pd.get("tag", ""), txt(pd.get("name_key", ""))])
	return _mand


func all_mandatory_ok() -> bool:
	for it in mandatory_items():
		if not mandatory_ok.get(it[0], false):
			return false
	return true


func set_tier(tr: String) -> void:
	Txt.hint_tier = tr
	Txt.save_settings(testing)
	sfx.play("tool")


# the training course: Liang's automatic help when you're stuck, on or off
# (Q still asks for it either way)
func toggle_hints() -> void:
	hints_on = not hints_on
	Txt.hints = hints_on
	Txt.save_settings(testing)
	say("hints_auto_on" if hints_on else "hints_auto_off", drone.global_position + Vector2(0, -44))
	sfx.play("switch")


func cycle_tier() -> void:
	set_tier(Txt.TIERS[(Txt.TIERS.find(Txt.hint_tier) + 1) % Txt.TIERS.size()])
	say("tier_now", drone.global_position + Vector2(0, -44), txt("tier_" + Txt.hint_tier))


func room_name(room: String) -> String:
	return txt(Ship.room_name_key(ship, room))


# the ship as the player reads it: registration and type, in their language
func ship_title() -> String:
	var ty: Dictionary = Market.type_of(ship_id)
	var tn: String = ((ty.name[0] if Txt.zh else ty.name[1]) if ty.has("name") else "")
	var reg: String = job.get("reg", ship.get("name", "").split(" ")[0])
	return ("%s · %s" % [reg, tn]) if tn != "" else ship.get("name", "")


func cam_zoom() -> float:
	return zoom_now


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	if dev_overlay_open or prelude_on:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	state_t += rdt
	if exchange_requested and career() and state == "play" and console_ui == null and not menu_open:
		exchange_requested = false
		open_exchange()
	if state == "play" and not menu_open and not paused_sim:
		playtime += dt
		if career() and Career.usable():
			preload("res://scripts/industrial_exchange.gd").advance_career(dt)
		# the end is checked when something is delivered; once a second as well, for a
		# last piece that went some other way (and for a contract loaded with nothing left)
		done_t += rdt
		if done_t > 1.0:
			done_t = 0.0
			_check_done()
		if (training or career()) and not Career.data.is_empty() and Career.usable():
			Career.data.time = float(Career.data.get("time", 0.0)) + rdt
		if standard_time() > 0.0 and playtime > standard_time() and not hints_seen.has("late"):
			hints_seen["late"] = true
			Copy.say(radio, "L_late")
		_find_faults(rdt)
		autosave_t += rdt
		if autosave_t > 25.0 and not in_berth():
			autosave_t = 0.0
			# written on a worker thread: no hitch every 25 s (ARK-01 took ~150 ms)
			SaveGame.save_async(self)
			hud.toast_saved()
	if state == "play" and bot == null and not in_berth():
		_account(dt, rdt)
	# 65 号: the crew's work goes on while the game is played
	if state == "play" and not menu_open and career() and Career.usable() and not training and exam == null:
		# 68 号: the belt sweep and the signal analysis run on the same clock
		var sc: Dictionary = Scan.advance(dt)
		if not sc.is_empty() and hud != null:
			hud.show_hint(Scan.done_text(sc))
		# 75 号: people at the trade port's pier, the companies' standing contracts
		var tp: Array = TradePeople.advance(dt)
		if not tp.is_empty() and hud != null:
			hud.show_hint(str(tp[0]))
		while not TradePeople.lines.is_empty():
			var lid: String = TradePeople.lines.pop_front()
			if radio != null:
				Copy.say(radio, lid, "client")
		# 77 号: the tug charters and the third-party storage
		var biz: Array = Charter.advance(dt) + Depot.advance(dt)
		if not biz.is_empty() and hud != null:
			hud.show_hint(str(biz[0]))
		# 76 号: the gas line, the LOX tank, the passing ships
		var gl: Array = GasLine.advance(self, dt)
		if not gl.is_empty() and hud != null:
			hud.show_hint(str(gl[0]))
		# 73 号: the warehouse's forklifts; 74 号: the rolling mill
		Warehouse.advance(self, dt)
		if Mill.advance(self, dt) and hud != null:
			hud.show_hint(Ops.w("轧机轧好一吨，送回仓库了。", "THE MILL ROLLED A TONNE: BACK ON THE RACKS."))
		# 72 号: the company's tugs charge on the grid
		if TugYard.advance(self, dt) and hud != null:
			hud.show_hint(Ops.w("拖船充满电了：%s", "TUGS CHARGED: %s") % TugYard.status())
		# 87-7: sail rolls listed for the sail-makers find their buyers
		var sold_rolls: Array = Repair.advance_listings(dt)
		if not sold_rolls.is_empty() and hud != null:
			hud.show_hint(Ops.w("挂牌的光帆卷卖出了：%s", "LISTED SAIL ROLLS SOLD: %s") % ", ".join(sold_rolls))
		if Works.advance(dt, drone.global_position if drone != null and drone.alive else Vector2.INF):
			# the wreck gives way to the built thing
			if dock != null and dock.static_node != null:
				dock.static_node.queue_redraw()
			if in_berth() and build == null:
				_maybe_show_repairs()
	_read_input()
	var dev_warp: bool = DevPanel.warp_on() and bot == null
	var want_warp: bool = state == "play" and not menu_open and not paused_sim and (Keys.down("warp") or dev_warp or (bot != null and bot.get("warp", false)))
	if want_warp != warp:
		warp = want_warp
		if hitstop_t <= 0.0 and slowmo <= 0.0:
			Look.time_k(_warp_k() if warp else 1.0)
	match state:
		"intro":
			_intro(rdt)
		"play":
			if not menu_open and not contract_open and not paused_sim:
				tools.aim = aim
				tools.step(dt)
				_drone_upkeep(dt)
		"ending":
			_ending(rdt)
		"towout":
			_towout(rdt)
		"survey":
			_survey(rdt)
		"towin":
			if tow_traffic != null:
				tow_traffic.step_cine(rdt)
			else:
				end_towin()
		"porttour":
			if port_tour != null and is_instance_valid(port_tour):
				port_tour.step(rdt)
			else:
				state = "play"
				cam_override = null
				zoom_override = -1.0
		"build":
			_build_step(rdt)
		"nuke":
			if nuke != null:
				nuke.step(rdt)
	fx.step(dt)
	if not menu_open:
		radio.step(rdt, tools.cutting or (tools.held_piece != null and tools.tether_force > 0.2))
	_age_messages(rdt)
	if hitstop_t > 0.0:
		hitstop_t -= rdt
		Look.time_k(0.05 if hitstop_t > 0.0 else (Look.SLOW if slowmo > 0.0 else (_warp_k() if warp else 1.0)))
	elif slowmo > 0.0:
		slowmo -= rdt
		Look.time_k(Look.SLOW if slowmo > 0.0 else (_warp_k() if warp else 1.0))


# one frame of the contract, booked to what the operator was doing
func _account(dt: float, rdt: float) -> void:
	var k := "wait"
	var sec := dt
	if menu_open or contract_open or paused_sim or (blueprint != null and blueprint.on):
		k = "menu"
		sec = rdt
	elif tools.cutting:
		k = "cut"
	elif tools.held_body != null or tools.held_piece != null:
		k = "haul"
	elif not tools.job.is_empty():
		k = "measure" if tools.job.kind == "measure" else "maintain"
	elif drone.alive and drone.linear_velocity.length() > 20.0:
		k = "fly"
	time_by[k] = float(time_by.get(k, 0.0)) + sec


func _warp_k() -> float:
	return DevPanel.time_k if DevPanel.warp_on() and bot == null else WARP


func _physics_process(dt: float) -> void:
	if dev_overlay_open:
		return
	_camera(dt / maxf(Engine.time_scale, 0.01))
	if state == "play" and not menu_open and not paused_sim:
		tools.physics_step(dt)
		_bodies_upkeep(dt)
		if work_order != null: work_order.tick(dt)


func _read_input() -> void:
	var mpos := get_global_mouse_position()
	var b: Dictionary = bot if bot != null else {}
	aim = b.get("aim", mpos)
	var lmb: bool = b.get("lmb", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if modal_release:
		if not lmb: modal_release = false
		lmb = false
	var blocked: bool = menu_open or contract_open or paused_sim or console_ui != null or (bot == null and hud.pointer_over_ui())
	# the press that readied the ring (on its slot) must let go before one can fire it
	if ring_wait and not lmb:
		ring_wait = false
	if blocked:
		lmb = false
	# a readied ring takes the click from the tools (and the rest of that press)
	if ring_armed:
		if state != "play" or not drone.alive or menu_open or contract_open or stock("ring") <= 0:
			ring_armed = false
		else:
			ring_aim = ring_target(aim)
			ring_eat = true
			if lmb and not prev_lmb and not ring_wait and breaching_ring():
				ring_armed = false
	if ring_eat and not ring_armed and not lmb:
		ring_eat = false
	tools.lmb_pressed = lmb and not prev_lmb and not ring_eat and not in_vehicle()
	tools.lmb = lmb and not ring_eat and not in_vehicle()
	prev_lmb = lmb
	var mv := Vector2.ZERO
	if b.has("move"):
		mv = b.move
	elif not menu_open and not contract_open:
		if Keys.down("left"):
			mv.x -= 1
		if Keys.down("right"):
			mv.x += 1
		if Keys.down("up"):
			mv.y -= 1
		if Keys.down("down"):
			mv.y += 1
	var pilot_blocked: bool = console_ui != null or in_vehicle()
	if boat != null and boat.aboard:
		boat.input.move = mv if state == "play" and console_ui == null else Vector2.ZERO
		boat.input.dash = b.get("dash", Keys.down("dash")) and state == "play" and console_ui == null
		boat.input.brake = b.get("brake", Keys.down("brake")) and state == "play" and console_ui == null
	player_moved = mv != Vector2.ZERO and not pilot_blocked
	# Q hint in the training course: the drone flies itself to where the target shows
	if tutorial != null and tutorial.autopilot != null and not player_moved:
		var to: Vector2 = tutorial.autopilot - drone.global_position
		mv = to.normalized() * clampf(to.length() / 90.0, 0.25, 1.0)
	drone.input.move = mv if state == "play" and not pilot_blocked else Vector2.ZERO
	drone.input.dash = b.get("dash", Keys.down("dash")) and state == "play" and not pilot_blocked
	drone.input.brake = b.get("brake", Keys.down("brake")) and state == "play" and not pilot_blocked
	drone.input.hold = b.get("hold", Keys.down("hold") and not menu_open) and state == "play"
	overview = bot == null and state == "play" and not menu_open and not contract_open and not pilot_blocked and Keys.down("overview")
	if not pilot_blocked: drone.aim = aim


func _unhandled_input(ev: InputEvent) -> void:
	# a berth computer is open over the berth: it has the keys
	if console_ui != null or dev_overlay_open:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if state == "nuke":
			if nuke != null:
				nuke.skip()
			return
		if state == "intro":
			if k in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
				_end_intro()
			return
		if state == "towin":
			if state_t > 0.3 and k in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER] and tow_traffic != null:
				tow_traffic.finish()
			return
		if state == "porttour":
			if port_tour != null:
				port_tour.key(k)
			return
		if state == "survey":
			if state_t > 0.3:
				_end_survey()
			return
		if state == "build":
			if state_t > 0.3:
				_end_build()
			return
		if state == "ending":
			if exam != null:
				if exam.result_t > 1.0 and k in [KEY_1, KEY_2]:
					exam_choice(k - KEY_1)
				return
			if story == null or not story.ending_key(k):
				hud.ending_key(k)
			return
		if k == KEY_ESCAPE:
			if menu_open and hud.menu_page != "":
				hud.menu_page = ""
				return
			if ring_armed:
				arm_ring(false)
			elif contract_open:
				close_contract()
			else:
				toggle_menu()
			return
		if menu_open:
			return
		if contract_open:
			if k in [KEY_SPACE, KEY_ENTER]:
				close_contract()
			elif k in [KEY_1, KEY_2, KEY_3]:
				set_tier(Txt.TIERS[k - KEY_1])
			return
		if exam != null and k == KEY_Q:
			exam.request_hint()
			return
		if tutorial != null:
			if tutorial.choice_open() and k in [KEY_1, KEY_2]:
				tutorial.pick("a" if k == KEY_1 else "b")
				return
			if k == KEY_Q:
				tutorial.request_hint()
				return
			if tutorial.done and k in [KEY_1, KEY_2]:
				after_training("exam" if k == KEY_1 else "contract")
				return
		# 68 号 §4: what a key is for, the first time it is used
		var first_act := Keys.action_of(ev)
		if first_act != "" and hud != null and career():
			hud.op_card(first_act)
		match Keys.action_of(ev):
			"tool1": tools.set_tool(1, false, true)
			"tool2": tools.set_tool(2, false, true)
			"tool3": tools.set_tool(3, false, true)
			"tool4": tools.set_tool(4, false, true)
			"tool5": tools.set_tool(5, false, true)
			"tool6": tools.set_tool(6, false, true)
			"blueprint": blueprint.toggle()
			"repair": repair_kit()
			"ring": arm_ring(not ring_armed)
			"assist":
				drone.assist = not drone.assist
				Txt.assist = drone.assist
				Txt.save_settings(testing)
				say("assist_on" if drone.assist else "assist_off", drone.global_position + Vector2(0, -44))
				sfx.play("switch")
			"contract": open_contract()
			"starmap": open_star_map("find")
			"log": hud.show_log = not hud.show_log
			"port":
				if career() and in_berth() and state == "play":
					port_view = not port_view
					sfx.play("switch")
			"auto": toggle_auto()
			"multi": tools.toggle_multi(ev is InputEventKey and ev.shift_pressed)
			"tow":
				if boat_tow != null and boat != null and boat.aboard:
					boat_tow.toggle()
			"plan":
				# 61 号: work plans stay out of sight until the second berth (G7)
				if plan != null and G4_OPEN:
					if plan.has_plan() and not plan.running:
						open_plan_panel()
						return
					if auto_paused and not plan.running:
						auto_paused = false
					var plan_message := plan.toggle()
					say(plan_message, drone.global_position + Vector2(0, -44), plan.message_arg)
					sfx.play("switch")
			"mouth":
				# the equipment bay always runs on its rail; the furnace with the rail upgrade
				dock.move_equip(drone.global_position.x / Geom.M)
				if has_upgrade("mouth_rail"):
					dock.move_mouth(drone.global_position.x / Geom.M)
					say("mouth_moving_both", drone.global_position + Vector2(0, -44))
				else:
					say("mouth_moving_equip", drone.global_position + Vector2(0, -44))
				sfx.play("switch")
			"mark": mark_salvage()
			"use":
				if boat != null and boat.aboard and state == "play":
					if not boat.leave():
						say_text(txt("boat_underway"), drone.global_position + Vector2(0, -44))
				elif boat != null and state == "play" and boat.drone_can_board():
					boat.board()
					sfx.play("switch")
				elif mill_line != null and state == "play" and mill_line.near():
					open_mill()
				elif cargo_floor != null and state == "play" and cargo_floor.use():
					pass
				elif tram != null and state == "play" and tram.phase == "" and tram.near_station() != "":
					open_transit("tram", tram.near_station())
				elif industrial_heat != null and state == "play" and industrial_heat.near():
					open_heat()
				elif industrial_assay != null and state == "play" and industrial_assay.near() and (industrial_sort == null or not industrial_sort.near() or drone.global_position.distance_to(industrial_assay.site()) < drone.global_position.distance_to(industrial_sort.site())):
					open_assay()
				elif industrial_sort != null and state == "play" and industrial_sort.near():
					open_sort()
				elif trade_hall != null and state == "play" and trade_hall.near_counter() != "":
					open_exchange("company:" + trade_hall.near_counter())
				elif port_structure != null and state == "play" and port_structure.near_console() != "":
					open_district(port_structure.near_console())
				elif port_access != null and state == "play" and port_access.near() != "":
					open_console("port:" + port_access.near())
				elif consoles != null and state == "play" and consoles.near() == "rack":
					open_parts_rack()
				elif consoles != null and state == "play" and consoles.near() != "":
					open_console(consoles.near())
			"terminal":
				# aboard the boat: its destination list; otherwise the same terminal from anywhere in the berth
				if boat != null and boat.aboard and state == "play":
					if boat.stopped():
						open_transit("boat", boat.pad)
					else:
						say_text(txt("boat_underway"), drone.global_position + Vector2(0, -44))
				elif consoles != null and state == "play":
					open_console("terminal")
			"zone":
				if has_upgrade("zones"):
					say(toggle_keepout(aim), aim + Vector2(0, -30))
					sfx.play("switch")
			"hints":
				if training:
					toggle_hints()
	elif ev is InputEventMouseButton and ev.pressed:
		if state == "nuke":
			if nuke != null:
				nuke.skip()
			return
		if state == "intro":
			_end_intro()
			return
		if state == "towin":
			if state_t > 0.3 and tow_traffic != null:
				tow_traffic.finish()
			return
		if state == "porttour":
			if port_tour != null:
				port_tour.next()
			return
		if state == "survey":
			if state_t > 0.3:
				_end_survey()
			return
		if state == "build":
			if state_t > 0.3:
				_end_build()
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * ZOOM_STEP, zoom_min(), 2.6)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / ZOOM_STEP, zoom_min(), 2.6)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and state == "play" and not menu_open and not contract_open:
			# A short click releases and marks; a drag only pans the view.
			rmb_down = true
			rmb_moved = 0.0
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if rmb_down and rmb_moved < 10.0 and ring_armed:
			arm_ring(false)
		elif rmb_down and rmb_moved < 10.0 and state == "play" and not menu_open and not contract_open:
			if tools.held_piece != null:
				tools.release_grab(true)
			tools.job = {}
			if Keys.RIGHT_MOUSE in Keys.codes("mark"):
				mark_salvage()
		rmb_down = false
	elif ev is InputEventMouseMotion and rmb_down:
		rmb_moved += ev.relative.length()
		if rmb_moved >= 10.0:
			cam_pan -= ev.relative / maxf(zoom_now, 0.1)


# the work plan hands a loose body to the berth's machines (G4): the haulers, or the
# crane for what they cannot lift; false when nobody aboard can take it
func plan_mark(b, zone: String = "") -> bool:
	if arm_extract(b,zone,true): return true
	return false

func arm_extract(b, zone: String = "", by_plan: bool = false) -> bool:
	# 78 号 P0②: on a manual-only ship the arm goes only where the player sends it
	if by_plan and manual_only():
		return false
	if b == null or not is_instance_valid(b) or b.capture != null or b.pieces.is_empty() or tools.held_body == b:
		return false
	# Explicit user choice: a rail arm extracts planned loads through hulls.
	# Keep the purchased carrier's load rating and actual receiver settlement.
	var rated_t: float = Crane.MAX_T if crane != null else (Hauler.MAX_T if hauler != null else (RecoveryArm.MAX_T if arm != null else 0.0))
	if rated_t > 0.0 and b.total_mass() <= rated_t:
		if arm == null:
			arm = RecoveryArm.new()
			arm.game = self
			add_child(arm)
		for carrier in haulers():
			carrier.queue.erase(b)
			if carrier.body == b: carrier.halt()
		if crane != null:
			crane.queue.erase(b)
			if crane.body == b: crane.halt()
		if by_plan: b.set_meta("plan_dispatch",true)
		b.set_meta("arm_extraction",true)
		return arm.enqueue(b,zone,rated_t)
	return false


func mark_salvage() -> void:
	var under: Array = world.pieces_at(aim)
	var mb = under[0].body if not under.is_empty() else null
	var key := ""
	# too heavy for the haulers (or none aboard): the crane's, if the berth has one
	if crane != null and mb != null and (hauler == null or mb.total_mass() > Hauler.MAX_T or crane.queue.has(mb)):
		key = crane.toggle(mb)
	elif hauler != null:
		key = hauler.toggle(mb)
	if key != "":
		if mb != null and is_instance_valid(mb):
			mb.set_meta("manual_mark", key in ["hauler_marked","crane_marked"])
		say(key, aim + Vector2(0, -30))


func toggle_menu() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	paused_sim = menu_open
	hud.menu_changed()
	sfx.play("menu")


# one of the berth's computers: its terminal page over the berth, play stopped
# while it is open (the operator is at the desk, not at the controls)
# 61 号 (60 号 Q7): the G4 work plans and engineering orders are kept, not shown
static var G4_OPEN := false   # tests of the work plans switch it on


func open_plan_panel() -> void:
	if console_ui != null or menu_open or contract_open or state != "play": return
	tools._finish_cut()
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = load("res://scripts/plan_panel.gd").new()
	panel.game = self
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
		get_tree().paused = false
		paused_sim = false
	paused_sim = true
	get_tree().paused = true
	console_ui = panel
	layer.add_child(panel)


func open_order_review(early: bool) -> void:
	if console_ui != null or order_review != null: return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = load("res://scripts/order_settlement.gd").new()
	panel.game = self
	var close_review := func():
		order_review = null
		console_ui = null
		modal_release = true
		layer.queue_free()
		get_tree().paused = false
		paused_sim = false
	panel.on_confirm = func(selling: bool):
		work_order.sell = selling
		close_review.call()
		finish_contract(early,true)
	panel.on_cancel = func():
		order_review_deferred = true
		close_review.call()
	order_review = panel
	console_ui = panel
	paused_sim = true
	get_tree().paused = true
	layer.add_child(panel)


func open_heat() -> void:
	if console_ui != null or menu_open or industrial_heat == null or not industrial_heat.near(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/heat_panel.gd").new()
	panel.service = industrial_heat
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)

func open_sort() -> void:
	if console_ui != null or menu_open or industrial_sort == null or not industrial_sort.near(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/sort_panel.gd").new()
	panel.service = industrial_sort
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)

func open_assay() -> void:
	if console_ui != null or menu_open or industrial_assay == null or not industrial_assay.near(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/assay_panel.gd").new()
	panel.service = industrial_assay
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


func backdrop_parts() -> Backdrop:
	return backdrop


# the very first hulk of a new career, found out in the belt and towed home (28 号 Q7/Q13):
# played once, before the berth's own tow-in; later unowned hulks get a line of caption
func _belt_prelude() -> void:
	if not career() or not Career.usable() or (testing and not cine_in_tests) or bot != null:
		return
	if str(job.get("owner", "")) != "salvage":
		return
	var seen: Dictionary = Career.data.get("seen", {})
	if str(job.get("id", "")) == "TUG-001" and not seen.has("belt_prelude"):
		seen["belt_prelude"] = true
		Career.data.seen = seen
		Career.save()
		var pre = preload("res://scripts/belt_prelude.gd").new()
		pre.ship = str(job.get("ship", "tug"))
		get_tree().paused = true
		prelude_on = true
		pre.on_done = func():
			prelude_on = false
			get_tree().paused = false
		add_child(pre)
	elif hud != null:
		hud.show_hint(Txt.t("tm_drift_open") if job.has("opening") else Txt.t("tm_drift_v") % int(job.get("drift_years", 0)))


# 68 号 §2: the opening cards (scripts/opening.gd): before the prologue once, and from the pause menu
static var opening_in_tests := false
var opening = null
func show_opening(first: bool) -> void:
	if opening != null and is_instance_valid(opening):
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	opening = preload("res://scripts/opening.gd").new()
	var was_paused := get_tree().paused
	get_tree().paused = true
	opening.on_done = func():
		layer.queue_free.call_deferred()
		opening = null
		if first:
			var seen: Dictionary = Career.data.get("seen", {})
			seen["intro"] = true
			Career.data.seen = seen
			Career.save()
		get_tree().paused = was_paused
	if first and Career.usable():
		if not Career.data.has("permit_day"):
			Career.data.permit_day = int(Shipping.day()) + 1
		opening.first = true
		opening.card = clampi(Career.guide_at("intro"), 0, opening.CARDS.size() - 1)
	layer.add_child(opening)


# 68 号 §3: TUG-001 at the berth, step by step (scripts/first_ship.gd), once per career
static var coach_in_tests := false
var coach = null
func _first_ship_coach() -> void:
	if not career() or not Career.usable() or ((bot != null or testing) and not coach_in_tests):
		return
	if str(job.get("id", "")) != "TUG-001" or Career.data.get("seen", {}).has("first_ship"):
		return
	coach = preload("res://scripts/first_ship.gd").new()
	coach.game = self
	add_child(coach)


# 78 号 P0②: a ship the player strips with their own hands — no bot, no work plan or package, no
# machine taking things on its own, no one-key tool. The ship file says so ("manual_only", ARK-01),
# so it holds after a save and a load. The player's own machines (marked loads, the crane, pumps,
# instruments) still work.
func manual_only() -> bool:
	return bool(ship.get("manual_only", false))


# an automatic entry refused on a manual-only ship: said once where the drone is; true = refused
func auto_refused(what: String) -> bool:
	if not manual_only():
		return false
	if drone != null:
		say("manual_only", drone.global_position + Vector2(0, -44), what)
	return true


# 84 号: the port on foot — out of the berth, the shuttle, every district's consoles; forced the
# first time (once the first ship is stripped), from the menu after
var port_walk = null
func start_port_walk(forced: bool) -> void:
	if walk_on() or state != "play":
		return
	if not in_berth():
		# the corridors open only on an empty berth
		say_text("船坞空着时才能出去走港区：先把这艘船拆完。" if Txt.zh else "The port opens only on an empty berth: finish this ship first.", drone.global_position + Vector2(0, -44))
		return
	# 90 号 (user 2026-10-27: "every time I load, now and then the whole tour starts over"): forced only
	# the first time; a walk cut short comes back as one the player may end ("关掉导览")
	if forced and Career.usable() and not Career.data.is_empty():
		var seen: Dictionary = Career.data.get("seen", {})
		if seen.has("port_walk_started"):
			forced = false
		else:
			seen["port_walk_started"] = true
			Career.data.seen = seen
			Career.save()
	port_walk = preload("res://scripts/port_walk.gd").new()
	port_walk.game = self
	port_walk.forced = forced
	add_child(port_walk)


func walk_on() -> bool:
	return port_walk != null and is_instance_valid(port_walk) and not port_walk.done


# 83 号: the port tour — forced the first time (once the first ship is stripped), from the menu after
func start_port_tour(forced: bool) -> void:
	if port_tour != null or state != "play":
		return
	port_tour = preload("res://scripts/port_tour.gd").new()
	add_child(port_tour)
	port_tour.start(self, forced)


func coach_on() -> bool:
	return coach != null and is_instance_valid(coach) and not coach.done


# 80 号: one place says whether a tool is open — the training course, the belt prologue or the
# first-ship guide (each step opens only what it needs; user: "强制只能切换这种武器")
func guide_coach():
	if prologue != null and is_instance_valid(prologue) and not prologue.done:
		return prologue
	if coach_on():
		return coach
	if walk_on():
		return port_walk
	return null


func tool_ok(n: int) -> bool:
	if tutorial != null:
		return tutorial.tool_allowed(n)
	var gc = guide_coach()
	return gc == null or gc.tool_allowed(n)


# "测量（1）、激光切割（2）" — the tools this step opens, by name and key; flying only when none
func open_tools_text() -> String:
	var out: Array = []
	for n in range(1, 7):
		if tool_ok(n):
			out.append(("%s（%s）" if Txt.zh else "%s (%s)") % [txt("tool_%d" % n), Keys.label("tool%d" % n)])
	if out.is_empty():
		return "飞行，先不用工具" if Txt.zh else "flying, no tool yet"
	return ("、" if Txt.zh else ", ").join(out)


func context_ok(n: int) -> bool:
	if tutorial != null:
		return tutorial.context_ok(n)
	return tool_ok(n)


# the beam stops at what the step keeps whole (the first ship's winch while its mounts are cut)
func coach_guards(q) -> bool:
	var gc = guide_coach()
	return gc != null and gc.has_method("guards") and gc.guards(q)


# the drone is riding something: the boat's rack or the shuttle
func in_vehicle() -> bool:
	return (boat != null and boat.aboard) or (tram != null and tram.riding)


# a floating line of plain text over the site (the keyed say() wants a text key)
func say_text(text: String, _at: Vector2) -> void:
	hud.show_hint(text)


# the destination list of the shuttle (at a station) or the boat (docked)
func open_transit(mode: String, here: String) -> void:
	if console_ui != null or menu_open or state != "play":
		return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/transit_panel.gd").new()
	panel.game = self
	panel.mode = mode
	panel.here = here
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


# 86 号 Q11: the parts rack (by the berth's terminal; the cargo district's racks once it is mended)
func open_parts_rack() -> void:
	if console_ui != null or menu_open or state != "play":
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/parts_rack_panel.gd").new()
	panel.game = self
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


# 85 号: one side of the cargo district's racks (scripts/shelf_panel.gd)
func open_shelf(side: String) -> void:
	if console_ui != null or menu_open or state != "play":
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/shelf_panel.gd").new()
	panel.game = self
	panel.side = side
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


# 85 号: the rolling mill's own panel (scripts/mill_panel.gd): play goes on while it is open
func open_mill() -> void:
	if console_ui != null or menu_open or state != "play":
		return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/mill_panel.gd").new()
	panel.game = self
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


# a district's business console (scripts/district_panel.gd): play goes on while it is open
func open_district(zone: String) -> void:
	if console_ui != null or menu_open or state != "play":
		return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel = preload("res://scripts/district_panel.gd").new()
	panel.game = self
	panel.zone = zone
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
	console_ui = panel
	layer.add_child(panel)
	sfx.play("menu")


func open_exchange(page: String = "") -> void:
	if console_ui != null or menu_open or state != "play": return
	var result: Dictionary = preload("res://scripts/industrial_exchange.gd").command("view")
	if not result.ok: return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = preload("res://scripts/exchange_panel.gd").new()
	panel.game = self
	panel.start_page = page
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
		_cover_world(false)
	panel.on_repair = func(): open_console("port:trade")
	console_ui = panel
	layer.add_child(panel)
	_cover_world(true)


# the hulk market (scripts/ship_market_panel.gd, 33 号)
func open_ship_market() -> void:
	if console_ui != null or menu_open or state != "play" or not career() or not Career.usable() or not ShipMarket.open(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = preload("res://scripts/ship_market_panel.gd").new()
	panel.game = self
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
		_cover_world(false)
	console_ui = panel
	layer.add_child(panel)
	_cover_world(true)
	sfx.play("menu")


# the power district's control screen (scripts/power_panel.gd, 48 号)
func open_power_screen() -> void:
	if console_ui != null or menu_open or state != "play" or not career() or not Career.usable(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = preload("res://scripts/power_panel.gd").new()
	panel.game = self
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
		_cover_world(false)
	console_ui = panel
	layer.add_child(panel)
	_cover_world(true)
	sfx.play("menu")


# a tug just sent: the star map, following it
func watch_tow(id: String) -> void:
	open_star_map("find")
	if console_ui != null and console_ui.has_method("watch_tow"):
		console_ui.watch_tow(id)


# the star map: the belt, the port and every freighter on its arc (scripts/star_map.gd, 31 号)
func open_star_map(mode := "ships") -> void:
	if console_ui != null or menu_open or state != "play" or not career() or not Career.usable(): return
	tools.release_grab(false)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel = preload("res://scripts/star_map.gd").new()
	panel.game = self
	panel.mode = mode
	panel.on_close = func():
		console_ui = null
		modal_release = true
		layer.queue_free()
		_cover_world(false)
	console_ui = panel
	layer.add_child(panel)
	_cover_world(true)
	sfx.play("menu")


# a page that fills the screen (the terminal, the exchange): the berth behind it is not
# drawn while it is open (2026-10-24, ~11 ms a frame saved); its nodes keep running and
# keep their own visibility, only this node's drawing stops
func _cover_world(on: bool) -> void:
	visible = not on
	if hud != null:
		hud.visible = not on

# a hulk towed home: said on the spot with the way to start on it (the terminal opens on its card)
func hulk_home(a: Dictionary) -> void:
	var ship := str(a.get("listing", {}).get("offer", {}).get("ship", ""))
	arrival = {"id": str(a.id), "name": Scan.type_name(ship) if ship != "" else str(a.id), "held": str(a.get("state", "")) == "held", "yard": int(a.get("yard", 0)) + 1}
	sfx.play("menu", Vector2.INF, 1.0)


func open_console(which: String) -> void:
	if console_ui != null or menu_open:
		return
	var term = load("res://scenes/terminal.tscn").instantiate()
	if which == "terminal" and not arrival.is_empty():
		term.focus_offer = str(arrival.id)
		arrival = {}
	term.overlay = true
	term.between = in_berth()
	term.tab = -1
	term.game_ref = self
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	term.on_skill_changed = fit_skills
	# 91 号 (seamless): the screen opens out of the drone and folds back into it
	var folds: bool = look != null and Txt.anim_level() > 0
	term.keep_on_close = folds
	term.on_close = func():
		fit_skills()
		console_ui = null
		if folds:
			look.console_close(layer, look.screen_of(drone.global_position if drone != null else Vector2.INF))
		else:
			layer.queue_free()
		_cover_world(false)
		get_tree().paused = false
		paused_sim = false
		sfx.play("menu")
		# an extension just bought: built in front of the operator
		if in_berth():
			_maybe_build()
	get_tree().paused = true
	paused_sim = true
	if folds:
		look.console_open(layer, term, look.screen_of(drone.global_position if drone != null else Vector2.INF), func(): if console_ui == term: _cover_world(true))
	else:
		layer.add_child(term)
	console_ui = term
	if not folds:
		_cover_world(true)
	if which.begins_with("port:") and in_berth():
		term.set_tab(5)
		term.route_panel.select_key(which)
	sfx.play("menu")


func open_contract() -> void:
	if in_berth():
		return
	contract_open = true
	hud.contract_changed()


func close_contract() -> void:
	contract_open = false
	hud.contract_changed()
	sfx.play("ok")
	hint("start")
	# Liang on the risk the operator just signed for
	match int(job.get("stars", 0)):
		1: Copy.say(radio, "L_accept_low")
		3: Copy.say(radio, "L_accept_high")
	# an opening ship: Liang's lines as it comes in (empty slots say nothing)
	if job.has("intro"):
		for i in 3:
			Copy.say(radio, "%s_%d" % [job.intro, i + 1])
	if story != null:
		story.on_start()
	_start_survey()


# ---------------------------------------------------------------- the survey pass
# Once the contract is signed the camera flies the ship from bow to stern, then
# pulls back until all of it is in view and measures it: length, height, mass,
# its centre of mass, its rooms (player 2026-10-20: "after taking the job, a
# camera move that shows the whole ship"). A ship type's first contract gets the
# whole pass, later ones the short look (Jev B 0.49 / 0.23). Any key or click
# skips it; the drone waits in its bay until it is over.
static var cine_in_tests := false     # tests that want to see the cinematics switch them on
static var surveyed := {}             # ship types seen this session (outside a career)
var survey := {}


func _start_survey() -> void:
	if bot != null or (testing and not cine_in_tests) or training or exam != null or in_berth() or state != "play":
		return
	var M := Geom.M
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	var mass := 0.0
	var mom := Vector2.ZERO
	var n := 0
	for p in world.pieces.values():
		if p.gone or p.body != null:
			continue
		var bb := Geom.bbox(p.poly)
		x0 = minf(x0, bb.position.x)
		x1 = maxf(x1, bb.end.x)
		y0 = minf(y0, bb.position.y)
		y1 = maxf(y1, bb.end.y)
		mass += p.mass
		mom += Geom.centroid(p.poly) * p.mass
		n += 1
	if n == 0:
		return
	var off := world.position
	var vs := get_viewport().get_visible_rect().size
	var L := (x1 - x0) / M
	var H := (y1 - y0) / M
	var win := clampf(L * 0.35, 26.0, 150.0)
	var z_pass := clampf(minf(vs.x / (win * M), (vs.y - 160.0) / ((H * 1.25 + 4.0) * M)), 0.04, 1.3)
	# framed for the hold: room on the right for the height, below for the length and the title
	var z_fit := clampf(minf((vs.x - 360.0) / ((L + 2.0) * M), (vs.y - 400.0) / ((H + 2.0) * M)), 0.02, 1.3)
	var half := vs.x * 0.5 / z_pass
	var xa := x0 + half - 2.0 * M
	var xb := x1 - half + 2.0 * M
	if xb < xa:
		xa = (x0 + x1) * 0.5
		xb = xa
	var seen: Dictionary = Career.data.get("surveyed", {}) if career() else surveyed
	var full := not seen.has(ship_id)
	var tp := clampf((xb - xa) / M / 16.0, 2.5, 7.0) if full else 0.0
	survey = {"x0": x0 + off.x, "x1": x1 + off.x, "y0": y0 + off.y, "y1": y1 + off.y, "mass": mass, "com": mom / maxf(mass, 0.001) + off,
		"n": n, "xa": xa + off.x, "xb": xb + off.x, "cy": (y0 + y1) * 0.5 + off.y, "z_pass": z_pass, "z_fit": z_fit, "full": full,
		"t_in": 1.3 if full else 0.0, "tp": tp, "t_out": 1.5, "hold": 3.0 if full else 2.2}
	survey.t_end = survey.t_in + tp + survey.t_out + survey.hold
	state = "survey"
	state_t = 0.0
	sfx.play("measure")


func _survey(_dt: float) -> void:
	var s := survey
	var t := state_t
	if t < s.t_in:
		cam_override = Vector2(s.xa, s.cy)
		zoom_override = s.z_pass
	elif t < s.t_in + s.tp:
		var k := Pal.ease_io((t - s.t_in) / s.tp)
		cam_override = Vector2(lerpf(s.xa, s.xb, k), s.cy)
		zoom_override = s.z_pass
	else:
		cam_override = Vector2((s.x0 + s.x1) * 0.5 + 100.0 / maxf(s.z_fit, 0.01), s.cy + 75.0 / maxf(s.z_fit, 0.01))
		zoom_override = s.z_fit
	if t >= s.t_end:
		_end_survey()


# where the survey is: "pass" (flying the hull), "out" (pulling back), "hold" (measured), and 0..1 through it
func survey_phase() -> Array:
	if survey.is_empty():
		return ["", 0.0]
	var t := state_t
	var a: float = survey.t_in + survey.tp
	if t < a:
		return ["pass", clampf((t - survey.t_in) / maxf(survey.tp, 0.01), 0.0, 1.0)]
	if t < a + survey.t_out:
		return ["out", (t - a) / survey.t_out]
	return ["hold", clampf((t - a - survey.t_out) / survey.hold, 0.0, 1.0)]


func _end_survey() -> void:
	if state != "survey":
		return
	if career():
		var sv: Dictionary = Career.data.get("surveyed", {})
		sv[ship_id] = true
		Career.data["surveyed"] = sv
	else:
		surveyed[ship_id] = true
	cam_override = null
	zoom_override = -1.0
	state = "play"
	state_t = 0.0
	if hud != null:
		hud.in_t = 0.0


# ---------------------------------------------------------------- the berth extension, built on site
# The berth grows in front of the operator (scripts/berth_build.gd), for two reasons:
# an extension bought since the berth was last seen (over the empty berth when the
# terminal closes, or before the tug brings the next ship in), and a ship taller than
# the berth was (player 2026-10-20: "a horizontal rectangle, and a solar sail comes
# in: show in detail how the berth grows to take it"): the boom is jacked up section
# by section, the platform drawn down, before the tug brings the ship in. A ship
# type's first time gets the whole procedure, later ones the same steps fast
# (Jev B 0.94 / 0.91).
var berth_ext := Vector2.ZERO
var berth_len := Dock.STANDARD
var prev_shape := {}            # the berth as the last scene left it: {len, lift, drop}
var build = null
var _after_build := "play"
static var reshaped := {}       # ship types the berth has grown for this session (outside a career)


func _maybe_build() -> void:
	if build != null or bot != null or (testing and not cine_in_tests) or state == "build":
		return
	# what the berth is now (over the empty berth a purchase has only just been made)
	berth_len = Dock.length_for(float(ship.get("length", 0.0)), _upgrades_for_berth())
	var to := {"len": berth_len, "lift": Dock.lift_for(berth_ext.x), "drop": Dock.drop_for(berth_ext.y)}
	var from := to.duplicate()
	var paid := false
	if career() and Career.data.has("berth_seen"):
		var seen := float(Career.data.berth_seen)
		var owned := Dock.owned(Career.data.get("upgrades", {}))
		if owned > seen + 0.5:
			if absf(berth_len - owned) <= 0.5:
				from.len = seen
				paid = true
			else:
				# this contract's berth isn't simply what was bought: nothing to show
				Career.data["berth_seen"] = owned
	# a detonation took the berth (scripts/nuke.gd): it is built again from the tower out
	var rebuild: bool = career() and Career.usable() and Career.data.get("berth_rebuild", false)
	if rebuild:
		from = {"len": Dock.MIN_REBUILD, "lift": 0.0, "drop": 0.0}
		Career.data.erase("berth_rebuild")
		Career.save()
	# taller than the berth the last scene left: it grows to take this ship
	if not in_berth() and not prev_shape.is_empty():
		from.lift = minf(float(prev_shape.lift), to.lift)
		from.drop = minf(float(prev_shape.drop), to.drop)
	if absf(from.len - to.len) < 0.5 and absf(from.lift - to.lift) < 0.5 and absf(from.drop - to.drop) < 0.5:
		return
	var seen_types: Dictionary = Career.data.get("reshaped", {}) if career() else reshaped
	var quick := not paid and not rebuild and seen_types.has(ship_id)
	_layout_shape(from.len, from.lift, from.drop)
	build = preload("res://scripts/berth_build.gd").new()
	dock.add_child(build)
	build.setup(self, from, to, quick, Ship.bounds(ship), ship_title() if not in_berth() else "")
	_after_build = state
	state = "build"
	state_t = 0.0
	if not in_berth():
		world.visible = false


func _layout_shape(x: float, lift: float, drop: float) -> void:
	Dock.configure_shape(x, lift, drop)
	if has_upgrade("port2"):
		Dock.add_port2()
	dock.set_ship(ship)


func _layout_berth(x: float) -> void:
	_layout_shape(x, Dock.lift_for(berth_ext.x), Dock.drop_for(berth_ext.y))


# the build re-lays the berth at its full new size
func _relayout_berth() -> void:
	_layout_berth(berth_len)


func _build_step(dt: float) -> void:
	if build == null:
		state = _after_build
		return
	var done: bool = build.step(dt)
	var c: Array = build.cam(get_viewport().get_visible_rect().size)
	cam_override = c[0]
	zoom_override = c[1]
	if done:
		_end_build()


func _end_build() -> void:
	if build == null:
		return
	build.finish()
	build.queue_free()
	build = null
	if career():
		if Career.data.has("berth_seen"):
			Career.data["berth_seen"] = Dock.owned(Career.data.get("upgrades", {}))
		if not in_berth():
			var rs: Dictionary = Career.data.get("reshaped", {})
			rs[ship_id] = true
			Career.data["reshaped"] = rs
		if in_berth():
			Career.save()
	elif not in_berth():
		reshaped[ship_id] = true
	world.visible = true
	cam_override = null
	zoom_override = -1.0
	state = _after_build
	state_t = 0.0
	if hud != null:
		hud.in_t = 0.0


# ---------------------------------------------------------------- camera

# The wheel keeps a local view until the last three notches before whole-ship
# fit. A fixed zoom threshold sent the camera hundreds of metres away on ARK-01.
const OVERVIEW_ZOOM_STEPS := 3
const ZOOM_STEP := 1.1


func zoom_min() -> float:
	var vs := get_viewport().get_visible_rect().size
	var r := focus_rect()
	return minf(0.7, minf(vs.x / maxf(r.size.x, 1.0), vs.y / maxf(r.size.y, 1.0)))


# What the zoomed-out view frames (player 2026-10-20: "zoomed out, let me look at the
# whole ship, not the whole berth: a ship in the berth's left half left me looking at
# its right half"): the ship's hull as it still stands, with a margin, so the view
# centres on the ship and the furthest zoom just takes it in (Jev A 0.55 / 0.33).
# Over the empty berth, or once the hull is gone, the berth. In px; worked out again
# when pieces come off.
var _focus := Rect2()
var _focus_sig := -1


func focus_rect() -> Rect2:
	if port_access != null and port_access.active():
		return port_access.navigation_bounds()
	var sig: int = (world.bodies.size() * 7919 + world.pieces.size()) if world != null else 0
	if sig == _focus_sig and _focus.size != Vector2.ZERO:
		return _focus
	_focus_sig = sig
	var M := Geom.M
	var r := Rect2()
	var have := false
	if not in_berth() and world != null:
		for p in world.pieces.values():
			if p.gone or p.body != null:
				continue
			var bb := Geom.bbox(p.poly)
			r = r.merge(bb) if have else bb
			have = true
	if have:
		r.position += world.position
		r = r.grow(5.0 * M)
	else:
		r = Rect2(Vector2(Dock.TOWER_X - 1.0, Dock.RAIL_Y - 3.0) * M, Vector2(Dock.FLOOR_X1 - Dock.TOWER_X + 2.0, Dock.FLOOR_Y - Dock.RAIL_Y + 5.0) * M)
	_focus = r
	return r


const CAM_K := 38.0
const CAM_LAG := 0.3244                # s (2/√CAM_K): how far a scripted shot leads what it follows


func _camera(dt: float) -> void:
	_pan(dt)
	var target := cam_pos
	var local_focus := cam_pos
	var following := false
	if plan_focus != null:
		plan_focus_t -= dt
		if player_moved or plan_focus_t <= 0.0: plan_focus = null
	if cam_override != null:
		target = cam_override
	elif plan_focus != null:
		target = plan_focus
	elif port_view:
		target = Backdrop.pano_centre_px()
	elif overview:
		target = focus_rect().get_center()
	elif drone != null and (drone.alive or state == "play"):
		var dp: Vector2 = drone.global_position
		var lead := drone.linear_velocity * 0.22
		var look: Vector2 = (aim - dp).limit_length(380.0) * 0.18
		target = dp + lead + look
		if tools.held_piece != null and not tools.held_piece.gone:
			target = target.lerp(tools.grab_point(), 0.18)
		target += cam_pan
		local_focus = target
		following = true
		# Only hand over to whole-ship framing when it is almost visible already.
		# Use the displayed zoom, so a fast wheel burst cannot pull the camera
		# away from the local structure before the view has actually widened.
		var zm := zoom_min()
		var start := zm * pow(ZOOM_STEP, OVERVIEW_ZOOM_STEPS)
		var progress := clampf((start - maxf(zoom_now, zoom_target)) / maxf(start - zm, 0.00001), 0.0, 1.0)
		var blend := progress * progress * (3.0 - 2.0 * progress)
		target = target.lerp(focus_rect().get_center(), blend)
	# a critically damped follow: soft, never laggy
	var k := CAM_K
	var c := 2.0 * sqrt(k)
	var n := maxi(1, ceili(dt / (1.0 / 240.0)))
	var h := dt / n
	for i in n:
		cam_vel += ((target - cam_pos) * k - cam_vel * c) * h
		cam_pos += cam_vel * h
	var zt := zoom_override if zoom_override > 0.0 else zoom_target
	if plan_focus != null and zoom_override <= 0.0: zt = maxf(zt,0.75)
	if overview and zoom_override <= 0.0:
		# the whole ship and the berth in view
		zt = zoom_min()
	if port_view and zoom_override <= 0.0:
		zt = Backdrop.port_zoom(get_viewport().get_visible_rect().size)
	elif state == "play" and drone.alive:
		zt *= lerpf(1.0, 0.86, clampf(drone.linear_velocity.length() / 700.0, 0.0, 1.0))
		if zoom_override <= 0.0:
			zt = maxf(zt, minf(zoom_min(), zoom_target))
	var next_zoom := Pal.damp(zoom_now, zt, 4.0 if zoom_override > 0.0 else 6.0, dt)
	if following and next_zoom > zoom_now:
		# On the way back from overview, let the camera reach the local area
		# before tightening the frame enough to leave that area off screen.
		var half := get_viewport().get_visible_rect().size * 0.48
		var offset := cam_pos - local_focus
		var safe := minf(half.x / maxf(absf(offset.x), 1.0), half.y / maxf(absf(offset.y), 1.0))
		next_zoom = minf(next_zoom, maxf(zoom_now, safe))
	zoom_now = next_zoom
	trauma = maxf(0.0, trauma - dt * 1.6)
	punch = Pal.damp2(punch, Vector2.ZERO, 12.0, dt)
	var sh := trauma * trauma
	var tt := Time.get_ticks_msec() / 1000.0
	var off := Vector2(sin(tt * 47.0) + sin(tt * 31.0) * 0.5, cos(tt * 41.0) + sin(tt * 23.0) * 0.5) * 14.0 * sh
	# 91 号: a big piece coming free pulls the view in a little toward it, then lets go
	zoom_kick = Pal.damp(zoom_kick, 0.0, 2.6, dt)
	var lean: Vector2 = (kick_at - cam_pos) * 0.22 * clampf(zoom_kick / 0.07, 0.0, 1.0) if kick_at != Vector2.INF else Vector2.ZERO
	# 91 号 遥控 Q5 a/b: the camera rides on the drone (scripts/look.gd)
	var ride: Vector2 = look.cam_offset / maxf(zoom_now, 0.1) if look != null else Vector2.ZERO
	# never let one bad number take the whole picture away (user 2026-10-28: the view went black)
	if not (cam_pos + off + punch + lean + ride).is_finite():
		punch = Vector2.ZERO
		zoom_kick = 0.0
		lean = Vector2.ZERO
		ride = Vector2.ZERO
		if not cam_pos.is_finite():
			cam_pos = drone.global_position if drone != null and drone.global_position.is_finite() else SHIP_CENTER
			cam_vel = Vector2.ZERO
	cam.position = cam_pos + off + punch + lean + ride
	if not is_finite(zoom_now) or zoom_now <= 0.0 or not is_finite(zoom_kick):
		zoom_now = maxf(zoom_target, 0.1)
		zoom_kick = 0.0
	cam.zoom = Vector2(zoom_now, zoom_now) * (1.0 + zoom_kick)
	cam.rotation = sin(tt * 37.0) * 0.006 * sh + (look.cam_roll if look != null else 0.0)


# the view leaves the drone while the right button drags it or the pointer
# rests on a screen edge, and drifts back when let go
func _pan(dt: float) -> void:
	var edge := Vector2.ZERO
	if bot == null and state == "play" and not menu_open and not contract_open and not rmb_down and DisplayServer.window_is_focused():
		var vs := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, vs).has_point(m):
			if m.x < 6.0: edge.x = -1.0
			elif m.x > vs.x - 6.0: edge.x = 1.0
			if m.y < 6.0: edge.y = -1.0
			elif m.y > vs.y - 6.0: edge.y = 1.0
	if edge != Vector2.ZERO:
		cam_pan += edge * 1100.0 / maxf(zoom_now, 0.1) * dt
	elif not (rmb_down and rmb_moved >= 10.0):
		cam_pan = Pal.damp2(cam_pan, Vector2.ZERO, 5.0, dt)
	cam_pan = cam_pan.limit_length(40.0 * Geom.M)


# a few frames of near-freeze that sell an impact
func hitstop(sec: float) -> void:
	if state != "play" or bot != null or Txt.no_flash():
		return
	hitstop_t = maxf(hitstop_t, sec)


func shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if Txt.no_flash():
		return
	trauma = minf(1.0, trauma + amount)
	punch += dir * 12.0 * amount


# ---------------------------------------------------------------- intro & ending

# 72 号: a hulk home from the belt lies in the tug yard; the contract's opening pushes it from
# its berth there round to the dock (Vector2.INF: it comes in the old way, from the side)
# (user 2026-10-28 "拖船还是太慢了": 16 → 9 s round the station)
const PUSH_T := 9.0
var _yard_from = null
var _yard_mid := Vector2.ZERO        # the hull's middle from its origin (px), for the camera
# 87-6 (user 2026-10-27: the hulk went straight through the port and came in from its right): the
# way round, as points for the hull's origin, every leg clear of the districts and of the hulks
# parked in the yard: west out of the yard's column, south past the processing district, east under
# the berth's floor, north up its open side to the berth's level, then the push in as before
var yard_path: Array = []
const YARD_CLEAR := 10.0             # m kept from any structure and any parked hull


# the hull's box (px) round its origin, from its ship file
static func hull_box(sid: String) -> Rect2:
	var r := Ship.bounds(Ship.load_data(sid))
	return Rect2(r.position * Geom.M, r.size * Geom.M)


# what the hull's way out must keep clear of: every district, the berth's floor and tower, and
# the hulls parked in the yard's other slots (px)
func yard_obstacles(except_id: String) -> Array:
	var out: Array = []
	for z in Port.ZONES:
		out.append(PortStructure.box(z))
	out.append(Rect2(Vector2(Dock.TOWER_X - 4.0, -24.0) * Geom.M, Vector2(Dock.FLOOR_X1 - Dock.TOWER_X + 8.0, 24.0 + Dock.FLOOR_Y + 3.0) * Geom.M))
	if Career.usable() and not Career.data.is_empty() and Career.data.has("ship_market"):
		for a in ShipMarket.data().assets:
			if str(a.id) == except_id or not a.has("yard"):
				continue
			var hb := hull_box(TugYard.ship_of(a))
			var x1 := hb.end.x
			var o := TugYard.slot_px(int(a.yard), TugYard.ship_of(a)) - Vector2(x1, hb.get_center().y)
			out.append(Rect2(o + hb.position, hb.size))
	return out


func _yard_route(from: Vector2, hb: Rect2, except_id: String) -> Array:
	var M := Geom.M
	var obs := yard_obstacles(except_id)
	var clear := YARD_CLEAR * M
	# west until the hull's right edge is past every parked hull in the yard's column
	var col_left := from.x + hb.position.x
	for r in obs:
		if r.position.x < from.x + hb.end.x + clear and r.end.x > from.x + hb.position.x - clear and r.position.x < col_left:
			col_left = r.position.x
	var west_x := minf(from.x, col_left - clear - hb.end.x)
	# under everything there is
	var bottom := -INF
	for r in obs:
		bottom = maxf(bottom, r.end.y)
	var south_y := bottom + clear - hb.position.y
	var p_end := Vector2(ship_offset, 0.0)
	return [from, Vector2(west_x, from.y), Vector2(west_x, south_y), Vector2(p_end.x, south_y), p_end]


# the hull's origin (px) t s into the push round the station. user 2026-10-28 ("推的东西要有真正
# 物理效果，像无人机一样"): each leg is its own burn and brake, the hull stopped at every corner
# before the tug pushes it the new way — no turn at speed. A leg's time grows as the root of its
# length (the same burn, the same brake: d = a t²/4); the legs together take PUSH_T
func yard_at(t: float) -> Vector2:
	var n := yard_path.size()
	if n == 0:
		return world.position
	var w: Array = []
	var tot := 0.0
	for i in range(1, n):
		var r := sqrt((yard_path[i] as Vector2).distance_to(yard_path[i - 1]))
		w.append(r)
		tot += r
	if tot <= 0.0:
		return yard_path[n - 1]
	var left := clampf(t, 0.0, PUSH_T)
	for i in range(1, n):
		var d: float = float(w[i - 1]) / tot * PUSH_T
		if left <= d or i == n - 1:
			return (yard_path[i - 1] as Vector2).lerp(yard_path[i], Pal.ease_io(left / maxf(d, 0.0001)))
		left -= d
	return yard_path[n - 1]


# how long the opening spends in the yard route (0: it comes in the old way, from the side)
func yard_push_t() -> float:
	return PUSH_T if state == "intro" and yard_start() != Vector2.INF else 0.0


# a point along a polyline, by the share of its length
static func along(path: Array, u: float) -> Vector2:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	var want := clampf(u, 0.0, 1.0) * total
	for i in range(1, path.size()):
		var seg: float = (path[i] as Vector2).distance_to(path[i - 1])
		if want <= seg or i == path.size() - 1:
			return (path[i - 1] as Vector2).lerp(path[i], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return path[path.size() - 1]
func yard_start() -> Vector2:
	if _yard_from != null:
		return _yard_from
	_yard_from = Vector2.INF
	if job.is_empty() or not Career.usable() or Career.data.is_empty() or not Career.data.has("ship_market"):
		return _yard_from
	var a := ShipMarket.asset(str(job.get("id", "")))
	if a.is_empty() or not a.has("yard"):
		return _yard_from
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for pd in Ship.load_data(ship_id).get("pieces", []):
		for q in pd.get("poly", []):
			x1 = maxf(x1, float(q[0]))
			y0 = minf(y0, float(q[1]))
			y1 = maxf(y1, float(q[1]))
	var stern := Vector2(x1, (y0 + y1) * 0.5) if x1 > -INF else Vector2(40.0, 0.0)
	_yard_mid = stern * 0.5 * Geom.M
	_yard_from = TugYard.slot_px(int(a.yard), ship_id) - stern * Geom.M
	yard_path = _yard_route(_yard_from, hull_box(ship_id), str(job.get("id", "")))
	return _yard_from


func _intro(dt: float) -> void:
	var t := state_t
	var from: Vector2 = yard_start()
	if from != Vector2.INF:
		if t < PUSH_T:
			# out of the yard, round the station (clear of every structure), to the dock's mouth
			world.position = yard_at(t)
			# led by the hull's speed: the camera's spring trails a moving target by 2/√k of its speed
			# (user 2026-10-28: at the faster push the hull ran off the bottom of the screen)
			cam_override = world.position + _yard_mid + (yard_at(t + 1.0 / 60.0) - world.position) * 60.0 * CAM_LAG
			zoom_override = 0.22
			return
		t -= PUSH_T
	# the tug pushes GR-7 into the dock
	var k := Pal.ease_io(clampf(t / 3.4, 0.0, 1.0))
	world.position = Vector2(ship_offset * (1.0 - k), 0.0)
	cam_override = Vector2(21.0 * 48.0 + world.position.x * 0.35, -0.5 * 48.0)
	zoom_override = 0.62
	for i in dock.clamps.size():
		var on := clampf((t - 3.5 - i * 0.22) / 0.3, 0.0, 1.0)
		dock.clamp_t[i] = 1.0 - Pal.ease_out(on)
		if on > 0.0 and not dock.has_meta("cl%d" % i):
			dock.set_meta("cl%d" % i, true)
			var p: Vector2 = dock.clamps[i] * 48.0
			fx.flash(p, 60.0, 0.35, Pal.ink(0.8, 1.6))
			fx.sparks(p, Vector2.UP, 10, Pal.heat(1.0, 2.0), 260.0, 0.35, 1.2)
			shake(0.15)
			sfx.play("clamp")
	if t > 4.7 and not drone.alive:
		_launch_drone()
	if t > 5.0:
		cam_override = null
		zoom_override = -1.0
	if t > 6.2:
		world.position = Vector2.ZERO
		_end_intro()


# the empty berth comes up as it was left: no tug, no contract card, the drone flying on
func _enter_berth() -> void:
	world.position.x = 0.0
	for i in dock.clamps.size():
		dock.clamp_t[i] = 1.0
	state = "play"
	state_t = 0.0
	if not carry.is_empty():
		drone.alive = true
		drone.integrity = float(carry.get("integrity", 100.0))
		drone.spawn_t = 3.0
		drone.global_position = carry.pos
		drone.linear_velocity = carry.vel
		drone.reset_physics_interpolation()
		cam_pos = carry.cam
		zoom_now = float(carry.zoom)
		zoom_target = CAM_ZOOM
		carry = {}
	elif not drone.alive:
		_launch_drone()
		cam_pos = drone.global_position
		zoom_now = CAM_ZOOM
	if hud != null:
		if port_access != null and port_access.active():
			hud.show_hint(txt("pt_access_hint") % [Keys.label("terminal"),Keys.label("port")])
		else:
			hud.show_hint(txt("berth_hint") % Keys.label("terminal"))
	# the main line's chapter, said once as it begins (28 号; the author's lines)
	if career() and Career.usable():
		Mainline.announce(radio)
	# the run-down berth, seen for the first time (the author's line, design/台词待写_成长体系.md)
	if career() and Career.usable() and not has_upgrade("lights") and not Career.data.get("seen", {}).has("berth_broken"):
		var seen: Dictionary = Career.data.get("seen", {})
		seen["berth_broken"] = true
		Career.data.seen = seen
		# 26 号: the berth is yours by salvage claim, not inherited (the author's lines; empty says nothing)
		Copy.say(radio, "L_salvage_claim")
		Copy.say(radio, "L_berth_broken")
	# the colony ship off the port, seen for the first time (G6; the author's line)
	if career() and Career.usable() and not Career.data.get("seen", {}).has("ark_seen"):
		var seen2: Dictionary = Career.data.get("seen", {})
		seen2["ark_seen"] = true
		Career.data.seen = seen2
		Copy.say(radio, "L_ark_seen")


# what the berth's length goes by: the career's purchases (and the developer's kit)
func _upgrades_for_berth() -> Dictionary:
	var u: Dictionary = {}
	for k in ["berth88", "berth120", "berth200", "berth620"]:
		if has_upgrade(k):
			u[k] = true
	return u


# no ship in: the berth between contracts
func in_berth() -> bool:
	return ship.get("berth", false)


# 86 号 Q7: the berth's three faults are found by flying close (Repair.FIND_M): framed, one line,
# logged in the berth page's repairs
var _fault_t := 0.0
func _find_faults(dt: float) -> void:
	_fault_t += dt
	if _fault_t < 0.2:
		return
	_fault_t = 0.0
	if not career() or not Career.usable() or Career.data.is_empty() or belt or drone == null or not drone.alive:
		return
	for id in Repair.FAULTS:
		if Repair.found(id):
			continue
		var at := RepairShow.spot(id)
		if drone.global_position.distance_to(at) < Repair.FIND_M * Geom.M and Repair.find_fault(id):
			Career.save()
			var co = preload("res://scripts/fault_callout.gd").new()
			co.id = id
			co.at = at
			add_child(co)
			sfx.play("ok")


# a ship being stripped on a contract: the only time it can be ended early (pause menu, terminal)
# the core's heart cut (scripts/reactor.gd): the detonation's cinematic takes over
func start_nuke(at: Vector2) -> void:
	if nuke != null or ended:
		return
	nuke = preload("res://scripts/nuke.gd").new()
	add_child(nuke)
	nuke.setup(self, at)
	state = "nuke"
	state_t = 0.0


# the card is through: the contract settles as given up, nothing left in the berth
func end_nuke() -> void:
	nuked = true
	state = "play"
	finish_contract(true)


func can_end_early() -> bool:
	return state == "play" and not ended and not training and exam == null and not belt and not in_berth()


# 63 号: the bringing-in is over: back to the berth as it was
func end_towin() -> void:
	if state != "towin":
		return
	cam_override = null
	zoom_override = -1.0
	state = "play"
	state_t = 0.0


func _end_intro() -> void:
	if state != "intro":
		return
	# skipped in the middle of the tug pushing it round from the yard: the ship goes all the way into
	# the berth (user 2026-10-26: only x was reset — the hulk stayed up to ~100 m off, the drone
	# launched into an empty berth or into its hull)
	world.position = Vector2.ZERO
	world.reset_physics_interpolation()
	for i in dock.clamps.size():
		dock.clamp_t[i] = 0.0
	if not drone.alive:
		_launch_drone()
	cam_override = null
	zoom_override = -1.0
	state = "play"
	state_t = 0.0
	if exam != null:
		exam.on_start()
	elif (bot == null or not bot.get("skip_contract", false)) and not training:
		open_contract()


func _launch_drone() -> void:
	drone.alive = true
	drone.integrity = 100.0
	drone.spawn_t = 0.0
	drone.global_position = Dock.BAY * Geom.M + Vector2(-30, 0)
	drone.reset_physics_interpolation()
	drone.linear_velocity = Vector2(520, 0)
	fx.flash(drone.global_position, 50.0, 0.3, Pal.heat(0.6, 1.8))
	fx.ring(drone.global_position, 10.0, 60.0, 0.4, Pal.ink(0.6))
	sfx.play("launch")


func finish_contract(early: bool, reviewed: bool = false) -> void:
	if ended or (settlement_retry_required and not early):
		return
	if order_review_deferred and not early and not reviewed: return
	if tools.cutting:
		tools._finish_cut()
	var cached_settlement: bool = Career.data.get("settled_jobs",{}).has(str(job.get("id","")))
	if not reviewed and not cached_settlement and work_order != null and work_order.active() and not (work_order.previous+work_order.receipts).is_empty():
		open_order_review(early)
		return
	order_review_deferred = false
	var previous_rest := income_rest
	if early and not training and exam == null:
		var rest := 0.0
		for p in pieces_left():
			rest += world.scrap_value(p)
		income_rest = snappedf(rest * REST_SCRAP, 1.0)
	if career() and Career.usable():
		Career.load_or_new()
		var before := Career.data
		var cached: Dictionary = before.get("settled_jobs", {}).get(str(job.get("id", "")), {})
		if cached.is_empty():
			Career.data = before.duplicate(true)
			Career.file_notes(ship_id, verified)
			var old_result_key: String = plan.result_key if plan != null else ""
			var old_result_arg: String = plan.result_arg if plan != null else ""
			if plan != null: plan.commit()
			Consum.settle_job(job)
			career_result = Career.settle(settle_report())
			if career_result.get("save_failed",false):
				Career.data = before
				income_rest = previous_rest
				career_result = {}
				settlement_retry_required = true
				if plan != null:
					plan.result_key = old_result_key
					plan.result_arg = old_result_arg
				say("g4_settle_failed",drone.global_position)
				hud.show_hint(txt("g4_settle_failed"))
				return
		else:
			career_result = cached.duplicate(true)
			career_result.already_settled = true
		if gear != null: gear.finalize()
	settlement_retry_required = false
	ended = true
	state = "ending"
	state_t = 0.0
	tools.release_grab(false)
	if not early:
		slowmo = 0.5
	cam_override = Vector2(21.0 * 48.0, -0.2 * 48.0)
	zoom_override = 0.6
	if story != null and story.wants_epilogue():
		story.start_epilogue(early)
	else:
		hud.start_ending(early)
	sfx.play("end")
	# a developer's test contract leaves the career's save and records alone
	if (not testing or SaveGame.allow_test) and not dev_job():
		SaveGame.clear()
	if not testing and not dev_job():
		best = SaveGame.record_best(recovery_rate(), net(), playtime, hud.grade())
	if career() and Career.usable():
		if job.has("outro") and not early:
			Copy.say(radio, job.outro)
		if career_result.installment + career_result.interest > 0.0:
			Copy.say(radio, "T_loan_installment", "term")
		if career_result.bonus > 0.0 and playtime <= standard_time():
			Copy.say(radio, "L_bonus")
		if career_result.short > 0.5:
			Copy.say(radio, "L_loan_short")
		# gear lost for the first time (the author's line)
		if career_result.get("gear_first_lost",false) and not career_result.get("already_settled",false):
			Copy.say(radio, "L_gear_lost")


# what the career needs to know about how this contract went
func settle_report() -> Dictionary:
	var tb := {}
	for k in time_by:
		tb[k] = snappedf(float(time_by[k]), 0.1)
	return {"job_id":str(job.get("id","")),"earned": earned(), "losses": losses, "rate": recovery_rate(), "grade": hud.grade(), "time": playtime, "fee": fee, "bonus": bonus(), "used": used, "ops": ops,
		"bonuses": bonuses(), "incidents": incidents.duplicate(true), "time_by": tb, "gear": gear.settlement_report() if gear != null else {},
		"material_receipts":material_receipts.duplicate(true), "parts": parts_in.duplicate(true), "parts_value": parts_value,
		# 64 号: the furnace's scrap, cast into ingots (tonnes from its value at this ship's metal rate)
		"ingot_value": income_metal, "ingot_t": income_metal / maxf(1.0, world.metal_price), "nuke": nuked, "structure_t": snappedf(structure_t, 0.01), "gas_take": sys.gas_take.duplicate() if GasLine.keeping() else {},"work_order":work_order.report() if work_order != null and work_order.active() else {}}


# the contract's standard time (0: none, like the first contract)
func standard_time() -> float:
	return float(job.get("time", 0.0))


# what the contract pays on top of the books (V2 2.2 / 2.6): [label key, amount]
#   time     finished within the standard time (a fast job pays a bigger share)
#   rate     the recovery rate reached 70 / 80 / 92 %
#   named    each named piece of equipment delivered whole (a rescue pays per piece already)
#   safe     a safe-recovery job with no incident at all
func bonuses() -> Array:
	if job.is_empty() or training or exam != null:
		return []
	var out: Array = []
	var g: String = goal()
	if standard_time() > 0.0:
		out.append(["e_bonus", Career.time_bonus(net(), playtime, standard_time(), Career.FAST_BONUS if g == "fast" else Career.BONUS)])
	var r := recovery_rate()
	for th in RATE_BONUS:
		if r >= th[0]:
			out.append(["e_rate_bonus", snappedf(earned() * th[1], 1.0)])
			break
	if scope() != "rescue":
		var named := 0.0
		for tg in must_value:
			named += maxf(MUST_MIN, float(must_value[tg]) * (MUST_VALUABLE if g == "valuable" else MUST_SHARE))
		if named > 0.0:
			out.append(["e_must_bonus", snappedf(named, 1.0)])
	if g == "safe" and incidents.is_empty():
		out.append(["e_safe_bonus", snappedf(earned() * SAFE_SHARE, 1.0)])
	return out


func bonus() -> float:
	var sum := 0.0
	for b in bonuses():
		sum += float(b[1])
	return sum


# the order's goal on top of its scope: "safe", "fast", "valuable" (or none, like the opening contracts)
func goal() -> String:
	return job.get("goal", "")


func career() -> bool:
	return not training and not ship.has("exam") and ((not job.is_empty() and not dev_job()) or (in_berth() and Career.usable()))


# a contract the developer built and started (DevPanel): played like any other, settled into nothing
func dev_job() -> bool:
	return job.get("dev", false)


func _ending(_dt: float) -> void:
	pass


func restart() -> void:
	# a developer's test contract comes back as it was built
	if dev_job():
		contract = job.duplicate(true)
		start_ship = ship_id
	Look.time_k(1.0)
	get_tree().paused = false
	get_tree().reload_current_scene()


# the prologue's cable is on (32 号): the tow home, then the career goes on at Berth 07
func finish_prologue() -> void:
	Career.certify("prologue")
	if not Txt.certified:
		Txt.certified = true
		Txt.cert_kind = "prologue"
		Txt.save_settings(testing)
	var seen: Dictionary = Career.data.get("seen", {})
	seen["belt_prelude"] = true
	Career.data.seen = seen
	# user 2026-10-26: "把 TS1 塞到拆第一艘船前面" — the hulk towed home, the base course first,
	# then the real ship. A career that has not passed it here must (no skipping it)
	if ts1_due():
		Career.data.ts1_required = true
	Career.save()
	if (testing and not cine_in_tests) or bot != null:
		_after_prologue()
		return
	var pre = preload("res://scripts/belt_prelude.gd").new()
	pre.ship = "tug"
	get_tree().paused = true
	prelude_on = true
	pre.on_done = func():
		prelude_on = false
		get_tree().paused = false
		_after_prologue()
	add_child(pre)


# the base course still owed by this career before its first ship
static func ts1_due() -> bool:
	return Career.usable() and not Career.data.is_empty() and str(Career.data.get("cert_kind", "")) != "full" and not _did_first_ship()


static func _did_first_ship() -> bool:
	for h in Career.data.get("history", []):
		if str(h.get("id", "")) == "TUG-001":
			return true
	return false


# after the tow home: TS-1 if it is owed, else the first ship
func _after_prologue() -> void:
	if ts1_due():
		start_ship = "ts1"
		contract = {}
		SaveGame.load_requested = false
		Look.time_k(1.0)
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	after_training("contract")


# the course is over: the apprentice assessment, or straight to the first contract
func after_training(where: String) -> void:
	# the base course passed: the main line's demand is met
	if Career.usable() and not Career.data.is_empty() and str(Career.data.get("cert_kind", "")) == "full":
		Career.data.erase("ts1_required")
		Career.save()
	SaveGame.clear(SaveGame.train_path)
	Look.time_k(1.0)
	get_tree().paused = false
	if where != "exam" and Career.usable():
		play_career(get_tree())
		return
	start_ship = "exam" if where == "exam" else "gr7"
	SaveGame.load_requested = false
	get_tree().reload_current_scene()


# after the assessment: 0 take it again, 1 on to the first contract
func exam_choice(i: int) -> void:
	if i == 0:
		Look.time_k(1.0)
		get_tree().paused = false
		start_ship = "exam"
		SaveGame.load_requested = false
		get_tree().reload_current_scene()
	else:
		after_training("contract")


func skip_training() -> void:
	if not Txt.certified:
		Txt.certified = true
		Txt.cert_kind = "skipped"
		Txt.save_settings(testing)
	Career.certify("skipped")
	after_training("contract")


func to_title() -> void:
	if state == "play":
		SaveGame.save(self)
	if (training or career()) and not Career.data.is_empty():
		Career.save()
	Look.time_k(1.0)
	get_tree().paused = false
	var tree := get_tree()
	Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/title.tscn"))


# the contract is over and settled: a career goes back to the berth terminal
func leave() -> void:
	if dev_job():
		# back to where the developer started it from
		Look.time_k(1.0)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/terminal.tscn" if job.get("dev_from", "") == "terminal" and Career.usable() else "res://scenes/title.tscn")
		return
	if not career():
		to_title()
		return
	Look.time_k(1.0)
	get_tree().paused = false
	# the tug takes what is left of the ship out, and the berth stays: the next
	# contract is picked at the berth's computer (or with the terminal key)
	_tow_out()


func _tow_out() -> void:
	if state == "towout":
		return
	state = "towout"
	state_t = 0.0
	hud.ending = false
	tools.release_grab(false)
	# what's still loose rides out with the hull
	for b in world.bodies:
		if is_instance_valid(b):
			b.set_deferred("freeze", true)
	cam_override = Vector2(21.0 * 48.0, -0.5 * 48.0)
	zoom_override = 0.62
	# the drone stays where the operator left it while the hull goes (it was being swept out with
	# it now and then, so the empty berth came up with it 28 m away — 91 号 seamless handover):
	# out of the hull's way for the tow, holding station; the berth's next scene makes a fresh one
	if drone != null and drone.alive:
		drone.collision_mask = drone.collision_mask & ~(1 | World.STATIC_LAYER)
		drone.linear_velocity = Vector2.ZERO
	sfx.play("clamp")


# the hull goes out the way it came in: the tug pulls it away, speeding up
func _towout(rdt: float) -> void:
	var k := clampf(state_t / TOW_T, 0.0, 1.0)
	world.position.x = ship_offset * pow(k, 3.0)
	for i in dock.clamps.size():
		dock.clamp_t[i] = clampf(state_t / 0.4 - i * 0.25, 0.0, 1.0)
	if state_t >= TOW_T and not _berth_asked:
		_berth_asked = true
		_to_berth()


var _berth_asked := false


func _to_berth() -> void:
	carry = {"pos": drone.global_position, "vel": drone.linear_velocity, "cam": cam.position if cam != null else cam_pos,
		"zoom": zoom_now, "integrity": drone.integrity if drone.alive else 100.0}
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	var tree := get_tree()
	Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/main.tscn"))


# the special courses (design/新手教程与图鉴定案.md): the first of them now, the rest
# after it, then the contract waiting on them (or back to the terminal)
static func start_courses(classes: Array, then: String) -> void:
	course_chain = classes.duplicate()
	course_then = then
	start_ship = Codex.course_ship(str(course_chain.pop_front()))
	contract = {}


# a special course passed: the next one, the contract, or the terminal
func after_special() -> void:
	Look.time_k(1.0)
	get_tree().paused = false
	var tree := get_tree()
	if not course_chain.is_empty():
		start_ship = Codex.course_ship(str(course_chain.pop_front()))
		SaveGame.load_requested = false
		tree.reload_current_scene()
		return
	var then := course_then
	course_then = ""
	if then == "contract" and Career.usable():
		play_career(tree)
		return
	if then == "contract_loadout" and Career.usable():
		if loadout_route() == "loadout":
			tree.change_scene_to_file("res://scenes/terminal.tscn")
			return
		play_career(tree)
		return
	if Career.usable():
		tree.change_scene_to_file("res://scenes/terminal.tscn")
	else:
		tree.change_scene_to_file("res://scenes/title.tscn")


# the courses a contract waited on are passed (25 号): "loadout" when its loadout page is
# next (the terminal opens it, loadout_after_course), "career" when something still waits
static func loadout_route() -> String:
	var waiting: Dictionary = Career.active()
	if not waiting.is_empty() and Codex.missing(str(waiting.get("ship", ""))).is_empty():
		loadout_after_course = true
		return "loadout"
	return "career"


# the career's contract in hand (the first one after training), or the terminal when there is none
static func play_career(tree: SceneTree) -> void:
	Career.load_or_new()
	var waiting: Dictionary = Career.active()
	var miss := Codex.required(str(waiting.get("ship", ""))) if not waiting.is_empty() else []
	if not miss.is_empty():
		# a contract taken on a family of ship never trained for: its courses first,
		# then its loadout page and the job (25 号)
		start_courses(miss, "contract_loadout")
		SaveGame.load_requested = false
		tree.change_scene_to_file("res://scenes/main.tscn")
		return
	var a: Dictionary = Career.sign_active()
	if a.is_empty():
		start_ship = "berth"
		contract = {}
		SaveGame.load_requested = false
		tree.change_scene_to_file("res://scenes/main.tscn")
		return
	contract = a
	start_ship = a.get("ship", "gr7")
	var saved := SaveGame.read(SaveGame.path) if SaveGame.exists() else {}
	# only a save of this very contract (user 2026-10-27 crash: a save made in the empty berth has
	# no job, and the old default took it for this contract — the berth was then loaded as its ship)
	SaveGame.load_requested = not saved.is_empty() and saved.has("job") and str(saved.job.get("id", "")) == str(a.get("id", ""))
	tree.change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- economy

func earned() -> float:
	# a part-ship contract buys pieces, not the ship's gas and fluids
	var reserved := 0.0
	if work_order != null and work_order.active(): reserved = work_order.reserved_value()-work_order.stock_sale_value()
	if scope() != "full":
		return income_equip + income_metal + income_hazard + income_rest-reserved
	return income_equip + income_metal + income_hazard + income_rest + sys.gas_value() + sys.fluid_value()-reserved


# pieces of the contract still to come off (in scope, not yet delivered)
func pieces_left() -> Array:
	if nuked:
		return []
	var out: Array = []
	for id in world.order:
		var p = world.pieces[id]
		if not p.gone and p.scope:
			out.append(p)
	return out


# how many are left (the HUD asks every frame): counted again only when pieces came or went
var _left_key := Vector2i(-1, -1)
var _left_n := 0


func left_count() -> int:
	var k := Vector2i(world.order.size(), world.gone_n)
	if k != _left_key:
		_left_key = k
		_left_n = pieces_left().size()
	return _left_n


# "full" | "section" | "rescue" (Variant._scope)
func scope() -> String:
	return ship.get("scope", {}).get("kind", "full")


# a section contract's boundary (m), or -1
func boundary() -> float:
	return float(ship.get("scope", {}).get("boundary", -1.0))


# what a piece would have fetched (whole equipment at its value and condition, the rest as scrap)
func worth(p) -> float:
	if p.cls == "equip" and p.intact:
		return p.value * clampf(p.cond, 0.0, 1.0)
	return world.scrap_value(p)


# taken from outside a section contract's section, or cut there: the breach is charged
func breach(p, cut: bool, at: Vector2) -> void:
	if scope() != "section" or p.scope:
		return
	var amount: float
	if cut:
		amount = worth(p) * Variant.BREACH_CUT if p.cls == "equip" and p.intact else Variant.BREACH_CUT_METAL
	else:
		amount = worth(p)
	if amount > 0.5:
		lose("loss_breach_cut" if cut else "loss_breach_take", snappedf(amount, 10.0), at)


var full_value := 0.0          # 78 号 P0-1: set at load, see rate_base()


func recovery_rate() -> float:
	return (earned() + material_recovery_value) / rate_base()


# the rate's denominator: the authored total, or what the ship can really pay if that is more
func rate_base() -> float:
	var authored := float(ship.get("value", {}).get("total", 120000.0))
	return maxf(authored, full_value) if scope() == "full" else authored


func net() -> float:
	return earned() - losses - fee


func incident(kind: String, detail: String = "") -> void:
	incidents.append([snappedf(playtime, 0.1), kind, detail])
	if plan != null and plan.running and kind in ["blowout","fire","arc","burst","blast","prop_blast","o2_fire","tank_burst","tank_rupture","drone_lost"]:
		plan.cancel()
	if assist != null:
		assist.on_incident(kind)


# value knocked off a piece (it still sells, for less): kept for the settlement's review
func note_loss(reason: String, tag: String, amount: float) -> void:
	if amount >= 1.0:
		devalued.append([reason, tag, snappedf(amount, 1.0)])


func _dent(p, new_cond: float, reason: String) -> void:
	if p.cls == "equip" and p.intact and new_cond < p.cond:
		note_loss(reason, p.tag, (p.cond - new_cond) * p.value)
	p.cond = new_cond


# a named piece of the contract is past saving: say so now, not at the settlement
func mandatory_gone(p, reason: String) -> void:
	if not p.mandatory or mandatory_lost.has(p.tag) or mandatory_ok.get(p.tag, false):
		return
	mandatory_lost[p.tag] = reason
	incident("mandatory_lost", p.tag)
	hud.mandatory_alert(p.tag, reason)
	sfx.play("warn")
	shake(0.2)


func lose(key: String, amount: float, at: Vector2) -> void:
	# the training rig is insured: a mistake costs a tenth
	if training or exam != null:
		amount *= 0.1
	losses += amount
	loss_lines.append([key, amount])
	fx.number(at, "−" + Pal.money(amount).trim_prefix("$"), Pal.heat(1.0, 1.4), 22)
	feed.push_front([txt(key), -amount, 0.0])
	hud.pop_credits(-amount)


# ore pouring out of a hopper gate into the trough: paid by the tonne, booked a second at a time
var _ore_due := 0.0
var _ore_t := 0.0


func on_ore_in(v: float) -> void:
	# a part-ship contract buys pieces: the hopper's fines run out unpaid
	if scope() != "full":
		return
	_ore_due += v
	if playtime - _ore_t < 1.0:
		return
	_ore_t = playtime
	var at := Vector2(Dock.metal_x, Dock.TROUGH_Y - 1.0) * Geom.M
	ledger.append([txt("ore_fines"), "metal", _ore_due])
	gain("metal", _ore_due, at, txt("ore_fines"))
	log_op("arm_haul")
	_ore_due = 0.0


func gain(kind: String, amount: float, at: Vector2, label: String) -> void:
	match kind:
		"equip": income_equip += amount
		"metal": income_metal += amount
		"hazard": income_hazard += amount
	fx.number(at, "+" + Pal.money(amount), Pal.ink(1.0, 1.5), 26 if amount > 3000 else 20)
	feed.push_front([label, amount, 0.0])
	hud.fly_credits(at, amount)


func piece_value(p, zone: String) -> float:
	if not p.scope:
		return 0.0
	# a rescue pays each named piece its fixed fee, whole at the equipment mouth, and nothing else
	if scope() == "rescue":
		if zone == "equip" and p.cls == "equip" and p.intact:
			return float(ship.scope.get("pay", {}).get(p.tag, 0.0))
		return 0.0
	return _piece_value(p, zone)


func _piece_value(p, zone: String) -> float:
	var scrap: float = world.scrap_value(p)
	var dest: String = sys.dest_of(p)
	var v := 0.0
	if p.cls == "equip" and p.intact:
		var full: float = p.value * clampf(p.cond, 0.0, 1.0)
		match zone:
			"equip": v = full if dest == "equip" else full * 0.4
			"metal": v = scrap
			"hazard": v = full * 0.4 if dest == "hazard" else full * 0.3
	else:
		v = scrap * (0.5 if zone == "hazard" else (1.0 if zone == "metal" else 0.8))
	if p.contam:
		v *= 0.75
	return v


func judge(b, zone: String) -> Dictionary:
	if zone == "metal" and Career.plant_reserved(self): return {"ok":false,"reason":"rej_plant_reserved"}
	var total := 0.0
	var metal_m := 0.0
	var all_m := 0.0
	var hazard := false
	var equip_intact := false
	for p in b.pieces:
		all_m += p.mass
		var d: String = sys.dest_of(p)
		if d == "hazard":
			hazard = true
		if p.cls != "equip" or not p.intact:
			metal_m += p.mass
		else:
			equip_intact = true
		total += piece_value(p, zone)
	match zone:
		"equip":
			if hazard:
				return {"ok": false, "reason": "rej_hazard"}
			if not equip_intact:
				return {"ok": false, "reason": "rej_scrap"}
			# 94 号: a block of the telescope's mirror (a backplane with its segments on) is one unit
			if metal_m > all_m * 0.2 and (work_order == null or not work_order.accepts_assembly(b)) and not (optics != null and optics.is_block(b)):
				return {"ok": false, "reason": "rej_mixed"}
		"hazard":
			if equip_intact and not hazard:
				return {"ok": false, "reason": "rej_not_hazard"}
	return {"ok": true, "value": total, "hazard": hazard, "equip": equip_intact}


func on_reject(b, zone: String, verdict: Dictionary) -> void:
	say(verdict.reason, Dock.zpos(zone) - Dock.ZONES[zone].face * 20.0)
	sfx.play("reject")
	fx.flash(Dock.zpos(zone), 80.0, 0.3, Pal.heat(0.5, 1.4))


func on_swallow_start(b, zone: String) -> void:
	sfx.play("swallow_" + Dock.kind(zone))


func on_swallowed(b, mouth: String) -> void:
	var batches = preload("res://scripts/material_batches.gd")
	# Guard the entire native receiver transaction, not only retained raw pieces.
	# This also blocks reentrant notifications before this body is removed.
	if batches.retains(job):
		var identities: Array = []
		for p in b.pieces:
			var identity: String = batches.receipt_id(str(job.id), p.key if p.key != "" else "#%d" % p.id)
			if receiver_commits.has(identity): return
			identities.append(identity)
		for identity in identities: receiver_commits[identity] = true
	# a second equipment bay pays and counts as the first; the effects play where it is
	var zone := Dock.kind(mouth)
	var at: Vector2 = Dock.zpos(mouth) - Dock.ZONES[mouth].face * 30.0
	var names: Array = []
	var v := 0.0
	var boom := false
	var retained_keys := {}
	for p in b.pieces:
		p.into = zone
		var piece_payment := piece_value(p, zone)
		if batches.eligible(self, p, zone):
			if not batches.has_piece(material_receipts, str(job.id), p.key):
				material_receipts.append(batches.received(job, p, piece_payment))
				material_recovery_value += piece_payment
			retained_keys[p.key] = true
		else:
			v += piece_payment
		if p.tag != "" and p.cls == "equip":
			names.append(p.tag)
			verify("pieces", p.tag, {"to": zone})
		if zone == "equip" and p.intact and p.cls == "equip" and p.mandatory:
			mandatory_ok[p.tag] = true
			must_value[p.tag] = float(p.value)
		elif p.mandatory and p.cls == "equip":
			mandatory_gone(p, "mg_wrong_mouth")
		if story != null and p.intact:
			story.on_delivered(p, zone)
		if zone == "metal" and sys.dest_of(p) == "hazard":
			boom = true
		# whatever it held goes with it
		var fv: String = sys.fluid_in_piece(p)
		if fv != "":
			sys.set_fluid(fv, 0.0)
		if sys.src.has(p.tag) and sys.src[p.tag].kind == "cap":
			sys.drain_source(p.tag)
	for p in b.pieces:
		breach(p, false, at)
	var label := ", ".join(names) if not names.is_empty() else txt("scrap_metal")
	if not b.pieces.any(func(p): return p.scope):
		label = txt("sc_out")
	# the berth's repairs (scripts/repair.gd): whole equipment of a useful class goes on the
	# shelf instead of being paid out; metal through the furnace is structure by the tonne
	if work_order != null: work_order.capture(b,zone)
	if career() and scope() != "rescue":
		if zone == "equip":
			for p in b.pieces:
				if work_order != null and work_order.owns(p): continue
				var cls := Repair.class_of(p, sys)
				if cls != "" and p.scope:
					parts_in.append(Repair.part_of(p, cls, ship_id, str(job.get("id", ""))))
					parts_value += piece_value(p, zone)
					say("rp_part_in", at + Vector2(0, -60), p.tag)
					if not hints_seen.has("rp_part"):
						hints_seen["rp_part"] = true
						if not career() or Career.hint_once("rp_part"):
							hud.show_hint(txt("hint_rp_part_in"))
						if Career.usable() and not Career.data.get("seen", {}).has("parts_first"):
							var seen2: Dictionary = Career.data.get("seen", {})
							seen2["parts_first"] = true
							Career.data.seen = seen2
							Copy.say(radio, "L_parts_first")
		elif zone == "metal":
			for p in b.pieces:
				if p.scope and not retained_keys.has(p.key) and (p.cls != "equip" or not p.intact):
					structure_t += p.mass
	ledger.append([label, zone, v])
	# Correlated notification from the actual receiver commit. Keep the legacy
	# ledger format and all income/stock/settlement behavior unchanged.
	var received_keys: Array = b.pieces.map(func(p): return p.key)
	received_keys.sort()
	load_received.emit(received_keys,zone,v,str(job.get("id","")))
	# the work plan learns where this went (G4): by the operator's hand or on their mark
	if plan != null:
		plan.on_haul(b, zone, b.get_meta("hauled", false) or b.get_meta("manual_mark", false))
	if b.get_meta("arm_drop", -1.0) >= 0.0 or not b.get_meta("hauled", false):
		# the arm brought it, or it drifted in on the mouth's own pull: nobody's hands
		log_op("arm_haul")
	elif zone == "hazard":
		log_op("deliver_hazard")
	elif b.pieces.any(func(p): return p.cls == "equip" and p.intact):
		log_op("deliver_equip")
	else:
		log_op("haul_scrap")
	if zone == "metal" and b.pieces.any(func(p): return p.cls == "equip" and p.intact):
		say("equip_as_scrap", at)
	if tutorial != null:
		tutorial.on_recovered(b, zone)
	if exam != null:
		exam.on_delivered(b, zone)
	gain("equip" if zone == "equip" else ("hazard" if zone == "hazard" else "metal"), v, at, label)
	var col := Pal.heat(1.0, 2.2) if zone == "metal" else (Pal.tint(Pal.FLUID, 0.9, 1.4) if zone == "hazard" else Pal.ink(0.9, 1.5))
	fx.flash(Dock.zpos(mouth), 140.0, 0.5, col)
	fx.ring(Dock.zpos(mouth), 20.0, 140.0, 0.5, col, 2.0)
	fx.sparks(Dock.zpos(mouth), -Dock.ZONES[mouth].face, 30, col, 480.0, 0.55, 0.9)
	var face: Vector2 = Dock.ZONES[mouth].face
	match zone:
		"metal":
			for i in 46:
				fx.molten(Dock.zpos(mouth) + Vector2(randf_range(-80, 80), 0), (-face * randf_range(160, 520)).rotated(randf_range(-0.5, 0.5)), randf_range(1.2, 2.4))
			fx.flash(Dock.zpos(mouth) - face * 40.0, 320.0, 0.8, Pal.heat(0.7, 3.0))
		"equip":
			for i in 3:
				fx.ring(Dock.zpos(mouth) - face * 30.0, 10.0 + i * 20.0, 150.0 + i * 50.0, 0.5 + i * 0.15, Pal.ink(0.7, 1.8), 1.6)
		"hazard":
			for i in 24:
				fx.puff(Dock.zpos(mouth), (-face * 200.0).rotated(randf_range(-1.2, 1.2)), 0.9, 8.0, 40.0, Pal.tint(Pal.FLUID, 0.12))
	hitstop(0.04)
	shake(0.12 + minf(0.25, b.total_mass() * 0.06))
	sfx.play("eat_" + zone)
	if boom:
		_furnace_boom()
	if gear != null:
		gear.on_swallowed(b, zone)
	world.remove_body(b)
	_check_done()


func _furnace_boom() -> void:
	incident("furnace")
	var p := Dock.zpos("metal")
	fx.flash(p, 260.0, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(p, 20.0, 300.0, 0.6, Pal.heat(0.9, 2.0), 3.0)
	fx.burst_shards(p, 24, 600.0, Pal.heat(0.9, 1.6), 12.0)
	shake(0.7)
	sfx.play("boom")
	lose("loss_furnace", 3000.0, p + Vector2(0, -60))


# the recovery arm let a load go over the furnace (the operation log counts it as the machine's)
func on_arm_drop(_b) -> void:
	sfx.play("release")


# a cut-off that slipped through the torn net (scripts/repair.gd: net_fix)
func on_debris_lost(value: float, at: Vector2) -> void:
	if value > 0.5:
		say("rp_debris_lost", at + Vector2(0, -30))
		if not hints_seen.has("rp_net"):
			hints_seen["rp_net"] = true
			if not career() or Career.hint_once("rp_net"):
				hud.show_hint(txt("hint_rp_net"))


func on_debris_in(value: float, at: Vector2) -> void:
	income_metal += value
	hud.fly_credits(at, value)
	sfx.play("net")
	_check_done()


func _check_done() -> void:
	if state != "play" or training or exam != null or in_berth():
		return
	for id in world.order:
		if not world.pieces[id].gone and world.pieces[id].scope:
			return
	if not dock.debris.is_empty() or not dock.swallowing.is_empty():
		await get_tree().create_timer(0.8).timeout
	finish_contract(false)


# ---------------------------------------------------------------- bodies

func on_body_freed(b) -> void:
	if bio != null:
		bio.on_freed(b)
	if media != null:
		for q in b.pieces:
			media.on_manifold(q)
	if rails != null:
		rails.on_freed(b)
	if furnace != null:
		furnace.on_freed(b)
	if drones != null:
		drones.on_freed(b)
	if liner != null:
		liner.on_freed(b)
	if boxbeam != null:
		boxbeam.on_freed(b)
	if sail != null:
		sail.on_freed(b)
	if reactor != null:
		reactor.on_freed(b)
	if softshell != null:
		softshell.on_freed(b)
	if flywheel != null:
		flywheel.on_freed(b)
	if rings != null:
		rings.on_freed(b)
	if spine != null:
		spine.on_freed(b)
	if boiloff != null:
		boiloff.on_freed(b)
	if drillstring != null:
		drillstring.on_freed(b)
	if nested != null:
		nested.on_freed(b)
	if waterball != null:
		waterball.on_freed(b)
	if magnets != null:
		magnets.on_freed(b)
	if optics != null:
		optics.on_freed(b)
	if immersion != null:
		immersion.on_freed(b)
	if thermal != null:
		thermal.on_freed(b)
	if composite != null:
		composite.on_freed(b)
	if dilution != null:
		dilution.on_freed(b)
	if tether != null:
		tether.on_freed(b)
	if sandwich != null:
		sandwich.on_freed(b)
	if ice != null:
		ice.on_freed(b)
	var m: float = b.total_mass()
	for p in b.pieces:
		if p.has_meta("snap_kick"):
			b.linear_velocity = p.get_meta("snap_kick") * 260.0
			b.angular_velocity = randf_range(-1.5, 1.5)
			p.remove_meta("snap_kick")
	var all_metal := true
	var crews := false
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			all_metal = false
		# 92 号: the works crew's wreck is hauled off by its own drones, not blown into the net
		if str(p.key).begins_with("crew:"):
			crews = true
	if all_metal and m < debris_max() and not crews:
		# tiny cut-offs go straight to the debris net
		var vel: Vector2 = (b.global_position - SHIP_CENTER).normalized() * randf_range(60, 140)
		for p in b.pieces:
			dock.add_debris(world.world_poly(p), vel, world.scrap_value(p) if p.scope and scope() != "rescue" else 0.0)
			breach(p, false, world.frame(p) * Geom.centroid(p.poly))
		world.remove_body(b)
		sfx.play("debris")
		return
	# its outline lights up and spreads out: it is free
	for p in b.pieces:
		fx.outline_pulse(world.world_poly(p), 0.6, Pal.ink(0.95, 2.0))
	# a gentle shove away from the hull so it reads as free
	var away: Vector2 = (b.global_position - SHIP_CENTER).normalized()
	b.linear_velocity += away * 10.0
	b.angular_velocity += randf_range(-0.05, 0.05)
	sfx.play("free", b.global_position, clampf(m / 2.0, 0.3, 1.0))
	# the last kerf flashes white-hot along its length and sheds sparks
	var now := Time.get_ticks_msec() / 1000.0
	var lit := 0
	for p in b.pieces:
		for h in p.heat:
			if now - h[1] > 0.6:
				continue
			var pl: PackedVector2Array = b.global_transform * (h[0] as PackedVector2Array)
			for i in range(0, pl.size(), 3):
				fx.sparks(pl[i], Vector2.from_angle(randf() * TAU), 2, Pal.heat(1.0, 3.2), 260.0, 0.45, PI)
				if randf() < 0.4:
					fx.molten(pl[i], Vector2.from_angle(randf() * TAU) * randf_range(30, 110), 1.8)
				lit += 1
	var com: Vector2 = b.global_transform * b.center_of_mass
	# 91 号: a short white-hot breath at the break, not a red blot over the plate
	fx.flash(com, 34.0 + 26.0 * minf(m, 2.0), 0.22, Color(1.7, 1.25, 0.85, 0.42))
	fx.ring(com, 10.0, 90.0 + 40.0 * minf(m, 2.0), 0.45, Pal.ink(0.5, 1.6), 1.6)
	fx.burst_shards(com, 6 + int(m * 4), 160.0, Pal.ink(0.7), 6.0)
	shake(0.1 + minf(0.25, m * 0.06), away)
	# 95 号 (user 2026-10-28, the demolition's weight, kept within bounds): a big section coming away
	# is heard and felt by its weight — the steel's groan, a harder shake, and for the biggest a
	# moment's hold as it goes
	if m >= 2.0:
		sfx.play("hull_break", com, clampf(0.45 + m / 12.0, 0.45, 1.0), clampf(1.15 - m / 40.0, 0.8, 1.1))
		shake(minf(0.25, (m - 2.0) * 0.03), away)
		if m >= 6.0:
			hitstop(0.08)
	if m > 0.5:
		hitstop(0.045 + minf(0.05, m * 0.015))
	# 91 号 Q11: a big piece coming free is a moment — the clock slows (the physics step stays 1/120 s)
	if m >= Look.SLOW_MASS and Txt.slowmo_on and state == "play" and bot == null and not Txt.no_flash():
		slowmo = maxf(slowmo, Look.SLOW_T)
	if m >= Look.SLOW_MASS and look != null and not Txt.no_flash():
		look.big_free(b, com, m)
	fx.puff(com, Vector2.ZERO, 0.9, 14.0, 80.0, Pal.ink(0.05))
	hint("free_body")


func _bodies_upkeep(dt: float) -> void:
	for b in world.bodies:
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.age += dt
		var dv: float = b.hit_imp / maxf(b.mass, 0.05)
		if dv > 55.0:
			# what the contact impulse says, but no more than the body's motion really
			# changed: a light piece pressed between two others takes big impulses that
			# cancel out, and is not knocked by them
			var bb := Rect2()
			for q in b.pieces:
				var qb := Geom.bbox(world.world_poly(q))
				bb = qb if bb.size == Vector2.ZERO else bb.merge(qb)
			var r: float = bb.size.length() * 0.5
			dv = minf(dv, 1.5 * ((b.linear_velocity - b.prev_v).length() + absf(b.angular_velocity - b.prev_w) * r))
		if dv > 55.0 and b.age > 0.4:
			_impact(b, dv)
		b.hit_imp = 0.0
		b.prev_v = b.linear_velocity
		b.prev_w = b.angular_velocity


func _impact(b, dv: float) -> void:
	var at: Vector2 = b.hit_pos
	var k := clampf((dv - 55.0) / 260.0, 0.0, 1.0)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 3 + int(k * 10), Pal.ink(0.8, 1.4), 200.0 + 200.0 * k, 0.3, 1.4)
	sfx.play("clank", at, 0.3 + 0.7 * k)
	var lost := 0.0
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			var before: float = p.cond
			_dent(p, maxf(0.0, p.cond - p.fragile * k * 0.5), "dv_impact")
			lost += (before - p.cond) * p.value
	if lost > 150.0:
		incident("impact", "%d" % int(lost))
		fx.number(at + Vector2(0, -20), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("impact_damage", at)
		hint("impact")
	if k > 0.3:
		shake(k * 0.2)


# ---------------------------------------------------------------- drone

func _drone_upkeep(dt: float) -> void:
	if not drone.alive:
		if drone_respawn > 0.0:
			drone_respawn -= dt
			if drone_respawn <= 0.0:
				_launch_drone()
		return
	var pull: Vector2 = port_access.boundary_pull(drone.global_position) if port_access != null and port_access.active() else dock.field_pull(drone.global_position)
	# out in the belt there is no berth field (32 号)
	if belt:
		pull = Vector2.ZERO
	if pull != Vector2.ZERO:
		drone.external += pull * drone.mass * 3.0
		hint("field")
	var bay := Dock.BAY * Geom.M
	if drone.global_position.distance_to(bay) < 2.6 * Geom.M and job.has("fit_pending") and not (job.fit_pending as Dictionary).is_empty():
		Consum.apply_pending(self)
	if drone.global_position.distance_to(bay) < 2.6 * Geom.M and drone.integrity < 100.0:
		drone.integrity = minf(100.0, drone.integrity + dt * 55.0)
		if randf() < 0.3:
			fx.sparks(drone.global_position, Vector2.UP, 1, Pal.ink(0.6, 1.2), 60.0, 0.3)


func hurt_drone(amount: float, from: Vector2, key: String, cd_key: String = "", cd: float = 1.0) -> void:
	if not drone.alive or drone.spawn_t < 1.0 or (Txt.dev and DevPanel.god and bot == null):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if cd_key != "" and now - hurt_cd.get(cd_key, -99.0) < cd:
		return
	if cd_key != "":
		hurt_cd[cd_key] = now
	incident("drone_hit", key)
	amount *= skill_value("armor") / 100.0
	if key in ["arc_hit", "live_unplug"]:
		amount *= skill_value("shield") / 100.0
	if key in ["scald", "fire_hit", "heat_hit"]:
		amount *= skill_value("thermal") / 100.0
	drone.hurt(amount, from)
	shake(0.25 + amount / 100.0, (drone.global_position - from).normalized())
	sfx.play("hurt")
	say(key, drone.global_position + Vector2(0, -40))
	hud.hurt_flash(amount)


func on_drone_impact(pos: Vector2, dv: float) -> void:
	# the bumper module: light knocks are nothing, hard ones half as bad
	var th := 300.0 if has_mod("mod_bumper") else 175.0
	if dv > th:
		var dmg := clampf((dv - th) / 18.0, 1.0, 14.0) * (0.5 if has_mod("mod_bumper") else 1.0)
		if dmg >= 8.0:
			hurt_drone(dmg, pos, "hit_hard", "impact", 0.7)
		elif drone.alive and not DevPanel.god:
			drone.integrity = maxf(1.0, drone.integrity - dmg * skill_value("armor") / 100.0)
			hud.hurt_flash(dmg)
	fx.sparks(pos, (drone.global_position - pos).normalized(), 6, Pal.ink(0.8, 1.3), 220.0, 0.3, 1.0)


func on_drone_destroyed() -> void:
	incident("drone_lost")
	var p := drone.global_position
	fx.flash(p, 200.0, 0.6, Pal.heat(1.0, 2.6))
	fx.ring(p, 10.0, 180.0, 0.6, Pal.heat(0.9, 1.8), 2.4)
	fx.burst_shards(p, 18, 380.0, Pal.ink(0.9), 9.0)
	fx.sparks(p, Vector2.UP, 30, Pal.heat(1.0, 2.2), 420.0, 0.6, PI)
	shake(0.8)
	sfx.play("boom")
	tools.release_grab(false)
	if tools.cutting:
		tools._finish_cut()
	# a spare drone in stock replaces it at no charge
	if use_item("spare"):
		say("item_spare", p + Vector2(0, -50))
	else:
		lose("loss_drone", DRONE_FEE, p + Vector2(0, -50))
	drone_respawn = 1.4 if training else 2.0
	drone.linear_velocity = Vector2.ZERO
	hint("drone_lost")
	if gear != null:
		gear.on_drone_destroyed(p)


# ---------------------------------------------------------------- tool events

# a cheap lens burst under the beam (scripts/consum.gd): the lens is gone, the drone is
# scalded, whatever was under the beam is spoilt
func lens_burst(at: Vector2, under: Array) -> void:
	Consum.wear_out(self, "lens")
	incident("lens_burst")
	fx.flash(at, 120.0, 0.4, Pal.heat(1.0, 2.4))
	fx.ring(at, 8.0, 90.0, 0.4, Pal.heat(0.9, 1.6), 2.0)
	fx.sparks(at, Vector2.UP, 24, Pal.heat(1.0, 2.2), 320.0, 0.5, PI)
	shake(0.5)
	sfx.play("boom")
	hurt_drone(Consum.BURST_HURT, at, "lens_burst")
	for q in under:
		if q.cls == "equip" and q.intact:
			_dent(q, maxf(0.0, q.cond - Consum.BURST_DENT), "dv_lens")
	say("cs_lens_burst", at + Vector2(0, -40))
	hud.show_hint(txt("hint_cs_cheap"))


func on_laser_near_equipment(p, pos: Vector2) -> void:
	say("laser_near", pos, p.tag if p.tag != "" else Txt.piece_name(p))
	sfx.play("warn")
	hint("equip_cut")


func on_cut_into(p, pos: Vector2) -> void:
	# 87-1: the first time the beam meets a material that is not plain steel, a line on what it is
	if p.mat != "" and p.mat != Mat.STEEL:
		hint("mat_" + str(p.mat))
	if bio != null:
		bio.on_cut(p)
	breach(p, true, pos)
	if rails != null:
		rails.on_cut(p)
	if boxbeam != null:
		boxbeam.on_cut(p)
	if sail != null:
		sail.on_cut(p)
	if reactor != null:
		reactor.on_cut(p)
	if softshell != null:
		softshell.on_cut(p)
	if train != null:
		train.on_cut(p)
	if flywheel != null:
		flywheel.on_cut(p)
	if spine != null:
		spine.on_cut(p)
	if boiloff != null:
		boiloff.on_cut(p)
	if drillstring != null:
		drillstring.on_cut(p)
	if nested != null:
		nested.on_cut(p)
	if waterball != null:
		waterball.on_cut(p)
	if magnets != null:
		magnets.on_cut(p)
	if optics != null:
		optics.on_cut(p)
	if immersion != null:
		immersion.on_cut(p)
	if thermal != null:
		thermal.on_cut(p)
	if composite != null:
		composite.on_cut(p)
	if dilution != null:
		dilution.on_cut(p)
	if tether != null:
		tether.on_cut(p)
	if sandwich != null:
		sandwich.on_cut(p)
	if ice != null:
		ice.on_cut(p)
	if atmos != null:
		atmos.on_cut(p, pos)
	if media != null:
		media.on_manifold(p)
	if p.cls != "equip":
		return
	var was_value: float = p.value * p.cond
	var volts: float = sys.piece_volts(p)
	var fv: String = sys.fluid_in_piece(p)
	if p.hazard == "explosive" and p.intact and (munitions == null or munitions.live(p)):
		_blast(p, pos)
	elif sys.bursts(p):
		# the gas over the liquid is what pushes it out: a tank that bursts throws its
		# contents out with it
		var burst_kpa: float = sys.P(sys.tank_vol(p))
		_burst(p, pos)
		if fv != "" and sys.fluid(fv) > 0.02:
			_breach(p, fv, pos, burst_kpa)
	elif fv != "" and sys.fluid(fv) > 0.02:
		_breach(p, fv, pos, 0.0)
	if volts > 30.0:
		_arc(pos, volts, p)
		# the arc empties whatever stored it
		sys.drain_source(p.tag)
	elif volts > 0.0:
		fx.sparks(pos, Vector2.UP, 8, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
		sfx.play("zap_small")
	if p.intact:
		note_loss("dv_cut", p.tag, was_value - world.scrap_value(p))
		mandatory_gone(p, "mg_cut")
	if was_value > 200.0:
		incident("equip_cut", p.tag)
		fx.number(pos + Vector2(0, -30), "−" + Pal.money(was_value).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("equip_ruined", pos, Txt.piece_name(p))
	# one touch of the beam and it is scrap
	if p.intact:
		p.intact = false
		world.redraw_all()


func _arc(pos: Vector2, volts: float, p = null) -> void:
	incident("arc", "%d V%s" % [int(volts), (" " + p.tag) if p != null and p.tag != "" else ""])
	combustion.spark(pos, 1.2 + clampf(volts / 400.0, 0.0, 1.5))
	var k := clampf(volts / 400.0, 0.3, 1.0)
	for i in 3 + int(k * 3):
		fx.arc(pos, pos + Vector2.from_angle(randf() * TAU) * randf_range(40, 120) * k, randf_range(0.18, 0.35), k)
	if drone.alive and drone.global_position.distance_to(pos) < 3.0 * 48.0:
		fx.arc(pos, drone.global_position, 0.3, 1.0)
		hurt_drone(40.0 * k, pos, "arc_hit", "arc", 0.6)
	fx.flash(pos, 220.0 * k, 0.4, Pal.tint(Pal.VOLT, 1.0, 2.4))
	fx.sparks(pos, Vector2.from_angle(randf() * TAU), 24, Pal.tint(Pal.VOLT, 1.0, 2.2), 420.0, 0.4, PI)
	hud.white_flash(0.35 * k)
	shake(0.35 * k)
	hitstop(0.06 * k)
	sfx.play("arc")
	hint("arc")


func _burst(p, pos: Vector2) -> void:
	incident("burst", p.tag)
	var v: String = sys.tank_vol(p)
	var n_out: float = sys.vols[v].n
	sys.gas_lost += n_out
	sys.vols[v].n = 0.0
	var c := world.frame(p) * Geom.centroid(p.poly)
	# the gas goes where the bottle was: into the room's air, or adrift (oxygen feeds a
	# fire, hydrogen is one)
	combustion.gas_released(str(sys.vessel_cfg[v].get("gas", "")), n_out, c)
	combustion.spark(c, 2.0)
	fx.flash(c, 240.0, 0.5, Pal.ink(1.0, 2.0))
	fx.ring(c, 10.0, 220.0, 0.5, Pal.ink(0.9), 3.0)
	for i in 40:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c, d * randf_range(200, 600), randf_range(0.5, 1.1), 6.0, 40.0, Pal.tint(Pal.AIR, 0.12))
	fx.burst_shards(c, 14, 420.0, Pal.ink(0.8), 8.0)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < 4.0 * 48.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 260.0 * (1.0 - d2.length() / 192.0))
	if drone.alive and drone.global_position.distance_to(c) < 3.0 * 48.0:
		hurt_drone(25.0, c, "burst_hit", "burst", 0.5)
	for q in _equip_near(c, 1.6 * 48.0):
		if q != p:
			_dent(q, maxf(0.0, q.cond - 0.2 * q.fragile), "dv_burst")
	shake(0.6)
	hud.white_flash(0.25)
	hitstop(0.07)
	sfx.play("burst")
	hint("burst")


# dangerous goods under the beam
func _blast(p, pos: Vector2) -> void:
	incident("blast", p.tag)
	var c := world.frame(p) * Geom.centroid(p.poly)
	combustion.spark(c, 4.0)
	fx.flash(c, 360.0, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(c, 20.0, 340.0, 0.6, Pal.heat(0.9, 2.2), 3.0)
	fx.burst_shards(c, 26, 620.0, Pal.heat(0.9, 1.6), 12.0)
	fx.sparks(c, Vector2.UP, 50, Pal.heat(1.0, 2.4), 560.0, 0.6, PI)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < 5.0 * 48.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 320.0)
	if drone.alive and drone.global_position.distance_to(c) < 3.5 * 48.0:
		hurt_drone(40.0, c, "fire_hit", "blast", 1.0)
	for q in _equip_near(c, 3.0 * 48.0):
		if q != p:
			_dent(q, maxf(0.0, q.cond - 0.4 * q.fragile), "dv_blast")
	shake(0.8)
	hud.white_flash(0.35)
	hitstop(0.08)
	sfx.play("boom")
	lose("loss_blast", 2500.0, c + Vector2(0, -60))
	p.intact = false
	if munitions != null:
		munitions.on_blast(p, c)


# a cracked piece of structure gives way under the grapple
func on_snap(j) -> void:
	var at: Vector2 = world.joint_world(j)
	var pa = world.pieces.get(j.a)
	incident("snap", pa.get_meta("origin", pa.tag) if pa != null else "")
	world.kill_joint(j)
	# the part that let go drops away from the pull: a roof plate's half falls into the room below
	# the half the grapple is not holding is the one that drops
	var held = tools.held_piece
	var pb = world.pieces.get(j.a if held != null and held.id == j.b else j.b) if held != null else world.pieces.get(j.a)
	if pb != null:
		pb.set_meta("snap_kick", Vector2(0, 1) if pb.kind == "hull" else Vector2.from_angle(randf() * TAU))
		if pb.kind == "hull":
			_falls_in(pb)
	fx.flash(at, 120.0, 0.35, Pal.ink(0.9, 1.8))
	fx.burst_shards(at, 12, 360.0, Pal.ink(0.8), 7.0)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 18, Pal.ink(0.9, 1.4), 320.0, 0.35, PI)
	var lost := 0.0
	for q in _equip_near(at, 3.0 * 48.0):
		var before: float = q.cond
		_dent(q, maxf(0.0, q.cond - 0.25 * q.fragile), "dv_snap")
		lost += (before - q.cond) * q.value
	if lost > 50.0:
		fx.number(at + Vector2(0, -30), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
	if drone.alive and drone.global_position.distance_to(at) < 2.0 * 48.0:
		hurt_drone(10.0, at, "hit_hard", "snap", 1.0)
	shake(0.4)
	hitstop(0.05)
	sfx.play("snap")
	say("snapped", at)


# half a roof plate drops into the room below: whatever stands under it takes the blow
func _falls_in(p) -> void:
	var bb := Geom.bbox(world.world_poly(p))
	var room := world.room_at(bb.get_center() + Vector2(0, 1.5 * Geom.M))
	if room == "":
		return
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.body != null or q.cls != "equip" or not q.intact or q.room != room:
			continue
		var qb := Geom.bbox(q.poly)
		if qb.end.x < bb.position.x or qb.position.x > bb.end.x:
			continue
		var before: float = q.cond
		# a tonne of plate dropping the height of the hold: what is fragile is finished
		_dent(q, maxf(0.0, q.cond - q.fragile), "dv_fall")
		lost += (before - q.cond) * q.value
		fx.sparks(Vector2(qb.get_center().x, qb.position.y), Vector2.UP, 16, Pal.ink(0.9, 1.4), 280.0, 0.35, PI)
	if lost > 50.0:
		incident("impact", "%d" % int(lost))
		fx.number(bb.get_center() + Vector2(0, 2.0 * Geom.M), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
		shake(0.3)


func _equip_near(c: Vector2, r: float) -> Array:
	var out: Array = []
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact:
			continue
		if (world.frame(q) * Geom.centroid(q.poly)).distance_to(c) < r:
			out.append(q)
	return out


func _leak(fluid: String, src: String, at: Vector2, piece = null) -> void:
	incident("leak", src)
	var lk := {"pos": at, "dir": Vector2.from_angle(randf() * TAU), "fluid": fluid, "rate": 1.0, "src": src, "t": 0.0, "piece": piece, "local": Vector2.ZERO}
	if piece != null:
		lk.local = world.frame(piece).affine_inverse() * at
		lk.dir = (at - world.frame(piece) * Geom.centroid(piece.poly)).normalized()
	sys.leaks.append(lk)
	sfx.play("leak")
	say("leak_" + fluid, at)
	hint("leak_" + fluid)
	if fluid == "lng":
		# a cryogenic spray: whatever equipment stands close freezes and cracks
		for id in world.order:
			var q = world.pieces[id]
			if q.gone or q.cls != "equip" or not q.intact or q == piece:
				continue
			if (world.frame(q) * Geom.centroid(q.poly)).distance_to(at) < 3.0 * Geom.M:
				_dent(q, q.cond * 0.7, "dv_frost")


# A cut into a tank still holding liquid: a hole the size of the kerf so far, the liquid
# pushed out of it by the gas over it (systems.gd works the flow out of the hole's area
# and the pressure behind it). burst_kpa: the tank burst at that pressure, and most of
# what it held is thrown out with its shell at once.
const LIQ = preload("res://scripts/liquids.gd")
const KERF_W := 0.004           # m: the width of a laser kerf through a tank wall


func _breach(p, fv: String, pos: Vector2, burst_kpa: float) -> void:
	var v: Dictionary = sys.fvol[fv]
	_leak(v.fluid, fv, pos, p)
	var lk: Dictionary = sys.leaks.back()
	lk.area = KERF_W * 0.25
	lk.ullage = sys.tank_vol(p)
	if burst_kpa <= 0.0:
		return
	lk.area = 0.5
	lk.severed = true
	var look: String = LIQ.look_of(v)
	var rho: float = float(LIQ.LOOKS.get(look, LIQ.LOOKS.water).get("rho", 1000.0))
	var out: float = float(v.amount) * 0.7
	v.amount = float(v.amount) - out
	sys.fluid_lost += out
	var speed: float = clampf(sqrt(2.0 * burst_kpa * 1000.0 / rho), 2.0, 16.0)
	var c := world.frame(p) * Geom.centroid(p.poly)
	liquids.spill(c, Vector2.ZERO, out, look, clampi(int(out * 25.0) + 10, 10, 70), TAU, speed, false)


# the kerf grows across a tank holding liquid: so does the hole; cut through, it is open
func _kerf_breach(p, pl: PackedVector2Array, res: Dictionary) -> void:
	for lk in sys.leaks:
		if lk.piece != p or not lk.has("area"):
			continue
		var ln := 0.0
		for i in pl.size() - 1:
			ln += pl[i].distance_to(pl[i + 1])
		lk.area = float(lk.area) + ln / Geom.M * KERF_W
		# the opening is the whole kerf, not the point it began at: the liquid comes out all
		# along it (liquids.gd; user 2026-10-27, "只是在某些角落喷出来一点")
		var slit: Array = lk.get("slit", [])
		for q in pl:
			if slit.size() < 64:
				slit.append(world.frame(p).affine_inverse() * q)
		lk.slit = slit
		if int(res.get("split", 1)) > 1:
			# cut in two: the tank's whole section is open to space
			var bb := Geom.bbox(p.poly)
			lk.area = maxf(float(lk.area), minf(bb.size.x, bb.size.y) / Geom.M * 0.8)
			lk.severed = true
		return


func leak_pos(lk: Dictionary) -> Vector2:
	if lk.piece != null and not lk.piece.gone:
		return world.frame(lk.piece) * lk.local
	return lk.pos


func on_line_cut(l, at: Vector2) -> void:
	changed["l:" + l.id] = true
	if l.kind == "cable":
		var volts: float = sys.line_volts(l) if l.id != "" else 0.0
		# line_volts reads alive lines; it has just been cut, so ask about the source side
		volts = _cut_cable_volts(l)
		if volts > 30.0:
			_arc(at, volts)
		elif volts > 0.0:
			fx.sparks(at, Vector2.UP, 10, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
			sfx.play("zap_small")
			combustion.spark(at, 0.6)
		else:
			fx.sparks(at, Vector2.UP, 4, Pal.ink(0.8, 1.3), 120.0, 0.2, PI)
		say("cable_cut", at, l.id.to_upper())
		return
	var vk: String = sys.fluid_of_net(l.net)
	if vk != "":
		var v: Dictionary = sys.fvol[vk]
		if sys.fluid_behind(vk) > float(v.get("leak_min", 0.02)):
			_leak(v.fluid, vk, at)
			if v.fluid != "fuel":
				# hot coolant scalds and fouls what it lands on
				if sys.line_temp(l) > 60.0 and drone.alive and drone.global_position.distance_to(at) < 2.5 * 48.0:
					hurt_drone(25.0, at, "scald", "scald", 1.0)
				var fouled := 0.0
				var names: Array = []
				for q in _equip_near(at, 2.0 * 48.0):
					if not q.contam and q.intact:
						fouled += q.value * clampf(q.cond, 0.0, 1.0) * 0.25
						note_loss("dv_contam", q.tag, q.value * clampf(q.cond, 0.0, 1.0) * 0.25)
						names.append(q.tag)
					q.contam = true
				if fouled > 50.0:
					fx.number(at + Vector2(0, -40), "−" + Pal.money(fouled).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
					say("contaminated", at + Vector2(0, -60), ", ".join(names))
				world.redraw_all()
	elif l.net == "gas":
		for i in 10:
			fx.puff(at, Vector2.from_angle(randf() * TAU) * 120.0, 0.6, 4.0, 22.0, Pal.tint(Pal.AIR, 0.1))
		sfx.play("hiss")
	fx.sparks(at, Vector2.UP, 3, Pal.ink(0.7, 1.2), 100.0, 0.2, PI)


func _cut_cable_volts(l) -> float:
	var was: bool = l.alive
	l.alive = true
	var v: float = sys.line_volts(l)
	l.alive = was
	return v


func on_ignite(cl: Dictionary, pos: Vector2) -> void:
	# it burns only with something to burn with (scripts/combustion.gd)
	if combustion != null:
		combustion.ignite_cloud(cl, pos)
		return
	incident("fire")
	sys.clouds.erase(cl)
	var c: Vector2 = cl.pos
	fx.flash(c, cl.r * 2.2, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(c, 10.0, cl.r * 1.6, 0.6, Pal.heat(0.9, 2.2), 3.0)
	for i in 50:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c + d * randf() * cl.r * 0.5, d * randf_range(80, 320), randf_range(0.4, 0.9), 8.0, 50.0, Pal.heat(0.25, 1.8))
	fx.sparks(c, Vector2.UP, 40, Pal.heat(1.0, 2.4), 500.0, 0.6, PI)
	if drone.alive and drone.global_position.distance_to(c) < cl.r + 1.5 * 48.0:
		hurt_drone(25.0, c, "fire_hit", "fire", 1.0)
	for q in _equip_near(c, cl.r + 48.0):
		_dent(q, maxf(0.0, q.cond - 0.3), "dv_fire")
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < cl.r * 2.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 200.0)
	shake(0.7)
	hud.white_flash(0.3)
	sfx.play("ignite")
	lose("loss_fire", 1500.0, c + Vector2(0, -60))
	hint("fire")


# a finished laser stroke through one attached piece (pl in world space), as
# the laser would make it: equipment it touches, lines it crosses, the kerf
func cut_kerf(p, pl: PackedVector2Array, kerf: float = World.KERF, by_plan: bool = false, source: Dictionary = {}) -> void:
	if pl.is_empty():
		return
	if not by_plan:
		log_op("cut")
	var inc0 := incidents.size()
	var plan_context: Dictionary = plan.cut_context(p) if plan != null else {}
	if not plan_context.is_empty(): plan_context.kerf = kerf
	if world.segment_cut(p, pl) and not _holds(p):
		# along its marked line: it comes apart as planned, nothing ruined
		fx.sparks(pl[0], Vector2.UP, 10, Pal.heat(1.0, 2.0), 160.0, 0.3, PI)
		say("seg_cut", pl[0], p.tag)
	else:
		on_cut_into(p, pl[0])
	if pl.size() >= 2:
		for hit in world.cut_lines(pl):
			on_line_cut(hit[0], hit[1])
	var attached: bool = p.body == null
	var local_pl: PackedVector2Array = world.frame(p).affine_inverse() * pl
	var material_pl: PackedVector2Array = local_pl
	if source.has("prefix"):
		material_pl = PackedVector2Array()
		for point in source.prefix: material_pl.append(Vector2(float(point[0]),float(point[1])))
	var res: Dictionary = world.commit_cut(p, material_pl, kerf, source)
	if not source.is_empty(): source.split = int(res.split)
	_kerf_breach(p, pl, res)
	on_kerf(p, res)
	if plan != null:
		plan.on_cut(p, local_pl, incidents.size() > inc0, attached, plan_context, by_plan)


# a marked line only takes an empty vessel apart cleanly: one still under
# pressure or holding liquid is ruined like any other cut
func _holds(p) -> bool:
	var fv: String = sys.fluid_in_piece(p)
	return sys.bursts(p) or (fv != "" and sys.fluid(fv) > 0.02)


func on_kerf(p, res: Dictionary) -> void:
	for j in res.killed:
		var jp: Vector2 = world.joint_world(j)
		fx.sparks(jp, Vector2.from_angle(randf() * TAU), 4, Pal.heat(1.0, 2.0), 160.0, 0.25, PI)
		combustion.spark(jp, 0.3)
	for l in res.lines:
		on_line_cut(l, world.frame(p) * Geom.centroid(p.poly))
	if res.split > 1:
		sfx.play("crack", world.frame(p) * Geom.centroid(p.poly), 0.8)
	# 87-1: a ceramic plate the beam heated too fast cracks: a snap, chips, its value spalls off
	if int(res.get("cracked", 0)) > 0 and not p.gone:
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
		sfx.play("crack", at, 1.0, 0.8)
		fx.burst_shards(at, 6 * int(res.cracked), 220.0, Pal.ink(0.75), 5.0)
		fx.puff(at, Vector2.ZERO, 1.2, 8.0, 40.0, Pal.ink(0.08))
		say("mat_crack", at, Mat.name_of(Mat.id_of(p)))


func on_grab(p) -> void:
	if p.body == null:
		var fixed := 0
		for j in world.joints_of(p):
			if j.type in ["bolt", "weld", "clamp", "seam", "crack"]:
				fixed += 1
		var locks := 0
		for j in world.joints_of(p):
			if j.type == "lock":
				locks += 1
		var lines_n: int = world.lines_of(p).size()
		var live := 0.0
		for l in world.lines_of(p):
			if l.kind == "cable":
				live = maxf(live, _cut_cable_volts(l))
		if fixed > 0:
			say("still_fixed", aim, str(fixed))
			hint("fixings")
		elif locks > 0 or lines_n > 0:
			# these give way if you pull: say it before they do
			say("tear_warn_live" if live > 30.0 else "tear_warn", aim, "%d" % (locks + lines_n) if live <= 30.0 else "%d · %d V" % [locks + lines_n, int(live)])
		elif world.group_mass(p) > grab_max():
			say("too_heavy", aim, "%.1f" % world.group_mass(p))
	elif p.body.total_mass() > grab_max():
		say("too_heavy", aim, "%.1f" % p.body.total_mass())
		hint("heavy")
	elif p.cls == "equip" and p.intact:
		# whole equipment far from its bay: the bay comes to you
		var destination := Dock.for_load("equip",p.body,false)
		if destination == "":
			# 78 号 P0-1: no equipment mouth takes it whole as it lies in the grapple
			say("no_mouth", aim, Dock.no_mouth_text(p.body,false))
		elif destination != "equip_bulk" and absf(Dock.zpos(destination).x - aim.x) > 10.0 * Geom.M:
			hint("equip_rail")


func on_tear(p, weak: Array, lines_held: Array, at: Vector2) -> void:
	# what held it: a fixing behind a cover, or lines (the accident review reads this)
	var held := ""
	if weak.any(func(j): return world.joint_covered(j)):
		held = " hidden"
	elif not lines_held.is_empty():
		held = " lines"
	incident("torn", p.tag + held)
	var dmg := 0.0
	for j in weak:
		world.kill_joint(j)
		dmg += 0.12
	if p.cls == "equip" and p.intact and p.mandatory and dmg >= 0.5:
		mandatory_gone(p, "mg_torn")
	for l in lines_held:
		var volts := _cut_cable_volts(l) if l.kind == "cable" else 0.0
		world.kill_line(l, world.line_end_world(l, 0 if l.a == p.id else 1))
		dmg += 0.15
		if volts > 30.0:
			_arc(at, volts * 0.5)
		elif l.kind == "pipe":
			on_line_cut(l, at)
	if p.cls == "equip" and p.intact:
		var before: float = p.cond
		_dent(p, maxf(0.0, p.cond - dmg * (0.5 + p.fragile)), "dv_tear")
		var lost: float = (before - p.cond) * p.value
		if lost > 50.0:
			fx.number(at + Vector2(0, -24), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 14, Pal.ink(0.9, 1.4), 300.0, 0.35, PI)
	shake(0.25)
	sfx.play("snap")
	say("torn_free", at)
	hint("torn")


# ---------------------------------------------------------------- measure / wrench / hose

func do_measure(tg: Dictionary) -> void:
	# the meter's probe tip wears with every reading (scripts/consum.gd)
	if not Consum.ready(self, "probe"):
		say("cs_out_probe", tg.pos)
		sfx.play("deny")
		return
	Consum.use(self, "probe", 1.0)
	var mkey: String = str(tg.ctrl.id) if tg.kind == "ctrl" else (str(tg.line.id) if tg.kind == "line" else ("P:%d" % tg.piece.id if tg.has("piece") else ""))
	log_op("remeasure" if _measured.has(mkey) else "measure")
	_measured[mkey] = true
	match tg.kind:
		"ctrl":
			var c = tg.ctrl
			verify("ports", c.id, c.target)
			if c.kind == "discharge":
				sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
			else:
				match c.medium:
					"bio":
						sys.measure(c.id, "bio", c.id, "inst_bio", {"ctrl": c, "room": c.target})
					"o2":
						sys.measure(c.id, "o2", c.id, "inst_o2", {"ctrl": c, "room": c.target})
					"cold":
						sys.measure(c.id, "temp", c.id, "inst_hold_temp", {"ctrl": c, "temp_fn": func(): return coldchain.room_temp(c.target)})
					"sample":
						sys.measure(c.id, "sample", c.id, "inst_sample", {"ctrl": c, "sample_fn": func(): return media.sample(c.id)})
					"core":
						sys.measure(c.id, "temp", c.id, "inst_core", {"ctrl": c, "temp_fn": func(): return furnace.core_temp()})
					"mag":
						sys.measure(c.id, "field", c.id, "inst_field", {"ctrl": c, "field_fn": func(): return mech.field(c.target)})
					"heat":
						sys.measure(c.id, "temp", c.id, "inst_temp", {"ctrl": c, "temp_fn": func(): return munitions.room_temp(c.target)})
					"cryo":
						sys.measure(c.id, "temp", c.id, "inst_cryo", {"ctrl": c, "temp_fn": func(): return cryo.temp(c.target)})
					"tension":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return mech.tension(c.target), "unit": "kN"})
					"strain":
						sys.measure(c.id, "field", c.id, "inst_strain", {"ctrl": c, "field_fn": func(): return boxbeam.strain(c.id), "unit": "%"})
					"rod":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return boxbeam.rod_pull(c.target), "unit": "kN"})
					"stay":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return sail.pull(c.target), "unit": "kN"})
					"dose":
						sys.measure(c.id, "field", c.id, "inst_dose", {"ctrl": c, "field_fn": func(): return reactor.probe(c), "unit": "mSv/h"})
					"bend":
						sys.measure(c.id, "field", c.id, "inst_bend", {"ctrl": c, "field_fn": func(): return train.aft_mass(), "unit": "t"})
					"rpm":
						sys.measure(c.id, "field", c.id, "inst_rpm", {"ctrl": c, "field_fn": func(): return float(flywheel.rpm.get(c.target, 0.0)), "unit": "rpm"})
					"ring":
						sys.measure(c.id, "field", c.id, "inst_rpm", {"ctrl": c, "field_fn": func(): return float(rings.rpm.get(c.target, 0.0)), "unit": "rpm"})
					"bheat":
						sys.measure(c.id, "field", c.id, "inst_temp", {"ctrl": c, "field_fn": func(): return rings.temp(c.target), "unit": "°C"})
					"spine":
						sys.measure(c.id, "field", c.id, "inst_load", {"ctrl": c, "field_fn": func(): return spine.gauge(c.id), "unit": "%"})
					"valve_temp":
						sys.measure(c.id, "field", c.id, "inst_valve_temp", {"ctrl": c, "field_fn": func(): return boiloff.valve_temp(str(c.target)), "unit": "°C"})
					"tank_kpa":
						sys.measure(c.id, "field", c.id, "inst_tank_kpa", {"ctrl": c, "field_fn": func(): return boiloff.tank_kpa(str(c.target)), "unit": "kPa"})
					"mudp":
						sys.measure(c.id, "field", c.id, "inst_mudp", {"ctrl": c, "field_fn": func(): return drillstring.mud_kpa(), "unit": "kPa"})
					"torque":
						sys.measure(c.id, "field", c.id, "inst_torque", {"ctrl": c, "field_fn": func(): return drillstring.torque_pct(), "unit": "%"})
					"ball":
						sys.measure(c.id, "field", c.id, "inst_ball", {"ctrl": c, "field_fn": func(): return waterball.level() * 100.0, "unit": "%"})
					"coil_temp":
						sys.measure(c.id, "field", c.id, "inst_coil_temp", {"ctrl": c, "field_fn": func(): return magnets.max_temp(), "unit": "K"})
					"field_pct":
						sys.measure(c.id, "field", c.id, "inst_coil_energy", {"ctrl": c, "field_fn": func(): return magnets.field(), "unit": "%"})
					"optics":
						sys.measure(c.id, "field", c.id, "inst_reflect", {"ctrl": c, "field_fn": func(): return optics.reflect(), "unit": "%"})
					"zone":
						sys.measure(c.id, "field", c.id, "inst_temp", {"ctrl": c, "field_fn": func(): return thermal.zone_temp(c.target), "unit": "°C"})
					"fume":
						sys.measure(c.id, "field", c.id, "inst_fume", {"ctrl": c, "field_fn": func(): return composite.level(c.target) * 1000.0, "unit": "ppm"})
					"stage":
						sys.measure(c.id, "field", c.id, "inst_cryo_t", {"ctrl": c, "field_fn": func(): return dilution.stage_temp(c.target), "unit": "K"})
					"rail":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return flywheel.rail_pull(c.target), "unit": "kN"})
					"spin":
						sys.measure(c.id, "field", c.id, "inst_rpm", {"ctrl": c, "field_fn": func(): return tether.rpm, "unit": "rpm"})
					"tether":
						sys.measure(c.id, "field", c.id, "inst_tension", {"ctrl": c, "field_fn": func(): return tether.pull(), "unit": "kN"})
					"heat":
						sys.measure(c.id, "field", c.id, "inst_temp", {"ctrl": c, "field_fn": func(): return tether.temp(), "unit": "°C"})
					"strand":
						sys.measure(c.id, "field", c.id, "inst_strands", {"ctrl": c, "field_fn": func(): return tether.strands(), "unit": "/7"})
					"load":
						sys.measure(c.id, "field", c.id, "inst_load", {"ctrl": c, "field_fn": func(): return sandwich.load(c.id), "unit": "kN"})
					"crack":
						sys.measure(c.id, "field", c.id, "inst_strain", {"ctrl": c, "field_fn": func(): return ice.strain(), "unit": "%"})
					"gas":
						sys.measure(c.id, "pressure", c.id, "inst_pressure", {"ctrl": c, "vol": c.target})
						if sys.dead_leg_closed(c):
							hint("dead_leg")
					"volt":
						sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
						if sys.remote_sent and sys.bus_live:
							hint("not_off")
							if story != null:
								story.event("fake_off")
					_:
						if sys.fluid_at_port(c.id) != "":
							sys.measure(c.id, "fluid", c.id, "inst_fluid", {"ctrl": c, "fluid_fn": func(): return sys.port_level(c.id)})
						if sys.is_heat_port(c.id):
							sys.measure(c.id + "/T", "temp", c.id, "inst_temp", {"ctrl": c, "temp_fn": func(): return sys.loop_T})
		"line":
			var l = tg.line
			verify("lines", l.id, [tag_of(l.a), tag_of(l.b)])
			if l.kind == "cable":
				sys.measure("L:" + l.id, "volts", l.id.to_upper(), "inst_volts", {"anchor_pos": tg.pos, "volts_fn": func(): return sys.line_volts(l)})
			else:
				sys.measure("L:" + l.id, "temp", l.id.to_upper(), "inst_temp", {"anchor_pos": tg.pos, "temp_fn": func(): return sys.line_temp(l)})
		"inspect", "piece":
			var p = tg.piece
			verify("pieces", p.tag, {"fix": _inspect_text(p)})
			var key := "P:%d" % p.id
			var local: Vector2 = world.frame(p).affine_inverse() * tg.pos
			var label: String = p.tag if p.tag != "" else Txt.piece_name(p)
			sys.measure(key, "temp", label, "inst_inspect", {"piece": p, "local": local, "inspect": _inspect_text(p), "temp_fn": func(): return Mat.temp(p)})
			if story != null:
				story.on_inspect(p)
			if sys.electric_piece(p):
				sys.measure(key + "/V", "volts", label, "inst_volts", {"piece": p, "local": local + Vector2(0, 16), "volts_fn": func(): return sys.piece_volts(p)})
			# a container: what is in it, how much, at what pressure
			if sys.contents_of(p) != "":
				sys.measure(key + "/C", "sample", label, "inst_contents", {"piece": p, "local": local + Vector2(0, 32), "sample_fn": func(): return sys.contents_reading(p)})
	sfx.play("measure")
	fx.ring(tg.pos, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3), 1.4)
	hint("measured")


func restore_reading(rd: Dictionary) -> void:
	var key: String = rd.key
	var extra := {}
	if key.begins_with("L:"):
		var l = world.lines.get(key.substr(2))
		if l == null:
			return
		extra = {"anchor_pos": world.line_path_world(l)[0]}
		if rd.kind == "volts":
			extra.volts_fn = func(): return sys.line_volts(l)
		else:
			extra.temp_fn = func(): return sys.line_temp(l)
	elif key.begins_with("P:"):
		var pid := int(key.substr(2).split("/")[0])
		var p = world.pieces.get(pid)
		if p == null or p.gone:
			return
		extra = {"piece": p, "local": Geom.centroid(p.poly)}
		if rd.kind == "volts":
			extra.local += Vector2(0, 16)
			extra.volts_fn = func(): return sys.piece_volts(p)
		elif rd.kind == "sample":
			extra.local += Vector2(0, 32)
			extra.sample_fn = func(): return sys.contents_reading(p)
		else:
			extra.inspect = _inspect_text(p)
			extra.temp_fn = func(): return Mat.temp(p)
	else:
		var cid: String = key.split("/")[0]
		var c = world.ctrls.get(cid)
		if c == null:
			return
		extra = {"ctrl": c, "vol": rd.vol}
		match rd.kind:
			"volts":
				extra.volts_fn = _ctrl_volts_fn(c)
			"fluid":
				extra.fluid_fn = func(): return sys.port_level(c.id)
			"temp":
				if c.medium == "cryo":
					extra.temp_fn = func(): return cryo.temp(c.target)
				elif c.medium == "heat":
					extra.temp_fn = func(): return munitions.room_temp(c.target)
				elif c.medium == "cold":
					extra.temp_fn = func(): return coldchain.room_temp(c.target)
				elif c.medium == "core":
					extra.temp_fn = func(): return furnace.core_temp()
				else:
					extra.temp_fn = func(): return sys.loop_T
			"field":
				if c.medium == "tension":
					extra.field_fn = func(): return mech.tension(c.target)
					extra.unit = "kN"
				elif c.medium == "strain":
					extra.field_fn = func(): return boxbeam.strain(c.id)
					extra.unit = "%"
				elif c.medium == "rod":
					extra.field_fn = func(): return boxbeam.rod_pull(c.target)
					extra.unit = "kN"
				elif c.medium == "stay":
					extra.field_fn = func(): return sail.pull(c.target)
					extra.unit = "kN"
				elif c.medium == "dose":
					extra.field_fn = func(): return reactor.probe(c)
					extra.unit = "mSv/h"
				elif c.medium == "bend":
					extra.field_fn = func(): return train.aft_mass()
					extra.unit = "t"
				elif c.medium == "rpm":
					extra.field_fn = func(): return float(flywheel.rpm.get(c.target, 0.0))
					extra.unit = "rpm"
				elif c.medium == "ring":
					extra.field_fn = func(): return float(rings.rpm.get(c.target, 0.0))
					extra.unit = "rpm"
				elif c.medium == "bheat":
					extra.field_fn = func(): return rings.temp(c.target)
					extra.unit = "°C"
				elif c.medium == "spine":
					extra.field_fn = func(): return spine.gauge(c.id)
					extra.unit = "%"
				elif c.medium == "valve_temp":
					extra.field_fn = func(): return boiloff.valve_temp(str(c.target))
					extra.unit = "°C"
				elif c.medium == "tank_kpa":
					extra.field_fn = func(): return boiloff.tank_kpa(str(c.target))
					extra.unit = "kPa"
				elif c.medium == "mudp":
					extra.field_fn = func(): return drillstring.mud_kpa()
					extra.unit = "kPa"
				elif c.medium == "torque":
					extra.field_fn = func(): return drillstring.torque_pct()
					extra.unit = "%"
				elif c.medium == "ball":
					extra.field_fn = func(): return waterball.level() * 100.0
					extra.unit = "%"
				elif c.medium == "coil_temp":
					extra.field_fn = func(): return magnets.max_temp()
					extra.unit = "K"
				elif c.medium == "field_pct":
					extra.field_fn = func(): return magnets.field()
					extra.unit = "%"
				elif c.medium == "optics":
					extra.field_fn = func(): return optics.reflect()
					extra.unit = "%"
				elif c.medium == "zone":
					extra.field_fn = func(): return thermal.zone_temp(c.target)
					extra.unit = "°C"
				elif c.medium == "fume":
					extra.field_fn = func(): return composite.level(c.target) * 1000.0
					extra.unit = "ppm"
				elif c.medium == "stage":
					extra.field_fn = func(): return dilution.stage_temp(c.target)
					extra.unit = "K"
				elif c.medium == "rail":
					extra.field_fn = func(): return flywheel.rail_pull(c.target)
					extra.unit = "kN"
				elif c.medium == "spin":
					extra.field_fn = func(): return tether.rpm
					extra.unit = "rpm"
				elif c.medium == "tether":
					extra.field_fn = func(): return tether.pull()
					extra.unit = "kN"
				elif c.medium == "heat":
					extra.field_fn = func(): return tether.temp()
					extra.unit = "°C"
				elif c.medium == "strand":
					extra.field_fn = func(): return tether.strands()
					extra.unit = "/7"
				elif c.medium == "load":
					extra.field_fn = func(): return sandwich.load(c.id)
					extra.unit = "kN"
				elif c.medium == "crack":
					extra.field_fn = func(): return ice.strain()
					extra.unit = "%"
				else:
					extra.field_fn = func(): return mech.field(c.target)
			"bio", "o2":
				extra.room = c.target
			"sample":
				extra.sample_fn = func(): return media.sample(c.id)
	var r := {"key": key, "kind": rd.kind, "at": rd.at, "inst": rd.inst, "t": rd.t, "val": rd.val, "text": rd.text, "ver": int(rd.ver), "vk": ""}
	r.merge(extra, true)
	sys.readings[key] = r


# What a volt probe on this control shows: a discharge plug reads its
# capacitor's own cable, a test point reads the bus.
func _ctrl_volts_fn(c) -> Callable:
	if c.kind == "discharge":
		var cap_tag: String = sys.discharge_source(c.id)
		# an isolated capacitor: its own reading
		if cap_tag != "" and sys.iso.has(cap_tag):
			var cp = world.tag(cap_tag)
			return func(): return sys.piece_volts(cp) if cp != null and not cp.gone else 0.0
		var l3 = world.lines.get(sys.src[cap_tag].cable) if cap_tag != "" else null
		return func(): return sys.line_volts(l3) if l3 != null and l3.alive else 0.0
	# a test point on a piece with its own supply (a pod's battery) reads that piece
	if c.kind == "test" and c.target != "" and c.target != "bus":
		var tp = world.tag(c.target)
		return func(): return sys.piece_volts(tp) if tp != null and not tp.gone else 0.0
	return func(): return sys.bus_volts()


func _inspect_text(p) -> String:
	var counts := {}
	for j in world.joints_of(p):
		counts[j.type] = counts.get(j.type, 0) + 1
	var nl := world.lines_of(p).size()
	var parts: Array = ["%.2f t" % world.group_mass(p)]
	# 87-1: what it is made of, how the beam goes through it at the current power, what cutting cost it
	parts.append(Mat.describe(p, skill_value("laser_power") * Grid.salvage_k(self, "laser", 0.15)))
	for k in ["bolt", "weld", "lock", "clamp", "seam"]:
		if counts.has(k):
			parts.append("%d %s" % [counts[k], txt("j_" + k)])
	# a crack in the structure only shows to the precision kit
	if counts.has("crack") and has_upgrade("scan_kit"):
		parts.append("%d %s" % [counts.crack, txt("j_crack")])
	if nl > 0:
		parts.append("%d %s" % [nl, txt("j_line")])
	var behind := lines_behind(p)
	if behind > 0:
		parts.append("%d %s" % [behind, txt("j_behind")])
	if p.hazard == "explosive" and p.intact:
		parts.append(txt("j_wet") if munitions != null and munitions.wet.has(p.id) else txt("j_explosive"))
	# an armour plate: with the precision kit you can tell what is fixed behind it
	if p.art == "armor":
		var fb: int = world.fixings_behind(p) if has_upgrade("scan_kit") else 0
		parts.append(txt("j_armor") if fb == 0 else txt("j_armor_fix") % fb)
	# a bent gate or door shows it to anyone who looks
	if p.door and p.tag != "" and Ship.ctrl_cfg(ship, p.tag).get("stuck", false):
		parts.append(txt("insp_stuck"))
	if p.has_meta("segments") and p.intact:
		parts.append(txt("j_segments") % p.get_meta("segments").size())
	if p.cls == "equip" and p.intact and has_upgrade("scan_kit"):
		parts.append(txt("j_cond") % int(round(p.cond * 100.0)))
	if parts.size() == 1 and p.body == null:
		parts.append(txt("j_none"))
	return " · ".join(parts)


# cables and pipes that run behind an attached plate of the hull or a deck
func lines_behind(p) -> int:
	if p.body != null or not p.kind in ["hull", "deck", "bulkhead"]:
		return 0
	var n := 0
	# a probe senses what runs within a hand's breadth of the plate
	var grown: Array = Geometry2D.offset_polygon(p.poly, 0.25 * Geom.M)
	var near: PackedVector2Array = grown[0] if not grown.is_empty() else p.poly
	for id in world.lines:
		var l = world.lines[id]
		if not l.alive or l.a == p.id or l.b == p.id:
			continue
		var path: PackedVector2Array = world.line_path_world(l)
		for i in path.size() - 1:
			if Geometry2D.is_point_in_polygon(path[i], near) or not Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([path[i], path[i + 1]]), near).is_empty():
				n += 1
				break
	return n


# ---------------------------------------------------------------- the operation log

func log_op(kind: String, n: int = 1) -> void:
	ops[kind] = int(ops.get(kind, 0)) + n


# {manual, decision, machine, share (manual / (manual + decision))}
static func op_share(counts: Dictionary) -> Dictionary:
	var out := {"manual": 0, "decision": 0, "machine": 0}
	for k in counts:
		out[OP_CAT.get(k, "manual")] += int(counts[k])
	var hands: int = out.manual + out.decision
	out.share = float(out.manual) / hands if hands > 0 else 0.0
	return out


# ---------------------------------------------------------------- the engineering archive

# something checked by hand: kind pieces / ports / lines / ctrls, a factory name, what was found
func verify(kind: String, id: String, info) -> void:
	var pre: String = {"pieces": "p:", "ports": "c:", "lines": "l:", "ctrls": "c:"}[kind]
	if id == "" or not _factory.has(pre + id):
		return
	var was = verified[kind].get(id)
	if was is Dictionary and info is Dictionary:
		was.merge(info, true)
	else:
		verified[kind][id] = info


func tag_of(piece_id: int) -> String:
	var p = world.pieces.get(piece_id)
	return p.get_meta("origin", p.tag) if p != null else ""


# notes from earlier ships of this type, as the contract was signed with them
func notes() -> Dictionary:
	return job.get("notes", {})


# ---------------------------------------------------------------- consumables

# what is left of a consumable for this contract: the stock it was signed with, less what is used
func stock(id: String) -> int:
	var have: Dictionary = job.get("items", {}) if bot == null or not bot.has("items") else bot.items
	return int(have.get(id, 0)) - int(used.get(id, 0))


func use_item(id: String) -> bool:
	if stock(id) <= 0:
		return false
	used[id] = int(used.get(id, 0)) + 1
	return true


# +50 integrity on the spot
func repair_kit() -> void:
	if state != "play" or not drone.alive or drone.integrity >= 100.0:
		return
	if not use_item("repair"):
		say("item_none", drone.global_position + Vector2(0, -44), txt("it_repair"))
		sfx.play("deny")
		return
	drone.integrity = minf(100.0, drone.integrity + skill_value("repair_eff"))
	log_op("repair")
	fx.ring(drone.global_position, 10.0, 60.0, 0.4, Pal.ink(0.8, 1.6), 2.0)
	fx.sparks(drone.global_position, Vector2.UP, 14, Pal.ink(0.9, 1.4), 160.0, 0.4, PI)
	say("item_repaired", drone.global_position + Vector2(0, -44))
	sfx.play("ok")


const RING_REACH := 6.0 * Geom.M   # the ring is placed by the drone: as far as the measuring reach
const RING_SNAP := 1.6 * Geom.M    # the pointer this close to a member finds it


# 7 (or its slot) readies the ring; again, Esc or a right click puts it away
func arm_ring(on: bool) -> void:
	if on == ring_armed:
		return
	if on:
		if state != "play" or not drone.alive:
			return
		if stock("ring") <= 0:
			say("item_none", drone.global_position + Vector2(0, -44), txt("it_ring"))
			sfx.play("deny")
			return
		ring_aim = ring_target(aim)
		ring_wait = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	ring_armed = on
	sfx.play("switch")


# the keel, beam or rail nearest the pointer, the point on it the ring would
# clamp to and the cut it would make: {piece, at, line, ok, why}
func ring_target(at: Vector2) -> Dictionary:
	var best = null
	var best_d := RING_SNAP
	var best_at := at
	for id in world.order:
		var p = world.pieces[id]
		if p.gone or p.body != null or not p.kind in ["keel", "beam", "rail"]:
			continue
		var bb := Geom.bbox(p.poly)
		if not bb.grow(best_d).has_point(at):
			continue
		var q := at
		var d := 0.0
		if not world.piece_contains(p, at):
			d = INF
			var poly: PackedVector2Array = p.poly
			for i in poly.size():
				var e := Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])
				if at.distance_to(e) < d:
					d = at.distance_to(e)
					q = e
			# a little way into the member, not on its edge
			var mid := Vector2(q.x, bb.get_center().y) if bb.size.x >= bb.size.y else Vector2(bb.get_center().x, q.y)
			q += (mid - q).limit_length(4.0)
		if d < best_d and not world.hidden(q):
			best = p
			best_d = d
			best_at = q
	if best == null:
		return {"ok": false, "why": "ring_no_target"}
	var bb := Geom.bbox(best.poly)
	var pl: PackedVector2Array
	if bb.size.x >= bb.size.y:
		pl = PackedVector2Array([Vector2(best_at.x, bb.position.y - 6.0), Vector2(best_at.x, bb.end.y + 6.0)])
	else:
		pl = PackedVector2Array([Vector2(bb.position.x - 6.0, best_at.y), Vector2(bb.end.x + 6.0, best_at.y)])
	var near: bool = drone.alive and drone.global_position.distance_to(best_at) <= RING_REACH
	return {"piece": best, "at": best_at, "line": pl, "ok": near, "why": "" if near else "ring_far"}


# clamped on a thick member at (or next to) the cursor, it cuts clean through in one flash
func breaching_ring() -> bool:
	if state != "play" or not drone.alive:
		return false
	var tg := ring_target(aim)
	if not tg.ok:
		say(tg.why, aim)
		sfx.play("deny")
		return false
	if not use_item("ring"):
		say("item_none", aim, txt("it_ring"))
		sfx.play("deny")
		return false
	var at: Vector2 = tg.at
	cut_kerf(tg.piece, tg.line)
	log_op("ring")
	fx.flash(at, 260.0, 0.5, Pal.heat(1.0, 3.0))
	fx.ring(at, 10.0, 160.0, 0.45, Pal.heat(0.9, 2.2), 3.0)
	fx.sparks(at, Vector2.UP, 40, Pal.heat(1.0, 2.6), 480.0, 0.5, PI)
	hud.white_flash(0.2)
	shake(0.4)
	sfx.play("boom")
	say("ring_fired", at)
	return true


# what the grapple can haul (the 5 t tractor grapple lifts the limit)
func grab_max() -> float:
	return maxf(skill_value("grapple_mass"), Consum.FINE_GRAB if Consum.is_fine(self, "cap") else 0.0)


# the berth's upgrades this contract was taken with
# what goes straight to the debris net (t): 0.1, or 0.5 with the net upgrade
func debris_max() -> float:
	return 0.5 if has_upgrade("net05") else 0.1


func skill_value(id: String) -> float:
	# the fine lens cuts a finer kerf than any volume did (scripts/consum.gd)
	if id == "laser_kerf" and Consum.is_fine(self, "lens"):
		return Consum.FINE_KERF
	var kit: Dictionary = job.get("kit", {})
	if bot != null and not bot.get("kit", {}).is_empty():
		kit = kit.duplicate()
		kit.merge(bot.get("kit", {}), true)
	return Growth.value(kit, id)


func fit_skills() -> void:
	if career() and Career.usable() and Career.active().get("id", "") == job.get("id", ""):
		Growth.sync_kit(job)
		if drone != null:
			drone.queue_redraw()


# a drone module carried on this job (scripts/gear.gd)
func has_mod(id: String) -> bool:
	return gear != null and gear.has_mod(id)


func has_upgrade(id: String) -> bool:
	# the fine probe tip reads condition and hidden damage like the inspection kit
	if id == "scan_kit" and not job.is_empty() and Consum.is_fine(self, "probe"):
		return true
	# between contracts there's no contract's kit: the berth has what the career bought
	if ship.get("berth", false) and Career.data.get("upgrades", {}).has(id):
		return true
	return job.get("kit", {}).has(id) or (bot != null and bot.get("kit", {}).has(id))


func do_wrench(tg: Dictionary, by_plan: bool = false) -> void:
	if tg.get("kind", "") == "ctrl" and tg.has("ctrl"):
		changed["c:" + tg.ctrl.id] = true
	# the training interlock looks at what the wrench is about to undo
	if tutorial != null:
		var on_piece = null
		match tg.kind:
			"joint":
				on_piece = world.pieces.get(tg.joint.a)
			"connector":
				on_piece = world.pieces.get(tg.line.a if tg.end == 0 else tg.line.b)
		if on_piece != null and tutorial.interlock(on_piece):
			return
		tutorial.progress()
	match tg.kind:
		"joint":
			var j = tg.joint
			# a box on a locked rail: the rail's lock holds it, not a bolt
			if rails != null and rails.holds(j):
				say(rails.locked_msg(j), world.joint_world(j))
				sfx.play("deny")
				return
			log_op("plan" if by_plan else "unfix")
			verify("pieces", tag_of(j.a), {"held": j.type})
			var p: Vector2 = world.joint_world(j)
			world.kill_joint(j)
			fx.shard(p, Vector2(-3, 0), Vector2(3, 0), Vector2.from_angle(randf() * TAU) * 120.0, randf_range(-12, 12), 0.7, Pal.ink(0.9), 2.0)
			fx.ring(p, 3.0, 18.0, 0.3, Pal.ink(0.7, 1.2))
			sfx.play("unbolt" if j.type != "clamp" else "clamp_off")
			if j.type == "clamp":
				shake(0.2)
				say("clamp_off", p, j.get_meta("tag", ""))
		"connector":
			var l = tg.line
			log_op("plan" if by_plan else "unplug")
			verify("lines", l.id, [tag_of(l.a), tag_of(l.b)])
			if l.kind == "pipe":
				var amt: float = sys.line_fluid(l)
				if amt > 0.02:
					say("pipe_full", tg.pos)
					sfx.play("deny")
					hint("pipe_full")
					return
				if sys.line_temp(l) > 60.0:
					say("pipe_hot", tg.pos, str(int(sys.line_temp(l))))
					sfx.play("deny")
					hint("pipe_hot")
					return
			else:
				var volts := _cut_cable_volts(l)
				if volts > 30.0:
					fx.arc(tg.pos, tg.pos + Vector2.from_angle(randf() * TAU) * 30.0, 0.25, 0.6)
					fx.flash(tg.pos, 80.0, 0.25, Pal.tint(Pal.VOLT, 1.0, 2.0))
					hurt_drone(15.0, tg.pos, "live_unplug", "unplug", 0.5)
			world.kill_line(l, tg.pos)
			sfx.play("unplug")
			fx.sparks(tg.pos, Vector2.UP, 4, Pal.ink(0.8, 1.2), 90.0, 0.2, PI)
		"ctrl":
			verify("ctrls", tg.ctrl.id, tg.ctrl.kind)
			log_op("plan" if by_plan else ("door" if tg.ctrl.kind in ["door", "hatch", "jam"] else "isolate"))
			if plan != null and not by_plan:
				plan.on_player("w", tg.ctrl)
			var operated := _operate(tg.ctrl, tg.pos)
			if plan != null and not by_plan:
				plan.finish_player(operated)


func _operate(c, at: Vector2) -> bool:
	match c.kind:
		"valve":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("valve_open" if c.state else "valve_closed", at, c.id)
			sfx.play("valve")
			# a magazine's flood valve: every round in it wet, safe and worthless
			if c.state and munitions != null and munitions.flood(c.id):
				say("mag_flooded", at, c.id)
				log_op("flood")
		"switch":
			if vault != null and vault.blocks_switch(c, at):
				return false
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("sw_on" if c.state else "sw_off", at, c.id)
			sfx.play("switch")
			if rails != null:
				rails.on_switch(c)
		"remote":
			# a remote stop may or may not reach the machine: the ship file says
			sys.remote_sent = true
			c.state = true
			var rt: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.src.has(rt) and sys.src[rt].get("remote_works", true):
				sys.stop_source(rt)
			say("remote_sent", at)
			sfx.play("switch")
			hint("remote")
		"stop":
			var st: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.running(st):
				sys.stop_source(st)
				say("gen_stopped", at)
				sfx.play("gen_down")
				shake(0.15)
		"socket":
			# the berth's temporary cooling (CL-104's cold holds), not its power
			if c.target == "cold":
				c.state = not c.state
				sys.set_switch(c.id, c.state)
				say("cold_on" if c.state else "cold_off", at)
				sfx.play("plug")
				return true
			sys.aux = not sys.aux
			c.state = sys.aux
			sys.set_switch(c.id, sys.aux)
			say("aux_on" if sys.aux else "aux_off", at)
			sfx.play("plug")
		"discharge":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("discharge_on" if c.state else "discharge_off", at)
			sfx.play("plug")
		"door":
			var was_open: bool = c.state
			if vault != null and vault.operate(c, at):
				return c.state != was_open
			if rings != null and rings.blocks_door(c, at):
				return false
			if Ship.ctrl_cfg(ship, c.id).get("stuck", false):
				say("door_stuck", at, c.id)
				sfx.play("deny")
				return false
			if not (sys.bus_live or sys.aux):
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return false
			var dp = world.tag(c.target)
			if dp == null:
				return false
			dp.door_open = not dp.door_open
			c.state = dp.door_open
			sfx.play("door")
		"degauss":
			var dc := Ship.ctrl_cfg(ship, c.id)
			if not mech.degauss(dc.get("magnets", []), dc.get("supply", "")):
				say("degauss_live", at)
				sfx.play("deny")
				hint("degauss_live")
				return false
			c.state = true
			say("degaussed", at)
			sfx.play("discharge")
			fx.ring(at, 6.0, 90.0, 0.6, Pal.tint(Pal.AIR, 0.8, 1.4), 2.0)
		"seal":
			if c.state:
				say("bio_sealed_already", at)
				return false
			if not bio.seal(c.target):
				say("bio_seal_fail", at)
				sfx.play("deny")
				return false
			c.state = true
			say("bio_sealed", at, c.target)
			sfx.play("clamp_off")
			fx.ring(at, 4.0, 40.0, 0.4, Pal.tint(Pal.FLUID, 0.8, 1.3), 1.5)
		"jam":
			if c.state:
				return false
			c.state = true
			say("jam_cleared", at)
			sfx.play("unjam")
			fx.sparks(at, Vector2.UP, 12, Pal.ink(0.9, 1.4), 200.0, 0.3, 1.2)
		"hatch":
			var hc := Ship.ctrl_cfg(ship, c.id)
			var jam = world.ctrls.get(hc.get("jam", ""))
			if jam != null and not jam.state:
				say("hatch_jammed", at)
				sfx.play("deny")
				hint("hatch_jam")
				return false
			var feed = world.lines.get(hc.get("cable", ""))
			var powered: bool = (sys.bus_live and (feed == null or feed.alive)) or sys.aux
			if not powered:
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return false
			# a seam welded shut: the drive strains against it and burns out
			var sealed := false
			for t in hc.get("doors", []):
				var hp = world.tag(t)
				if hp != null and world.joints_of(hp).any(func(j): return j.type == "seam"):
					sealed = true
			if sealed:
				say("hatch_welded", at)
				sfx.play("deny")
				if not c.get_meta("burnt", false):
					c.set_meta("burnt", true)
					incident("motor", c.id)
					fx.sparks(at, Vector2.UP, 20, Pal.heat(1.0, 2.0), 260.0, 0.4, PI)
					lose("loss_motor", 2500.0, at + Vector2(0, -40))
				return false
			for t in hc.get("doors", []):
				var hp = world.tag(t)
				if hp != null and hp.body == null:
					hp.door_open = not hp.door_open
			sfx.play("hatch")
			shake(0.2)

	return true

func do_hose(tg: Dictionary, by_plan := false) -> bool:
	var c = tg.ctrl
	log_op("plan" if by_plan else "hose")
	if plan != null and not by_plan:
		plan.on_player("h", c)
	if sys.hoses.has(c.id):
		sys.hoses.erase(c.id)
		dock.hose_detach(c.id)
		say("hose_off", tg.pos, c.id)
		sfx.play("unplug")
		if plan != null and not by_plan: plan.finish_player(true)
		return true
	# a port behind a jammed valve: it has to be freed first
	var jam = world.ctrls.get(Ship.ctrl_cfg(ship, c.id).get("jam", ""))
	if jam != null and not jam.state:
		say("vent_jammed", tg.pos, c.id)
		sfx.play("deny")
		if plan != null and not by_plan: plan.finish_player(false)
		return false
	var mode := tools.hose_mode if c.medium == "gas" else "recover"
	if sys.dead_leg_closed(c):
		hint("dead_leg_hose")
	sys.hoses[c.id] = {"mode": mode, "t": 0.0}
	dock.hose_attach(c.id, tg.pos)
	say("hose_on_" + mode, tg.pos, c.id)
	sfx.play("hose_on")
	hint("hose")

	if plan != null and not by_plan: plan.finish_player(true)
	return true

# a step of the work plan, done by the berth: the same control, worked as the operator did it
func plan_do(kind: String, c) -> bool:
	var at: Vector2 = world.ctrl_world(c)
	fx.ring(at, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3))
	if kind == "h":
		return do_hose({"ctrl": c, "pos": at}, true)
	changed["c:" + c.id] = true
	var success := _operate(c, at)
	if success: log_op("plan")
	return success


# one machine at a time over a mouth: the arm and the hauler queue for it
func mouth_take(zone: String, who: String) -> bool:
	var h: String = mouths.get(zone, "")
	if h == "" or h == who:
		mouths[zone] = who
		return true
	return false


func mouth_release(zone: String, who: String) -> void:
	if mouths.get(zone, "") == who:
		mouths.erase(zone)


# where the berth's machines can fly round the ship (scripts/nav.gd), made when first wanted
var _nav = null


func nav_grid():
	if _nav == null:
		_nav = preload("res://scripts/nav.gd").new(self)
	return _nav


# the hauling drones aboard (one or two)
func haulers() -> Array:
	var out: Array = []
	for h in [hauler, hauler2]:
		if h != null:
			out.append(h)
	return out


# the keep-out key: a zone round the pointer, or off again if the pointer is in one
func toggle_keepout(at: Vector2) -> String:
	for r in keepout:
		if r.has_point(at):
			keepout.erase(r)
			dock.queue_redraw()
			return "keepout_off"
	var sz := KEEPOUT_SIZE * Geom.M
	keepout.append(Rect2(at - sz * 0.5, sz))
	if keepout.size() > KEEPOUT_MAX:
		keepout.pop_front()
	dock.queue_redraw()
	return "keepout_on"


# would a machine at `from` making for `to` cross into a keep-out zone? (one already
# inside is let out)
func keepout_blocks(from: Vector2, to: Vector2) -> bool:
	for r in keepout:
		if r.has_point(from):
			continue
		if r.has_point(to) or _seg_rect(from, to, r):
			return true
	return false


func _seg_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


# a machine keeps clear of the operator's drone: is the drone close and on the way it is going?
func drone_near(at: Vector2, r: float, going: Vector2 = Vector2.ZERO) -> bool:
	if drone == null or not drone.alive:
		return false
	var d: Vector2 = drone.global_position - at
	if d.length() >= r:
		return false
	return going == Vector2.ZERO or d.dot(going - at) > 0.0


# the automation key: every machine of the berth stops where it is, or goes on
func toggle_auto() -> void:
	auto_paused = not auto_paused
	if auto_paused:
		if plan != null:
			plan.cancel()
		if arm != null and arm.has_method("halt"):
			arm.halt()
		for h in haulers():
			h.halt()
		if crane != null:
			crane.halt()
	say("auto_off" if auto_paused else "auto_on", drone.global_position + Vector2(0, -44))
	sfx.play("switch")


# ---------------------------------------------------------------- gas & room events

func on_reveal(room: String, from: Vector2) -> void:
	reveal_count += 1
	if assist != null:
		assist.on_reveal(room)
	if state == "play":
		sfx.play("reveal", from)
		say("room_open", from, room_name(room))


func on_blowout(room: String, pos: Vector2, dir: Vector2, p0: float) -> void:
	incident("blowout", room)
	shake(0.55, dir)
	hitstop(0.06)
	fx.flash(pos, 260.0, 0.6, Pal.tint(Pal.AIR, 0.6, 1.8))
	fx.ring(pos, 10.0, 260.0, 0.6, Pal.tint(Pal.AIR, 0.7, 1.5), 3.0)
	for i in 40:
		var d := dir.rotated(randf_range(-0.5, 0.5))
		fx.spark(pos, d * randf_range(500, 1100), randf_range(0.3, 0.7), Pal.tint(Pal.AIR, 0.8, 1.6), 1.4, 16.0, 1.2)
	fx.burst_shards(pos, 12, 500.0, Pal.ink(0.8), 7.0)
	hud.white_flash(0.12)
	sfx.play("blowout", pos)
	say("blowout", pos, room_name(room))
	var k := clampf(p0 / 108.0, 0.2, 1.2)
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.room != room or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		_dent(q, maxf(0.0, q.cond - q.fragile * 0.45 * k), "dv_blowout")
		lost += (before - q.cond) * q.value
	if lost > 100.0:
		fx.number(pos + Vector2(0, -40), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
	for b in world.bodies:
		var d: Vector2 = pos - b.global_position
		if world.room_at(b.global_position) == room or d.length() < 4.0 * 48.0:
			b.apply_central_impulse((d.normalized() + dir) * b.mass * 180.0 * k)
	hint("blowout")


func on_jet(room: String, pos: Vector2, dir: Vector2, p: float, g: float) -> void:
	var strength := clampf(p / 100.0, 0.0, 1.2) * clampf(g / 8.0, 0.1, 1.5)
	if strength < 0.01:
		return
	var n := int(strength * 6.0) + (1 if randf() < strength * 6.0 - int(strength * 6.0) else 0)
	for i in n:
		var d := dir.rotated(randf_range(-0.35, 0.35))
		fx.puff(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), d * randf_range(260, 620) * (0.5 + strength), randf_range(0.35, 0.8), 3.0, 18.0 + 30.0 * strength, Pal.tint(Pal.AIR, 0.09 + 0.06 * strength))
	if randf() < strength:
		fx.spark(pos, dir.rotated(randf_range(-0.3, 0.3)) * 500.0, 0.25, Pal.tint(Pal.AIR, 0.6, 1.2), 1.0, 8.0, 2.0)
	sfx.jet(strength)
	# the stream shoves what is in it
	for b in world.bodies:
		var rel: Vector2 = b.global_position - pos
		if rel.length() < 3.5 * 48.0 and rel.dot(dir) > -20.0:
			b.apply_central_force(dir * b.mass * 600.0 * strength)
		elif world.room_at(b.global_position) == room and rel.length() < 6.0 * 48.0:
			b.apply_central_force(-rel.normalized() * b.mass * 300.0 * strength)
	if drone.alive:
		var rd := drone.global_position - pos
		if rd.length() < 3.0 * 48.0 and rd.normalized().dot(dir) > 0.4:
			drone.external += dir * drone.mass * 900.0 * strength
			if strength > 0.5 and rd.length() < 1.6 * 48.0:
				hurt_drone(25.0, pos, "jet_hit", "jet", 1.5)


func on_discharge_refused(ctrl_id: String) -> void:
	var c = world.ctrls.get(ctrl_id)
	if c != null:
		c.state = false
		say("discharge_refused", world.ctrl_world(c))
	sfx.play("deny")
	hint("discharge_refused")


# ---------------------------------------------------------------- messages & hints

func say(key: String, at: Vector2, arg: String = "") -> void:
	var text := txt(key)
	if text.find("%s") >= 0:
		text = text % arg
	for m in messages:
		if m[3] == text and m[2] < 1.2:
			m[2] = 0.0
			m[1] = at
			return
	messages.append([key, at, 0.0, text])
	while messages.size() > 6:
		messages.remove_at(0)


func _age_messages(dt: float) -> void:
	for m in messages:
		m[2] += dt
	messages = messages.filter(func(m): return m[2] < 2.6)
	for f in feed:
		f[2] += dt
	feed = feed.filter(func(f): return f[2] < 5.0)
	while feed.size() > 5:
		feed.pop_back()


# how the controls work: these stay on in the standard tier
const RATE_BONUS := [[0.92, 0.04], [0.80, 0.02], [0.70, 0.01]]   # recovery rate -> share of what was earned
const MUST_SHARE := 0.10        # a named piece delivered whole: this share of its value...
const MUST_VALUABLE := 0.25     # ...or this, on a valuable-equipment job
const MUST_MIN := 500.0
const SAFE_SHARE := 0.05        # a safe-recovery job with no incident: this share of what was earned
const UI_HINTS := ["field", "hose", "measured", "drone_lost", "free_body", "equip_cut", "equip_rail",
	"mat_armor", "mat_ti", "mat_ceramic", "mat_shield", "mat_al", "mat_composite"]
var hint_log: Array = []


# One-off explanations. Guided: all of them. Standard: only how the controls
# work (never how to solve the ship). Hardcore: none. The training course has
# Liang instead.
func hint(key: String) -> void:
	if training or exam != null or hints_seen.has(key):
		return
	var own_key: String = ship_id + ":" + key if ship.get("hints", {}).has(key) else key
	if career() and Career.data.get("hints_once", {}).has(own_key):
		return
	# 80 号: one voice while the guide runs (the hint waits for after it, unseen)
	if guide_coach() != null:
		return
	var tr := Txt.hint_tier
	if tr == "hardcore" or (tr == "standard" and not key in UI_HINTS):
		return
	var own: Array = ship.get("hints", {}).get(key, [])
	var text: String = (own[0] if Txt.zh else own[1]) if own.size() == 2 else (txt("hint_" + key) if Txt.has("hint_" + key) else "")
	if text == "":
		return
	hints_seen[key] = true
	if career():
		Career.hint_once(own_key)
	hint_log.append([key, tr])
	hud.show_hint(text)
