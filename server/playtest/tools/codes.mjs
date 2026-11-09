// 零压试玩版管理（远程 D1：zp-playtest）。用法（在 server/playtest 目录下）：
// —— 公测版（2026-11-08 起，不用激活码）——
//   node tools/codes.mjs status                        总开关状态、登记机器数、最近 24 小时 / 7 天活跃数、反馈条数
//   node tools/codes.mjs close ["公测已结束，谢谢！"]    一键关停：所有人下次启动都进不去，显示这句话
//   node tools/codes.mjs open                          重新打开
//   node tools/codes.mjs machines                      每台登记的电脑：首次、最近、启动次数、版本
//   node tools/codes.mjs feedback [条数]               最近的反馈（默认 30 条），带编号
//   node tools/codes.mjs shot <编号> [out.jpg]         下载那条反馈的截图
//   node tools/codes.mjs log <编号> [out.txt]          下载那条反馈的日志尾部
//   node tools/codes.mjs drop-feedback <编号>          删掉一条反馈（连截图、日志）
//   node tools/codes.mjs drop-machine <指纹前缀>        删掉一台电脑的登记（和它的反馈）
// —— 10-30 试玩版（激活码，留着）——
//   node tools/codes.mjs new 20 "Playcocola 第一批"   生成 20 个码，写进数据库，追加到 codes.txt
//   node tools/codes.mjs list                          每个码：备注、是否激活、哪台电脑、最后上线
//   node tools/codes.mjs revoke ZP-XXXX-XXXX           作废一个码（已激活的那台电脑下次启动就进不去）
//   node tools/codes.mjs reports                       玩家上传的试玩记录
//   node tools/codes.mjs fetch <r2_key> <out.zip>      下载一份记录
import { execSync } from "node:child_process";
import { appendFileSync, writeFileSync, mkdtempSync } from "node:fs";
import { randomInt } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";

const WRANGLER = process.env.WRANGLER || "npx --no-install wrangler";
const DB = "zp-playtest";
const BUCKET = "pixel-observatory-game-assets";
const ALPHA = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";   // no 0/O, 1/I

