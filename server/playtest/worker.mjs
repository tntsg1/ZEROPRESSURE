// 零压 ZERO PRESSURE playtest gate (playtest.stellarascensiongame.com), 2026-10-30, user: "正好，我不是有那个网站吗？
// 正好这个东西做成联网的". A small Worker of its own, apart from the main site, so the site never has
// to be redeployed for it.
//   POST /activate {code, machine}  a code works once: the first machine to use it owns it, the same machine may
//                                   come back any number of times, any other machine is refused
//   POST /check    {code, machine}  every launch: still valid (not revoked, not expired, this machine)
//   POST /report?code=&machine=     the playtest record (a zip), only when the player said yes at the end
// Codes are made, listed and revoked with tools/codes.mjs (wrangler d1 execute), never over HTTP.

const MAX_REPORT = 25 * 1024 * 1024;
const CODE_RE = /^ZP-[0-9A-Z]{4}-[0-9A-Z]{4}$/;
const MACHINE_RE = /^[0-9a-f]{16,64}$/;

const now = () => Math.floor(Date.now() / 1000);

function json(data, status = 200) {
	return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
}

function expired(env) {
	const until = Date.parse(String(env.EXPIRES || "") + "T23:59:59Z");
	return Number.isFinite(until) && Date.now() > until;
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
	if (expired(env)) return json({ ok: false, error: "expired", expires: env.EXPIRES }, 403);
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
	if (expired(env)) return json({ ok: false, error: "expired", expires: env.EXPIRES }, 403);
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
	if (!CODE_RE.test(code) || !MACHINE_RE.test(machine)) return json({ ok: false, error: "invalid" }, 400);
	const row = await env.DB.prepare("SELECT machine, revoked FROM zp_codes WHERE code = ?").bind(code).first();
	if (!row || row.revoked || row.machine !== machine) return json({ ok: false, error: "refused" }, 403);
	const size = Number(request.headers.get("Content-Length") || 0);
	if (size > MAX_REPORT) return json({ ok: false, error: "too_large" }, 413);
	const body = await request.arrayBuffer();
	if (body.byteLength === 0 || body.byteLength > MAX_REPORT) return json({ ok: false, error: "too_large" }, 413);
	const t = now();
	const key = `zp-playtest/reports/${code}/${new Date(t * 1000).toISOString().replace(/[:.]/g, "-")}.zip`;
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
		if (request.method === "GET" && (path === "" || path === "/")) return json({ ok: true, service: "zero-pressure-playtest" });
		return json({ ok: false, error: "not_found" }, 404);
	},
};
