// 零压试玩版激活码管理（远程 D1：zp-playtest）。用法（在 server/playtest 目录下）：
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
if (cmd === "new") {
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
	console.log("node tools/codes.mjs new <n> [note] | list | revoke <code> | reports | fetch <r2_key> <out.zip>");
}