function wr(args) {
	const line = [WRANGLER, ...args.map((x) => (/[\s"']/.test(x) ? `"${String(x).replace(/"/g, '\\"')}"` : x))].join(" ");
	return execSync(line, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function query(sql) {
	const out = wr(["d1", "execute", DB, "--remote", "--json", "--command", sql]);
	const parsed = JSON.parse(out.slice(out.indexOf("[")));
	return parsed[0]?.results || [];
}

function part() {
	let s = "";
	for (let i = 0; i < 4; i++) s += ALPHA[randomInt(ALPHA.length)];
	return s;
}

const [cmd, a, b] = process.argv.slice(2);
const when = (x) => (x ? new Date(x * 1000).toISOString().slice(0, 16).replace("T", " ") : "-");
const esc = (x) => String(x).replace(/'/g, "''");
const KIND = { stuck: "卡住了", bug: "有 bug", idea: "建议", other: "其他" };

function feedbackRow(id) {
	const r = query(`SELECT * FROM zp_feedback WHERE id = ${Number(id) | 0}`)[0];
	if (!r) { console.log(`没有编号 ${id} 的反馈`); process.exit(1); }
	return r;
}

if (cmd === "status") {
	const t = Math.floor(Date.now() / 1000);
	const f = Object.fromEntries(query("SELECT k, v FROM zp_flags").map((r) => [r.k, r.v]));
	const m = query(`SELECT COUNT(*) AS n, SUM(last_seen > ${t - 86400}) AS d1, SUM(last_seen > ${t - 7 * 86400}) AS d7 FROM zp_machines`)[0] || {};
	const fb = query("SELECT COUNT(*) AS n FROM zp_feedback")[0] || {};
	console.log(`总开关：${f.closed === "1" ? "已关停（" + (f.closed_text || "公测已结束，谢谢！") + "）" : "开着，能玩"}`);
	console.log(`登记的电脑：${m.n || 0} 台；最近 24 小时活跃 ${m.d1 || 0} 台；最近 7 天活跃 ${m.d7 || 0} 台`);
	console.log(`反馈：${fb.n || 0} 条（node tools/codes.mjs feedback 查看）`);
} else if (cmd === "close") {
	const text = esc(a || "公测已结束，谢谢！");
	query(`INSERT INTO zp_flags (k, v) VALUES ('closed', '1') ON CONFLICT(k) DO UPDATE SET v = '1'`);
	query(`INSERT INTO zp_flags (k, v) VALUES ('closed_text', '${text}') ON CONFLICT(k) DO UPDATE SET v = '${text}'`);
	console.log(`已关停。所有人下次启动看到：${a || "公测已结束，谢谢！"}`);
} else if (cmd === "open") {
	query(`INSERT INTO zp_flags (k, v) VALUES ('closed', '0') ON CONFLICT(k) DO UPDATE SET v = '0'`);
	console.log("已重新打开，能玩了。");
} else if (cmd === "machines") {
	const rows = query("SELECT * FROM zp_machines ORDER BY last_seen DESC");
	for (const r of rows) console.log(`${r.machine.slice(0, 12)}  首次 ${when(r.first_seen)}  最近 ${when(r.last_seen)}  启动 ${r.checks} 次  ${r.version}${r.revoked ? "  已停用" : ""}`);
	console.log(`共 ${rows.length} 台`);
} else if (cmd === "feedback") {
	const n = Math.max(1, Math.min(500, Number(a) || 30));
	for (const r of query(`SELECT * FROM zp_feedback ORDER BY id DESC LIMIT ${n}`).reverse()) {
		console.log(`#${r.id}  ${when(r.created_at)}  [${KIND[r.kind] || r.kind}]  ${r.machine.slice(0, 8)}  玩了 ${Math.round(r.played_s / 60)} 分  章节 ${r.chapter || "-"}  船 ${r.ship || "-"}  ${r.version}  截图 ${r.shot_key ? (r.shot_bytes / 1024).toFixed(0) + " KB" : "无"}`);
		console.log("    " + String(r.text).split("\n").join("\n    "));
	}
} else if ((cmd === "shot" || cmd === "log") && a) {
	const r = feedbackRow(a);
	const key = cmd === "shot" ? r.shot_key : r.log_key;
	if (!key) { console.log("这条反馈没有" + (cmd === "shot" ? "截图" : "日志")); process.exit(1); }
	const out = b || `feedback_${r.id}${cmd === "shot" ? ".jpg" : ".log.txt"}`;
	wr(["r2", "object", "get", `${BUCKET}/${key}`, "--remote", "--file", out]);
	console.log(`saved ${out}`);
} else if (cmd === "drop-feedback" && a) {
	const r = feedbackRow(a);
	for (const k of [r.shot_key, r.log_key]) if (k) wr(["r2", "object", "delete", `${BUCKET}/${k}`, "--remote"]);
	query(`DELETE FROM zp_feedback WHERE id = ${r.id}`);
	console.log(`删掉了反馈 #${r.id}`);
} else if (cmd === "drop-machine" && a) {
	const pre = esc(String(a).toLowerCase().replace(/[^0-9a-f]/g, ""));
	if (pre.length < 6) { console.log("指纹前缀至少 6 位"); process.exit(1); }
	const ms = query(`SELECT machine FROM zp_machines WHERE machine LIKE '${pre}%'`);
	if (ms.length !== 1) { console.log(`前缀 ${pre} 对上 ${ms.length} 台，需要正好一台`); process.exit(1); }
	const m = ms[0].machine;
	for (const r of query(`SELECT id, shot_key, log_key FROM zp_feedback WHERE machine = '${m}'`)) {
		for (const k of [r.shot_key, r.log_key]) if (k) wr(["r2", "object", "delete", `${BUCKET}/${k}`, "--remote"]);
	}
	for (const r of query(`SELECT r2_key FROM zp_reports WHERE machine = '${m}' AND code = ''`)) wr(["r2", "object", "delete", `${BUCKET}/${r.r2_key}`, "--remote"]);
	query(`DELETE FROM zp_reports WHERE machine = '${m}' AND code = ''`);
	query(`DELETE FROM zp_feedback WHERE machine = '${m}'`);
	query(`DELETE FROM zp_machines WHERE machine = '${m}'`);
	console.log(`删掉了电脑 ${m.slice(0, 12)} 的登记、反馈和试玩记录`);
} else if (cmd === "new") {
	const n = Math.max(1, Math.min(200, Number(a) || 10));
	const note = String(b || "").replace(/'/g, "''");
	const codes = [];
	for (let i = 0; i < n; i++) codes.push(`ZP-${part()}-${part()}`);
	const t = Math.floor(Date.now() / 1000);
	const sql = codes.map((c) => `INSERT INTO zp_codes (code, note, created_at) VALUES ('${c}', '${note}', ${t});`).join("\n");
	const file = join(mkdtempSync(join(tmpdir(), "zpcodes-")), "codes.sql");
	writeFileSync(file, sql);
	wr(["d1", "execute", DB, "--remote", "--file", file]);
	appendFileSync("codes.txt", `# ${new Date().toISOString()} ${b || ""}\n${codes.join("\n")}\n`);
	console.log(codes.join("\n"));
	console.log(`\n${n} codes written to ${DB} and appended to codes.txt`);
} else if (cmd === "list") {
	for (const r of query("SELECT code, note, machine, activated_at, last_seen, checks, revoked FROM zp_codes ORDER BY created_at, code")) {
		const when = (s) => (s ? new Date(s * 1000).toISOString().slice(0, 16).replace("T", " ") : "-");
		console.log(`${r.code}  ${r.revoked ? "REVOKED" : r.machine ? "ACTIVE " : "unused "}  ${r.machine ? r.machine.slice(0, 8) : "--------"}  activated ${when(r.activated_at)}  last ${when(r.last_seen)}  checks ${r.checks}  ${r.note}`);
	}
} else if (cmd === "revoke" && a) {
	query(`UPDATE zp_codes SET revoked = 1 WHERE code = '${String(a).toUpperCase().replace(/'/g, "")}'`);
	console.log(`revoked ${a}`);
} else if (cmd === "reports") {
	for (const r of query("SELECT id, code, bytes, created_at, r2_key FROM zp_reports ORDER BY id")) {
		console.log(`#${r.id}  ${r.code}  ${(r.bytes / 1024).toFixed(0)} KB  ${new Date(r.created_at * 1000).toISOString().slice(0, 16)}  ${r.r2_key}`);
	}
} else if (cmd === "fetch" && a && b) {
	wr(["r2", "object", "get", `${BUCKET}/${a}`, "--remote", "--file", b]);
	console.log(`saved ${b}`);
} else {
	console.log("node tools/codes.mjs status | close [text] | open | machines | feedback [n] | shot <id> [out] | log <id> [out] | drop-feedback <id> | drop-machine <prefix>");
	console.log("  (10-30 build) new <n> [note] | list | revoke <code> | reports | fetch <r2_key> <out.zip>");
}
