// 零压 ZERO PRESSURE playtest gate (playtest.stellarascensiongame.com), 2026-10-30, user: "正好，我不是有那个网站吗？
// 正好这个东西做成联网的". A small Worker of its own, apart from the main site, so the site never has
// to be redeployed for it.
//   POST /activate {code, machine}  a code works once: the first machine to use it owns it, the same machine may
//                                   come back any number of times, any other machine is refused
//   POST /check    {code, machine}  every launch: still valid (not revoked, not expired, this machine)
//   POST /report?code=&machine=     the playtest record (a zip), only when the player said yes at the end
// Codes are made, listed and revoked with tools/codes.mjs (wrangler d1 execute), never over HTTP.
// 公测版 2026-11-08（用户定案 Q1 B / Q3 C / Q4 A）: no codes any more —
//   POST /hello    {machine, version}        every launch: the machine is registered the first time and
//                                            seen again after; refused with "closed" once the switch is on
//   POST /feedback {machine, kind, text, …}  a player's feedback (a JPG and the log tail with it), kept in R2
//                                            and D1; 3 a minute a machine, 2000 characters at most
//   POST /report?machine=                    the end-of-hour record, from a registered machine
// The switch (zp_flags.closed) and the lists are worked with tools/codes.mjs, never over HTTP.
// /activate and /check stay for the 10-30 playtest build; the end date is gone (the switch stops it).

const MAX_REPORT = 25 * 1024 * 1024;
const MAX_FEEDBACK = 2 * 1024 * 1024;      // the whole JSON: a 300 KB JPG in base64, the log tail, the words
const MAX_TEXT = 2000;
const MAX_SHOT = 300 * 1024;
const MAX_LOG = 64 * 1024;
const PER_MINUTE = 3;
const KINDS = ["stuck", "bug", "idea", "other"];
const CLOSED_TEXT = "公测已结束，谢谢！";
const CODE_RE = /^ZP-[0-9A-Z]{4}-[0-9A-Z]{4}$/;
const MACHINE_RE = /^[0-9a-f]{16,64}$/;

const now = () => Math.floor(Date.now() / 1000);

function json(data, status = 200) {
	return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
}

// no end date now (Q3 C): EXPIRES left empty never expires; the switch below stops everyone
function expired(env) {
	if (!env.EXPIRES) return false;
	const until = Date.parse(String(env.EXPIRES) + "T23:59:59Z");
	return Number.isFinite(until) && Date.now() > until;
}

async function closed(env) {
	const row = await env.DB.prepare("SELECT v FROM zp_flags WHERE k = 'closed'").first();
	return !!row && String(row.v) === "1";
}

async function closedText(env) {
	const row = await env.DB.prepare("SELECT v FROM zp_flags WHERE k = 'closed_text'").first();
	return row && row.v ? String(row.v) : CLOSED_TEXT;
}

async function readJson(request, max) {
	const size = Number(request.headers.get("Content-Length") || 0);
	if (size > max) return null;
	const raw = await request.arrayBuffer();
	if (raw.byteLength > max) return null;
	try { return JSON.parse(new TextDecoder().decode(raw)); } catch { return null; }
}

function b64bytes(s) {
	const bin = atob(String(s || ""));
	const out = new Uint8Array(bin.length);
	for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
	return out;
}

// every launch of the public build: the machine registered the first time, seen again after
async function hello(env, request) {
	const body = await readJson(request, 4096);
	const machine = String(body?.machine || "").trim().toLowerCase();
	if (!MACHINE_RE.test(machine)) return json({ ok: false, error: "invalid" }, 400);
	if (await closed(env)) return json({ ok: false, error: "closed", message: await closedText(env) }, 403);
	const version = String(body?.version || "").slice(0, 40);
	const t = now();
	const row = await env.DB.prepare("SELECT revoked FROM zp_machines WHERE machine = ?").bind(machine).first();
	if (row && row.revoked) return json({ ok: false, error: "revoked" }, 403);
	if (!row) {
		await env.DB.prepare("INSERT OR IGNORE INTO zp_machines (machine, first_seen, last_seen, checks, version) VALUES (?, ?, ?, 1, ?)")
			.bind(machine, t, t, version).run();
	} else {
		await env.DB.prepare("UPDATE zp_machines SET last_seen = ?, checks = checks + 1, version = ? WHERE machine = ?").bind(t, version, machine).run();
	}
	return json({ ok: true, first: !row });
}

async function feedback(env, request) {
	const b = await readJson(request, MAX_FEEDBACK);
	if (!b) return json({ ok: false, error: "too_large" }, 413);
	const machine = String(b.machine || "").trim().toLowerCase();
	if (!MACHINE_RE.test(machine)) return json({ ok: false, error: "invalid" }, 400);
	const reg = await env.DB.prepare("SELECT revoked FROM zp_machines WHERE machine = ?").bind(machine).first();
	if (!reg || reg.revoked) return json({ ok: false, error: "unknown_machine" }, 403);
	const text = String(b.text || "").trim();
	if (text.length === 0) return json({ ok: false, error: "empty" }, 400);
	if ([...text].length > MAX_TEXT) return json({ ok: false, error: "too_long", max: MAX_TEXT }, 413);
	const t = now();
	const recent = await env.DB.prepare("SELECT COUNT(*) AS n FROM zp_feedback WHERE machine = ? AND created_at > ?").bind(machine, t - 60).first();
	if (recent && recent.n >= PER_MINUTE) return json({ ok: false, error: "rate", retry_s: 60 }, 429);
	const kind = KINDS.includes(String(b.kind)) ? String(b.kind) : "other";
	const stamp = new Date(t * 1000).toISOString().replace(/[:.]/g, "-");
	const base = `zp-playtest/feedback/${machine.slice(0, 12)}/${stamp}-${crypto.randomUUID().slice(0, 8)}`;
	let shotKey = "", logKey = "", shotBytes = 0;
	if (b.shot) {
		let shot;
		try { shot = b64bytes(b.shot); } catch { return json({ ok: false, error: "invalid_shot" }, 400); }
		if (shot.byteLength > MAX_SHOT) return json({ ok: false, error: "shot_too_large" }, 413);
		shotKey = base + ".jpg";
		shotBytes = shot.byteLength;
		await env.REPORTS.put(shotKey, shot, { httpMetadata: { contentType: "image/jpeg" } });
	}
	const log = String(b.log || "").slice(-MAX_LOG);
	if (log) {
		logKey = base + ".log.txt";
		await env.REPORTS.put(logKey, log, { httpMetadata: { contentType: "text/plain; charset=utf-8" } });
	}
	const r = await env.DB.prepare("INSERT INTO zp_feedback (machine, kind, text, version, played_s, chapter, ship, shot_key, shot_bytes, log_key, made_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
		.bind(machine, kind, text, String(b.version || "").slice(0, 40), Math.round(Number(b.played_s) || 0), String(b.chapter || "").slice(0, 40),
			String(b.ship || "").slice(0, 80), shotKey, shotBytes, logKey, String(b.made_at || "").slice(0, 40), t).run();
	return json({ ok: true, id: r.meta?.last_row_id ?? null });
}

async function readPair(request) {
	let body = {};
	try { body = await request.json(); } catch { return null; }
	const code = String(body.code || "").trim().toUpperCase();
	const machine = String(body.machine || "").trim().toLowerCase();
	if (!CODE_RE.test(code) || !MACHINE_RE.test(machine)) return null;
	return { code, machine };
}

async function activate(env, request) {
	const p = await readPair(request);
	if (!p) return json({ ok: false, error: "invalid" }, 400);
	if (expired(env) || (await closed(env))) return json({ ok: false, error: "expired", expires: env.EXPIRES }, 403);
	const row = await env.DB.prepare("SELECT code, machine, revoked FROM zp_codes WHERE code = ?").bind(p.code).first();
	if (!row) return json({ ok: false, error: "unknown" }, 404);
	if (row.revoked) return json({ ok: false, error: "revoked" }, 403);
	if (row.machine && row.machine !== p.machine) return json({ ok: false, error: "used" }, 409);
	const t = now();
	if (!row.machine) {
		// only the first machine gets it, even if two press at once
		const r = await env.DB.prepare("UPDATE zp_codes SET machine = ?, activated_at = ?, last_seen = ?, checks = checks + 1 WHERE code = ? AND machine IS NULL")
			.bind(p.machine, t, t, p.code).run();
		if (!r.meta || r.meta.changes !== 1) return json({ ok: false, error: "used" }, 409);
	} else {
		await env.DB.prepare("UPDATE zp_codes SET last_seen = ?, checks = checks + 1 WHERE code = ?").bind(t, p.code).run();
	}
	return json({ ok: true, expires: env.EXPIRES });
}

async function check(env, request) {
	const p = await readPair(request);
	if (!p) return json({ ok: false, error: "invalid" }, 400);
	if (expired(env) || (await closed(env))) return json({ ok: false, error: "expired", expires: env.EXPIRES }, 403);
	const row = await env.DB.prepare("SELECT machine, revoked FROM zp_codes WHERE code = ?").bind(p.code).first();
	if (!row) return json({ ok: false, error: "unknown" }, 404);
	if (row.revoked) return json({ ok: false, error: "revoked" }, 403);
	if (row.machine !== p.machine) return json({ ok: false, error: "used" }, 409);
	await env.DB.prepare("UPDATE zp_codes SET last_seen = ?, checks = checks + 1 WHERE code = ?").bind(now(), p.code).run();
	return json({ ok: true, expires: env.EXPIRES });
}

async function report(env, request) {
	const url = new URL(request.url);
	const code = String(url.searchParams.get("code") || "").toUpperCase();
	const machine = String(url.searchParams.get("machine") || "").toLowerCase();
	if (!MACHINE_RE.test(machine)) return json({ ok: false, error: "invalid" }, 400);
	if (code) {
		// the 10-30 build: its code must own this machine
		if (!CODE_RE.test(code)) return json({ ok: false, error: "invalid" }, 400);
		const row = await env.DB.prepare("SELECT machine, revoked FROM zp_codes WHERE code = ?").bind(code).first();
		if (!row || row.revoked || row.machine !== machine) return json({ ok: false, error: "refused" }, 403);
	} else {
		// the public build: a registered machine
		const reg = await env.DB.prepare("SELECT revoked FROM zp_machines WHERE machine = ?").bind(machine).first();
		if (!reg || reg.revoked) return json({ ok: false, error: "refused" }, 403);
	}
	const size = Number(request.headers.get("Content-Length") || 0);
	if (size > MAX_REPORT) return json({ ok: false, error: "too_large" }, 413);
	const body = await request.arrayBuffer();
	if (body.byteLength === 0 || body.byteLength > MAX_REPORT) return json({ ok: false, error: "too_large" }, 413);
	const t = now();
	const key = `zp-playtest/reports/${code || machine.slice(0, 12)}/${new Date(t * 1000).toISOString().replace(/[:.]/g, "-")}.zip`;
	await env.REPORTS.put(key, body, { httpMetadata: { contentType: "application/zip" } });
	await env.DB.prepare("INSERT INTO zp_reports (code, machine, r2_key, bytes, created_at) VALUES (?, ?, ?, ?, ?)")
		.bind(code, machine, key, body.byteLength, t).run();
	return json({ ok: true });
}

export default {
	async fetch(request, env) {
		const path = new URL(request.url).pathname.replace(/\/+$/, "");
		if (request.method === "POST" && path === "/activate") return activate(env, request);
		if (request.method === "POST" && path === "/check") return check(env, request);
		if (request.method === "POST" && path === "/report") return report(env, request);
		if (request.method === "POST" && path === "/hello") return hello(env, request);
		if (request.method === "POST" && path === "/feedback") return feedback(env, request);
		if (request.method === "GET" && (path === "" || path === "/")) return json({ ok: true, service: "zero-pressure-playtest" });
		return json({ ok: false, error: "not_found" }, 404);
	},
};
